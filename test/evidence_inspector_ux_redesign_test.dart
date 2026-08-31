import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/mappers/evidence_projection.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/presentation/evidence_inspector_semantics.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_inspector_preview.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/evidence_inspector/pdf_document_surface.dart';
import 'package:evidence_vault/widgets/investigation/inspector_context_section.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  DateTime? capturedAt,
  DateTime? recordedAt,
  String? title,
  String? fileName,
  String? notePreview,
  String? contentHash,
  String? deviceModel,
  int? fileSizeBytes,
  String incidentId = 'incident-1',
}) {
  final captured = capturedAt ?? DateTime.utc(2026, 8, 20, 12);
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: title ?? 'Evidence $id',
    lastPreservedAt: captured,
    capturedAt: captured,
    recordedAt: recordedAt,
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    fileName: fileName,
    notePreview: notePreview,
    contentHash: contentHash,
    deviceModel: deviceModel,
    fileSizeBytes: fileSizeBytes,
    incidentId: incidentId,
  );
}

Finder get _contextField => find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == InspectorContextSection.placeholder,
    );

Future<void> _openInspector(
  WidgetTester tester, {
  required WorkspaceEvidenceController controller,
  required WorkspaceEvidenceItem evidence,
  List<WorkspaceEvidenceItem>? ordered,
  Future<void> Function(WorkspaceEvidenceItem evidence)? onOpenAdvancedRecord,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  showInvestigationEvidenceInspectorModal(
                    context: context,
                    evidence: evidence,
                    controller: controller,
                    orderedEvidence: ordered ??
                        evidenceInspectorOrder(controller.journeyEvidenceItems),
                    onOpenAdvancedRecord: onOpenAdvancedRecord,
                  );
                },
                child: const Text('Open Inspector'),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('Open Inspector'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

void _expectNoAiConclusions() {
  expect(find.textContaining('AI OBSERVATION'), findsNothing);
  expect(find.textContaining('Possible recurring'), findsNothing);
  expect(find.textContaining('harassment'), findsNothing);
  expect(find.textContaining('stalking'), findsNothing);
  expect(find.textContaining('risk score'), findsNothing);
  expect(find.textContaining('similarity score'), findsNothing);
  expect(find.text('Verified ✓'), findsNothing);
  expect(find.text('Original Preserved'), findsNothing);
}

void main() {
  group('chronology mapping', () {
    test('uses sequenceOrder list and does not invent missing positions', () {
      final position = EvidenceInspectorSemantics.chronologyPosition(
        evidenceId: 'photo-b',
        orderedCapturedEvidenceIds: const ['photo-a', 'photo-b', 'photo-c'],
      );

      expect(position, isNotNull);
      expect(position!.ordinal, 2);
      expect(position.total, 3);
      expect(position.headline, 'Evidence 2 of 3');
      expect(
        EvidenceInspectorSemantics.chronologyPosition(
          evidenceId: 'note-1',
          orderedCapturedEvidenceIds: const ['photo-a', 'photo-b'],
        ),
        isNull,
      );
    });
  });

  group('media', () {
    testWidgets('image evidence is primary and keeps stable missing-preview copy',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo', kind: WorkspaceEvidenceKind.image)],
        ),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
      expect(find.text('Photo evidence'), findsOneWidget);
      expect(find.text('Preview unavailable'), findsOneWidget);
      expect(find.byKey(const Key('evidence_inspector_identity')), findsOneWidget);
      _expectNoAiConclusions();
    });

    testWidgets('video evidence keeps discoverable playback and specific failure',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'video', kind: WorkspaceEvidenceKind.video)],
        ),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
      expect(find.text('Video evidence'), findsOneWidget);
      expect(find.text('Preview unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('audio evidence is a playback surface without a fabricated waveform',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'voice', kind: WorkspaceEvidenceKind.voice)],
        ),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.text('Voice Note'), findsWidgets);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byTooltip('Play voice note'), findsOneWidget);
      expect(find.byKey(const Key('evidence_inspector_audio_player')), findsOneWidget);
    });

    testWidgets('document evidence shows identity and PDF surface failure',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(360, 640));
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(
              id: 'pdf',
              kind: WorkspaceEvidenceKind.attachment,
              fileName: 'statement.pdf',
            ),
          ],
        ),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
      expect(find.byKey(PdfDocumentSurface.errorKey), findsOneWidget);
      expect(find.text('PDF is unavailable'), findsOneWidget);
      expect(find.text('Device'), findsOneWidget);
      expect(find.text('File Import / Attachment'), findsOneWidget);
    });
  });

  group('facts and context', () {
    testWidgets('shows only existing facts with truthful timestamp labels',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final captured = DateTime.utc(2026, 8, 20, 15, 4, 5);
      final recorded = DateTime.utc(2026, 8, 21, 9);
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          incidentName: 'Downtown incident',
          items: [
            _item(
              id: 'photo',
              kind: WorkspaceEvidenceKind.image,
              capturedAt: captured,
              recordedAt: recorded,
              deviceModel: 'Pixel 8',
              fileSizeBytes: 2048,
            ),
          ],
        ),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.text('Downtown incident'), findsOneWidget);
      expect(find.byKey(const Key('evidence_inspector_facts')), findsOneWidget);
      expect(find.text('Capture modality'), findsOneWidget);
      expect(find.text('Device Camera'), findsOneWidget);
      expect(find.text('Captured'), findsWidgets);
      expect(find.text('Recorded'), findsOneWidget);
      expect(find.text('Device'), findsOneWidget);
      expect(find.text('Pixel 8'), findsOneWidget);
      expect(find.text('File size'), findsOneWidget);
      expect(find.text('Timestamp'), findsNothing);
      expect(find.text('Date'), findsNothing);
      expect(find.byKey(const Key('evidence_inspector_timestamp')), findsOneWidget);
    });

    testWidgets('empty context is a lightweight authored affordance',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo', kind: WorkspaceEvidenceKind.image)],
        ),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.text('Your observation'), findsOneWidget);
      expect(
        find.byKey(const Key('evidence_inspector_add_observation')),
        findsOneWidget,
      );
      expect(_contextField, findsNothing);

      await tester.ensureVisible(
        find.byKey(const Key('evidence_inspector_add_observation')),
      );
      await tester.tap(find.byKey(const Key('evidence_inspector_add_observation')));
      await tester.pump();

      expect(_contextField, findsOneWidget);
      expect(find.text(InspectorContextSection.placeholder), findsOneWidget);
    });
  });

  group('chronology integrity relationships', () {
    testWidgets('presents sequenceOrder position without a new chronology field',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.video);
      final orderedIds =
          controller.timelineRepository.orderedCapturedEvidenceIds();
      final second = controller.journeyEvidenceItems.firstWhere(
        (item) => item.id == orderedIds[1],
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: second,
      );

      expect(find.text('Chronology'), findsOneWidget);
      expect(find.text('Evidence 2 of 2'), findsOneWidget);
      expect(find.text('Position 2 in this incident'), findsOneWidget);
      expect(
        controller.timelineRepository.orderedCapturedEvidenceIds(),
        orderedIds,
      );
    });

    testWidgets('supporting items do not invent an N of M chronology',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(id: 'photo', kind: WorkspaceEvidenceKind.image),
            _item(
              id: 'note',
              kind: WorkspaceEvidenceKind.note,
              notePreview: 'A note',
            ),
          ],
        ),
      );
      final note = controller.state.items.firstWhere((item) => item.id == 'note');

      await _openInspector(
        tester,
        controller: controller,
        evidence: note,
        ordered: [note],
      );

      expect(
        find.text(EvidenceInspectorSemantics.chronologyUnsupported),
        findsOneWidget,
      );
      expect(find.textContaining('Evidence 1 of'), findsNothing);
    });

    testWidgets('fingerprint and independent verification are not shown',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final withHash = _item(
        id: 'hashed',
        kind: WorkspaceEvidenceKind.image,
        contentHash: 'abcdef0123456789deadbeef42',
      );
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(items: [withHash]),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.text('Independent verification'), findsNothing);
      expect(find.text('SHA-256 recorded'), findsOneWidget);
      expect(find.text('abcdef0123456789deadbeef42'), findsNothing);
      expect(find.byKey(const Key('evidence_inspector_hash')), findsNothing);
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('imported media is not presented as independently verified',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'file', kind: WorkspaceEvidenceKind.attachment)],
        ),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.text('Independent verification'), findsNothing);
      expect(find.text('Fingerprint'), findsNothing);
      expect(find.text('Verified'), findsNothing);
      expect(find.text('Independently verified'), findsNothing);
    });

    testWidgets('relationships show connected records, not AI inference',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final photo = _item(id: 'photo', kind: WorkspaceEvidenceKind.image);
      final video = _item(id: 'video', kind: WorkspaceEvidenceKind.video);
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [photo, video],
          relationships: [
            EvidenceRelationship(
              id: 'rel-1',
              sourceEvidenceId: 'photo',
              targetEvidenceId: 'video',
              type: RelationshipType.supports,
              createdAt: DateTime.utc(2026, 8, 20),
              source: 'user',
            ),
          ],
        ),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.firstWhere((e) => e.id == 'photo'),
      );

      expect(find.text('Relationships'), findsOneWidget);
      expect(
        find.text(EvidenceInspectorSemantics.relationshipsCaption),
        findsOneWidget,
      );
      expect(find.text('Connected evidence'), findsOneWidget);
      expect(find.text('Related People'), findsOneWidget);
      _expectNoAiConclusions();
    });
  });

  group('regression', () {
    testWidgets('inspector opens, closes, and keeps incident association',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          incidentName: 'Alpha',
          items: [_item(id: 'photo', kind: WorkspaceEvidenceKind.image)],
        ),
      );
      final incidentId = controller.currentIncident.id;
      final evidenceId = controller.journeyEvidenceItems.first.id;

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
        onOpenAdvancedRecord: (_) async {},
      );

      expect(find.text('Evidence Inspector'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('View complete record →'), findsOneWidget);
      expect(find.byType(EvidenceSpatialCarousel), findsOneWidget);
      _expectNoAiConclusions();

      await tester.tap(find.byKey(const Key('evidence_inspector_close')));
      await tester.pumpAndSettle();

      expect(find.text('Evidence Inspector'), findsNothing);
      expect(controller.currentIncident.id, incidentId);
      expect(controller.journeyEvidenceItems.first.id, evidenceId);
    });

    test('opening inspector mapping does not mutate canonical evidence fields',
        () {
      final captured = DateTime.utc(2026, 8, 20, 12);
      final created = DateTime.utc(2026, 8, 20, 12, 0, 1);
      final evidence = CapturedEvidence(
        id: 'evidence-a1',
        incidentId: 'incident-a',
        type: CapturedEvidenceType.photo,
        capturedAt: captured,
        createdAt: created,
        title: 'Photo',
        integrityVerified: false,
        verification: VerificationFactory.initial(),
        timelineAnchorId: 'anchor-a1',
        contentHash: 'hash-a1',
        timelineOrder: 3,
        filePath: '/evidence/a1.jpg',
      );
      final store = IncidentStore(
        incident: Incident(
          id: 'incident-a',
          title: 'Alpha',
          status: IncidentStatus.active,
          createdAt: DateTime.utc(2026, 8, 20),
          updatedAt: DateTime.utc(2026, 8, 21),
        ),
        capturedEvidence: [evidence],
      );

      final projected = EvidenceProjection.toWorkspaceItems(store).single;
      expect(projected.contentHash, 'hash-a1');
      expect(identical(store.capturedEvidence.single, evidence), isTrue);
      expect(store.capturedEvidence.single.contentHash, 'hash-a1');
      expect(store.capturedEvidence.single.id, 'evidence-a1');
      expect(store.capturedEvidence.single.incidentId, 'incident-a');
      expect(store.capturedEvidence.single.capturedAt, captured);
      expect(store.capturedEvidence.single.createdAt, created);
      expect(store.capturedEvidence.single.timelineOrder, 3);
      expect(store.capturedEvidence.single.filePath, '/evidence/a1.jpg');
    });
  });
}
