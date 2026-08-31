import 'dart:io';

import 'package:evidence_vault/domain/evidence/evidence_integrity.dart';
import 'package:evidence_vault/domain/evidence/evidence_provenance_event.dart';
import 'package:evidence_vault/domain/trust_package/trust_package.dart';
import 'package:evidence_vault/domain/trust_package/trust_package_integrity_provenance_builder.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/verification_model.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/presentation/evidence_inspector_semantics.dart';
import 'package:evidence_vault/utils/evidence_formatters.dart';
import 'package:evidence_vault/widgets/trust_package/preview/trust_package_integrity_provenance_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _knownBytes = <int>[0x45, 0x56, 0x31, 0x00, 0xFF];

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  String title = 'Arrival Photo',
  String? contentHash,
  String? filePath,
  String? thumbnailPath,
  String? notePreview,
  String? deviceModel,
  double? latitude,
  double? longitude,
  DateTime? capturedAt,
  DateTime? recordedAt,
  List<EvidenceProvenanceEvent> provenanceEvents = const [],
  VerificationModel? verification,
}) {
  final at = capturedAt ?? DateTime(2026, 8, 15, 14, 32, 18);
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: title,
    lastPreservedAt: at,
    integrityVerified: false,
    verification: verification ?? VerificationFactory.initial(),
    contentHash: contentHash,
    filePath: filePath,
    thumbnailPath: thumbnailPath,
    notePreview: notePreview,
    deviceModel: deviceModel,
    latitude: latitude,
    longitude: longitude,
    capturedAt: capturedAt ?? at,
    recordedAt: recordedAt,
    provenanceEvents: provenanceEvents,
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('trust_pack_integrity_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> writeOriginal(List<int> bytes) async {
    final file = File('${tempDir.path}/original.bin');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  group('A verified evidence', () {
    test('valid hash and available original bytes are Integrity verified',
        () async {
      final original = await writeOriginal(_knownBytes);
      final hash = EvidenceIntegrity.sha256OfBytes(_knownBytes);
      final entry = TrustPackageIntegrityProvenanceBuilder.fromItem(
        _item(
          id: 'photo',
          contentHash: hash,
          filePath: original.path,
          thumbnailPath: '${tempDir.path}/thumb.bin',
        ),
      );

      expect(entry.state, TrustPackIntegrityState.verified);
      expect(entry.statusLabel, TrustPackIntegrityLabels.verified);
      expect(entry.originalPreserved, isTrue);
      expect(entry.contentHash, hash);
    });
  });

  group('B unavailable original', () {
    test('recorded hash without bytes is not reported as verified', () {
      const hash =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final entry = TrustPackageIntegrityProvenanceBuilder.fromItem(
        _item(
          id: 'photo',
          contentHash: hash,
          filePath: '${tempDir.path}/missing.bin',
          thumbnailPath: '${tempDir.path}/thumb.bin',
        ),
      );

      expect(entry.state, TrustPackIntegrityState.recorded);
      expect(entry.statusLabel, TrustPackIntegrityLabels.recorded);
      expect(entry.statusLabel, isNot(TrustPackIntegrityLabels.verified));
      expect(entry.originalPreserved, isFalse);
      expect(
        entry.statusExplanation,
        TrustPackIntegrityLabels.recordedExplanation,
      );
    });
  });

  group('C mismatch', () {
    test('modified bytes produce Integrity mismatch and keep the hash',
        () async {
      final original = await writeOriginal(const [0x00, 0x01, 0x02]);
      final recorded = EvidenceIntegrity.sha256OfBytes(_knownBytes);
      final entry = TrustPackageIntegrityProvenanceBuilder.fromItem(
        _item(
          id: 'photo',
          contentHash: recorded,
          filePath: original.path,
          thumbnailPath: '${tempDir.path}/thumb.bin',
        ),
      );

      expect(entry.state, TrustPackIntegrityState.mismatch);
      expect(entry.statusLabel, TrustPackIntegrityLabels.mismatch);
      expect(entry.contentHash, recorded);
      expect(
        entry.statusExplanation,
        TrustPackIntegrityLabels.mismatchExplanation,
      );
    });
  });

  group('D no payload', () {
    test('evidence without a hash is not reported as verified', () {
      final entry = TrustPackageIntegrityProvenanceBuilder.fromItem(
        _item(id: 'note', kind: WorkspaceEvidenceKind.note, title: 'Note'),
      );

      expect(entry.state, TrustPackIntegrityState.fingerprintUnavailable);
      expect(entry.statusLabel, TrustPackIntegrityLabels.fingerprintUnavailable);
      expect(entry.contentHash, isNull);
      expect(entry.originalPreserved, isFalse);
    });
  });

  group('E provenance display', () {
    test('timestamps, source, modality, and location come from evidence', () {
      final captured = DateTime(2026, 8, 15, 14, 32, 18);
      final preserved = DateTime(2026, 8, 15, 14, 32, 21);
      final entry = TrustPackageIntegrityProvenanceBuilder.fromItem(
        _item(
          id: 'photo',
          kind: WorkspaceEvidenceKind.image,
          deviceModel: 'Motorola moto g35 5G',
          latitude: 28.2096,
          longitude: 83.9856,
          capturedAt: captured,
          recordedAt: preserved,
          provenanceEvents: [
            EvidenceProvenanceEvent(
              type: EvidenceProvenanceType.captured,
              evidenceId: 'photo',
              at: captured,
              captureModality: 'Device Camera',
              source: 'Motorola moto g35 5G',
            ),
            EvidenceProvenanceEvent(
              type: EvidenceProvenanceType.preserved,
              evidenceId: 'photo',
              at: preserved,
              captureModality: 'Device Camera',
              source: 'Motorola moto g35 5G',
            ),
          ],
        ),
      );

      expect(entry.capturedAt, captured);
      expect(entry.preservedAt, preserved);
      expect(entry.source, 'Motorola moto g35 5G');
      expect(entry.captureModality, 'Device Camera');
      expect(
        entry.location,
        EvidenceFormatters.coordinates(28.2096, 83.9856),
      );
      expect(entry.locationUncertain, isFalse);
    });

    test('missing location is Unavailable and is not fabricated', () {
      final entry = TrustPackageIntegrityProvenanceBuilder.fromItem(
        _item(id: 'photo'),
      );
      expect(entry.location, TrustPackIntegrityLabels.locationUnavailable);
    });
  });

  group('F audit history', () {
    test('provenance events are displayed in chronological order', () {
      final captured = DateTime(2026, 8, 15, 14, 32, 18);
      final preserved = DateTime(2026, 8, 15, 14, 32, 21);
      final context = DateTime(2026, 8, 15, 14, 35, 4);
      final entry = TrustPackageIntegrityProvenanceBuilder.fromItem(
        _item(
          id: 'photo',
          provenanceEvents: [
            EvidenceProvenanceEvent(
              type: EvidenceProvenanceType.contextAdded,
              evidenceId: 'photo',
              at: context,
            ),
            EvidenceProvenanceEvent(
              type: EvidenceProvenanceType.captured,
              evidenceId: 'photo',
              at: captured,
            ),
            EvidenceProvenanceEvent(
              type: EvidenceProvenanceType.preserved,
              evidenceId: 'photo',
              at: preserved,
            ),
          ],
        ),
      );

      expect(entry.history.map((event) => event.label), [
        TrustPackIntegrityLabels.eventCaptured,
        TrustPackIntegrityLabels.eventPreserved,
        TrustPackIntegrityLabels.eventContextAdded,
      ]);
      expect(entry.history.map((event) => event.at), [
        captured,
        preserved,
        context,
      ]);
    });
  });

  group('G independent verification', () {
    test('SHA-256 verified does not mark independent verification', () async {
      final original = await writeOriginal(_knownBytes);
      final hash = EvidenceIntegrity.sha256OfBytes(_knownBytes);
      final section = TrustPackageIntegrityProvenanceBuilder.fromItems([
        _item(
          id: 'photo',
          contentHash: hash,
          filePath: original.path,
          thumbnailPath: '${tempDir.path}/thumb.bin',
          verification: VerificationModel.verified(
            verifiedAt: DateTime(2026, 8, 15, 15),
          ),
        ),
      ]);

      expect(section.reportsEntirePackVerified, isTrue);
      expect(section.packStatusLabel, TrustPackIntegrityLabels.verified);
      expect(
        section.entries.single.independentVerification,
        TrustPackIntegrityLabels.independentNotPerformed,
      );
      expect(
        section.entries.single.independentVerification,
        isNot(EvidenceInspectorSemantics.integrityVerified),
      );
      expect(
        section.entries.single.independentVerification,
        isNot(EvidenceInspectorSemantics.verifiedLabel),
      );
    });
  });

  group('H multi-evidence Trust Pack', () {
    test('mixed states do not report the entire pack as verified', () async {
      final original = await writeOriginal(_knownBytes);
      final hash = EvidenceIntegrity.sha256OfBytes(_knownBytes);
      const recorded =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final mutated = File('${tempDir.path}/mutated.bin');
      await mutated.writeAsBytes(const [0x00], flush: true);

      final section = TrustPackageIntegrityProvenanceBuilder.fromItems([
        _item(
          id: 'verified',
          title: 'Verified photo',
          contentHash: hash,
          filePath: original.path,
          thumbnailPath: '${tempDir.path}/thumb.bin',
        ),
        _item(
          id: 'recorded',
          title: 'Unavailable original',
          contentHash: recorded,
          filePath: '${tempDir.path}/missing.bin',
          thumbnailPath: '${tempDir.path}/thumb.bin',
        ),
        _item(
          id: 'mismatch',
          title: 'Changed photo',
          contentHash: hash,
          filePath: mutated.path,
          thumbnailPath: '${tempDir.path}/thumb.bin',
        ),
      ]);

      expect(section.verifiedCount, 1);
      expect(section.recordedCount, 1);
      expect(section.mismatchCount, 1);
      expect(section.reportsEntirePackVerified, isFalse);
      expect(section.packStatusLabel, TrustPackIntegrityLabels.mismatch);
      expect(section.packStatusLabel, isNot(TrustPackIntegrityLabels.verified));
      expect(
        section.packStatusSecondary,
        TrustPackIntegrityLabels.ofNVerified(1, 3),
      );
    });

  });

  group('I SHA-256 detail', () {
    test('detailed fingerprint is the persisted hash', () async {
      final original = await writeOriginal(_knownBytes);
      final hash = EvidenceIntegrity.sha256OfBytes(_knownBytes);
      final entry = TrustPackageIntegrityProvenanceBuilder.fromItem(
        _item(
          id: 'photo',
          contentHash: hash,
          filePath: original.path,
          thumbnailPath: '${tempDir.path}/thumb.bin',
        ),
      );

      expect(entry.contentHash, hash);
      expect(
        EvidenceInspectorSemantics.hashPreview(entry.contentHash!),
        EvidenceInspectorSemantics.hashPreview(hash),
      );
    });
  });

  testWidgets('section renders mixed integrity without claiming pack verified',
      (tester) async {
    const hash =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    final section = TrustPackageIntegrityProvenanceSection(
      entries: [
        TrustPackageIntegrityProvenanceEntry(
          evidenceId: 'verified',
          title: 'Verified photo',
          state: TrustPackIntegrityState.verified,
          originalPreserved: true,
          location: TrustPackIntegrityLabels.locationUnavailable,
          history: const [],
          contentHash: hash,
          independentVerification:
              TrustPackIntegrityLabels.independentNotPerformed,
        ),
        TrustPackageIntegrityProvenanceEntry(
          evidenceId: 'mismatch',
          title: 'Changed photo',
          state: TrustPackIntegrityState.mismatch,
          originalPreserved: false,
          location: TrustPackIntegrityLabels.locationUnavailable,
          history: const [],
          contentHash: hash,
          independentVerification:
              TrustPackIntegrityLabels.independentNotPerformed,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrustPackageIntegrityProvenanceView(section: section),
          ),
        ),
      ),
    );

    expect(section.packStatusLabel, TrustPackIntegrityLabels.mismatch);
    expect(find.text(TrustPackIntegrityLabels.mismatch), findsWidgets);
    expect(find.text(TrustPackIntegrityLabels.ofNVerified(1, 2)), findsOneWidget);
    expect(find.text(TrustPackIntegrityLabels.verified), findsOneWidget);
    expect(
      find.byKey(TrustPackageIntegrityProvenanceView.independentVerificationKey),
      findsOneWidget,
    );
    expect(find.text('Independently verified'), findsNothing);
    expect(find.text(hash), findsNothing);

    await tester.tap(find.text(TrustPackIntegrityLabels.integrityDetails).first);
    await tester.pump();
    expect(find.text(hash), findsWidgets);
    expect(
      find.text(EvidenceInspectorSemantics.hashPreview(hash)),
      findsWidgets,
    );
  });
}
