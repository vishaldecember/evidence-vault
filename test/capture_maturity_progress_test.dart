import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/presentation/capture_maturity_progress.dart';
import 'package:evidence_vault/services/workspace_coaching_service.dart';
import 'package:evidence_vault/widgets/workspace/incident_journey_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  String? parentEvidenceId,
  bool isContextual = false,
  String? notePreview,
  DateTime? at,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: id,
    lastPreservedAt: at ?? DateTime(2026, 8, 1, 10),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    parentEvidenceId: parentEvidenceId,
    isContextual: isContextual,
    notePreview: notePreview,
  );
}

void main() {
  group('CaptureMaturityProgress', () {
    test('empty incident is created only', () {
      final progress = CaptureMaturityProgress.evaluate(
        evidence: const [],
        journeyStage: JourneyStage.empty,
      );

      expect(progress.isReached(CaptureMaturityStep.incidentCreated), isTrue);
      expect(progress.isReached(CaptureMaturityStep.evidenceCaptured), isFalse);
      expect(progress.isReached(CaptureMaturityStep.contextsAdded), isFalse);
      expect(progress.isReached(CaptureMaturityStep.chronologyReady), isFalse);
      expect(
        progress.isReached(CaptureMaturityStep.investigationReady),
        isFalse,
      );
    });

    test('photo lights evidence but not investigation ready', () {
      final progress = CaptureMaturityProgress.evaluate(
        evidence: [_item(id: 'photo')],
        journeyStage: JourneyStage.empty,
      );

      expect(progress.isReached(CaptureMaturityStep.evidenceCaptured), isTrue);
      expect(progress.isReached(CaptureMaturityStep.contextsAdded), isFalse);
      expect(progress.isReached(CaptureMaturityStep.chronologyReady), isFalse);
      expect(
        progress.isReached(CaptureMaturityStep.investigationReady),
        isFalse,
      );
    });

    test('linked context lights contexts added', () {
      final progress = CaptureMaturityProgress.evaluate(
        evidence: [
          _item(id: 'photo'),
          _item(
            id: 'note',
            kind: WorkspaceEvidenceKind.note,
            parentEvidenceId: 'photo',
            isContextual: true,
            notePreview: 'What happened',
          ),
        ],
        journeyStage: JourneyStage.building,
      );

      expect(progress.isReached(CaptureMaturityStep.contextsAdded), isTrue);
      expect(
        progress.isReached(CaptureMaturityStep.investigationReady),
        isFalse,
      );
    });

    test('founder composition lights chronology ready', () {
      final progress = CaptureMaturityProgress.evaluate(
        evidence: [
          _item(
            id: 'voice',
            kind: WorkspaceEvidenceKind.voice,
            at: DateTime(2026, 8, 1, 9),
          ),
          _item(id: 'photo', at: DateTime(2026, 8, 1, 10)),
          _item(
            id: 'note',
            kind: WorkspaceEvidenceKind.note,
            notePreview: 'Context',
            at: DateTime(2026, 8, 1, 11),
          ),
        ],
        journeyStage: JourneyStage.building,
      );

      expect(progress.readiness.isReady, isTrue);
      expect(progress.isReached(CaptureMaturityStep.chronologyReady), isTrue);
      expect(
        progress.isReached(CaptureMaturityStep.investigationReady),
        isFalse,
      );
    });

    test('JourneyStage.rich lights investigation ready', () {
      final progress = CaptureMaturityProgress.evaluate(
        evidence: [
          _item(id: 'photo'),
          _item(
            id: 'note',
            kind: WorkspaceEvidenceKind.note,
            parentEvidenceId: 'photo',
            isContextual: true,
            notePreview: 'Context',
          ),
        ],
        journeyStage: JourneyStage.rich,
      );

      expect(
        progress.isReached(CaptureMaturityStep.investigationReady),
        isTrue,
      );
    });
  });

  testWidgets('Investigation ready responds to journey stage', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final evidence = [
      _item(id: 'photo'),
      _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        parentEvidenceId: 'photo',
        isContextual: true,
        notePreview: 'Context',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncidentJourneyCard(
            currentStage: JourneyStage.building,
            currentCoaching: WorkspaceCoachingService.coachingFor(
              primaryEvidenceCount: 1,
              enrichedEvidenceCount: 0,
              enrichmentPercentage: 0,
            ),
            journeyEvidence: evidence,
          ),
        ),
      ),
    );
    await tester.pump();

    final readyKey = CaptureMaturityProgress.keyFor(
      CaptureMaturityStep.investigationReady,
    );
    expect(tester.widget<Semantics>(find.byKey(readyKey)).properties.selected, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncidentJourneyCard(
            currentStage: JourneyStage.rich,
            currentCoaching: WorkspaceCoachingService.coachingFor(
              primaryEvidenceCount: 1,
              enrichedEvidenceCount: 1,
              enrichmentPercentage: 100,
            ),
            journeyEvidence: evidence,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.widget<Semantics>(find.byKey(readyKey)).properties.selected, isTrue);
    expect(find.text('Chronology Complete'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });
}
