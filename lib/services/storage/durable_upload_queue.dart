import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/workspace_capture_mode.dart';
import 'evidence_upload_queue.dart';

/// Disk-backed store for [QueuedEvidenceUpload] entries (Sprint 4D).
///
/// **Phase 2(B)-1 — quarantined.** Production upload retry ownership moved to
/// [EvidenceSyncQueue] / [EvidenceSyncManager]. This class is retained so
/// leftover `durable_upload_queue_v1` rows can be wiped on Clear Vault /
/// account deletion. Do not enqueue live retries here. File deletion is a
/// later cleanup phase.
///
/// [EvidenceUploadQueue] is the in-memory façade over this store.
class DurableUploadQueue {
  DurableUploadQueue({SharedPreferences? preferences})
      : _preferencesOverride = preferences;

  static const String storageKey = 'durable_upload_queue_v1';
  static const String _storageKey = storageKey;

  SharedPreferences? _preferencesOverride;
  final List<QueuedEvidenceUpload> _items = [];

  UnmodifiableListView<QueuedEvidenceUpload> get items =>
      UnmodifiableListView(_items);

  bool get hasPending => _items.isNotEmpty;

  Future<SharedPreferences> get _preferences async =>
      _preferencesOverride ??= await SharedPreferences.getInstance();

  /// Reads the persisted queue from disk into memory. Safe to call repeatedly.
  Future<void> load() async {
    try {
      final prefs = await _preferences;
      final raw = prefs.getString(_storageKey);
      _items.clear();
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      _items.addAll(
        decoded.whereType<Map<String, dynamic>>().map(_fromJson),
      );
    } catch (error) {
      debugPrint('[DurableUploadQueue] load failed: $error');
    }
  }

  /// Writes the current in-memory queue to disk.
  Future<void> save() async {
    try {
      final prefs = await _preferences;
      await prefs.setString(
        _storageKey,
        jsonEncode([for (final item in _items) _toJson(item)]),
      );
    } catch (error) {
      // Unit tests may call enqueue before WidgetsFlutterBinding is ready.
      if (kDebugMode &&
          !error.toString().contains('Binding has not yet been initialized')) {
        debugPrint('[DurableUploadQueue] save failed: $error');
      }
    }
  }

  Future<void> enqueue(QueuedEvidenceUpload item) async {
    _items.removeWhere((entry) => entry.evidenceId == item.evidenceId);
    _items.add(item);
    await save();
  }

  Future<void> remove(String evidenceId) async {
    final before = _items.length;
    _items.removeWhere((entry) => entry.evidenceId == evidenceId);
    if (_items.length != before) {
      await save();
    }
  }

  /// Drops in-memory and persisted leftover retry rows (Clear Vault).
  Future<void> clear() async {
    _items.clear();
    try {
      final prefs = await _preferences;
      await prefs.remove(_storageKey);
    } catch (error) {
      if (kDebugMode &&
          !error.toString().contains('Binding has not yet been initialized')) {
        debugPrint('[DurableUploadQueue] clear failed: $error');
      }
    }
  }

  static Map<String, dynamic> _toJson(QueuedEvidenceUpload item) => {
        'evidenceId': item.evidenceId,
        'incidentId': item.incidentId,
        'userId': item.userId,
        'localFilePath': item.localFilePath,
        'mode': item.mode.name,
        'intendedStoragePath': item.intendedStoragePath,
        'deviceModel': item.deviceModel,
        'latitude': item.latitude,
        'longitude': item.longitude,
        'captureTime': item.captureTime?.toIso8601String(),
      };

  static QueuedEvidenceUpload _fromJson(Map<String, dynamic> json) {
    return buildQueuedEvidenceUpload(
      evidenceId: json['evidenceId'] as String? ?? '',
      incidentId: json['incidentId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      localFilePath: json['localFilePath'] as String? ?? '',
      mode: WorkspaceCaptureMode.values.firstWhere(
        (value) => value.name == json['mode'],
        orElse: () => WorkspaceCaptureMode.file,
      ),
      intendedStoragePath: json['intendedStoragePath'] as String? ?? '',
      deviceModel: json['deviceModel'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      captureTime: json['captureTime'] is String
          ? DateTime.tryParse(json['captureTime'] as String)
          : null,
    );
  }
}
