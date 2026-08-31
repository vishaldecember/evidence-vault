import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/reflection_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/investigation_selection_visuals.dart';

/// Narrative segment for the Reconstruction Canvas with synchronized selection.
class InvestigationNarrativeSegment extends StatelessWidget {
  const InvestigationNarrativeSegment({
    super.key,
    required this.notes,
    required this.highlightedSectionIds,
    required this.onSectionSelected,
  });

  final List<ReflectionModel> notes;
  final Set<String> highlightedSectionIds;
  final ValueChanged<ReflectionModel> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Reconstruction Narrative',
                style: AppTextStyles.screenTitle.copyWith(
                  fontSize: 20,
                  color: AppColors.onCanvas,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your evidence-backed reconstruction will appear here.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.onCanvasSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      itemCount: notes.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final note = notes[index];
        final isHighlighted = highlightedSectionIds.contains(note.id);
        return _NarrativeSectionCard(
          note: note,
          isHighlighted: isHighlighted,
          onTap: () => onSectionSelected(note),
        );
      },
    );
  }
}

class _NarrativeSectionCard extends StatelessWidget {
  const _NarrativeSectionCard({
    required this.note,
    required this.isHighlighted,
    required this.onTap,
  });

  final ReflectionModel note;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: InvestigationSelectionVisuals.selectionDuration,
      curve: InvestigationSelectionVisuals.selectionCurve,
      decoration: BoxDecoration(
        color: isHighlighted
            ? InvestigationSelectionVisuals.selectionColor
                .withValues(alpha: 0.06)
            : AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border(
          left: BorderSide(
            color: isHighlighted
                ? InvestigationSelectionVisuals.selectionColor
                : AppColors.border,
            width: InvestigationSelectionVisuals.narrativeBorderWidth,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.hasTitle ? note.title!.trim() : 'Narrative Section',
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  note.body.trim(),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
