import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/workspace_capture_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/capture_mode_icon.dart';

/// Sticky capture bar for Incident Workspace — Photo / Video / Voice / Note / File.
///
/// One horizontal row, no scrolling. Photo / Video / Voice open Capture Cockpit.
/// Note / File stay Workspace-only. Capture Cockpit uses
/// [CaptureCockpitModalityBar] instead.
class CaptureStickyBar extends StatelessWidget {
  const CaptureStickyBar({
    super.key,
    required this.onModalitySelected,
    required this.onNoteTap,
    required this.onFileTap,
    this.activeModality,
    this.highlightSelected = false,
    this.enabled = true,
  });

  /// Optional highlighted Photo / Video / Voice modality.
  final WorkspaceCaptureMode? activeModality;
  final ValueChanged<WorkspaceCaptureMode> onModalitySelected;
  final VoidCallback onNoteTap;
  final VoidCallback onFileTap;
  final bool highlightSelected;
  final bool enabled;

  static const modalities = <WorkspaceCaptureMode>[
    WorkspaceCaptureMode.photo,
    WorkspaceCaptureMode.video,
    WorkspaceCaptureMode.voice,
  ];

  static const actions = <WorkspaceCaptureMode>[
    WorkspaceCaptureMode.photo,
    WorkspaceCaptureMode.video,
    WorkspaceCaptureMode.voice,
    WorkspaceCaptureMode.note,
    WorkspaceCaptureMode.file,
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Capture bar',
      child: Container(
        key: const Key('capture_sticky_bar'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _StickyAction(
                  mode: actions[i],
                  selected:
                      highlightSelected &&
                      activeModality != null &&
                      modalities.contains(actions[i]) &&
                      activeModality == actions[i],
                  enabled: enabled,
                  onTap: () {
                    final mode = actions[i];
                    if (mode == WorkspaceCaptureMode.note) {
                      onNoteTap();
                      return;
                    }
                    if (mode == WorkspaceCaptureMode.file) {
                      onFileTap();
                      return;
                    }
                    onModalitySelected(mode);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StickyAction extends StatelessWidget {
  const _StickyAction({
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('capture_action_${mode.name}'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PinnedCaptureModeIcon(
                mode: mode,
                size: CaptureModeIconMetrics.stickyBar,
                layoutSize: CaptureModeIconMetrics.stickyBarLayout,
              ),
              const SizedBox(height: 2),
              Text(
                mode.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
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
