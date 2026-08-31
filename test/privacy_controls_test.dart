import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/domain/trust_package/trust_package.dart';
import 'package:evidence_vault/domain/trust_package/trust_package_assembler.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/home_dashboard_mock.dart';
import 'package:evidence_vault/models/trust_package_archive_record.dart';
import 'package:evidence_vault/repositories/trust_package_archive_store.dart';
import 'package:evidence_vault/repositories/trust_package_share_store.dart';
import 'package:evidence_vault/services/account_deletion_service.dart';
import 'package:evidence_vault/services/investigation_data_deletion_service.dart';
import 'package:evidence_vault/services/persistence/incident_library_service.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:evidence_vault/services/vault_reset_service.dart';
import 'package:evidence_vault/widgets/privacy/typed_confirmation_dialog.dart';
import 'package:evidence_vault/screens/privacy_data_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TrustPackage _sampleTrustPackage() {
  final date = DateTime(2026, 7, 28, 12);
  return TrustPackage(
    incidentSummary: TrustPackageIncidentSummary(
      incidentName: 'Workplace Incident',
      incidentType: 'General Incident',
      incidentStatus: 'Active',
      dateCreated: date,
      dateUpdated: date,
      investigationConfidence: 'Building',
      reconstructionHealth: 'Needs Review',
    ),
    investigationSummary: TrustPackageInvestigationSummary(
      timelineAnchorCount: 1,
      relationshipGroupCount: 1,
      narrativeEventCount: 1,
      primaryEvidenceCount: 1,
      supportingEvidenceCount: 0,
      contextEntryCount: 0,
      witnessCount: 0,
      documentCount: 0,
    ),
    timelineSection: const TrustPackageTimelineSection(entries: []),
    relationshipGroupsSection:
        const TrustPackageRelationshipGroupsSection(groups: []),
    reconstructionSection: const TrustPackageReconstructionSection(events: []),
    evidenceAppendix: const TrustPackageEvidenceAppendix(entries: []),
    integritySummary: TrustPackageIntegritySummary(
      evidenceCount: 1,
      timelineIntegrity: 'Complete',
      relationshipIntegrity: 'Complete',
      missingReferences: const [],
      validationStatus: 'Needs Review',
    ),
    metadata: TrustPackageMetadata(
      packageVersion: DefaultTrustPackageAssembler.packageVersion,
      generatedAt: date,
      generatedBy: DefaultTrustPackageAssembler.generatedBy,
      incidentVersion: '1',
      trustPackageId: 'incident-1@trust-package/v1',
    ),
  );
}

void main() {
  setUp(() {
    WorkspaceSession.instance.reset();
    TrustPackageArchiveStore.resetForTests();
    TrustPackageShareStore.resetForTests();
    UserSessionService.resetForTests();
    VaultResetService.resetForTests();
    HomeDashboardMock.resetToEmpty();
    IncidentLibraryService.instance.summaries =
        List.from(HomeDashboardMock.activeLibraryIncidents);
    IncidentLibraryService.instance.records =
        List.from(HomeDashboardMock.activeLibraryIncidentRecords);
  });

  group('InvestigationDataDeletionService', () {
    test('deletes investigation data in transactional order', () async {
      TrustPackageArchiveStore.add(
        TrustPackageArchiveRecord(
          archiveId: 'archive-1',
          originatingIncidentId: 'incident-1',
          packageVersion: '1.0.0',
          generatedAt: DateTime(2026, 7, 28),
          generatedBy: 'Evidence Vault',
          archivedAt: DateTime(2026, 7, 28),
          snapshot: _sampleTrustPackage(),
        ),
      );

      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          incidentName: 'Workplace Incident',
          items: const [],
        ),
      );
      WorkspaceSession.instance.controller = controller;

      const service = InvestigationDataDeletionService(
        deletePersistedMedia: _noop,
        removeCloudBackups: _noop,
        removeSearchIndexes: _noop,
      );
      await service.deleteAllInvestigationData();

      expect(TrustPackageArchiveStore.all, isEmpty);
      expect(TrustPackageShareStore.all, isEmpty);
      expect(IncidentLibraryService.instance.summaries, isEmpty);
      expect(IncidentLibraryService.instance.records, isEmpty);
      expect(
        WorkspaceSession.instance.controller.state.items,
        isEmpty,
      );
    });

    test('rolls back when a deletion step fails', () async {
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          incidentName: 'Rollback Incident',
          items: const [],
        ),
      );
      WorkspaceSession.instance.controller = controller;
      final originalTitle =
          WorkspaceSession.instance.controller.state.incidentName;

      final service = InvestigationDataDeletionService(
        deletePersistedMedia: () async {
          throw StateError('disk failure');
        },
        removeCloudBackups: _noop,
        removeSearchIndexes: _noop,
      );

      await expectLater(
        service.deleteAllInvestigationData(),
        throwsStateError,
      );

      expect(
        WorkspaceSession.instance.controller.state.incidentName,
        originalTitle,
      );
    });
  });

  group('VaultResetService', () {
    test('clears investigations but preserves account', () async {
      UserSessionService.establishSession(
        email: 'user@example.com',
        name: 'Alex Morgan',
      );

      const service = VaultResetService(
        investigationDataDeletionService: InvestigationDataDeletionService(
          deletePersistedMedia: _noop,
          removeCloudBackups: _noop,
          removeSearchIndexes: _noop,
        ),
      );

      await service.clearVault();

      expect(UserSessionService.isSignedIn, isTrue);
      expect(UserSessionService.account?.email, 'user@example.com');
      expect(VaultResetService.vaultWasCleared, isTrue);
      expect(IncidentLibraryService.instance.summaries, isEmpty);
    });
  });

  group('AccountDeletionService', () {
    test('removes account after investigation data deletion', () async {
      UserSessionService.establishSession(
        email: 'delete@example.com',
        name: 'Delete Me',
      );

      const service = AccountDeletionService(
        investigationDataDeletionService: InvestigationDataDeletionService(
          deletePersistedMedia: _noop,
          removeCloudBackups: _noop,
          removeSearchIndexes: _noop,
        ),
      );

      await service.deleteAccount();

      expect(UserSessionService.isSignedIn, isFalse);
      expect(UserSessionService.account, isNull);
    });
  });

  group('Privacy UI', () {
    testWidgets('typed confirmation requires exact keyword', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      TypedConfirmationDialog.show(
                        context,
                        title: 'Clear your Vault?',
                        body: 'Body',
                        confirmationWord: 'CLEAR',
                        confirmLabel: 'Clear Vault',
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final confirmButton = find.widgetWithText(FilledButton, 'Clear Vault');
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'CLEAR');
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
    });

    testWidgets('privacy screen exposes clear vault and delete account',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PrivacyDataScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clear Vault'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
    });
  });
}

Future<void> _noop() async {}
