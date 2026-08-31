import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/workspace_evidence_repository.dart';
import 'package:evidence_vault/services/workspace_coaching_service.dart';
import 'package:evidence_vault/theme/app_colors.dart';
import 'package:evidence_vault/widgets/workspace/incident_journey_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Semantic evidence timeline', () {
    test('note and file captures stay chronological without silent parent', () {
      final controller = WorkspaceEvidenceController();

      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.video);

      controller.preserveEvidence(WorkspaceCaptureMode.note);
      controller.preserveEvidence(WorkspaceCaptureMode.file);
      controller.preserveEvidence(WorkspaceCaptureMode.voice);
      controller.preserveEvidence(WorkspaceCaptureMode.note);

      final journey = controller.currentIncident.journeyEvidence;
      expect(journey, hasLength(6));
      expect(
        journey.map((item) => item.kind).toList(),
        [
          WorkspaceEvidenceKind.image,
          WorkspaceEvidenceKind.video,
          WorkspaceEvidenceKind.note,
          WorkspaceEvidenceKind.attachment,
          WorkspaceEvidenceKind.voice,
          WorkspaceEvidenceKind.note,
        ],
      );

      // Capture-bar notes/files are dedicated evidence — not auto-parented
      // onto the latest voice/photo (Sprint 6B Task 3.1 recovery).
      expect(journey[2].parentEvidenceId, isNull);
      expect(journey[3].parentEvidenceId, isNull);
      expect(journey[5].parentEvidenceId, isNull);

      expect(journey[0].isPrimaryChronologyEvidence, isTrue);
      expect(journey[1].isPrimaryChronologyEvidence, isTrue);
      expect(journey[2].isSupportingEvidence, isTrue);
      expect(journey[3].isSupportingEvidence, isTrue);
      expect(journey[4].isPrimaryChronologyEvidence, isTrue);
      expect(journey[5].isSupportingEvidence, isTrue);
    });

    test('explicit linkToNearestPrimary still attaches supporting context',
        () async {
      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.video);
      final videoId = controller.currentIncident.journeyEvidence
          .firstWhere((item) => item.kind == WorkspaceEvidenceKind.video)
          .id;

      await controller.preserveEvidenceWithMedia(
        mode: WorkspaceCaptureMode.note,
        noteText: 'Linked note',
        linkToNearestPrimary: true,
      );

      final note = controller.currentIncident.journeyEvidence
          .firstWhere((item) => item.kind == WorkspaceEvidenceKind.note);
      expect(note.parentEvidenceId, videoId);
      expect(note.relationshipType, RelationshipType.supports);
    });

    testWidgets('connectors are orange into primary and blue into supporting',
        (tester) async {
      final journeyEvidence = WorkspaceEvidenceRepository.journeySequenceFromItems([
        WorkspaceEvidenceItem(
          id: 'photo',
          kind: WorkspaceEvidenceKind.image,
          title: 'Photo',
          lastPreservedAt: DateTime(2026, 8, 5, 9),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
        ),
        WorkspaceEvidenceItem(
          id: 'video',
          kind: WorkspaceEvidenceKind.video,
          title: 'Video',
          lastPreservedAt: DateTime(2026, 8, 5, 10),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
        ),
        WorkspaceEvidenceItem(
          id: 'note',
          kind: WorkspaceEvidenceKind.note,
          title: 'Note',
          lastPreservedAt: DateTime(2026, 8, 5, 11),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
          parentEvidenceId: 'video',
          relationshipType: RelationshipType.supports,
          isContextual: true,
          relatedEvidenceIds: const {'video'},
        ),
        WorkspaceEvidenceItem(
          id: 'file',
          kind: WorkspaceEvidenceKind.attachment,
          title: 'PDF',
          lastPreservedAt: DateTime(2026, 8, 5, 12),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
          parentEvidenceId: 'video',
          relationshipType: RelationshipType.supports,
          isContextual: true,
          relatedEvidenceIds: const {'video'},
        ),
        WorkspaceEvidenceItem(
          id: 'voice',
          kind: WorkspaceEvidenceKind.voice,
          title: 'Voice',
          lastPreservedAt: DateTime(2026, 8, 5, 13),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncidentJourneyCard(
              currentStage: JourneyStage.building,
              currentCoaching: WorkspaceCoachingService.coachingFor(
                primaryEvidenceCount: 3,
                enrichedEvidenceCount: 1,
                enrichmentPercentage: 33,
              ),
              journeyEvidence: journeyEvidence,
              isOrganizeStage: true,
            ),
          ),
        ),
      );

      final arrows = tester
          .widgetList<Icon>(find.byIcon(Icons.arrow_forward_rounded))
          .toList();
      expect(arrows, hasLength(4));

      Color? solid(Color? color) => color?.withValues(alpha: 1);

      // photo → video (orange), video → note (blue), note → file (blue),
      // file → voice (orange)
      expect(
        solid(arrows[0].color),
        solid(AppColors.timelineChronology.withValues(alpha: 0.9)),
      );
      expect(
        solid(arrows[1].color),
        solid(AppColors.timelineSupporting.withValues(alpha: 0.9)),
      );
      expect(
        solid(arrows[2].color),
        solid(AppColors.timelineSupporting.withValues(alpha: 0.9)),
      );
      expect(
        solid(arrows[3].color),
        solid(AppColors.timelineChronology.withValues(alpha: 0.9)),
      );
    });
  });
}
