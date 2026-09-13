import 'dart:io';

import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/workspace_evidence_item.dart';
import '../../presentation/evidence_presentation_resolver.dart';
import '../../security/https_preview_url.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/workspace_evidence_formatters.dart';

/// A calm, tappable evidence preview for the Incident Journey evidence strip.
///
/// Overlay slots are reserved for future metadata (verification, context,
/// relationships, AI insights, integrity) without redesigning the layout.
class LivingEvidencePreview extends StatelessWidget {
  const LivingEvidencePreview({
    super.key,
    required this.item,
    this.onTap,
    this.uniformThumbnailSize = false,
    this.suppressBorder = false,
    this.paperSurfaceColor,
    this.identifyingTextColor,
    this.verificationOverlay,
    this.contextOverlay,
    this.relationshipOverlay,
    this.aiInsightOverlay,
    this.integrityOverlay,
  });

  static const double mediaSize = 72;
  static const double noteWidth = 88;
  static const double noteHeight = 56;
  static const double voiceHeight = 48;

  final WorkspaceEvidenceItem item;
  final VoidCallback? onTap;
  final bool uniformThumbnailSize;
  final bool suppressBorder;

  /// Paper fill for note / attachment previews. Null keeps the default tint.
  final Color? paperSurfaceColor;

  /// Note / file identifying copy and its clock. Null keeps the default ink.
  final Color? identifyingTextColor;

  /// Reserved: verification status affordance.
  final Widget? verificationOverlay;

  /// Reserved: contextual enrichment indicator.
  final Widget? contextOverlay;

  /// Reserved: linked evidence / relationship indicator.
  final Widget? relationshipOverlay;

  /// Reserved: AI insight indicator.
  final Widget? aiInsightOverlay;

  /// Reserved: integrity status indicator.
  final Widget? integrityOverlay;

  Size get _previewSize {
    if (uniformThumbnailSize) {
      return const Size(mediaSize, mediaSize);
    }

    return switch (item.kind) {
      WorkspaceEvidenceKind.note => const Size(noteWidth, noteHeight),
      WorkspaceEvidenceKind.voice => const Size(mediaSize, voiceHeight),
      _ => const Size(mediaSize, mediaSize),
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = _previewSize;

    return Semantics(
      label: item.kind.label,
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          splashColor: AppColors.primary.withValues(alpha: 0.06),
          highlightColor: AppColors.primary.withValues(alpha: 0.03),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        border: suppressBorder
                            ? null
                            : Border.all(
                                color: AppColors.border.withValues(alpha: 0.55),
                              ),
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: _PreviewContent(
                        item: item,
                        paperSurfaceColor: paperSurfaceColor,
                        identifyingTextColor: identifyingTextColor,
                      ),
                    ),
                  ),
                ),
                if (verificationOverlay != null)
                  Positioned(left: 4, bottom: 4, child: verificationOverlay!),
                if (contextOverlay != null)
                  Positioned(left: 4, top: 4, child: contextOverlay!),
                if (relationshipOverlay != null)
                  Positioned(right: 4, bottom: 4, child: relationshipOverlay!),
                if (aiInsightOverlay != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: aiInsightOverlay!,
                  ),
                if (integrityOverlay != null)
                  Positioned(right: 4, top: 4, child: integrityOverlay!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({
    required this.item,
    this.paperSurfaceColor,
    this.identifyingTextColor,
  });

  final WorkspaceEvidenceItem item;
  final Color? paperSurfaceColor;
  final Color? identifyingTextColor;

  @override
  Widget build(BuildContext context) {
    if (item.kind == WorkspaceEvidenceKind.witness) {
      return _WitnessPreview(
        title: item.title,
        identifyingTextColor: identifyingTextColor,
      );
    }

    final presentation = EvidencePresentationResolver.resolve(item);
    final previewPath = presentation.thumbnailPath;

    return switch (presentation.previewKind) {
      EvidencePresentationKind.photo => _PhotoPreview(imagePath: previewPath),
      EvidencePresentationKind.video => _VideoPreview(imagePath: previewPath),
      EvidencePresentationKind.voice => const _VoicePreview(),
      EvidencePresentationKind.note => _NotePreview(
        text: item.notePreview,
        capturedAt: item.lastPreservedAt,
        paperColor: paperSurfaceColor,
        identifyingTextColor: identifyingTextColor,
      ),
      EvidencePresentationKind.document => _DocumentPreview(
        fileName: item.fileName,
        mimeType: item.mimeType,
        fileSizeBytes: item.fileSizeBytes,
        capturedAt: item.lastPreservedAt,
        paperColor: paperSurfaceColor,
        identifyingTextColor: identifyingTextColor,
      ),
      EvidencePresentationKind.pdf => _DocumentPreview(
        fileName: item.fileName,
        mimeType: item.mimeType ?? 'application/pdf',
        fileSizeBytes: item.fileSizeBytes,
        capturedAt: item.lastPreservedAt,
        paperColor: paperSurfaceColor,
        identifyingTextColor: identifyingTextColor,
      ),
      EvidencePresentationKind.witness => _WitnessPreview(
        title: item.title,
        identifyingTextColor: identifyingTextColor,
      ),
    };
  }
}

class _MediaImagePreview extends StatelessWidget {
  const _MediaImagePreview({required this.imagePath});

  final String imagePath;

  static bool _isNetworkUrl(String path) => isHttpsPreviewUrl(path);

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (LivingEvidencePreview.mediaSize * dpr).round().clamp(
      72,
      256,
    );

    if (_isNetworkUrl(imagePath)) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheWidth,
        errorBuilder: (context, error, stackTrace) => const _PhotoFallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return const _PhotoFallback();
        },
      );
    }

    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stackTrace) => const _PhotoFallback(),
    );
  }
}

/// Placeholder until backend media paths are wired.
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    if (imagePath != null) {
      return _MediaImagePreview(imagePath: imagePath!);
    }

    return const _PhotoFallback();
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceMuted,
            AppColors.surfaceMuted.withValues(alpha: 0.65),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.primary.withValues(alpha: 0.55),
          size: 26,
        ),
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imagePath != null)
          _MediaImagePreview(imagePath: imagePath!)
        else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.navy.withValues(alpha: 0.55),
                  AppColors.navy.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        Center(
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.onPrimary.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: AppColors.onPrimary,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _VoicePreview extends StatelessWidget {
  const _VoicePreview();

  static const _barHeights = <double>[8, 14, 20, 12, 24, 16, 22, 11, 18, 9];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1F4A), AppColors.navy, Color(0xFF1A3A7A)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.onPrimary.withValues(alpha: 0.22),
                ),
              ),
              child: const Icon(
                Icons.mic_rounded,
                size: 13,
                color: AppColors.onPrimary,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final height in _barHeights)
                    Container(
                      width: 2.2,
                      height: height * 0.85,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1.5),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.onPrimary.withValues(alpha: 0.35),
                            AppColors.onPrimary.withValues(alpha: 0.92),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotePreview extends StatelessWidget {
  const _NotePreview({
    this.text,
    this.capturedAt,
    this.paperColor,
    this.identifyingTextColor,
  });

  final String? text;
  final DateTime? capturedAt;
  final Color? paperColor;
  final Color? identifyingTextColor;

  @override
  Widget build(BuildContext context) {
    final preview = (text ?? '').trim();
    final firstLine = preview.isEmpty
        ? 'Text note'
        : preview.split('\n').first.trim();
    final timeLabel = capturedAt == null
        ? null
        : WorkspaceEvidenceFormatters.evidenceClockTime(capturedAt!);

    return ColoredBox(
      color: paperColor ?? AppColors.surfaceMuted.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs + 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 14,
              color: AppColors.primary.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                firstLine,
                maxLines: timeLabel == null ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  height: 1.25,
                  color: identifyingTextColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (timeLabel != null)
              Text(
                timeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 8,
                  color: identifyingTextColor ?? AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({
    this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    this.capturedAt,
    this.paperColor,
    this.identifyingTextColor,
  });

  final String? fileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final DateTime? capturedAt;
  final Color? paperColor;
  final Color? identifyingTextColor;

  @override
  Widget build(BuildContext context) {
    // Capture-method FILE is authoritative — never render image bytes as a
    // photo thumbnail even when MIME is image/*.
    final name = (fileName ?? 'Attachment').trim();
    final typeLabel = _typeLabel(name, mimeType);
    final sizeLabel = _sizeLabel(fileSizeBytes);
    final timeLabel = capturedAt == null
        ? null
        : WorkspaceEvidenceFormatters.evidenceClockTime(capturedAt!);

    return ColoredBox(
      color: paperColor ?? AppColors.surfaceMuted.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.attach_file_rounded,
              color: AppColors.primary.withValues(alpha: 0.85),
              size: 16,
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  height: 1.2,
                  color: identifyingTextColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              ['FILE', ?typeLabel, ?sizeLabel, ?timeLabel].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 8,
                color: identifyingTextColor ?? AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _typeLabel(String name, String? mimeType) {
    final mime = (mimeType ?? '').trim();
    if (mime.isNotEmpty) {
      final slash = mime.indexOf('/');
      if (slash > 0 && slash < mime.length - 1) {
        return mime.substring(slash + 1).toUpperCase();
      }
      return mime.toUpperCase();
    }
    final dot = name.lastIndexOf('.');
    if (dot > 0 && dot < name.length - 1) {
      return name.substring(dot + 1).toUpperCase();
    }
    return 'FILE';
  }

  static String? _sizeLabel(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return null;
    }
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _WitnessPreview extends StatelessWidget {
  const _WitnessPreview({required this.title, this.identifyingTextColor});

  final String title;
  final Color? identifyingTextColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceMuted.withValues(alpha: 0.9),
      child: Center(
        child: CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            _initialsFor(title),
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
              color: identifyingTextColor ?? AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  static String _initialsFor(String value) {
    final cleaned = value
        .replaceFirst(RegExp(r'^Context — '), '')
        .replaceFirst(RegExp(r'Witness Record$'), 'Witness')
        .trim();
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return 'W';
    }
    if (words.length == 1) {
      final word = words.first;
      return word.length >= 2
          ? word.substring(0, 2).toUpperCase()
          : word.toUpperCase();
    }
    return '${words.first[0]}${words[1][0]}'.toUpperCase();
  }
}
