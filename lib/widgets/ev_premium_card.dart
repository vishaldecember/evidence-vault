import 'package:flutter/material.dart';
import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';

class EVPremiumCard extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final EdgeInsetsGeometry? padding;

  const EVPremiumCard({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 150),
    this.padding,
  });

  @override
  State<EVPremiumCard> createState() => _EVPremiumCardState();
}

class _EVPremiumCardState extends State<EVPremiumCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          padding: widget.padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
