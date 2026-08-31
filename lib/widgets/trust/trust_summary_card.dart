import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/trust_summary_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Read-only trust details for one preserved evidence artifact.
class TrustSummaryCard extends StatelessWidget {
  const TrustSummaryCard({super.key, required this.summary});

  final TrustSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < summary.entries.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          _TrustSummaryRow(entry: summary.entries[i]),
        ],
      ],
    );
  }
}

class _TrustSummaryRow extends StatelessWidget {
  const _TrustSummaryRow({required this.entry});

  final TrustSummaryEntry entry;

  IconData get _icon => switch (entry.iconName) {
        'integrity' => Icons.shield_outlined,
        'metadata' => Icons.verified_outlined,
        'verifiedAt' => Icons.schedule_outlined,
        _ => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            _icon,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.label,
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                entry.value,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
