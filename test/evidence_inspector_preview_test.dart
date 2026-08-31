import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_inspector_preview.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_preview_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/attachment_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/photo_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/text_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/video_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/voice_evidence_renderer.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:evidence_vault/models/evidence_artifact_model.dart';
import 'package:evidence_vault/widgets/evidence_inspector/pdf_document_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  String? fileName,
  String? notePreview,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 8, 5, 10, 30),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    fileName: fileName,
    notePreview: notePreview,
  );
}

Future<void> _openInspector(
  WidgetTester tester, {
  required WorkspaceEvidenceItem item,
}) async {
  final controller = WorkspaceEvidenceController(
    initialState: WorkspaceEvidenceState(items: [item]),
  );

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
                    evidence: item,
                    controller: controller,
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

void main() {
  group('EvidencePreviewRegistry', () {
    test('resolves typed renderers without a modal switch', () {
      expect(
        EvidencePreviewRegistry.resolve(EvidenceArtifactType.photo),
        isA<PhotoEvidenceRenderer>(),
      );
      expect(
        EvidencePreviewRegistry.resolve(EvidenceArtifactType.video),
        isA<VideoEvidenceRenderer>(),
      );
      expect(
        EvidencePreviewRegistry.resolve(EvidenceArtifactType.voiceRecording),
        isA<VoiceEvidenceRenderer>(),
      );
      expect(
        EvidencePreviewRegistry.resolve(EvidenceArtifactType.note),
        isA<TextEvidenceRenderer>(),
      );
      expect(
        EvidencePreviewRegistry.resolve(EvidenceArtifactType.document),
        isA<AttachmentEvidenceRenderer>(),
      );
    });
  });

  group('Evidence Inspector premium previews', () {
    testWidgets('photo preview fills inspector without overflow', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      await _openInspector(
        tester,
        item: _item(id: 'photo', kind: WorkspaceEvidenceKind.image),
      );

      expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
      expect(
        find.byKey(const Key('evidence_inspector_preview_frame')),
        findsOneWidget,
      );
      expect(find.text('Photo evidence'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('video preview shows play affordance and duration',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      await _openInspector(
        tester,
        item: _item(id: 'video', kind: WorkspaceEvidenceKind.video),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
      expect(find.text('0:42'), findsNothing);
      expect(find.text('248 KB'), findsNothing);
      expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('voice preview exposes waveform controls', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      await _openInspector(
        tester,
        item: _item(id: 'voice', kind: WorkspaceEvidenceKind.voice),
      );

      expect(find.byType(Slider), findsOneWidget);
      expect(find.byTooltip('Play voice note'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Play voice note'));
      await tester.pump();
      expect(find.byTooltip('Pause voice note'), findsOneWidget);
      await tester.tap(find.byTooltip('Pause voice note'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('text note preview is editable', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      await _openInspector(
        tester,
        item: _item(
          id: 'note',
          kind: WorkspaceEvidenceKind.note,
          notePreview: 'Initial observation.',
        ),
      );

      expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
      expect(find.text('Text note'), findsOneWidget);
      expect(find.text('Initial observation.'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('attachment preview shows file card without overflow',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(360, 640));

      await _openInspector(
        tester,
        item: _item(
          id: 'file',
          kind: WorkspaceEvidenceKind.attachment,
          fileName: 'incident_report_draft.docx',
        ),
      );

      expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
      expect(find.textContaining('incident_report_draft.docx'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PDF preview uses the PDF surface not a file card',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(360, 640));

      await _openInspector(
        tester,
        item: _item(
          id: 'pdf',
          kind: WorkspaceEvidenceKind.attachment,
          fileName: 'incident_report_draft.pdf',
        ),
      );

      expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
      expect(find.byKey(PdfDocumentSurface.errorKey), findsOneWidget);
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
