import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../common/silver_lustre_text.dart';

/// Global product branding shown once above the Investigation Journey.
class IncidentProductHeader extends StatelessWidget {
  const IncidentProductHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: AppSpacing.logoSizeCompact + AppSpacing.sm,
          height: AppSpacing.logoSizeCompact + AppSpacing.sm,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: ExcludeSemantics(
              child: Image.asset(
                'assets/images/branding/splash_logo.png',
                fit: BoxFit.contain,
              ),
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
