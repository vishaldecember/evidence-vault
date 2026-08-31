import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../domain/collection/evidence_collection.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/collection/collection_engine.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Pending engine-generated collection awaiting accept or dismiss.
class OrganizeSuggestionCard extends StatelessWidget {
  const OrganizeSuggestionCard({
    super.key,
    required this.collection,
    required this.evidence,
    this.onAccept,
    this.onDismiss,
  });

  final EvidenceCollection collection;
  final List<WorkspaceEvidenceItem> evidence;
  final VoidCallback? onAccept;
  final VoidCallback? onDismiss;

  static Key cardKey(String collectionId) =>
      Key('organize_suggestion_$collectionId');

  static Key acceptKey(String collectionId) =>
      Key('organize_suggestion_accept_$collectionId');

  static Key dismissKey(String collectionId) =>
      Key('organize_suggestion_dismiss_$collectionId');

  @override
  Widget build(BuildContext context) {
    final members = CollectionEngine.membersOf(
      collection: collection,
      evidence: evidence,
    );
    final kinds = <String>{for (final item in members) item.kind.label};
    final countLabel = members.length == 1
        ? '1 preserved record'
        : '${members.length} preserved records';
    final kindsLabel = kinds.isEmpty ? null : kinds.join(', ');

    return Container(
      key: cardKey(collection.id),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        border: Border.all(
          color: AppColors.borderAccent.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Suggested evidence group',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            collection.name,
            style: AppTextStyles.label.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            countLabel,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (kindsLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              kindsLabel,
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (onAccept != null || onDismiss != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                if (onAccept != null)
                  TextButton(
                    key: acceptKey(collection.id),
                    onPressed: onAccept,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Add to Group'),
                  ),
                if (onDismiss != null)
                  TextButton(
                    key: dismissKey(collection.id),
                    onPressed: onDismiss,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Dismiss'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
