import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../engines/enrichment_engine.dart';
import '../../models/connection_group_node.dart';
import '../../models/relationship_group.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/relationship_group_color_service.dart';
import '../../services/relationship_group_confidence_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/investigation_selection_visuals.dart';
import '../timeline/timeline_evidence_labels.dart';
import '../workspace/living_evidence_preview.dart';
import '../investigation/evidence_review_halo.dart';
import 'relationship_group_confidence_indicator.dart';

typedef ConnectionEvidenceTap = void Function(WorkspaceEvidenceItem item);

typedef ConnectionSupportingAction = void Function({
  required WorkspaceEvidenceItem item,
  required RelationshipGroup group,
  required ConnectionSupportingActionType action,
});

enum ConnectionSupportingActionType {
  moveToGroup,
  removeFromGroup,
}

typedef ConnectionGroupAction = void Function({
  required RelationshipGroup group,
  required ConnectionGroupActionType action,
});

enum ConnectionGroupActionType {
  merge,
  split,
  deleteEmpty,
}

typedef ConnectionGroupEdit = void Function({
  required RelationshipGroup group,
  required String displayName,
  required String description,
});

/// Coloured relationship group panel for the Connections Workspace.
class ConnectionGroupPanel extends StatefulWidget {
  const ConnectionGroupPanel({
    super.key,
    required this.node,
    required this.allGroups,
    required this.organizeMode,
    required this.enrichmentContext,
    required this.onEvidenceTap,
    this.onSupportingAction,
    this.onGroupAction,
    this.onEdit,
    this.isGroupHighlighted = false,
    this.highlightedEvidenceIds = const {},
    this.onGroupSelected,
  });

  final ConnectionGroupNode node;
  final List<RelationshipGroup> allGroups;
  final bool organizeMode;
  final EnrichmentContext enrichmentContext;
  final ConnectionEvidenceTap onEvidenceTap;
  final ConnectionSupportingAction? onSupportingAction;
  final ConnectionGroupAction? onGroupAction;
  final ConnectionGroupEdit? onEdit;
  final bool isGroupHighlighted;
  final Set<String> highlightedEvidenceIds;
  final VoidCallback? onGroupSelected;

  @override
  State<ConnectionGroupPanel> createState() => _ConnectionGroupPanelState();
}

class _ConnectionGroupPanelState extends State<ConnectionGroupPanel> {
  bool _expanded = true;
  bool _isEditing = false;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _descriptionFocusNode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _nameFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();
    _nameFocusNode.addListener(_handleEditFocusChange);
    _descriptionFocusNode.addListener(_handleEditFocusChange);
  }

  @override
  void dispose() {
    _nameFocusNode.removeListener(_handleEditFocusChange);
    _descriptionFocusNode.removeListener(_handleEditFocusChange);
    _nameFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleEditFocusChange() {
    if (_isEditing &&
        !_nameFocusNode.hasFocus &&
        !_descriptionFocusNode.hasFocus) {
      _commitEdit();
    }
  }

  Color get _groupColor =>
      RelationshipGroupColorService.colorForGroup(widget.node.group);

  String get _groupTitle => RelationshipGroupColorService.displayName(
        widget.node.group,
        widget.allGroups,
      );

  String? get _groupDescription {
    final description = widget.node.group.description?.trim();
    if (description == null || description.isEmpty) {
      return null;
    }
    return description;
  }

  bool get _showOrganizeMenu =>
      widget.organizeMode && widget.onGroupAction != null;

  void _startEdit() {
    _nameController.text = _groupTitle;
    _descriptionController.text = widget.node.group.description ?? '';
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _nameFocusNode.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  void _commitEdit() {
    if (!_isEditing) {
      return;
    }
    setState(() => _isEditing = false);
    widget.onEdit?.call(
      group: widget.node.group,
      displayName: _nameController.text,
      description: _descriptionController.text,
    );
  }

  void _handleNameSubmitted(String _) {
    _descriptionFocusNode.requestFocus();
    _descriptionController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _descriptionController.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final evidenceLabel = widget.node.evidenceCount == 1
        ? '1 Evidence'
        : '${widget.node.evidenceCount} Evidence';
    final confidence = RelationshipGroupConfidenceService.compute(
      widget.node,
      widget.enrichmentContext,
    );

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: InvestigationSelectionVisuals.selectionDuration,
        curve: InvestigationSelectionVisuals.selectionCurve,
        decoration: AppDecorations.card().copyWith(
          border: Border.all(
            color: widget.isGroupHighlighted
                ? _groupColor.withValues(alpha: 0.65)
                : _groupColor.withValues(alpha: 0.28),
            width: widget.isGroupHighlighted
                ? InvestigationSelectionVisuals.connectionsBorderWidth
                : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _groupColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            ...AppDecorations.cardShadows,
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: _groupColor.withValues(alpha: 0.06),
              child: InkWell(
                onTap: _isEditing
                    ? null
                    : () => setState(() => _expanded = !_expanded),
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
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _GroupColorChip(color: _groupColor),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isEditing) ...[
                              TextField(
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                maxLength:
                                    RelationshipGroup.maxDisplayNameLength,
                                buildCounter: (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) =>
                                    null,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  hintText: _groupTitle,
                                  hintStyle: AppTextStyles.label.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                style: AppTextStyles.label.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                                textInputAction: TextInputAction.next,
                                onSubmitted: _handleNameSubmitted,
                              ),
                              TextField(
                                controller: _descriptionController,
                                focusNode: _descriptionFocusNode,
                                maxLength:
                                    RelationshipGroup.maxDescriptionLength,
                                maxLines: 3,
                                buildCounter: (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) =>
                                    null,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  hintText:
                                      'Why does this evidence belong together?',
                                  hintStyle: AppTextStyles.caption.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _commitEdit(),
                              ),
                            ]                             else ...[
                              GestureDetector(
                                onTap: widget.onGroupSelected,
                                behavior: HitTestBehavior.opaque,
                                child: Text(
                                  _groupTitle,
                                  style: AppTextStyles.label.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                              if (_groupDescription != null) ...[
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  _groupDescription!,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              evidenceLabel,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (!_isEditing) ...[
                              const SizedBox(height: AppSpacing.xs),
                              RelationshipGroupConfidenceIndicator(
                                confidence: confidence,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.onEdit != null && !_isEditing)
                        TextButton(
                          onPressed: _startEdit,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Edit',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (_showOrganizeMenu)
                        PopupMenuButton<ConnectionGroupActionType>(
                          tooltip: 'Group actions',
                          onSelected: (action) => widget.onGroupAction!(
                            group: widget.node.group,
                            action: action,
                          ),
                          itemBuilder: (context) => [
                            if (widget.allGroups.length > 1)
                              const PopupMenuItem(
                                value: ConnectionGroupActionType.merge,
                                child: Text('Merge with another group'),
                              ),
                            const PopupMenuItem(
                              value: ConnectionGroupActionType.split,
                              child: Text('Split supporting evidence'),
                            ),
                            if (widget.node.evidenceCount == 0)
                              const PopupMenuItem(
                                value: ConnectionGroupActionType.deleteEmpty,
                                child: Text('Delete empty group'),
                              ),
                          ],
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.85),
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
                  AppSpacing.xs,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: _GroupEvidenceColumn(
                  node: widget.node,
                  groupColor: _groupColor,
                  organizeMode: widget.organizeMode,
                  onEvidenceTap: widget.onEvidenceTap,
                  onSupportingAction: widget.onSupportingAction,
                  group: widget.node.group,
                  highlightedEvidenceIds: widget.highlightedEvidenceIds,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupColorChip extends StatelessWidget {
  const _GroupColorChip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
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

class _GroupEvidenceColumn extends StatelessWidget {
  const _GroupEvidenceColumn({
    required this.node,
    required this.groupColor,
    required this.organizeMode,
    required this.onEvidenceTap,
    required this.group,
    this.onSupportingAction,
    this.highlightedEvidenceIds = const {},
  });

  final ConnectionGroupNode node;
  final Color groupColor;
  final bool organizeMode;
  final ConnectionEvidenceTap onEvidenceTap;
  final RelationshipGroup group;
  final ConnectionSupportingAction? onSupportingAction;
  final Set<String> highlightedEvidenceIds;

  @override
  Widget build(BuildContext context) {
    final capturedEntries = node.capturedEntries;
    final children = <Widget>[];

    for (var i = 0; i < capturedEntries.length; i++) {
      final entry = capturedEntries[i];
      final showConnector = i < capturedEntries.length - 1 ||
          node.standaloneSupporting.isNotEmpty;

      children.add(
        EvidenceReviewHalo(
          evidenceId: entry.captured.id,
          ensureVisible: true,
          child: _CapturedGroupRow(
          item: entry.captured,
          groupColor: groupColor,
          showConnector: showConnector,
          isHighlighted: highlightedEvidenceIds.contains(entry.captured.id),
          onTap: () => onEvidenceTap(entry.captured),
          ),
        ),
      );

      for (var j = 0; j < entry.supportingItems.length; j++) {
        final supporting = entry.supportingItems[j];
        children.add(
          EvidenceReviewHalo(
            evidenceId: supporting.id,
            child: _SupportingGroupRow(
            item: supporting,
            isLast: j == entry.supportingItems.length - 1 &&
                i == capturedEntries.length - 1 &&
                node.standaloneSupporting.isEmpty,
            isHighlighted: highlightedEvidenceIds.contains(supporting.id),
            organizeMode: organizeMode,
            onTap: () => onEvidenceTap(supporting),
            onAction: onSupportingAction == null
                ? null
                : (action) => onSupportingAction!(
                      item: supporting,
                      group: group,
                      action: action,
                    ),
            ),
          ),
        );
      }
    }

    for (var i = 0; i < node.standaloneSupporting.length; i++) {
      final supporting = node.standaloneSupporting[i];
      children.add(
        EvidenceReviewHalo(
          evidenceId: supporting.id,
          child: _SupportingGroupRow(
          item: supporting,
          isLast: i == node.standaloneSupporting.length - 1,
          isHighlighted: highlightedEvidenceIds.contains(supporting.id),
          organizeMode: organizeMode,
          onTap: () => onEvidenceTap(supporting),
          onAction: onSupportingAction == null
              ? null
              : (action) => onSupportingAction!(
                    item: supporting,
                    group: group,
                    action: action,
                  ),
          ),
        ),
      );
    }

    if (children.isEmpty) {
      return Text(
        'No evidence in this group.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _CapturedGroupRow extends StatelessWidget {
  const _CapturedGroupRow({
    required this.item,
    required this.groupColor,
    required this.showConnector,
    required this.onTap,
    this.isHighlighted = false,
  });

  final WorkspaceEvidenceItem item;
  final Color groupColor;
  final bool showConnector;
  final VoidCallback onTap;
  final bool isHighlighted;

  static const double _railWidth = 18;
  static const double _thumbnailSize = 40;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _railWidth,
            child: Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: groupColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: groupColor.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _EvidenceThumbnail(
            item: item,
            groupColor: groupColor,
            size: _thumbnailSize,
            isHighlighted: isHighlighted,
            onTap: onTap,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Text(
                TimelineEvidenceLabels.capturedLabel(item),
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportingGroupRow extends StatelessWidget {
  const _SupportingGroupRow({
    required this.item,
    required this.isLast,
    required this.organizeMode,
    required this.onTap,
    this.isHighlighted = false,
    this.onAction,
  });

  final WorkspaceEvidenceItem item;
  final bool isLast;
  final bool organizeMode;
  final VoidCallback onTap;
  final bool isHighlighted;
  final void Function(ConnectionSupportingActionType action)? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isHighlighted
          ? AppColors.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            top: AppSpacing.xxs,
            bottom: AppSpacing.xxs,
            right: AppSpacing.xxs,
          ),
          child: Row(
            children: [
              Text(
                isLast ? '└── ' : '├── ',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
              Expanded(
                child: Text(
                  TimelineEvidenceLabels.supportingLabel(item),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              if (organizeMode && onAction != null)
                PopupMenuButton<ConnectionSupportingActionType>(
                  tooltip: 'Supporting evidence actions',
                  padding: EdgeInsets.zero,
                  onSelected: onAction,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: ConnectionSupportingActionType.moveToGroup,
                      child: Text('Move to group'),
                    ),
                    PopupMenuItem(
                      value: ConnectionSupportingActionType.removeFromGroup,
                      child: Text('Remove from group'),
                    ),
                  ],
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidenceThumbnail extends StatelessWidget {
  const _EvidenceThumbnail({
    required this.item,
    required this.groupColor,
    required this.size,
    required this.onTap,
    this.isHighlighted = false,
  });

  final WorkspaceEvidenceItem item;
  final Color groupColor;
  final double size;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(
          color: isHighlighted
              ? AppColors.primary.withValues(alpha: 0.65)
              : groupColor.withValues(alpha: 0.35),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.xs - 1),
        child: SizedBox(
          width: size,
          height: size,
          child: FittedBox(
            fit: BoxFit.cover,
            child: LivingEvidencePreview(
              item: item,
              uniformThumbnailSize: true,
              suppressBorder: true,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}
