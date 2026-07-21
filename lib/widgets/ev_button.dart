import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class EVButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;

  const EVButton({
    super.key,
    required this.text,
    this.onPressed,
  });

  @override
  State<EVButton> createState() => _EVButtonState();
}

class _EVButtonState extends State<EVButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: _isEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: _isEnabled ? 1 : 0.5,
          child: SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton(
              onPressed: widget.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                disabledForegroundColor: AppColors.onPrimary,
                elevation: _isPressed ? 0 : 2,
                shadowColor: AppColors.primaryShadow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                ),
              ),
              child: Text(widget.text, style: AppTextStyles.button),
            ),
          ),
        ),
      ),
    );
  }
}
