import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../diagnostics/file_final_trace.dart';
import 'durable_attach_intent.dart';
import 'saf_staging_bridge.dart';

/// Disk-backed pending File attach intent (SharedPreferences JSON).
///
/// Survives Flutter process death while Android DocumentsUI is foregrounded.
/// Keyed by authenticated [userId] — never a process-global incident pointer.
///
/// Stale policy: records older than [maxAge] are discarded. No other attach
/// TTL exists in the project; 24h covers a killed-while-picking session
/// without leaving orphaned recovery forever.
abstract final class DurableAttachIntentStore {
  static const _keyPrefix = 'ev_durable_attach_intent_v1_';

  /// Conservative expiry for an interrupted SAF session.
  static const maxAge = Duration(hours: 24);

  static SharedPreferences? _prefsOverride;

  /// Clock seam for stale-intent tests.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  @visibleForTesting
  static void debugOverridePreferences(SharedPreferences? prefs) {
    _prefsOverride = prefs;
  }

  @visibleForTesting
  static void debugReset() {
    _prefsOverride = null;
    now = DateTime.now;
  }

  static String _key(String userId) => '$_keyPrefix$userId';

  static Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  static Future<void> savePendingIntent(DurableAttachIntent intent) async {
    if (intent.userId.isEmpty || intent.sourceIncidentId.isEmpty) {
      FileFinalTrace.stage(
        'ATTACH_INTENT_SAVED',
        result: 'SKIPPED_EMPTY_IDENTITY',
      );
      return;
    }
    try {
      final prefs = await _prefs();
      await prefs.setString(_key(intent.userId), jsonEncode(intent.toJson()));
      await _writeNativePointer(intent);
      FileFinalTrace.stage(
        'ATTACH_INTENT_SAVED',
        extra:
            'origin=${intent.origin} operationId=${intent.operationId} '
            'status=${intent.status} userId=${intent.userId}',
      );
    } catch (error) {
      debugPrint('[DurableAttachIntentStore] save failed: $error');
      FileFinalTrace.failure('ATTACH_INTENT_SAVED', error: error);
    }
  }

  /// Returns the pending intent for [userId], or null if none / malformed / stale.
  ///
  /// Malformed and stale records are removed so they cannot recover later.
  static Future<DurableAttachIntent?> readPendingIntent({
    required String userId,
  }) async {
    if (userId.isEmpty) {
      return null;
    }
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final parsed = DurableAttachIntent.tryParse(jsonDecode(raw));
      if (parsed == null) {
        await prefs.remove(_key(userId));
        await _clearNativePointer();
        FileFinalTrace.stage(
          'ATTACH_RECOVERY_ABANDONED',
          result: 'MALFORMED',
          extra: 'userId=$userId',
        );
        return null;
      }
      if (parsed.userId != userId) {
        await prefs.remove(_key(userId));
        await _clearNativePointer();
        await SafStagingBridge.discard(parsed.operationId);
        FileFinalTrace.stage(
          'ATTACH_RECOVERY_ABANDONED',
          result: 'USER_MISMATCH_IN_RECORD',
          extra: 'userId=$userId stored=${parsed.userId}',
        );
        return null;
      }
      final age = now().difference(
        DateTime.fromMillisecondsSinceEpoch(parsed.createdAtMs),
      );
      if (age > maxAge || age.isNegative) {
        await prefs.remove(_key(userId));
        await _clearNativePointer();
        await SafStagingBridge.discard(parsed.operationId);
        FileFinalTrace.stage(
          'ATTACH_RECOVERY_ABANDONED',
          result: 'STALE',
          extra:
              'origin=${parsed.origin} operationId=${parsed.operationId} '
              'ageMs=${age.inMilliseconds} userId=$userId',
        );
        return null;
      }
      return parsed;
    } catch (error) {
      debugPrint('[DurableAttachIntentStore] read failed: $error');
      FileFinalTrace.failure('ATTACH_INTENT_READ', error: error);
      return null;
    }
  }

  /// Clears the pending intent for [userId].
  ///
  /// When [operationId] is set, the record is kept if it belongs to a newer
  /// overlapping attach (rapid successive attempts).
  static Future<void> clearPendingIntent({
    required String userId,
    String? operationId,
    String? reason,
  }) async {
    if (userId.isEmpty) {
      return;
    }
    try {
      final prefs = await _prefs();
      if (operationId != null && operationId.isNotEmpty) {
        final raw = prefs.getString(_key(userId));
        if (raw != null && raw.isNotEmpty) {
          final parsed = DurableAttachIntent.tryParse(jsonDecode(raw));
          if (parsed != null && parsed.operationId != operationId) {
            FileFinalTrace.stage(
              'ATTACH_INTENT_CLEARED',
              result: 'KEPT_NEWER',
              extra:
                  'clearedOp=$operationId kept=${parsed.operationId} '
                  'userId=$userId',
            );
            return;
          }
        }
      }
      await prefs.remove(_key(userId));
      await _clearNativePointer(operationId: operationId);
      FileFinalTrace.stage(
        'ATTACH_INTENT_CLEARED',
        extra:
            'operationId=${operationId ?? 'any'} '
            'reason=${reason ?? 'unspecified'} userId=$userId',
      );
    } catch (error) {
      debugPrint('[DurableAttachIntentStore] clear failed: $error');
    }
  }

  /// Native-readable copy of the pending intent for SAF result correlation.
  static Future<void> _writeNativePointer(DurableAttachIntent intent) async {
    if (kIsWeb) {
      return;
    }
    try {
      final file = await _nativePointerFile();
      if (file == null) {
        return;
      }
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(intent.toJson()), flush: true);
    } catch (_) {}
  }

  static Future<void> _clearNativePointer({String? operationId}) async {
    if (kIsWeb) {
      return;
    }
    try {
      final file = await _nativePointerFile();
      if (file == null || !await file.exists()) {
        return;
      }
      if (operationId != null && operationId.isNotEmpty) {
        try {
          final parsed = DurableAttachIntent.tryParse(
            jsonDecode(await file.readAsString()),
          );
          if (parsed != null && parsed.operationId != operationId) {
            return;
          }
        } catch (_) {}
      }
      await file.delete();
    } catch (_) {}
  }

  static Future<File?> _nativePointerFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File(p.join(dir.path, 'attach_staging', 'pending_intent.json'));
    } catch (_) {
      return null;
    }
  }
}
