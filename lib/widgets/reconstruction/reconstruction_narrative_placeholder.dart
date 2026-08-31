import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Placeholder for Sprint 9.3.2 Narrative Builder.
class ReconstructionNarrativePlaceholder extends StatelessWidget {
  const ReconstructionNarrativePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
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
}
