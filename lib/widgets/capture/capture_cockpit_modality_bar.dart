import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/workspace_capture_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Translucent Cockpit modality bar — Photo / Video / Voice only.
///
/// Floats over the straight live capture surface. Active modality uses the
/// Evidence Vault signature orange — not opaque navy/blue blocks.
class CaptureCockpitModalityBar extends StatelessWidget {
  const CaptureCockpitModalityBar({
    super.key,
    required this.activeModality,
    required this.onModalitySelected,
    this.enabled = true,
  });

  final WorkspaceCaptureMode activeModality;
  final ValueChanged<WorkspaceCaptureMode> onModalitySelected;
  final bool enabled;

  static const modalities = <WorkspaceCaptureMode>[
    WorkspaceCaptureMode.photo,
    WorkspaceCaptureMode.video,
    WorkspaceCaptureMode.voice,
  ];

  /// Effective dark scrim over the live surface (20–35% target).
  static const double overlayOpacity = 0.28;

  /// Chip row height used to inset shutter controls above this overlay bar.
  static const double contentHeight = 56;

  static double preferredHeight(BuildContext context) {
    return contentHeight +
        AppSpacing.sm * 2 +
        MediaQuery.paddingOf(context).bottom;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Capture modalities',
      child: Container(
        key: const Key('capture_cockpit_modality_bar'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: overlayOpacity),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < modalities.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ModalityChip(
                  mode: modalities[i],
                  selected: activeModality == modalities[i],
                  enabled: enabled,
                  onTap: () => onModalitySelected(modalities[i]),
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
    final foreground = selected
        ? AppColors.navy
        : Colors.white.withValues(alpha: 0.92);
    final fill = selected
        ? AppColors.warning.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.12);

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('capture_modality_${mode.name}'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: CaptureCockpitModalityBar.contentHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(mode.icon, size: 22, color: foreground),
              const SizedBox(height: 2),
              Text(
                mode.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
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
