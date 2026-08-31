import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/screens/main_shell_screen.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/widgets/home/first_incident_card.dart';
import 'package:evidence_vault/widgets/home/home_incident_display_state.dart';
import 'package:evidence_vault/widgets/home/session_resume_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
  });

  tearDown(() {
    WorkspaceSession.instance.reset();
    IncidentLibraryService.instance.clear();
  });

  LibraryIncidentSummary incident({
    required String id,
    required String title,
    int evidenceCount = 3,
    bool isInProgress = true,
    DateTime? updatedAt,
    String lastPreserved = 'Today • 2 minutes ago',
  }) {
    return LibraryIncidentSummary(
      id: id,
      title: title,
      evidenceCount: evidenceCount,
      contextEnrichedCount: 0,
      integrityVerified: false,
      lastPreserved: lastPreserved,
      narrativeCount: 1,
      isInProgress: isInProgress,
      updatedAt: updatedAt,
    );
  }

  group('HomeIncidentDisplayState.resolve', () {
    test('empty library is first-incident even when session has leftover evidence',
        () {
      final state = HomeIncidentDisplayState.resolve(
        libraryIncidents: const [],
        sessionIncidentId: 'stale-incident',
        sessionTitle: 'Stale Workplace',
        sessionEvidenceCount: 4,
        sessionNarrativeCount: 2,
      );

      expect(state.kind, HomeIncidentDisplayKind.firstIncident);
      expect(state.continueIncident, isNull);
      expect(state.visibleLibraryIncidents, isEmpty);
    });

    test('untitled zero-evidence draft is not a real incident', () {
      final state = HomeIncidentDisplayState.resolve(
        libraryIncidents: [
          incident(
            id: 'incident-empty-draft',
            title: 'Untitled Incident',
            evidenceCount: 0,
          ),
        ],
        sessionIncidentId: 'incident-empty-draft',
        sessionTitle: '',
        sessionEvidenceCount: 0,
        sessionNarrativeCount: 0,
      );

      expect(state.kind, HomeIncidentDisplayKind.firstIncident);
      expect(state.continueIncident, isNull);
    });

    test('one valid in-progress incident is continue-preserving for that id', () {
      final workplace = incident(
        id: 'incident-workplace',
        title: 'Workplace Concern',
      );
      final state = HomeIncidentDisplayState.resolve(
        libraryIncidents: [workplace],
        sessionIncidentId: 'incident-workplace',
        sessionTitle: 'Workplace Concern',
        sessionEvidenceCount: 5,
        sessionNarrativeCount: 2,
      );

      expect(state.kind, HomeIncidentDisplayKind.continuePreserving);
      expect(state.continueIncident?.id, 'incident-workplace');
      expect(state.continueIncident?.title, 'Workplace Concern');
      expect(state.continueIncident?.evidenceCount, 5);
    });

    test('multiple incidents overlay only the matching session incident', () {
      final first = incident(
        id: 'incident-a',
        title: 'Commute Incident',
        evidenceCount: 8,
      );
      final second = incident(
        id: 'incident-b',
        title: 'Vehicle Damage',
        evidenceCount: 2,
      );
      final state = HomeIncidentDisplayState.resolve(
        libraryIncidents: [first, second],
        sessionIncidentId: 'incident-b',
        sessionTitle: 'Vehicle Damage',
        sessionEvidenceCount: 2,
        sessionNarrativeCount: 1,
      );

      expect(state.kind, HomeIncidentDisplayKind.continuePreserving);
      expect(state.continueIncident?.id, 'incident-b');
      expect(state.continueIncident?.title, 'Vehicle Damage');
      expect(state.continueIncident?.title, isNot('Commute Incident'));
      expect(state.continueIncident?.evidenceCount, 2);
    });

    test('completed-only library is library-only without continue card', () {
      final state = HomeIncidentDisplayState.resolve(
        libraryIncidents: [
          incident(
            id: 'incident-done',
            title: 'Closed Matter',
            isInProgress: false,
          ),
        ],
        sessionIncidentId: 'unrelated-shell',
        sessionTitle: '',
        sessionEvidenceCount: 0,
        sessionNarrativeCount: 0,
      );

      expect(state.kind, HomeIncidentDisplayKind.libraryOnly);
      expect(state.continueIncident, isNull);
      expect(state.visibleLibraryIncidents.single.id, 'incident-done');
    });
  });

  group('Home screen incident-state contract', () {
    Future<void> pumpHome(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: MainShellScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'TEST 1 zero incidents shows first-incident Home, not continue/open',
      (tester) async {
        await pumpHome(tester);

        expect(find.text(FirstIncidentCard.title), findsOneWidget);
        expect(find.text(FirstIncidentCard.cta), findsOneWidget);
        expect(find.byType(FirstIncidentCard), findsOneWidget);
        expect(find.byType(SessionResumeCard), findsNothing);
        expect(find.text('Continue preserving'), findsNothing);
        expect(find.text('Continue Preserving'), findsNothing);
        expect(find.text('Open incident'), findsNothing);
        expect(find.text('Open Incident'), findsNothing);
        expect(find.textContaining('Last activity'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(SessionResumeCard),
            matching: find.textContaining('Evidence'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'TEST 2 one valid incident keeps Continue Preserving for that incident',
      (tester) async {
        IncidentLibraryService.instance.restoreSnapshot(
          summaries: [
            incident(
              id: 'incident-workplace',
              title: 'Workplace Concern',
              evidenceCount: 5,
            ),
          ],
          records: const [],
        );
        WorkspaceSession.instance.controller.replaceAggregate(
          IncidentAggregate.shell(
            id: 'incident-workplace',
            title: 'Workplace Concern',
          ),
        );

        await pumpHome(tester);

        expect(find.byType(SessionResumeCard), findsOneWidget);
        expect(find.text('Continue preserving'), findsWidgets);
        expect(find.text('Workplace Concern'), findsWidgets);
        expect(find.text('5 evidence'), findsOneWidget);
        expect(find.text(FirstIncidentCard.title), findsNothing);
        expect(find.text(FirstIncidentCard.cta), findsNothing);
        expect(find.text('Open incident'), findsNothing);
      },
    );

    testWidgets(
      'TEST 3 multiple incidents do not mix continuation metadata',
      (tester) async {
        IncidentLibraryService.instance.restoreSnapshot(
          summaries: [
            incident(
              id: 'incident-a',
              title: 'Commute Incident',
              evidenceCount: 8,
            ),
            incident(
              id: 'incident-b',
              title: 'Vehicle Damage',
              evidenceCount: 2,
            ),
          ],
          records: const [],
        );
        WorkspaceSession.instance.controller.replaceAggregate(
          IncidentAggregate.shell(
            id: 'incident-b',
            title: 'Vehicle Damage',
          ),
        );

        await pumpHome(tester);

        expect(find.byType(SessionResumeCard), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SessionResumeCard),
            matching: find.text('Vehicle Damage'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(SessionResumeCard),
            matching: find.text('Commute Incident'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(SessionResumeCard),
            matching: find.text('2 evidence'),
          ),
          findsOneWidget,
        );
        expect(find.text(FirstIncidentCard.title), findsNothing);
      },
    );

    testWidgets(
      'TEST 4 clear library then restart session renders zero-incident Home',
      (tester) async {
        IncidentLibraryService.instance.restoreSnapshot(
          summaries: [
            incident(
              id: 'incident-prior',
              title: 'Prior Incident',
              evidenceCount: 4,
            ),
          ],
          records: const [],
        );
        WorkspaceSession.instance.controller.replaceAggregate(
          IncidentAggregate.shell(
            id: 'incident-prior',
            title: 'Prior Incident',
          ),
        );

        await pumpHome(tester);
        expect(find.text('Prior Incident'), findsWidgets);

        IncidentLibraryService.instance.clear();
        WorkspaceSession.instance.reset();
        await tester.pumpAndSettle();

        expect(find.text(FirstIncidentCard.title), findsOneWidget);
        expect(find.text(FirstIncidentCard.cta), findsOneWidget);
        expect(find.byType(SessionResumeCard), findsNothing);
        expect(find.text('Prior Incident'), findsNothing);
        expect(find.text('Continue preserving'), findsNothing);
        expect(find.text('Open incident'), findsNothing);
      },
    );

    testWidgets(
      'TEST 5 stale session metadata does not populate Home after library clear',
      (tester) async {
        final now = DateTime(2026, 8, 16, 9);
        WorkspaceSession.instance.controller.replaceAggregate(
          IncidentAggregate.fromStore(
            IncidentStore(
              incident: Incident(
                id: 'stale-open',
                title: 'Previously Open Incident',
                status: IncidentStatus.draft,
                createdAt: now,
                updatedAt: now,
              ),
              capturedEvidence: [
                CapturedEvidence(
                  id: 'ev-stale',
                  incidentId: 'stale-open',
                  type: CapturedEvidenceType.photo,
                  capturedAt: now,
                  title: 'leftover note',
                  integrityVerified: false,
                  verification: VerificationFactory.initial(),
                  timelineAnchorId: 'anchor-stale',
                ),
              ],
            ),
          ),
        );
        expect(
          WorkspaceSession.instance.controller.currentIncident.evidenceCount,
          greaterThan(0),
        );
        IncidentLibraryService.instance.clear();

        await pumpHome(tester);

        expect(find.text(FirstIncidentCard.title), findsOneWidget);
        expect(find.text(FirstIncidentCard.cta), findsOneWidget);
        expect(find.byType(SessionResumeCard), findsNothing);
        expect(find.text('Previously Open Incident'), findsNothing);
        expect(find.text('Continue preserving'), findsNothing);
        expect(find.text('Open incident'), findsNothing);
      },
    );

    testWidgets(
      'empty untitled library draft after restart does not show Open incident',
      (tester) async {
        IncidentLibraryService.instance.restoreSnapshot(
          summaries: [
            incident(
              id: 'incident-ensure-draft',
              title: 'Untitled Incident',
              evidenceCount: 0,
              lastPreserved: 'Just now',
            ),
          ],
          records: const [],
        );

        await pumpHome(tester);

        expect(find.text(FirstIncidentCard.title), findsOneWidget);
        expect(find.byType(SessionResumeCard), findsNothing);
        expect(find.text('Continue preserving'), findsNothing);
        expect(find.text('Open incident'), findsNothing);
        expect(find.text('Untitled Incident'), findsNothing);
      },
    );
  });
}
