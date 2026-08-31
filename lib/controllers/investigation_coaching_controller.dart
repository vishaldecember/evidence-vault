import 'package:flutter/foundation.dart';

import '../controllers/workspace_evidence_controller.dart';
import '../engines/investigation_coaching_engine.dart';
import '../models/investigation_coaching_item.dart';

/// Manages visible coaching insights and dismiss state for one workspace session.
///
/// Observes the shared [WorkspaceEvidenceController] so coaching reflects the
/// same [CurrentIncident] evidence collection as every other screen.
///
/// Session-only evidence ID snapshot detects NEW development without a
/// CoachingMemory store. First evaluation is the baseline.
class InvestigationCoachingController extends ChangeNotifier {
  InvestigationCoachingController({
    required this._controller,
  }) {
    _controller.addListener(_onIncidentChanged);
  }

  final WorkspaceEvidenceController _controller;
  final Set<String> _dismissedFingerprints = {};
  final Map<String, InvestigationCoachingItem> _pocketedItems = {};
  Set<String> _seenEvidenceIds = {};
  bool _hasBaseline = false;
  List<InvestigationCoachingItem>? _cachedVisible;

  void _onIncidentChanged() {
    _cachedVisible = null;
    notifyListeners();
  }

  List<InvestigationCoachingItem> get visibleItems {
    return _cachedVisible ??= _computeVisible();
  }

  List<InvestigationCoachingItem> _computeVisible() {
    final previouslySeen = _hasBaseline ? _seenEvidenceIds : null;
    final context = InvestigationCoachingContext.fromController(
      _controller,
      previouslySeenEvidenceIds: previouslySeen,
    );
    final generated = InvestigationCoachingEngine.generate(context);
    _seenEvidenceIds = {for (final item in context.items) item.id};
    _hasBaseline = true;
    return generated
        .where((item) => !_dismissedFingerprints.contains(item.fingerprint))
        .toList(growable: false);
  }

  List<InvestigationCoachingItem> get pocketedItems {
    return [
      for (final fingerprint in _dismissedFingerprints)
        if (_pocketedItems[fingerprint] != null) _pocketedItems[fingerprint]!,
    ];
  }

  void dismiss(String fingerprint) {
    InvestigationCoachingItem? stored;
    for (final item in visibleItems) {
      if (item.fingerprint == fingerprint) {
        stored = item;
        break;
      }
    }
    if (stored != null) {
      _pocketedItems[fingerprint] = stored;
    }
    if (_dismissedFingerprints.add(fingerprint)) {
      _cachedVisible = null;
      notifyListeners();
    }
  }

  void restore(String fingerprint) {
    final removed = _dismissedFingerprints.remove(fingerprint);
    _pocketedItems.remove(fingerprint);
    if (removed) {
      _cachedVisible = null;
      notifyListeners();
    }
  }

  void refresh() {
    _cachedVisible = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.removeListener(_onIncidentChanged);
    super.dispose();
  }

  /// Clears dismiss state — for widget tests only.
  @visibleForTesting
  void resetDismissals() {
    _dismissedFingerprints.clear();
    _pocketedItems.clear();
    _cachedVisible = null;
    notifyListeners();
  }

  @visibleForTesting
  Set<String> get dismissedFingerprints =>
      Set.unmodifiable(_dismissedFingerprints);
}
