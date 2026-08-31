import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/workspace_evidence_repository.dart';
import 'package:evidence_vault/services/workspace_coaching_service.dart';
import 'package:evidence_vault/widgets/common/thumbnail_atmosphere_surface.dart';
import 'package:evidence_vault/widgets/workspace/evidence_maturity_engine.dart';
import 'package:evidence_vault/widgets/workspace/incident_journey_card.dart';
import 'package:evidence_vault/widgets/workspace/journey_evidence_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Evidence Maturity responsive capture grid', () {
    testWidgets('wraps primary evidence without horizontal scrolling',
        (tester) async {
      final journeyEvidence = WorkspaceEvidenceRepository.journeySequenceFromItems([
        WorkspaceEvidenceItem(
          id: 'photo',
          kind: WorkspaceEvidenceKind.image,
          title: 'Photo Evidence',
          lastPreservedAt: DateTime(2026, 7, 28, 9),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
        ),
        WorkspaceEvidenceItem(
          id: 'video',
          kind: WorkspaceEvidenceKind.video,
          title: 'Video Evidence',
          lastPreservedAt: DateTime(2026, 7, 28, 10),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
        ),
        WorkspaceEvidenceItem(
          id: 'ctx',
          kind: WorkspaceEvidenceKind.note,
          title: 'Context note',
          lastPreservedAt: DateTime(2026, 7, 28, 11),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
          isContextual: true,
          parentEvidenceId: 'photo',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncidentJourneyCard(
              currentStage: JourneyStage.building,
              currentCoaching: WorkspaceCoachingService.coachingFor(
                primaryEvidenceCount: 2,
                enrichedEvidenceCount: 0,
                enrichmentPercentage: 0,
              ),
              journeyEvidence: journeyEvidence,
            ),
          ),
        ),
      );

      expect(find.text('Evidence Maturity'), findsOneWidget);
      expect(find.text('Captured'), findsOneWidget);
      expect(find.text('Strengthening'), findsNothing);
      expect(EvidenceMaturityEngine.showStrengtheningLane, isFalse);
      expect(find.text('Investigation Ready'), findsOneWidget);
      expect(find.text('Incident created'), findsOneWidget);
      expect(find.text('Evidence captured'), findsOneWidget);
      expect(find.text('Contexts added'), findsOneWidget);
      expect(find.text('Chronology ready'), findsOneWidget);
      expect(find.text('Investigation ready'), findsOneWidget);
      expect(find.byType(EvidenceMaturityEngine), findsOneWidget);
      expect(find.byType(ThumbnailAtmosphereSurface), findsOneWidget);
      expect(
        find.image(
          const AssetImage(ThumbnailAtmosphereSurface.asset),
        ),
        findsOneWidget,
      );
      expect(find.byType(Wrap), findsWidgets);
      expect(find.byType(ListView), findsNothing);
      // Captured lane: primary media only — parent-linked notes stay Strengthening.
      expect(find.byType(JourneyEvidenceThumbnail), findsNWidgets(2));
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNWidgets(1));
    });

    testWidgets('Captured lane includes primary chronology kinds', (tester) async {
      final journeyEvidence = WorkspaceEvidenceRepository.journeySequenceFromItems([
        WorkspaceEvidenceItem(
          id: 'photo',
          kind: WorkspaceEvidenceKind.image,
          title: 'Photo Evidence',
          lastPreservedAt: DateTime(2026, 7, 28, 9),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
        ),
        WorkspaceEvidenceItem(
          id: 'voice',
          kind: WorkspaceEvidenceKind.voice,
          title: 'Voice Note',
          lastPreservedAt: DateTime(2026, 7, 28, 10),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
        ),
        WorkspaceEvidenceItem(
          id: 'note',
          kind: WorkspaceEvidenceKind.note,
          title: 'Written Note',
          notePreview: 'First line of note',
          lastPreservedAt: DateTime(2026, 7, 28, 11),
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
                primaryEvidenceCount: 2,
                enrichedEvidenceCount: 0,
                enrichmentPercentage: 0,
              ),
              journeyEvidence: journeyEvidence,
            ),
          ),
        ),
      );

      // Sprint 6B Task 3.2 — standalone text notes appear in Captured lane.
      expect(find.byType(JourneyEvidenceThumbnail), findsNWidgets(3));
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNWidgets(2));
      expect(find.text('Text Note'), findsNothing);
      expect(find.text('Attachment'), findsNothing);
      expect(find.text('Primary Evidence'), findsNothing);
      expect(find.text('Relationship'), findsNothing);
      expect(EvidenceMaturityEngine.showStrengtheningLane, isFalse);
    });

    testWidgets('tap thumbnail opens evidence via callback', (tester) async {
      WorkspaceEvidenceItem? selected;
      final journeyEvidence = WorkspaceEvidenceRepository.journeySequenceFromItems([
        WorkspaceEvidenceItem(
          id: 'photo',
          kind: WorkspaceEvidenceKind.image,
          title: 'Photo Evidence',
          lastPreservedAt: DateTime(2026, 7, 28, 9),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncidentJourneyCard(
              currentStage: JourneyStage.empty,
              currentCoaching: WorkspaceCoachingService.coachingFor(
                primaryEvidenceCount: 0,
                enrichedEvidenceCount: 0,
                enrichmentPercentage: 0,
              ),
              journeyEvidence: journeyEvidence,
              onEvidenceSelected: (item) => selected = item,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(JourneyEvidenceThumbnail));
      await tester.pump();

      expect(selected?.id, 'photo');
    });
  });
}
