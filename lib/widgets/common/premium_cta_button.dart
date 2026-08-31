import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';

/// Major CTA with a solid premium violet fill.
///
/// Presentation only — [onPressed] is unchanged.
class PremiumCtaButton extends StatefulWidget {
  const PremiumCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  State<PremiumCtaButton> createState() => _PremiumCtaButtonState();
}

class _PremiumCtaButtonState extends State<PremiumCtaButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.buttonRadius);
    return AnimatedScale(
      scale: _pressed && _enabled ? AppMotion.pressScale : 1,
      duration: AppMotion.fast,
      curve: AppMotion.enter,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: _enabled ? 1 : 0.5,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: _pressed ? const [] : AppDecorations.ctaShadows,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppDecorations.ctaGradient,
              borderRadius: radius,
            ),
            child: Material(
              type: MaterialType.transparency,
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                onHighlightChanged: (value) {
                  if (_enabled) {
                    setState(() => _pressed = value);
                  }
                },
                borderRadius: radius,
                splashColor: AppColors.onPrimary.withValues(alpha: 0.12),
                highlightColor: AppColors.onPrimary.withValues(alpha: 0.06),
                child: SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: AppDecorations.ctaSheen,
                    ),
                    child: Center(
                      child: Text(
                        widget.label,
                        style: AppTextStyles.button,
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
