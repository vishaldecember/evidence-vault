import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/workspace_capture_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/capture_mode_icon.dart';

/// Product-level visual guide of meaningful evidence compositions.
///
/// Presentation only. Does not assess an incident, write chronology, treat
/// context as evidence, or create evidence/context relationships.
class EvidenceCompositionGuide extends StatelessWidget {
  const EvidenceCompositionGuide({super.key});

  static const Key guideKey = Key('evidence_composition_guide');
  static const title = 'Evidence Composition';
  static const subtitle = 'Helpful ways to compose what you preserved';

  static const plusJoiner = ' + ';
  static const sequenceJoiner = ' → ';

  static const compositions = <EvidenceCompositionPattern>[
    EvidenceCompositionPattern.together([
      EvidenceCompositionModality.photo,
      EvidenceCompositionModality.voice,
      EvidenceCompositionModality.text,
    ]),
    EvidenceCompositionPattern.sequence([
      EvidenceCompositionModality.photo,
      EvidenceCompositionModality.text,
      EvidenceCompositionModality.photo,
    ]),
    EvidenceCompositionPattern.together([
      EvidenceCompositionModality.photo,
      EvidenceCompositionModality.witness,
    ]),
    EvidenceCompositionPattern.together([
      EvidenceCompositionModality.video,
      EvidenceCompositionModality.text,
    ]),
    EvidenceCompositionPattern.together([
      EvidenceCompositionModality.video,
      EvidenceCompositionModality.voice,
    ]),
    EvidenceCompositionPattern.together([
      EvidenceCompositionModality.video,
      EvidenceCompositionModality.witness,
    ]),
    EvidenceCompositionPattern.sequence([
      EvidenceCompositionModality.video,
      EvidenceCompositionModality.text,
      EvidenceCompositionModality.video,
    ]),
    EvidenceCompositionPattern.sequence([
      EvidenceCompositionModality.video,
      EvidenceCompositionModality.voice,
      EvidenceCompositionModality.video,
    ]),
    EvidenceCompositionPattern.sequence([
      EvidenceCompositionModality.voice,
      EvidenceCompositionModality.photo,
      EvidenceCompositionModality.voice,
    ]),
    EvidenceCompositionPattern.sequence([
      EvidenceCompositionModality.text,
      EvidenceCompositionModality.photo,
      EvidenceCompositionModality.text,
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      key: guideKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: AppColors.navy,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
            height: 1.3,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumn = constraints.maxWidth >= 300;
            if (!twoColumn) {
              return Column(
                children: [
                  for (var i = 0; i < compositions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 7),
                    _CompositionCell(pattern: compositions[i]),
                  ],
                ],
              );
            }
            return Column(
              children: [
                for (var i = 0; i < compositions.length; i += 2) ...[
                  if (i > 0) const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _CompositionCell(pattern: compositions[i]),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: i + 1 < compositions.length
                            ? _CompositionCell(pattern: compositions[i + 1])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

enum EvidenceCompositionModality {
  photo,
  video,
  voice,
  text,
  witness;

  String get label => switch (this) {
        EvidenceCompositionModality.photo => 'Photo',
        EvidenceCompositionModality.video => 'Video',
        EvidenceCompositionModality.voice => 'Voice',
        EvidenceCompositionModality.text => 'Text',
        EvidenceCompositionModality.witness => 'Witness',
      };

  IconData get icon => switch (this) {
        EvidenceCompositionModality.photo => Icons.photo_camera_outlined,
        EvidenceCompositionModality.video => Icons.videocam_outlined,
        EvidenceCompositionModality.voice => Icons.mic_outlined,
        EvidenceCompositionModality.text => Icons.edit_note_outlined,
        EvidenceCompositionModality.witness => Icons.person_outline,
      };

  /// Shared capture-mode family. Witness has no capture asset.
  WorkspaceCaptureMode? get captureMode => switch (this) {
        EvidenceCompositionModality.photo => WorkspaceCaptureMode.photo,
        EvidenceCompositionModality.video => WorkspaceCaptureMode.video,
        EvidenceCompositionModality.voice => WorkspaceCaptureMode.voice,
        EvidenceCompositionModality.text => WorkspaceCaptureMode.note,
        EvidenceCompositionModality.witness => null,
      };
}

class EvidenceCompositionPattern {
  const EvidenceCompositionPattern._({
    required this.modalities,
    required this.sequential,
  });

  const EvidenceCompositionPattern.together(
    List<EvidenceCompositionModality> modalities,
  ) : this._(modalities: modalities, sequential: false);

  const EvidenceCompositionPattern.sequence(
    List<EvidenceCompositionModality> modalities,
  ) : this._(modalities: modalities, sequential: true);

  final List<EvidenceCompositionModality> modalities;
  final bool sequential;

  String get joiner => sequential
      ? EvidenceCompositionGuide.sequenceJoiner
      : EvidenceCompositionGuide.plusJoiner;

  String get label =>
      modalities.map((modality) => modality.label).join(joiner);
}

class _CompositionCell extends StatelessWidget {
  const _CompositionCell({required this.pattern});

  final EvidenceCompositionPattern pattern;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: pattern.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                for (var i = 0; i < pattern.modalities.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        pattern.sequential ? '→' : '+',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    ),
                  _ModalityMark(modality: pattern.modalities[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            pattern.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalityMark extends StatelessWidget {
  const _ModalityMark({required this.modality});

  final EvidenceCompositionModality modality;

  @override
  Widget build(BuildContext context) {
    final mode = modality.captureMode;
    if (mode != null) {
      return CaptureModeIcon(
        mode: mode,
        size: CaptureModeIconMetrics.compositionGuide,
      );
    }
    return Icon(
      modality.icon,
      size: CaptureModeIconMetrics.compositionGuide,
      color: AppColors.navy.withValues(alpha: 0.72),
    );
  }
}
