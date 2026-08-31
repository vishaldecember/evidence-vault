import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/workspace_capture_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Persistent Photo / Video / Voice mode switcher for Capture Cockpit.
///
/// This is a modality control — not the shutter. Switching must not leave
/// the cockpit or recreate the incident / CaptureSession.
class CaptureModalityBar extends StatelessWidget {
  const CaptureModalityBar({
    super.key,
    required this.active,
    required this.onChanged,
    this.enabled = true,
  });

  final WorkspaceCaptureMode active;
  final ValueChanged<WorkspaceCaptureMode> onChanged;
  final bool enabled;

  static const modalities = <WorkspaceCaptureMode>[
    WorkspaceCaptureMode.photo,
    WorkspaceCaptureMode.video,
    WorkspaceCaptureMode.voice,
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Capture modality switcher',
      child: Container(
        key: const Key('capture_modality_bar'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            bottom: BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < modalities.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _ModalityChip(
                  mode: modalities[i],
                  selected: active == modalities[i],
                  enabled: enabled,
                  onTap: () => onChanged(modalities[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModalityChip extends StatelessWidget {
  const _ModalityChip({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final WorkspaceCaptureMode mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.onPrimary : AppColors.navy;
    return Material(
      color: selected ? AppColors.navy : AppColors.card,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: InkWell(
        key: Key('capture_modality_${mode.name}'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
            border: Border.all(
              color: selected ? AppColors.navy : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(mode.icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Text(
                mode.label,
                style: AppTextStyles.caption.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
