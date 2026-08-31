import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/reflection_model.dart';
import '../../theme/app_button_styles.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../workspace/workspace_card.dart';
import 'reflection_card.dart';

/// Personal understanding preserved after evidence — the final journey stage.
///
/// Never auto-generated or inferred. Extension points reserved for AI
/// summaries, reminders, multiple reflections, export, and visibility.
class ReflectionSection extends StatelessWidget {
  const ReflectionSection({
    super.key,
    required this.reflections,
    required this.onAddReflection,
    required this.onEditReflection,
  });

  final List<ReflectionModel> reflections;
  final VoidCallback onAddReflection;
  final ValueChanged<ReflectionModel> onEditReflection;

  @override
  Widget build(BuildContext context) {
    return WorkspaceOrientationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkspaceSectionHeader(
            title: 'Reconstruction Notes',
            caption:
                'Capture observations, hypotheses and investigative notes.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (reflections.isEmpty)
            _EmptyState(onAddReflection: onAddReflection)
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reflections.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final reflection = reflections[index];
                return ReflectionCard(
                  reflection: reflection,
                  onTap: () => onEditReflection(reflection),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onAddReflection,
              style: AppButtonStyles.inlineOutlined,
              child: Text(
                'Add Reflection',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddReflection});

  final VoidCallback onAddReflection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sometimes understanding comes with time.',
          style: AppTextStyles.bodySmall.copyWith(height: 1.5),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "When you're ready, record what this experience taught you.",
          style: AppTextStyles.caption.copyWith(height: 1.5),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: AppSpacing.buttonHeight,
          child: ElevatedButton(
            onPressed: onAddReflection,
            style: AppButtonStyles.primary,
            child: Text('Add Reflection', style: AppTextStyles.button),
          ),
        ),
      ],
    );
  }
}
