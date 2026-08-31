import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local dismiss / snooze preferences for Memory Recall (Sprint 5D).
///
/// Never mutates incident documents — presentation preference only.
class MemoryRecallPreferences {
  MemoryRecallPreferences._();

  static final MemoryRecallPreferences instance = MemoryRecallPreferences._();

  static const _prefix = 'memory_recall_dismissed_until_';
  static const Duration snoozeDuration = Duration(days: 14);

  final Map<String, DateTime> _memory = {};

  Set<String> activeDismissedIds({DateTime? now}) {
    final clock = now ?? DateTime.now();
    return {
      for (final entry in _memory.entries)
        if (entry.value.isAfter(clock)) entry.key,
    };
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_prefix)) {
          continue;
        }
        final id = key.substring(_prefix.length);
        final millis = prefs.getInt(key);
        if (millis == null) {
          continue;
        }
        _memory[id] = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    } catch (error) {
      debugPrint('[MemoryRecall] prefs restore skipped: $error');
    }
  }

  Future<void> dismiss(String recallId, {DateTime? now}) async {
    final until = (now ?? DateTime.now()).add(snoozeDuration);
    _memory[recallId] = until;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        '$_prefix$recallId',
        until.millisecondsSinceEpoch,
      );
    } catch (error) {
      debugPrint('[MemoryRecall] prefs save skipped: $error');
    }
  }

  /// Clears in-memory dismiss state (tests + service reset).
  void clearMemory() {
    _memory.clear();
  }

  @visibleForTesting
  void resetForTests() {
    clearMemory();
  }
}
