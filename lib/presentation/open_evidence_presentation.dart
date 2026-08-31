import 'package:flutter/material.dart';

import '../models/workspace_evidence_item.dart';
import '../navigation/app_navigation.dart';
import 'evidence_presentation_resolver.dart';

/// Opens the dedicated PDF viewer when presentation is PDF; otherwise no-op.
abstract final class OpenEvidencePresentation {
  static Future<bool> openPdfIfNeeded(
    BuildContext context,
    WorkspaceEvidenceItem evidence,
  ) async {
    final presentation = EvidencePresentationResolver.resolve(evidence);
    if (presentation.previewKind != EvidencePresentationKind.pdf) {
      return false;
    }
    if (!context.mounted) {
      return false;
    }
    await AppNavigation.openPdfViewer(context, evidence: evidence);
    return true;
  }
}
