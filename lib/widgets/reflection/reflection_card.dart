import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/reflection_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/workspace_evidence_formatters.dart';

/// Displays one personal reflection — softer than evidence cards.
///
/// Reflections are editable by the author. Extension points reserved for
/// AI summaries, reminders, export, and visibility controls.
class ReflectionCard extends StatelessWidget {
  const ReflectionCard({
    super.key,
    required this.reflection,
    this.onTap,
  });

  final ReflectionModel reflection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 18,
                    color: AppColors.primary.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Reflection Added',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
              if (reflection.hasTitle) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  reflection.title!,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                reflection.body,
                style: AppTextStyles.bodySmall.copyWith(
                  height: 1.6,
                  color: AppColors.navy.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                WorkspaceEvidenceFormatters.preservedTimestamp(
                  reflection.createdAt,
                ),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
