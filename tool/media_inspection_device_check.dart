import 'dart:io';

import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/evidence_image_inspection_screen.dart';
import 'package:evidence_vault/screens/evidence_video_inspection_screen.dart';
import 'package:evidence_vault/screens/pdf_evidence_viewer_screen.dart';
import 'package:evidence_vault/widgets/evidence_inspector/pdf_document_surface.dart';
import 'package:evidence_vault/widgets/evidence_inspector/pdf_native_viewer.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Device-only close-inspection check. Not part of the product navigation graph.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PdfDocumentSurface.nativeBuilder = buildNativePdfViewer;
  final dir = await getTemporaryDirectory();
  final photo = File('${dir.path}/ev_inspect_check.png');
  final large = File('${dir.path}/ev_inspect_large.png');
  await photo.writeAsBytes(_png(width: 640, height: 400));
  await large.writeAsBytes(_png(width: 2400, height: 1600));

  runApp(
    MaterialApp(
      home: _DeviceCheckHome(photoPath: photo.path, largePath: large.path),
    ),
  );
}

List<int> _png({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(28, 46, 72));
  for (var x = 0; x < width; x += 80) {
    img.drawLine(
      image,
      x1: x,
      y1: 0,
      x2: x,
      y2: height,
      color: img.ColorRgb8(180, 190, 210),
    );
  }
  for (var y = 0; y < height; y += 80) {
    img.drawLine(
      image,
      x1: 0,
      y1: y,
      x2: width,
      y2: y,
      color: img.ColorRgb8(180, 190, 210),
    );
  }
  return img.encodePng(image);
}

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  required String filePath,
  String? fileName,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: id,
    lastPreservedAt: DateTime.utc(2026, 8, 23),
    capturedAt: DateTime.utc(2026, 8, 23),
    integrityVerified: false,
    verification: VerificationFactory.initial(),
    filePath: filePath,
    fileName: fileName,
  );
}

class _DeviceCheckHome extends StatelessWidget {
  const _DeviceCheckHome({
    required this.photoPath,
    required this.largePath,
  });

  final String photoPath;
  final String largePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media inspection check')),
      body: ListView(
        children: [
          ListTile(
            key: const Key('open_small_photo'),
            title: const Text('Open photo'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EvidenceImageInspectionScreen(
                    evidence: _item(
                      id: 'photo-small',
                      kind: WorkspaceEvidenceKind.image,
                      filePath: photoPath,
                    ),
                  ),
                ),
              );
            },
          ),
          ListTile(
            key: const Key('open_large_photo'),
            title: const Text('Open large photo'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EvidenceImageInspectionScreen(
                    evidence: _item(
                      id: 'photo-large',
                      kind: WorkspaceEvidenceKind.image,
                      filePath: largePath,
                    ),
                  ),
                ),
              );
            },
          ),
          ListTile(
            key: const Key('open_video'),
            title: const Text('Open video'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EvidenceVideoInspectionScreen(
                    evidence: _item(
                      id: 'video-missing',
                      kind: WorkspaceEvidenceKind.video,
                      filePath: '/missing/clip.mp4',
                    ),
                  ),
                ),
              );
            },
          ),
          ListTile(
            key: const Key('open_pdf'),
            title: const Text('Open document'),
            onTap: () {
              const devicePdf = '/sdcard/Download/ev_21mb_gate.pdf';
              final pdfFile = File(devicePdf);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PdfEvidenceViewerScreen(
                    evidence: _item(
                      id: pdfFile.existsSync() ? 'pdf-gate' : 'pdf-missing',
                      kind: WorkspaceEvidenceKind.attachment,
                      filePath:
                          pdfFile.existsSync() ? devicePdf : '/missing/doc.pdf',
                      fileName: 'doc.pdf',
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
