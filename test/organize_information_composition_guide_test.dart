import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/organize/organize_context_anchor.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/workspace/evidence_composition_guide.dart';
import 'package:evidence_vault/widgets/workspace/organize_composition_matrix.dart';
import 'package:evidence_vault/widgets/workspace/organize_readiness_guide.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:evidence_vault/widgets/workspace/product_concept_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _ev({
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
    incidentId: 'inc-compose',
  );
}

CurrentIncident _incident({
  required List<WorkspaceEvidenceItem> evidence,
}) {
  return CurrentIncident(
    id: 'inc-compose',
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
    evidenceCollections: const [],
    trustPackageReady: evidence.isNotEmpty,
    trustPackageProgressPercent: 40,
  );
}

Future<void> _openInformationPanel(
  WidgetTester tester, {
  required CurrentIncident incident,
  List<String> orderedCapturedEvidenceIds = const [],
  Set<String> organizeCreatedIds = const {},
  List<OrganizeContextAnchor> contextAnchors = const [],
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrganizeWorkspaceView(
          incident: incident,
          orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
          organizeCreatedIds: organizeCreatedIds,
          contextAnchors: contextAnchors,
          onEvidenceSelected: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  expect(find.byKey(OrganizeReadinessInfoButton.buttonKey), findsOneWidget);
  await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
  await tester.pumpAndSettle();
}

void main() {
  final t0 = DateTime.utc(2026, 8, 24, 10);
  final t1 = DateTime.utc(2026, 8, 24, 11);

  test('composition patterns encode + vs → without inventing chronology', () {
    expect(EvidenceCompositionGuide.compositions, hasLength(10));
    for (final pattern in EvidenceCompositionGuide.compositions) {
      if (pattern.sequential) {
        expect(pattern.label, contains('→'));
        expect(pattern.label, isNot(contains('+')));
      } else {
        expect(pattern.label, contains('+'));
        expect(pattern.label, isNot(contains('→')));
      }
    }
  });

  testWidgets(
    'Organize information panel shows Evidence Composition without mutating state',
    (tester) async {
      final photo = _ev(
        id: 'p1',
        kind: WorkspaceEvidenceKind.image,
        at: t0,
      );
      final note = _ev(
        id: 'n1',
        kind: WorkspaceEvidenceKind.note,
        at: t1,
      );
      const anchors = [
        OrganizeContextAnchor(
          contextEvidenceId: 'n1',
          capturedEvidenceId: 'p1',
        ),
      ];
      await _openInformationPanel(
        tester,
        incident: _incident(evidence: [photo, note]),
        orderedCapturedEvidenceIds: const ['p1'],
        organizeCreatedIds: const {'n1'},
        contextAnchors: anchors,
      );

      expect(find.text(EvidenceCompositionGuide.title), findsOneWidget);
      expect(find.byKey(EvidenceCompositionGuide.guideKey), findsOneWidget);
      expect(EvidenceCompositionGuide.compositions, hasLength(10));
      for (final pattern in EvidenceCompositionGuide.compositions) {
        expect(find.text(pattern.label), findsOneWidget);
        if (pattern.sequential) {
          expect(pattern.label, contains(EvidenceCompositionGuide.sequenceJoiner));
          expect(
            find.text(
              pattern.modalities
                  .map((modality) => modality.label)
                  .join(EvidenceCompositionGuide.plusJoiner),
            ),
            findsNothing,
          );
        } else {
          expect(pattern.label, contains(EvidenceCompositionGuide.plusJoiner));
          expect(
            find.text(
              pattern.modalities
                  .map((modality) => modality.label)
                  .join(EvidenceCompositionGuide.sequenceJoiner),
            ),
            findsNothing,
          );
        }
      }

      expect(find.byKey(ProductConceptChart.chartKey), findsOneWidget);
      expect(find.text(ProductConceptCopy.title), findsOneWidget);
      expect(find.text(ProductConceptCopy.organizeTitle), findsOneWidget);
      expect(find.byKey(ProductConceptChart.organizeKey), findsOneWidget);
      expect(find.byKey(OrganizeReadinessGuideSheet.sheetKey), findsOneWidget);
      expect(find.byKey(OrganizeReadinessInfoButton.buttonKey), findsOneWidget);
      expect(find.byKey(OrganizeCompositionMatrix.matrixKey), findsNothing);
      expect(
        find.byKey(OrganizeReadinessGuideSheet.compositionKey),
        findsNothing,
      );
      expect(find.textContaining('This incident'), findsNothing);

      expect(anchors, hasLength(1));
      expect(anchors.single.contextEvidenceId, 'n1');
      expect(anchors.single.capturedEvidenceId, 'p1');
      expect(photo.id, 'p1');
      expect(photo.contentHash, 'hash-p1');
      expect(note.id, 'n1');
      expect(note.contentHash, 'hash-n1');
    },
  );

  testWidgets(
    'opening Evidence Composition does not mutate evidence or context',
    (tester) async {
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(id: 'inc-compose', title: 'Case'),
      );
      controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
      final store = controller.aggregate.store;
      final idsBefore = [for (final item in store.capturedEvidence) item.id];
      final hashesBefore = [
        for (final item in store.capturedEvidence) item.contentHash,
      ];
      final capturedBefore = [
        for (final item in store.capturedEvidence) item.capturedAt,
      ];
      final sequenceBefore = [
        for (final anchor in controller.timelineRepository.anchors)
          '${anchor.capturedEvidenceId}:${anchor.sequenceOrder}',
      ];
      final contextBefore = [
        for (final anchor in controller.organizeContextAnchors)
          '${anchor.contextEvidenceId}:${anchor.capturedEvidenceId}',
      ];
      final statusBefore = controller.organizeReadiness.status;

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizeWorkspaceView(
              incident: controller.currentIncident,
              orderedCapturedEvidenceIds:
                  controller.timelineRepository.orderedCapturedEvidenceIds(),
              organizeCreatedIds: controller.organizeCreatedEvidenceIds,
              contextAnchors: controller.organizeContextAnchors,
              onEvidenceSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
      await tester.pumpAndSettle();

      expect(find.text(EvidenceCompositionGuide.title), findsOneWidget);
      expect(controller.organizeReadiness.status, statusBefore);
      expect([for (final item in store.capturedEvidence) item.id], idsBefore);
      expect(
        [for (final item in store.capturedEvidence) item.contentHash],
        hashesBefore,
      );
      expect(
        [for (final item in store.capturedEvidence) item.capturedAt],
        capturedBefore,
      );
      expect(
        [
          for (final anchor in controller.timelineRepository.anchors)
            '${anchor.capturedEvidenceId}:${anchor.sequenceOrder}',
        ],
        sequenceBefore,
      );
      expect(
        [
          for (final anchor in controller.organizeContextAnchors)
            '${anchor.contextEvidenceId}:${anchor.capturedEvidenceId}',
        ],
        contextBefore,
      );
    },
  );
}
