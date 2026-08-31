import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_artifact_model.dart';
import '../../models/reflection_model.dart';
import '../../models/story_model.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/workspace_evidence_formatters.dart';
import '../evidence/evidence_artifact_card.dart';
import '../linked_evidence/linked_evidence_card.dart';
import '../timeline/timeline_item_card.dart';
import 'story_section.dart';

/// Renders a [StoryModel] as a reading-focused case file.
///
/// Deterministic — every sentence traceable to preserved information.
/// Extension points reserved for AI refinement and export formats.
class StoryRenderer extends StatelessWidget {
  const StoryRenderer({
    super.key,
    required this.story,
    required this.allItems,
    required this.onEvidenceSelected,
  });

  final StoryModel story;
  final List<WorkspaceEvidenceItem> allItems;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;

  Map<String, WorkspaceEvidenceItem> get _itemById =>
      {for (final item in allItems) item.id: item};

  @override
  Widget build(BuildContext context) {
    if (story.isEmpty) {
      return Text(
        'No preserved information is available to assemble a story yet.',
        style: AppTextStyles.bodySmall.copyWith(height: 1.6),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (story.hasSummary) ...[
          StorySection(
            title: 'Incident Summary',
            child: Text(
              story.summary!,
              style: AppTextStyles.body.copyWith(height: 1.7),
            ),
          ),
          const StorySectionDivider(),
        ],
        if (story.hasTimeline) ...[
          StorySection(
            title: 'Incident Timeline',
            caption: 'What happened, and in what order.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < story.timeline.length; i++)
                  TimelineItemCard(
                    item: story.timeline[i],
                    showConnector: i < story.timeline.length - 1,
                    onTap: () => _selectById(story.timeline[i].evidenceId),
                  ),
              ],
            ),
          ),
          const StorySectionDivider(),
        ],
        if (story.hasEvidenceHighlights) ...[
          StorySection(
            title: 'Evidence Highlights',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < story.evidenceHighlights.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  EvidenceArtifactCard(
                    artifact: EvidenceArtifactModel.fromWorkspaceItem(
                      story.evidenceHighlights[i],
                    ),
                    onTap: () =>
                        onEvidenceSelected(story.evidenceHighlights[i]),
                  ),
                ],
              ],
            ),
          ),
          const StorySectionDivider(),
        ],
        if (story.hasSupportingContext) ...[
          StorySection(
            title: 'Supporting Context',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < story.supportingContext.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.lg),
                  _ContextGroupBlock(
                    group: story.supportingContext[i],
                    onEvidenceSelected: onEvidenceSelected,
                  ),
                ],
              ],
            ),
          ),
          const StorySectionDivider(),
        ],
        if (story.hasLinkedEvidence) ...[
          StorySection(
            title: 'Linked Evidence',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < story.linkedEvidence.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  _LinkedEvidenceStoryRow(
                    entry: story.linkedEvidence[i],
                    onTap: () => _selectById(
                      story.linkedEvidence[i].link.evidenceId,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const StorySectionDivider(),
        ],
        if (story.hasReflections)
          StorySection(
            title: 'Reflection',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < story.reflections.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  _ReflectionStoryBlock(reflection: story.reflections[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  void _selectById(String evidenceId) {
    final item = _itemById[evidenceId];
    if (item != null) {
      onEvidenceSelected(item);
    }
  }
}

class _ContextGroupBlock extends StatelessWidget {
  const _ContextGroupBlock({
    required this.group,
    required this.onEvidenceSelected,
  });

  final StoryContextGroup group;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'For ${EvidenceArtifactType.fromWorkspaceKind(group.parentEvidence.kind).label}',
          style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < group.contextItems.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          Material(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: InkWell(
              onTap: () => onEvidenceSelected(group.contextItems[i]),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      EvidenceArtifactType.fromWorkspaceKind(
                        group.contextItems[i].kind,
                      ).label,
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      group.contextItems[i].notePreview ??
                          group.contextItems[i].title,
                      style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      WorkspaceEvidenceFormatters.preservedTimestamp(
                        group.contextItems[i].lastPreservedAt,
                      ),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LinkedEvidenceStoryRow extends StatelessWidget {
  const _LinkedEvidenceStoryRow({
    required this.entry,
    required this.onTap,
  });

  final StoryLinkedEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'From ${EvidenceArtifactType.fromWorkspaceKind(entry.sourceEvidence.kind).label}',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.xxs),
        LinkedEvidenceCard(item: entry.link, onTap: onTap),
      ],
    );
  }
}

class _ReflectionStoryBlock extends StatelessWidget {
  const _ReflectionStoryBlock({required this.reflection});

  final ReflectionModel reflection;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reflection.hasTitle) ...[
            Text(
              reflection.title!,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            reflection.body,
            style: AppTextStyles.body.copyWith(height: 1.7),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            WorkspaceEvidenceFormatters.preservedTimestamp(
              reflection.createdAt,
            ),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
