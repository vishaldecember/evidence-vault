import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/risk/incident_risk_assessment.dart';
import '../engines/adaptive_coaching.dart';
import '../engines/investigation_coaching_engine.dart';
import '../models/library_incident_summary.dart';
import '../models/workspace_evidence_item.dart';
import '../services/persistence/incident_library_service.dart';
import '../services/relationship/relationship_engine.dart';
import '../services/risk/deterministic_risk_assessment_provider.dart';
import '../services/risk/risk_assessment_provider.dart';
import '../services/risk/risk_coach_preferences.dart';
import 'workspace_evidence_controller.dart';

/// Async Risk Coach for Investigation — never blocks Capture (Sprint 5E).
///
/// Reassessment is triggered by workspace changes (same path as coaching),
/// not by a second CaptureEngine queue.
class RiskCoachController extends ChangeNotifier {
  RiskCoachController({
    required this._controller,
    RiskAssessmentProvider? provider,
    RiskCoachPreferences? preferences,
    IncidentLibraryService? library,
  })  : _provider = provider ?? const DeterministicRiskAssessmentProvider(),
        _preferences = preferences ?? RiskCoachPreferences.instance,
        _library = library ?? IncidentLibraryService.instance {
    _controller.addListener(_onIncidentChanged);
    unawaited(refresh());
  }

  final WorkspaceEvidenceController _controller;
  final RiskAssessmentProvider _provider;
  final RiskCoachPreferences _preferences;
  final IncidentLibraryService _library;

  List<IncidentRiskAssessment> assessments = const [];
  bool wellSupported = false;
  bool _ready = false;
  bool get isReady => _ready;

  void _onIncidentChanged() {
    unawaited(refresh());
  }

  Future<void> refresh({DateTime? now}) async {
    await _preferences.restore();
    final context = buildContext(now: now);
    wellSupported = _provider.looksWellSupported(context);
    final loaded = await _provider.assess(context);
    final coachingContext =
        InvestigationCoachingContext.fromController(_controller);
    final coaching = InvestigationCoachingEngine.generate(coachingContext);
    final maturity = AdaptiveCoaching.maturityFor(
      AdaptiveCoachingInput(
        items: coachingContext.items,
        relationships: coachingContext.relationships,
        primaryEvidenceCount: coachingContext.primaryEvidenceCount,
        groupMemberEvidenceIds: coachingContext.groupMemberEvidenceIds,
        narrativeEventCount: coachingContext.narrativeEvents.length,
      ),
    );
    final covered = AdaptiveCoaching.riskTypesCoveredBy(
      coaching,
      maturity: maturity,
    );
    assessments = [
      for (final item in loaded)
        if (!covered.contains(item.riskType)) item,
    ];
    _ready = true;
    notifyListeners();
  }

  RiskAssessmentContext buildContext({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final aggregate = _controller.aggregate;
    final store = aggregate.store;
    final incident = store.incident;
    final graph = RelationshipEngine.instance.buildGraphView(
      store: store,
      evidence: _controller.currentIncident.evidence,
      relationships: _controller.relationshipRepository.all,
    );

    final memoryHints = <String>[];
    final siblings = [
      for (final s in _library.summaries)
        if (s.id != incident.id && s.isInProgress) s,
    ];
    if (siblings.isNotEmpty) {
      memoryHints.add(
        '${siblings.length} other investigation${siblings.length == 1 ? '' : 's'} '
        'still in progress in your library.',
      );
    }

    return RiskAssessmentContext(
      incidentId: incident.id,
      incidentTitle: incident.title,
      journeyStage: _controller.journeyStage,
      createdAt: incident.createdAt,
      updatedAt: incident.updatedAt,
      now: clock,
      evidence: List<WorkspaceEvidenceItem>.from(
        _controller.currentIncident.evidence,
      ),
      capturedEvidence: List.from(store.capturedEvidence),
      relationships: _controller.relationshipRepository.all,
      collections: List.from(store.evidenceCollections),
      graph: graph,
      relationshipSuggestions: List.from(store.relationshipSuggestions),
      narrativeEventCount: _controller.currentIncident.narrativeEventCount,
      dismissedIds: _preferences.activeDismissedIds(now: clock),
      reviewedIds: _preferences.reviewedIds,
      librarySummaries: List<LibraryIncidentSummary>.from(_library.summaries),
      memoryRecallHints: memoryHints,
    );
  }

  Future<void> dismiss(String assessmentId) async {
    await _preferences.dismiss(assessmentId);
    await refresh();
  }

  Future<void> markReviewed(String assessmentId) async {
    await _preferences.markReviewed(assessmentId);
    await refresh();
  }

  @override
  void dispose() {
    _controller.removeListener(_onIncidentChanged);
    super.dispose();
  }

  @visibleForTesting
  void resetForTests() {
    assessments = const [];
    wellSupported = false;
    _ready = false;
    _preferences.clearMemory();
  }
}
