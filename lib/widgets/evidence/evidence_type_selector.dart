import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_type.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class EvidenceTypeSelector extends StatelessWidget {
  const EvidenceTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final EvidenceType selected;
  final ValueChanged<EvidenceType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Evidence type', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        ...EvidenceType.values.map(
          (type) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _EvidenceTypeCard(
              type: type,
              isSelected: selected == type,
              onTap: () => onChanged(type),
            ),
          ),
        ),
      ],
    );
  }
}

class _EvidenceTypeCard extends StatelessWidget {
  const _EvidenceTypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final EvidenceType type;
  final bool isSelected;
  final VoidCallback onTap;

  IconData get _icon => switch (type) {
        EvidenceType.photo => Icons.photo_camera_outlined,
        EvidenceType.video => Icons.videocam_outlined,
        EvidenceType.audio => Icons.mic_outlined,
        EvidenceType.document => Icons.description_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.surfaceMuted : AppColors.card,
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
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  type.label,
                  style: AppTextStyles.label.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.navy,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
