import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../domain/collection/evidence_collection.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/collection/collection_engine.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import 'living_evidence_preview.dart';

/// Organize-stage Suggested Collections — review and refine only (Sprint 5B).
class SuggestedCollectionsPanel extends StatelessWidget {
  const SuggestedCollectionsPanel({
    super.key,
    required this.collections,
    required this.evidence,
    required this.onRename,
    required this.onMerge,
    required this.onSplit,
    required this.onMoveEvidence,
    required this.onDeleteEmpty,
  });

  final List<EvidenceCollection> collections;
  final List<WorkspaceEvidenceItem> evidence;
  final void Function(EvidenceCollection collection) onRename;
  final void Function(EvidenceCollection collection) onMerge;
  final void Function(EvidenceCollection collection) onSplit;
  final void Function({
    required String evidenceId,
    required String toCollectionId,
  }) onMoveEvidence;
  final void Function(EvidenceCollection collection) onDeleteEmpty;

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return Text(
        'Capture evidence to generate suggested collections.',
        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      );
    }

    final ordered = List<EvidenceCollection>.from(collections)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Suggested Collections',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Review and adjust — Investigation uses these collections.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final collection in ordered) ...[
          _CollectionCard(
            collection: collection,
            members: CollectionEngine.membersOf(
              collection: collection,
              evidence: evidence,
            ),
            allCollections: ordered,
            onRename: () => onRename(collection),
            onMerge: () => onMerge(collection),
            onSplit: () => onSplit(collection),
            onDeleteEmpty: collection.isEmpty
                ? () => onDeleteEmpty(collection)
                : null,
            onAcceptEvidence: (evidenceId) => onMoveEvidence(
              evidenceId: evidenceId,
              toCollectionId: collection.id,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.members,
    required this.allCollections,
    required this.onRename,
    required this.onMerge,
    required this.onSplit,
    required this.onAcceptEvidence,
    this.onDeleteEmpty,
  });

  final EvidenceCollection collection;
  final List<WorkspaceEvidenceItem> members;
  final List<EvidenceCollection> allCollections;
  final VoidCallback onRename;
  final VoidCallback onMerge;
  final VoidCallback onSplit;
  final ValueChanged<String> onAcceptEvidence;
  final VoidCallback? onDeleteEmpty;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        return details.data.isNotEmpty &&
            !collection.memberEvidenceIds.contains(details.data);
      },
      onAcceptWithDetails: (details) => onAcceptEvidence(details.data),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: AppDecorations.card().copyWith(
            border: Border.all(
              color: hovering
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : AppColors.border.withValues(alpha: 0.9),
              width: hovering ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: collection.name,
                            style: AppTextStyles.heading.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          TextSpan(
                            text: '  (${collection.count})',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<_CollectionAction>(
                    tooltip: 'Collection actions',
                    onSelected: (action) {
                      switch (action) {
                        case _CollectionAction.rename:
                          onRename();
                        case _CollectionAction.merge:
                          onMerge();
                        case _CollectionAction.split:
                          onSplit();
                        case _CollectionAction.delete:
                          onDeleteEmpty?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _CollectionAction.rename,
                        child: Text('Rename'),
                      ),
                      if (allCollections.length > 1)
                        const PopupMenuItem(
                          value: _CollectionAction.merge,
                          child: Text('Merge into…'),
                        ),
                      if (collection.count >= 2)
                        const PopupMenuItem(
                          value: _CollectionAction.split,
                          child: Text('Split selected…'),
                        ),
                      if (onDeleteEmpty != null)
                        const PopupMenuItem(
                          value: _CollectionAction.delete,
                          child: Text('Delete empty'),
                        ),
                    ],
                    icon: Icon(
                      Icons.more_horiz,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              if (collection.systemGenerated) ...[
                const SizedBox(height: 2),
                Text(
                  'Suggested',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              if (members.isEmpty)
                Text(
                  'Drop evidence here',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                )
              else
                SizedBox(
                  height: LivingEvidencePreview.mediaSize + 8,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: members.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final item = members[index];
                      return LongPressDraggable<String>(
                        data: item.id,
                        feedback: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: LivingEvidencePreview.mediaSize,
                            height: LivingEvidencePreview.mediaSize,
                            child: LivingEvidencePreview(item: item),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: SizedBox(
                            width: LivingEvidencePreview.mediaSize,
                            height: LivingEvidencePreview.mediaSize,
                            child: LivingEvidencePreview(item: item),
                          ),
                        ),
                        child: SizedBox(
                          width: LivingEvidencePreview.mediaSize,
                          height: LivingEvidencePreview.mediaSize,
                          child: LivingEvidencePreview(item: item),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _CollectionAction { rename, merge, split, delete }
