import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_accessibility.dart';
import '../../constants/app_spacing.dart';
import '../../domain/collection/evidence_collection.dart';
import '../../domain/groups/group_intelligence.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/groups/group_intelligence_engine.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/organize_visuals.dart';
import 'journey_evidence_thumbnail.dart';
import 'organize_suggestion_rail.dart';

/// System intelligence lenses. Distinct from user-created custom groups.
enum OrganizeGroupCategory {
  personParticipant,
  location,
  relationship,
  pattern;

  String get label => switch (this) {
    OrganizeGroupCategory.personParticipant => 'People / Participants',
    OrganizeGroupCategory.location => 'Locations',
    OrganizeGroupCategory.relationship => 'Relationships',
    OrganizeGroupCategory.pattern => 'Patterns',
  };

  IconData get icon => switch (this) {
    OrganizeGroupCategory.personParticipant => Icons.people_outline_rounded,
    OrganizeGroupCategory.location => Icons.place_outlined,
    OrganizeGroupCategory.relationship => Icons.hub_outlined,
    OrganizeGroupCategory.pattern => Icons.auto_awesome_outlined,
  };

  Key get key => Key('organize_group_category_$name');

  static OrganizeGroupCategory? fromName(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    for (final value in values) {
      if (value.name == trimmed) {
        return value;
      }
    }
    return null;
  }
}

/// Translucent intelligence layer over Organize.
///
/// Derived from evidence/context relationships. Does not move chronology.
class OrganizeGroupsModal extends StatefulWidget {
  const OrganizeGroupsModal({
    super.key,
    required this.onDismiss,
    this.initialLens,
    this.collections = const [],
    this.evidence = const [],
    this.onUpsertGroup,
    this.onSetMembership,
    this.onCreateCustomGroup,
    this.onOpenCustomGroup,
    this.onRenamePerson,
    this.onOpenEvidence,
    this.onStartTransfer,
  });

  final VoidCallback onDismiss;
  final OrganizeGroupCategory? initialLens;
  final List<EvidenceCollection> collections;
  final List<WorkspaceEvidenceItem> evidence;
  final EvidenceCollection? Function({
    required OrganizeGroupCategory category,
    required String name,
    String? collectionId,
  })?
  onUpsertGroup;
  final void Function({
    required String collectionId,
    required String evidenceId,
    required bool associated,
  })?
  onSetMembership;
  final EvidenceCollection? Function({
    required String name,
    List<String> evidenceIds,
  })?
  onCreateCustomGroup;
  final ValueChanged<EvidenceCollection>? onOpenCustomGroup;
  final void Function(String participantId, String displayName)? onRenamePerson;
  final ValueChanged<WorkspaceEvidenceItem>? onOpenEvidence;
  final VoidCallback? onStartTransfer;

  static const Key modalKey = Key('organize_groups_modal');
  static const Key scrimKey = Key('organize_groups_modal_scrim');
  static const Key panelKey = Key('organize_groups_modal_panel');
  static const Key nameFieldKey = Key('organize_group_name_field');
  static const Key customGroupBarKey = Key('organize_custom_group_bar');
  static const Key matrixKey = Key('organize_groups_matrix');
  static const Key transferBarKey = Key('organize_groups_transfer_bar');
  static const String plusLabel = 'Groups +';
  static const String transferLabel = '+ Transfer';

  static Key entityKey(String collectionId) =>
      Key('organize_group_entity_$collectionId');

  static Key evidenceKey(String evidenceId) =>
      Key('organize_group_evidence_$evidenceId');

  static Key associatedKey(String evidenceId) =>
      Key('organize_group_associated_$evidenceId');

  static Key personKey(String participantId) =>
      Key('organize_group_person_$participantId');

  static Key lensKey(OrganizeGroupCategory category) =>
      Key('organize_group_lens_${category.name}');

  @override
  State<OrganizeGroupsModal> createState() => _OrganizeGroupsModalState();
}

class _OrganizeGroupsModalState extends State<OrganizeGroupsModal> {
  OrganizeGroupCategory? _lens;
  bool _composingCustom = false;
  String? _editingPersonId;
  late final TextEditingController _nameController;
  final Set<String> _customEvidenceIds = {};

  @override
  void initState() {
    super.initState();
    _lens = widget.initialLens;
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  GroupIntelligenceSnapshot get _intelligence {
    return GroupIntelligenceEngine.derive(
      evidence: widget.evidence,
      collections: widget.collections,
    );
  }

  void _openLens(OrganizeGroupCategory category) {
    setState(() {
      _lens = category;
      _composingCustom = false;
      _editingPersonId = null;
    });
  }

  void _backToMatrix() {
    setState(() {
      _lens = null;
      _composingCustom = false;
      _editingPersonId = null;
      _nameController.clear();
      _customEvidenceIds.clear();
    });
  }

  void _openCustomComposer() {
    setState(() {
      _lens = null;
      _composingCustom = true;
      _editingPersonId = null;
      _nameController.clear();
      _customEvidenceIds.clear();
    });
  }

  void _saveCustomGroup() {
    final create = widget.onCreateCustomGroup;
    final name = _nameController.text.trim();
    if (create == null || name.isEmpty) {
      return;
    }
    create(name: name, evidenceIds: _customEvidenceIds.toList());
    _backToMatrix();
  }

  void _openMoment(String evidenceId) {
    for (final item in widget.evidence) {
      if (item.id == evidenceId) {
        widget.onOpenEvidence?.call(item);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: OrganizeGroupsModal.scrimKey,
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: ColoredBox(
                color: const Color(0xFF0E1A24).withValues(alpha: 0.10),
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.screenHorizontal,
          right: OrganizeSuggestionRail.width,
          top: 56,
          bottom: 88 + media.viewInsets.bottom,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.sheet,
            curve: AppMotion.enter,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * -22),
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTap: () {},
              child: _GroupsGlassPanel(
                lens: _lens,
                composingCustom: _composingCustom,
                intelligence: _intelligence,
                evidence: widget.evidence,
                nameController: _nameController,
                customEvidenceIds: _customEvidenceIds,
                editingPersonId: _editingPersonId,
                canEditCustom: widget.onCreateCustomGroup != null,
                onOpenLens: _openLens,
                onBack: _backToMatrix,
                onOpenCustom: _openCustomComposer,
                onSaveCustom: _saveCustomGroup,
                onToggleCustomEvidence: (id) {
                  setState(() {
                    if (!_customEvidenceIds.add(id)) {
                      _customEvidenceIds.remove(id);
                    }
                  });
                },
                onRenamePerson: widget.onRenamePerson,
                onStartRename: (id, name) {
                  setState(() {
                    _editingPersonId = id;
                    _nameController.text = name;
                  });
                },
                onCommitRename: () {
                  final id = _editingPersonId;
                  final name = _nameController.text.trim();
                  if (id != null && name.isNotEmpty) {
                    widget.onRenamePerson?.call(id, name);
                  }
                  setState(() {
                    _editingPersonId = null;
                    _nameController.clear();
                  });
                },
                onOpenMoment: _openMoment,
                onOpenCustomGroup: widget.onOpenCustomGroup,
                onStartTransfer: widget.onStartTransfer,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupsGlassPanel extends StatelessWidget {
  const _GroupsGlassPanel({
    required this.lens,
    required this.composingCustom,
    required this.intelligence,
    required this.evidence,
    required this.nameController,
    required this.customEvidenceIds,
    required this.editingPersonId,
    required this.canEditCustom,
    required this.onOpenLens,
    required this.onBack,
    required this.onOpenCustom,
    required this.onSaveCustom,
    required this.onToggleCustomEvidence,
    required this.onRenamePerson,
    required this.onStartRename,
    required this.onCommitRename,
    required this.onOpenMoment,
    this.onOpenCustomGroup,
    this.onStartTransfer,
  });

  final OrganizeGroupCategory? lens;
  final bool composingCustom;
  final GroupIntelligenceSnapshot intelligence;
  final List<WorkspaceEvidenceItem> evidence;
  final TextEditingController nameController;
  final Set<String> customEvidenceIds;
  final String? editingPersonId;
  final bool canEditCustom;
  final ValueChanged<OrganizeGroupCategory> onOpenLens;
  final VoidCallback onBack;
  final VoidCallback onOpenCustom;
  final VoidCallback onSaveCustom;
  final ValueChanged<String> onToggleCustomEvidence;
  final void Function(String participantId, String displayName)? onRenamePerson;
  final void Function(String participantId, String name) onStartRename;
  final VoidCallback onCommitRename;
  final ValueChanged<String> onOpenMoment;
  final ValueChanged<EvidenceCollection>? onOpenCustomGroup;
  final VoidCallback? onStartTransfer;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: OrganizeGroupsModal.modalKey,
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            key: OrganizeGroupsModal.panelKey,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.md),
              border: Border.all(color: const Color(0x33A8C0D4), width: 0.6),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const IgnorePointer(
                  child: CustomPaint(
                    painter: OrganizeGroupsModalPainter(),
                    child: SizedBox.expand(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: composingCustom
                      ? _CustomGroupComposer(
                          nameController: nameController,
                          evidence: evidence,
                          selectedIds: customEvidenceIds,
                          onBack: onBack,
                          onSave: onSaveCustom,
                          onToggle: onToggleCustomEvidence,
                        )
                      : lens == null
                      ? _MatrixHome(
                          intelligence: intelligence,
                          onOpenLens: onOpenLens,
                          onStartTransfer: onStartTransfer,
                        )
                      : _LensDetail(
                          lens: lens!,
                          intelligence: intelligence,
                          evidence: evidence,
                          editingPersonId: editingPersonId,
                          nameController: nameController,
                          onBack: onBack,
                          onRenamePerson: onRenamePerson,
                          onStartRename: onStartRename,
                          onCommitRename: onCommitRename,
                          onOpenMoment: onOpenMoment,
                          onOpenCustomGroup: onOpenCustomGroup,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatrixHome extends StatelessWidget {
  const _MatrixHome({
    required this.intelligence,
    required this.onOpenLens,
    this.onStartTransfer,
  });

  final GroupIntelligenceSnapshot intelligence;
  final ValueChanged<OrganizeGroupCategory> onOpenLens;
  final VoidCallback? onStartTransfer;

  int _count(OrganizeGroupCategory category) => switch (category) {
    OrganizeGroupCategory.personParticipant => intelligence.people.length,
    OrganizeGroupCategory.location => intelligence.locations.length,
    OrganizeGroupCategory.relationship => intelligence.relationships.length,
    OrganizeGroupCategory.pattern => intelligence.patterns.length,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            key: OrganizeGroupsModal.matrixKey,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _LensCard(
                        category: OrganizeGroupCategory.personParticipant,
                        count: _count(OrganizeGroupCategory.personParticipant),
                        onTap: () =>
                            onOpenLens(OrganizeGroupCategory.personParticipant),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _LensCard(
                        category: OrganizeGroupCategory.location,
                        count: _count(OrganizeGroupCategory.location),
                        onTap: () => onOpenLens(OrganizeGroupCategory.location),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _LensCard(
                        category: OrganizeGroupCategory.relationship,
                        count: _count(OrganizeGroupCategory.relationship),
                        onTap: () =>
                            onOpenLens(OrganizeGroupCategory.relationship),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _LensCard(
                        category: OrganizeGroupCategory.pattern,
                        count: _count(OrganizeGroupCategory.pattern),
                        onTap: () => onOpenLens(OrganizeGroupCategory.pattern),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (onStartTransfer != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _TransferBar(onTap: onStartTransfer!),
        ],
      ],
    );
  }
}

class _TransferBar extends StatelessWidget {
  const _TransferBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: OrganizeGroupsModal.transferBarKey,
      color: const Color(0x33A8C0D4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        side: const BorderSide(color: Color(0x44A8C0D4), width: 0.6),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppAccessibility.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Center(
              child: Text(
                OrganizeGroupsModal.transferLabel,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.onCanvas,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LensCard extends StatelessWidget {
  const _LensCard({
    required this.category,
    required this.count,
    required this.onTap,
  });

  final OrganizeGroupCategory category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: OrganizeGroupsModal.lensKey(category),
      color: const Color(0x14A8C0D4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        side: const BorderSide(color: Color(0x33A8C0D4), width: 0.6),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(category.icon, color: AppColors.onCanvas, size: 22),
              const Spacer(),
              Text(
                category.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.onCanvas,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$count recognized',
                  style: AppTextStyles.caption.copyWith(
                    color: OrganizeVisuals.meta,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LensDetail extends StatelessWidget {
  const _LensDetail({
    required this.lens,
    required this.intelligence,
    required this.evidence,
    required this.editingPersonId,
    required this.nameController,
    required this.onBack,
    required this.onRenamePerson,
    required this.onStartRename,
    required this.onCommitRename,
    required this.onOpenMoment,
    this.onOpenCustomGroup,
  });

  final OrganizeGroupCategory lens;
  final GroupIntelligenceSnapshot intelligence;
  final List<WorkspaceEvidenceItem> evidence;
  final String? editingPersonId;
  final TextEditingController nameController;
  final VoidCallback onBack;
  final void Function(String participantId, String displayName)? onRenamePerson;
  final void Function(String participantId, String name) onStartRename;
  final VoidCallback onCommitRename;
  final ValueChanged<String> onOpenMoment;
  final ValueChanged<EvidenceCollection>? onOpenCustomGroup;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              key: const Key('organize_groups_back'),
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.onCanvas,
                ),
              ),
            ),
            Icon(lens.icon, color: AppColors.onCanvas, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lens.label,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.onCanvas,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ...switch (lens) {
                OrganizeGroupCategory.personParticipant => [
                  if (intelligence.people.isEmpty)
                    const _EmptyLensNote(
                      text: 'No people identified in preserved moments yet.',
                    )
                  else
                    for (final person in intelligence.people)
                      _PersonInsightTile(
                        person: person,
                        editing: editingPersonId == person.participantId,
                        nameController: nameController,
                        evidence: evidence,
                        canEdit:
                            onRenamePerson != null &&
                            !person.participantId.startsWith('collection:'),
                        onStartRename: () =>
                            onStartRename(person.participantId, person.name),
                        onCommitRename: onCommitRename,
                        onOpenMoment: onOpenMoment,
                      ),
                  if (intelligence.customGroups.isNotEmpty) ...[
                    if (intelligence.people.isNotEmpty)
                      const SizedBox(height: AppSpacing.md),
                    for (final group in intelligence.customGroups)
                      _NamedInsightTile(
                        key: OrganizeGroupsModal.entityKey(group.id),
                        title: group.name,
                        explanation: group.memberEvidenceIds.length == 1
                            ? 'Associated with 1 preserved moment.'
                            : 'Associated with ${group.memberEvidenceIds.length} preserved moments.',
                        source: group.systemGenerated
                            ? GroupObservationSource.representedInEvidence.label
                            : GroupObservationSource.userProvided.label,
                        evidenceIds: group.memberEvidenceIds,
                        evidence: evidence,
                        associationScope: group.id,
                        onOpenMoment: onOpenMoment,
                        onOpen: onOpenCustomGroup == null
                            ? null
                            : () => onOpenCustomGroup!(group),
                      ),
                  ],
                ],
                OrganizeGroupCategory.location => [
                  if (intelligence.locations.isEmpty)
                    const _EmptyLensNote(
                      text: 'No locations identified in preserved moments yet.',
                    )
                  else
                    for (final location in intelligence.locations)
                      _NamedInsightTile(
                        title: location.name,
                        explanation: location.explanation,
                        source: location.source.label,
                        evidenceIds: location.evidenceIds,
                        evidence: evidence,
                        associationScope: location.id,
                        onOpenMoment: onOpenMoment,
                      ),
                ],
                OrganizeGroupCategory.relationship => [
                  if (intelligence.relationships.isEmpty)
                    const _EmptyLensNote(
                      text:
                          'No relationships identified in preserved moments yet.',
                    )
                  else
                    for (final relationship in intelligence.relationships)
                      _NamedInsightTile(
                        title: relationship.title,
                        explanation: relationship.explanation,
                        source: relationship.source.label,
                        evidenceIds: relationship.evidenceIds,
                        evidence: evidence,
                        associationScope: relationship.id,
                        onOpenMoment: onOpenMoment,
                      ),
                ],
                OrganizeGroupCategory.pattern => [
                  if (intelligence.patterns.isEmpty)
                    const _EmptyLensNote(
                      text: 'No patterns identified in preserved moments yet.',
                    )
                  else
                    for (final pattern in intelligence.patterns)
                      _NamedInsightTile(
                        title: pattern.title,
                        explanation: pattern.explanation,
                        source: pattern.qualification,
                        evidenceIds: pattern.evidenceIds,
                        evidence: evidence,
                        associationScope: pattern.id,
                        onOpenMoment: onOpenMoment,
                      ),
                ],
              },
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonInsightTile extends StatelessWidget {
  const _PersonInsightTile({
    required this.person,
    required this.editing,
    required this.nameController,
    required this.evidence,
    required this.canEdit,
    required this.onStartRename,
    required this.onCommitRename,
    required this.onOpenMoment,
  });

  final GroupPersonInsight person;
  final bool editing;
  final TextEditingController nameController;
  final List<WorkspaceEvidenceItem> evidence;
  final bool canEdit;
  final VoidCallback onStartRename;
  final VoidCallback onCommitRename;
  final ValueChanged<String> onOpenMoment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: OrganizeGroupsModal.personKey(person.participantId),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x14A8C0D4),
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          border: Border.all(color: const Color(0x33A8C0D4), width: 0.6),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (editing)
                TextField(
                  key: OrganizeGroupsModal.nameFieldKey,
                  controller: nameController,
                  autofocus: true,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.onCanvas,
                    fontWeight: FontWeight.w700,
                  ),
                  cursorColor: AppColors.onCanvas,
                  onSubmitted: (_) => onCommitRename(),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                )
              else
                Text(
                  person.name,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.onCanvas,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                person.explanation,
                style: AppTextStyles.caption.copyWith(
                  color: OrganizeVisuals.meta,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                person.source.label,
                style: AppTextStyles.caption.copyWith(
                  color: OrganizeVisuals.meta.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (person.evidenceIds.isNotEmpty) {
                        onOpenMoment(person.evidenceIds.first);
                      }
                    },
                    child: Text(
                      'View moments',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.onCanvas,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (canEdit)
                    GestureDetector(
                      onTap: editing ? onCommitRename : onStartRename,
                      child: Text(
                        editing ? 'Save' : 'Edit',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.onCanvas,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _AssociatedEvidenceWrap(
                evidenceIds: person.evidenceIds,
                evidence: evidence,
                onOpenMoment: onOpenMoment,
                peopleTypography: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NamedInsightTile extends StatelessWidget {
  const _NamedInsightTile({
    super.key,
    required this.title,
    required this.explanation,
    required this.source,
    required this.evidenceIds,
    required this.evidence,
    required this.onOpenMoment,
    this.associationScope,
    this.onOpen,
  });

  final String title;
  final String explanation;
  final String source;
  final List<String> evidenceIds;
  final List<WorkspaceEvidenceItem> evidence;
  final ValueChanged<String> onOpenMoment;
  final String? associationScope;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: const Color(0x14A8C0D4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          side: const BorderSide(color: Color(0x33A8C0D4), width: 0.6),
        ),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.onCanvas,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  explanation,
                  style: AppTextStyles.caption.copyWith(
                    color: OrganizeVisuals.meta,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  source,
                  style: AppTextStyles.caption.copyWith(
                    color: OrganizeVisuals.meta.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _AssociatedEvidenceWrap(
                  evidenceIds: evidenceIds,
                  evidence: evidence,
                  onOpenMoment: onOpenMoment,
                  keyScope: associationScope ?? title,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyLensNote extends StatelessWidget {
  const _EmptyLensNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: OrganizeVisuals.meta,
          height: 1.4,
        ),
      ),
    );
  }
}

class _CustomGroupComposer extends StatelessWidget {
  const _CustomGroupComposer({
    required this.nameController,
    required this.evidence,
    required this.selectedIds,
    required this.onBack,
    required this.onSave,
    required this.onToggle,
  });

  final TextEditingController nameController;
  final List<WorkspaceEvidenceItem> evidence;
  final Set<String> selectedIds;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.onCanvas,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Custom group',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.onCanvas,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            GestureDetector(
              onTap: onSave,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppAccessibility.minTouchTarget,
                  minHeight: AppAccessibility.minTouchTarget,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Save',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.onCanvas,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(bottom: bottomInset),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: OrganizeGroupsModal.nameFieldKey,
                controller: nameController,
                autofocus: true,
                style: AppTextStyles.label.copyWith(color: AppColors.onCanvas),
                cursorColor: AppColors.onCanvas,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Name this group',
                  hintStyle: AppTextStyles.caption.copyWith(
                    color: OrganizeVisuals.meta,
                  ),
                  filled: true,
                  fillColor: const Color(0x14A8C0D4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                    borderSide: const BorderSide(
                      color: Color(0x33A8C0D4),
                      width: 0.6,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                    borderSide: const BorderSide(
                      color: Color(0x33A8C0D4),
                      width: 0.6,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                    borderSide: const BorderSide(color: Color(0x66A8C0D4)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'What this group represents is up to you. Associate moments below.',
                style: AppTextStyles.caption.copyWith(
                  color: OrganizeVisuals.meta,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final item in evidence)
                GestureDetector(
                  key: OrganizeGroupsModal.evidenceKey(item.id),
                  onTap: () => onToggle(item.id),
                  behavior: HitTestBehavior.opaque,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppAccessibility.minTouchTarget,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            selectedIds.contains(item.id)
                                ? Icons.check_box_outlined
                                : Icons.check_box_outline_blank,
                            size: 16,
                            color: selectedIds.contains(item.id)
                                ? AppColors.onCanvas
                                : OrganizeVisuals.meta,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.onCanvas,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssociatedEvidenceWrap extends StatelessWidget {
  const _AssociatedEvidenceWrap({
    required this.evidenceIds,
    required this.evidence,
    required this.onOpenMoment,
    this.keyScope,
    this.peopleTypography = false,
  });

  final List<String> evidenceIds;
  final List<WorkspaceEvidenceItem> evidence;
  final ValueChanged<String> onOpenMoment;
  final String? keyScope;
  final bool peopleTypography;

  WorkspaceEvidenceItem? _itemFor(String id) {
    for (final item in evidence) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  String _titleFor(String id) {
    return _itemFor(id)?.title ?? id;
  }

  Key _chipKey(String id) {
    final scope = keyScope;
    if (scope == null || scope.isEmpty) {
      return OrganizeGroupsModal.associatedKey(id);
    }
    return Key('organize_group_mirror_${scope}_$id');
  }

  @override
  Widget build(BuildContext context) {
    if (evidenceIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final id in evidenceIds)
          _AssociatedEvidenceChip(
            key: _chipKey(id),
            item: _itemFor(id),
            fallbackTitle: _titleFor(id),
            onTap: () => onOpenMoment(id),
            peopleTypography: peopleTypography,
          ),
      ],
    );
  }
}

class _AssociatedEvidenceChip extends StatelessWidget {
  const _AssociatedEvidenceChip({
    super.key,
    required this.item,
    required this.fallbackTitle,
    required this.onTap,
    this.peopleTypography = false,
  });

  final WorkspaceEvidenceItem? item;
  final String fallbackTitle;
  final VoidCallback onTap;
  final bool peopleTypography;

  static const Color _peopleInk = Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
    final resolved = item;
    if (resolved != null) {
      return Semantics(
        button: true,
        label: resolved.title,
        child: JourneyEvidenceThumbnail(
          item: resolved,
          onTap: onTap,
          identifyingTextColor: peopleTypography ? _peopleInk : null,
        ),
      );
    }
    return Semantics(
      button: true,
      label: fallbackTitle,
      child: Material(
        color: const Color(0x14A8C0D4),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppAccessibility.minTouchTarget,
              minHeight: AppAccessibility.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  fallbackTitle,
                  style: AppTextStyles.caption.copyWith(
                    color: peopleTypography ? _peopleInk : OrganizeVisuals.meta,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cool steel-glass wash — classification layer, not the milky context canvas.
class OrganizeGroupsModalPainter extends CustomPainter {
  const OrganizeGroupsModalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99152632), Color(0x85101C28), Color(0x990C1822)],
        ).createShader(rect),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.55),
          radius: 1.05,
          colors: [
            const Color(0xFF7A96AE).withValues(alpha: 0.10),
            const Color(0xFF7A96AE).withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );

    canvas.save();
    canvas.translate(size.width * 0.72, size.height * 0.78);
    canvas.scale(1.0, 0.38);
    canvas.drawCircle(
      Offset.zero,
      size.width * 0.55,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFF4A6A82).withValues(alpha: 0.08),
                const Color(0xFF4A6A82).withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(center: Offset.zero, radius: size.width * 0.55),
            ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
