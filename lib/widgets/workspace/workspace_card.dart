import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import '../common/layered_card.dart';

/// Shared static card shell for Evidence Workspace information sections.
///
/// Calm elevation without entrance animation — keeps the workspace cohesive.
class WorkspaceCard extends StatelessWidget {
  const WorkspaceCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor = AppColors.background,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color backgroundColor;

  static BoxDecoration decoration({Color? backgroundColor}) {
    return AppDecorations.card(backgroundColor: backgroundColor ?? AppColors.background);
  }

  @override
  Widget build(BuildContext context) {
    if (backgroundColor != AppColors.background) {
      return Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(AppSpacing.md),
        decoration: decoration(backgroundColor: backgroundColor),
        child: child,
      );
    }
    return LayeredCard(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      child: child,
    );
  }
}

/// Orientation card shell — subtle tint for journey and guidance sections.
class WorkspaceOrientationCard extends StatelessWidget {
  const WorkspaceOrientationCard({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return WorkspaceCard(
      padding: padding,
      backgroundColor: AppColors.surfaceMuted,
      child: child,
    );
  }
}

/// Consistent section heading rhythm across workspace information layers.
class WorkspaceSectionHeader extends StatelessWidget {
  const WorkspaceSectionHeader({
    super.key,
    required this.title,
    this.caption,
    this.titleStyle = AppTextStyles.heading,
  });

  final String title;
  final String? caption;
  final TextStyle titleStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            caption!,
            style: AppTextStyles.caption.copyWith(height: 1.4),
          ),
        ],
      ],
    );
  }
}
