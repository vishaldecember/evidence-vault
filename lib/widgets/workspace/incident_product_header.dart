import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import '../common/silver_lustre_text.dart';

/// Global product branding shown once above the Investigation Journey.
class IncidentProductHeader extends StatelessWidget {
  const IncidentProductHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: AppSpacing.logoSizeCompact + AppSpacing.sm,
          height: AppSpacing.logoSizeCompact + AppSpacing.sm,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSpacing.xxl),
            boxShadow: AppDecorations.cardShadows,
          ),
          child: ExcludeSemantics(
            child: Image.asset(
              'assets/images/branding/logo_mark.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SilverLustreText(
          'Your incident lives here.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
