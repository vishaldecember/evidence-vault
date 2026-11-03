import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_accessibility.dart';
import '../../constants/app_spacing.dart';
import '../../domain/collection/evidence_collection.dart';
import '../../domain/incident/current_incident.dart';
import '../../domain/organize/organize_context_anchor.dart';
import '../../domain/organize/organize_floating_context_layout.dart';
import '../../domain/participant/evidence_person_relationship.dart';
import '../../domain/participant/participant_role.dart';
import '../../models/context_type.dart';
import '../../models/evidence_record_model.dart';
import '../../models/workspace_capture_mode.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/organize_visuals.dart';
import '../common/modern_art_material.dart';
import '../common/silver_lustre_text.dart';
import 'capture_action_button.dart';
import 'organize_chronology_canvas.dart';
import 'organize_group_composition.dart';
import 'organize_groups_modal.dart';
import 'organize_readiness_guide.dart';
import 'organize_suggestion_rail.dart';

/// Organize mode â€” structure the bound incident's evidence record.
///
/// Inspector remains the detail surface. This view never edits descriptions
/// or people; tapping a row opens the existing Evidence Inspector.
class OrganizeWorkspaceView extends StatefulWidget {
  const OrganizeWorkspaceView({
    super.key,
    required this.incident,
    required this.onEvidenceSelected,
    this.dismissedCollectionIds = const {},
    this.onCreateGroup,
    this.onAcceptSuggestion,
    this.onDismissSuggestion,
    this.onRestoreSuggestion,
    this.contextAnchors = const [],
    this.organizeCreatedIds = const {},
    this.onSetContextAnchor,
    this.onClearContextAnchor,
    this.onDiscardUnsnappedContext,
    this.onAddOrganizeContext,
    this.orderedCapturedEvidenceIds = const [],
    this.capturedAnchoredAtById = const {},
    this.onRemoveFromGroup,
    this.onUpsertInterpretiveGroup,
    this.onSetInterpretiveGroupMembership,
    this.onCreateCustomGroup,
    this.onCommitGroupComposition,
    this.onDeleteCustomGroup,
    this.onRenameGroupPerson,
    this.onGroupCompositionChanged,
  });

  final CurrentIncident incident;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;
  final Set<String> dismissedCollectionIds;
  final VoidCallback? onCreateGroup;
  final ValueChanged<String>? onAcceptSuggestion;
  final ValueChanged<String>? onDismissSuggestion;
  final ValueChanged<String>? onRestoreSuggestion;
  final List<OrganizeContextAnchor> contextAnchors;
  final Set<String> organizeCreatedIds;
  final void Function(String contextEvidenceId, String capturedEvidenceId)?
  onSetContextAnchor;

  /// Clears placement only â€” never deletes evidence or chronology.
  final ValueChanged<String>? onClearContextAnchor;

  /// Deletes one unsnapped Organize context. Never deletes captured evidence.
  final ValueChanged<String>? onDiscardUnsnappedContext;
  final ValueChanged<WorkspaceCaptureMode>? onAddOrganizeContext;
  final List<String> orderedCapturedEvidenceIds;

  /// [TimelineAnchor.anchoredAt] keyed by captured evidence id.
  final Map<String, DateTime> capturedAnchoredAtById;
  final void Function(String collectionId, String evidenceId)?
  onRemoveFromGroup;
  final EvidenceCollection? Function({
    required OrganizeGroupCategory category,
    required String name,
    String? collectionId,
  })?
  onUpsertInterpretiveGroup;
  final void Function({
    required String collectionId,
    required String evidenceId,
    required bool associated,
  })?
  onSetInterpretiveGroupMembership;
  final EvidenceCollection? Function({
    required String name,
    List<String> evidenceIds,
  })?
  onCreateCustomGroup;
  final EvidenceCollection? Function({
    required String name,
    required List<String> evidenceIds,
    String? collectionId,
  })?
  onCommitGroupComposition;
  final ValueChanged<String>? onDeleteCustomGroup;
  final void Function(String participantId, String displayName)?
  onRenameGroupPerson;
  final ValueChanged<bool>? onGroupCompositionChanged;

  static const Key viewKey = Key('organize_workspace_view');
  static const Key headerKey = Key('organize_incident_header');
  static const Key structureKey = Key('organize_evidence_structure');
  static const Key groupsKey = Key('organize_groups');
  static const Key groupsMatrixKey = Key('organize_groups_matrix_grid');

  static Key groupMatrixCardKey(String collectionId) =>
      Key('organize_group_matrix_$collectionId');
  static const Key groupsPlusKey = Key('organize_groups_plus');
  static const Key groupsBrowseKey = Key('organize_groups_browse');
  static const Key groupsPlusOverlayKey = Key('organize_groups_plus_overlay');
  static const Key groupsLayerKey = Key('organize_groups_layer');
  static const Key groupsExpandKey = Key('organize_groups_expand');
  static const Key groupsPeekActionKey = Key('organize_groups_peek_action');
  static const String groupsPlusLabel = OrganizeGroupsModal.plusLabel;
  static const double groupsPlusReserveWidth = 96;

  /// Visible strip above the toolbar when collapsed — title only.
  static const double groupsPeekVisible = 36;

  /// How far the solid toolbar overlaps the Groups card (collapsed peek only).
  static const double groupsToolbarOverlap = 20;

  /// Intentional gap between expanded Groups card and the toolbar.
  static const double groupsToolbarGap = 8;

  /// Expanded card height — fits the full 2×2 category matrix above the toolbar.
  static const double groupsExpandedBody = 292;

  static double get groupsPeekExtent =>
      groupsPeekVisible + groupsToolbarOverlap;
  static double get groupsExpandedExtent => groupsExpandedBody;
  static const double groupsHeaderExtent = 48;
  static const Key suggestionsKey = Key('organize_suggestions');
  static const Key suggestionSlotKey = Key('organize_suggestion_slot');
  static const Key addContextBarKey = Key('organize_add_context_bar');
  static const Key workspaceDismissKey = Key(
    'organize_group_workspace_dismiss',
  );

  static const String groupsTitle = 'Groups';
  static const String groupsCaption = 'Evidence grouped within this incident.';
  static const String suggestionsCaption =
      'Suggested grouping of evidence in this incident.';
  static const String addContextTitle = 'Add context';
  static const String addContextCaption =
      'Drag the context on the moments preserved';
  static const Key addContextInstructionWobbleKey = Key(
    'organize_add_context_instruction_wobble',
  );
  static const String removeFromGroupLabel = 'Remove from group';
  static const int minCreateGroupCount = 2;

  static Key rowKey(String evidenceId) =>
      Key('organize_evidence_row_$evidenceId');

  static Key removeFromGroupKey(String collectionId, String evidenceId) =>
      Key('organize_remove_from_group_${collectionId}_$evidenceId');

  @override
  State<OrganizeWorkspaceView> createState() => _OrganizeWorkspaceViewState();
}

class _OrganizeWorkspaceViewState extends State<OrganizeWorkspaceView> {
  final GlobalKey _railAnchorKey = GlobalKey();
  final GlobalKey<OrganizeChronologyCanvasState> _canvasKey =
      GlobalKey<OrganizeChronologyCanvasState>();
  final ScrollController _scrollController = ScrollController();
  final Map<String, Offset> _freeOffsets = {};
  final Set<String> _discardedContextIds = {};
  Offset? _lastDragGlobal;
  bool _lockContextDragScroll = false;
  String? _expandedClusterCapturedId;
  bool _groupsModalOpen = false;
  bool _groupsExpanded = false;
  OrganizeGroupCategory? _groupsInitialLens;
  bool _groupComposing = false;
  String? _editingGroupId;
  final List<String> _groupDraftIds = [];
  bool _groupDropArmed = false;
  final Set<String> _wobblingCloneIds = {};
  late final TextEditingController _groupNameController;
  String _groupBaselineName = '';
  List<String> _groupBaselineIds = const [];
  Timer? _trailFadeTimer;

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant OrganizeWorkspaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final captured = _expandedClusterCapturedId;
    if (captured != null && _contextsForCaptured(captured).length < 2) {
      _expandedClusterCapturedId = null;
    }
  }

  @override
  void dispose() {
    _trailFadeTimer?.cancel();
    if (_groupComposing) {
      widget.onGroupCompositionChanged?.call(false);
    }
    _groupNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  CurrentIncident get incident => widget.incident;

  List<WorkspaceEvidenceItem> get _ordered {
    return OrganizeChronologyCanvas.displayOrder(
      items: incident.journeyEvidence,
      orderedCapturedEvidenceIds: widget.orderedCapturedEvidenceIds,
      organizeCreatedIds: widget.organizeCreatedIds,
      incidentId: incident.id,
    );
  }

  List<WorkspaceEvidenceItem> get _unsnappedContexts {
    final snapped = {
      for (final anchor in widget.contextAnchors) anchor.contextEvidenceId,
    };
    return [
      for (final item in _ordered)
        if (!_discardedContextIds.contains(item.id) &&
            OrganizeChronologyCanvas.isContextSpineItem(
              item,
              organizeCreatedIds: widget.organizeCreatedIds,
            ) &&
            !snapped.contains(item.id))
          item,
    ];
  }

  List<WorkspaceEvidenceItem> get _floatingContexts => _unsnappedContexts;

  List<WorkspaceEvidenceItem> _contextsForCaptured(String capturedId) {
    final ids = {
      for (final anchor in widget.contextAnchors)
        if (anchor.capturedEvidenceId == capturedId) anchor.contextEvidenceId,
    };
    return [
      for (final item in _ordered)
        if (ids.contains(item.id)) item,
    ];
  }

  void _discardFloatingContext(String id) {
    setState(() {
      _discardedContextIds.add(id);
      _freeOffsets.remove(id);
    });
    widget.onDiscardUnsnappedContext?.call(id);
  }

  Offset _offsetForUnsnapped(String id, int index, double width) {
    return _freeOffsets[id] ??
        OrganizeFloatingContextLayout.offsetFor(
          index: index,
          canvasWidth: width,
        );
  }

  void _placeUnsnappedAt(String id, Offset? global) {
    if (global == null) {
      return;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return;
    }
    final local = box.globalToLocal(global);
    const top = 56.0;
    const bottom = 88.0;
    final left = AppSpacing.screenHorizontal;
    final right = OrganizeSuggestionRail.width;
    final maxX =
        box.size.width - left - right - OrganizeFloatingContextLayout.tileWidth;
    final maxY =
        box.size.height -
        top -
        bottom -
        OrganizeFloatingContextLayout.tileHeight;
    _freeOffsets[id] = Offset(
      (local.dx - left).clamp(0.0, maxX < 0 ? 0.0 : maxX),
      (local.dy - top).clamp(0.0, maxY < 0 ? 0.0 : maxY),
    );
  }

  void _maybeAutoScroll(Offset global) {
    if (!_scrollController.hasClients) {
      return;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return;
    }
    final local = box.globalToLocal(global);
    const edge = 56.0;
    final max = _scrollController.position.maxScrollExtent;
    if (local.dy > box.size.height - edge - 88) {
      _scrollController.jumpTo((_scrollController.offset + 14).clamp(0, max));
    } else if (local.dy < edge + 24) {
      _scrollController.jumpTo((_scrollController.offset - 14).clamp(0, max));
    }
  }

  void _fadeSoulTrail() {
    _trailFadeTimer?.cancel();
    _trailFadeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final empty = _canvasKey.currentState?.soulTrail.isEmpty ?? true;
      if (!mounted || empty) {
        timer.cancel();
        _trailFadeTimer = null;
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  bool get _composingGroup => _groupComposing;

  void _startGroupComposition({
    String? collectionId,
    List<String> memberIds = const [],
    String name = '',
  }) {
    setState(() {
      _groupsModalOpen = false;
      _expandedClusterCapturedId = null;
      _groupComposing = true;
      _editingGroupId = collectionId;
      _groupDraftIds
        ..clear()
        ..addAll(memberIds);
      _groupDropArmed = false;
      _wobblingCloneIds.clear();
      _groupNameController.text = name;
      _groupBaselineName = name;
      _groupBaselineIds = List<String>.of(memberIds);
    });
    widget.onGroupCompositionChanged?.call(true);
  }

  void _closeGroupComposition() {
    setState(() {
      _groupComposing = false;
      _editingGroupId = null;
      _groupDraftIds.clear();
      _groupDropArmed = false;
      _wobblingCloneIds.clear();
      _groupNameController.clear();
      _groupBaselineName = '';
      _groupBaselineIds = const [];
    });
    widget.onGroupCompositionChanged?.call(false);
  }

  void _exitGroupComposition({required bool saveIfReady}) {
    if (saveIfReady) {
      _finalizeGroupComposition();
    }
    _closeGroupComposition();
  }

  bool _draftUnchanged() {
    if (_editingGroupId == null) {
      return false;
    }
    final name = _groupNameController.text.trim();
    if (name != _groupBaselineName ||
        _groupDraftIds.length != _groupBaselineIds.length) {
      return false;
    }
    for (var i = 0; i < _groupDraftIds.length; i++) {
      if (_groupDraftIds[i] != _groupBaselineIds[i]) {
        return false;
      }
    }
    return true;
  }

  void _resetDraftAfterSave() {
    _editingGroupId = null;
    _groupDraftIds.clear();
    _groupDropArmed = false;
    _wobblingCloneIds.clear();
    _groupNameController.clear();
    _groupBaselineName = '';
    _groupBaselineIds = const [];
  }

  EvidenceCollection? _editingCollection() {
    final id = _editingGroupId;
    if (id == null) {
      return null;
    }
    for (final collection in incident.evidenceCollections) {
      if (collection.id == id) {
        return collection;
      }
    }
    return null;
  }

  bool _isUserCustomGroup(EvidenceCollection? collection) {
    return collection != null && !collection.systemGenerated;
  }

  void _persistCustomGroupDraft() {
    final editing = _editingCollection();
    if (_groupDraftIds.isEmpty) {
      final id = _editingGroupId;
      if (id != null && _isUserCustomGroup(editing)) {
        widget.onDeleteCustomGroup?.call(id);
      }
      return;
    }
    final commit = widget.onCommitGroupComposition;
    final name = _groupNameController.text.trim();
    if (commit == null) {
      return;
    }
    if (editing != null && !_isUserCustomGroup(editing)) {
      return;
    }
    if (name.isEmpty && editing == null) {
      return;
    }
    commit(
      name: name.isEmpty ? (editing?.name ?? '') : name,
      evidenceIds: List<String>.of(_groupDraftIds),
      collectionId: _editingGroupId,
    );
  }

  void _finalizeGroupComposition() {
    if (_draftUnchanged() && _groupDraftIds.isNotEmpty) {
      return;
    }
    _persistCustomGroupDraft();
    setState(_resetDraftAfterSave);
  }

  void _dismissGroupWorkspace() {
    final closeModal = _groupsModalOpen;
    final collapseCard = _groupsExpanded;
    if (closeModal || collapseCard) {
      setState(() {
        if (closeModal) {
          _groupsModalOpen = false;
        }
        if (collapseCard) {
          _groupsExpanded = false;
        }
      });
    }
    if (_groupComposing) {
      _exitGroupComposition(saveIfReady: true);
    }
  }

  void _acceptGroupClone(String evidenceId) {
    if (_groupDraftIds.contains(evidenceId)) {
      return;
    }
    setState(() {
      _groupDraftIds.add(evidenceId);
      _wobblingCloneIds.add(evidenceId);
    });
    if (_editingGroupId != null) {
      _persistCustomGroupDraft();
    }
  }

  void _removeGroupClone(String evidenceId) {
    if (!_groupDraftIds.contains(evidenceId)) {
      return;
    }
    final emptied = _groupDraftIds.length == 1;
    final deletingCustom = emptied && _isUserCustomGroup(_editingCollection());
    setState(() {
      _groupDraftIds.remove(evidenceId);
      _wobblingCloneIds.remove(evidenceId);
    });
    _persistCustomGroupDraft();
    if (deletingCustom) {
      _closeGroupComposition();
    }
  }

  void _armCloneWobble(String evidenceId) {
    if (!_groupDraftIds.contains(evidenceId) ||
        _wobblingCloneIds.contains(evidenceId)) {
      return;
    }
    setState(() {
      _wobblingCloneIds.add(evidenceId);
    });
  }

  void _settleGroupClones() {
    if (_wobblingCloneIds.isEmpty) {
      return;
    }
    setState(_wobblingCloneIds.clear);
  }

  List<EvidenceCollection> get _groups {
    final dismissed = widget.dismissedCollectionIds;
    final collections = [
      for (final collection in incident.evidenceCollections)
        if (!dismissed.contains(collection.id)) collection,
    ]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return collections;
  }

  List<EvidenceCollection> get _dismissedSuggestions {
    final collections = [
      for (final collection in incident.evidenceCollections)
        if (collection.pending &&
            widget.dismissedCollectionIds.contains(collection.id))
          collection,
    ]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return collections;
  }

  void _restore(EvidenceCollection collection, BuildContext chipContext) {
    if (widget.onRestoreSuggestion == null) {
      return;
    }
    OrganizeSuggestionRail.flyFromRail(
      fromContext: chipContext,
      toContext: context,
      onArrived: () => widget.onRestoreSuggestion!(collection.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _ordered;
    final dismissed = _dismissedSuggestions;

    return PopScope(
      canPop: !_composingGroup,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_composingGroup) {
          return;
        }
        _exitGroupComposition(saveIfReady: true);
      },
      child: LayoutBuilder(
        builder: (context, _) {
          return Stack(
            children: [
              GestureDetector(
                key: OrganizeWorkspaceView.workspaceDismissKey,
                behavior: HitTestBehavior.translucent,
                onTap: _groupComposing || _groupsModalOpen || _groupsExpanded
                    ? _dismissGroupWorkspace
                    : null,
                child: CustomScrollView(
                  key: OrganizeWorkspaceView.viewKey,
                  controller: _scrollController,
                  physics: _lockContextDragScroll
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenHorizontal,
                        AppSpacing.xxs,
                        OrganizeSuggestionRail.width,
                        AppSpacing.lg +
                            76 +
                            OrganizeWorkspaceView.groupsPeekVisible,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _IncidentIdentityHeader(
                            title: incident.displayTitle,
                            evidenceCount: ordered.length,
                          ),
                          const SizedBox(
                            key: OrganizeWorkspaceView.suggestionSlotKey,
                            height: 0,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _EvidenceStructureCard(
                            canvasKey: _canvasKey,
                            ordered: ordered,
                            allEvidence: incident.evidence,
                            onEvidenceSelected: widget.onEvidenceSelected,
                            anchors: widget.contextAnchors,
                            organizeCreatedIds: widget.organizeCreatedIds,
                            anchoredAtByEvidenceId:
                                widget.capturedAnchoredAtById,
                            onSetContextAnchor: widget.onSetContextAnchor,
                            onClearContextAnchor: widget.onClearContextAnchor,
                            onDiscardUnsnapped: _discardFloatingContext,
                            onExpandCluster: (capturedId) {
                              setState(() {
                                _expandedClusterCapturedId = capturedId;
                                _groupsModalOpen = false;
                              });
                            },
                            expandedClusterCapturedId:
                                _expandedClusterCapturedId,
                            onLockAncestorScroll: (lock) {
                              if (_lockContextDragScroll == lock) {
                                return;
                              }
                              setState(() {
                                _lockContextDragScroll = lock;
                              });
                            },
                            groupSelectionMode: _composingGroup,
                            groupMemberIds: _groupDraftIds,
                            onGroupCloneDragStarted: () {
                              setState(() {
                                _lockContextDragScroll = true;
                              });
                            },
                            onGroupCloneDragEnded: () {
                              setState(() {
                                _lockContextDragScroll = false;
                              });
                              _fadeSoulTrail();
                            },
                            onRemoveGroupClone: _removeGroupClone,
                            onWorkspaceDismiss: _groupComposing
                                ? _dismissGroupWorkspace
                                : null,
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                key: OrganizeWorkspaceView.groupsPlusOverlayKey,
                top: AppSpacing.xxs,
                right: OrganizeSuggestionRail.width,
                child: AbsorbPointer(
                  absorbing: _composingGroup,
                  child: _PinnedGroupsPlus(
                    onOpen: () {
                      setState(() {
                        _groupsModalOpen = true;
                        _groupsInitialLens = null;
                        _expandedClusterCapturedId = null;
                      });
                    },
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.screenHorizontal,
                right: OrganizeSuggestionRail.width,
                bottom: AppSpacing.sm,
                child: _OrganizeGroupsBottomStack(
                  expanded: _groupsExpanded,
                  composingGroup: _composingGroup,
                  groupsModalOpen: _groupsModalOpen,
                  onToggleExpanded: () {
                    setState(() {
                      _groupsExpanded = !_groupsExpanded;
                    });
                  },
                  onOpenCategory: (category) {
                    setState(() {
                      _groupsExpanded = true;
                      _groupsModalOpen = true;
                      _expandedClusterCapturedId = null;
                      _groupsInitialLens = category;
                    });
                  },
                  onAddOrganizeContext: widget.onAddOrganizeContext,
                  wobblingContextIds: {
                    for (final item in _unsnappedContexts) item.id,
                  },
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: AbsorbPointer(
                  absorbing: _composingGroup,
                  child: dismissed.isEmpty || widget.onRestoreSuggestion == null
                      ? IgnorePointer(
                          child: SizedBox(
                            key: _railAnchorKey,
                            width: OrganizeSuggestionRail.width,
                            height: 48,
                          ),
                        )
                      : KeyedSubtree(
                          key: _railAnchorKey,
                          child: OrganizeSuggestionRail(
                            collections: dismissed,
                            onRestore: _restore,
                          ),
                        ),
                ),
              ),
              if (_floatingContexts.isNotEmpty && !_composingGroup)
                Positioned(
                  left: AppSpacing.screenHorizontal,
                  right: OrganizeSuggestionRail.width,
                  top: 56,
                  bottom: 88,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : 280.0;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var i = 0; i < _floatingContexts.length; i++)
                            Positioned(
                              left:
                                  _offsetForUnsnapped(
                                    _floatingContexts[i].id,
                                    i,
                                    width,
                                  ).dx -
                                  OrganizeFloatingContextLayout
                                      .removeControlOutset,
                              top:
                                  _offsetForUnsnapped(
                                    _floatingContexts[i].id,
                                    i,
                                    width,
                                  ).dy -
                                  OrganizeFloatingContextLayout
                                      .removeControlOutset,
                              width:
                                  OrganizeFloatingContextLayout.tileWidth +
                                  OrganizeFloatingContextLayout
                                      .removeControlOutset,
                              height:
                                  OrganizeFloatingContextLayout.tileHeight +
                                  OrganizeFloatingContextLayout
                                      .removeControlOutset,
                              child: OrganizeUnsnappedContextObject(
                                item: _floatingContexts[i],
                                allEvidence: incident.evidence,
                                anchoredAtByEvidenceId:
                                    widget.capturedAnchoredAtById,
                                linked: false,
                                wobbling: true,
                                placementEnabled:
                                    widget.onSetContextAnchor != null,
                                confirming: false,
                                onEvidenceSelected: widget.onEvidenceSelected,
                                onContextPointerDown: (_) {},
                                onContextPointerMove: (global) {
                                  _canvasKey.currentState
                                      ?.handleOverlayDragUpdate(global);
                                  _maybeAutoScroll(global);
                                },
                                onContextPointerUp: () {},
                                onContextDragStarted: () {
                                  _canvasKey.currentState
                                      ?.handleOverlayDragStarted();
                                },
                                onContextDragUpdate: (global) {
                                  _lastDragGlobal = global;
                                  _canvasKey.currentState
                                      ?.handleOverlayDragUpdate(global);
                                  _maybeAutoScroll(global);
                                  setState(() {});
                                },
                                onContextDragEnd: (id) {
                                  final snapped =
                                      _canvasKey.currentState
                                          ?.handleOverlayDragEnd(id) ??
                                      false;
                                  if (snapped) {
                                    _freeOffsets.remove(id);
                                  } else {
                                    _placeUnsnappedAt(id, _lastDragGlobal);
                                  }
                                  setState(() {});
                                  _fadeSoulTrail();
                                },
                                onDiscardUnsnapped: _discardFloatingContext,
                              ),
                            ),
                          if (_canvasKey.currentState?.soulTrail.isNotEmpty ??
                              false)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: OrganizeSoulTrailLayer(
                                  dots: List.of(
                                    _canvasKey.currentState!.soulTrail,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              if (_expandedClusterCapturedId != null)
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: ColoredBox(
                        color: AppColors.navy.withValues(alpha: 0.18),
                        child: OrganizeContextClusterModal(
                          items: _contextsForCaptured(
                            _expandedClusterCapturedId!,
                          ),
                          capturedEvidenceId: _expandedClusterCapturedId!,
                          onEvidenceSelected: (item) {
                            setState(() {
                              _expandedClusterCapturedId = null;
                            });
                            widget.onEvidenceSelected(item);
                          },
                          onDismiss: () {
                            setState(() {
                              _expandedClusterCapturedId = null;
                            });
                          },
                          onUnlinkContext: (id, global) {
                            _placeUnsnappedAt(id, global);
                          },
                          onDiscardContext: _discardFloatingContext,
                          onContextDragStarted: () {
                            _canvasKey.currentState?.handleOverlayDragStarted();
                          },
                          onContextDragUpdate: (global) {
                            _lastDragGlobal = global;
                            _canvasKey.currentState?.handleOverlayDragUpdate(
                              global,
                            );
                          },
                          onContextDragEnd: (id) {
                            _canvasKey.currentState?.handleOverlayDragEnd(id);
                            _fadeSoulTrail();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              if (_groupComposing)
                Positioned(
                  right: 8,
                  top: 56,
                  child: OrganizeGroupCompositionModal(
                    members: _groupDraftIds,
                    evidence: incident.evidence,
                    nameController: _groupNameController,
                    dropArmed: _groupDropArmed,
                    wobblingIds: _wobblingCloneIds,
                    savedGroups: _groups,
                    onOpenSavedGroup: (collection) {
                      _startGroupComposition(
                        collectionId: collection.id,
                        memberIds: collection.memberEvidenceIds,
                        name: collection.name,
                      );
                    },
                    onDismiss: () => _exitGroupComposition(saveIfReady: true),
                    onAcceptClone: _acceptGroupClone,
                    onRemoveClone: _removeGroupClone,
                    onArmCloneWobble: _armCloneWobble,
                    onSettleClones: _settleGroupClones,
                    onDropArmed: (armed) {
                      if (_groupDropArmed == armed) {
                        return;
                      }
                      setState(() {
                        _groupDropArmed = armed;
                      });
                    },
                    onNameSubmitted: _finalizeGroupComposition,
                  ),
                ),
              if (_groupsModalOpen)
                Positioned.fill(
                  child: OrganizeGroupsModal(
                    initialLens: _groupsInitialLens,
                    collections: [
                      for (final collection in incident.evidenceCollections)
                        if (!widget.dismissedCollectionIds.contains(
                          collection.id,
                        ))
                          collection,
                    ],
                    evidence: incident.evidence,
                    onUpsertGroup: widget.onUpsertInterpretiveGroup,
                    onSetMembership: widget.onSetInterpretiveGroupMembership,
                    onCreateCustomGroup: widget.onCreateCustomGroup,
                    onOpenCustomGroup: (collection) {
                      _startGroupComposition(
                        collectionId: collection.id,
                        memberIds: collection.memberEvidenceIds,
                        name: collection.name,
                      );
                    },
                    onRenamePerson: widget.onRenameGroupPerson,
                    onOpenEvidence: widget.onEvidenceSelected,
                    onStartTransfer: _startGroupComposition,
                    onDismiss: () {
                      setState(() {
                        _groupsModalOpen = false;
                        _groupsInitialLens = null;
                      });
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _IncidentIdentityHeader extends StatelessWidget {
  const _IncidentIdentityHeader({
    required this.title,
    required this.evidenceCount,
  });

  final String title;
  final int evidenceCount;

  @override
  Widget build(BuildContext context) {
    final countLabel = evidenceCount == 1
        ? '1 preserved record'
        : '$evidenceCount preserved records';

    return Padding(
      key: OrganizeWorkspaceView.headerKey,
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: SilverLustreText(
                        title,
                        key: const Key('organize_incident_title'),
                        textAlign: TextAlign.start,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const OrganizeReadinessInfoButton(
                      iconColor: AppColors.onCanvas,
                    ),
                  ],
                ),
                Text(
                  countLabel,
                  key: const Key('organize_evidence_count'),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.onCanvasSecondary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: OrganizeWorkspaceView.groupsPlusReserveWidth),
        ],
      ),
    );
  }
}

class _OrganizeGroupsBottomStack extends StatelessWidget {
  const _OrganizeGroupsBottomStack({
    required this.expanded,
    required this.composingGroup,
    required this.groupsModalOpen,
    required this.onToggleExpanded,
    required this.onOpenCategory,
    required this.onAddOrganizeContext,
    required this.wobblingContextIds,
  });

  final bool expanded;
  final bool composingGroup;
  final bool groupsModalOpen;
  final VoidCallback onToggleExpanded;
  final ValueChanged<OrganizeGroupCategory> onOpenCategory;
  final ValueChanged<WorkspaceCaptureMode>? onAddOrganizeContext;
  final Set<String> wobblingContextIds;

  @override
  Widget build(BuildContext context) {
    final addContext = onAddOrganizeContext;
    final showToolbar =
        addContext != null && !groupsModalOpen && !composingGroup;
    final toolbar = showToolbar
        ? _OrganizeAddContextBar(
            onSelected: addContext,
            wobblingContextIds: wobblingContextIds,
          )
        : null;
    return Column(
      key: OrganizeWorkspaceView.groupsLayerKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        AbsorbPointer(
          absorbing: composingGroup,
          child: _GroupsCard(
            expanded: expanded,
            onToggleExpanded: onToggleExpanded,
            onOpenCategory: onOpenCategory,
          ),
        ),
        if (showToolbar)
          // Collapsed: tuck toolbar over the card for a deep "Groups" peek.
          // Expanded: keep the full matrix clear above the toolbar with a gap.
          expanded
              ? Padding(
                  padding: const EdgeInsets.only(
                    top: OrganizeWorkspaceView.groupsToolbarGap,
                  ),
                  child: toolbar!,
                )
              : Transform.translate(
                  offset: const Offset(
                    0,
                    -OrganizeWorkspaceView.groupsToolbarOverlap,
                  ),
                  child: toolbar!,
                ),
      ],
    );
  }
}

class _PinnedGroupsPlus extends StatelessWidget {
  const _PinnedGroupsPlus({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.xs),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.journeyTabOrganize.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(AppSpacing.xs),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: _GroupsPlusControl(onOpen: onOpen),
          ),
        ),
      ),
    );
  }
}

class _GroupsPlusControl extends StatelessWidget {
  const _GroupsPlusControl({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.caption.copyWith(
      color: AppColors.onCanvas,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.onCanvas,
      decorationThickness: 1.15,
      height: 1.2,
    );
    return Semantics(
      button: true,
      label: OrganizeWorkspaceView.groupsPlusLabel,
      hint: 'Open Groups',
      child: GestureDetector(
        key: OrganizeWorkspaceView.groupsPlusKey,
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppAccessibility.minTouchTarget,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KeyedSubtree(
                key: OrganizeWorkspaceView.groupsBrowseKey,
                child: Text('Groups', style: style),
              ),
              const SizedBox(width: 4),
              Text('+', style: style),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidenceStructureCard extends StatelessWidget {
  const _EvidenceStructureCard({
    this.canvasKey,
    required this.ordered,
    required this.allEvidence,
    required this.onEvidenceSelected,
    this.anchors = const [],
    this.organizeCreatedIds = const {},
    this.anchoredAtByEvidenceId = const {},
    this.onSetContextAnchor,
    this.onClearContextAnchor,
    this.onDiscardUnsnapped,
    this.onExpandCluster,
    this.expandedClusterCapturedId,
    this.onLockAncestorScroll,
    this.groupSelectionMode = false,
    this.groupMemberIds = const [],
    this.onGroupCloneDragStarted,
    this.onGroupCloneDragEnded,
    this.onRemoveGroupClone,
    this.onWorkspaceDismiss,
  });

  final GlobalKey<OrganizeChronologyCanvasState>? canvasKey;
  final List<WorkspaceEvidenceItem> ordered;
  final List<WorkspaceEvidenceItem> allEvidence;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;
  final List<OrganizeContextAnchor> anchors;
  final Set<String> organizeCreatedIds;
  final Map<String, DateTime> anchoredAtByEvidenceId;
  final void Function(String contextEvidenceId, String capturedEvidenceId)?
  onSetContextAnchor;
  final ValueChanged<String>? onClearContextAnchor;
  final ValueChanged<String>? onDiscardUnsnapped;
  final ValueChanged<String>? onExpandCluster;
  final String? expandedClusterCapturedId;
  final ValueChanged<bool>? onLockAncestorScroll;
  final bool groupSelectionMode;
  final List<String> groupMemberIds;
  final VoidCallback? onGroupCloneDragStarted;
  final VoidCallback? onGroupCloneDragEnded;
  final ValueChanged<String>? onRemoveGroupClone;
  final VoidCallback? onWorkspaceDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: OrganizeWorkspaceView.structureKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrganizeChronologyCanvas(
          key: canvasKey,
          ordered: ordered,
          allEvidence: allEvidence,
          onEvidenceSelected: onEvidenceSelected,
          anchors: anchors,
          organizeCreatedIds: organizeCreatedIds,
          anchoredAtByEvidenceId: anchoredAtByEvidenceId,
          onSetContextAnchor: onSetContextAnchor,
          onClearContextAnchor: onClearContextAnchor,
          onDiscardUnsnapped: onDiscardUnsnapped,
          onExpandCluster: onExpandCluster,
          expandedClusterCapturedId: expandedClusterCapturedId,
          detachUnsnappedOverlay: true,
          onLockAncestorScroll: onLockAncestorScroll,
          groupSelectionMode: groupSelectionMode,
          groupMemberIds: groupMemberIds,
          onGroupCloneDragStarted: onGroupCloneDragStarted,
          onGroupCloneDragEnded: onGroupCloneDragEnded,
          onRemoveGroupClone: onRemoveGroupClone,
          onWorkspaceDismiss: onWorkspaceDismiss,
        ),
      ],
    );
  }
}

class _GroupsCard extends StatelessWidget {
  const _GroupsCard({
    required this.expanded,
    required this.onToggleExpanded,
    required this.onOpenCategory,
  });

  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<OrganizeGroupCategory> onOpenCategory;

  static const _categories = <OrganizeGroupCategory>[
    OrganizeGroupCategory.personParticipant,
    OrganizeGroupCategory.location,
    OrganizeGroupCategory.relationship,
    OrganizeGroupCategory.pattern,
  ];

  static String _shortLabel(OrganizeGroupCategory category) =>
      switch (category) {
        OrganizeGroupCategory.personParticipant => 'Person / Participant',
        OrganizeGroupCategory.location => 'Location',
        OrganizeGroupCategory.relationship => 'Relationship',
        OrganizeGroupCategory.pattern => 'Pattern',
      };

  @override
  Widget build(BuildContext context) {
    final height = expanded
        ? OrganizeWorkspaceView.groupsExpandedExtent
        : OrganizeWorkspaceView.groupsPeekExtent;
    return AnimatedContainer(
      key: OrganizeWorkspaceView.groupsKey,
      duration: AppMotion.sheet,
      curve: AppMotion.enter,
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const GroupsAtmosphereSurface(),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.55),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              top: 0,
              bottom: expanded
                  ? AppSpacing.sm
                  : OrganizeWorkspaceView.groupsToolbarOverlap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    button: true,
                    label: expanded ? 'Collapse Groups' : 'Expand Groups',
                    child: GestureDetector(
                      key: OrganizeWorkspaceView.groupsPeekActionKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: onToggleExpanded,
                      child: SizedBox(
                        height: OrganizeWorkspaceView.groupsPeekVisible,
                        width: double.infinity,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            OrganizeWorkspaceView.groupsTitle,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              height: 1,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (expanded)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: _GroupsCategoryMatrix(
                          key: OrganizeWorkspaceView.groupsMatrixKey,
                          categories: _categories,
                          labelFor: _shortLabel,
                          onOpenCategory: onOpenCategory,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2×2 matrix that always fills its bounds — never clips under the toolbar.
class _GroupsCategoryMatrix extends StatelessWidget {
  const _GroupsCategoryMatrix({
    super.key,
    required this.categories,
    required this.labelFor,
    required this.onOpenCategory,
  });

  final List<OrganizeGroupCategory> categories;
  final String Function(OrganizeGroupCategory) labelFor;
  final ValueChanged<OrganizeGroupCategory> onOpenCategory;

  @override
  Widget build(BuildContext context) {
    assert(categories.length == 4);
    Widget tile(OrganizeGroupCategory category) => Expanded(
      child: _GroupCategoryTile(
        category: category,
        label: labelFor(category),
        onTap: () => onOpenCategory(category),
      ),
    );
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile(categories[0]),
              const SizedBox(width: 8),
              tile(categories[1]),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile(categories[2]),
              const SizedBox(width: 8),
              tile(categories[3]),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupCategoryTile extends StatelessWidget {
  const _GroupCategoryTile({
    required this.category,
    required this.label,
    required this.onTap,
  });

  final OrganizeGroupCategory category;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: OrganizeGroupsModal.lensKey(category),
      color: const Color(0xA6F8FBFD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        side: const BorderSide(color: Color(0x88A8C0D4), width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(category.icon, color: Colors.black87, size: 20),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Existing Inspector description / note body — never a second field.
String? organizeEvidenceDescription(
  WorkspaceEvidenceItem item,
  List<WorkspaceEvidenceItem> allEvidence,
) {
  if (item.kind == WorkspaceEvidenceKind.note) {
    final body = item.notePreview?.trim();
    if (body != null && body.isNotEmpty) {
      return body;
    }
  }

  final record = EvidenceRecordModel.fromWorkspace(
    evidence: item,
    allItems: allEvidence,
    relationships: const [],
  );
  for (final context in record.contextItems) {
    if (context.type != ContextType.note) {
      continue;
    }
    final text = context.displayTitle.trim();
    if (text.isNotEmpty) {
      return text;
    }
  }

  final preview = item.notePreview?.trim();
  if (preview != null && preview.isNotEmpty) {
    return preview;
  }
  return null;
}

/// Denormalized related-person line already persisted on the evidence.
String? organizeRelatedPersonLabel(WorkspaceEvidenceItem item) {
  final name = item.relatedPersonName?.trim();
  if (name == null || name.isEmpty) {
    return null;
  }
  final role = _relatedPersonRoleLabel(item.relatedPersonRole);
  if (role == null || role.isEmpty) {
    return name;
  }
  return '$name \u00B7 $role';
}

String? _relatedPersonRoleLabel(String? roleName) {
  if (roleName == null || roleName.isEmpty) {
    return null;
  }
  for (final relationship in EvidencePersonRelationship.values) {
    if (relationship.name == roleName) {
      return relationship.label;
    }
  }
  for (final role in ParticipantRole.values) {
    if (role.name == roleName) {
      return role.label;
    }
  }
  return roleName;
}

/// Structural parent link only â€” no causal language.
String? organizeLinkedLabel(
  WorkspaceEvidenceItem item,
  List<WorkspaceEvidenceItem> allEvidence,
) {
  final parentId = item.parentEvidenceId;
  if (parentId == null || parentId.isEmpty) {
    return null;
  }
  for (final other in allEvidence) {
    if (other.id == parentId) {
      return 'Linked with ${other.kind.label}';
    }
  }
  return null;
}

class _OrganizeAddContextBar extends StatelessWidget {
  const _OrganizeAddContextBar({
    required this.onSelected,
    this.wobblingContextIds = const {},
  });

  final ValueChanged<WorkspaceCaptureMode> onSelected;
  final Set<String> wobblingContextIds;

  static const Key barKey = OrganizeWorkspaceView.addContextBarKey;
  static const _modes = <WorkspaceCaptureMode>[
    WorkspaceCaptureMode.voice,
    WorkspaceCaptureMode.note,
    WorkspaceCaptureMode.file,
  ];

  @override
  Widget build(BuildContext context) {
    final awaiting = wobblingContextIds.isNotEmpty;
    final restartToken = (wobblingContextIds.toList()..sort()).join(',');
    return Semantics(
      container: true,
      label: OrganizeWorkspaceView.addContextTitle,
      child: ClipRRect(
        key: barKey,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Stack(
          children: [
            const Positioned.fill(child: ChromeAtmosphereSurface(solid: true)),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    OrganizeWorkspaceView.addContextTitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.15,
                      height: 1.2,
                    ),
                  ),
                  OrganizePlacementWobble(
                    key: OrganizeWorkspaceView.addContextInstructionWobbleKey,
                    active: awaiting,
                    restartToken: restartToken,
                    maxAngle: 0.038,
                    child: awaiting
                        ? Text(
                            OrganizeWorkspaceView.addContextCaption,
                            style: AppTextStyles.caption.copyWith(
                              color: OrganizeVisuals.contextInstruction,
                              fontSize: 12,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1,
                            ),
                          )
                        : Text(
                            OrganizeWorkspaceView.addContextCaption,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              height: 1.25,
                            ),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      for (var i = 0; i < _modes.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.xs),
                        CaptureActionButton(
                          mode: _modes[i],
                          isActive: false,
                          onTap: () => onSelected(_modes[i]),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
