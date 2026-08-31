import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/models/library_incident_record.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/repositories/firebase/firestore_serializers.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/persistence/local_incident_pointer.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/widgets/home/library_of_truth_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'user-library-open';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: userId,
    );
    await LocalIncidentPointer.clearForTests(userId);
    IncidentLibraryService.instance.clear();
  });

  tearDown(() async {
    await LocalIncidentPointer.clearForTests(userId);
    IncidentLibraryService.instance.clear();
    WorkspaceSession.instance.reset();
    UserSessionService.resetForTests();
  });

  test('A. named incident opens by id', () async {
    final session = WorkspaceSession.instance;
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: 'incident-A', title: 'Street Fight'),
    );
    final ok = await session.openIncident('incident-A');
    expect(ok, isTrue);
    expect(session.controller.currentIncident.id, 'incident-A');
    expect(session.controller.currentIncident.title, 'Street Fight');
  });

  test('B. untitled incident opens by id', () async {
    final session = WorkspaceSession.instance;
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: 'incident-B', title: ''),
    );
    // Switch away then reopen untitled — proves empty title is irrelevant.
    await session.beginNewCaptureIncident();
    expect(session.controller.currentIncident.id, isNot('incident-B'));

    final ok = await session.openIncident('incident-B');
    expect(ok, isTrue);
    expect(session.controller.currentIncident.id, 'incident-B');
    expect(session.controller.currentIncident.title, isEmpty);
  });

  test('C. multiple incident isolation B→D→A→C', () async {
    final session = WorkspaceSession.instance;
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'incident-A',
      title: 'Street Fight',
    );
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'incident-C',
      title: 'Workplace Incident',
    );

    for (final id in ['incident-B', 'incident-D', 'incident-A', 'incident-C']) {
      final ok = await session.openIncident(id);
      expect(ok, isTrue, reason: 'failed to open $id');
      expect(session.controller.currentIncident.id, id);
    }
    expect(session.controller.currentIncident.title, 'Workplace Incident');
  });

  test('D. identical empty titles remain independently openable', () async {
    final session = WorkspaceSession.instance;
    expect('incident-B' != 'incident-C', isTrue);

    final openB = await session.openIncident('incident-B');
    expect(openB, isTrue);
    expect(session.controller.currentIncident.id, 'incident-B');

    final openC = await session.openIncident('incident-C');
    expect(openC, isTrue);
    expect(session.controller.currentIncident.id, 'incident-C');
    expect(session.controller.currentIncident.id, isNot('incident-B'));
  });

  test('E. active incident does not override Library card id', () async {
    final session = WorkspaceSession.instance;
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: 'incident-A', title: 'Street Fight'),
    );
    session.controller.preserveEvidence(WorkspaceCaptureMode.photo);
    expect(session.controller.currentIncident.id, 'incident-A');

    final ok = await session.openIncident('incident-B');
    expect(ok, isTrue);
    expect(session.controller.currentIncident.id, 'incident-B');
    expect(session.controller.currentIncident.id, isNot('incident-A'));
  });

  test('F. Library card identity uses incident.id (incl. Untitled)', () {
    IncidentLibraryService.instance.restoreSnapshot(
      summaries: const [
        LibraryIncidentSummary(
          id: 'incident-A',
          title: 'Street Fight',
          evidenceCount: 1,
          contextEnrichedCount: 0,
          integrityVerified: false,
          lastPreserved: 'Just now',
          isInProgress: true,
        ),
        LibraryIncidentSummary(
          id: 'incident-B',
          title: 'Untitled Incident',
          evidenceCount: 1,
          contextEnrichedCount: 0,
          integrityVerified: false,
          lastPreserved: 'Just now',
          isInProgress: true,
        ),
      ],
      records: [
        LibraryIncidentRecord(
          id: 'incident-A',
          title: 'Street Fight',
          preservedAt: DateTime(2026, 1, 1),
        ),
        LibraryIncidentRecord(
          id: 'incident-B',
          title: 'Untitled Incident',
          preservedAt: DateTime(2026, 1, 2),
        ),
      ],
    );

    for (final card in IncidentLibraryService.instance.summaries) {
      expect(card.id, isNotEmpty);
      expect(card.id.startsWith('incident-'), isTrue);
    }
    final untitled = IncidentLibraryService.instance.summaries
        .firstWhere((s) => s.title == 'Untitled Incident');
    expect(untitled.id, 'incident-B');
  });

  test('F2. empty Firestore incidentId field falls back to doc id', () {
    final incident = FirestoreSerializers.incidentFromMap(
      {
        'incidentId': '',
        'title': '',
        'status': 'draft',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      },
      'incident-doc-real-id',
    );
    expect(incident.id, 'incident-doc-real-id');
    expect(incident.title, isEmpty);
  });

  test('G. restart — untitled remains openable by persisted id', () async {
    final session = WorkspaceSession.instance;
    session.controller.replaceAggregate(
      IncidentAggregate.shell(id: 'incident-A', title: 'Street Fight'),
    );
    await LocalIncidentPointer.rememberTitle(
      userId: userId,
      incidentId: 'incident-A',
      title: 'Street Fight',
    );
    await LocalIncidentPointer.remember(
      userId: userId,
      incidentId: 'incident-B',
    );

    // Simulate restart: clear working set, reopen from ids.
    session.reset();
    UserSessionService.establishSession(
      email: 'investigator@example.com',
      name: 'Investigator',
      userId: userId,
    );

    expect(await session.openIncident('incident-A'), isTrue);
    expect(session.controller.currentIncident.id, 'incident-A');

    expect(await session.openIncident('incident-B'), isTrue);
    expect(session.controller.currentIncident.id, 'incident-B');
  });

  test('empty incidentId is rejected and does not steal active incident',
      () async {
    final session = WorkspaceSession.instance;
    final active = session.controller.currentIncident.id;
    final ok = await session.openIncident('');
    expect(ok, isFalse);
    expect(session.controller.currentIncident.id, active);
  });

  testWidgets('Library tile tap passes card.incidentId (Untitled)',
      (tester) async {
    String? tappedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryOfTruthSection(
            incidents: const [
              LibraryIncidentSummary(
                id: 'incident-untitled-1',
                title: 'Untitled Incident',
                evidenceCount: 0,
                contextEnrichedCount: 0,
                integrityVerified: false,
                lastPreserved: 'Just now',
                isInProgress: true,
              ),
              LibraryIncidentSummary(
                id: 'incident-named-1',
                title: 'Street Fight',
                evidenceCount: 1,
                contextEnrichedCount: 0,
                integrityVerified: false,
                lastPreserved: 'Just now',
                isInProgress: true,
              ),
            ],
            onIncidentTap: (id) => tappedId = id,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Untitled Incident'));
    await tester.pump();
    expect(tappedId, 'incident-untitled-1');

    await tester.tap(find.text('Street Fight'));
    await tester.pump();
    expect(tappedId, 'incident-named-1');
  });

  test('serializer preserves non-empty incidentId over doc id', () {
    final incident = FirestoreSerializers.incidentFromMap(
      {
        'incidentId': 'incident-A',
        'title': 'Street Fight',
        'status': IncidentStatus.active.name,
      },
      'doc-should-not-win',
    );
    expect(incident.id, 'incident-A');
    expect(incident, isA<Incident>());
  });
}
