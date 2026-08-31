import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/relationship/relationship_suggestion.dart';
import 'package:evidence_vault/domain/risk/incident_risk_assessment.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/services/relationship/relationship_engine.dart';
import 'package:evidence_vault/services/risk/contradiction_detector.dart';
import 'package:evidence_vault/services/risk/deterministic_risk_assessment_provider.dart';
import 'package:evidence_vault/services/risk/risk_assessment_provider.dart';
import 'package:evidence_vault/services/risk/risk_coach_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceEvidenceItem _photo(String id, {String? collectionId}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.image,
    title: 'Photo $id',
    lastPreservedAt: DateTime(2026, 8, 1),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    collectionId: collectionId,
    incidentId: 'inc-1',
  );
}

WorkspaceEvidenceItem _note(String id, {String? parentId}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.note,
    title: 'Note $id',
    lastPreservedAt: DateTime(2026, 8, 1),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    parentEvidenceId: parentId,
    relationshipType: parentId == null ? null : RelationshipType.supports,
    incidentId: 'inc-1',
  );
}

CapturedEvidence _captured({
  required String id,
  double? lat,
  double? lon,
  DateTime? capturedAt,
  bool isPrimary = false,
}) {
  return CapturedEvidence(
    id: id,
    incidentId: 'inc-1',
    type: CapturedEvidenceType.photo,
    capturedAt: capturedAt ?? DateTime(2026, 8, 1, 12),
    title: 'Photo $id',
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    timelineAnchorId: 'anchor-$id',
    latitude: lat,
    longitude: lon,
    isPrimaryEvidence: isPrimary,
  );
}

RiskAssessmentContext _context({
  String incidentId = 'inc-1',
  JourneyStage stage = JourneyStage.building,
  List<WorkspaceEvidenceItem> evidence = const [],
  List<CapturedEvidence> captured = const [],
  List<EvidenceRelationship> relationships = const [],
  List<EvidenceCollection> collections = const [],
  List<RelationshipSuggestion> suggestions = const [],
  List<LibraryIncidentSummary> library = const [],
  List<String> memoryHints = const [],
  Set<String> dismissed = const {},
  Set<String> reviewed = const {},
  int narrativeCount = 0,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? now,
}) {
  final clock = now ?? DateTime(2026, 8, 8);
  final byId = {for (final e in evidence) e.id: e};
  final primaryIds = <String>[
    for (final c in captured)
      if (c.isPrimaryEvidence) c.id,
  ];
  if (primaryIds.isEmpty) {
    for (final e in evidence) {
      if (e.kind.isPrimaryChronology && !e.isContextual) {
        primaryIds.add(e.id);
      }
    }
  }
  final supports = <String, List<String>>{};
  for (final e in evidence) {
    final parent = e.parentEvidenceId;
    if (parent == null) continue;
    supports.putIfAbsent(parent, () => []).add(e.id);
  }
  final graphView = InvestigationGraphView(
    primaryEvidenceIds: primaryIds,
    supportingByPrimaryId: supports,
    edges: [
      for (final rel in relationships)
        InvestigationGraphEdge(
          id: rel.id,
          sourceEvidenceId: rel.sourceEvidenceId,
          targetEvidenceId: rel.targetEvidenceId,
          kind: InvestigationGraphEdgeKind.related,
        ),
      for (final entry in supports.entries)
        for (final supportId in entry.value)
          InvestigationGraphEdge(
            id: 'supports_$supportId',
            sourceEvidenceId: supportId,
            targetEvidenceId: entry.key,
            kind: InvestigationGraphEdgeKind.supports,
          ),
    ],
    collections: collections,
    evidenceById: byId,
  );

  return RiskAssessmentContext(
    incidentId: incidentId,
    incidentTitle: 'Parking Incident',
    journeyStage: stage,
    createdAt: createdAt ?? DateTime(2026, 8, 1),
    updatedAt: updatedAt ?? DateTime(2026, 8, 1),
    now: clock,
    evidence: evidence,
    capturedEvidence: captured,
    relationships: relationships,
    collections: collections,
    graph: graphView,
    relationshipSuggestions: suggestions,
    narrativeEventCount: narrativeCount,
    dismissedIds: dismissed,
    reviewedIds: reviewed,
    librarySummaries: library,
    memoryRecallHints: memoryHints,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeterministicRiskAssessmentProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = const DeterministicRiskAssessmentProvider();
    RiskCoachPreferences.instance.resetForTests();
  });

  test('no evidence → no fabricated risks', () async {
    final context = _context(evidence: const []);
    expect(await provider.assess(context), isEmpty);
    expect(provider.looksWellSupported(context), isFalse);
  });

  test('building incident → unresolved insight with explainable reason', () async {
    final items = await provider.assess(
      _context(evidence: [_photo('p1')]),
    );
    expect(
      items.any((a) => a.riskType == RiskType.unresolved),
      isTrue,
    );
    final unresolved =
        items.firstWhere((a) => a.riskType == RiskType.unresolved);
    expect(unresolved.reason, contains('Building'));
    expect(unresolved.severity, isNot(RiskSeverity.critical));
  });

  test('documentation gap when chronology has no supporting evidence', () async {
    final items = await provider.assess(
      _context(evidence: [_photo('p1'), _photo('p2')]),
    );
    expect(
      items.any((a) => a.riskType == RiskType.documentationGap),
      isTrue,
    );
  });

  test('missing evidence when primary has no supporting', () async {
    final items = await provider.assess(
      _context(
        evidence: [_photo('p1'), _note('n1')],
        captured: [_captured(id: 'p1', isPrimary: true)],
      ),
    );
    expect(
      items.any((a) => a.riskType == RiskType.missingEvidence),
      isTrue,
    );
  });

  test('collection with disconnected evidence → relationship gap', () async {
    final collection = EvidenceCollection(
      id: 'col-1',
      incidentId: 'inc-1',
      name: 'Vehicle',
      systemGenerated: true,
      displayOrder: 0,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      memberEvidenceIds: const ['p1', 'p2', 'p3'],
    );
    final items = await provider.assess(
      _context(
        evidence: [
          _photo('p1', collectionId: 'col-1'),
          _photo('p2', collectionId: 'col-1'),
          _photo('p3', collectionId: 'col-1'),
        ],
        collections: [collection],
      ),
    );
    final gap =
        items.firstWhere((a) => a.riskType == RiskType.relationshipGap);
    expect(gap.reason, contains('Vehicle'));
    expect(gap.reason, contains('explicit parent-link or SUPPORTS relationship'));
  });

  test('follow-up when supporting exists without narrative', () async {
    final items = await provider.assess(
      _context(
        evidence: [_photo('p1'), _note('n1', parentId: 'p1')],
        narrativeCount: 0,
        updatedAt: DateTime(2026, 8, 7),
      ),
    );
    expect(items.any((a) => a.riskType == RiskType.followUp), isTrue);
  });

  test('rich well-supported investigation', () async {
    final collection = EvidenceCollection(
      id: 'col-1',
      incidentId: 'inc-1',
      name: 'Scene',
      systemGenerated: true,
      displayOrder: 0,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      memberEvidenceIds: const ['p1', 'n1'],
    );
    final context = _context(
      stage: JourneyStage.rich,
      evidence: [_photo('p1'), _note('n1', parentId: 'p1')],
      captured: [_captured(id: 'p1', isPrimary: true)],
      collections: [collection],
      relationships: [
        EvidenceRelationship(
          id: 'r1',
          sourceEvidenceId: 'n1',
          targetEvidenceId: 'p1',
          type: RelationshipType.supports,
          createdAt: DateTime(2026, 8, 1),
        ),
      ],
      narrativeCount: 1,
    );
    expect(provider.looksWellSupported(context), isTrue);
    // Building-only risks should not fire on rich stage.
    final items = await provider.assess(context);
    expect(items.any((a) => a.riskType == RiskType.unresolved), isFalse);
  });

  test('simple GPS contradiction', () async {
    final hits = ContradictionDetector.geoTimestampConflicts(
      captured: [
        _captured(id: 'a', lat: 27.7172, lon: 85.3240),
        _captured(
          id: 'b',
          lat: 27.7000,
          lon: 85.3000,
          capturedAt: DateTime(2026, 8, 1, 12, 0, 10),
        ),
      ],
    );
    expect(hits, isNotEmpty);

    final items = await provider.assess(
      _context(
        evidence: [_photo('a'), _photo('b')],
        captured: [
          _captured(id: 'a', lat: 27.7172, lon: 85.3240),
          _captured(
            id: 'b',
            lat: 27.7000,
            lon: 85.3000,
            capturedAt: DateTime(2026, 8, 1, 12, 0, 10),
          ),
        ],
      ),
    );
    expect(items.any((a) => a.riskType == RiskType.contradiction), isTrue);
  });

  test('deterministic recurrence from matching library titles', () async {
    LibraryIncidentSummary summary(String id) => LibraryIncidentSummary(
          id: id,
          title: 'Parking Incident',
          evidenceCount: 2,
          contextEnrichedCount: 0,
          integrityVerified: false,
          lastPreserved: 'today',
          isInProgress: true,
        );

    final items = await provider.assess(
      _context(
        stage: JourneyStage.rich,
        evidence: [_photo('p1'), _note('n1', parentId: 'p1')],
        library: [
          summary('inc-1'),
          summary('inc-2'),
          summary('inc-3'),
        ],
      ),
    );
    expect(items.any((a) => a.riskType == RiskType.pattern), isTrue);
  });

  test('dismissed assessment excluded; no duplicates by type', () async {
    final context = _context(
      evidence: [_photo('p1'), _photo('p2')],
      dismissed: {'UNRESOLVED_inc-1'},
    );
    final items = await provider.assess(context);
    expect(items.any((a) => a.riskType == RiskType.unresolved), isFalse);
    final types = items.map((a) => a.riskType).toSet();
    expect(types.length, items.length);
  });

  test('reviewed assessment excluded', () async {
    final context = _context(
      evidence: [_photo('p1')],
      reviewed: {'UNRESOLVED_inc-1'},
    );
    final items = await provider.assess(context);
    expect(items.any((a) => a.riskType == RiskType.unresolved), isFalse);
  });

  test('prefs dismiss persists across restore', () async {
    await RiskCoachPreferences.instance.dismiss('risk-1');
    RiskCoachPreferences.instance.clearMemory();
    await RiskCoachPreferences.instance.restore();
    expect(
      RiskCoachPreferences.instance.activeDismissedIds().contains('risk-1'),
      isTrue,
    );
  });

  test('no critical severity from deterministic provider', () async {
    final items = await provider.assess(
      _context(
        evidence: [_photo('p1')],
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      ),
    );
    expect(items.every((a) => a.severity != RiskSeverity.critical), isTrue);
  });

  test('blank context incidentId fails closed', () async {
    final items = await provider.assess(
      _context(
        incidentId: '',
        evidence: [_photo('p1'), _photo('p2')],
      ),
    );
    expect(items, isEmpty);
    expect(
      provider.looksWellSupported(
        _context(incidentId: '', evidence: [_photo('p1')]),
      ),
      isFalse,
    );
  });

  test('blank collection incidentId is not treated as current incident',
      () async {
    final collection = EvidenceCollection(
      id: 'col-blank',
      incidentId: '',
      name: 'Vehicle',
      systemGenerated: true,
      displayOrder: 0,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      memberEvidenceIds: const ['p1', 'p2', 'p3'],
    );
    final items = await provider.assess(
      _context(
        evidence: [
          _photo('p1', collectionId: 'col-blank'),
          _photo('p2', collectionId: 'col-blank'),
          _photo('p3', collectionId: 'col-blank'),
        ],
        collections: [collection],
      ),
    );
    expect(
      items.any((a) => a.riskType == RiskType.relationshipGap),
      isFalse,
    );
  });

  test('blank suggestion incidentId is not treated as current incident',
      () async {
    RelationshipSuggestion suggestion(String incidentId) =>
        RelationshipSuggestion(
          id: 'sug-1',
          incidentId: incidentId,
          sourceEvidenceId: 'p1',
          targetEvidenceId: 'p2',
          relationshipType: RelationshipType.relatedTo.name,
          confidence: 0.9,
          reason: 'metadata',
          source: RelationshipSuggestionSource.metadata,
          status: RelationshipSuggestionStatus.suggested,
          createdAt: DateTime(2026, 8, 1),
        );

    final blankItems = await provider.assess(
      _context(
        evidence: [_photo('p1'), _photo('p2')],
        suggestions: [suggestion('')],
      ),
    );
    expect(
      blankItems.any(
        (a) =>
            a.riskType == RiskType.relationshipGap &&
            a.id.contains('suggestion'),
      ),
      isFalse,
    );

    final stampedItems = await provider.assess(
      _context(
        evidence: [_photo('p1'), _photo('p2')],
        suggestions: [suggestion('inc-1')],
      ),
    );
    expect(
      stampedItems.any(
        (a) =>
            a.riskType == RiskType.relationshipGap &&
            a.id.contains('suggestion'),
      ),
      isTrue,
    );
  });
}
