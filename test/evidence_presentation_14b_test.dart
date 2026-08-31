import 'package:evidence_vault/models/evidence_record_model.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/navigation/app_navigation.dart';
import 'package:evidence_vault/presentation/evidence_presentation_resolver.dart';
import 'package:evidence_vault/screens/pdf_evidence_viewer_screen.dart';
import 'package:evidence_vault/widgets/evidence_inspector/pdf_document_surface.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/pdf_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_inspector/renderers/video_evidence_renderer.dart';
import 'package:evidence_vault/widgets/evidence_record/evidence_record_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _pdfItem({
  String id = 'pdf-1',
  String? filePath,
  int fileSizeBytes = 21113500,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.attachment,
    title: 'Brief',
    lastPreservedAt: DateTime(2026, 8, 19, 15),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    fileName: 'brief.pdf',
    filePath: filePath,
    mimeType: 'application/pdf',
    fileSizeBytes: fileSizeBytes,
    incidentId: 'incident-14b',
  );
}

WorkspaceEvidenceItem _videoItem() {
  return WorkspaceEvidenceItem(
    id: 'vid-1',
    kind: WorkspaceEvidenceKind.video,
    title: 'Clip',
    lastPreservedAt: DateTime(2026, 8, 19, 15),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    fileName: 'clip.mp4',
    filePath: '/data/clip.mp4',
    mimeType: 'video/mp4',
    fileSizeBytes: 4096,
    incidentId: 'incident-14b',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PdfDocumentSurface.debugSurfaceBuilder = null;
  });

  tearDown(() {
    PdfDocumentSurface.debugSurfaceBuilder = null;
  });

  group('PDF presentation boundary', () {
    test('PDF evidence resolves to the PDF renderer', () {
      final item = _pdfItem(filePath: '/durable/brief.pdf');
      final presentation = EvidencePresentationResolver.resolve(item);
      expect(item.kind, WorkspaceEvidenceKind.attachment);
      expect(presentation.semanticKind, WorkspaceEvidenceKind.attachment);
      expect(presentation.previewKind, EvidencePresentationKind.pdf);
      expect(presentation.renderer, isA<PdfEvidenceRenderer>());
      expect(
        EvidencePresentationResolver.resolvePreview(item),
        isA<PdfEvidenceRenderer>(),
      );
    });

    test('PDF renderer receives the existing durable filePath', () {
      const durable = '/data/evidence_cache/incident-14b/ev-pdf.pdf';
      final item = _pdfItem(filePath: durable);
      final presentation = EvidencePresentationResolver.resolve(item);
      expect(presentation.playbackPath, durable);
      expect(PdfEvidenceViewerScreen.sourcePath(item), durable);
      expect(PdfEvidenceViewerScreen.sourcePath(item), item.filePath);
    });

    test('does not create a second permanent copy merely for viewing', () {
      const durable = '/data/evidence_cache/incident-14b/ev-pdf.pdf';
      final item = _pdfItem(filePath: durable);
      expect(PdfEvidenceViewerScreen.sourcePath(item), durable);
      expect(PdfEvidenceViewerScreen.sourcePath(item), isNot(contains('/tmp/')));
      expect(
        PdfEvidenceViewerScreen.sourcePath(item),
        isNot(contains('file_picker')),
      );
    });

    test('Complete Record uses the same PDF presentation boundary', () {
      final item = _pdfItem(filePath: '/durable/brief.pdf');
      expect(
        EvidencePresentationResolver.resolveCompleteRecordPresentation(item),
        isA<PdfEvidenceRenderer>(),
      );
      expect(
        identical(
          EvidencePresentationResolver.resolveCompleteRecordPresentation(item)
              .runtimeType,
          EvidencePresentationResolver.resolvePreview(item).runtimeType,
        ),
        isTrue,
      );
    });

    test('video/photo/voice presentation is unchanged', () {
      expect(
        EvidencePresentationResolver.resolve(_videoItem()).renderer,
        isA<VideoEvidenceRenderer>(),
      );
      expect(
        EvidencePresentationResolver.resolve(_videoItem()).previewKind,
        EvidencePresentationKind.video,
      );
    });

    test('real fileSizeBytes remains available', () {
      final item = _pdfItem(fileSizeBytes: 21113500);
      final metadata = EvidencePresentationResolver.resolveMetadata(item);
      expect(metadata.fileSize, isNot('248 KB'));
      expect(metadata.fileSize, contains('MB'));
      expect(metadata.duration, isNull);
      expect(item.fileSizeBytes, 21113500);
    });

    test('PDF viewer does not modify evidence identity or count', () {
      final items = [
        _pdfItem(id: 'pdf-1', filePath: '/durable/a.pdf'),
        _videoItem(),
      ];
      EvidencePresentationResolver.resolve(items[0]);
      PdfEvidenceViewerScreen.sourcePath(items[0]);
      expect(items.map((e) => e.id).toList(), ['pdf-1', 'vid-1']);
      expect(items.length, 2);
      expect(items[0].incidentId, 'incident-14b');
      expect(items[0].filePath, '/durable/a.pdf');
    });
  });

  group('PDF viewer surface', () {
    testWidgets('missing file produces a controlled error', (tester) async {
      final item = _pdfItem(filePath: '/missing/does-not-exist.pdf');
      await tester.pumpWidget(
        MaterialApp(
          home: PdfEvidenceViewerScreen(evidence: item),
        ),
      );
      expect(find.byKey(PdfEvidenceViewerScreen.screenKey), findsOneWidget);
      expect(find.byKey(PdfDocumentSurface.errorKey), findsOneWidget);
      expect(find.text('PDF is unavailable'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('readable path is handed to the document surface',
        (tester) async {
      const durable = r'C:\data\evidence_cache\incident-14b\ev-pdf.pdf';
      String? openedPath;
      PdfDocumentSurface.debugSurfaceBuilder = (path) {
        openedPath = path;
        return const ColoredBox(
          key: Key('pdf_test_surface'),
          color: Color(0xFFEEEEEE),
        );
      };

      final item = _pdfItem(filePath: durable);
      await tester.pumpWidget(
        MaterialApp(
          home: PdfEvidenceViewerScreen(evidence: item),
        ),
      );

      expect(openedPath, durable);
      expect(find.byKey(PdfDocumentSurface.viewerKey), findsOneWidget);
      expect(find.byKey(const Key('pdf_test_surface')), findsOneWidget);
      expect(find.textContaining('248 KB'), findsNothing);
    });

    testWidgets('Android Back / close returns to the previous route',
        (tester) async {
      PdfDocumentSurface.debugSurfaceBuilder = (path) {
        return const SizedBox(key: Key('pdf_test_surface'));
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      AppNavigation.openPdfViewer(
                        context,
                        evidence: _pdfItem(
                          filePath: r'C:\data\evidence_cache\incident-14b\a.pdf',
                        ),
                      );
                    },
                    child: const Text('Workspace'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Workspace'), findsOneWidget);
      await tester.tap(find.text('Workspace'));
      await tester.pumpAndSettle();
      expect(find.byKey(PdfEvidenceViewerScreen.screenKey), findsOneWidget);
      expect(find.text('Workspace'), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byKey(PdfEvidenceViewerScreen.screenKey), findsNothing);
      expect(find.text('Workspace'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('Complete Record hosts the PDF renderer', (tester) async {
      PdfDocumentSurface.debugSurfaceBuilder = (path) {
        return const SizedBox(key: Key('pdf_test_surface'));
      };

      final item = _pdfItem(
        filePath: r'C:\data\evidence_cache\incident-14b\brief.pdf',
      );
      final record = EvidenceRecordModel.fromWorkspace(
        evidence: item,
        allItems: [item],
        relationships: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceRecordPreview(record: record),
          ),
        ),
      );

      expect(find.byKey(const Key('pdf_test_surface')), findsOneWidget);
    });
  });
}
