import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class EvidenceCategorySelector extends StatelessWidget {
  const EvidenceCategorySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final EvidenceCategory selected;
  final ValueChanged<EvidenceCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<EvidenceCategory>(
          key: ValueKey(selected),
          initialValue: selected,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          icon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
          items: EvidenceCategory.values
              .map(
                (category) => DropdownMenuItem(
                  value: category,
                  child: Text(category.label, style: AppTextStyles.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    );
  }
}
