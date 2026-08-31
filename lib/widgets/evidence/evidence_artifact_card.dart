import 'dart:io';

import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_artifact_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/workspace_evidence_formatters.dart';
import '../verification/verification_badge.dart';

/// Standard presentation component for every preserved piece of evidence.
///
/// Callback-only interaction — navigation is supplied by the parent.
/// Extension slots for detail, relationships, sharing, custody, and AI are
/// reserved for future sprints.
class EvidenceArtifactCard extends StatelessWidget {
  const EvidenceArtifactCard({
    super.key,
    required this.artifact,
    this.onTap,
    this.detailBadge,
    this.relationshipIndicator,
    this.contextBadge,
    this.custodyIndicator,
    this.aiInsightIndicator,
  });

  final EvidenceArtifactModel artifact;
  final VoidCallback? onTap;

  /// Reserved: Evidence Detail entry affordance.
  final Widget? detailBadge;

  /// Reserved: relationship count or link indicator.
  final Widget? relationshipIndicator;

  /// Reserved: enriched context badge beyond the default context row.
  final Widget? contextBadge;

  /// Reserved: chain-of-custody indicator.
  final Widget? custodyIndicator;

  /// Reserved: AI observation indicator.
  final Widget? aiInsightIndicator;

  static const double _thumbnailSize = 88;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            boxShadow: AppDecorations.cardShadows,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ArtifactThumbnail(artifact: artifact),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            artifact.type.label,
                            style: AppTextStyles.emphasisLabel.copyWith(
                              fontSize: 16,
                            ),
                          ),
                          if (detailBadge != null ||
                              relationshipIndicator != null) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Row(
                              children: [
                                ?detailBadge,
                                if (detailBadge != null &&
                                    relationshipIndicator != null)
                                  const SizedBox(width: AppSpacing.xs),
                                ?relationshipIndicator,
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  WorkspaceEvidenceFormatters.preservedTimestamp(
                    artifact.preservedAt,
                  ),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.sm),
                _IntegrityRow(verified: artifact.integrityVerified),
                if (!artifact.verification.isNotVerified) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: VerificationBadge(
                      verification: artifact.verification,
                      compact: true,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                _ContextRow(enriched: artifact.contextEnriched),
                if (contextBadge != null ||
                    custodyIndicator != null ||
                    aiInsightIndicator != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ?contextBadge,
                      ?custodyIndicator,
                      ?aiInsightIndicator,
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntegrityRow extends StatelessWidget {
  const _IntegrityRow({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Evidence Integrity',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: verified
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Integrity Verified',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppColors.success,
                      ),
                    ],
                  )
                : Text(
                    'Pending verification',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
          ),
        ),
      ],
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.enriched});

  final bool enriched;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Context',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            enriched ? 'Context Enriched' : 'No additional context yet',
            style: AppTextStyles.caption.copyWith(
              color: enriched ? AppColors.primary : AppColors.textMuted,
              fontWeight: enriched ? FontWeight.w600 : FontWeight.w500,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ArtifactThumbnail extends StatelessWidget {
  const _ArtifactThumbnail({required this.artifact});

  final EvidenceArtifactModel artifact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: SizedBox(
        key: Key('evidence_map_thumb_${artifact.id}'),
        width: EvidenceArtifactCard._thumbnailSize,
        height: EvidenceArtifactCard._thumbnailSize,
        child: switch (artifact.type) {
          EvidenceArtifactType.photo => _PhotoThumbnail(
              imagePath: artifact.previewImagePath,
            ),
          EvidenceArtifactType.video => _VideoThumbnail(
              imagePath: artifact.previewImagePath,
            ),
          EvidenceArtifactType.voiceRecording => const _VoiceThumbnail(),
          EvidenceArtifactType.note =>
            _NoteThumbnail(text: artifact.notePreview),
          EvidenceArtifactType.document => _DocumentThumbnail(
              fileName: artifact.fileName,
              imagePath: artifact.documentImagePreviewPath,
            ),
        },
      ),
    );
  }
}

/// Decodes only a map-sized target — never full-resolution bitmaps.
class _CachedMediaImage extends StatelessWidget {
  const _CachedMediaImage({
    required this.imagePath,
    required this.fallback,
  });

  final String imagePath;
  final Widget fallback;

  static bool _isNetworkUrl(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth =
        (EvidenceArtifactCard._thumbnailSize * dpr).round().clamp(88, 256);

    if (_isNetworkUrl(imagePath)) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheWidth,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return fallback;
        },
      );
    }

    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    const fallback = _PhotoIconFallback();
    if (imagePath == null || imagePath!.isEmpty) {
      return fallback;
    }
    return _CachedMediaImage(imagePath: imagePath!, fallback: fallback);
  }
}

class _PhotoIconFallback extends StatelessWidget {
  const _PhotoIconFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceMuted,
      child: const Icon(
        Icons.photo_outlined,
        color: AppColors.primary,
        size: 36,
      ),
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imagePath != null && imagePath!.isNotEmpty)
          _CachedMediaImage(
            imagePath: imagePath!,
            fallback: const _VideoIconFallback(),
          )
        else
          const _VideoIconFallback(),
        Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: AppColors.onPrimary,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoIconFallback extends StatelessWidget {
  const _VideoIconFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceMuted,
      child: const Center(
        child: Icon(
          Icons.videocam_outlined,
          color: AppColors.primary,
          size: 32,
        ),
      ),
    );
  }
}

class _VoiceThumbnail extends StatelessWidget {
  const _VoiceThumbnail();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final height in [12.0, 22.0, 16.0, 28.0, 18.0, 24.0, 14.0])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 3,
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteThumbnail extends StatelessWidget {
  const _NoteThumbnail({this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final preview = text ?? 'No preview available.';
    final lines = preview.split('\n');
    final lineOne = lines.isNotEmpty ? lines.first : preview;

    return Container(
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.all(AppSpacing.xs),
      alignment: Alignment.topLeft,
      child: Text(
        lineOne,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(fontSize: 10, height: 1.3),
      ),
    );
  }
}

class _DocumentThumbnail extends StatelessWidget {
  const _DocumentThumbnail({this.fileName, this.imagePath});

  final String? fileName;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && imagePath!.isNotEmpty) {
      return _CachedMediaImage(
        imagePath: imagePath!,
        fallback: _DocumentIconFallback(fileName: fileName),
      );
    }
    return _DocumentIconFallback(fileName: fileName);
  }
}

class _DocumentIconFallback extends StatelessWidget {
  const _DocumentIconFallback({this.fileName});

  final String? fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            color: AppColors.primary,
            size: 30,
          ),
          if (fileName != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              fileName!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}
