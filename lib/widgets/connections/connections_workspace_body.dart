import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../engines/enrichment_engine.dart';
import '../../models/connections_presentation.dart';
import '../../models/relationship_group.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import '../common/silver_lustre_text.dart';
import '../../utils/workspace_evidence_formatters.dart';
import '../timeline/timeline_evidence_labels.dart';
import '../workspace/living_evidence_preview.dart';
import 'connection_group_panel.dart';
import 'connections_pair_card.dart';

/// Scrollable body for the Connections Workspace.
class ConnectionsWorkspaceBody extends StatelessWidget {
  const ConnectionsWorkspaceBody({
    super.key,
    required this.presentation,
    required this.allGroups,
    required this.incidentName,
    required this.organizeMode,
    required this.enrichmentContext,
    required this.onEvidenceTap,
    this.onSupportingAction,
    this.onGroupAction,
    this.onEdit,
    this.highlightedGroupIds = const {},
    this.highlightedEvidenceIds = const {},
    this.onGroupSelected,
    this.embeddedInCanvas = false,
    this.showWorkspaceHeader = true,
  });

  final ConnectionsPresentation presentation;
  final List<RelationshipGroup> allGroups;
  final String incidentName;
  final bool organizeMode;
  final EnrichmentContext enrichmentContext;
  final ConnectionEvidenceTap onEvidenceTap;
  final ConnectionSupportingAction? onSupportingAction;
  final ConnectionGroupAction? onGroupAction;
  final ConnectionGroupEdit? onEdit;
  final Set<String> highlightedGroupIds;
  final Set<String> highlightedEvidenceIds;
  final ValueChanged<RelationshipGroup>? onGroupSelected;
  final bool embeddedInCanvas;
  final bool showWorkspaceHeader;

  @override
  Widget build(BuildContext context) {
    final resolvedIncidentName = incidentName.trim().isEmpty
        ? 'Untitled Incident'
        : incidentName.trim();
    final structuralPairs = [
      ...presentation.supporting,
      ...presentation.linked,
    ];

    return CustomScrollView(
      slivers: [
        if (showWorkspaceHeader)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Connections Workspace',
                  style: AppTextStyles.screenTitle.copyWith(
                    color: AppColors.onCanvas,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  resolvedIncidentName,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.onCanvasSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  organizeMode
                      ? 'Edit relationship groups for this incident.'
                      : 'How the pieces of this incident are structurally connected.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onCanvasSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        if (showWorkspaceHeader)
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        SliverToBoxAdapter(
          child: _SectionLabel(
            key: ConnectionsPresentation.structuralSectionKey,
            label: 'Structural',
            silver: true,
          ),
        ),
        if (!presentation.hasStructural)
          const SliverToBoxAdapter(
            child: _EmptyStructural(),
          )
        else ...[
          if (structuralPairs.isNotEmpty)
            SliverList.builder(
              itemCount: structuralPairs.length,
              itemBuilder: (context, index) {
                final pair = structuralPairs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ConnectionsPairCard(
                    key: ConnectionsPresentation.pairKey(pair),
                    pair: pair,
                    onEvidenceTap: onEvidenceTap,
                  ),
                );
              },
            ),
          if (presentation.collections.isNotEmpty)
            SliverList.builder(
              itemCount: presentation.collections.length,
              itemBuilder: (context, index) {
                final collection = presentation.collections[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _CollectionCard(
                    key: ConnectionsPresentation.collectionKey(
                      collection.collection.id,
                    ),
                    view: collection,
                    onEvidenceTap: onEvidenceTap,
                  ),
                );
              },
            ),
          if (presentation.groupNodes.isNotEmpty)
            SliverList.builder(
              itemCount: presentation.groupNodes.length,
              itemBuilder: (context, index) {
                final node = presentation.groupNodes[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < presentation.groupNodes.length - 1
                        ? AppSpacing.sm
                        : 0,
                  ),
                  child: ConnectionGroupPanel(
                    node: node,
                    allGroups: allGroups,
                    organizeMode: organizeMode,
                    enrichmentContext: enrichmentContext,
                    onEvidenceTap: onEvidenceTap,
                    onSupportingAction:
                        organizeMode ? onSupportingAction : null,
                    onGroupAction: organizeMode ? onGroupAction : null,
                    onEdit: onEdit,
                    isGroupHighlighted:
                        highlightedGroupIds.contains(node.group.id),
                    highlightedEvidenceIds: highlightedEvidenceIds,
                    onGroupSelected: onGroupSelected == null
                        ? null
                        : () => onGroupSelected!(node.group),
                  ),
                );
              },
            ),
        ],
        if (presentation.hasSuggested) ...[
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          SliverToBoxAdapter(
            child: _SectionLabel(
              key: ConnectionsPresentation.suggestedSectionKey,
              label: 'Suggested',
              muted: true,
            ),
          ),
          SliverList.builder(
            itemCount: presentation.suggested.length,
            itemBuilder: (context, index) {
              final pair = presentation.suggested[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ConnectionsPairCard(
                  key: ConnectionsPresentation.suggestedKey(pair),
                  pair: pair,
                  onEvidenceTap: onEvidenceTap,
                ),
              );
            },
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    super.key,
    required this.label,
    this.muted = false,
    this.silver = false,
  });

  final String label;
  final bool muted;
  final bool silver;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.dividerLabel.copyWith(
      color: muted ? AppColors.textMuted : AppColors.navy,
      letterSpacing: 0.8,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: silver
          ? SilverLustreText(
              label.toUpperCase(),
              style: style,
            )
          : Text(
              label.toUpperCase(),
              style: style,
            ),
    );
  }
}

class _EmptyStructural extends StatelessWidget {
  const _EmptyStructural();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ConnectionsPresentation.emptyStructuralKey,
      decoration: AppDecorations.card(backgroundColor: AppColors.background),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'No explicit connections yet.',
          style: AppTextStyles.bodySmall.copyWith(height: 1.55),
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    super.key,
    required this.view,
    required this.onEvidenceTap,
  });

  final ConnectionsCollectionView view;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppDecorations.card(backgroundColor: AppColors.background),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Part of collection',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              view.name,
              style: AppTextStyles.emphasisLabel,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final member in view.members) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onEvidenceTap(member),
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppSpacing.xs),
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: LivingEvidencePreview(
                                item: member,
                                uniformThumbnailSize: true,
                                suppressBorder: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                TimelineEvidenceLabels.capturedLabel(member),
                                style: AppTextStyles.label,
                              ),
                              Text(
                                WorkspaceEvidenceFormatters.evidenceClock(
                                  member.lastPreservedAt,
                                ),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
