import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/services/workspace_coaching_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkspaceCoachingService', () {
    test('EMPTY coaching when no primary evidence', () {
      final coaching = WorkspaceCoachingService.coachingFor(
        primaryEvidenceCount: 0,
        enrichedEvidenceCount: 0,
        enrichmentPercentage: 0,
      );

      expect(coaching.journeyStatus, 'EMPTY');
      expect(coaching.progressMessage, isNull);
      expect(coaching.coachingMessage, WorkspaceCoachingService.emptyMessage);
    });

    test('BUILDING coaching shows quantitative progress and remaining count', () {
      final coaching = WorkspaceCoachingService.coachingFor(
        primaryEvidenceCount: 7,
        enrichedEvidenceCount: 3,
        enrichmentPercentage: 43,
      );

      expect(coaching.journeyStatus, 'BUILDING');
      expect(
        coaching.progressMessage,
        '3 of 7 primary chronology items have recorded context.',
      );
      expect(
        coaching.coachingMessage,
        'Consider adding location, description, or notes to the remaining 4 primary chronology items.',
      );
    });

    test('RICH coaching confirms full enrichment', () {
      final coaching = WorkspaceCoachingService.coachingFor(
        primaryEvidenceCount: 5,
        enrichedEvidenceCount: 5,
        enrichmentPercentage: 100,
      );

      expect(coaching.journeyStatus, 'RICH');
      expect(
        coaching.progressMessage,
        'All 5 primary chronology items have recorded context.',
      );
      expect(coaching.coachingMessage, WorkspaceCoachingService.richCoaching);
    });

    test('remaining count is calculated automatically', () {
      final coaching = WorkspaceCoachingService.coachingFor(
        primaryEvidenceCount: 4,
        enrichedEvidenceCount: 1,
        enrichmentPercentage: 25,
      );

      expect(
        coaching.coachingMessage,
        contains('remaining 3 primary chronology items'),
      );
    });

    test('coaching copy contains no legacy philosophy phrases', () {
      const banned = [
        'Every library begins with one piece of truth',
        'Your truth is taking shape',
        'Your Library of Truth is ready',
      ];

      final samples = [
        WorkspaceCoachingService.coachingFor(
          primaryEvidenceCount: 0,
          enrichedEvidenceCount: 0,
          enrichmentPercentage: 0,
        ),
        WorkspaceCoachingService.coachingFor(
          primaryEvidenceCount: 3,
          enrichedEvidenceCount: 1,
          enrichmentPercentage: 33,
        ),
        WorkspaceCoachingService.coachingFor(
          primaryEvidenceCount: 2,
          enrichedEvidenceCount: 2,
          enrichmentPercentage: 100,
        ),
      ];

      for (final coaching in samples) {
        for (final phrase in banned) {
          expect(coaching.coachingMessage.contains(phrase), isFalse);
          if (coaching.progressMessage != null) {
            expect(coaching.progressMessage!.contains(phrase), isFalse);
          }
        }
      }

      for (final stage in JourneyStage.timeline) {
        final message = WorkspaceCoachingService.messageForStage(stage);
        for (final phrase in banned) {
          expect(message.contains(phrase), isFalse, reason: stage.label);
        }
      }
    });

    test('organize coaching focuses on organising not investigation', () {
      final building = WorkspaceCoachingService.organizeCoachingFrom(
        WorkspaceCoachingService.coachingFor(
          primaryEvidenceCount: 3,
          enrichedEvidenceCount: 1,
          enrichmentPercentage: 33,
        ),
        relationshipGroupCount: 0,
      );
      expect(
        building.coachingMessage,
        'Group related photos and connect matching evidence.',
      );
      expect(building.coachingMessage.toLowerCase(), isNot(contains('reconstruction')));
      expect(building.coachingMessage.toLowerCase(), isNot(contains('investigation')));

      final richWithGroups = WorkspaceCoachingService.organizeCoachingFrom(
        WorkspaceCoachingService.coachingFor(
          primaryEvidenceCount: 2,
          enrichedEvidenceCount: 2,
          enrichmentPercentage: 100,
        ),
        relationshipGroupCount: 1,
      );
      expect(
        richWithGroups.coachingMessage,
        contains('witness group'),
      );

      expect(
        WorkspaceCoachingService.organizeMessageForStage(JourneyStage.rich),
        contains('relationship groups'),
      );
    });
  });
}
