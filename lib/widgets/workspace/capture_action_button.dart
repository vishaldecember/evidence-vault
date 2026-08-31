import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/workspace_capture_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../common/capture_mode_icon.dart';

class CaptureActionButton extends StatefulWidget {
  const CaptureActionButton({
    super.key,
    required this.mode,
    required this.isActive,
    required this.onTap,
  });

  final WorkspaceCaptureMode mode;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<CaptureActionButton> createState() => _CaptureActionButtonState();
}

class _CaptureActionButtonState extends State<CaptureActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isActive
        ? AppColors.surfaceMuted
        : AppColors.background;

    return Expanded(
      child: Semantics(
        button: true,
        label: widget.mode.semanticLabel,
        selected: widget.isActive,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isPressed ? AppMotion.pressScale : 1,
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            child: AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.enter,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs,
                horizontal: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                border: Border.all(
                  color: widget.isActive ? AppColors.primary : AppColors.border,
                  width: widget.isActive ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isActive
                        ? AppColors.primaryShadow
                        : AppColors.shadow,
                    blurRadius: widget.isActive ? 12 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CaptureModeIcon(
                      mode: widget.mode,
                      size: CaptureModeIconMetrics.organizeToolbar,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.mode.label,
                      style: AppTextStyles.label.copyWith(fontSize: 10),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
