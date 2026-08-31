import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/workspace_capture_mode.dart';

/// Work lanes coordinated by [EvidenceSyncManager] (Sprint 6B Task 3).
enum EvidenceSyncLane {
  /// Photos, video, voice, attachments, essential metadata → Firebase.
  fastSync,

  /// AI enrichment, relationships, transcription, reconstruction, scoring.
  intelligence,
}

/// Priority within a lane — architecture supports HIGH / NORMAL / LOW.
enum SyncWorkPriority {
  high,
  normal,
  low,
}

/// One queued sync / intelligence unit.
class EvidenceSyncQueueItem {
  const EvidenceSyncQueueItem({
    required this.evidenceId,
    required this.incidentId,
    required this.lane,
    required this.priority,
    required this.enqueuedAt,
    this.userId = '',
    this.mode,
    this.localFilePath,
    this.attempts = 0,
    this.nextAttemptAt,
  });

  final String evidenceId;
  final String incidentId;

  /// Authenticated user who created this queue row. Identity is immutable.
  final String userId;
  final EvidenceSyncLane lane;
  final SyncWorkPriority priority;
  final DateTime enqueuedAt;
  final WorkspaceCaptureMode? mode;
  final String? localFilePath;
  final int attempts;

  /// When set, workers skip until this time (backoff).
  final DateTime? nextAttemptAt;

  /// Fail-closed ownership: blank ids never authorize work for the current user.
  bool isOwnedBy(String currentUserId) {
    return userId.isNotEmpty &&
        currentUserId.isNotEmpty &&
        userId == currentUserId;
  }

  EvidenceSyncQueueItem copyWith({
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttemptAt = false,
    SyncWorkPriority? priority,
    EvidenceSyncLane? lane,
  }) {
    return EvidenceSyncQueueItem(
      evidenceId: evidenceId,
      incidentId: incidentId,
      userId: userId,
      lane: lane ?? this.lane,
      priority: priority ?? this.priority,
      enqueuedAt: enqueuedAt,
      mode: mode,
      localFilePath: localFilePath,
      attempts: attempts ?? this.attempts,
      nextAttemptAt:
          clearNextAttemptAt ? null : (nextAttemptAt ?? this.nextAttemptAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'evidenceId': evidenceId,
        'incidentId': incidentId,
        'userId': userId,
        'lane': lane.name,
        'priority': priority.name,
        'enqueuedAt': enqueuedAt.toIso8601String(),
        'mode': mode?.name,
        'localFilePath': localFilePath,
        'attempts': attempts,
        'nextAttemptAt': nextAttemptAt?.toIso8601String(),
        // Legacy Task 2 wire key — keep for older persisted queues.
        'priorityLegacy': lane == EvidenceSyncLane.fastSync
            ? 'immediateEvidence'
            : 'intelligenceProcessing',
      };

  factory EvidenceSyncQueueItem.fromJson(Map<String, dynamic> json) {
    final lane = _laneFromJson(json);
    final priorityName = json['priority'] as String?;
    final priority = SyncWorkPriority.values.firstWhere(
      (value) => value.name == priorityName,
      orElse: () => lane == EvidenceSyncLane.fastSync
          ? SyncWorkPriority.high
          : SyncWorkPriority.normal,
    );
    final modeName = json['mode'] as String?;
    WorkspaceCaptureMode? mode;
    if (modeName != null) {
      mode = WorkspaceCaptureMode.values.firstWhere(
        (value) => value.name == modeName,
        orElse: () => WorkspaceCaptureMode.photo,
      );
    }
    return EvidenceSyncQueueItem(
      evidenceId: json['evidenceId'] as String? ?? '',
      incidentId: json['incidentId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      lane: lane,
      priority: priority,
      enqueuedAt: DateTime.tryParse(json['enqueuedAt'] as String? ?? '') ??
          DateTime.now(),
      mode: mode,
      localFilePath: json['localFilePath'] as String?,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAt: DateTime.tryParse(json['nextAttemptAt'] as String? ?? ''),
    );
  }

  static EvidenceSyncLane _laneFromJson(Map<String, dynamic> json) {
    final laneName = json['lane'] as String?;
    if (laneName != null) {
      return EvidenceSyncLane.values.firstWhere(
        (value) => value.name == laneName,
        orElse: () => EvidenceSyncLane.fastSync,
      );
    }
    // Sprint 6B Task 2 compatibility.
    final legacy = json['priority'] as String? ??
        json['priorityLegacy'] as String? ??
        'immediateEvidence';
    if (legacy == 'intelligenceProcessing' || legacy == 'normal') {
      return EvidenceSyncLane.intelligence;
    }
    return EvidenceSyncLane.fastSync;
  }
}

/// Durable dual-lane queue: FAST_SYNC (HIGH) + INTELLIGENCE (NORMAL).
///
/// FIFO within the same [SyncWorkPriority]. Fast lane is always preferred
/// over intelligence when selecting work.
class EvidenceSyncQueue extends ChangeNotifier {
  EvidenceSyncQueue({SharedPreferences? preferences})
      : _preferencesOverride = preferences;

  static const String _storageKey = 'evidence_sync_queue_v1';

  SharedPreferences? _preferencesOverride;
  final List<EvidenceSyncQueueItem> _items = [];
  bool _loaded = false;

  UnmodifiableListView<EvidenceSyncQueueItem> get items =>
      UnmodifiableListView(_items);

  bool get hasPending => _items.isNotEmpty;

  bool get hasFastPending =>
      _items.any((item) => item.lane == EvidenceSyncLane.fastSync);

  bool get hasIntelligencePending =>
      _items.any((item) => item.lane == EvidenceSyncLane.intelligence);

  List<EvidenceSyncQueueItem> get fastSyncItems => _items
      .where((item) => item.lane == EvidenceSyncLane.fastSync)
      .toList(growable: false);

  List<EvidenceSyncQueueItem> get intelligenceItems => _items
      .where((item) => item.lane == EvidenceSyncLane.intelligence)
      .toList(growable: false);

  /// Legacy alias used by Task 2 call sites / tests.
  List<EvidenceSyncQueueItem> get immediateEvidence => fastSyncItems;

  List<EvidenceSyncQueueItem> get intelligenceProcessing => intelligenceItems;

  Future<SharedPreferences> get _preferences async =>
      _preferencesOverride ??= await SharedPreferences.getInstance();

  Future<void> restore() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final prefs = await _preferences;
      final raw = prefs.getString(_storageKey);
      _items.clear();
      if (raw == null || raw.isEmpty) {
        notifyListeners();
        return;
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          _items.add(EvidenceSyncQueueItem.fromJson(entry));
        } else if (entry is Map) {
          _items.add(
            EvidenceSyncQueueItem.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
      _sortStable();
      notifyListeners();
    } catch (error) {
      debugPrint('[EvidenceSyncQueue] restore failed: $error');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await _preferences;
      await prefs.setString(
        _storageKey,
        jsonEncode([for (final item in _items) item.toJson()]),
      );
    } catch (error) {
      if (kDebugMode &&
          !error.toString().contains('Binding has not yet been initialized')) {
        debugPrint('[EvidenceSyncQueue] persist failed: $error');
      }
    }
  }

  int _priorityRank(SyncWorkPriority priority) => switch (priority) {
        SyncWorkPriority.high => 0,
        SyncWorkPriority.normal => 1,
        SyncWorkPriority.low => 2,
      };

  void _sortStable() {
    _items.sort((a, b) {
      final byPriority =
          _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
      if (byPriority != 0) {
        return byPriority;
      }
      return a.enqueuedAt.compareTo(b.enqueuedAt);
    });
  }

  Future<void> enqueue(EvidenceSyncQueueItem item) async {
    await restore();
    // Idempotent: one queue row per evidenceId (duplicate upload protection).
    _items.removeWhere((entry) => entry.evidenceId == item.evidenceId);
    _items.add(item);
    _sortStable();
    notifyListeners();
    await _persist();
  }

  bool _isReady(EvidenceSyncQueueItem item, DateTime now) {
    final next = item.nextAttemptAt;
    return next == null || !next.isAfter(now);
  }

  /// Next ready work unit for [lane], skipping [excludeIds] (in-flight).
  ///
  /// When [ownerUserId] is non-null, foreign or unproven rows are skipped
  /// (never remapped to the caller).
  EvidenceSyncQueueItem? peekLane(
    EvidenceSyncLane lane, {
    Set<String> excludeIds = const {},
    DateTime? now,
    String? ownerUserId,
  }) {
    final clock = now ?? DateTime.now();
    for (final item in _items) {
      if (item.lane != lane) {
        continue;
      }
      if (excludeIds.contains(item.evidenceId)) {
        continue;
      }
      if (ownerUserId != null && !item.isOwnedBy(ownerUserId)) {
        continue;
      }
      if (!_isReady(item, clock)) {
        continue;
      }
      return item;
    }
    return null;
  }

  /// Next work unit: fast sync before intelligence (FIFO within priority).
  EvidenceSyncQueueItem? peekNext({
    Set<String> excludeIds = const {},
    DateTime? now,
    String? ownerUserId,
  }) {
    return peekLane(
          EvidenceSyncLane.fastSync,
          excludeIds: excludeIds,
          now: now,
          ownerUserId: ownerUserId,
        ) ??
        peekLane(
          EvidenceSyncLane.intelligence,
          excludeIds: excludeIds,
          now: now,
          ownerUserId: ownerUserId,
        );
  }

  Future<EvidenceSyncQueueItem?> takeLane(
    EvidenceSyncLane lane, {
    Set<String> excludeIds = const {},
    DateTime? now,
    String? ownerUserId,
  }) async {
    final next = peekLane(
      lane,
      excludeIds: excludeIds,
      now: now,
      ownerUserId: ownerUserId,
    );
    if (next == null) {
      return null;
    }
    _items.removeWhere((entry) => entry.evidenceId == next.evidenceId);
    notifyListeners();
    await _persist();
    return next;
  }

  Future<EvidenceSyncQueueItem?> takeNext({
    Set<String> excludeIds = const {},
    DateTime? now,
    String? ownerUserId,
  }) async {
    final next = peekNext(
      excludeIds: excludeIds,
      now: now,
      ownerUserId: ownerUserId,
    );
    if (next == null) {
      return null;
    }
    _items.removeWhere((entry) => entry.evidenceId == next.evidenceId);
    notifyListeners();
    await _persist();
    return next;
  }

  Future<void> remove(String evidenceId) async {
    final before = _items.length;
    _items.removeWhere((entry) => entry.evidenceId == evidenceId);
    if (_items.length != before) {
      notifyListeners();
      await _persist();
    }
  }

  /// Drops all queued work (sign-out / test reset).
  Future<void> clear() async {
    if (_items.isEmpty && _loaded) {
      return;
    }
    _items.clear();
    _loaded = false;
    notifyListeners();
    await _persist();
  }

  Future<void> bumpAttempt(
    String evidenceId, {
    DateTime? nextAttemptAt,
  }) async {
    final index = _items.indexWhere((entry) => entry.evidenceId == evidenceId);
    if (index == -1) {
      return;
    }
    _items[index] = _items[index].copyWith(
      attempts: _items[index].attempts + 1,
      nextAttemptAt: nextAttemptAt,
    );
    notifyListeners();
    await _persist();
  }

  @visibleForTesting
  void resetForTests() {
    _items.clear();
    _loaded = false;
    notifyListeners();
  }
}
