import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/capture/capture_session.dart';
import '../../domain/capture/capture_session_status.dart';

/// Durable local [CaptureSession] index (Sprint 6C).
///
/// Lives beside [LocalEvidenceCache] under `evidence_cache/` — same documents
/// root, no second database. Survives restart, force-close, logout, and offline.
abstract final class LocalCaptureSessionStore {
  static const String _indexFileName = 'capture_sessions_index.json';

  static final Map<String, CaptureSession> _index = {};
  static bool _indexLoaded = false;

  @visibleForTesting
  static void resetForTests() {
    _index.clear();
    _indexLoaded = false;
  }

  static Future<Directory> _ensureRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'evidence_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _indexFile() async {
    final root = await _ensureRoot();
    return File(p.join(root.path, _indexFileName));
  }

  static Future<void> _ensureIndexLoaded() async {
    if (_indexLoaded || kIsWeb) {
      _indexLoaded = true;
      return;
    }
    try {
      final file = await _indexFile();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        _index.clear();
        if (decoded is List) {
          for (final raw in decoded) {
            if (raw is Map<String, dynamic>) {
              final session = CaptureSession.fromJson(raw);
              if (session.id.isNotEmpty) {
                _index[session.id] = session;
              }
            } else if (raw is Map) {
              final session = CaptureSession.fromJson(
                Map<String, dynamic>.from(raw),
              );
              if (session.id.isNotEmpty) {
                _index[session.id] = session;
              }
            }
          }
        }
      }
    } catch (error) {
      debugPrint('[LocalCaptureSessionStore] index load failed: $error');
    }
    _indexLoaded = true;
  }

  static Future<void> _persistIndex() async {
    if (kIsWeb) {
      return;
    }
    try {
      final file = await _indexFile();
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      final payload = [
        for (final session in _index.values) session.toJson(),
      ];
      await file.writeAsString(jsonEncode(payload));
    } catch (error) {
      debugPrint('[LocalCaptureSessionStore] index persist failed: $error');
    }
  }

  static Future<void> upsert(CaptureSession session) async {
    if (session.id.isEmpty) {
      return;
    }
    await _ensureIndexLoaded();
    _index[session.id] = session;
    await _persistIndex();
  }

  static Future<CaptureSession?> byId(String sessionId) async {
    if (sessionId.isEmpty) {
      return null;
    }
    await _ensureIndexLoaded();
    return _index[sessionId];
  }

  static Future<List<CaptureSession>> forIncident(
    String incidentId, {
    String? userId,
  }) async {
    if (incidentId.isEmpty) {
      return const [];
    }
    await _ensureIndexLoaded();
    final rows = _index.values.where((session) {
      if (session.incidentId != incidentId) {
        return false;
      }
      if (userId != null &&
          userId.isNotEmpty &&
          session.userId.isNotEmpty &&
          session.userId != userId) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return rows;
  }

  /// Most recent ACTIVE session for [incidentId] (and optional [userId]).
  static Future<CaptureSession?> activeForIncident(
    String incidentId, {
    String? userId,
  }) async {
    final sessions = await forIncident(incidentId, userId: userId);
    for (final session in sessions) {
      if (session.status == CaptureSessionStatus.active) {
        return session;
      }
    }
    return null;
  }

  static Future<List<CaptureSession>> all() async {
    await _ensureIndexLoaded();
    return List<CaptureSession>.unmodifiable(_index.values);
  }

  /// Removes durable capture sessions owned by [incidentId] only.
  static Future<void> removeForIncident(String incidentId) async {
    final id = incidentId.trim();
    if (id.isEmpty) {
      return;
    }
    await _ensureIndexLoaded();
    final owned = [
      for (final session in _index.values)
        if (session.incidentId == id) session.id,
    ];
    for (final sessionId in owned) {
      _index.remove(sessionId);
    }
    if (owned.isNotEmpty) {
      await _persistIndex();
    }
  }

  /// Clears every durable capture session (Clear Vault).
  static Future<void> clearAll() async {
    await _ensureIndexLoaded();
    _index.clear();
    await _persistIndex();
    debugPrint('[LocalCaptureSessionStore] clearAll');
  }
}
