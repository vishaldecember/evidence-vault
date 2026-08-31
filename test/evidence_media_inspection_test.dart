import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/mappers/evidence_projection.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/navigation/app_navigation.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/screens/evidence_image_inspection_screen.dart';
import 'package:evidence_vault/screens/evidence_video_inspection_screen.dart';
import 'package:evidence_vault/screens/pdf_evidence_viewer_screen.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_media_source.dart';
import 'package:evidence_vault/widgets/evidence_inspector/pdf_document_surface.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _photo({
  String id = 'photo-1',
  String? filePath,
  String? thumbnailPath,
  String? contentHash = 'hash-inspect-1',
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.image,
    title: 'Street photo',
    lastPreservedAt: DateTime.utc(2026, 8, 20, 12),
    capturedAt: DateTime.utc(2026, 8, 20, 12),
    integrityVerified: false,
    verification: VerificationFactory.initial(),
    filePath: filePath,
    thumbnailPath: thumbnailPath,
    contentHash: contentHash,
    incidentId: 'incident-inspect',
  );
}

WorkspaceEvidenceItem _video({String? filePath}) {
  return WorkspaceEvidenceItem(
    id: 'video-1',
    kind: WorkspaceEvidenceKind.video,
    title: 'Clip',
    lastPreservedAt: DateTime.utc(2026, 8, 20, 12),
    capturedAt: DateTime.utc(2026, 8, 20, 12),
    integrityVerified: false,
    verification: VerificationFactory.initial(),
    filePath: filePath,
    incidentId: 'incident-inspect',
  );
}

WorkspaceEvidenceItem _pdf({String? filePath}) {
  return WorkspaceEvidenceItem(
    id: 'pdf-1',
    kind: WorkspaceEvidenceKind.attachment,
    title: 'Statement',
    lastPreservedAt: DateTime.utc(2026, 8, 20, 12),
    recordedAt: DateTime.utc(2026, 8, 20, 12),
    integrityVerified: false,
    verification: VerificationFactory.initial(),
    fileName: 'statement.pdf',
    filePath: filePath ?? '/missing/statement.pdf',
    incidentId: 'incident-inspect',
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

void main() {
  tearDown(() {
    EvidenceImageInspectionScreen.debugImageBuilder = null;
    PdfDocumentSurface.debugSurfaceBuilder = null;
  });

  group('inspection path', () {
    test('prefers a readable original image over the thumbnail', () {
      expect(
        EvidenceMediaSource.inspectionPath(
          _photo(filePath: null, thumbnailPath: '/thumb.jpg'),
        ),
        '/thumb.jpg',
      );
      expect(
        EvidenceMediaSource.isInspectionPreviewOnly(
          _photo(filePath: null, thumbnailPath: '/thumb.jpg'),
        ),
        isFalse,
      );
    });

    test('decode width is bounded and never zero', () {
      expect(
        EvidenceMediaSource.decodeWidth(
          logicalWidth: 12,
          devicePixelRatio: 1,
        ),
        64,
      );
      expect(
        EvidenceMediaSource.decodeWidth(
          logicalWidth: 4000,
          devicePixelRatio: 3,
          scale: 4,
        ),
        4096,
      );
    });
  });

  group('image inspection', () {
    testWidgets('opens from Inspector and dismisses without losing Inspector',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      EvidenceImageInspectionScreen.debugImageBuilder = (path) {
        return ColoredBox(
          key: Key('inspect_image_$path'),
          color: const Color(0xFFCCCCCC),
        );
      };

      await _openInspector(
        tester,
        item: _photo(filePath: r'C:\data\evidence\photo.jpg'),
      );
      expect(find.text('Evidence Inspector'), findsOneWidget);

      await tester.tap(find.byKey(const Key('evidence_image_open')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(EvidenceImageInspectionScreen.screenKey),
        findsOneWidget,
      );
      expect(find.byKey(EvidenceImageInspectionScreen.viewerKey), findsOneWidget);
      expect(find.text('Evidence Inspector'), findsNothing);

      await tester.tap(find.byKey(EvidenceImageInspectionScreen.closeKey));
      await tester.pumpAndSettle();

      expect(
        find.byKey(EvidenceImageInspectionScreen.screenKey),
        findsNothing,
      );
      expect(find.text('Evidence Inspector'), findsOneWidget);
      expect(find.text('Street photo'), findsNothing);
    });

    testWidgets('missing image explains the limitation without implying corruption',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      await tester.pumpWidget(
        MaterialApp(
          home: EvidenceImageInspectionScreen(
            evidence: _photo(filePath: '/missing/no-file.jpg'),
          ),
        ),
      );

      expect(find.byKey(EvidenceImageInspectionScreen.errorKey), findsOneWidget);
      expect(find.text('Photo unavailable'), findsOneWidget);
      expect(find.textContaining('corrupted'), findsNothing);
      expect(find.textContaining('original evidence was not changed'), findsOneWidget);
    });

    testWidgets('zoom in, reset, and zoom out stay bounded', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      EvidenceImageInspectionScreen.debugImageBuilder = (_) {
        return const ColoredBox(
          key: Key('inspect_image_ok'),
          color: Color(0xFFCCCCCC),
        );
      };

      await tester.pumpWidget(
        MaterialApp(
          home: EvidenceImageInspectionScreen(
            evidence: _photo(filePath: r'C:\data\evidence\photo.jpg'),
          ),
        ),
      );

      final viewer = tester.widget<InteractiveViewer>(
        find.byKey(EvidenceImageInspectionScreen.viewerKey),
      );
      expect(viewer.minScale, EvidenceImageInspectionScreen.minScale);
      expect(viewer.maxScale, EvidenceImageInspectionScreen.maxScale);
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);

      await tester.tap(find.byKey(EvidenceImageInspectionScreen.zoomInKey));
      await tester.pump();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1),
      );
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        lessThanOrEqualTo(EvidenceImageInspectionScreen.maxScale),
      );

      await tester.tap(find.byKey(EvidenceImageInspectionScreen.resetKey));
      await tester.pump();
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);

      await tester.tap(find.byKey(EvidenceImageInspectionScreen.zoomOutKey));
      await tester.pump();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        EvidenceImageInspectionScreen.minScale,
      );

      await tester.tap(find.byKey(EvidenceImageInspectionScreen.zoomInKey));
      await tester.pump();
      final before = viewer.transformationController!.value.clone();
      await tester.drag(
        find.byKey(EvidenceImageInspectionScreen.viewerKey),
        const Offset(-40, -24),
      );
      // InteractiveViewer tracks a short double-tap window; let it expire.
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewer.transformationController!.value, isNot(before));
    });

    testWidgets('system back returns to Inspector', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      EvidenceImageInspectionScreen.debugImageBuilder = (_) {
        return const SizedBox.shrink();
      };

      await _openInspector(
        tester,
        item: _photo(filePath: r'C:\data\evidence\photo.jpg'),
      );
      await tester.tap(find.byKey(const Key('evidence_image_open')));
      await tester.pumpAndSettle();
      expect(find.byKey(EvidenceImageInspectionScreen.screenKey), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(EvidenceImageInspectionScreen.screenKey), findsNothing);
      expect(find.text('Evidence Inspector'), findsOneWidget);
    });
  });

  group('video inspection', () {
    testWidgets('expanded video opens and returns on missing file',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      await _openInspector(tester, item: _video());
      expect(find.byKey(const Key('evidence_video_open_full')), findsOneWidget);

      await tester.tap(find.byKey(const Key('evidence_video_open_full')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(EvidenceVideoInspectionScreen.screenKey),
        findsOneWidget,
      );
      expect(find.byKey(EvidenceVideoInspectionScreen.errorKey), findsOneWidget);
      expect(find.text('Video unavailable'), findsWidgets);

      await tester.tap(find.byKey(EvidenceVideoInspectionScreen.closeKey));
      await tester.pumpAndSettle();
      expect(find.text('Evidence Inspector'), findsOneWidget);
    });
  });

  group('document inspection', () {
    testWidgets('Inspector PDF surface opens the existing viewer and returns',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      PdfDocumentSurface.debugSurfaceBuilder = (_) {
        return const SizedBox(key: Key('pdf_test_surface'));
      };

      await _openInspector(
        tester,
        item: _pdf(filePath: r'C:\data\evidence\statement.pdf'),
      );
      expect(find.byKey(const Key('pdf_evidence_open_full')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pdf_evidence_open_full')));
      await tester.pumpAndSettle();
      expect(find.byKey(PdfEvidenceViewerScreen.screenKey), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byKey(PdfEvidenceViewerScreen.screenKey), findsNothing);
      expect(find.text('Evidence Inspector'), findsOneWidget);
    });
  });

  group('integrity', () {
    test('inspection mapping does not mutate canonical evidence fields', () {
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
        thumbnailPath: '/evidence/a1_thumb.jpg',
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
      EvidenceImageInspectionScreen.sourcePath(projected);
      EvidenceVideoInspectionScreen.sourcePath(projected);
      AppNavigation.imageInspectionRouteName;
      AppNavigation.videoInspectionRouteName;

      expect(identical(store.capturedEvidence.single, evidence), isTrue);
      expect(store.capturedEvidence.single.id, 'evidence-a1');
      expect(store.capturedEvidence.single.incidentId, 'incident-a');
      expect(store.capturedEvidence.single.contentHash, 'hash-a1');
      expect(store.capturedEvidence.single.capturedAt, captured);
      expect(store.capturedEvidence.single.createdAt, created);
      expect(store.capturedEvidence.single.timelineOrder, 3);
      expect(store.capturedEvidence.single.filePath, '/evidence/a1.jpg');
      expect(store.timelineAnchors, isEmpty);
    });
  });
}
