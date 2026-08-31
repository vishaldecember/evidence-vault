import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/layered_card.dart';
import '../common/premium_cta_button.dart';

/// Home journey card when the signed-in user has no real incident.
class FirstIncidentCard extends StatelessWidget {
  const FirstIncidentCard({super.key, required this.onCaptureNewIncident});

  final VoidCallback onCaptureNewIncident;

  static const title = 'Preserve your first incident';
  static const cta = 'Capture New Incident';
  static const supporting =
      'Capture photos, video, voice, notes, or documents to start building your record.';

  @override
  Widget build(BuildContext context) {
    return LayeredCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        key: const Key('first_incident_card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            key: const Key('first_incident_title'),
            style: AppTextStyles.heading.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            supporting,
            key: const Key('first_incident_supporting'),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumCtaButton(
            key: const Key('first_incident_cta'),
            label: cta,
            onPressed: onCaptureNewIncident,
          ),
        ],
      ),
    );
  }
}
