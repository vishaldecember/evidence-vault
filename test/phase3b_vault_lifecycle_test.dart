import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_title.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/screens/vault_screen.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/vault/incident_collection_store.dart';
import 'package:evidence_vault/services/vault/vault_incident_grouping.dart';
import 'package:evidence_vault/theme/app_colors.dart';
import 'package:evidence_vault/widgets/vault/vault_incident_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LibraryIncidentSummary _incident({
  required String id,
  required String title,
  bool isArchived = false,
}) {
  return LibraryIncidentSummary(
    id: id,
    title: title,
    evidenceCount: 2,
    contextEnrichedCount: 1,
    integrityVerified: true,
    lastPreserved: 'Today',
    isInProgress: !isArchived,
    isArchived: isArchived,
    createdAt: DateTime.utc(2026, 8, 20),
    updatedAt: DateTime.utc(2026, 8, 21),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
  });

  tearDown(() {
    IncidentLibraryService.instance.clear();
    IncidentCollectionStore.instance.debugReset();
  });

  test('IncidentTitle rejects placeholders and accepts short useful titles', () {
    expect(IncidentTitle.isMeaningful(''), isFalse);
    expect(IncidentTitle.isMeaningful('   '), isFalse);
    expect(IncidentTitle.isMeaningful('Untitled Incident'), isFalse);
    expect(IncidentTitle.isMeaningful('untitled incident'), isFalse);
    expect(IncidentTitle.isMeaningful('Parking dispute'), isTrue);
    expect(IncidentTitle.isMeaningful('Landlord call'), isTrue);
    expect(IncidentTitle.isMeaningful('Noise complaint'), isTrue);
    expect(IncidentTitle.isMeaningful('Workplace incident'), isTrue);
  });

  test('archived incident cannot edit metadata or add evidence', () async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(
        id: 'incident-a',
        title: 'Parking dispute',
      ),
    );
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    final evidenceBefore = [
      for (final item in controller.currentIncident.evidence) item.id,
    ];
    IncidentLibraryService.instance.summaries = [
      _incident(id: 'incident-a', title: 'Parking dispute'),
    ];
    await IncidentLibraryService.instance.archiveIncident('incident-a');

    expect(controller.isArchivedReadOnly, isTrue);
    controller.updateIncidentName('Changed');
    expect(controller.currentIncident.title, 'Parking dispute');
    controller.preserveEvidence(WorkspaceCaptureMode.note);
    expect(
      [for (final item in controller.currentIncident.evidence) item.id],
      evidenceBefore,
    );

    await IncidentLibraryService.instance.restoreIncident('incident-a');
    expect(controller.isArchivedReadOnly, isFalse);
    controller.updateIncidentName('Named after restore');
    expect(controller.currentIncident.title, 'Named after restore');
  });

  test('collection membership survives archive and restore', () async {
    const userId = 'user-lifecycle';
    final grouping = VaultIncidentGrouping();
    final collection = await grouping.groupIncidents(
      userId: userId,
      sourceIncidentId: 'incident-a',
      targetIncidentId: 'incident-b',
    );
    IncidentLibraryService.instance.summaries = [
      _incident(id: 'incident-a', title: 'Parking dispute'),
      _incident(id: 'incident-b', title: 'Landlord call'),
    ];

    await IncidentLibraryService.instance.archiveIncident('incident-a');
    final archived = await IncidentCollectionStore.instance.get(
      userId: userId,
      collectionId: collection!.id,
    );
    expect(archived!.memberIncidentIds, ['incident-a', 'incident-b']);

    await IncidentLibraryService.instance.restoreIncident('incident-a');
    final restored = await IncidentCollectionStore.instance.get(
      userId: userId,
      collectionId: collection.id,
    );
    expect(restored!.memberIncidentIds, ['incident-a', 'incident-b']);
    expect(restored.title, collection.title);
  });

  testWidgets('Vault untitled title is red and archived module stays readable',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            VaultIncidentModule(
              incident: _incident(
                id: 'incident-untitled',
                title: 'Untitled Incident',
              ),
              onTap: () {},
            ),
            VaultIncidentModule(
              incident: _incident(
                id: 'incident-archived',
                title: 'Workplace incident',
                isArchived: true,
              ),
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    final untitled = tester.widget<Text>(find.text('Untitled Incident'));
    expect(untitled.style?.color, AppColors.danger);
    final named = tester.widget<Text>(find.text('Workplace incident'));
    expect(named.style?.color, AppColors.navy);

    final archivedInk = tester.widget<Ink>(
      find.byKey(VaultIncidentModule.moduleKey('incident-archived')),
    );
    expect(
      (archivedInk.decoration! as BoxDecoration).color,
      AppColors.archivedSurface,
    );
  });

  testWidgets('archived Vault cards remain openable for viewing', (tester) async {
    final opened = <LibraryIncidentSummary>[];
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(480, 1400));
    IncidentLibraryService.instance.summaries = [
      _incident(
        id: 'incident-archived',
        title: 'Workplace incident',
        isArchived: true,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: VaultScreen(onIncidentOpen: opened.add),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Workplace incident'));
    await tester.pump();
    expect(opened.single.id, 'incident-archived');
    expect(find.byKey(VaultScreen.organizeModeKey), findsNothing);
  });
}
