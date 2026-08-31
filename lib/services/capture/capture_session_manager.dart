import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/capture/capture_session.dart';
import '../../domain/capture/capture_session_status.dart';
import '../../domain/capture/capture_session_summary.dart';
import '../../domain/evidence/evidence_record_type.dart';
import '../persistence/local_capture_session_store.dart';
import '../persistence/local_incident_pointer.dart';
import '../storage/local_evidence_cache.dart';
import '../user_session_service.dart';

/// Manages the currently active evidence collection session (Sprint 6C Task 2).
///
/// Users never create sessions manually — [getOrCreateActiveSession] runs from
/// [CaptureEngine] when capture begins. Persistence uses
/// [LocalCaptureSessionStore] (same evidence_cache root; no second database).
class CaptureSessionManager {
  CaptureSessionManager._();

  static final CaptureSessionManager instance = CaptureSessionManager._();

  static const _uuid = Uuid();

  /// In-memory pointer to the open session for an incident (ACTIVE or PAUSED).
  final Map<String, CaptureSession> _openByIncident = {};

  CaptureSession? getActiveSession(String incidentId) {
    if (incidentId.isEmpty) {
      return null;
    }
    final session = _openByIncident[incidentId];
    if (session == null || session.status != CaptureSessionStatus.active) {
      return null;
    }
    return session;
  }

  CaptureSession? getOpenSession(String incidentId) {
    if (incidentId.isEmpty) {
      return null;
    }
    return _openByIncident[incidentId];
  }

  /// Starts a session when none is ACTIVE — otherwise returns the active one.
  Future<CaptureSession> startSession({
    required String incidentId,
    String? userId,
  }) =>
      getOrCreateActiveSession(incidentId: incidentId, userId: userId);

  /// Rule 1–2: reuse ACTIVE session, else create a new ACTIVE session.
  ///
  /// Paused / completed / archived sessions are not reused for new capture.
  Future<CaptureSession> getOrCreateActiveSession({
    required String incidentId,
    String? userId,
  }) async {
    final resolvedUser = _resolveUserId(userId);
    if (incidentId.isEmpty) {
      throw ArgumentError('incidentId must not be empty');
    }

    final cached = getActiveSession(incidentId);
    if (cached != null && _userMatches(cached, resolvedUser)) {
      return cached;
    }

    final existing = await LocalCaptureSessionStore.activeForIncident(
      incidentId,
      userId: resolvedUser.isEmpty ? null : resolvedUser,
    );
    if (existing != null) {
      _openByIncident[incidentId] = existing;
      await _rememberPointer(
        userId: resolvedUser,
        incidentId: incidentId,
        captureSessionId: existing.id,
      );
      debugPrint(
        '[CaptureSessionManager] restored active=${existing.id} '
        'incident=$incidentId',
      );
      return existing;
    }

    return _createActiveSession(
      incidentId: incidentId,
      userId: resolvedUser,
    );
  }

  /// Appends evidence to [sessionId]. Only ACTIVE sessions accept evidence.
  Future<CaptureSession?> attachEvidenceToSession({
    required String sessionId,
    required String evidenceId,
  }) async {
    if (sessionId.isEmpty || evidenceId.isEmpty) {
      return null;
    }
    final current = await LocalCaptureSessionStore.byId(sessionId);
    if (current == null) {
      return null;
    }
    if (current.status == CaptureSessionStatus.completed ||
        current.status == CaptureSessionStatus.archived) {
      debugPrint(
        '[CaptureSessionManager] refuse attach to ${current.status.wireName} '
        'session=$sessionId',
      );
      return null;
    }
    if (current.status == CaptureSessionStatus.paused) {
      debugPrint(
        '[CaptureSessionManager] refuse attach to paused session=$sessionId '
        '(resume first)',
      );
      return null;
    }
    if (current.evidenceIds.contains(evidenceId)) {
      _openByIncident[current.incidentId] = current;
      return current;
    }
    final next = current.copyWith(
      evidenceIds: [...current.evidenceIds, evidenceId],
      updatedAt: DateTime.now(),
    );
    await LocalCaptureSessionStore.upsert(next);
    _openByIncident[next.incidentId] = next;
    await _rememberPointer(
      userId: next.userId,
      incidentId: next.incidentId,
      captureSessionId: next.id,
    );
    return next;
  }

  Future<CaptureSession?> pauseSession({
    required String sessionId,
  }) async {
    final current = await _requireSession(sessionId);
    if (current == null) {
      return null;
    }
    if (current.status != CaptureSessionStatus.active) {
      return current;
    }
    final next = current.copyWith(
      status: CaptureSessionStatus.paused,
      updatedAt: DateTime.now(),
    );
    await LocalCaptureSessionStore.upsert(next);
    _openByIncident[next.incidentId] = next;
    await _rememberPointer(
      userId: next.userId,
      incidentId: next.incidentId,
      captureSessionId: next.id,
    );
    debugPrint('[CaptureSessionManager] paused session=${next.id}');
    return next;
  }

  Future<CaptureSession?> resumeSession({
    required String sessionId,
  }) async {
    final current = await _requireSession(sessionId);
    if (current == null) {
      return null;
    }
    if (current.status != CaptureSessionStatus.paused) {
      if (current.status == CaptureSessionStatus.active) {
        _openByIncident[current.incidentId] = current;
        return current;
      }
      debugPrint(
        '[CaptureSessionManager] cannot resume ${current.status.wireName} '
        'session=$sessionId',
      );
      return null;
    }

    // Only one ACTIVE session per incident — complete any other active.
    final active = await LocalCaptureSessionStore.activeForIncident(
      current.incidentId,
      userId: current.userId.isEmpty ? null : current.userId,
    );
    if (active != null && active.id != current.id) {
      await completeSession(sessionId: active.id);
    }

    final next = current.copyWith(
      status: CaptureSessionStatus.active,
      clearEndedAt: true,
      updatedAt: DateTime.now(),
    );
    await LocalCaptureSessionStore.upsert(next);
    _openByIncident[next.incidentId] = next;
    await _rememberPointer(
      userId: next.userId,
      incidentId: next.incidentId,
      captureSessionId: next.id,
    );
    debugPrint('[CaptureSessionManager] resumed session=${next.id}');
    return next;
  }

  Future<CaptureSession?> completeSession({
    required String sessionId,
  }) async {
    final current = await _requireSession(sessionId);
    if (current == null) {
      return null;
    }
    if (current.status == CaptureSessionStatus.completed ||
        current.status == CaptureSessionStatus.archived) {
      return current;
    }
    final now = DateTime.now();
    final next = current.copyWith(
      status: CaptureSessionStatus.completed,
      endedAt: now,
      updatedAt: now,
    );
    await LocalCaptureSessionStore.upsert(next);
    if (_openByIncident[next.incidentId]?.id == next.id) {
      _openByIncident.remove(next.incidentId);
    }
    await _rememberPointer(
      userId: next.userId,
      incidentId: next.incidentId,
      captureSessionId: next.id,
    );
    debugPrint('[CaptureSessionManager] completed session=${next.id}');
    return next;
  }

  Future<CaptureSession?> archiveSession({
    required String sessionId,
  }) async {
    final current = await _requireSession(sessionId);
    if (current == null) {
      return null;
    }
    if (current.status == CaptureSessionStatus.archived) {
      return current;
    }
    final now = DateTime.now();
    final next = current.copyWith(
      status: CaptureSessionStatus.archived,
      endedAt: current.endedAt ?? now,
      updatedAt: now,
    );
    await LocalCaptureSessionStore.upsert(next);
    if (_openByIncident[next.incidentId]?.id == next.id) {
      _openByIncident.remove(next.incidentId);
    }
    await _rememberPointer(
      userId: next.userId,
      incidentId: next.incidentId,
      captureSessionId: next.id,
    );
    debugPrint('[CaptureSessionManager] archived session=${next.id}');
    return next;
  }

  /// Restores ACTIVE (preferred) or PAUSED session for restart / login.
  Future<CaptureSession?> restoreForIncident({
    required String incidentId,
    String? userId,
  }) async {
    if (incidentId.isEmpty) {
      return null;
    }
    final resolvedUser = _resolveUserId(userId);

    final active = await LocalCaptureSessionStore.activeForIncident(
      incidentId,
      userId: resolvedUser.isEmpty ? null : resolvedUser,
    );
    if (active != null) {
      _openByIncident[incidentId] = active;
      await _rememberPointer(
        userId: resolvedUser,
        incidentId: incidentId,
        captureSessionId: active.id,
      );
      debugPrint(
        '[CaptureSessionManager] hydrate active=${active.id} '
        'evidence=${active.evidenceIds.length} incident=$incidentId',
      );
      return active;
    }

    final rememberedId = resolvedUser.isEmpty
        ? null
        : await LocalIncidentPointer.recallCaptureSession(resolvedUser);
    if (rememberedId != null && rememberedId.isNotEmpty) {
      final remembered = await LocalCaptureSessionStore.byId(rememberedId);
      if (remembered != null &&
          remembered.incidentId == incidentId &&
          (remembered.status == CaptureSessionStatus.active ||
              remembered.status == CaptureSessionStatus.paused) &&
          _userMatches(remembered, resolvedUser)) {
        _openByIncident[incidentId] = remembered;
        debugPrint(
          '[CaptureSessionManager] hydrate remembered=${remembered.id} '
          'status=${remembered.status.wireName} incident=$incidentId',
        );
        return remembered;
      }
    }

    final sessions = await LocalCaptureSessionStore.forIncident(
      incidentId,
      userId: resolvedUser.isEmpty ? null : resolvedUser,
    );
    for (final session in sessions) {
      if (session.status == CaptureSessionStatus.paused) {
        _openByIncident[incidentId] = session;
        debugPrint(
          '[CaptureSessionManager] hydrate paused=${session.id} '
          'incident=$incidentId',
        );
        return session;
      }
    }

    _openByIncident.remove(incidentId);
    return null;
  }

  Future<CaptureSessionSummary?> summarize({
    required String sessionId,
  }) async {
    final session = await LocalCaptureSessionStore.byId(sessionId);
    if (session == null) {
      return null;
    }
    var photo = 0;
    var video = 0;
    var voice = 0;
    var note = 0;
    var file = 0;
    for (final evidenceId in session.evidenceIds) {
      final entry = await LocalEvidenceCache.byId(evidenceId);
      switch (entry?.evidenceType) {
        case EvidenceRecordType.photo:
          photo += 1;
          break;
        case EvidenceRecordType.video:
          video += 1;
          break;
        case EvidenceRecordType.voice:
          voice += 1;
          break;
        case EvidenceRecordType.note:
          note += 1;
          break;
        case EvidenceRecordType.document:
        case EvidenceRecordType.witness:
        case EvidenceRecordType.other:
          file += 1;
          break;
        case null:
          break;
      }
    }
    return CaptureSessionSummary.fromSession(
      session,
      photoCount: photo,
      videoCount: video,
      voiceCount: voice,
      noteCount: note,
      fileCount: file,
    );
  }

  void clearMemory() {
    _openByIncident.clear();
  }

  @visibleForTesting
  Future<void> resetForTests() async {
    clearMemory();
  }

  Future<CaptureSession> _createActiveSession({
    required String incidentId,
    required String userId,
  }) async {
    final now = DateTime.now();
    final session = CaptureSession(
      id: 'cs-${_uuid.v4()}',
      incidentId: incidentId,
      userId: userId,
      startedAt: now,
      status: CaptureSessionStatus.active,
      evidenceIds: const [],
      createdAt: now,
      updatedAt: now,
    );
    await LocalCaptureSessionStore.upsert(session);
    _openByIncident[incidentId] = session;
    await _rememberPointer(
      userId: userId,
      incidentId: incidentId,
      captureSessionId: session.id,
    );
    debugPrint(
      '[CaptureSessionManager] started session=${session.id} '
      'incident=$incidentId',
    );
    return session;
  }

  Future<CaptureSession?> _requireSession(String sessionId) async {
    if (sessionId.isEmpty) {
      return null;
    }
    return LocalCaptureSessionStore.byId(sessionId);
  }

  String _resolveUserId(String? userId) =>
      (userId ?? UserSessionService.account?.userId ?? '').trim();

  bool _userMatches(CaptureSession session, String userId) {
    if (userId.isEmpty || session.userId.isEmpty) {
      return true;
    }
    return session.userId == userId;
  }

  Future<void> _rememberPointer({
    required String userId,
    required String incidentId,
    required String captureSessionId,
  }) async {
    if (userId.isEmpty || incidentId.isEmpty) {
      return;
    }
    await LocalIncidentPointer.remember(
      userId: userId,
      incidentId: incidentId,
      captureSessionId: captureSessionId,
    );
  }
}
