import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Compact WhatsApp-style voice preview panel (not a full-screen overlay).
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
  });

  final List<double> levels;
  final String durationLabel;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onAccept;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
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
              color: const Color(0xFF1A1D24).withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
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
                          isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              for (final level in levels)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 1),
                                    child: FractionallySizedBox(
                                      heightFactor: math.max(0.15, level),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        durationLabel,
                        style: AppTextStyles.label.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
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
                        icon: const Icon(Icons.delete_outline, color: Colors.white),
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
