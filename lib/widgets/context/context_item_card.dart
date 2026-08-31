import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/context_item.dart';
import '../../models/context_type.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/workspace_evidence_formatters.dart';

/// Single entry in the Context Timeline.
///
/// View-only in Sprint 4.0 — editing reserved for a future sprint.
/// Extension points reserved for witness statements, location confirmations,
/// evidence relationships, AI observations, and reflection.
class ContextItemCard extends StatelessWidget {
  const ContextItemCard({
    super.key,
    required this.item,
    this.showDivider = true,
    this.onTap,
  });

  final ContextItem item;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypeIcon(type: item.type),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.type.label,
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    WorkspaceEvidenceFormatters.contextAdded(item.addedAt),
                    style: AppTextStyles.caption,
                  ),
                  if (item.displayTitle.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.displayTitle,
                      style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: AppSpacing.md),
          Divider(
            height: 1,
            color: AppColors.border.withValues(alpha: 0.5),
          ),
        ],
      ],
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: content,
        ),
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});

  final ContextType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Icon(
        type.icon,
        size: 22,
        color: AppColors.primary,
      ),
    );
  }
}
