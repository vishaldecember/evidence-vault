import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../models/workspace_capture_mode.dart';
import 'durable_upload_queue.dart';
import 'evidence_upload_models.dart';

/// Locally queued failed (or pending) Firebase Storage uploads.
///
/// Evidence stays in the incident store; this queue only tracks retry work.
/// Backed by [DurableUploadQueue] (Sprint 4D) so retryable uploads survive an
/// app restart — enqueue / remove persist automatically.
class EvidenceUploadQueue extends ChangeNotifier {
  EvidenceUploadQueue({DurableUploadQueue? durable})
      : _durable = durable ?? DurableUploadQueue();

  final DurableUploadQueue _durable;
  final List<QueuedEvidenceUpload> _items = [];
  bool _loaded = false;

  UnmodifiableListView<QueuedEvidenceUpload> get items =>
      UnmodifiableListView(_items);

  bool get hasPending => _items.isNotEmpty;

  /// Loads any durably persisted queue entries. Safe to call multiple times.
  Future<void> restore() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    await _durable.load();
    _items
      ..clear()
      ..addAll(_durable.items);
    notifyListeners();
  }

  void enqueue(QueuedEvidenceUpload item) {
    _items.removeWhere((entry) => entry.evidenceId == item.evidenceId);
    _items.add(item);
    StorageUploadLog.queued(item.evidenceId, item.intendedStoragePath);
    notifyListeners();
    unawaited(_durable.enqueue(item));
  }

  QueuedEvidenceUpload? takeNext() {
    if (_items.isEmpty) {
      return null;
    }
    final next = _items.removeAt(0);
    notifyListeners();
    unawaited(_durable.remove(next.evidenceId));
    return next;
  }

  void remove(String evidenceId) {
    final before = _items.length;
    _items.removeWhere((entry) => entry.evidenceId == evidenceId);
    if (_items.length != before) {
      notifyListeners();
      unawaited(_durable.remove(evidenceId));
    }
  }

  QueuedEvidenceUpload? byEvidenceId(String evidenceId) {
    for (final item in _items) {
      if (item.evidenceId == evidenceId) {
        return item;
      }
    }
    return null;
  }

  /// Durably persists the current queue snapshot. Retained for callers that
  /// still expect an explicit flush point (retry survival is automatic now).
  Future<void> persist() => _durable.save();
}

/// One failed upload retained for retry — local file path is never discarded.
class QueuedEvidenceUpload {
  const QueuedEvidenceUpload({
    required this.evidenceId,
    required this.incidentId,
    required this.localFilePath,
    required this.mode,
    required this.intendedStoragePath,
    this.userId = '',
    this.deviceModel,
    this.latitude,
    this.longitude,
    this.captureTime,
  });

  final String evidenceId;
  final String incidentId;

  /// Authenticated user who queued this upload. Identity is immutable.
  final String userId;
  final String localFilePath;
  final WorkspaceCaptureMode mode;
  final String intendedStoragePath;
  final String? deviceModel;
  final double? latitude;
  final double? longitude;
  final DateTime? captureTime;

  bool isOwnedBy(String currentUserId) {
    return userId.isNotEmpty &&
        currentUserId.isNotEmpty &&
        userId == currentUserId;
  }
}

QueuedEvidenceUpload buildQueuedEvidenceUpload({
  required String evidenceId,
  required String incidentId,
  required String localFilePath,
  required WorkspaceCaptureMode mode,
  required String intendedStoragePath,
  String userId = '',
  String? deviceModel,
  double? latitude,
  double? longitude,
  DateTime? captureTime,
}) {
  return QueuedEvidenceUpload(
    evidenceId: evidenceId,
    incidentId: incidentId,
    userId: userId,
    localFilePath: localFilePath,
    mode: mode,
    intendedStoragePath: intendedStoragePath,
    deviceModel: deviceModel,
    latitude: latitude,
    longitude: longitude,
    captureTime: captureTime,
  );
}
