import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_artifact_model.dart';
import '../../models/evidence_record_model.dart';
import '../../presentation/evidence_presentation_resolver.dart';
import '../../theme/app_colors.dart';
import '../evidence_inspector/evidence_preview_renderer.dart';

/// Type-adaptive evidence preview — preferred heights differ by media kind.
///
/// Preview widgets come from [EvidencePresentationResolver] so Complete Record
/// shares Inspector renderers. Never forces identical heights across types.
class EvidenceRecordPreview extends StatelessWidget {
  const EvidenceRecordPreview({
    super.key,
    required this.record,
    this.heightScale = 1,
    this.maxHeight,
  });

  final EvidenceRecordModel record;

  /// Scales preferred height for compact surfaces such as the Evidence Inspector.
  final double heightScale;

  /// Optional hard cap (e.g. from a [LayoutBuilder] slot).
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final presentation = EvidencePresentationResolver.resolve(record.evidence);
    final preferred = (presentation.previewKind == EvidencePresentationKind.pdf
            ? 280.0
            : preferredHeightFor(presentation.artifactType)) *
        heightScale;
    final capped = maxHeight == null
        ? preferred
        : math.min(preferred, maxHeight!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: ColoredBox(
        color: AppColors.surfaceMuted,
        child: SizedBox(
          width: double.infinity,
          height: math.max(capped, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              if (size.width <= 0 || size.height <= 0) {
                return const SizedBox.shrink();
              }
              final renderer = presentation.renderer;
              return renderer.build(
                context,
                EvidencePreviewContext(
                  record: record,
                  availableSize: size,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Intrinsic preferred height by evidence type — used by inspector flex math.
  static double preferredHeightFor(EvidenceArtifactType type) =>
      switch (type) {
        EvidenceArtifactType.photo => 220,
        EvidenceArtifactType.video => 160,
        EvidenceArtifactType.voiceRecording => 96,
        EvidenceArtifactType.document => 104,
        EvidenceArtifactType.note => 140,
      };

  /// Back-compat alias for callers that still use the old name.
  static double previewHeightFor(EvidenceArtifactType type) =>
      preferredHeightFor(type);
}
