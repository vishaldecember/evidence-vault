import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local dismiss / reviewed preferences for Risk Coach (Sprint 5E).
///
/// Never mutates incident documents — presentation preference only.
class RiskCoachPreferences {
  RiskCoachPreferences._();

  static final RiskCoachPreferences instance = RiskCoachPreferences._();

  static const _dismissPrefix = 'risk_coach_dismissed_until_';
  static const _reviewedPrefix = 'risk_coach_reviewed_';
  static const Duration snoozeDuration = Duration(days: 14);

  final Map<String, DateTime> _dismissedUntil = {};
  final Set<String> _reviewed = {};

  Set<String> activeDismissedIds({DateTime? now}) {
    final clock = now ?? DateTime.now();
    return {
      for (final entry in _dismissedUntil.entries)
        if (entry.value.isAfter(clock)) entry.key,
    };
  }

  Set<String> get reviewedIds => Set.unmodifiable(_reviewed);

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith(_dismissPrefix)) {
          final id = key.substring(_dismissPrefix.length);
          final millis = prefs.getInt(key);
          if (millis != null) {
            _dismissedUntil[id] = DateTime.fromMillisecondsSinceEpoch(millis);
          }
        } else if (key.startsWith(_reviewedPrefix)) {
          final id = key.substring(_reviewedPrefix.length);
          if (prefs.getBool(key) == true) {
            _reviewed.add(id);
          }
        }
      }
    } catch (error) {
      debugPrint('[RiskCoach] prefs restore skipped: $error');
    }
  }

  Future<void> dismiss(String assessmentId, {DateTime? now}) async {
    final until = (now ?? DateTime.now()).add(snoozeDuration);
    _dismissedUntil[assessmentId] = until;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        '$_dismissPrefix$assessmentId',
        until.millisecondsSinceEpoch,
      );
    } catch (error) {
      debugPrint('[RiskCoach] dismiss save skipped: $error');
    }
  }

  Future<void> markReviewed(String assessmentId) async {
    _reviewed.add(assessmentId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_reviewedPrefix$assessmentId', true);
    } catch (error) {
      debugPrint('[RiskCoach] reviewed save skipped: $error');
    }
  }

  void clearMemory() {
    _dismissedUntil.clear();
    _reviewed.clear();
  }

  @visibleForTesting
  void resetForTests() {
    clearMemory();
  }
}
