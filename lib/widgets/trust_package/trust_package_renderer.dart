import 'package:flutter/material.dart';



import '../../constants/app_spacing.dart';

import '../../models/evidence_artifact_model.dart';

import '../../models/reflection_model.dart';

import '../../models/story_model.dart';

import '../../models/trust_package_model.dart';

import '../../models/verification_model.dart';

import '../../models/workspace_evidence_item.dart';

import '../../theme/app_colors.dart';

import '../../theme/app_text_styles.dart';

import '../../utils/workspace_evidence_formatters.dart';

import '../evidence/evidence_artifact_card.dart';

import '../linked_evidence/linked_evidence_card.dart';

import '../timeline/timeline_item_card.dart';

import '../verification/verification_badge.dart';

import 'trust_package_section.dart';



/// Renders a [TrustPackageModel] as a read-only sharing preview.

///

/// Assembles existing information only — never edits or generates content.

/// Structured sections are rendered once; the nested [StoryRenderer] is

/// omitted here because timeline, evidence, context, and reflections are

/// already shown in dedicated export sections below the summary.

class TrustPackageRenderer extends StatelessWidget {

  const TrustPackageRenderer({

    super.key,

    required this.package,

    required this.allItems,

    required this.onEvidenceSelected,

  });



  final TrustPackageModel package;

  final List<WorkspaceEvidenceItem> allItems;

  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;



  Map<String, WorkspaceEvidenceItem> get _itemById =>

      {for (final item in allItems) item.id: item};



  @override

  Widget build(BuildContext context) {

    if (package.isEmpty) {

      return Text(

        'No preserved information is available to prepare a trust package yet.',

        style: AppTextStyles.bodySmall.copyWith(height: 1.6),

      );

    }



    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        if (package.hasIncidentSummary) ...[

          TrustPackageSection(

            title: 'Incident Summary',

            child: Text(

              package.incidentSummary!,

              style: AppTextStyles.body.copyWith(height: 1.7),

            ),

          ),

          const TrustPackageSectionDivider(),

        ],

        if (package.hasTimeline) ...[

          TrustPackageSection(

            title: 'Incident Timeline',

            caption: 'What happened, and in what order.',

            child: ListView.builder(

              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: package.timeline.length,

              itemBuilder: (context, index) {

                final item = package.timeline[index];

                return RepaintBoundary(

                  child: TimelineItemCard(

                    item: item,

                    showConnector: index < package.timeline.length - 1,

                    onTap: () => _selectById(item.evidenceId),

                  ),

                );

              },

            ),

          ),

          const TrustPackageSectionDivider(),

        ],

        if (package.hasEvidence) ...[

          TrustPackageSection(

            title: 'Evidence',

            child: ListView.separated(

              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: package.evidence.length,

              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),

              itemBuilder: (context, index) {

                final item = package.evidence[index];

                return RepaintBoundary(

                  child: EvidenceArtifactCard(

                    artifact: EvidenceArtifactModel.fromWorkspaceItem(item),

                    onTap: () => onEvidenceSelected(item),

                  ),

                );

              },

            ),

          ),

          const TrustPackageSectionDivider(),

        ],

        if (package.hasContext) ...[

          TrustPackageSection(

            title: 'Context',

            child: ListView.separated(

              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: package.context.length,

              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),

              itemBuilder: (context, index) {

                return _ContextGroupBlock(

                  group: package.context[index],

                  onEvidenceSelected: onEvidenceSelected,

                );

              },

            ),

          ),

          const TrustPackageSectionDivider(),

        ],

        if (package.hasLinkedEvidence) ...[

          TrustPackageSection(

            title: 'Linked Evidence',

            child: ListView.separated(

              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: package.linkedEvidence.length,

              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),

              itemBuilder: (context, index) {

                final entry = package.linkedEvidence[index];

                return _LinkedEvidenceRow(

                  entry: entry,

                  onTap: () => _selectById(entry.link.evidenceId),

                );

              },

            ),

          ),

          const TrustPackageSectionDivider(),

        ],

        if (package.hasReflections)

          TrustPackageSection(

            title: 'Reflection',

            child: ListView.separated(

              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: package.reflections.length,

              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),

              itemBuilder: (context, index) {

                return _ReflectionBlock(reflection: package.reflections[index]);

              },

            ),

          ),

        if (package.hasReflections) const TrustPackageSectionDivider(),

        TrustPackageSection(

          title: 'Integrity',

          child: _IntegrityBlock(

            verified: package.integrityVerified,

            explanation: package.integrityExplanation,

            verification: package.verification,

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



class _LinkedEvidenceRow extends StatelessWidget {

  const _LinkedEvidenceRow({

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



class _ReflectionBlock extends StatelessWidget {

  const _ReflectionBlock({required this.reflection});



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

            WorkspaceEvidenceFormatters.preservedTimestamp(reflection.createdAt),

            style: AppTextStyles.caption,

          ),

        ],

      ),

    );

  }

}



class _IntegrityBlock extends StatelessWidget {

  const _IntegrityBlock({

    required this.verified,

    required this.explanation,

    required this.verification,

  });



  final bool verified;

  final String explanation;

  final VerificationModel verification;



  @override

  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(AppSpacing.md),

      decoration: BoxDecoration(

        color: AppColors.surfaceMuted.withValues(alpha: 0.45),

        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),

        border: Border.all(

          color: verified

              ? AppColors.success.withValues(alpha: 0.25)

              : AppColors.border.withValues(alpha: 0.55),

        ),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          if (verified)

            Row(

              children: [

                Text(

                  'Integrity Verified',

                  style: AppTextStyles.label.copyWith(

                    color: AppColors.success,

                    fontWeight: FontWeight.w600,

                  ),

                ),

                const SizedBox(width: AppSpacing.xxs),

                const Icon(

                  Icons.check_rounded,

                  size: 18,

                  color: AppColors.success,

                ),

              ],

            ),

          if (verified) const SizedBox(height: AppSpacing.sm),

          Text(

            explanation,

            style: AppTextStyles.bodySmall.copyWith(height: 1.6),

          ),

          if (!verification.isNotVerified) ...[

            const SizedBox(height: AppSpacing.sm),

            VerificationBadge(verification: verification),

          ],

        ],

      ),

    );

  }

}

