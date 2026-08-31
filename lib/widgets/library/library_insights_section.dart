import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/library_insight_model.dart';
import '../../theme/app_text_styles.dart';
import '../common/home_section_card.dart';
import 'library_insight_card.dart';

/// Cross-incident observations surfaced from the Library of Truth.
class LibraryInsightsSection extends StatelessWidget {
  const LibraryInsightsSection({
    super.key,
    required this.insights,
  });

  /// Default visible observations — section grows only when more exist.
  static const int maxVisibleInsights = 4;

  final List<LibraryInsightModel> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleInsights = insights.take(maxVisibleInsights).toList();

    return HomeSectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
            title: 'Library Insights',
            caption: 'Observable patterns across your preserved incidents.',
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < visibleInsights.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            LibraryInsightCard(insight: visibleInsights[i]),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.caption,
  });

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          caption,
          style: AppTextStyles.caption.copyWith(height: 1.5),
        ),
      ],
    );
  }
}
