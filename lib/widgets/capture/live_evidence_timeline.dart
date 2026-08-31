import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../constants/app_spacing.dart';
import '../../models/workspace_evidence_item.dart';
import '../../presentation/evidence_presentation_resolver.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/workspace_evidence_formatters.dart';

/// Live chronological timeline — oldest at top, newest at bottom.
///
/// Grows upward toward the sticky capture bar. Visual representation follows
/// semantic [WorkspaceEvidenceKind], never MIME sniffing for File attachments.
class LiveEvidenceTimeline extends StatelessWidget {
  const LiveEvidenceTimeline({
    super.key,
    required this.items,
    this.scrollController,
    this.padding,
    this.onEvidenceTap,
  });

  /// Chronological ascending (oldest → newest).
  final List<WorkspaceEvidenceItem> items;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;

  /// Opens Evidence Inspector for the tapped item; does not mutate evidence.
  final ValueChanged<WorkspaceEvidenceItem>? onEvidenceTap;

  static String formatClock(DateTime at) {
    return WorkspaceEvidenceFormatters.evidenceClock(at);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            'Captured evidence will appear here.',
            key: const Key('live_timeline_empty'),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('live_evidence_timeline'),
      controller: scrollController,
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.xs,
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
          ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final item = items[index];
        return _TimelineTile(
          key: Key('live_timeline_item_${item.id}'),
          item: item,
          indexLabel: 'Evidence ${index + 1}',
          onTap: onEvidenceTap == null ? null : () => onEvidenceTap!(item),
        );
      },
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    super.key,
    required this.item,
    required this.indexLabel,
    this.onTap,
  });

  final WorkspaceEvidenceItem item;
  final String indexLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VisualBadge(item: item),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  indexLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.kind.label,
                  key: Key('live_timeline_kind_${item.id}'),
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  LiveEvidenceTimeline.formatClock(item.lastPreservedAt),
                  key: Key('live_timeline_time_${item.id}'),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return tile;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        child: tile,
      ),
    );
  }

  String _subtitle(WorkspaceEvidenceItem item) {
    switch (item.kind) {
      case WorkspaceEvidenceKind.note:
        final snippet = (item.notePreview ?? item.title).trim();
        return snippet.isEmpty ? 'Text note' : snippet;
      case WorkspaceEvidenceKind.attachment:
        final name = (item.fileName ?? item.title).trim();
        if (name.isEmpty) {
          return 'Attachment';
        }
        final ext = p.extension(name).replaceFirst('.', '').toUpperCase();
        return ext.isEmpty ? name : '$name · $ext';
      case WorkspaceEvidenceKind.voice:
        return 'Voice recording';
      case WorkspaceEvidenceKind.image:
        return 'Photo';
      case WorkspaceEvidenceKind.video:
        return 'Video';
      case WorkspaceEvidenceKind.witness:
        return item.title;
    }
  }
}

class _VisualBadge extends StatelessWidget {
  const _VisualBadge({required this.item});

  final WorkspaceEvidenceItem item;

  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    final presentation = EvidencePresentationResolver.resolve(item);
    if (presentation.previewKind == EvidencePresentationKind.video) {
      return _VideoThumb(
        item: item,
        thumbnailPath: presentation.thumbnailPath,
      );
    }
    return switch (item.kind) {
      WorkspaceEvidenceKind.image => _PhotoThumb(
          item: item,
          imagePath: presentation.thumbnailPath ?? item.filePath,
        ),
      WorkspaceEvidenceKind.video => _VideoThumb(
          item: item,
          thumbnailPath: presentation.thumbnailPath,
        ),
      WorkspaceEvidenceKind.voice => const _VoiceWaveThumb(),
      WorkspaceEvidenceKind.note => _IconThumb(
          icon: Icons.edit_note_outlined,
          semanticKey: 'live_timeline_note_visual_${item.id}',
        ),
      WorkspaceEvidenceKind.attachment => _IconThumb(
          icon: Icons.attach_file_outlined,
          semanticKey: 'live_timeline_file_visual_${item.id}',
        ),
      WorkspaceEvidenceKind.witness => _IconThumb(
          icon: Icons.record_voice_over_outlined,
          semanticKey: 'live_timeline_witness_visual_${item.id}',
        ),
    };
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.item, this.imagePath});

  final WorkspaceEvidenceItem item;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: SizedBox(
        width: _VisualBadge._size,
        height: _VisualBadge._size,
        child: path != null && File(path).existsSync()
            ? Image.file(
                File(path),
                key: Key('live_timeline_photo_thumb_${item.id}'),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _IconThumb(
                  icon: Icons.photo_camera_outlined,
                ),
              )
            : const _IconThumb(icon: Icons.photo_camera_outlined),
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.item, this.thumbnailPath});

  final WorkspaceEvidenceItem item;
  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    final thumb = thumbnailPath;
    final hasThumb = thumb != null && File(thumb).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: SizedBox(
        width: _VisualBadge._size,
        height: _VisualBadge._size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasThumb)
              Image.file(
                File(thumb),
                key: Key('live_timeline_video_thumb_${item.id}'),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: AppColors.surfaceMuted,
                  child: Icon(
                    Icons.videocam_outlined,
                    color: AppColors.navy.withValues(alpha: 0.7),
                  ),
                ),
              )
            else
              ColoredBox(
                color: AppColors.surfaceMuted,
                child: Icon(
                  Icons.videocam_outlined,
                  color: AppColors.navy.withValues(alpha: 0.7),
                ),
              ),
            const ColoredBox(color: Color(0x33000000)),
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                key: Key('live_timeline_video_play_icon'),
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceWaveThumb extends StatelessWidget {
  const _VoiceWaveThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('live_timeline_voice_wave'),
      width: _VisualBadge._size,
      height: _VisualBadge._size,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: CustomPaint(
        painter: _MiniWavePainter(color: AppColors.navy),
      ),
    );
  }
}

class _IconThumb extends StatelessWidget {
  const _IconThumb({
    required this.icon,
    this.semanticKey,
  });

  final IconData icon;
  final String? semanticKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: semanticKey == null ? null : Key(semanticKey!),
      width: _VisualBadge._size,
      height: _VisualBadge._size,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, color: AppColors.navy, size: 26),
    );
  }
}

class _MiniWavePainter extends CustomPainter {
  _MiniWavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const bars = 7;
    final gap = size.width / (bars * 1.6);
    final barWidth = gap * 0.7;
    for (var i = 0; i < bars; i++) {
      final t = i / (bars - 1);
      final heightFactor = 0.35 + 0.55 * math.sin(t * math.pi);
      final h = size.height * heightFactor;
      final x = gap + i * (barWidth + gap * 0.6);
      final top = (size.height - h) / 2;
      canvas.drawLine(Offset(x, top), Offset(x, top + h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniWavePainter oldDelegate) =>
      oldDelegate.color != color;
}
