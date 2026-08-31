import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../domain/memory/memory_recall_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';

/// Premium, quiet Memory Recall cards for Vault (Sprint 5D).
class MemoryRecallSection extends StatelessWidget {
  const MemoryRecallSection({
    super.key,
    required this.items,
    required this.onAction,
    required this.onDismiss,
    this.showEmptyExplanation = false,
  });

  final List<MemoryRecallItem> items;
  final ValueChanged<MemoryRecallItem> onAction;
  final ValueChanged<MemoryRecallItem> onDismiss;
  final bool showEmptyExplanation;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && !showEmptyExplanation) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Memory Recall',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (items.isEmpty)
          _EmptyMemoryRecall()
        else ...[
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _MemoryRecallCard(
              item: items[i],
              onAction: () => onAction(items[i]),
              onDismiss: () => onDismiss(items[i]),
            ),
          ],
        ],
      ],
    );
  }
}

class _EmptyMemoryRecall extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.elevatedSection(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your future self will thank you.',
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Capture important moments now. We’ll help you find them later.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryRecallCard extends StatelessWidget {
  const _MemoryRecallCard({
    required this.item,
    required this.onAction,
    required this.onDismiss,
  });

  final MemoryRecallItem item;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.headline,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.title,
            style: AppTextStyles.label.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _metaLine(item),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Reason: ${item.reason}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  item.actionLabel,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Not now',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _metaLine(MemoryRecallItem item) {
    final parts = <String>[
      if (item.ageLabel != null) item.ageLabel!,
      if (item.maturityLabel != null) item.maturityLabel!,
      if (item.evidenceCount != null)
        '${item.evidenceCount} evidence',
      if (item.relationshipCount != null && item.relationshipCount! > 0)
        '${item.relationshipCount} relationships',
    ];
    return parts.join(' · ');
  }
}
