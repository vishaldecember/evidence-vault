import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/relationship/relationship_group.dart';
import 'package:evidence_vault/domain/relationship/relationship_suggestion.dart';
import 'package:evidence_vault/domain/trust_package/trust_package_assembler.dart';
import 'package:evidence_vault/engines/evidence_semantics.dart';
import 'package:evidence_vault/mappers/connections_presentation_mapper.dart';
import 'package:evidence_vault/models/connections_presentation.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/evidence_workspace_content.dart';
import 'package:evidence_vault/screens/investigation_workspace_screen.dart';
import 'package:evidence_vault/services/trust_package_scorecard_service.dart';
import 'package:evidence_vault/widgets/home/evidence_map_readiness_sheet.dart';
import 'package:evidence_vault/widgets/investigation/investigate_incident_scope.dart';
import 'package:evidence_vault/widgets/timeline/timeline_workspace_header.dart';
import 'package:evidence_vault/widgets/trust_package/preview/trust_package_preview.dart';
import 'package:evidence_vault/widgets/workspace/timeline_workspace_summary.dart';
import 'package:evidence_vault/widgets/workspace/workspace_body_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void expectIncident(String expected, String actual) {
  if (expected != actual) {
    fail('EXPECTED INCIDENT:\n$expected\n\nACTUAL INCIDENT:\n$actual');
  }
}

WorkspaceEvidenceController _controllerFor({
  required String id,
  required String title,
}) {
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: id, title: title),
  );
}

WorkspaceEvidenceItem _item({
  required String id,
  required String incidentId,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: '$kind $id',
    lastPreservedAt: DateTime(2026, 8, 15, 12),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: incidentId,
  );
}

RelationshipGroup _group({
  required String id,
  required String incidentId,
  List<String> members = const ['a', 'b'],
}) {
  return RelationshipGroup(
    id: id,
    incidentId: incidentId,
    memberEvidenceIds: members,
    type: RelationshipType.relatedTo,
    createdAt: DateTime(2026, 8, 15),
    colorIndex: 0,
  );
}

Future<void> _pumpBoundInvestigate(
  WidgetTester tester, {
  required WorkspaceEvidenceController controller,
  required String boundIncidentId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: InvestigationWorkspaceScreen(
        controller: controller,
        boundIncidentId: boundIncidentId,
        onOpenFullEvidenceRecord: (_) async {},
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WorkspaceSession.instance.reset();
  });

  test('sessionMatchesBound fail-closes blank and mismatch', () {
    expect(
      InvestigateIncidentScope.sessionMatchesBound('inc-B', 'inc-B'),
      isTrue,
    );
    expect(
      InvestigateIncidentScope.sessionMatchesBound('inc-B', 'inc-A'),
      isFalse,
    );
    expect(InvestigateIncidentScope.sessionMatchesBound('', 'inc-B'), isFalse);
    expect(InvestigateIncidentScope.sessionMatchesBound('inc-B', ''), isFalse);
    expect(InvestigateIncidentScope.sessionMatchesBound('   ', 'inc-B'), isFalse);
  });

  testWidgets('1. Bound write with matching incident ID succeeds',
      (tester) async {
    final controller = _controllerFor(id: 'inc-B', title: 'Beta');
    await _pumpBoundInvestigate(
      tester,
      controller: controller,
      boundIncidentId: 'inc-B',
    );

    final state = tester.state<InvestigationWorkspaceScreenState>(
      find.byType(InvestigationWorkspaceScreen),
    );
    state.applyIncidentName('Bound Beta');
    expectIncident('inc-B', controller.currentIncident.id);
    expect(controller.currentIncident.title, 'Bound Beta');
  });

  testWidgets('2b. Mismatched write is not remapped onto the session incident',
      (tester) async {
    final controller = _controllerFor(id: 'inc-B', title: 'Beta');
    await _pumpBoundInvestigate(
      tester,
      controller: controller,
      boundIncidentId: 'inc-A',
    );
    tester
        .state<InvestigationWorkspaceScreenState>(
          find.byType(InvestigationWorkspaceScreen),
        )
        .applyIncidentName('Remapped');
    expectIncident('inc-B', controller.currentIncident.id);
    expect(controller.currentIncident.title, 'Beta');
  });

  testWidgets('2. Bound write with mismatched session incident ID fails closed',
      (tester) async {
    final controller = _controllerFor(id: 'inc-B', title: 'Beta');
    await _pumpBoundInvestigate(
      tester,
      controller: controller,
      boundIncidentId: 'inc-B',
    );

    controller.replaceAggregate(
      IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
    );
    await tester.pump();

    final state = tester.state<InvestigationWorkspaceScreenState>(
      find.byType(InvestigationWorkspaceScreen),
    );
    state.applyIncidentName('Hijacked');
    expectIncident('inc-A', controller.currentIncident.id);
    expect(controller.currentIncident.title, 'Alpha');
  });

  testWidgets('3. Bound write with blank incident ID fails closed',
      (tester) async {
    final controller = _controllerFor(id: 'inc-B', title: 'Beta');
    await _pumpBoundInvestigate(
      tester,
      controller: controller,
      boundIncidentId: '',
    );

    final state = tester.state<InvestigationWorkspaceScreenState>(
      find.byType(InvestigationWorkspaceScreen),
    );
    state.applyIncidentName('Blank write');
    expect(controller.currentIncident.title, 'Beta');
  });

  testWidgets('4. Reflection add with mismatch → no write', (tester) async {
    final controller = _controllerFor(id: 'inc-B', title: 'Beta');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvidenceWorkspaceContent(
            controller: controller,
            boundIncidentId: 'inc-B',
            presentation: WorkspaceBodyPresentation.capture,
            onShowEvidenceInspector: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    controller.replaceAggregate(
      IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
    );
    await tester.pump();

    final state = tester.state<EvidenceWorkspaceContentState>(
      find.byType(EvidenceWorkspaceContent),
    );
    state.applyAddReflection(title: 'Note', body: 'Should not persist');
    expect(controller.sortedReflections, isEmpty);
  });

  testWidgets('5. Reflection edit with mismatch → no write', (tester) async {
    final controller = _controllerFor(id: 'inc-B', title: 'Beta');
    final added = controller.addReflection(title: 'Original', body: 'Body');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvidenceWorkspaceContent(
            controller: controller,
            boundIncidentId: 'inc-B',
            presentation: WorkspaceBodyPresentation.capture,
            onShowEvidenceInspector: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    controller.replaceAggregate(
      IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
    );
    await tester.pump();

    final state = tester.state<EvidenceWorkspaceContentState>(
      find.byType(EvidenceWorkspaceContent),
    );
    state.applyEditReflection(
      reflectionId: added.id,
      title: 'Edited',
      body: 'Changed',
    );
    expect(controller.sortedReflections, isEmpty);
  });

  testWidgets('6. Incident name mutation with mismatch → no write',
      (tester) async {
    final controller = _controllerFor(id: 'inc-B', title: 'Beta');
    await _pumpBoundInvestigate(
      tester,
      controller: controller,
      boundIncidentId: 'inc-B',
    );
    controller.replaceAggregate(
      IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
    );
    await tester.pump();
    tester
        .state<InvestigationWorkspaceScreenState>(
          find.byType(InvestigationWorkspaceScreen),
        )
        .applyIncidentName('Renamed through B');
    expect(controller.currentIncident.title, 'Alpha');
  });

  testWidgets('7. Primary mutation with mismatch → no write', (tester) async {
    final controller = _controllerFor(id: 'inc-B', title: 'Beta');
    final photoId = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    controller.setPrimaryEvidence(evidenceId: photoId, isPrimary: true);
    await _pumpBoundInvestigate(
      tester,
      controller: controller,
      boundIncidentId: 'inc-B',
    );

    final before = controller.aggregate.store.capturedEvidence
        .firstWhere((item) => item.id == photoId)
        .isPrimaryEvidence;
    controller.replaceAggregate(
      IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
    );
    await tester.pump();
    tester
        .state<InvestigationWorkspaceScreenState>(
          find.byType(InvestigationWorkspaceScreen),
        )
        .applySetPrimaryEvidence(photoId, false);
    expect(before, isTrue);
    expect(
      controller.aggregate.store.capturedEvidence
          .where((item) => item.id == photoId),
      isEmpty,
    );
  });

  testWidgets('8. Group mutation with mismatch → no write', (tester) async {
    final controller = _controllerFor(id: 'inc-B', title: 'Beta');
    final a = controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final b = controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.video);
    await _pumpBoundInvestigate(
      tester,
      controller: controller,
      boundIncidentId: 'inc-B',
    );
    controller.replaceAggregate(
      IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
    );
    await tester.pump();
    tester
        .state<InvestigationWorkspaceScreenState>(
          find.byType(InvestigationWorkspaceScreen),
        )
        .applyCommitRelationshipGroup([a, b]);
    expect(controller.currentIncident.relationshipGroups, isEmpty);
  });

  testWidgets('9. Narrative mutation with mismatch → no write', (tester) async {
    final controller = _controllerFor(id: 'inc-B', title: 'Beta');
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    await _pumpBoundInvestigate(
      tester,
      controller: controller,
      boundIncidentId: 'inc-B',
    );
    final eventId = controller.narrativeEvents.first.event.id;
    final original = controller.narrativeEvents.first.event.title;
    controller.replaceAggregate(
      IncidentAggregate.shell(id: 'inc-A', title: 'Alpha'),
    );
    await tester.pump();
    tester
        .state<InvestigationWorkspaceScreenState>(
          find.byType(InvestigationWorkspaceScreen),
        )
        .applyNarrativeEventTitle(eventId, 'Swapped title');
    expect(
      controller.narrativeEvents.any((event) => event.event.id == eventId),
      isFalse,
    );
    expect(original, isNot('Swapped title'));
  });

  testWidgets(
      '10. Relationship initialization with mismatch → no cross-incident operation',
      (tester) async {
    final controllerA = _controllerFor(id: 'inc-A', title: 'Alpha');
    controllerA.preserveEvidence(WorkspaceCaptureMode.photo);
    controllerA.preserveEvidence(WorkspaceCaptureMode.video);
    final before = controllerA.relationshipRepository.all.length;

    await _pumpBoundInvestigate(
      tester,
      controller: controllerA,
      boundIncidentId: 'inc-B',
    );

    final state = tester.state<InvestigationWorkspaceScreenState>(
      find.byType(InvestigationWorkspaceScreen),
    );
    state.ensureInvestigationRelationshipsIfBound();
    await tester.pump();
    expect(controllerA.relationshipRepository.all.length, before);
    expectIncident('inc-A', controllerA.currentIncident.id);
  });

  test('13. Connections allGroups only include bound incident groups', () {
    final groups = InvestigateIncidentScope.relationshipGroups(
      [
        _group(id: 'g-a', incidentId: 'inc-A'),
        _group(id: 'g-b', incidentId: 'inc-B'),
        _group(id: 'g-blank', incidentId: ''),
      ],
      'inc-B',
    );
    expect(groups.map((group) => group.id), ['g-b']);
  });

  test('14. Timeline language does not call kind-based evidence supporting', () {
    final summary = TimelineWorkspaceSummary.summaryLabel(
      timelineAnchorCount: 3,
      supportingEvidenceCount: 2,
    );
    expect(summary.toLowerCase(), isNot(contains('supporting')));
    expect(summary, contains('additional evidence'));
    expect(
      TimelineWorkspaceHeader.supportingCountLabel(1).toLowerCase(),
      isNot(contains('supporting')),
    );
    expect(
      TimelineWorkspaceHeader.supportingCountLabel(1),
      '1 additional evidence',
    );
  });

  test('15. Trust scorecard does not call referential integrity Complete', () {
    final controller = _controllerFor(id: 'inc-B', title: 'Beta');
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    final package = const DefaultTrustPackageAssembler().assemble(
      controller.aggregate,
    );
    final quality = TrustPackageScorecardService.evaluate(package);
    expect(
      quality.indicators.any((entry) => entry.label.contains('Complete')),
      isFalse,
    );
    expect(
      quality.indicators.any((entry) => entry.statusLabel.contains('Complete')),
      isFalse,
    );
    expect(
      quality.indicators.map((entry) => entry.label),
      contains(TrustPackageScorecardService.timelineReferencesLabel),
    );
    expect(
      quality.indicators.map((entry) => entry.label),
      contains(TrustPackageScorecardService.narrativeReferencesLabel),
    );
  });

  testWidgets('Home readiness does not label kind as supporting context',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showEvidenceMapReadinessSheet(
                  context: context,
                  readiness: const EvidenceMapReadiness(
                    hasEvidence: true,
                    hasChronology: true,
                    hasSupportingContext: false,
                    hasConnections: false,
                  ),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Supporting context'), findsNothing);
    expect(find.text('Additional evidence'), findsOneWidget);
  });

  group('Founder scenarios', () {
    test('A. Incident isolation — scoped lists never mix A into B', () {
      final a = _item(id: 'photo-a', incidentId: 'inc-A');
      final b = _item(id: 'photo-b', incidentId: 'inc-B');
      final scopedB = InvestigateIncidentScope.evidence([a, b], 'inc-B');
      expect(scopedB.map((item) => item.id), ['photo-b']);
      expect(
        InvestigateIncidentScope.sessionMatchesBound('inc-B', 'inc-A'),
        isFalse,
      );
    });

    test('B. Matter RELATED remains Suggested Relationship', () {
      final photo = _item(id: 'p1', incidentId: 'inc-B');
      final video = _item(
        id: 'v1',
        incidentId: 'inc-B',
        kind: WorkspaceEvidenceKind.video,
      );
      final matter = EvidenceRelationship(
        id: 'rel-matter',
        sourceEvidenceId: 'p1',
        targetEvidenceId: 'v1',
        type: RelationshipType.relatedTo,
        createdAt: DateTime(2026, 8, 15),
        source: 'ai',
        reason: 'Related because both mention the same vehicle.',
      );
      expect(EvidenceSemantics.isSuggestedRelated(matter), isTrue);
      expect(
        EvidenceSemantics.structurallySupports(
          child: video,
          parentId: photo.id,
          relationships: [matter],
        ),
        isFalse,
      );
      final presentation = ConnectionsPresentationMapper.build(
        incidentId: 'inc-B',
        items: [photo, video],
        relationships: [matter],
        collections: const [],
        groupNodes: const [],
        suggestions: [
          RelationshipSuggestion(
            id: 'sug-matter',
            incidentId: 'inc-B',
            sourceEvidenceId: 'p1',
            targetEvidenceId: 'v1',
            relationshipType: RelationshipType.relatedTo.name,
            confidence: 0.4,
            reason: 'Related because both mention the same vehicle.',
            source: RelationshipSuggestionSource.ai,
            status: RelationshipSuggestionStatus.suggested,
            createdAt: DateTime(2026, 8, 15),
          ),
        ],
      );
      expect(presentation.supporting, isEmpty);
      expect(presentation.suggested, isNotEmpty);
      expect(
        presentation.suggested.single.label.toLowerCase(),
        contains('suggested relationship'),
      );
      expect(
        presentation.suggested.single.kind,
        ConnectionsPairKind.suggested,
      );
    });

    test('C. Photo + Video + Voice produce primary count 3', () {
      final items = [
        _item(id: 'photo', incidentId: 'inc-B'),
        _item(
          id: 'video',
          incidentId: 'inc-B',
          kind: WorkspaceEvidenceKind.video,
        ),
        _item(
          id: 'voice',
          incidentId: 'inc-B',
          kind: WorkspaceEvidenceKind.voice,
        ),
      ];
      expect(EvidenceSemantics.primaryChronologyCount(items), 3);
      expect(items.where((item) => item.isSupportingEvidence), isEmpty);
    });

    testWidgets('D. Trust referential checks do not imply incident complete',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      final controller = _controllerFor(id: 'inc-B', title: 'Beta');
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      final package = const DefaultTrustPackageAssembler().assemble(
        controller.aggregate,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TrustPackagePreview(package: package),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Timeline Complete'), findsNothing);
      expect(find.text('Narrative Complete'), findsNothing);
      expect(find.text('Incident complete'), findsNothing);
      expect(
        find.text(TrustPackageScorecardService.timelineReferencesLabel),
        findsWidgets,
      );
    });
  });
}
