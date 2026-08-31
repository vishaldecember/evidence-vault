import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_motion.dart';
import '../theme/app_text_styles.dart';

class EVButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  /// Shown instead of a bare spinner while [isLoading] is true.
  final String? loadingText;

  /// Retained for callers; fill always uses [AppDecorations.ctaGradient].
  // ignore: unused_field
  final Color? color;

  const EVButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.loadingText,
    this.color,
  });

  @override
  State<EVButton> createState() => _EVButtonState();
}

class _EVButtonState extends State<EVButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  // [color] is accepted for API compatibility; CTA fill is always the
  // canonical violet gradient so Material / fromSeed cannot resolve blue.

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: _isEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedScale(
        scale: _isPressed ? AppMotion.pressScale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        child: AnimatedOpacity(
          duration: AppMotion.fast,
          opacity: _isEnabled ? 1 : 0.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppDecorations.ctaGradient,
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                boxShadow: _isPressed ? const [] : AppDecorations.ctaShadows,
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: _isEnabled ? widget.onPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: AppColors.onPrimary,
                    disabledForegroundColor: AppColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                    ),
                  ),
              child: widget.isLoading
                  ? (widget.loadingText == null
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(
                          widget.loadingText!,
                          style: AppTextStyles.button,
                          textAlign: TextAlign.center,
                        ))
                  : Text(widget.text, style: AppTextStyles.button),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
