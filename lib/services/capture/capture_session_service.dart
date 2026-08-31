import 'package:flutter/foundation.dart';

import '../../domain/capture/capture_session.dart';
import 'capture_session_manager.dart';

/// Compatibility facade over [CaptureSessionManager] (Sprint 6C Task 1 API).
///
/// Prefer [CaptureSessionManager] for pause / resume / complete / archive.
class CaptureSessionService {
  CaptureSessionService._();

  static final CaptureSessionService instance = CaptureSessionService._();

  CaptureSession? activeSessionFor(String incidentId) =>
      CaptureSessionManager.instance.getActiveSession(incidentId);

  String? activeSessionIdFor(String incidentId) =>
      activeSessionFor(incidentId)?.id;

  Future<CaptureSession> ensureActive({
    required String incidentId,
    String? userId,
  }) =>
      CaptureSessionManager.instance.getOrCreateActiveSession(
        incidentId: incidentId,
        userId: userId,
      );

  Future<CaptureSession?> attachEvidence({
    required String sessionId,
    required String evidenceId,
  }) =>
      CaptureSessionManager.instance.attachEvidenceToSession(
        sessionId: sessionId,
        evidenceId: evidenceId,
      );

  Future<CaptureSession?> restoreForIncident({
    required String incidentId,
    String? userId,
  }) =>
      CaptureSessionManager.instance.restoreForIncident(
        incidentId: incidentId,
        userId: userId,
      );

  void clearMemory() {
    CaptureSessionManager.instance.clearMemory();
  }

  @visibleForTesting
  Future<void> resetForTests() async {
    clearMemory();
  }
}
