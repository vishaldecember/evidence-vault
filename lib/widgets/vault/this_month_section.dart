import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../domain/memory/memory_recall_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/silver_lustre_text.dart';

/// Incident/evidence focused month summary — not a productivity dashboard.
class ThisMonthSection extends StatelessWidget {
  const ThisMonthSection({
    super.key,
    required this.summary,
  });

  final MemoryMonthSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) {
      return const SizedBox.shrink();
    }

    final lines = <String>[
      if (summary.evidenceCaptured > 0)
        '${summary.evidenceCaptured} evidence captured',
      if (summary.incidentsTouched > 0)
        '${summary.incidentsTouched} incident${summary.incidentsTouched == 1 ? '' : 's'} touched',
      if (summary.investigationsStrengthened > 0)
        '${summary.investigationsStrengthened} investigation${summary.investigationsStrengthened == 1 ? '' : 's'} strengthened',
      if (summary.becameReady > 0)
        '${summary.becameReady} investigation${summary.becameReady == 1 ? '' : 's'} became Ready',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'This Month',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: SilverLustreText(
              line,
              style: AppTextStyles.bodySmall,
            ),
          ),
      ],
    );
  }
}
