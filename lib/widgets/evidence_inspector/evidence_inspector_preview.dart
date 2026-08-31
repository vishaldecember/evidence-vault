import 'package:flutter/material.dart';

import '../../models/evidence_record_model.dart';
import '../../models/workspace_evidence_item.dart';
import '../../presentation/evidence_presentation_resolver.dart';
import '../../theme/app_colors.dart';
import 'evidence_preview_renderer.dart';

/// Framed Evidence Inspector preview — a deliberate evidence frame.
class EvidenceInspectorPreview extends StatelessWidget {
  const EvidenceInspectorPreview({
    super.key,
    required this.record,
    this.onNoteBodyChanged,
  });

  final EvidenceRecordModel record;
  final ValueChanged<String>? onNoteBodyChanged;

  static const double frameRadius = 10;
  static const double borderWidth = 1.25;

  /// Neutral cool-gray letterbox for non-media evidence.
  static const Color surface = Color(0xFFF1F3F6);

  /// Inspector-local light-blue gutter for photo/video letterboxing.
  static const Color mediaGutter = Color(0xFFD9EAF6);

  static Color frameColorFor(WorkspaceEvidenceKind kind) {
    switch (kind) {
      case WorkspaceEvidenceKind.image:
      case WorkspaceEvidenceKind.video:
        return mediaGutter;
      case WorkspaceEvidenceKind.voice:
      case WorkspaceEvidenceKind.note:
      case WorkspaceEvidenceKind.attachment:
      case WorkspaceEvidenceKind.witness:
        return surface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final frameColor = frameColorFor(record.evidence.kind);
    return DecoratedBox(
      key: const Key('evidence_inspector_preview_frame'),
      decoration: BoxDecoration(
        color: frameColor,
        borderRadius: BorderRadius.circular(frameRadius),
        border: Border.all(
          color: AppColors.navy.withValues(alpha: 0.18),
          width: borderWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(frameRadius - borderWidth),
        child: ColoredBox(
          color: frameColor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              if (size.width <= 0 || size.height <= 0) {
                return const SizedBox.expand();
              }

              final renderer =
                  EvidencePresentationResolver.resolvePreview(record.evidence);
              return SizedBox.expand(
                child: ClipRect(
                  child: renderer.build(
                    context,
                    EvidencePreviewContext(
                      record: record,
                      availableSize: size,
                      onNoteBodyChanged: onNoteBodyChanged,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
