import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/memory/memory_recall_item.dart';
import '../persistence/incident_library_service.dart';
import 'deterministic_memory_recall_provider.dart';
import 'memory_recall_preferences.dart';
import 'memory_recall_provider.dart';

/// Async Memory Recall for Vault — never blocks Capture or Vault first paint.
class MemoryRecallService extends ChangeNotifier {
  MemoryRecallService({
    MemoryRecallProvider? provider,
    IncidentLibraryService? library,
    MemoryRecallPreferences? preferences,
  })  : _provider = provider ?? const DeterministicMemoryRecallProvider(),
        _library = library ?? IncidentLibraryService.instance,
        _preferences = preferences ?? MemoryRecallPreferences.instance;

  static final MemoryRecallService instance = MemoryRecallService();

  final MemoryRecallProvider _provider;
  final IncidentLibraryService _library;
  final MemoryRecallPreferences _preferences;

  List<MemoryRecallItem> items = const [];
  MemoryMonthSummary monthSummary = const MemoryMonthSummary(
    evidenceCaptured: 0,
    incidentsTouched: 0,
    investigationsStrengthened: 0,
    becameReady: 0,
  );
  bool _ready = false;
  bool get isReady => _ready;

  /// Loads dismiss prefs then computes recall from current library cache.
  Future<void> refresh({DateTime? now}) async {
    await _preferences.restore();
    _recompute(now: now);
  }

  /// Recompute from already-loaded library data (fast path after library notify).
  void recomputeFromLibrary({DateTime? now}) {
    _recompute(now: now);
  }

  void _recompute({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final context = MemoryRecallContext(
      incidents: [
        for (final summary in _library.summaries)
          if (!summary.isArchived && !summary.isRecentlyDeleted) summary,
      ],
      now: clock,
      dismissedIds: _preferences.activeDismissedIds(now: clock),
    );
    monthSummary = _provider.monthSummary(context);
    unawaited(
      _provider.load(context).then((loaded) {
        items = loaded;
        _ready = true;
        notifyListeners();
      }),
    );
  }

  Future<void> dismiss(String recallId) async {
    await _preferences.dismiss(recallId);
    _recompute();
  }

  @visibleForTesting
  void resetForTests() {
    items = const [];
    monthSummary = const MemoryMonthSummary(
      evidenceCaptured: 0,
      incidentsTouched: 0,
      investigationsStrengthened: 0,
      becameReady: 0,
    );
    _ready = false;
    _preferences.clearMemory();
  }
}
