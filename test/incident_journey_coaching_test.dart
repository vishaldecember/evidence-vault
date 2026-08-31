import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/services/workspace_coaching_service.dart';
import 'package:evidence_vault/widgets/workspace/incident_journey_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Incident Journey coaching', () {
    test('coaching updates quantitatively when journey stage changes', () {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            WorkspaceEvidenceItem(
              id: 'photo',
              kind: WorkspaceEvidenceKind.image,
              title: 'Photo',
              lastPreservedAt: DateTime(2026, 7, 28),
              integrityVerified: true,
              verification: VerificationFactory.initial(),
            ),
          ],
        ),
      );

      expect(controller.journeyCoaching.journeyStatus, 'BUILDING');
      expect(
        controller.journeyCoaching.progressMessage,
        'None of 1 primary chronology items have recorded location, description, or notes.',
      );
      expect(
        controller.journeyCoaching.coachingMessage,
        contains('remaining 1 primary chronology items'),
      );

      controller.addContextEvidence(
        parentEvidenceId: 'photo',
        mode: WorkspaceCaptureMode.note,
      );

      expect(controller.journeyStage, JourneyStage.rich);
      expect(controller.journeyCoaching.journeyStatus, 'RICH');
      expect(
        controller.journeyCoaching.progressMessage,
        'All 1 primary chronology items have recorded context.',
      );
      expect(
        controller.journeyCoaching.coachingMessage,
        WorkspaceCoachingService.richCoaching,
      );

      controller.preserveEvidence(WorkspaceCaptureMode.video);
      expect(controller.journeyStage, JourneyStage.building);
      expect(controller.journeyCoaching.journeyStatus, 'BUILDING');
      expect(
        controller.journeyCoaching.progressMessage,
        '1 of 2 primary chronology items have recorded context.',
      );
      expect(
        controller.journeyCoaching.coachingMessage,
        contains('remaining 1 primary chronology items'),
      );
    });

    testWidgets('active stage shows two-line quantitative coaching only',
        (tester) async {
      final coaching = WorkspaceCoachingService.coachingFor(
        primaryEvidenceCount: 7,
        enrichedEvidenceCount: 3,
        enrichmentPercentage: 43,
      );

      expect(
        coaching.progressMessage,
        '3 of 7 primary chronology items have recorded context.',
      );
      expect(
        coaching.coachingMessage,
        contains('remaining 4 primary chronology items'),
      );
      expect(coaching.progressMessage, isNot(contains('%')));
      expect(coaching.coachingMessage, isNot(contains('%')));

      // Capture path uses EvidenceMaturityEngine and does not render coaching
      // copy. Organize path still renders the two-line quantitative coaching.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncidentJourneyCard(
              currentStage: JourneyStage.building,
              currentCoaching: coaching,
              journeyEvidence: const [],
              isOrganizeStage: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          '3 of 7 primary chronology items have recorded context',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('remaining 4 primary chronology items'),
        findsOneWidget,
      );
      expect(find.textContaining('%'), findsNothing);
    });
  });
}
