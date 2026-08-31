import 'package:flutter/material.dart';

import '../../../navigation/app_navigation.dart';
import '../evidence_preview_renderer.dart';
import '../pdf_document_surface.dart';

/// Real in-app PDF renderer for Inspector and Complete Record slots.
class PdfEvidenceRenderer extends EvidencePreviewRenderer {
  const PdfEvidenceRenderer();

  @override
  Widget build(BuildContext context, EvidencePreviewContext preview) {
    final evidence = preview.record.evidence;
    final alreadyOpen = ModalRoute.of(context)?.settings.name ==
        AppNavigation.pdfViewerRouteName;

    return Stack(
      fit: StackFit.expand,
      children: [
        PdfDocumentSurface(filePath: evidence.filePath),
        if (!alreadyOpen)
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Open PDF',
              child: GestureDetector(
                key: const Key('pdf_evidence_open_surface'),
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  AppNavigation.openPdfViewer(context, evidence: evidence);
                },
              ),
            ),
          ),
        if (!alreadyOpen)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.transparent,
                child: IconButton.filledTonal(
                  key: const Key('pdf_evidence_open_full'),
                  tooltip: 'Open PDF',
                  onPressed: () {
                    AppNavigation.openPdfViewer(context, evidence: evidence);
                  },
                  icon: const Icon(Icons.fullscreen),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
