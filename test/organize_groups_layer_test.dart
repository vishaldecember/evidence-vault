import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/theme/organize_visuals.dart';
import 'package:evidence_vault/widgets/common/modern_art_material.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_groups_modal.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime at,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: kind.label,
    lastPreservedAt: at,
    capturedAt: kind.isPrimaryChronology ? at : null,
    recordedAt: kind.isPrimaryChronology ? null : at,
    contentHash: 'hash-$id',
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: 'inc-groups-layer',
  );
}

CurrentIncident _incident({
  required List<WorkspaceEvidenceItem> evidence,
  List<EvidenceCollection> collections = const [],
}) {
  return CurrentIncident(
    id: 'inc-groups-layer',
    title: 'Case',
    status: IncidentStatus.active,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    manuallyComplete: false,
    journeyStage: JourneyStage.building,
    captureProgressPercent: 0,
    timelineAnchorCount: evidence.length,
    relationshipGroupCount: 0,
    narrativeEventCount: 0,
    evidence: evidence,
    journeyEvidence: evidence,
    relationshipGroups: const [],
    evidenceCollections: collections,
    trustPackageReady: evidence.isNotEmpty,
    trustPackageProgressPercent: 40,
  );
}

Future<void> _pumpOrganize(
  WidgetTester tester, {
  required CurrentIncident incident,
  List<String> orderedCapturedEvidenceIds = const [],
  VoidCallback? onCreateGroup,
  ValueChanged<WorkspaceEvidenceItem>? onEvidenceSelected,
  ValueChanged<WorkspaceCaptureMode>? onAddOrganizeContext,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizeWorkspaceView(
          incident: incident,
          orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
          onEvidenceSelected: onEvidenceSelected ?? (_) {},
          onCreateGroup: onCreateGroup,
          onAddOrganizeContext: onAddOrganizeContext ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final t0 = DateTime.utc(2026, 8, 24, 10);

  List<WorkspaceEvidenceItem> moments(int count) {
    return [
      for (var i = 0; i < count; i++)
        _item(
          id: 'm$i',
          kind: WorkspaceEvidenceKind.image,
          at: t0.add(Duration(minutes: i)),
        ),
    ];
  }

  testWidgets('Groups card is not inside the chronology scroll view', (
    tester,
  ) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: moments(3)),
      orderedCapturedEvidenceIds: const ['m0', 'm1', 'm2'],
    );

    expect(
      find.descendant(
        of: find.byKey(OrganizeWorkspaceView.viewKey),
        matching: find.byKey(OrganizeWorkspaceView.groupsKey),
      ),
      findsNothing,
    );
    expect(find.byKey(OrganizeWorkspaceView.groupsLayerKey), findsOneWidget);
    expect(find.byKey(OrganizeWorkspaceView.groupsKey), findsOneWidget);
  });

  testWidgets('collapsed Groups peeks with only Groups title visible', (
    tester,
  ) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: moments(2)),
      orderedCapturedEvidenceIds: const ['m0', 'm1'],
    );

    expect(
      find.byKey(OrganizeWorkspaceView.groupsPeekActionKey),
      findsOneWidget,
    );
    expect(find.text(OrganizeWorkspaceView.groupsTitle), findsWidgets);
    final card = tester.getRect(find.byKey(OrganizeWorkspaceView.groupsKey));
    expect(card.height, closeTo(OrganizeWorkspaceView.groupsPeekExtent, 1));
    expect(find.text('Person / Participant'), findsNothing);
    expect(find.text('Create Group'), findsNothing);
    expect(find.byKey(const Key('organize_create_group')), findsNothing);
  });

  testWidgets('Groups+ sits on the Incident title row', (tester) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: moments(2)),
      orderedCapturedEvidenceIds: const ['m0', 'm1'],
    );

    final title = tester.getRect(
      find.byKey(const Key('organize_incident_title')),
    );
    final plus = tester.getRect(
      find.byKey(OrganizeWorkspaceView.groupsPlusKey),
    );
    expect(plus.left, greaterThan(title.right));
    expect((title.center.dy - plus.center.dy).abs(), lessThan(28));
  });

  testWidgets('Groups layer does not move when chronology scrolls', (
    tester,
  ) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: moments(12)),
      orderedCapturedEvidenceIds: [for (var i = 0; i < 12; i++) 'm$i'],
    );

    final groups = find.byKey(OrganizeWorkspaceView.groupsKey);
    final plus = find.byKey(OrganizeWorkspaceView.groupsPlusKey);
    final originGroups = tester.getTopLeft(groups);
    final originPlus = tester.getTopLeft(plus);

    await tester.drag(
      find.byKey(OrganizeWorkspaceView.viewKey),
      const Offset(0, -420),
    );
    await tester.pump();

    expect(tester.getTopLeft(groups), originGroups);
    expect(tester.getTopLeft(plus), originPlus);
  });

  testWidgets('tapping Groups peeks expands the 4-group matrix below title', (
    tester,
  ) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: moments(2)),
      orderedCapturedEvidenceIds: const ['m0', 'm1'],
    );

    final titleBottom = tester
        .getRect(find.byKey(const Key('organize_incident_title')))
        .bottom;
    await tester.tap(find.byKey(OrganizeWorkspaceView.groupsPeekActionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    final card = tester.getRect(find.byKey(OrganizeWorkspaceView.groupsKey));
    final toolbar = tester.getRect(
      find.byKey(OrganizeWorkspaceView.addContextBarKey),
    );
    expect(card.height, closeTo(OrganizeWorkspaceView.groupsExpandedExtent, 1));
    expect(card.top, greaterThan(titleBottom + 8));
    expect(card.bottom, lessThanOrEqualTo(toolbar.top + 0.5));
    expect(
      toolbar.top - card.bottom,
      closeTo(OrganizeWorkspaceView.groupsToolbarGap, 1),
    );
    expect(find.text('Person / Participant'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Relationship'), findsOneWidget);
    expect(find.text('Pattern'), findsOneWidget);
    for (final category in OrganizeGroupCategory.values) {
      final tile = find.byKey(OrganizeGroupsModal.lensKey(category));
      expect(tile, findsOneWidget);
      final rect = tester.getRect(tile);
      expect(rect.bottom, lessThanOrEqualTo(toolbar.top + 0.5));
      expect(rect.bottom, lessThanOrEqualTo(card.bottom + 0.5));
    }
  });

  testWidgets('tapping Groups again slides the card back to peek', (
    tester,
  ) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: moments(2)),
      orderedCapturedEvidenceIds: const ['m0', 'm1'],
    );

    await tester.tap(find.byKey(OrganizeWorkspaceView.groupsPeekActionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(
      tester.getRect(find.byKey(OrganizeWorkspaceView.groupsKey)).height,
      closeTo(OrganizeWorkspaceView.groupsExpandedExtent, 1),
    );

    await tester.tap(find.byKey(OrganizeWorkspaceView.groupsPeekActionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(
      tester.getRect(find.byKey(OrganizeWorkspaceView.groupsKey)).height,
      closeTo(OrganizeWorkspaceView.groupsPeekExtent, 1),
    );
    expect(find.text('Person / Participant'), findsNothing);
  });

  testWidgets('tapping the Organize workspace collapses an open Groups card', (
    tester,
  ) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: moments(2)),
      orderedCapturedEvidenceIds: const ['m0', 'm1'],
    );

    await tester.tap(find.byKey(OrganizeWorkspaceView.groupsPeekActionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(
      tester.getRect(find.byKey(OrganizeWorkspaceView.groupsKey)).height,
      closeTo(OrganizeWorkspaceView.groupsExpandedExtent, 1),
    );

    final workspace = tester.getRect(
      find.byKey(OrganizeWorkspaceView.workspaceDismissKey),
    );
    await tester.tapAt(Offset(workspace.left + 16, workspace.top + 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(
      tester.getRect(find.byKey(OrganizeWorkspaceView.groupsKey)).height,
      closeTo(OrganizeWorkspaceView.groupsPeekExtent, 1),
    );
    expect(find.text('Person / Participant'), findsNothing);
  });

  testWidgets('workspace tap does nothing while Groups is collapsed', (
    tester,
  ) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: moments(2)),
      orderedCapturedEvidenceIds: const ['m0', 'm1'],
    );

    final before = tester.getRect(find.byKey(OrganizeWorkspaceView.groupsKey));
    final workspace = tester.getRect(
      find.byKey(OrganizeWorkspaceView.workspaceDismissKey),
    );
    await tester.tapAt(Offset(workspace.left + 16, workspace.top + 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(
      tester.getRect(find.byKey(OrganizeWorkspaceView.groupsKey)),
      before,
    );
    expect(find.text('Person / Participant'), findsNothing);
  });

  testWidgets('open Groups still lets Voice fire and Groups stay tappable', (
    tester,
  ) async {
    final selected = <WorkspaceCaptureMode>[];
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: moments(2)),
      orderedCapturedEvidenceIds: const ['m0', 'm1'],
      onAddOrganizeContext: selected.add,
    );

    await tester.tap(find.byKey(OrganizeWorkspaceView.groupsPeekActionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    await tester.tap(find.text('Voice'));
    await tester.pump();
    expect(selected, [WorkspaceCaptureMode.voice]);

    await tester.tap(find.byKey(OrganizeWorkspaceView.groupsPeekActionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(
      tester.getRect(find.byKey(OrganizeWorkspaceView.groupsKey)).height,
      closeTo(OrganizeWorkspaceView.groupsPeekExtent, 1),
    );
  });

  testWidgets('rapid Groups and workspace taps settle at peek', (tester) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: moments(2)),
      orderedCapturedEvidenceIds: const ['m0', 'm1'],
    );

    final peek = find.byKey(OrganizeWorkspaceView.groupsPeekActionKey);
    final workspace = tester.getRect(
      find.byKey(OrganizeWorkspaceView.workspaceDismissKey),
    );
    await tester.tap(peek);
    await tester.pumpAndSettle();
    await tester.tapAt(Offset(workspace.left + 16, workspace.top + 8));
    await tester.pumpAndSettle();
    await tester.tap(peek);
    await tester.pumpAndSettle();
    await tester.tap(peek);
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(OrganizeWorkspaceView.groupsKey)).height,
      closeTo(OrganizeWorkspaceView.groupsPeekExtent, 1),
    );
  });

  testWidgets('Groups card shows soft atmosphere artwork behind matrix', (
    tester,
  ) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: moments(2)),
      orderedCapturedEvidenceIds: const ['m0', 'm1'],
    );

    expect(
      find.descendant(
        of: find.byKey(OrganizeWorkspaceView.groupsKey),
        matching: find.byType(GroupsAtmosphereSurface),
      ),
      findsOneWidget,
    );
    expect(find.byKey(GroupsAtmosphereSurface.layerKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(GroupsAtmosphereSurface.layerKey),
        matching: find.image(const AssetImage(GroupsAtmosphereSurface.asset)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('toolbar uses solid chrome atmosphere', (tester) async {
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: moments(2)),
      orderedCapturedEvidenceIds: const ['m0', 'm1'],
    );

    expect(
      find.descendant(
        of: find.byKey(OrganizeWorkspaceView.addContextBarKey),
        matching: find.byKey(ChromeAtmosphereSurface.solidLayerKey),
      ),
      findsOneWidget,
    );
  });

  testWidgets('chronology gutter time is white; canvas is not wallpapered', (
    tester,
  ) async {
    final evidence = moments(1);
    await _pumpOrganize(
      tester,
      incident: _incident(evidence: evidence),
      orderedCapturedEvidenceIds: const ['m0'],
    );

    final clock = OrganizeChronologyClock.gutterLabel(item: evidence.first);
    final gutter = tester.widget<Text>(find.text(clock).first);
    expect(gutter.style?.color, OrganizeVisuals.clock);
    expect(
      find.descendant(
        of: find.byKey(OrganizeWorkspaceView.structureKey),
        matching: find.byType(GroupsAtmosphereSurface),
      ),
      findsNothing,
    );
  });
}
