import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the last capture incident per authenticated user, plus
/// per-incident titles keyed by [userId] + [incidentId].
///
/// Sprint 6C Task 8B — title integrity:
/// - Title storage is ALWAYS `ev_incident_title_v1_${userId}_${incidentId}`.
/// - There is NO safe user-scoped "last title" that may become a new incident's
///   title. Legacy `ev_last_capture_title_v1_$userId` is ignored and purged.
/// - Renaming A never changes B or C.
/// - Empty hydration must not wipe a valid incident title.
/// - Explicit clear uses [clearTitleForIncident] only.
abstract final class LocalIncidentPointer {
  static const _keyPrefix = 'ev_last_capture_incident_v1_';
  /// Legacy user-scoped title — UNSAFE. Never read for assignment; purged on use.
  static const _legacyTitlePrefix = 'ev_last_capture_title_v1_';
  static const _incidentTitlePrefix = 'ev_incident_title_v1_';
  static const _sessionPrefix = 'ev_last_capture_session_v1_';

  /// Bumped by [clearAllForUser] so in-flight [remember] / [rememberTitle]
  /// cannot rewrite prefs after Clear Vault.
  static int _writeEpoch = 0;

  @visibleForTesting
  static int get writeEpoch => _writeEpoch;

  static String _key(String userId) => '$_keyPrefix$userId';

  static String _legacyTitleKey(String userId) => '$_legacyTitlePrefix$userId';

  static String _incidentTitleKey(String userId, String incidentId) =>
      '$_incidentTitlePrefix${userId}_$incidentId';

  static String _sessionKey(String userId) => '$_sessionPrefix$userId';

  /// Persists a non-empty [title] for exactly one incident.
  ///
  /// Empty/whitespace titles are ignored — use [clearTitleForIncident] for an
  /// explicit user clear. Never writes into another incident's key. Never
  /// writes a user-scoped "last title".
  static Future<void> rememberTitle({
    required String userId,
    required String incidentId,
    required String title,
  }) async {
    if (userId.isEmpty || incidentId.isEmpty) {
      return;
    }
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final epoch = _writeEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (epoch != _writeEpoch) {
        debugPrint(
          '[Recovery] rememberTitle dropped (vault cleared) incident=$incidentId',
        );
        return;
      }
      await _purgeLegacyTitle(prefs, userId);
      if (epoch != _writeEpoch) {
        return;
      }
      await prefs.setString(
        _incidentTitleKey(userId, incidentId),
        trimmed,
      );
      debugPrint(
        '[Recovery] rememberTitle incident=$incidentId '
        'title=$trimmed for user=$userId',
      );
    } catch (error) {
      debugPrint('[Recovery] rememberTitle failed: $error');
    }
  }

  /// Explicitly clears the title for one incident (user cleared the name).
  ///
  /// Does not touch any other incident's title storage.
  static Future<void> clearTitleForIncident({
    required String userId,
    required String incidentId,
  }) async {
    if (userId.isEmpty || incidentId.isEmpty) {
      return;
    }
    final epoch = _writeEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (epoch != _writeEpoch) {
        return;
      }
      await prefs.remove(_incidentTitleKey(userId, incidentId));
      await _purgeLegacyTitle(prefs, userId);
      debugPrint(
        '[Recovery] clearTitleForIncident incident=$incidentId '
        'for user=$userId',
      );
    } catch (error) {
      debugPrint('[Recovery] clearTitleForIncident failed: $error');
    }
  }

  /// Clears last-capture pointer, sessions, and ALL per-incident titles for
  /// [userId]. Used by Clear Vault so old titles cannot contaminate new IDs.
  static Future<void> clearAllForUser(String userId) async {
    // Invalidate in-flight remembers before awaiting prefs I/O.
    _writeEpoch++;
    if (userId.isEmpty) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
      await prefs.remove(_sessionKey(userId));
      await _purgeLegacyTitle(prefs, userId);
      final prefix = '$_incidentTitlePrefix${userId}_';
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(prefix)) {
          await prefs.remove(key);
        }
      }
      debugPrint('[Recovery] clearAllForUser user=$userId epoch=$_writeEpoch');
    } catch (error) {
      debugPrint('[Recovery] clearAllForUser failed: $error');
    }
  }

  /// Persists [incidentId] (and optional [title] / [captureSessionId]) for [userId].
  ///
  /// When [title] is non-null and non-empty it is stored via [rememberTitle].
  /// Empty titles are ignored (hydration-safe).
  static Future<void> remember({
    required String userId,
    required String incidentId,
    String? title,
    String? captureSessionId,
  }) async {
    if (userId.isEmpty || incidentId.isEmpty) {
      return;
    }
    final epoch = _writeEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (epoch != _writeEpoch) {
        debugPrint(
          '[Recovery] remember dropped (vault cleared) incident=$incidentId',
        );
        return;
      }
      await prefs.setString(_key(userId), incidentId);
      await _purgeLegacyTitle(prefs, userId);
      if (epoch != _writeEpoch) {
        return;
      }
      if (title != null && title.trim().isNotEmpty) {
        await rememberTitle(
          userId: userId,
          incidentId: incidentId,
          title: title,
        );
      }
      if (epoch != _writeEpoch) {
        return;
      }
      if (captureSessionId != null) {
        if (captureSessionId.isEmpty) {
          await prefs.remove(_sessionKey(userId));
        } else {
          await prefs.setString(_sessionKey(userId), captureSessionId);
        }
      }
      debugPrint(
        '[Recovery] remembered incident=$incidentId '
        'title=${title == null ? '(unchanged)' : (title.trim().isEmpty ? '(empty ignored)' : title.trim())} '
        'session=${captureSessionId ?? '(unchanged)'} for user=$userId',
      );
    } catch (error) {
      debugPrint('[Recovery] remember failed: $error');
    }
  }

  /// Clears the last-capture pointer only when it still points at [incidentId].
  static Future<void> clearPointerIfIncident({
    required String userId,
    required String incidentId,
  }) async {
    if (userId.isEmpty || incidentId.isEmpty) {
      return;
    }
    try {
      final current = await recall(userId);
      if (current != incidentId) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
      await prefs.remove(_sessionKey(userId));
    } catch (error) {
      debugPrint('[Recovery] clearPointerIfIncident failed: $error');
    }
  }

  /// Returns the last remembered incident for [userId], if any.
  static Future<String?> recall(String userId) async {
    if (userId.isEmpty) {
      return null;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_key(userId));
      if (id == null || id.isEmpty) {
        return null;
      }
      return id;
    } catch (error) {
      debugPrint('[Recovery] recall failed: $error');
      return null;
    }
  }

  /// Title for the last remembered incident — always incident-scoped.
  ///
  /// Never returns a bare user-scoped legacy title (that caused new incidents
  /// to inherit "Street Fight" after Vault clear).
  static Future<String?> recallTitle(String userId) async {
    if (userId.isEmpty) {
      return null;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await _purgeLegacyTitle(prefs, userId);
      final rememberedId = await recall(userId);
      if (rememberedId == null) {
        return null;
      }
      return recallTitleForIncident(
        userId: userId,
        incidentId: rememberedId,
      );
    } catch (error) {
      debugPrint('[Recovery] recallTitle failed: $error');
      return null;
    }
  }

  /// Title stored for [userId] + [incidentId] only.
  ///
  /// Legacy user-scoped titles are never used — they cannot be safely bound
  /// to a specific incident after pointer rotation / Vault clear.
  static Future<String?> recallTitleForIncident({
    required String userId,
    required String incidentId,
  }) async {
    if (userId.isEmpty || incidentId.isEmpty) {
      return null;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await _purgeLegacyTitle(prefs, userId);
      final perIncident =
          prefs.getString(_incidentTitleKey(userId, incidentId));
      if (perIncident == null || perIncident.trim().isEmpty) {
        return null;
      }
      return perIncident.trim();
    } catch (error) {
      debugPrint('[Recovery] recallTitleForIncident failed: $error');
      return null;
    }
  }

  /// Last remembered capture session id for [userId], if any.
  static Future<String?> recallCaptureSession(String userId) async {
    if (userId.isEmpty) {
      return null;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_sessionKey(userId));
      if (id == null || id.isEmpty) {
        return null;
      }
      return id;
    } catch (error) {
      debugPrint('[Recovery] recallCaptureSession failed: $error');
      return null;
    }
  }

  static Future<void> _purgeLegacyTitle(
    SharedPreferences prefs,
    String userId,
  ) async {
    final legacy = prefs.getString(_legacyTitleKey(userId));
    if (legacy != null) {
      await prefs.remove(_legacyTitleKey(userId));
      debugPrint(
        '[Recovery] purged unsafe legacy title for user=$userId '
        '(was="$legacy")',
      );
    }
  }

  @visibleForTesting
  static Future<void> clearForTests(String userId) async {
    await clearAllForUser(userId);
  }
}
