import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/workspace_capture_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';

/// Capture action grid for continuous session — Photo / Video / Voice / Note / File.
class CaptureActionGrid extends StatelessWidget {
  const CaptureActionGrid({
    super.key,
    required this.enabled,
    required this.onCapture,
  });

  final bool enabled;
  final ValueChanged<WorkspaceCaptureMode> onCapture;

  static const _actions = <(WorkspaceCaptureMode, String, IconData)>[
    (WorkspaceCaptureMode.photo, 'Photo', Icons.photo_camera_outlined),
    (WorkspaceCaptureMode.video, 'Video', Icons.videocam_outlined),
    (WorkspaceCaptureMode.voice, 'Voice', Icons.mic_outlined),
    (WorkspaceCaptureMode.note, 'Note', Icons.edit_note_outlined),
    (WorkspaceCaptureMode.file, 'File', Icons.attach_file_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Capture', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final action in _actions)
              SizedBox(
                width: (MediaQuery.sizeOf(context).width -
                        AppSpacing.screenHorizontal * 2 -
                        AppSpacing.xs * 2) /
                    3,
                child: _ActionTile(
                  key: Key('capture_action_${action.$1.name}'),
                  label: action.$2,
                  icon: action.$3,
                  enabled: enabled,
                  onTap: () => onCapture(action.$1),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        child: Ink(
          height: 88,
          decoration: AppDecorations.card(
            backgroundColor: enabled ? AppColors.card : AppColors.surfaceMuted,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: enabled ? AppColors.navy : AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
