import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/relationship_group.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../../services/relationship_group_color_service.dart';
import '../../utils/workspace_evidence_formatters.dart';
import '../workspace/living_evidence_preview.dart';

/// Expandable card for one committed [RelationshipGroup].
class RelationshipGroupCard extends StatefulWidget {
  const RelationshipGroupCard({
    super.key,
    required this.group,
    required this.allGroups,
    required this.evidenceById,
    required this.onEvidenceSelected,
  });

  final RelationshipGroup group;
  final List<RelationshipGroup> allGroups;
  final Map<String, WorkspaceEvidenceItem> evidenceById;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;

  @override
  State<RelationshipGroupCard> createState() => _RelationshipGroupCardState();
}

class _RelationshipGroupCardState extends State<RelationshipGroupCard> {
  bool _expanded = true;

  Color get _groupColor =>
      RelationshipGroupColorService.colorForGroup(widget.group);

  List<WorkspaceEvidenceItem> get _members {
    return widget.group.evidenceIds
        .map((id) => widget.evidenceById[id])
        .whereType<WorkspaceEvidenceItem>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    final title = RelationshipGroupColorService.displayName(
      widget.group,
      widget.allGroups,
    );

    return DecoratedBox(
      decoration: AppDecorations.card().copyWith(
        boxShadow: [
          BoxShadow(
            color: _groupColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          ...AppDecorations.cardShadows,
        ],
        border: Border.all(
          color: _groupColor.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.cardRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.xxs,
                  AppSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GroupColorIndicator(color: _groupColor),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.label.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '${members.length} evidence items • '
                            '${WorkspaceEvidenceFormatters.preservedTimestamp(widget.group.createdAt)}',
                            style: AppTextStyles.caption.copyWith(
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Group actions',
                      padding: EdgeInsets.zero,
                      onSelected: (_) {},
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename Group'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Group'),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit Group'),
                        ),
                      ],
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: AppMotion.medium,
                      curve: AppMotion.enter,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: _GroupEvidenceGrid(
                members: members,
                groupColor: _groupColor,
                onEvidenceSelected: widget.onEvidenceSelected,
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupColorIndicator extends StatelessWidget {
  const _GroupColorIndicator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

class _GroupEvidenceGrid extends StatelessWidget {
  const _GroupEvidenceGrid({
    required this.members,
    required this.groupColor,
    required this.onEvidenceSelected,
  });

  final List<WorkspaceEvidenceItem> members;
  final Color groupColor;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final item in members)
          _GroupEvidenceTile(
            item: item,
            groupColor: groupColor,
            onTap: () => onEvidenceSelected(item),
          ),
      ],
    );
  }
}

class _GroupEvidenceTile extends StatelessWidget {
  const _GroupEvidenceTile({
    required this.item,
    required this.groupColor,
    required this.onTap,
  });

  final WorkspaceEvidenceItem item;
  final Color groupColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: LivingEvidencePreview.mediaSize + 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: Border.all(
                color: groupColor.withValues(alpha: 0.35),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.sm - 1),
              child: LivingEvidencePreview(
                item: item,
                uniformThumbnailSize: true,
                suppressBorder: true,
                onTap: onTap,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            item.kind.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
