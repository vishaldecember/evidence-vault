import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/evidence_inspector/inspector_atmosphere_background.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_groups_modal.dart';
import 'package:evidence_vault/widgets/workspace/organize_readiness_guide.dart';
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
    incidentId: 'inc-v3r',
  );
}

CurrentIncident _incident({required List<WorkspaceEvidenceItem> evidence}) {
  return CurrentIncident(
    id: 'inc-v3r',
    title: 'Street',
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
    evidenceCollections: const [],
    trustPackageReady: evidence.isNotEmpty,
    trustPackageProgressPercent: 40,
  );
}

Future<void> _pumpOrganize(
  WidgetTester tester, {
  required List<WorkspaceEvidenceItem> evidence,
  ValueChanged<WorkspaceCaptureMode>? onAddOrganizeContext,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizeWorkspaceView(
          incident: _incident(evidence: evidence),
          orderedCapturedEvidenceIds: [
            for (final item in evidence)
              if (item.kind.isPrimaryChronology) item.id,
          ],
          onEvidenceSelected: (_) {},
          onAddOrganizeContext: onAddOrganizeContext ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final t0 = DateTime(2026, 8, 26, 10);
  final photo = _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0);
  final video = _item(
    id: 'video',
    kind: WorkspaceEvidenceKind.video,
    at: t0.add(const Duration(minutes: 1)),
  );

  testWidgets(
    'A Captured evidence lane label is gone; Groups + is on the header',
    (tester) async {
      await _pumpOrganize(tester, evidence: [photo, video]);

      expect(
        find.text(OrganizeChronologyCanvas.capturedEvidenceLabel),
        findsNothing,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.capturedLaneHeaderKey),
        findsNothing,
      );
      expect(find.byKey(OrganizeWorkspaceView.groupsPlusKey), findsOneWidget);

      final control = tester.widget<Text>(
        find.descendant(
          of: find.byKey(OrganizeWorkspaceView.groupsPlusKey),
          matching: find.text('+'),
        ),
      );
      expect(control.style?.fontWeight, FontWeight.w700);
      expect(control.style?.decoration, TextDecoration.underline);

      final title = tester.getRect(
        find.byKey(const Key('organize_incident_title')),
      );
      final info = tester.getRect(
        find.byKey(OrganizeReadinessInfoButton.buttonKey),
      );
      final groups = tester.getRect(
        find.byKey(OrganizeWorkspaceView.groupsPlusKey),
      );
      expect(info.left, greaterThanOrEqualTo(title.right - 0.5));
      expect(groups.left, greaterThan(info.right));
      expect((title.center.dy - info.center.dy).abs(), lessThan(16));
      expect((title.center.dy - groups.center.dy).abs(), lessThan(28));
      expect(find.byKey(OrganizeWorkspaceView.groupsLayerKey), findsOneWidget);
    },
  );

  testWidgets('Groups + stays pinned while chronology scrolls', (tester) async {
    final many = <WorkspaceEvidenceItem>[
      for (var i = 0; i < 12; i++)
        _item(
          id: 'moment-$i',
          kind: WorkspaceEvidenceKind.image,
          at: t0.add(Duration(minutes: i)),
        ),
    ];
    await _pumpOrganize(tester, evidence: many);

    final plus = find.byKey(OrganizeWorkspaceView.groupsPlusKey);
    final overlay = find.byKey(OrganizeWorkspaceView.groupsPlusOverlayKey);
    expect(plus, findsOneWidget);
    expect(overlay, findsOneWidget);

    final origin = tester.getTopLeft(plus);
    await tester.drag(
      find.byKey(OrganizeWorkspaceView.viewKey),
      const Offset(0, -420),
    );
    await tester.pump();

    expect(tester.getTopLeft(plus), origin);
    expect(
      find.byKey(OrganizeWorkspaceView.groupsPlusOverlayKey),
      findsOneWidget,
    );

    await tester.tap(plus);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(OrganizeGroupsModal.modalKey), findsOneWidget);
  });

  testWidgets('B Groups + opens a translucent classification modal', (
    tester,
  ) async {
    await _pumpOrganize(tester, evidence: [photo, video]);

    await tester.tap(find.byKey(OrganizeWorkspaceView.groupsBrowseKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(OrganizeGroupsModal.modalKey), findsOneWidget);
    expect(find.byKey(OrganizeGroupsModal.scrimKey), findsOneWidget);
    expect(find.byKey(OrganizeGroupsModal.panelKey), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);
    expect(find.text('People / Participants'), findsOneWidget);
    expect(find.text('Locations'), findsOneWidget);
    expect(find.text('Relationships'), findsOneWidget);
    expect(find.text('Patterns'), findsOneWidget);
    expect(find.byKey(OrganizeGroupsModal.matrixKey), findsOneWidget);
    expect(find.byKey(OrganizeGroupsModal.customGroupBarKey), findsNothing);
    expect(
      find.text('Optional interpretive layer. Chronology is unchanged.'),
      findsNothing,
    );
  });

  testWidgets('E Groups modal hides the Add context toolbar until dismissed', (
    tester,
  ) async {
    final tapped = <WorkspaceCaptureMode>[];
    await _pumpOrganize(
      tester,
      evidence: [photo, video],
      onAddOrganizeContext: tapped.add,
    );

    expect(find.byKey(OrganizeWorkspaceView.addContextBarKey), findsOneWidget);
    final toolbarRect = tester.getRect(
      find.byKey(OrganizeWorkspaceView.addContextBarKey),
    );

    await tester.tap(find.byKey(OrganizeWorkspaceView.groupsBrowseKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(OrganizeGroupsModal.modalKey), findsOneWidget);
    expect(find.byKey(OrganizeWorkspaceView.addContextBarKey), findsNothing);

    await tester.tapAt(toolbarRect.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tapped, isEmpty);

    if (find.byKey(OrganizeGroupsModal.modalKey).evaluate().isNotEmpty) {
      final scrim = tester.getRect(find.byKey(OrganizeGroupsModal.scrimKey));
      await tester.tapAt(Offset(scrim.center.dx, scrim.top + 12));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.byKey(OrganizeGroupsModal.modalKey), findsNothing);
    expect(find.byKey(OrganizeWorkspaceView.addContextBarKey), findsOneWidget);
  });

  testWidgets(
    'C selecting a group type does not mutate chronology or collections',
    (tester) async {
      final incident = _incident(evidence: [photo, video]);
      final idsBefore = [for (final item in incident.journeyEvidence) item.id];
      final hashesBefore = [
        for (final item in incident.journeyEvidence) item.contentHash,
      ];
      final collectionsBefore = incident.evidenceCollections.length;

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizeWorkspaceView(
              incident: incident,
              orderedCapturedEvidenceIds: const ['photo', 'video'],
              onEvidenceSelected: (_) {},
              onAddOrganizeContext: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(OrganizeWorkspaceView.groupsBrowseKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Locations'));
      await tester.pump();

      expect([for (final item in incident.journeyEvidence) item.id], idsBefore);
      expect([
        for (final item in incident.journeyEvidence) item.contentHash,
      ], hashesBefore);
      expect(incident.evidenceCollections.length, collectionsBefore);
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('video')),
        findsOneWidget,
      );
    },
  );

  testWidgets('D Inspector retains a soft 3D atmosphere behind content', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));
    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: [photo]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    showInvestigationEvidenceInspectorModal(
                      context: context,
                      evidence: photo,
                      controller: controller,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(InspectorAtmosphereBackground), findsOneWidget);
    expect(find.byKey(InspectorAtmosphereBackground.layerKey), findsOneWidget);
  });
}
