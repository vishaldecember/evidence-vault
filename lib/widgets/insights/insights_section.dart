import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/insight_model.dart';
import '../workspace/workspace_card.dart';
import 'insight_card.dart';

/// Observational insights derived from existing incident information.
///
/// Describes patterns — never judges, speculates, or accuses.
/// Extension points reserved for AI insights, risk detection, missing
/// evidence suggestions, contradiction detection, and narrative summaries.
class InsightsSection extends StatelessWidget {
  const InsightsSection({
    super.key,
    required this.insights,
  });

  final List<InsightModel> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkspaceSectionHeader(
            title: 'Insights',
            caption: 'Observations from your preserved record.',
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < insights.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            InsightCard(insight: insights[i]),
          ],
        ],
      ),
    );
  }
}
