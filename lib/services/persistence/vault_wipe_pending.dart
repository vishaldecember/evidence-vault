import 'package:shared_preferences/shared_preferences.dart';

/// Remembers incident ids that Clear Vault still owes a cloud delete.
///
/// Local identity is cleared first. If Firestore wipe is incomplete, later
/// Library refresh / sign-in must not resurrect those ids.
abstract final class VaultWipePending {
  static const _userKey = 'ev_pending_vault_wipe_uid';
  static const _idsKey = 'ev_pending_vault_wipe_ids';

  static Future<void> mark({
    required String userId,
    required Iterable<String> incidentIds,
  }) async {
    if (userId.isEmpty) {
      return;
    }
    final ids = {
      for (final id in incidentIds)
        if (id.trim().isNotEmpty) id.trim(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, userId);
    await prefs.setStringList(_idsKey, ids.toList());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_idsKey);
  }

  static Future<Set<String>> incidentIdsFor(String userId) async {
    if (userId.isEmpty) {
      return {};
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_userKey) != userId) {
      return {};
    }
    return {
      for (final id in prefs.getStringList(_idsKey) ?? const <String>[])
        if (id.trim().isNotEmpty) id.trim(),
    };
  }

  static Future<void> removeIds(Iterable<String> incidentIds) async {
    final prefs = await SharedPreferences.getInstance();
    final remaining = {
      for (final id in prefs.getStringList(_idsKey) ?? const <String>[])
        if (id.trim().isNotEmpty) id.trim(),
    }..removeAll(incidentIds);
    if (remaining.isEmpty) {
      await prefs.remove(_userKey);
      await prefs.remove(_idsKey);
      return;
    }
    await prefs.setStringList(_idsKey, remaining.toList());
  }
}
