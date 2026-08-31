import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-supplied Reconstruct location labels. Presentation only.
class ReconstructionLocationLabelStore extends ChangeNotifier {
  ReconstructionLocationLabelStore._();

  static final ReconstructionLocationLabelStore instance =
      ReconstructionLocationLabelStore._();

  final Map<String, Map<String, String>> _labels = {};

  Map<String, String> labelsFor(String incidentId) =>
      Map.unmodifiable(_labels[incidentId] ?? const {});

  @visibleForTesting
  void resetForTests() {
    _labels.clear();
  }

  Future<void> hydrate(String incidentId) async {
    if (_labels.containsKey(incidentId)) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(incidentId));
      if (raw == null || raw.isEmpty) {
        _labels[incidentId] = {};
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _labels[incidentId] = {};
        return;
      }
      _labels[incidentId] = {
        for (final entry in decoded.entries) '${entry.key}': '${entry.value}',
      };
      notifyListeners();
    } catch (_) {
      _labels[incidentId] = {};
    }
  }

  Future<void> save({
    required String incidentId,
    required String locationKey,
    required String label,
  }) async {
    final current = {...(_labels[incidentId] ?? {})};
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      current.remove(locationKey);
    } else {
      current[locationKey] = trimmed;
    }
    _labels[incidentId] = current;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(incidentId), jsonEncode(current));
    } catch (_) {}
  }

  Future<void> removeForIncident(String incidentId) async {
    final id = incidentId.trim();
    if (id.isEmpty) {
      return;
    }
    _labels.remove(id);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(id));
    } catch (_) {}
  }

  static String _key(String incidentId) =>
      'reconstruction_location_labels_$incidentId';
}
