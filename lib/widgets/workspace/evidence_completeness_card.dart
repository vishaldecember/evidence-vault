import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'workspace_card.dart';

class EvidenceCompletenessItem {
  const EvidenceCompletenessItem({
    required this.label,
    required this.isPreserved,
  });

  final String label;
  final bool isPreserved;
}

class EvidenceCompletenessCard extends StatelessWidget {
  const EvidenceCompletenessCard({
    super.key,
    required this.items,
  });

  final List<EvidenceCompletenessItem> items;

  @override
  Widget build(BuildContext context) {
    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkspaceSectionHeader(
            title: 'Next Best Action',
            caption: 'Evidence can always be enriched later.',
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            _EnrichmentRow(item: items[index]),
          ],
        ],
      ),
    );
  }
}

class _EnrichmentRow extends StatelessWidget {
  const _EnrichmentRow({required this.item});

  final EvidenceCompletenessItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          item.isPreserved ? Icons.circle : Icons.circle_outlined,
          size: 10,
          color: item.isPreserved ? AppColors.primary : AppColors.textMuted,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          item.label,
          style: AppTextStyles.label.copyWith(
            color:
                item.isPreserved ? AppColors.navy : AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          item.isPreserved ? 'Preserved' : 'Not yet',
          style: AppTextStyles.caption.copyWith(
            color: item.isPreserved ? AppColors.primary : AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
