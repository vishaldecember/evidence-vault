import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/engines/enrichment_engine.dart';
import 'package:evidence_vault/engines/investigation_coaching_engine.dart';
import 'package:evidence_vault/models/evidence_artifact_model.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/investigation_workspace_tab.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/navigation/library_incident_routes.dart';
import 'package:evidence_vault/repositories/narrative_event_repository.dart';
import 'package:evidence_vault/services/narrative_validation_service.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_preview_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/attachment_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/photo_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/text_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/video_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/voice_evidence_renderer.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/widgets/reconstruction/evidence_inspector_panel.dart';
import 'package:evidence_vault/widgets/workspace/evidence_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void expectIncident(String expected, String actual) {
  if (expected != actual) {
    fail(
      'EXPECTED INCIDENT:\n$expected\n\nACTUAL INCIDENT:\n$actual',
    );
  }
}

WorkspaceEvidenceController _controllerFor({
  required String id,
  required String title,
  int photos = 0,
  int videos = 0,
  int voices = 0,
}) {
  final controller = WorkspaceEvidenceController(
    aggregate: IncidentAggregate.shell(id: id, title: title),
  );
  for (var i = 0; i < photos; i++) {
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
  }
  for (var i = 0; i < videos; i++) {
    controller.preserveEvidence(WorkspaceCaptureMode.video);
  }
  for (var i = 0; i < voices; i++) {
    controller.preserveEvidence(WorkspaceCaptureMode.voice);
  }
  return controller;
}

Future<void> _openInspector(
  WidgetTester tester, {
  required WorkspaceEvidenceController controller,
  required WorkspaceEvidenceItem evidence,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(412, 915));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return TextButton(
            onPressed: () {
              showInvestigationEvidenceInspectorModal(
                context: context,
                evidence: evidence,
                controller: controller,
                orderedEvidence: evidenceInspectorOrder(
                  controller.journeyEvidenceItems,
                  incidentId: controller.currentIncident.id,
                ),
              );
            },
            child: const Text('Open inspector'),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('Open inspector'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    WorkspaceSession.instance.reset();
    InMemoryNarrativeEventRepository.resetForTests();
  });

  group('LibraryIncidentRoutes', () {
    test('Continue Investigation → Investigate Timeline', () {
      expect(
        LibraryIncidentRoutes.continueInvestigationStage,
        InvestigationMethodologyStage.investigation,
      );
      expect(
        LibraryIncidentRoutes.continueInvestigationTab,
        InvestigationWorkspaceTab.timeline,
      );
    });

    test('View Evidence Map → Organize, not Investigate Connections', () {
      expect(
        LibraryIncidentRoutes.viewEvidenceMapStage,
        InvestigationMethodologyStage.evidence,
      );
      expect(
        LibraryIncidentRoutes.viewEvidenceMapStage,
        isNot(InvestigationMethodologyStage.investigation),
      );
      expect(
        LibraryIncidentRoutes.continueOrganizingStage,
        LibraryIncidentRoutes.viewEvidenceMapStage,
      );
    });

    test('card body and Continue Preserving both stay on the same incident workspace',
        () {
      expect(
        LibraryIncidentRoutes.cardBodyStage,
        InvestigationMethodologyStage.capture,
      );
      expect(
        LibraryIncidentRoutes.continuePreservingStage,
        InvestigationMethodologyStage.capture,
      );
      expect(
        LibraryIncidentRoutes.continueOrganizingStage,
        InvestigationMethodologyStage.evidence,
      );
      expect(
        LibraryIncidentRoutes.continueTrustStage,
        InvestigationMethodologyStage.trustPackage,
      );
    });
  });

  group('Stale shell state', () {
    test('switching incidents does not keep the previous incident stage',
        () async {
      final session = WorkspaceSession.instance;
      final first = _controllerFor(id: 'inc-A', title: 'Alpha', photos: 1);
      session.controller = first;
      session.setActiveStage(InvestigationMethodologyStage.trustPackage);

      final opened = await session.openIncident('inc-B');
      expect(opened, isTrue);
      expectIncident('inc-B', session.controller.currentIncident.id);
      expect(
        session.activeMethodologyStage,
        InvestigationMethodologyStage.capture,
      );
      expect(
        session.activeInvestigationTab,
        InvestigationWorkspaceTab.timeline,
      );
    });

    test('reopening the same incident via card body does not use leftover stage',
        () async {
      final session = WorkspaceSession.instance;
      final first = _controllerFor(id: 'inc-A', title: 'Alpha', photos: 1);
      session.controller = first;
      session.setActiveStage(InvestigationMethodologyStage.trustPackage);

      final opened = await session.openIncident('inc-A');
      expect(opened, isTrue);
      expectIncident('inc-A', session.controller.currentIncident.id);
      expect(
        session.activeMethodologyStage,
        InvestigationMethodologyStage.trustPackage,
      );
      expect(
        LibraryIncidentRoutes.cardBodyStage,
        InvestigationMethodologyStage.capture,
      );
      expect(
        LibraryIncidentRoutes.cardBodyStage,
        isNot(session.activeMethodologyStage),
      );
    });
  });

  group('Inspector playback registry', () {
    test('playable and non-playable kinds resolve to the existing Inspector renderers',
        () {
      expect(
        EvidencePreviewRegistry.resolve(EvidenceArtifactType.video),
        isA<VideoEvidenceRenderer>(),
      );
      expect(
        EvidencePreviewRegistry.resolve(EvidenceArtifactType.voiceRecording),
        isA<VoiceEvidenceRenderer>(),
      );
      expect(
        EvidencePreviewRegistry.resolve(EvidenceArtifactType.photo),
        isA<PhotoEvidenceRenderer>(),
      );
      expect(
        EvidencePreviewRegistry.resolve(EvidenceArtifactType.document),
        isA<AttachmentEvidenceRenderer>(),
      );
      expect(
        EvidencePreviewRegistry.resolve(EvidenceArtifactType.note),
        isA<TextEvidenceRenderer>(),
      );
    });
  });

  group('Inspector convergence', () {
    testWidgets('the existing Inspector is the only evidence-detail surface',
        (tester) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 1,
        videos: 1,
      );
      final incidentId = controller.currentIncident.id;
      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.byType(InvestigationEvidenceInspectorModal), findsOneWidget);
      expect(find.text('Evidence Inspector'), findsOneWidget);
      expect(find.byType(EvidenceInspectorPanel), findsNothing);
      expect(find.byType(EvidenceDetailSheet), findsNothing);
      expectIncident(incidentId, controller.currentIncident.id);
      expect(
        evidenceInspectorOrder(
          controller.journeyEvidenceItems,
          incidentId: incidentId,
        ).map((item) => item.incidentId).toSet(),
        {incidentId},
      );
    });

    testWidgets('video Inspector preview is a playable video surface',
        (tester) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        videos: 1,
      );
      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.single,
      );
      expect(find.byType(InvestigationEvidenceInspectorModal), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsWidgets);
    });

    testWidgets('voice Inspector preview is a playable audio surface',
        (tester) async {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        voices: 1,
      );
      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.single,
      );
      expect(
        find.byKey(const Key('evidence_inspector_audio_player')),
        findsOneWidget,
      );
    });
  });

  group('Coaching predicates vs visible evidence', () {
    test('three chronology items are not reported as one primary captured', () {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 1,
        videos: 1,
        voices: 1,
      );
      final items = controller.currentIncident.evidence;
      final primary = EnrichmentEngine.primaryEvidence(items);
      expect(items, hasLength(3));
      expect(primary, hasLength(3));

      final linkedSupporting = items.where(
        (item) => item.parentEvidenceId != null && item.parentEvidenceId!.isNotEmpty,
      );
      expect(linkedSupporting, isEmpty);
      expect(primary.length, 3);

      for (final event in controller.narrativeEvents) {
        final validation = event.validation;
        expect(
          validation.recommendations,
          isNot(contains('Only one primary evidence captured.')),
        );
        expect(
          validation.recommendations,
          isNot(contains('Capture additional evidence.')),
        );
        expect(
          validation.recommendations,
          isNot(contains('Missing supporting evidence')),
        );
        expect(
          validation.recommendations,
          isNot(contains('Missing contextual explanation.')),
        );
        expect(
          validation.recommendations,
          isNot(contains('Missing witness statement.')),
        );
        if (validation.recommendations.contains(
          NarrativeValidationService.recWitnessOptional,
        )) {
          expect(validation.recommendations.singleWhere((line) => line.contains('witness')),
              contains('may consider'));
        }
        if (validation.recommendations.contains(
          NarrativeValidationService.recSupportingDocumentOptional,
        )) {
          expect(
            validation.recommendations.firstWhere((line) => line.contains('supporting document')),
            contains('may consider'),
          );
        }
      }
    });

    test('supporting count is distinct from total and primary counts', () {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 1,
      );
      final photoId = controller.journeyEvidenceItems.single.id;
      controller.addContextTextNote(
        parentEvidenceId: photoId,
        text: 'Heard shouting.',
      );
      final items = controller.currentIncident.evidence;
      final primary = EnrichmentEngine.primaryEvidence(items);
      final linkedSupporting = items.where(
        (item) => item.parentEvidenceId != null && item.parentEvidenceId!.isNotEmpty,
      ).toList();

      expect(items.length, greaterThan(primary.length));
      expect(primary, hasLength(1));
      expect(linkedSupporting, hasLength(1));
      expect(items.length, primary.length + linkedSupporting.length);
    });

    test('location warning is omitted when coordinates exist', () {
      final item = WorkspaceEvidenceItem(
        id: 'photo',
        kind: WorkspaceEvidenceKind.image,
        title: 'Evidence photo',
        lastPreservedAt: DateTime(2026, 8, 14, 9, 13, 5),
        integrityVerified: true,
        verification: VerificationFactory.initial(),
        incidentId: 'inc-A',
        latitude: 28.2096,
        longitude: 83.9856,
      );
      final validation = NarrativeValidationService.validateEvent(
        displayEvidence: [item],
        supportingEvidence: const [],
        reconstructionNotes: const [],
        hasMissingReferencedEvidence: false,
        enrichmentContext: const EnrichmentContext(items: [], relationships: []),
      );
      expect(
        validation.recommendations,
        isNot(contains(NarrativeValidationService.recLocationMissing)),
      );
      expect(
        validation.recommendations,
        contains(NarrativeValidationService.recNoWrittenExplanation),
      );
    });

    test('coaching observations are traceable and do not overstate capture count',
        () {
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 1,
        videos: 1,
        voices: 1,
      );
      final items = InvestigationCoachingEngine.generate(
        InvestigationCoachingContext.fromController(controller),
      );
      expect(controller.enrichment.primaryEvidenceCount, 3);
      for (final item in items) {
        expect(item.fingerprint, isNotEmpty);
        expect(item.observation.toLowerCase(), isNot(contains('only one primary')));
        expect(item.observation, isNot(contains('This happened')));
        expect(item.observation, isNot(contains('Missing supporting evidence')));
      }
    });
  });

  group('Incident ownership', () {
    test('stage changes stay on the bound incident and create none', () {
      final session = WorkspaceSession.instance;
      final controller = _controllerFor(
        id: 'inc-A',
        title: 'Alpha Case',
        photos: 2,
      );
      final incidentId = controller.currentIncident.id;
      final count = controller.journeyEvidenceItems.length;
      session.controller = controller;

      session.setActiveStage(
        InvestigationMethodologyStage.investigation,
        investigationTab: InvestigationWorkspaceTab.connections,
      );
      expectIncident(incidentId, session.controller.currentIncident.id);

      session.setActiveStage(InvestigationMethodologyStage.evidence);
      expectIncident(incidentId, session.controller.currentIncident.id);

      session.setActiveStage(InvestigationMethodologyStage.trustPackage);
      expectIncident(incidentId, session.controller.currentIncident.id);
      expect(controller.journeyEvidenceItems, hasLength(count));
    });
  });
}
