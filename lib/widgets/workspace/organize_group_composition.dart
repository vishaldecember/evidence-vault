import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_accessibility.dart';
import '../../constants/app_spacing.dart';
import '../../domain/collection/evidence_collection.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/organize_visuals.dart';
import '../investigation/investigation_evidence_mark.dart';

/// Drag payload for a chronology clone. Never the original evidence record.
class OrganizeGroupCloneDrag {
  const OrganizeGroupCloneDrag(this.evidenceId);

  final String evidenceId;
}

/// Right-side translucent composition space. Membership is evidence IDs only.
///
/// Height is content-driven up to [maxHeightFor], then the interior scrolls.
class OrganizeGroupCompositionModal extends StatelessWidget {
  const OrganizeGroupCompositionModal({
    super.key,
    required this.members,
    required this.evidence,
    required this.nameController,
    required this.dropArmed,
    required this.wobblingIds,
    required this.onDismiss,
    required this.onAcceptClone,
    required this.onRemoveClone,
    required this.onArmCloneWobble,
    required this.onSettleClones,
    required this.onDropArmed,
    required this.onNameSubmitted,
    this.savedGroups = const [],
    this.onOpenSavedGroup,
  });

  final List<String> members;
  final List<WorkspaceEvidenceItem> evidence;
  final TextEditingController nameController;
  final bool dropArmed;
  final Set<String> wobblingIds;
  final VoidCallback onDismiss;
  final ValueChanged<String> onAcceptClone;
  final ValueChanged<String> onRemoveClone;
  final ValueChanged<String> onArmCloneWobble;
  final VoidCallback onSettleClones;
  final ValueChanged<bool> onDropArmed;
  final VoidCallback onNameSubmitted;
  final List<EvidenceCollection> savedGroups;
  final ValueChanged<EvidenceCollection>? onOpenSavedGroup;

  static const double width = 168;
  static const double cloneExtent = 52;
  static const int minMembers = 2;
  static const String namePlaceholder = 'Name this group';
  static const String dropHint = 'Drop moments here.';
  static const String minMembersMessage =
      'At least 2 moments are required to form a group.';

  static const Key modalKey = Key('organize_group_composition');
  static const Key dropKey = Key('organize_group_composition_drop');
  static const Key closeKey = Key('organize_group_composition_close');
  static const Key nameFieldKey = Key('organize_group_composition_name');
  static const Key minMessageKey = Key('organize_group_min_message');
  static const Key savedListKey = Key('organize_group_workspace_list');
  static const Key savedScrollKey = Key('organize_group_workspace_scroll');
  static const Key titleBoxKey = Key('organize_group_title_box');
  static const Key dropZoneKey = Key('organize_group_drop_zone');

  static Key cloneKey(String evidenceId) =>
      Key('organize_group_clone_$evidenceId');
  static Key cloneDiscardKey(String evidenceId) =>
      Key('organize_group_clone_discard_$evidenceId');
  static Key savedGroupKey(String collectionId) =>
      Key('organize_group_workspace_$collectionId');

  static double maxWidthFor(Size size) =>
      (size.width * 0.44).clamp(156.0, 196.0);

  static double maxHeightFor(Size size, double viewInsetBottom) {
    final usable = (size.height - viewInsetBottom).clamp(240.0, 1200.0);
    return (usable * 0.36).clamp(fourCloneMinHeight, 320.0);
  }

  /// Header + 2×2 clone workspace + name field. Not a full-height sheet.
  static const double fourCloneMinHeight = 248;
  static const double dropZoneMinHeight = 112;

  List<EvidenceCollection> get _uniqueSavedGroups {
    final seen = <String>{};
    return [
      for (final group in savedGroups)
        if (seen.add(group.id)) group,
    ];
  }

  WorkspaceEvidenceItem? _itemFor(String id) {
    for (final item in evidence) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxWidth = maxWidthFor(media.size);
    final maxHeight = maxHeightFor(media.size, media.viewInsets.bottom);
    final groups = _uniqueSavedGroups;
    final empty = members.isEmpty;

    return DragTarget<OrganizeGroupCloneDrag>(
      key: dropKey,
      onWillAcceptWithDetails: (details) {
        onDropArmed(true);
        return !members.contains(details.data.evidenceId);
      },
      onLeave: (_) => onDropArmed(false),
      onAcceptWithDetails: (details) {
        onDropArmed(false);
        onAcceptClone(details.data.evidenceId);
      },
      builder: (context, candidate, rejected) {
        final armed = dropArmed || candidate.isNotEmpty;
        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: width,
            maxWidth: maxWidth,
            minHeight: fourCloneMinHeight,
            maxHeight: maxHeight,
          ),
          child: DecoratedBox(
            key: modalKey,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: armed
                    ? AppColors.onCanvas.withValues(alpha: 0.55)
                    : const Color(0x66A8C0D4),
                width: armed ? 1.6 : 0.9,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: ColoredBox(
                  color: armed
                      ? const Color(0x66152632)
                      : const Color(0x52101822),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: onSettleClones,
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        key: savedScrollKey,
                        primary: false,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Group',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.onCanvas,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    key: closeKey,
                                    onTap: onDismiss,
                                    behavior: HitTestBehavior.opaque,
                                    child: const SizedBox(
                                      width: AppAccessibility.minTouchTarget,
                                      height: AppAccessibility.minTouchTarget,
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: AppColors.onCanvas,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              _GroupTitleBox(
                                controller: nameController,
                                onSubmitted: onNameSubmitted,
                              ),
                              const SizedBox(height: 8),
                              _GroupDropZone(
                                empty: empty,
                                members: members,
                                itemFor: _itemFor,
                                wobblingIds: wobblingIds,
                                onArmCloneWobble: onArmCloneWobble,
                                onRemoveClone: onRemoveClone,
                              ),
                              if (groups.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 6,
                                  ),
                                  child: Text(
                                    'Groups',
                                    style: AppTextStyles.caption.copyWith(
                                      color: OrganizeVisuals.meta,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                KeyedSubtree(
                                  key: savedListKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final group in groups)
                                        _SavedGroupTile(
                                          group: group,
                                          onTap: onOpenSavedGroup == null
                                              ? null
                                              : () => onOpenSavedGroup!(group),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GroupTitleBox extends StatelessWidget {
  const _GroupTitleBox({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: OrganizeGroupCompositionModal.titleBoxKey,
      decoration: BoxDecoration(
        color: const Color(0x33101822),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xE6FFFFFF), width: 1.15),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: TextField(
          key: OrganizeGroupCompositionModal.nameFieldKey,
          controller: controller,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.onCanvas,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: AppColors.onCanvas,
          onSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            isDense: true,
            hintText: OrganizeGroupCompositionModal.namePlaceholder,
            hintStyle: AppTextStyles.caption.copyWith(
              color: OrganizeVisuals.meta,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    );
  }
}

class _GroupDropZone extends StatelessWidget {
  const _GroupDropZone({
    required this.empty,
    required this.members,
    required this.itemFor,
    required this.wobblingIds,
    required this.onArmCloneWobble,
    required this.onRemoveClone,
  });

  final bool empty;
  final List<String> members;
  final WorkspaceEvidenceItem? Function(String id) itemFor;
  final Set<String> wobblingIds;
  final ValueChanged<String> onArmCloneWobble;
  final ValueChanged<String> onRemoveClone;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: OrganizeGroupCompositionModal.dropZoneKey,
      constraints: const BoxConstraints(
        minHeight: OrganizeGroupCompositionModal.dropZoneMinHeight,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x22101822),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xE6FFFFFF), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          child: empty
              ? Center(
                  child: Text(
                    OrganizeGroupCompositionModal.dropHint,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: OrganizeVisuals.meta,
                      height: 1.35,
                    ),
                  ),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                    for (final id in members)
                      _GroupMomentClone(
                        item: itemFor(id),
                        evidenceId: id,
                        wobbling: wobblingIds.contains(id),
                        onArmWobble: () => onArmCloneWobble(id),
                        onRemove: () => onRemoveClone(id),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SavedGroupTile extends StatelessWidget {
  const _SavedGroupTile({required this.group, this.onTap});

  final EvidenceCollection group;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        key: OrganizeGroupCompositionModal.savedGroupKey(group.id),
        color: const Color(0x14A8C0D4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          side: const BorderSide(color: Color(0x33A8C0D4), width: 0.6),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              group.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onCanvas,
                fontWeight: group.systemGenerated
                    ? FontWeight.w600
                    : FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupMomentClone extends StatelessWidget {
  const _GroupMomentClone({
    required this.item,
    required this.evidenceId,
    required this.wobbling,
    required this.onArmWobble,
    required this.onRemove,
  });

  final WorkspaceEvidenceItem? item;
  final String evidenceId;
  final bool wobbling;
  final VoidCallback onArmWobble;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      onLongPress: onArmWobble,
      child: SizedBox(
        key: OrganizeGroupCompositionModal.cloneKey(evidenceId),
        width: OrganizeGroupCompositionModal.cloneExtent,
        height: OrganizeGroupCompositionModal.cloneExtent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 8,
              top: 8,
              child: InvestigationNodeWobble(
                active: wobbling,
                maxAngle: 0.032,
                child: InvestigationEvidenceMark(
                  kind: item?.kind,
                  color: const Color(0xFFE8F1F8),
                  size: 34,
                ),
              ),
            ),
            if (wobbling)
              Positioned(
                left: 0,
                top: 0,
                child: _CloneDiscardButton(
                  evidenceId: evidenceId,
                  onPressed: onRemove,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CloneDiscardButton extends StatelessWidget {
  const _CloneDiscardButton({
    required this.evidenceId,
    required this.onPressed,
  });

  final String evidenceId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Remove this moment from the group',
      hint: 'Does not delete captured evidence',
      child: GestureDetector(
        key: OrganizeGroupCompositionModal.cloneDiscardKey(evidenceId),
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            shape: BoxShape.circle,
            border: Border.all(
              color: OrganizeVisuals.meta.withValues(alpha: 0.55),
            ),
          ),
          child: const SizedBox(
            width: 22,
            height: 22,
            child: Icon(Icons.remove, size: 14, color: AppColors.navy),
          ),
        ),
      ),
    );
  }
}

/// Chronology clone feedback — original tile stays; this follows the finger.
class OrganizeGroupCloneFeedback extends StatelessWidget {
  const OrganizeGroupCloneFeedback({super.key, required this.item});

  final WorkspaceEvidenceItem item;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.92,
      child: InvestigationNodeWobble(
        active: true,
        child: InvestigationEvidenceMark(
          kind: item.kind,
          color: const Color(0xFFE8F1F8),
          size: 36,
        ),
      ),
    );
  }
}
