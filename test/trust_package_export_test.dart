import 'dart:io';
import 'dart:typed_data';

import 'package:evidence_vault/domain/trust_package/trust_package.dart';
import 'package:evidence_vault/domain/trust_package/trust_package_assembler.dart';
import 'package:evidence_vault/models/trust_package_share_link.dart';
import 'package:evidence_vault/repositories/trust_package_archive_store.dart';
import 'package:evidence_vault/repositories/trust_package_share_store.dart';
import 'package:evidence_vault/services/trust_package/trust_package_export_metadata.dart';
import 'package:evidence_vault/services/trust_package/trust_package_export_service.dart';
import 'package:evidence_vault/services/trust_package/trust_package_filename_service.dart';
import 'package:evidence_vault/services/trust_package/trust_package_pdf_renderer.dart';
import 'package:evidence_vault/services/trust_package/trust_package_share_service.dart';
import 'package:evidence_vault/widgets/trust_package/export/trust_package_export_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TrustPackage _samplePackage() {
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
      timelineAnchorCount: 2,
      relationshipGroupCount: 1,
      narrativeEventCount: 2,
      primaryEvidenceCount: 2,
      supportingEvidenceCount: 1,
      contextEntryCount: 1,
      witnessCount: 0,
      documentCount: 0,
    ),
    timelineSection: TrustPackageTimelineSection(
      entries: [
        TrustPackageTimelineEntry(
          timestamp: date,
          title: 'Arrival Photo',
          relatedEvidenceIds: ['photo'],
          relationshipGroupIds: ['group-1'],
          timelineAnchorId: 'anchor-1',
          capturedEvidenceId: 'photo',
        ),
      ],
    ),
    relationshipGroupsSection: TrustPackageRelationshipGroupsSection(
      groups: [
        TrustPackageRelationshipGroupEntry(
          groupId: 'group-1',
          colorHex: '#FF3B36F4',
          groupName: 'Group 1',
          supportingEvidenceIds: ['video'],
          connectedTimelineAnchorIds: ['photo'],
          confidenceLevel: 'Medium',
          validationStatus: '🟡 Medium',
        ),
      ],
    ),
    reconstructionSection: TrustPackageReconstructionSection(
      events: [
        TrustPackageReconstructionEventEntry(
          eventId: 'event-1',
          title: 'Arrival',
          summary: 'The subject arrived at the entrance.',
          evidenceReferenceIds: ['photo'],
          confidence: 'Medium',
          validationStatus: '🟡 Medium',
        ),
      ],
    ),
    evidenceAppendix: TrustPackageEvidenceAppendix(
      entries: [
        TrustPackageEvidenceAppendixEntry(
          evidenceId: 'photo',
          title: 'Arrival Photo',
          evidenceType: 'Photo',
          timestamp: date,
          device: 'Moto G35 5G',
          location: 'Pokhara, Nepal',
          context: 'Entrance captured on camera.',
          relationshipGroupIds: ['group-1'],
        ),
      ],
    ),
    integritySummary: TrustPackageIntegritySummary(
      evidenceCount: 2,
      timelineIntegrity: 'Complete',
      relationshipIntegrity: 'Complete',
      missingReferences: [],
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
    TrustPackageArchiveStore.resetForTests();
    TrustPackageShareStore.resetForTests();
  });

  group('TrustPackageFilenameService', () {
    test('uses standardised naming convention', () {
      final fileName = TrustPackageFilenameService.pdf(_samplePackage());
      expect(fileName, 'Workplace_Incident_TrustPackage_v1_20260728.pdf');
    });
  });

  group('TrustPackageExportMetadata', () {
    test('embeds required export metadata fields', () {
      final embedded = TrustPackageExportMetadata.embedded(_samplePackage());
      expect(embedded.keys, containsAll([
        'trustPackageId',
        'packageVersion',
        'generatedTimestamp',
        'incidentVersion',
        'generatedBy',
      ]));
      expect(
        TrustPackageExportMetadata.originatingIncidentId(_samplePackage()),
        'incident-1',
      );
    });

    test('includes integrity notice copy', () {
      expect(
        TrustPackageExportMetadata.integrityNoticeTitle,
        'Integrity Notice',
      );
      expect(
        TrustPackageExportMetadata.integrityNoticeBody,
        contains('Incident Aggregate'),
      );
    });
  });

  group('TrustPackagePdfRenderer', () {
    test('generates non-empty PDF bytes', () async {
      final bytes = await TrustPackagePdfRenderer.buildPdf(_samplePackage());
      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });

  group('TrustPackageExportService', () {
    test('writes PDF and archive exports', () async {
      final tempDir = Directory.systemTemp.createTempSync('trust_export_test');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final service = TrustPackageExportService(
        exportDirectoryProvider: (_) async => tempDir,
      );
      final pdf = await service.exportPdf(_samplePackage());
      final archive = await service.exportArchive(_samplePackage());

      expect(pdf.format, TrustPackageExportFormat.pdf);
      expect(pdf.fileName.endsWith('.pdf'), isTrue);
      expect(archive.format, TrustPackageExportFormat.archive);
      expect(archive.fileName.endsWith('.zip'), isTrue);
      expect(TrustPackageArchiveStore.all, hasLength(1));
    });
  });

  group('TrustPackageShareService', () {
    test('creates secure share link with settings', () {
      const service = TrustPackageShareService();
      final expiry = DateTime(2026, 8, 1);
      final link = service.createShareLink(
        _samplePackage(),
        settings: TrustPackageShareSettings(
          recipientNotes: 'For HR review',
          expiresAt: expiry,
          viewOnly: true,
        ),
      );

      expect(link.packageId, isNotEmpty);
      expect(link.shareUrl, isNotEmpty);
      expect(link.viewOnly, isTrue);
      expect(link.recipientNotes, 'For HR review');
      expect(link.expiresAt, expiry);
      expect(TrustPackageShareStore.all, hasLength(1));
    });
  });

  group('TrustPackage export UI', () {
    testWidgets('export sheet exposes PDF, print, archive and share actions',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrustPackageExportActions(package: _samplePackage()),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Export Trust Package'));
      await tester.pumpAndSettle();

      expect(find.text('Export PDF'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.text('Archive Snapshot'), findsOneWidget);
      expect(find.text('Create Secure Share Link'), findsOneWidget);
    });

    testWidgets('print view hides navigation panel', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: TrustPackagePrintScreen(package: _samplePackage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Print Preview'), findsOneWidget);
      expect(find.text('Contents'), findsNothing);
      expect(find.text('Executive Summary'), findsWidgets);
    });
  });
}
