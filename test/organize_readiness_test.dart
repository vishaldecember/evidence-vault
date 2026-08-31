import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/organize/organize_readiness.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/workspace/organize_readiness_guide.dart';
import 'package:evidence_vault/widgets/workspace/product_concept_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _ev({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime at,
  String? contentHash,
  String? relatedPersonRole,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: kind.label,
    lastPreservedAt: at,
    capturedAt: kind.isPrimaryChronology ? at : null,
    recordedAt: kind.isPrimaryChronology ? null : at,
    contentHash: contentHash,
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    relatedPersonRole: relatedPersonRole,
  );
}

OrganizeReadiness _assess(
  List<WorkspaceEvidenceItem> evidence, {
  List<String>? capturedOrder,
}) {
  return OrganizeReadiness.assess(
    evidence: evidence,
    orderedCapturedEvidenceIds: capturedOrder ??
        [
          for (final item in evidence)
            if (item.kind.isPrimaryChronology) item.id,
        ],
  );
}

void main() {
  final t0 = DateTime.utc(2026, 8, 24, 10);
  final t1 = DateTime.utc(2026, 8, 24, 11);
  final t2 = DateTime.utc(2026, 8, 24, 12);

  test('A: Photo + Voice + Text with Voice/Text framing Photo is ready', () {
    final evidence = [
      _ev(id: 'v1', kind: WorkspaceEvidenceKind.voice, at: t0, contentHash: 'h-v'),
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t1, contentHash: 'h-p'),
      _ev(id: 'n1', kind: WorkspaceEvidenceKind.note, at: t2, contentHash: 'h-n'),
    ];
    final readiness = _assess(evidence, capturedOrder: ['v1', 'p1']);
    expect(readiness.isReady, isTrue);
    expect(readiness.matchedPattern, OrganizeReadinessPattern.photoVoiceText);
    expect(readiness.structureSummary, 'Voice → Photo → Text');
    expect(evidence.map((e) => e.id), ['v1', 'p1', 'n1']);
    expect(evidence.map((e) => e.contentHash), ['h-v', 'h-p', 'h-n']);
  });

  test('B: 2 Photos + Text is ready', () {
    final readiness = _assess([
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
      _ev(id: 'p2', kind: WorkspaceEvidenceKind.image, at: t1),
      _ev(id: 'n1', kind: WorkspaceEvidenceKind.note, at: t2),
    ]);
    expect(readiness.isReady, isTrue);
    expect(readiness.matchedPattern, OrganizeReadinessPattern.twoPhotosText);
  });

  test('C: Photo + Witness is ready', () {
    final readiness = _assess([
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
      _ev(id: 'w1', kind: WorkspaceEvidenceKind.witness, at: t1),
    ]);
    expect(readiness.isReady, isTrue);
    expect(readiness.matchedPattern, OrganizeReadinessPattern.photoWitness);
  });

  test('C: related-person role does not invent a Witness', () {
    final readiness = _assess([
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
      _ev(
        id: 'n1',
        kind: WorkspaceEvidenceKind.note,
        at: t1,
        relatedPersonRole: 'witness',
      ),
    ]);
    expect(readiness.isReady, isFalse);
    expect(readiness.composition.witnesses, 0);
  });

  test('D: Video + Text is ready', () {
    final readiness = _assess([
      _ev(id: 'vid1', kind: WorkspaceEvidenceKind.video, at: t0),
      _ev(id: 'n1', kind: WorkspaceEvidenceKind.note, at: t1),
    ]);
    expect(readiness.isReady, isTrue);
    expect(
      readiness.matchedPattern,
      OrganizeReadinessPattern.videoText,
    );
  });

  test('E: Video + Voice is ready', () {
    final readiness = _assess([
      _ev(id: 'vid1', kind: WorkspaceEvidenceKind.video, at: t0),
      _ev(id: 'v1', kind: WorkspaceEvidenceKind.voice, at: t1),
    ]);
    expect(readiness.isReady, isTrue);
    expect(readiness.matchedPattern, OrganizeReadinessPattern.videoVoice);
  });

  test('F: Video + Witness is ready', () {
    final readiness = _assess([
      _ev(id: 'vid1', kind: WorkspaceEvidenceKind.video, at: t0),
      _ev(id: 'w1', kind: WorkspaceEvidenceKind.witness, at: t1),
    ]);
    expect(readiness.isReady, isTrue);
    expect(readiness.matchedPattern, OrganizeReadinessPattern.videoWitness);
  });

  test('G: 2 Videos + Text is ready', () {
    final readiness = _assess([
      _ev(id: 'vid1', kind: WorkspaceEvidenceKind.video, at: t0),
      _ev(id: 'vid2', kind: WorkspaceEvidenceKind.video, at: t1),
      _ev(id: 'n1', kind: WorkspaceEvidenceKind.note, at: t2),
    ]);
    expect(readiness.isReady, isTrue);
  });

  test('H: 2 Videos + Voice is ready', () {
    final readiness = _assess([
      _ev(id: 'vid1', kind: WorkspaceEvidenceKind.video, at: t0),
      _ev(id: 'vid2', kind: WorkspaceEvidenceKind.video, at: t1),
      _ev(id: 'v1', kind: WorkspaceEvidenceKind.voice, at: t2),
    ]);
    expect(readiness.isReady, isTrue);
  });

  test('I: Photo + 2 Voice with Voice → Photo → Voice is ready', () {
    final evidence = [
      _ev(id: 'v1', kind: WorkspaceEvidenceKind.voice, at: t0),
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t1),
      _ev(id: 'v2', kind: WorkspaceEvidenceKind.voice, at: t2),
    ];
    final order = ['v1', 'p1', 'v2'];
    final readiness = _assess(evidence, capturedOrder: order);
    expect(readiness.isReady, isTrue);
    expect(readiness.matchedPattern, OrganizeReadinessPattern.photoTwoVoice);
    expect(readiness.structureSummary, 'Voice → Photo → Voice');
    expect(order, ['v1', 'p1', 'v2']);
  });

  test('I uses sequenceOrder, not timestamp order, for captured Voice → Photo → Voice',
      () {
    final readiness = _assess(
      [
        _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
        _ev(id: 'v2', kind: WorkspaceEvidenceKind.voice, at: t1),
        _ev(id: 'v1', kind: WorkspaceEvidenceKind.voice, at: t2),
      ],
      capturedOrder: ['v1', 'p1', 'v2'],
    );
    expect(readiness.isReady, isTrue);
    expect(readiness.matchedPattern, OrganizeReadinessPattern.photoTwoVoice);
    expect(readiness.structureSummary, 'Voice → Photo → Voice');
  });

  test('I: Photo + 2 Voice with Photo first is not that structure', () {
    final readiness = _assess(
      [
        _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
        _ev(id: 'v1', kind: WorkspaceEvidenceKind.voice, at: t1),
        _ev(id: 'v2', kind: WorkspaceEvidenceKind.voice, at: t2),
      ],
      capturedOrder: ['p1', 'v1', 'v2'],
    );
    expect(readiness.isReady, isFalse);
  });

  test('J: Photo + 2 Text with Text → Photo → Text is ready', () {
    final readiness = _assess(
      [
        _ev(id: 'n1', kind: WorkspaceEvidenceKind.note, at: t0),
        _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t1),
        _ev(id: 'n2', kind: WorkspaceEvidenceKind.note, at: t2),
      ],
      capturedOrder: ['p1'],
    );
    expect(readiness.isReady, isTrue);
    expect(readiness.matchedPattern, OrganizeReadinessPattern.photoTwoText);
    expect(readiness.structureSummary, 'Text → Photo → Text');
  });

  test('Attachment alone does not qualify', () {
    final readiness = _assess([
      _ev(id: 'a1', kind: WorkspaceEvidenceKind.attachment, at: t0),
    ]);
    expect(readiness.isReady, isFalse);
    expect(readiness.composition.attachments, 1);
    expect(readiness.nextUsefulMaterial, contains('Attachments'));
  });

  test('Photo + Attachment does not qualify', () {
    final readiness = _assess([
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
      _ev(id: 'a1', kind: WorkspaceEvidenceKind.attachment, at: t1),
    ]);
    expect(readiness.isReady, isFalse);
    expect(readiness.matchedPattern, isNull);
  });

  test('Single Photo remains not ready', () {
    final readiness = _assess([
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
    ]);
    expect(readiness.isReady, isFalse);
    expect(readiness.status, OrganizeReadinessStatus.notReady);
  });

  test('Single Video remains not ready', () {
    final readiness = _assess([
      _ev(id: 'vid1', kind: WorkspaceEvidenceKind.video, at: t0),
    ]);
    expect(readiness.isReady, isFalse);
  });

  test('adding qualifying evidence recalculates readiness', () {
    final photo = _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0);
    expect(_assess([photo]).isReady, isFalse);

    final withWitness = [
      photo,
      _ev(id: 'w1', kind: WorkspaceEvidenceKind.witness, at: t1),
    ];
    expect(_assess(withWitness).isReady, isTrue);
  });

  test('removing qualifying evidence recalculates readiness', () {
    final evidence = [
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
      _ev(id: 'w1', kind: WorkspaceEvidenceKind.witness, at: t1),
    ];
    expect(_assess(evidence).isReady, isTrue);
    expect(_assess([evidence.first]).isReady, isFalse);
  });

  test('attachments remain additive on a ready combination', () {
    final readiness = _assess([
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
      _ev(id: 'w1', kind: WorkspaceEvidenceKind.witness, at: t1),
      _ev(id: 'a1', kind: WorkspaceEvidenceKind.attachment, at: t2),
    ]);
    expect(readiness.isReady, isTrue);
    expect(readiness.composition.attachments, 1);
    expect(readiness.structureSummary, isNot(contains('Attachment')));
  });

  test('evidence identity and chronology inputs are unchanged by assess', () {
    final evidence = [
      _ev(
        id: 'p1',
        kind: WorkspaceEvidenceKind.image,
        at: t0,
        contentHash: 'hash-photo',
      ),
      _ev(id: 'n1', kind: WorkspaceEvidenceKind.note, at: t1, contentHash: 'hash-note'),
    ];
    final capturedOrder = ['p1'];
    final ids = [for (final item in evidence) item.id];
    final hashes = [for (final item in evidence) item.contentHash];
    final capturedAt = [for (final item in evidence) item.capturedAt];
    final lastPreserved = [for (final item in evidence) item.lastPreservedAt];

    _assess(evidence, capturedOrder: capturedOrder);

    expect([for (final item in evidence) item.id], ids);
    expect([for (final item in evidence) item.contentHash], hashes);
    expect([for (final item in evidence) item.capturedAt], capturedAt);
    expect([for (final item in evidence) item.lastPreservedAt], lastPreserved);
    expect(capturedOrder, ['p1']);
  });

  test('readiness is not an Incident field', () {
    final incident = Incident(
      id: 'inc-1',
      title: 'Parking dispute',
      status: IncidentStatus.active,
      createdAt: t0,
      updatedAt: t1,
    );
    _assess([
      _ev(id: 'p1', kind: WorkspaceEvidenceKind.image, at: t0),
    ]);
    expect(incident.id, 'inc-1');
    expect(incident.status, IncidentStatus.active);
    expect(incident.createdAt, t0);
    expect(
      OrganizeReadiness.assess(evidence: const []).runtimeType.toString(),
      isNot(incident.runtimeType.toString()),
    );
  });

  testWidgets('ⓘ guide educates without A–J labels or legal claims',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrganizeReadinessGuideSheet(),
        ),
      ),
    );

    expect(find.text(ProductConceptCopy.title), findsOneWidget);
    expect(find.byKey(ProductConceptChart.chartKey), findsOneWidget);
    expect(find.text(OrganizeReadinessCopy.unevaluableHeadline), findsNothing);
    expect(find.text(OrganizeReadinessCopy.nextStepLabel), findsNothing);
    expect(find.text('Useful combinations'), findsNothing);
    expect(find.text('1 Photo + 1 Voice + 1 Text'), findsNothing);
    expect(find.text('A:'), findsNothing);
    expect(find.text('Pattern A'), findsNothing);
    expect(find.textContaining('legally'), findsNothing);
    expect(find.textContaining('proven'), findsNothing);
    expect(find.textContaining('AI'), findsNothing);
    expect(find.textContaining('Coach'), findsNothing);
  });

  testWidgets('ⓘ button opens the Organize readiness guide', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrganizeReadinessInfoButton(),
        ),
      ),
    );

    await tester.tap(find.byKey(OrganizeReadinessInfoButton.buttonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(OrganizeReadinessGuideSheet.sheetKey), findsOneWidget);
    expect(find.text('How does an Incident become ready to organize?'), findsNothing);
    expect(find.text(ProductConceptCopy.title), findsOneWidget);
  });
}
