import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../services/workspace_coaching_service.dart';
import '../../models/journey_stage.dart';
import '../../models/relationship_group.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/relationship_group_color_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../common/status_badge.dart';
import 'evidence_maturity_engine.dart';
import 'journey_evidence_thumbnail.dart';
import 'workspace_card.dart';

/// Visualizes evidence maturity (capture) or organize records (organize).
///
/// Capture path: [EvidenceMaturityEngine] with three fixed lanes.
/// Organize path: full journey grid + organizer coaching + connect toolbar.
class IncidentJourneyCard extends StatelessWidget {
  const IncidentJourneyCard({
    super.key,
    required this.currentStage,
    required this.currentCoaching,
    required this.journeyEvidence,
    this.onEvidenceSelected,
    this.animateEvidenceId,
    this.relationshipGroups = const [],
    this.connectModeActive = false,
    this.selectedEvidenceIds = const {},
    this.connectPendingColorIndex = 0,
    this.resolveParticipantName,
    this.isOrganizeStage = false,
    this.onConnectPressed,
    this.onCancelConnect,
    this.showConnectAction = false,
    this.suggestedCollectionsPanel,
  });

  final JourneyStage currentStage;
  final WorkspaceCoaching currentCoaching;
  final List<WorkspaceEvidenceItem> journeyEvidence;
  final ValueChanged<WorkspaceEvidenceItem>? onEvidenceSelected;
  final String? animateEvidenceId;
  final List<RelationshipGroup> relationshipGroups;
  final bool connectModeActive;
  final Set<String> selectedEvidenceIds;
  final int connectPendingColorIndex;
  final String? Function(String participantId)? resolveParticipantName;

  /// Organize stage: title, actions, and organiser-focused coaching.
  final bool isOrganizeStage;
  final VoidCallback? onConnectPressed;
  final VoidCallback? onCancelConnect;
  final bool showConnectAction;

  /// Sprint 5B — Suggested Collections replace manual Connect Mode.
  final Widget? suggestedCollectionsPanel;

  static const double _nodeSize = 12;
  static const double _connectorHeight = 22;
  static const double _railWidth = 24;

  @override
  Widget build(BuildContext context) {
    final currentIndex = JourneyStage.timeline.indexOf(currentStage);

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.enter,
      decoration: connectModeActive
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      child: WorkspaceOrientationCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: WorkspaceSectionHeader(
                    title: isOrganizeStage
                        ? 'Organize Records'
                        : 'Evidence Maturity',
                    caption: isOrganizeStage
                        ? 'Review suggested collections, then continue.'
                        : 'Primary evidence grows into investigation strength.',
                    titleStyle: AppTextStyles.heading.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(
                  status: IncidentStatus.fromJourneyStage(currentStage),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (isOrganizeStage) ...[
              if (suggestedCollectionsPanel != null)
                suggestedCollectionsPanel!
              else if (journeyEvidence.isNotEmpty)
                _OrganizeEvidenceGrid(
                  journeyEvidence: journeyEvidence,
                  onEvidenceSelected: onEvidenceSelected,
                  animateEvidenceId: animateEvidenceId,
                  relationshipGroups: relationshipGroups,
                  connectModeActive: connectModeActive,
                  selectedEvidenceIds: selectedEvidenceIds,
                  connectPendingColorIndex: connectPendingColorIndex,
                  resolveParticipantName: resolveParticipantName,
                ),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < JourneyStage.timeline.length; i++)
                _StageRow(
                  stage: JourneyStage.timeline[i],
                  isReached: i <= currentIndex,
                  isCurrent: i == currentIndex,
                  showConnector: i < JourneyStage.timeline.length - 1,
                  connectorIsReached: i < currentIndex,
                  coaching: i == currentIndex ? currentCoaching : null,
                  useOrganizeCoaching: true,
                ),
            ] else
              EvidenceMaturityEngine(
                journeyEvidence: journeyEvidence,
                currentStage: currentStage,
                onEvidenceSelected: onEvidenceSelected,
                animateEvidenceId: animateEvidenceId,
                relationshipGroups: relationshipGroups,
                connectModeActive: connectModeActive,
                selectedEvidenceIds: selectedEvidenceIds,
                connectPendingColorIndex: connectPendingColorIndex,
                resolveParticipantName: resolveParticipantName,
              ),
          ],
        ),
      ),
    );
  }
}

/// Organize-stage grid — full journey sequence for connect / grouping.
class _OrganizeEvidenceGrid extends StatelessWidget {
  const _OrganizeEvidenceGrid({
    required this.journeyEvidence,
    this.onEvidenceSelected,
    this.animateEvidenceId,
    this.relationshipGroups = const [],
    this.connectModeActive = false,
    this.selectedEvidenceIds = const {},
    this.connectPendingColorIndex = 0,
    this.resolveParticipantName,
  });

  final List<WorkspaceEvidenceItem> journeyEvidence;
  final ValueChanged<WorkspaceEvidenceItem>? onEvidenceSelected;
  final String? animateEvidenceId;
  final List<RelationshipGroup> relationshipGroups;
  final bool connectModeActive;
  final Set<String> selectedEvidenceIds;
  final int connectPendingColorIndex;
  final String? Function(String participantId)? resolveParticipantName;

  Color? _accentFor(WorkspaceEvidenceItem item) {
    if (connectModeActive && selectedEvidenceIds.contains(item.id)) {
      return RelationshipGroupColorService.colorForIndex(
        connectPendingColorIndex,
      );
    }

    final savedGroup = RelationshipGroupColorService.groupForEvidence(
      item.id,
      relationshipGroups,
    );
    if (savedGroup != null) {
      return RelationshipGroupColorService.colorForGroup(savedGroup);
    }
    return null;
  }

  bool _showBadgeFor(WorkspaceEvidenceItem item) {
    if (connectModeActive && selectedEvidenceIds.contains(item.id)) {
      return true;
    }
    return RelationshipGroupColorService.groupForEvidence(
          item.id,
          relationshipGroups,
        ) !=
        null;
  }

  String? _participantNameFor(WorkspaceEvidenceItem item) {
    final participantId = item.participantId;
    if (participantId == null || resolveParticipantName == null) {
      return null;
    }
    return resolveParticipantName!(participantId);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xxs,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < journeyEvidence.length; i++) ...[
          JourneyEvidenceThumbnail(
            key: ValueKey(journeyEvidence[i].id),
            item: journeyEvidence[i],
            animateEntry: journeyEvidence[i].id == animateEvidenceId,
            isSelected: connectModeActive &&
                selectedEvidenceIds.contains(journeyEvidence[i].id),
            accentColor: _accentFor(journeyEvidence[i]),
            showGroupBadge: _showBadgeFor(journeyEvidence[i]),
            participantDisplayName: _participantNameFor(journeyEvidence[i]),
            onTap: onEvidenceSelected == null
                ? null
                : () => onEvidenceSelected!(journeyEvidence[i]),
          ),
          if (i < journeyEvidence.length - 1)
            _SemanticEvidenceConnector(
              key: ValueKey(
                'connector-${journeyEvidence[i].id}-${journeyEvidence[i + 1].id}',
              ),
              leadingTo: journeyEvidence[i + 1],
            ),
        ],
      ],
    );
  }
}

class _SemanticEvidenceConnector extends StatelessWidget {
  const _SemanticEvidenceConnector({
    super.key,
    required this.leadingTo,
  });

  final WorkspaceEvidenceItem leadingTo;

  @override
  Widget build(BuildContext context) {
    final color = leadingTo.isPrimaryChronologyEvidence
        ? AppColors.timelineChronology
        : AppColors.timelineSupporting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 22,
        color: color.withValues(alpha: 0.9),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.isReached,
    required this.isCurrent,
    required this.showConnector,
    required this.connectorIsReached,
    this.coaching,
    this.useOrganizeCoaching = false,
  });

  final JourneyStage stage;
  final bool isReached;
  final bool isCurrent;
  final bool showConnector;
  final bool connectorIsReached;
  final WorkspaceCoaching? coaching;
  final bool useOrganizeCoaching;

  @override
  Widget build(BuildContext context) {
    final nodeColor = isReached ? AppColors.primary : AppColors.textSecondary;
    final nodeSize = isCurrent
        ? IncidentJourneyCard._nodeSize + 3
        : IncidentJourneyCard._nodeSize;
    final labelStyle = AppTextStyles.label.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      fontSize: 13,
      color: isReached ? AppColors.navy : AppColors.textMuted,
    );
    final descriptionStyle = AppTextStyles.caption.copyWith(
      height: 1.45,
      fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w400,
      color: isCurrent
          ? AppColors.textPrimary
          : isReached
              ? AppColors.textSecondary
              : AppColors.textMuted,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: IncidentJourneyCard._railWidth,
          child: Column(
            children: [
              Container(
                width: nodeSize,
                height: nodeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isReached ? nodeColor : Colors.transparent,
                  border: Border.all(
                    color: nodeColor,
                    width: isReached ? 0 : 2,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              ),
              if (showConnector)
                Container(
                  width: 2,
                  height: IncidentJourneyCard._connectorHeight,
                  decoration: BoxDecoration(
                    color: connectorIsReached
                        ? AppColors.primary
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: showConnector ? AppSpacing.sm : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage.label, style: labelStyle),
                const SizedBox(height: AppSpacing.xxs),
                AnimatedSwitcher(
                  duration: WorkspaceCoachingService.coachingAnimationDuration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _CoachingContent(
                    key: ValueKey(
                      '${coaching?.progressMessage ?? stage.label}'
                      '::${coaching?.coachingMessage ?? (useOrganizeCoaching ? WorkspaceCoachingService.organizeMessageForStage(stage) : WorkspaceCoachingService.messageForStage(stage))}',
                    ),
                    coaching: coaching,
                    stage: stage,
                    descriptionStyle: descriptionStyle,
                    useOrganizeCoaching: useOrganizeCoaching,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachingContent extends StatelessWidget {
  const _CoachingContent({
    super.key,
    required this.coaching,
    required this.stage,
    required this.descriptionStyle,
    this.useOrganizeCoaching = false,
  });

  final WorkspaceCoaching? coaching;
  final JourneyStage stage;
  final TextStyle descriptionStyle;
  final bool useOrganizeCoaching;

  @override
  Widget build(BuildContext context) {
    final progressMessage = coaching?.progressMessage;
    final message = coaching?.coachingMessage ??
        (useOrganizeCoaching
            ? WorkspaceCoachingService.organizeMessageForStage(stage)
            : WorkspaceCoachingService.messageForStage(stage));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progressMessage != null) ...[
          Text(
            progressMessage,
            style: descriptionStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        Text(message, style: descriptionStyle),
      ],
    );
  }
}
