import 'dart:io';

import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_integrity.dart';
import 'package:evidence_vault/domain/evidence/evidence_provenance_event.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/verification_status.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/presentation/evidence_inspector_semantics.dart';
import 'package:evidence_vault/repositories/firebase/firestore_serializers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const knownBytes = <int>[0x45, 0x56, 0x31, 0x00, 0xFF];

  test('A hash is generated from known evidence bytes', () {
    final hash = EvidenceIntegrity.sha256OfBytes(knownBytes);
    expect(hash, isNotEmpty);
    expect(hash.length, 64);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
  });

  test('B the same original bytes produce the same SHA-256', () {
    final first = EvidenceIntegrity.sha256OfBytes(knownBytes);
    final second = EvidenceIntegrity.sha256OfBytes(List<int>.from(knownBytes));
    expect(second, first);
    expect(EvidenceIntegrity.sha256OfUtf8('canonical note'),
        EvidenceIntegrity.sha256OfUtf8('canonical note'));
  });

  test('C changing one byte changes the SHA-256', () {
    final original = EvidenceIntegrity.sha256OfBytes(knownBytes);
    final mutated = List<int>.from(knownBytes);
    mutated[0] = mutated[0] ^ 0x01;
    final changed = EvidenceIntegrity.sha256OfBytes(mutated);
    expect(changed, isNot(original));
  });

  test('D hash uses the original payload, not a thumbnail derivative', () async {
    final dir = await Directory.systemTemp.createTemp('ev_integrity_');
    addTearDown(() => dir.delete(recursive: true));
    final original = File('${dir.path}/original.bin');
    final thumbnail = File('${dir.path}/thumb.bin');
    await original.writeAsBytes(knownBytes, flush: true);
    await thumbnail.writeAsBytes(const [0x00, 0x01, 0x02], flush: true);

    final originalHash = await EvidenceIntegrity.sha256OfFile(original.path);
    final thumbHash = await EvidenceIntegrity.sha256OfFile(thumbnail.path);
    expect(originalHash, isNot(thumbHash));
    expect(originalHash, EvidenceIntegrity.sha256OfBytes(knownBytes));

    final check = await EvidenceIntegrity.verifyOriginal(
      recordedHash: originalHash,
      originalFilePath: original.path,
      thumbnailPath: thumbnail.path,
    );
    expect(check, EvidenceIntegrityCheck.match);

    final thumbAsOriginal = await EvidenceIntegrity.verifyOriginal(
      recordedHash: originalHash,
      originalFilePath: thumbnail.path,
      thumbnailPath: thumbnail.path,
      noteText: null,
    );
    expect(thumbAsOriginal, isNot(EvidenceIntegrityCheck.match));
  });

  test('E provenance events stay in chronological order', () async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-integrity', title: 'Case'),
    );
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final note = controller.addContextTextNote(
      parentEvidenceId: photo,
      text: 'Witness stood by the door.',
    )!;
    controller.setOrganizeContextAnchor(
      contextEvidenceId: note,
      capturedEvidenceId: photo,
    );

    final events = controller.evidenceRepository.provenanceEventsFor(note);
    expect(events.map((e) => e.type), [
      EvidenceProvenanceType.captured,
      EvidenceProvenanceType.preserved,
      EvidenceProvenanceType.contextAdded,
    ]);
    for (var i = 1; i < events.length; i++) {
      expect(
        !events[i].at.isBefore(events[i - 1].at),
        isTrue,
        reason: 'later provenance must not precede earlier events',
      );
    }
  });

  test('F later actions do not rewrite earlier provenance events', () async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-append', title: 'Case'),
    );
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final first = List.of(
      controller.evidenceRepository.provenanceEventsFor(photo),
    );
    expect(first, hasLength(2));
    expect(first.first.type, EvidenceProvenanceType.captured);
    expect(first.last.type, EvidenceProvenanceType.preserved);
    final capturedAt = first.first.at;
    final preservedAt = first.last.at;

    const recorded =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    controller.recordContentHash(evidenceId: photo, hash: recorded);
    controller.appendEvidenceProvenance(
      EvidenceProvenanceEvent(
        type: EvidenceProvenanceType.captured,
        evidenceId: photo,
        at: DateTime.utc(2030, 1, 1),
        captureModality: 'Device Camera',
      ),
    );
    controller.recordContentHash(
      evidenceId: photo,
      hash: 'should-not-overwrite',
    );
    controller.setOrganizeContextAnchor(
      contextEvidenceId: photo,
      capturedEvidenceId: photo,
    );

    final after = controller.evidenceRepository.provenanceEventsFor(photo);
    expect(after.first.type, EvidenceProvenanceType.captured);
    expect(after.first.at, capturedAt);
    expect(after[1].type, EvidenceProvenanceType.preserved);
    expect(after[1].at, preservedAt);
    expect(after.where((e) => e.type == EvidenceProvenanceType.captured),
        hasLength(1));
    expect(after.where((e) => e.type == EvidenceProvenanceType.preserved),
        hasLength(1));
    expect(
      controller.currentIncident.evidenceById(photo)!.contentHash,
      recorded,
    );
  });

  test('G serialize persist reload keeps id, hash, clocks, and events', () {
    final capturedAt = DateTime.utc(2026, 8, 29, 8, 32, 18);
    final preservedAt = DateTime.utc(2026, 8, 29, 8, 32, 21);
    const hash =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final original = CapturedEvidence(
      id: 'ev-integrity-1',
      incidentId: 'inc-integrity',
      type: CapturedEvidenceType.photo,
      capturedAt: capturedAt,
      createdAt: preservedAt,
      title: 'Photo Evidence',
      integrityVerified: true,
      verification: VerificationFactory.initial(),
      timelineAnchorId: 'anchor-ev-integrity-1',
      contentHash: hash,
      filePath: '/vault/original.jpg',
      thumbnailPath: '/vault/thumb.jpg',
      provenanceEvents: [
        EvidenceProvenanceEvent(
          type: EvidenceProvenanceType.captured,
          evidenceId: 'ev-integrity-1',
          at: capturedAt,
          captureModality: 'Device Camera',
          source: 'Motorola moto g35 5G',
        ),
        EvidenceProvenanceEvent(
          type: EvidenceProvenanceType.preserved,
          evidenceId: 'ev-integrity-1',
          at: preservedAt,
          captureModality: 'Device Camera',
          source: 'Motorola moto g35 5G',
          contentHash: hash,
          storageReference: '/vault/original.jpg',
        ),
      ],
    );

    final map = FirestoreSerializers.capturedToMap(
      original,
      userId: 'user-1',
      timelineOrder: 0,
      supportingEvidenceIds: const [],
    );
    final restored = FirestoreSerializers.capturedFromMap(map)!;

    expect(restored.id, original.id);
    expect(restored.contentHash, hash);
    expect(restored.capturedAt.toUtc(), capturedAt);
    expect(restored.createdAt!.toUtc(), preservedAt);
    expect(restored.provenanceEvents, hasLength(2));
    expect(restored.provenanceEvents.first.type, EvidenceProvenanceType.captured);
    expect(restored.provenanceEvents.first.at.toUtc(), capturedAt);
    expect(restored.provenanceEvents.last.type, EvidenceProvenanceType.preserved);
    expect(restored.provenanceEvents.last.contentHash, hash);
    expect(restored.filePath, isNull); // local path is not a Firestore field
    expect(restored.thumbnailPath, isNull);
  });

  test('H a recorded hash is not independent verification', () async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-verify', title: 'Case'),
    );
    final note = controller.preserveForWidgetTest(
      WorkspaceCaptureMode.note,
      noteText: 'Door was already open.',
    );
    final item = controller.currentIncident.evidenceById(note)!;
    expect(item.contentHash, isNotNull);
    expect(item.contentHash, EvidenceIntegrity.sha256OfUtf8('Door was already open.'));
    expect(item.verification.status, VerificationStatus.notVerified);
    expect(
      EvidenceInspectorSemantics.integrityStatus(item),
      EvidenceInspectorSemantics.integrityNotVerified,
    );
    expect(
      EvidenceInspectorSemantics.fingerprintStatus(item),
      EvidenceInspectorSemantics.fingerprintRecorded,
    );
    expect(
      EvidenceInspectorSemantics.fingerprintStatus(item),
      isNot(EvidenceInspectorSemantics.integrityVerified),
    );

    final match = await controller.verifyEvidenceIntegrity(note);
    expect(match, EvidenceIntegrityCheck.match);

    controller.recordContentHash(
      evidenceId: note,
      hash: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    );
    expect(item.contentHash, isNot(startsWith('fff')));
    expect(
      controller.currentIncident.evidenceById(note)!.contentHash,
      item.contentHash,
    );
    expect(
      await controller.verifyEvidenceIntegrity(note),
      EvidenceIntegrityCheck.match,
    );
  });

  test('mismatch stays detectable and does not repair the recorded hash',
      () async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-mismatch', title: 'Case'),
    );
    final note = controller.preserveForWidgetTest(
      WorkspaceCaptureMode.note,
      noteText: 'Original wording.',
    );
    final recorded = controller.currentIncident.evidenceById(note)!.contentHash;
    expect(recorded, isNotNull);

    controller.updateEvidenceNoteText(
      evidenceId: note,
      text: 'Original wording was changed.',
    );
    expect(
      controller.currentIncident.evidenceById(note)!.contentHash,
      recorded,
    );
    expect(
      await controller.verifyEvidenceIntegrity(note),
      EvidenceIntegrityCheck.mismatch,
    );
  });
}
