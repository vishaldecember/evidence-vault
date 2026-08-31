import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/incident/incident.dart';
import '../../domain/incident/incident_deletion_lifecycle.dart';
import '../../domain/incident/incident_status.dart';
import '../../domain/incident/incident_title.dart';
import '../../models/library_incident_record.dart';
import '../../models/library_incident_summary.dart';
import '../../repositories/firebase/firebase_incident_repository.dart';
import '../auth/firebase_bootstrap.dart';
import '../storage/local_evidence_cache.dart';
import '../user_session_service.dart';
import 'incident_owned_deletion_service.dart';

/// Loads every incident the signed-in investigator has preserved, for the
/// Home Library preview and the Vault (Sprint 4D).
///
/// UI reads [summaries] / [records] and calls [refresh] — it never touches
/// Firestore directly.
///
/// Evidence counts are local-first: [upsertFromLocal] after capture, and
/// [refresh] merges LocalEvidenceCache counts so Airplane Mode / first-incident
/// captures are not stuck at 0 when cloud metadata is stale or unavailable.
class IncidentLibraryService extends ChangeNotifier {
  IncidentLibraryService({FirebaseIncidentRepository? repository})
    : _repositoryOverride = repository;

  static final IncidentLibraryService instance = IncidentLibraryService();

  FirebaseIncidentRepository? _repositoryOverride;

  FirebaseIncidentRepository get _repository =>
      _repositoryOverride ??= FirebaseIncidentRepository();

  static const _archivedIdsKey = 'incident_lifecycle_archived_ids';
  static const _pendingRestoredKey = 'incident_lifecycle_pending_restored_ids';
  static const _recentlyDeletedIdsKey =
      'incident_lifecycle_recently_deleted_ids';
  static const _deletedAtKey = 'incident_lifecycle_deleted_at';

  List<LibraryIncidentSummary> summaries = [];
  List<LibraryIncidentRecord> records = [];

  final Set<String> _archivedIds = {};
  final Set<String> _pendingRestoredIds = {};
  final Set<String> _recentlyDeletedIds = {};
  final Map<String, DateTime> _deletedAtById = {};
  bool _lifecycleLoaded = false;

  IncidentOwnedDeletionService _deletionService =
      const IncidentOwnedDeletionService();

  @visibleForTesting
  set debugDeletionService(IncidentOwnedDeletionService service) {
    _deletionService = service;
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool isArchivedId(String incidentId) =>
      _archivedIds.contains(incidentId) &&
      !_recentlyDeletedIds.contains(incidentId);

  bool isRecentlyDeletedId(String incidentId) =>
      _recentlyDeletedIds.contains(incidentId);

  DateTime? deletedAtFor(String incidentId) => _deletedAtById[incidentId];

  List<LibraryIncidentSummary> get activeSummaries => [
    for (final summary in summaries)
      if (!summary.isArchived && !summary.isRecentlyDeleted) summary,
  ];

  List<LibraryIncidentSummary> get archivedSummaries => [
    for (final summary in summaries)
      if (summary.isArchived && !summary.isRecentlyDeleted) summary,
  ];

  List<LibraryIncidentSummary> get recentlyDeletedSummaries => [
    for (final summary in summaries)
      if (summary.isRecentlyDeleted) summary,
  ];

  /// Incidents visible on normal Active / Archived / search / count surfaces.
  List<LibraryIncidentSummary> get visibleOperationalSummaries => [
    for (final summary in summaries)
      if (!summary.isRecentlyDeleted) summary,
  ];

  bool get _enabled {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    return FirebaseBootstrap.isAvailable && UserSessionService.isSignedIn;
  }

  /// Reloads [summaries] / [records] from Firestore when online, then always
  /// merges durable local evidence counts by incidentId.
  Future<void> refresh() async {
    await _ensureLifecycleLoaded();
    final userId = UserSessionService.account?.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    _isLoading = true;
    var newSummaries = List<LibraryIncidentSummary>.from(summaries);
    var newRecords = List<LibraryIncidentRecord>.from(records);

    try {
      if (_enabled) {
        final entries = await _repository.listIncidentSummaries(userId);
        newSummaries = <LibraryIncidentSummary>[];
        newRecords = <LibraryIncidentRecord>[];

        for (final entry in entries) {
          final incident = entry.incident;
          if (incident.id.trim().isEmpty) {
            debugPrint('[Library] skipping summary with empty incident id');
            continue;
          }
          final title = incident.title.trim().isEmpty
              ? 'Untitled Incident'
              : incident.title.trim();
          _mergeCloudLifecycle(incident);
          final recentlyDeleted = _recentlyDeletedIds.contains(incident.id);
          final archived =
              _archivedIds.contains(incident.id) && !recentlyDeleted;
          final isInProgress =
              !archived &&
              !recentlyDeleted &&
              _isActiveStatus(incident.status) &&
              !incident.manuallyComplete;

          newSummaries.add(
            LibraryIncidentSummary(
              id: incident.id,
              title: title,
              evidenceCount: entry.evidenceCount,
              contextEnrichedCount: entry.relationshipCount,
              integrityVerified: entry.reconstructionHealth >= 50,
              lastPreserved: _formatLastPreserved(incident.updatedAt),
              narrativeCount: entry.narrativeCount,
              isInProgress: isInProgress,
              isArchived: archived,
              isRecentlyDeleted: recentlyDeleted,
              deletedAt: _deletedAtById[incident.id],
              coverEvidenceId: incident.coverEvidenceId,
              createdAt: incident.createdAt,
              updatedAt: incident.updatedAt,
            ),
          );
          newRecords.add(
            LibraryIncidentRecord(
              id: incident.id,
              title: title,
              preservedAt: incident.updatedAt,
            ),
          );
        }
      }

      await _mergeLocalEvidenceCounts(
        userId: userId,
        summaries: newSummaries,
        records: newRecords,
      );

      summaries = newSummaries;
      records = newRecords;
      await _persistLifecycle();
      await sweepExpiredRecentlyDeleted();
    } catch (error, stack) {
      debugPrint('[Library] refresh failed: $error');
      debugPrint('$stack');
      // Offline / cloud failure — still try to surface local counts.
      try {
        await _mergeLocalEvidenceCounts(
          userId: userId,
          summaries: newSummaries,
          records: newRecords,
        );
        summaries = newSummaries;
        records = newRecords;
      } catch (mergeError) {
        debugPrint('[Library] local merge failed: $mergeError');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Upserts one Library card from local incident state (capture / Workspace).
  ///
  /// Count is for [incidentId] only — never copies another incident's count.
  ///
  /// Never lets a transient empty Workspace shell (`evidenceCount == 0`) wipe a
  /// card that already shows a known positive count. Library → open replaces the
  /// session aggregate with [IncidentAggregate.shell] before hydrate; publishing
  /// that zero would flash "Evidence: 0" on the still-visible Library card.
  /// Downgrades to a non-zero count, and full [refresh] rebuilds, still apply.
  void upsertFromLocal({
    required String incidentId,
    required int evidenceCount,
    String title = '',
    DateTime? updatedAt,
    bool isInProgress = true,
  }) {
    final id = incidentId.trim();
    if (id.isEmpty) {
      return;
    }
    final count = evidenceCount < 0 ? 0 : evidenceCount;
    final display = title.trim().isEmpty ? 'Untitled Incident' : title.trim();
    final preservedAt = updatedAt ?? DateTime.now();
    final lastPreserved = _formatLastPreserved(preservedAt);

    var found = false;
    final nextSummaries = <LibraryIncidentSummary>[];
    for (final s in summaries) {
      if (s.id == id) {
        found = true;
        // Keep last known valid count across empty-shell open transitions.
        final nextCount = (s.evidenceCount > 0 && count == 0)
            ? s.evidenceCount
            : count;
        final recentlyDeleted =
            _recentlyDeletedIds.contains(id) || s.isRecentlyDeleted;
        final archived =
            !recentlyDeleted && (_archivedIds.contains(id) || s.isArchived);
        nextSummaries.add(
          s.copyWith(
            title: display,
            evidenceCount: nextCount,
            lastPreserved: lastPreserved,
            isInProgress: (archived || recentlyDeleted) ? false : isInProgress,
            isArchived: archived,
            isRecentlyDeleted: recentlyDeleted,
            deletedAt: _deletedAtById[id] ?? s.deletedAt,
            createdAt: s.createdAt ?? preservedAt,
            updatedAt: preservedAt,
          ),
        );
      } else {
        nextSummaries.add(s);
      }
    }
    if (!found) {
      final recentlyDeleted = _recentlyDeletedIds.contains(id);
      final archived = !recentlyDeleted && _archivedIds.contains(id);
      nextSummaries.insert(
        0,
        LibraryIncidentSummary(
          id: id,
          title: display,
          evidenceCount: count,
          contextEnrichedCount: 0,
          integrityVerified: false,
          lastPreserved: lastPreserved,
          narrativeCount: 0,
          isInProgress: (archived || recentlyDeleted) ? false : isInProgress,
          isArchived: archived,
          isRecentlyDeleted: recentlyDeleted,
          deletedAt: _deletedAtById[id],
          createdAt: preservedAt,
          updatedAt: preservedAt,
        ),
      );
    }

    var foundRecord = false;
    final nextRecords = <LibraryIncidentRecord>[];
    for (final r in records) {
      if (r.id == id) {
        foundRecord = true;
        nextRecords.add(
          LibraryIncidentRecord(
            id: r.id,
            title: display,
            preservedAt: preservedAt,
            location: r.location,
            organisation: r.organisation,
            referencedPeople: r.referencedPeople,
            evidenceTypes: r.evidenceTypes,
          ),
        );
      } else {
        nextRecords.add(r);
      }
    }
    if (!foundRecord) {
      nextRecords.insert(
        0,
        LibraryIncidentRecord(id: id, title: display, preservedAt: preservedAt),
      );
    }

    summaries = nextSummaries;
    records = nextRecords;
    notifyListeners();
  }

  /// Patches one Library card title by stable [incidentId] — rename isolation.
  void patchTitle(String incidentId, String title) {
    if (incidentId.isEmpty) {
      return;
    }
    final display = title.trim().isEmpty ? 'Untitled Incident' : title.trim();
    var changed = false;
    final nextSummaries = <LibraryIncidentSummary>[];
    for (final s in summaries) {
      if (s.id == incidentId) {
        changed = true;
        nextSummaries.add(s.copyWith(title: display));
      } else {
        nextSummaries.add(s);
      }
    }
    final nextRecords = <LibraryIncidentRecord>[];
    for (final r in records) {
      if (r.id == incidentId) {
        changed = true;
        nextRecords.add(
          LibraryIncidentRecord(
            id: r.id,
            title: display,
            preservedAt: r.preservedAt,
            location: r.location,
            organisation: r.organisation,
            referencedPeople: r.referencedPeople,
            evidenceTypes: r.evidenceTypes,
          ),
        );
      } else {
        nextRecords.add(r);
      }
    }
    if (!changed) {
      return;
    }
    summaries = nextSummaries;
    records = nextRecords;
    notifyListeners();
  }

  /// Replaces cached state directly — used by rollback flows (data deletion).
  void restoreSnapshot({
    required List<LibraryIncidentSummary> summaries,
    required List<LibraryIncidentRecord> records,
  }) {
    this.summaries = summaries;
    this.records = records;
    _archivedIds
      ..clear()
      ..addAll({
        for (final summary in summaries)
          if (summary.isArchived && !summary.isRecentlyDeleted) summary.id,
      });
    _recentlyDeletedIds
      ..clear()
      ..addAll({
        for (final summary in summaries)
          if (summary.isRecentlyDeleted) summary.id,
      });
    _deletedAtById
      ..clear()
      ..addEntries([
        for (final summary in summaries)
          if (summary.isRecentlyDeleted && summary.deletedAt != null)
            MapEntry(summary.id, summary.deletedAt!),
      ]);
    _pendingRestoredIds.clear();
    notifyListeners();
  }

  /// Clears cached state — for sign-out and account/vault deletion flows.
  void clear() {
    summaries = [];
    records = [];
    _archivedIds.clear();
    _pendingRestoredIds.clear();
    _recentlyDeletedIds.clear();
    _deletedAtById.clear();
    notifyListeners();
    unawaited(_persistLifecycle());
  }

  /// Archives the existing incident — same id and data, lifecycle only.
  ///
  /// Returns false when the incident has no meaningful title.
  Future<bool> archiveIncident(String incidentId) async {
    await _ensureLifecycleLoaded();
    final id = incidentId.trim();
    if (id.isEmpty || _recentlyDeletedIds.contains(id)) {
      return false;
    }
    if (_archivedIds.contains(id)) {
      return true;
    }
    LibraryIncidentSummary? summary;
    for (final item in summaries) {
      if (item.id == id) {
        summary = item;
        break;
      }
    }
    if (summary != null && !IncidentTitle.isMeaningful(summary.title)) {
      return false;
    }
    _archivedIds.add(id);
    _pendingRestoredIds.remove(id);
    _applyLifecycleToSummaries();
    notifyListeners();
    await _persistLifecycle();
    await _syncLifecycleToCloud(id, IncidentStatus.archived);
    return true;
  }

  /// Restores the same incident to Active — never duplicates.
  ///
  /// Recently Deleted incidents must use [restoreFromRecentlyDeleted].
  Future<void> restoreIncident(String incidentId) async {
    await _ensureLifecycleLoaded();
    final id = incidentId.trim();
    if (id.isEmpty ||
        _recentlyDeletedIds.contains(id) ||
        !_archivedIds.contains(id)) {
      return;
    }
    _archivedIds.remove(id);
    _pendingRestoredIds.add(id);
    _applyLifecycleToSummaries();
    notifyListeners();
    await _persistLifecycle();
    final synced = await _syncLifecycleToCloud(id, IncidentStatus.active);
    if (synced) {
      _pendingRestoredIds.remove(id);
      await _persistLifecycle();
    }
  }

  /// Active or Archived → Deleted. Archive is not required.
  Future<bool> moveToRecentlyDeleted(
    String incidentId, {
    DateTime? deletedAt,
  }) async {
    await _ensureLifecycleLoaded();
    final id = incidentId.trim();
    if (id.isEmpty) {
      return false;
    }
    if (_recentlyDeletedIds.contains(id)) {
      return true;
    }
    final when = deletedAt ?? DateTime.now().toUtc();
    _archivedIds.remove(id);
    _pendingRestoredIds.remove(id);
    _recentlyDeletedIds.add(id);
    _deletedAtById[id] = when;
    _applyLifecycleToSummaries();
    notifyListeners();
    await _persistLifecycle();
    await _syncLifecycleToCloud(
      id,
      IncidentStatus.recentlyDeleted,
      deletedAt: when,
    );
    return true;
  }

  /// Deleted → Active. Same incident identity — never a copy.
  Future<void> restoreFromRecentlyDeleted(String incidentId) async {
    await _ensureLifecycleLoaded();
    final id = incidentId.trim();
    if (id.isEmpty || !_recentlyDeletedIds.contains(id)) {
      return;
    }
    _recentlyDeletedIds.remove(id);
    _deletedAtById.remove(id);
    _archivedIds.remove(id);
    _pendingRestoredIds.add(id);
    _applyLifecycleToSummaries();
    notifyListeners();
    await _persistLifecycle();
    final synced = await _syncLifecycleToCloud(
      id,
      IncidentStatus.active,
      clearDeletedAt: true,
    );
    if (synced) {
      _pendingRestoredIds.remove(id);
      await _persistLifecycle();
    }
  }

  /// Manual or automatic permanent removal of a Recently Deleted incident.
  Future<IncidentOwnedDeletionResult?> permanentlyDeleteIncident(
    String incidentId, {
    bool requireRecentlyDeleted = true,
  }) async {
    await _ensureLifecycleLoaded();
    final id = incidentId.trim();
    if (id.isEmpty) {
      return null;
    }
    if (requireRecentlyDeleted && !_recentlyDeletedIds.contains(id)) {
      return null;
    }
    IncidentOwnedDeletionResult result;
    try {
      result = await _deletionService.deleteOwnedData(incidentId: id);
    } catch (error) {
      debugPrint('[Library] owned deletion failed: $error');
      result = IncidentOwnedDeletionResult(
        incidentId: id,
        localEvidenceIds: const [],
        removedArchiveIds: const [],
      );
    }
    _archivedIds.remove(id);
    _pendingRestoredIds.remove(id);
    _recentlyDeletedIds.remove(id);
    _deletedAtById.remove(id);
    summaries = [
      for (final summary in summaries)
        if (summary.id != id) summary,
    ];
    records = [
      for (final record in records)
        if (record.id != id) record,
    ];
    notifyListeners();
    await _persistLifecycle();
    return result;
  }

  /// Enforces the 30-day rule from persisted deletion timestamps.
  ///
  /// Called from [refresh], not from merely opening a UI surface.
  Future<List<String>> sweepExpiredRecentlyDeleted({DateTime? now}) async {
    await _ensureLifecycleLoaded();
    final clock = now ?? DateTime.now();
    final expired = [
      for (final id in _recentlyDeletedIds)
        if ((_deletedAtById[id] != null) &&
            IncidentDeletionLifecycle.isEligibleForPermanentDeletion(
              deletedAt: _deletedAtById[id]!,
              now: clock,
            ))
          id,
    ];
    for (final id in expired) {
      await permanentlyDeleteIncident(id);
    }
    return expired;
  }

  /// Merges LocalEvidenceCache counts into [summaries] by incidentId.
  Future<void> _mergeLocalEvidenceCounts({
    required String userId,
    required List<LibraryIncidentSummary> summaries,
    required List<LibraryIncidentRecord> records,
  }) async {
    final all = await LocalEvidenceCache.all();
    final counts = <String, int>{};
    final latest = <String, DateTime>{};
    for (final entry in all) {
      if (entry.incidentId.isEmpty) {
        continue;
      }
      if (entry.userId.isNotEmpty &&
          userId.isNotEmpty &&
          entry.userId != userId) {
        continue;
      }
      counts[entry.incidentId] = (counts[entry.incidentId] ?? 0) + 1;
      final prev = latest[entry.incidentId];
      if (prev == null || entry.capturedAt.isAfter(prev)) {
        latest[entry.incidentId] = entry.capturedAt;
      }
    }
    if (counts.isEmpty) {
      return;
    }

    final byId = {for (final s in summaries) s.id: s};
    for (final entry in counts.entries) {
      final id = entry.key;
      final localCount = entry.value;
      final existing = byId[id];
      if (existing != null) {
        final merged = math.max(existing.evidenceCount, localCount);
        if (merged != existing.evidenceCount) {
          final idx = summaries.indexWhere((s) => s.id == id);
          if (idx != -1) {
            summaries[idx] = existing.copyWith(
              evidenceCount: merged,
              updatedAt: existing.updatedAt ?? latest[id],
            );
          }
        }
      } else {
        // Local-only incident (e.g. first Capture Now while offline).
        final when = latest[id] ?? DateTime.now();
        final recentlyDeleted = _recentlyDeletedIds.contains(id);
        final archived = !recentlyDeleted && _archivedIds.contains(id);
        summaries.insert(
          0,
          LibraryIncidentSummary(
            id: id,
            title: 'Untitled Incident',
            evidenceCount: localCount,
            contextEnrichedCount: 0,
            integrityVerified: false,
            lastPreserved: _formatLastPreserved(when),
            narrativeCount: 0,
            isInProgress: !archived && !recentlyDeleted,
            isArchived: archived,
            isRecentlyDeleted: recentlyDeleted,
            deletedAt: _deletedAtById[id],
            createdAt: when,
            updatedAt: when,
          ),
        );
        records.insert(
          0,
          LibraryIncidentRecord(
            id: id,
            title: 'Untitled Incident',
            preservedAt: when,
          ),
        );
      }
    }
  }

  void _mergeCloudLifecycle(Incident incident) {
    if (incident.status == IncidentStatus.recentlyDeleted) {
      _recentlyDeletedIds.add(incident.id);
      _archivedIds.remove(incident.id);
      if (incident.deletedAt != null) {
        _deletedAtById[incident.id] = incident.deletedAt!.toUtc();
      } else {
        _deletedAtById.putIfAbsent(incident.id, () => DateTime.now().toUtc());
      }
      return;
    }
    if (incident.status == IncidentStatus.archived) {
      if (_recentlyDeletedIds.contains(incident.id)) {
        return;
      }
      if (!_pendingRestoredIds.contains(incident.id)) {
        _archivedIds.add(incident.id);
      }
      return;
    }
    if (_recentlyDeletedIds.contains(incident.id)) {
      return;
    }
    if (!_archivedIds.contains(incident.id)) {
      return;
    }
    // Cloud still active — keep a local archive that has not synced yet.
  }

  void _applyLifecycleToSummaries() {
    summaries = [
      for (final summary in summaries)
        summary.copyWith(
          isRecentlyDeleted: _recentlyDeletedIds.contains(summary.id),
          isArchived:
              _archivedIds.contains(summary.id) &&
              !_recentlyDeletedIds.contains(summary.id),
          isInProgress:
              (_archivedIds.contains(summary.id) ||
                  _recentlyDeletedIds.contains(summary.id))
              ? false
              : summary.isInProgress,
          deletedAt: _deletedAtById[summary.id],
          clearDeletedAt: !_recentlyDeletedIds.contains(summary.id),
        ),
    ];
  }

  /// Test seam — production always persists to disk.
  @visibleForTesting
  static bool debugForceDiskPersist = false;

  bool get _persistLifecycleToDisk {
    if (debugForceDiskPersist) {
      return true;
    }
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    return true;
  }

  Future<void> _ensureLifecycleLoaded() async {
    if (_lifecycleLoaded) {
      return;
    }
    _lifecycleLoaded = true;
    if (!_persistLifecycleToDisk) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _archivedIds.addAll(prefs.getStringList(_archivedIdsKey) ?? const []);
      _pendingRestoredIds.addAll(
        prefs.getStringList(_pendingRestoredKey) ?? const [],
      );
      _recentlyDeletedIds.addAll(
        prefs.getStringList(_recentlyDeletedIdsKey) ?? const [],
      );
      final rawDeletedAt = prefs.getString(_deletedAtKey);
      if (rawDeletedAt != null && rawDeletedAt.isNotEmpty) {
        final decoded = jsonDecode(rawDeletedAt);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final when = DateTime.tryParse('$value');
            if (key is String && key.isNotEmpty && when != null) {
              _deletedAtById[key] = when.toUtc();
            }
          });
        }
      }
    } catch (error) {
      debugPrint('[Library] lifecycle prefs load skipped: $error');
    }
  }

  Future<void> _persistLifecycle() async {
    if (!_persistLifecycleToDisk) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_archivedIdsKey, _archivedIds.toList());
      await prefs.setStringList(
        _pendingRestoredKey,
        _pendingRestoredIds.toList(),
      );
      await prefs.setStringList(
        _recentlyDeletedIdsKey,
        _recentlyDeletedIds.toList(),
      );
      await prefs.setString(
        _deletedAtKey,
        jsonEncode({
          for (final entry in _deletedAtById.entries)
            entry.key: entry.value.toUtc().toIso8601String(),
        }),
      );
    } catch (error) {
      debugPrint('[Library] lifecycle prefs save skipped: $error');
    }
  }

  Future<bool> _syncLifecycleToCloud(
    String incidentId,
    IncidentStatus status, {
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) async {
    if (!_enabled) {
      return false;
    }
    final userId = UserSessionService.account?.userId;
    if (userId == null || userId.isEmpty) {
      return false;
    }
    LibraryIncidentSummary? summary;
    for (final item in summaries) {
      if (item.id == incidentId) {
        summary = item;
        break;
      }
    }
    if (summary == null) {
      return false;
    }
    try {
      final now = DateTime.now();
      await _repository.patchIncidentIdentity(
        userId: userId,
        incident: Incident(
          id: summary.id,
          title: summary.title,
          status: status,
          createdAt: summary.createdAt ?? now,
          updatedAt: now,
          deletedAt: clearDeletedAt
              ? null
              : (deletedAt ?? _deletedAtById[incidentId]),
        ),
      );
      return true;
    } catch (error) {
      debugPrint('[Library] lifecycle cloud sync skipped: $error');
      return false;
    }
  }

  static bool _isActiveStatus(IncidentStatus status) =>
      status == IncidentStatus.draft || status == IncidentStatus.active;

  static String _formatLastPreserved(DateTime updatedAt) {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    }
    final isToday =
        now.year == updatedAt.year &&
        now.month == updatedAt.month &&
        now.day == updatedAt.day;
    if (isToday) {
      return 'Today • ${DateFormat.jm().format(updatedAt)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        yesterday.year == updatedAt.year &&
        yesterday.month == updatedAt.month &&
        yesterday.day == updatedAt.day;
    if (isYesterday) {
      return 'Yesterday • ${DateFormat.jm().format(updatedAt)}';
    }
    return DateFormat('MMM d • h:mm a').format(updatedAt);
  }
}
