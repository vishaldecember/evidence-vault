import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Compact premium voice preview (play / waveform / accept).
///
/// Preview controls (play) are separate from recording pause/resume.
class VoicePreviewPanel extends StatelessWidget {
  const VoicePreviewPanel({
    super.key,
    required this.levels,
    required this.durationLabel,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onAccept,
    required this.onDiscard,
    this.positionLabel,
    this.progress = 0,
  });

  final List<double> levels;
  final String durationLabel;
  final String? positionLabel;
  final bool isPlaying;
  final double progress;
  final VoidCallback onPlayPause;
  final VoidCallback onAccept;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final elapsed = positionLabel ?? '0:00';
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: isPlaying ? 'Pause preview' : 'Play preview',
                        onPressed: onPlayPause,
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: AppColors.primary,
                          size: 40,
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: CustomPaint(
                            painter: _WaveformProgressPainter(
                              levels: levels,
                              progress: progress.clamp(0.0, 1.0),
                              played: AppColors.primary,
                              rest: AppColors.navy.withValues(alpha: 0.22),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            elapsed,
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            durationLabel,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Discard',
                        onPressed: onDiscard,
                        icon: Icon(
                          Icons.delete_outline,
                          color: AppColors.textMuted,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: onAccept,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                        ),
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text('Accept'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveformProgressPainter extends CustomPainter {
  const _WaveformProgressPainter({
    required this.levels,
    required this.progress,
    required this.played,
    required this.rest,
  });

  final List<double> levels;
  final double progress;
  final Color played;
  final Color rest;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }
    final barCount = levels.length;
    final gap = 2.0;
    final barWidth = math.max(
      2.0,
      (size.width - gap * (barCount - 1)) / barCount,
    );
    final playedUntil = progress * size.width;
    for (var i = 0; i < barCount; i++) {
      final x = i * (barWidth + gap);
      final h = math.max(4.0, levels[i].clamp(0.08, 1.0) * size.height);
      final y = (size.height - h) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = x + barWidth * 0.5 <= playedUntil ? played : rest,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.played != played ||
        oldDelegate.rest != rest ||
        oldDelegate.levels != levels;
  }
}
