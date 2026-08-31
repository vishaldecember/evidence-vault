import 'package:flutter/material.dart';
import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class AuthHeader extends StatefulWidget {
  final String title;
  final String description;
  final bool showBrandName;
  final bool compact;
  /// Further reduced logo + spacing for create-account onboarding.
  final bool onboarding;

  const AuthHeader({
    super.key,
    required this.title,
    required this.description,
    this.showBrandName = true,
    this.compact = false,
    this.onboarding = false,
  });

  @override
  State<AuthHeader> createState() => _AuthHeaderState();
}

class _AuthHeaderState extends State<AuthHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = widget.onboarding
        ? AppSpacing.logoSizeOnboarding
        : widget.compact
            ? AppSpacing.logoSizeCompact
            : AppSpacing.logoSizeLarge;
    final chromePadding = widget.onboarding
        ? AppSpacing.xs
        : widget.compact
            ? AppSpacing.sm
            : AppSpacing.xl;
    final titleStyle = widget.onboarding
        ? AppTextStyles.pageTitle.copyWith(fontSize: 26)
        : AppTextStyles.pageTitle;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            Container(
              width: logoSize + chromePadding,
              height: logoSize + chromePadding,
              padding: EdgeInsets.all(
                widget.onboarding || widget.compact
                    ? AppSpacing.xxs + 2
                    : AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppSpacing.xxl),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: widget.onboarding ? 16 : 24,
                    offset: Offset(0, widget.onboarding ? 4 : 8),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/branding/logo_mark.png',
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            if (widget.showBrandName) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Evidence Vault',
                style: AppTextStyles.appTitle.copyWith(fontSize: 22),
              ),
            ],
            SizedBox(
              height: widget.onboarding
                  ? AppSpacing.sm
                  : widget.compact
                      ? AppSpacing.md
                      : AppSpacing.xl,
            ),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: titleStyle,
            ),
            SizedBox(
              height: widget.onboarding || widget.compact
                  ? AppSpacing.xs
                  : AppSpacing.sm,
            ),
            Text(
              widget.description,
              textAlign: TextAlign.center,
              maxLines: widget.onboarding || widget.compact ? 2 : null,
              overflow: widget.onboarding || widget.compact
                  ? TextOverflow.ellipsis
                  : null,
              style: AppTextStyles.bodySmall.copyWith(
                height: widget.onboarding ? 1.35 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
