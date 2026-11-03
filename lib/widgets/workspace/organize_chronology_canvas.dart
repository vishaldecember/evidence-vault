import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../constants/app_accessibility.dart';
import '../../constants/app_spacing.dart';
import '../../domain/organize/organize_context_anchor.dart';
import '../../domain/organize/organize_chronology_eligibility.dart';
import '../../domain/organize/organize_floating_context_layout.dart';
import '../../domain/organize/organize_proactive_record.dart';
import '../../domain/organize/organize_spine_classification.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/organize_visuals.dart';
import '../../utils/instant_codec.dart';
import '../common/thumbnail_atmosphere_surface.dart';
import '../../utils/workspace_evidence_formatters.dart';
import 'journey_evidence_thumbnail.dart';
import 'organize_context_anchor_arrow.dart';
import 'organize_context_delete_dialog.dart';
import 'organize_context_targeting.dart';
import 'organize_group_composition.dart';
import 'organize_workspace_view.dart';

/// Presentation of canonical capture chronology as the captured spine, with
/// Organize context as floating objects — not a parallel timeline.
///
/// Chronological-lane order is [OrganizeChronologyEligibilityPolicy]:
/// canonical [TimelineAnchor.sequenceOrder] first, then explicitly
/// chronological items without anchors (timestamp fallback), then legacy
/// leftovers. [lastPreservedAt] is never event time. Spine membership
/// follows [OrganizeSpineClassification]. Dragging a context tile stores an
/// [OrganizeContextAnchor] only.
class OrganizeChronologyCanvas extends StatefulWidget {
  const OrganizeChronologyCanvas({
    super.key,
    required this.ordered,
    required this.allEvidence,
    required this.onEvidenceSelected,
    this.anchors = const [],
    this.organizeCreatedIds = const {},
    this.anchoredAtByEvidenceId = const {},
    this.onSetContextAnchor,
    this.onClearContextAnchor,
    this.onLockAncestorScroll,
    this.detachUnsnappedOverlay = false,
    this.onDiscardUnsnapped,
    this.onExpandCluster,
    this.expandedClusterCapturedId,
    this.groupSelectionMode = false,
    this.groupMemberIds = const [],
    this.onGroupCloneDragStarted,
    this.onGroupCloneDragEnded,
    this.onRemoveGroupClone,
    this.onWorkspaceDismiss,
    this.onWobblingContextIdsChanged,
  });

  final List<WorkspaceEvidenceItem> ordered;
  final List<WorkspaceEvidenceItem> allEvidence;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;
  final List<OrganizeContextAnchor> anchors;
  final Set<String> organizeCreatedIds;

  /// [TimelineAnchor.anchoredAt] by captured evidence id. Presentation only.
  final Map<String, DateTime> anchoredAtByEvidenceId;
  final void Function(String contextEvidenceId, String capturedEvidenceId)?
  onSetContextAnchor;

  /// Clears an [OrganizeContextAnchor] only — never deletes evidence.
  final ValueChanged<String>? onClearContextAnchor;
  final ValueChanged<bool>? onLockAncestorScroll;

  /// When true, unsnapped context is hosted by the parent overlay and must
  /// not be laid out against the chronology spine.
  final bool detachUnsnappedOverlay;

  /// Deletes an unsnapped Organize context. Never deletes captured evidence.
  final ValueChanged<String>? onDiscardUnsnapped;
  final ValueChanged<String>? onExpandCluster;
  final String? expandedClusterCapturedId;
  final bool groupSelectionMode;
  final List<String> groupMemberIds;
  final VoidCallback? onGroupCloneDragStarted;
  final VoidCallback? onGroupCloneDragEnded;
  final ValueChanged<String>? onRemoveGroupClone;
  final VoidCallback? onWorkspaceDismiss;

  /// Appended contexts currently in the wobbling/floating placement state.
  /// Unsnapped overlay contexts wobble independently and are not listed here.
  final ValueChanged<Set<String>>? onWobblingContextIdsChanged;

  static const Key canvasKey = Key('organize_chronology_canvas');
  static const Key fixedSpineKey = Key('organize_fixed_spine');
  static const Key contextSpineKey = Key('organize_context_spine');
  static const Key floatingLayerKey = Key('organize_floating_context_layer');
  static const Key dragAuraKey = Key('organize_context_drag_aura');
  static const Key targetAuraKey = Key('organize_placement_target_aura');
  static const Key capturedLaneHeaderKey = Key('organize_captured_lane_header');
  static const Key addedContextLaneHeaderKey = Key(
    'organize_added_context_lane_header',
  );
  static const double snapDistance = OrganizeContextTargeting.enterDistance;

  /// Capture-origin / chronological spine.
  static const String capturedEvidenceLabel = 'Captured evidence';

  /// Authored-context objects. Not an integrity label and not event time.
  static const String addedContextLabel = 'Added context';

  static const Duration placementAuraDuration = Duration(milliseconds: 380);

  static Key addedContextCaptionKey(String evidenceId) =>
      Key('organize_added_context_caption_$evidenceId');

  static Key priorObservationCaptionKey(String evidenceId) =>
      Key('organize_prior_observation_caption_$evidenceId');

  static Key fixedTileKey(String evidenceId) =>
      Key('organize_fixed_tile_$evidenceId');

  static Key contextTileKey(String evidenceId) =>
      Key('organize_context_tile_$evidenceId');

  static Key contextDateKey(String evidenceId) =>
      Key('organize_context_date_$evidenceId');

  static Key awaitingPlacementKey(String evidenceId) =>
      Key('organize_context_awaiting_placement_$evidenceId');

  static Key discardKey(String evidenceId) =>
      Key('organize_context_discard_$evidenceId');

  static Key groupSelectDiscardKey(String evidenceId) =>
      Key('organize_group_select_discard_$evidenceId');

  static Key contextFrameKey(String evidenceId) =>
      Key('organize_context_frame_$evidenceId');

  static Key clusterKey(String capturedEvidenceId) =>
      Key('organize_context_cluster_$capturedEvidenceId');

  static const Key clusterModalKey = Key('organize_context_cluster_modal');
  static const Key clusterScrimKey = Key('organize_context_cluster_scrim');
  static const Key clusterModalScrollKey = Key(
    'organize_context_cluster_modal_scroll',
  );
  static const Key clusterModalScrollbarKey = Key(
    'organize_context_cluster_modal_scrollbar',
  );

  static Key clusterChipScrollbarKey(String capturedEvidenceId) =>
      Key('organize_context_cluster_chip_scrollbar_$capturedEvidenceId');

  static Key clusterArrowKey(String capturedEvidenceId) =>
      Key('organize_context_cluster_arrow_$capturedEvidenceId');

  static Key clusterExpandedArrowKey(String capturedEvidenceId) =>
      Key('organize_context_cluster_expanded_arrow_$capturedEvidenceId');

  static Key clusterItemKey(String contextEvidenceId) =>
      Key('organize_context_cluster_item_$contextEvidenceId');

  static Key contextArrowKey(String contextEvidenceId) =>
      Key('organize_context_arrow_$contextEvidenceId');

  static const Key placementGuidanceKey = Key('organize_placement_guidance');

  /// Placement is visual only — not chronology.
  static const String placementGuidance =
      'Captured context placed beside a captured moment — does not change chronology';

  /// Removed. Kept so tests can assert the action no longer exists.
  static const String unplaceLabel = 'Remove placement';

  static Key unplaceKey(String contextEvidenceId) =>
      Key('organize_unplace_$contextEvidenceId');

  static const double liftScale = 1.035;
  static const Duration dragStartDelay = Duration(milliseconds: 180);

  static const double clusterModalExtent = 284;

  static List<List<WorkspaceEvidenceItem>> minuteBands(
    List<WorkspaceEvidenceItem> ordered,
  ) {
    final bands = <List<WorkspaceEvidenceItem>>[];
    DateTime? currentMinute;
    for (final item in ordered) {
      final minute = _localMinute(item.lastPreservedAt);
      if (currentMinute == null || minute != currentMinute) {
        bands.add([item]);
        currentMinute = minute;
      } else {
        bands.last.add(item);
      }
    }
    return bands;
  }

  static DateTime _localMinute(DateTime at) {
    final local = InstantCodec.toLocal(at);
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }

  static bool isVisualCapture(WorkspaceEvidenceItem item) {
    return item.kind == WorkspaceEvidenceKind.image ||
        item.kind == WorkspaceEvidenceKind.video;
  }

  /// Organize spine display order. Presentation only — never writes
  /// [TimelineAnchor.sequenceOrder], `timelineOrder`, evidence ids, hashes,
  /// or provenance.
  ///
  /// Delegates to [OrganizeChronologyEligibilityPolicy.presentationOrder]:
  /// canonical sequence, then uncanonical chronological fallback, then
  /// legacy leftovers, then authored context.
  static List<WorkspaceEvidenceItem> displayOrder({
    required Iterable<WorkspaceEvidenceItem> items,
    required List<String> orderedCapturedEvidenceIds,
    Set<String> organizeCreatedIds = const {},
    String? incidentId,
  }) {
    return OrganizeChronologyEligibilityPolicy.presentationOrder(
      items: items,
      orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
      organizeCreatedIds: organizeCreatedIds,
      incidentId: incidentId,
    );
  }

  /// Organize-toolbar Voice / Text / File — the only items that float/wobble.
  static bool isContextSpineItem(
    WorkspaceEvidenceItem item, {
    Set<String> organizeCreatedIds = const {},
  }) {
    return OrganizeSpineClassification.isContextSpine(
      item: item,
      organizeCreatedIds: organizeCreatedIds,
    );
  }

  static bool isFixedSpineItem(
    WorkspaceEvidenceItem item, {
    Set<String> organizeCreatedIds = const {},
  }) {
    return OrganizeSpineClassification.isChronologicalSpine(
      item: item,
      organizeCreatedIds: organizeCreatedIds,
    );
  }

  @override
  OrganizeChronologyCanvasState createState() =>
      OrganizeChronologyCanvasState();
}

/// Organize presentation clock. Does not write chronology or evidence fields.
///
/// Captured spine: [TimelineAnchor.anchoredAt], then [WorkspaceEvidenceItem.capturedAt],
/// then [WorkspaceEvidenceItem.recordedAt]. Never [lastPreservedAt].
/// Context spine: [recordedAt] only — not a capture time.
abstract final class OrganizeChronologyClock {
  static const missingCaptureLabel = 'Chronology position preserved';

  static DateTime? captureInstant({
    required WorkspaceEvidenceItem item,
    Map<String, DateTime> anchoredAtByEvidenceId = const {},
  }) {
    return anchoredAtByEvidenceId[item.id] ??
        item.capturedAt ??
        item.recordedAt;
  }

  static DateTime? contextInstant(WorkspaceEvidenceItem item) {
    return item.recordedAt;
  }

  static DateTime? instant({
    required WorkspaceEvidenceItem item,
    required bool isAddedContext,
    Map<String, DateTime> anchoredAtByEvidenceId = const {},
  }) {
    if (isAddedContext) {
      return contextInstant(item);
    }
    return captureInstant(
      item: item,
      anchoredAtByEvidenceId: anchoredAtByEvidenceId,
    );
  }

  static String tileLabel({
    required WorkspaceEvidenceItem item,
    required bool isAddedContext,
    Map<String, DateTime> anchoredAtByEvidenceId = const {},
  }) {
    final at = instant(
      item: item,
      isAddedContext: isAddedContext,
      anchoredAtByEvidenceId: anchoredAtByEvidenceId,
    );
    if (at == null) {
      return missingCaptureLabel;
    }
    return WorkspaceEvidenceFormatters.evidenceClock(at);
  }

  static String gutterLabel({
    required WorkspaceEvidenceItem item,
    Map<String, DateTime> anchoredAtByEvidenceId = const {},
  }) {
    final at = captureInstant(
      item: item,
      anchoredAtByEvidenceId: anchoredAtByEvidenceId,
    );
    if (at == null) {
      return '—';
    }
    return DateFormat('HH:mm').format(InstantCodec.toLocal(at));
  }

  static String compactTime({
    required WorkspaceEvidenceItem item,
    required bool isAddedContext,
    Map<String, DateTime> anchoredAtByEvidenceId = const {},
  }) {
    final at = instant(
      item: item,
      isAddedContext: isAddedContext,
      anchoredAtByEvidenceId: anchoredAtByEvidenceId,
    );
    if (at == null) {
      return missingCaptureLabel;
    }
    return WorkspaceEvidenceFormatters.evidenceClockTime(at);
  }

  /// Calendar day for context thumbnails. Never "Today" / "Yesterday".
  static String compactDate({
    required WorkspaceEvidenceItem item,
    required bool isAddedContext,
    Map<String, DateTime> anchoredAtByEvidenceId = const {},
  }) {
    final at = instant(
      item: item,
      isAddedContext: isAddedContext,
      anchoredAtByEvidenceId: anchoredAtByEvidenceId,
    );
    if (at == null) {
      return '';
    }
    final local = InstantCodec.toLocal(at);
    final now = InstantCodec.toLocal(DateTime.now());
    if (local.year == now.year) {
      return DateFormat('d MMM').format(local);
    }
    return DateFormat('d MMM yyyy').format(local);
  }
}

class OrganizeChronologyCanvasState extends State<OrganizeChronologyCanvas> {
  final Map<String, GlobalKey> _targetKeys = {};
  final Set<String> _wobblingContextIds = {};
  final Set<String> _discardedContextIds = {};
  String? _magnetTargetId;
  String? _detentTargetId;
  String? _confirmingContextId;
  String? _confirmingCapturedId;
  String? _draggingContextId;
  double _magnetStrength = 0;
  Timer? _confirmTimer;
  Timer? _scrollLockTimer;
  Timer? _trailTimer;
  Offset? _pressOrigin;
  Offset? _lastPointer;
  bool _scrollLocked = false;
  bool _dragging = false;
  final List<OrganizeSoulTrailDot> soulTrail = [];

  @override
  void dispose() {
    _confirmTimer?.cancel();
    _scrollLockTimer?.cancel();
    _trailTimer?.cancel();
    super.dispose();
  }

  List<WorkspaceEvidenceItem> get _fixed {
    return [
      for (final item in widget.ordered)
        if (OrganizeChronologyCanvas.isFixedSpineItem(
          item,
          organizeCreatedIds: widget.organizeCreatedIds,
        ))
          item,
    ];
  }

  List<WorkspaceEvidenceItem> get _contextItems {
    return [
      for (final item in widget.ordered)
        if (!_discardedContextIds.contains(item.id) &&
            OrganizeChronologyCanvas.isContextSpineItem(
              item,
              organizeCreatedIds: widget.organizeCreatedIds,
            ))
          item,
    ];
  }

  void _publishWobblingContextIds() {
    widget.onWobblingContextIdsChanged?.call(
      Set<String>.of(_wobblingContextIds),
    );
  }

  void _discardFloatingContext(String contextId) {
    setState(() {
      _discardedContextIds.add(contextId);
      _wobblingContextIds.remove(contextId);
    });
    _publishWobblingContextIds();
    widget.onDiscardUnsnapped?.call(contextId);
  }

  /// Toolbar context that stays in free space. Linked singles sit beside
  /// their evidence on the spine; clustered relationships use the modal.
  List<WorkspaceEvidenceItem> get _floatingContextItems {
    final snapped = {
      for (final anchor in widget.anchors) anchor.contextEvidenceId,
    };
    return [
      for (final item in _contextItems)
        if (!snapped.contains(item.id)) item,
    ];
  }

  List<WorkspaceEvidenceItem> _snappedTo(String capturedId) {
    final ids = {
      for (final anchor in widget.anchors)
        if (anchor.capturedEvidenceId == capturedId) anchor.contextEvidenceId,
    };
    return [
      for (final item in _contextItems)
        if (ids.contains(item.id)) item,
    ];
  }

  bool get _placementEnabled =>
      widget.onSetContextAnchor != null && !widget.groupSelectionMode;

  GlobalKey _keyFor(String capturedId) {
    return _targetKeys.putIfAbsent(capturedId, GlobalKey.new);
  }

  Offset? _targetCenter(String capturedId) {
    final box = _targetKeys[capturedId]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  Map<String, Offset> get _targetCenters {
    return {
      for (final item in _fixed)
        if (_targetCenter(item.id) != null) item.id: _targetCenter(item.id)!,
    };
  }

  Rect? _targetRect(String capturedId) {
    final box = _targetKeys[capturedId]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Map<String, Rect> get _targetRects {
    return {
      for (final item in _fixed)
        if (_targetRect(item.id) != null) item.id: _targetRect(item.id)!,
    };
  }

  bool _hasAnchor(String contextId) {
    return widget.anchors.any(
      (anchor) => anchor.contextEvidenceId == contextId,
    );
  }

  void _armWobble(String contextId) {
    setState(() {
      _wobblingContextIds.add(contextId);
    });
    _publishWobblingContextIds();
  }

  void _onContextPointerDown(Offset global) {
    _pressOrigin = global;
    _scrollLockTimer?.cancel();
    _scrollLockTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted || _pressOrigin == null) {
        return;
      }
      _setScrollLocked(true);
    });
  }

  void _onContextPointerMove(Offset global) {
    final origin = _pressOrigin;
    if (origin == null || _scrollLocked) {
      return;
    }
    if ((global - origin).distance > kTouchSlop) {
      _scrollLockTimer?.cancel();
      _scrollLockTimer = null;
    }
  }

  void _onContextPointerUp() {
    if (_dragging) {
      return;
    }
    _releaseScrollLock();
  }

  void _releaseScrollLock() {
    _scrollLockTimer?.cancel();
    _scrollLockTimer = null;
    _pressOrigin = null;
    _setScrollLocked(false);
  }

  void _setScrollLocked(bool locked) {
    if (_scrollLocked == locked) {
      return;
    }
    _scrollLocked = locked;
    widget.onLockAncestorScroll?.call(locked);
  }

  void _onContextDragStarted([String? contextId]) {
    _dragging = true;
    _draggingContextId = contextId;
    if (!widget.detachUnsnappedOverlay) {
      _setScrollLocked(true);
    }
    HapticFeedback.lightImpact();
    setState(() {
      _detentTargetId = null;
    });
  }

  void _recordSoulTrail(Offset global) {
    final now = DateTime.now();
    soulTrail.add(OrganizeSoulTrailDot(global, now));
    soulTrail.removeWhere(
      (dot) => now.difference(dot.at) > OrganizeSoulTrailDot.lifetime,
    );
    _trailTimer?.cancel();
    _trailTimer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted) {
        return;
      }
      setState(() {
        final t = DateTime.now();
        soulTrail.removeWhere(
          (dot) => t.difference(dot.at) > OrganizeSoulTrailDot.lifetime,
        );
      });
    });
  }

  void _updateMagnet(Offset global) {
    _lastPointer = global;
    if (_dragging) {
      _recordSoulTrail(global);
    }
    final rects = _targetRects;
    final centers = _targetCenters;
    final nearest = rects.isEmpty
        ? OrganizeContextTargeting.resolveMagnet(
            currentId: _magnetTargetId,
            centers: centers,
            pointer: global,
          )
        : OrganizeContextTargeting.resolveExactTarget(
            targetRects: rects,
            pointer: global,
            currentId: _magnetTargetId,
          );
    final detent = OrganizeContextTargeting.resolveDetentAlignment(
      centers: centers,
      pointer: global,
    );
    final strength = rects.isEmpty
        ? OrganizeContextTargeting.magnetStrength(
            targetCenter: nearest == null ? null : centers[nearest],
            pointer: global,
          )
        : OrganizeContextTargeting.magnetStrengthForRect(
            targetRect: nearest == null ? null : rects[nearest],
            pointer: global,
          );
    if (OrganizeContextTargeting.shouldEmitDetent(
      previousDetentId: _detentTargetId,
      nextDetentId: detent,
    )) {
      HapticFeedback.selectionClick();
    }

    final strengthBand = (strength * 8).floor();
    final lastBand = (_magnetStrength * 8).floor();
    if (nearest != _magnetTargetId ||
        detent != _detentTargetId ||
        strengthBand != lastBand) {
      setState(() {
        _magnetTargetId = nearest;
        _magnetStrength = strength;
        _detentTargetId = detent;
      });
    }
  }

  void handleOverlayDragStarted() => _onContextDragStarted();

  void handleOverlayDragUpdate(Offset global) => _updateMagnet(global);

  bool handleOverlayDragEnd(String contextId) => _commitSnap(contextId);

  bool _commitSnap(String contextId) {
    final rects = _targetRects;
    final pointer = _lastPointer;
    final targetId = pointer == null
        ? _magnetTargetId
        : (rects.isEmpty
              ? OrganizeContextTargeting.resolveMagnet(
                  currentId: _magnetTargetId,
                  centers: _targetCenters,
                  pointer: pointer,
                )
              : OrganizeContextTargeting.resolveExactTarget(
                  targetRects: rects,
                  pointer: pointer,
                  currentId: _magnetTargetId,
                ));
    final hadAnchor = _hasAnchor(contextId);
    final willSnap = targetId != null && widget.onSetContextAnchor != null;
    _dragging = false;
    _draggingContextId = null;
    _releaseScrollLock();
    setState(() {
      _magnetTargetId = null;
      _detentTargetId = null;
      _magnetStrength = 0;
      if (willSnap) {
        _confirmingContextId = contextId;
        _confirmingCapturedId = targetId;
        _wobblingContextIds.remove(contextId);
      } else if (hadAnchor) {
        _wobblingContextIds.add(contextId);
      }
    });
    _publishWobblingContextIds();
    if (!willSnap) {
      if (hadAnchor) {
        widget.onClearContextAnchor?.call(contextId);
      }
      return false;
    }
    HapticFeedback.mediumImpact();
    widget.onSetContextAnchor!(contextId, targetId);
    _confirmTimer?.cancel();
    _confirmTimer = Timer(OrganizeChronologyCanvas.placementAuraDuration, () {
      if (!mounted || _confirmingContextId != contextId) {
        return;
      }
      setState(() {
        _confirmingContextId = null;
        _confirmingCapturedId = null;
      });
    });
    return true;
  }

  Widget _evidenceLinkArrow({
    required String capturedId,
    required Key arrowKey,
    required String contextEvidenceId,
    bool hide = false,
  }) {
    return SizedBox(
      width: OrganizeFloatingContextLayout.fingerGap,
      child: hide
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 36),
              child: OrganizeContextAnchorArrow(
                key: arrowKey,
                contextEvidenceId: contextEvidenceId,
                capturedEvidenceId: capturedId,
              ),
            ),
    );
  }

  Widget? _frozenLinkedContextSlot(WorkspaceEvidenceItem captured) {
    final slot = _linkedContextSlot(captured);
    if (slot == null) {
      return null;
    }
    return AbsorbPointer(child: slot);
  }

  Widget? _linkedContextSlot(WorkspaceEvidenceItem captured) {
    final snapped = _snappedTo(captured.id);
    if (snapped.length > 1) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _evidenceLinkArrow(
            capturedId: captured.id,
            arrowKey: OrganizeChronologyCanvas.clusterArrowKey(captured.id),
            contextEvidenceId: 'cluster:${captured.id}',
          ),
          _ContextCluster(
            capturedId: captured.id,
            items: snapped,
            onTap: () => widget.onExpandCluster?.call(captured.id),
          ),
        ],
      );
    }
    if (snapped.length != 1) {
      return null;
    }
    final item = snapped.first;
    final wobbling = _wobblingContextIds.contains(item.id);
    final draggingAway =
        _dragging &&
        _draggingContextId == item.id &&
        _magnetTargetId != captured.id;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _evidenceLinkArrow(
          capturedId: captured.id,
          arrowKey: OrganizeChronologyCanvas.contextArrowKey(item.id),
          contextEvidenceId: item.id,
          hide: draggingAway,
        ),
        OrganizeUnsnappedContextObject(
          item: item,
          allEvidence: widget.allEvidence,
          anchoredAtByEvidenceId: widget.anchoredAtByEvidenceId,
          linked: !draggingAway,
          wobbling: wobbling,
          confirming: _confirmingContextId == item.id,
          placementEnabled: _placementEnabled,
          onEvidenceSelected: widget.onEvidenceSelected,
          onArmWobble: () => _armWobble(item.id),
          onContextPointerDown: _onContextPointerDown,
          onContextPointerMove: _onContextPointerMove,
          onContextPointerUp: _onContextPointerUp,
          onContextDragStarted: () => _onContextDragStarted(item.id),
          onContextDragUpdate: _updateMagnet,
          onContextDragEnd: _commitSnap,
          onDiscardUnsnapped: _discardFloatingContext,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ordered.isEmpty) {
      return Semantics(
        container: true,
        child: Text(
          'No evidence in this incident yet. Capture to begin organizing.',
          style: AppTextStyles.bodySmall.copyWith(
            color: OrganizeVisuals.meta,
            height: 1.35,
          ),
        ),
      );
    }

    final fixed = _fixed;
    final contextItems = _contextItems;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.groupSelectionMode ? widget.onWorkspaceDismiss : null,
      child: Column(
        key: OrganizeChronologyCanvas.canvasKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fixed.isEmpty && contextItems.isEmpty)
            Text(
              'No evidence in this incident yet. Capture to begin organizing.',
              style: AppTextStyles.bodySmall.copyWith(
                color: OrganizeVisuals.meta,
                height: 1.35,
              ),
            )
          else ...[
            if (contextItems.isNotEmpty && _placementEnabled) ...[
              const SizedBox(height: 6),
              Text(
                OrganizeChronologyCanvas.placementGuidance,
                key: OrganizeChronologyCanvas.placementGuidanceKey,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: OrganizeVisuals.meta,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final floating = widget.detachUnsnappedOverlay
                    ? const <WorkspaceEvidenceItem>[]
                    : _floatingContextItems;
                final trail =
                    soulTrail.isNotEmpty &&
                        constraints.hasBoundedHeight &&
                        constraints.hasBoundedWidth
                    ? soulTrail
                    : const <OrganizeSoulTrailDot>[];
                final overlayHeight = floating.isEmpty
                    ? 0.0
                    : OrganizeFloatingContextLayout.stackHeight(
                            floating.length,
                          ) +
                          40 +
                          OrganizeFloatingContextLayout.removeControlOutset;
                return ConstrainedBox(
                  constraints: BoxConstraints(minHeight: overlayHeight),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < fixed.length; i++)
                            _SpineRow(
                              target: fixed[i],
                              allEvidence: widget.allEvidence,
                              anchoredAtByEvidenceId:
                                  widget.anchoredAtByEvidenceId,
                              targetKey: _keyFor(fixed[i].id),
                              magnetized: _magnetTargetId == fixed[i].id,
                              magnetStrength: _magnetTargetId == fixed[i].id
                                  ? _magnetStrength
                                  : 0,
                              targetAura: _confirmingCapturedId == fixed[i].id,
                              showConnector: i < fixed.length - 1,
                              fixedLaneKey: i == 0
                                  ? OrganizeChronologyCanvas.fixedSpineKey
                                  : null,
                              linkedContextSlot: widget.groupSelectionMode
                                  ? _frozenLinkedContextSlot(fixed[i])
                                  : _linkedContextSlot(fixed[i]),
                              onEvidenceSelected: widget.onEvidenceSelected,
                              groupSelectionMode: widget.groupSelectionMode,
                              alreadyGrouped: widget.groupMemberIds.contains(
                                fixed[i].id,
                              ),
                              onGroupCloneDragStarted:
                                  widget.onGroupCloneDragStarted,
                              onGroupCloneDragEnded:
                                  widget.onGroupCloneDragEnded,
                              onRemoveGroupClone: widget.onRemoveGroupClone,
                            ),
                        ],
                      ),
                      if (floating.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          width: OrganizeFloatingContextLayout.layerWidth,
                          height:
                              OrganizeFloatingContextLayout.stackHeight(
                                floating.length,
                              ) +
                              40 +
                              OrganizeFloatingContextLayout.removeControlOutset,
                          child: _FloatingContextLayer(
                            items: floating,
                            canvasWidth:
                                OrganizeFloatingContextLayout.layerWidth,
                            allEvidence: widget.allEvidence,
                            anchoredAtByEvidenceId:
                                widget.anchoredAtByEvidenceId,
                            confirmingContextId: _confirmingContextId,
                            placementEnabled: _placementEnabled,
                            onEvidenceSelected: widget.onEvidenceSelected,
                            onContextPointerDown: _onContextPointerDown,
                            onContextPointerMove: _onContextPointerMove,
                            onContextPointerUp: _onContextPointerUp,
                            onContextDragStarted: () => _onContextDragStarted(),
                            onContextDragUpdate: _updateMagnet,
                            onContextDragEnd: _commitSnap,
                            onDiscardUnsnapped: _discardFloatingContext,
                          ),
                        ),
                      if (trail.isNotEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: OrganizeSoulTrailLayer(dots: List.of(trail)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SpineRow extends StatelessWidget {
  const _SpineRow({
    required this.target,
    required this.allEvidence,
    this.anchoredAtByEvidenceId = const {},
    required this.targetKey,
    required this.magnetized,
    required this.magnetStrength,
    this.targetAura = false,
    required this.showConnector,
    this.fixedLaneKey,
    this.linkedContextSlot,
    required this.onEvidenceSelected,
    this.groupSelectionMode = false,
    this.alreadyGrouped = false,
    this.onGroupCloneDragStarted,
    this.onGroupCloneDragEnded,
    this.onRemoveGroupClone,
  });

  final WorkspaceEvidenceItem target;
  final List<WorkspaceEvidenceItem> allEvidence;
  final Map<String, DateTime> anchoredAtByEvidenceId;
  final GlobalKey targetKey;
  final bool magnetized;
  final double magnetStrength;
  final bool targetAura;
  final bool showConnector;
  final Key? fixedLaneKey;
  final Widget? linkedContextSlot;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;
  final bool groupSelectionMode;
  final bool alreadyGrouped;
  final VoidCallback? onGroupCloneDragStarted;
  final VoidCallback? onGroupCloneDragEnded;
  final ValueChanged<String>? onRemoveGroupClone;

  @override
  Widget build(BuildContext context) {
    final clock = OrganizeChronologyClock.gutterLabel(
      item: target,
      anchoredAtByEvidenceId: anchoredAtByEvidenceId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  clock,
                  style: AppTextStyles.caption.copyWith(
                    color: OrganizeVisuals.clock,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            DragTarget<String>(
              key: fixedLaneKey,
              onWillAcceptWithDetails: (details) =>
                  !groupSelectionMode && details.data != target.id,
              builder: (context, candidate, rejected) {
                final approaching = magnetized || candidate.isNotEmpty;
                final strength = approaching
                    ? (candidate.isNotEmpty
                          ? 1.0
                          : magnetStrength.clamp(0.0, 1.0))
                    : 0.0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (targetAura)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            key: OrganizeChronologyCanvas.targetAuraKey,
                            painter: OrganizeMilkyGalaxyPainter(
                              intensity: 0.85,
                            ),
                            child: SizedBox.expand(),
                          ),
                        ),
                      ),
                    DecoratedBox(
                      key: targetKey,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        border: approaching
                            ? Border.all(
                                color: OrganizeVisuals.spine.withValues(
                                  alpha: 0.28 + (0.28 * strength),
                                ),
                              )
                            : null,
                      ),
                      child: _groupSelectableTile(),
                    ),
                  ],
                );
              },
            ),
            ?linkedContextSlot,
          ],
        ),
        if (showConnector)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: 16,
                color: OrganizeVisuals.spine.withValues(alpha: 0.72),
              ),
            ),
          ),
      ],
    );
  }

  Widget _capturedBody({VoidCallback? onTap}) {
    return _ChronologyTile(
      item: target,
      allEvidence: allEvidence,
      anchoredAtByEvidenceId: anchoredAtByEvidenceId,
      tileKey: OrganizeChronologyCanvas.fixedTileKey(target.id),
      isAddedContext: false,
      onTap: onTap,
    );
  }

  Widget _groupSelectableTile() {
    if (!groupSelectionMode) {
      return _capturedBody(onTap: () => onEvidenceSelected(target));
    }

    Widget tile = OrganizePlacementWobble(
      active: true,
      child: alreadyGrouped
          ? GestureDetector(onTap: () {}, child: _capturedBody())
          : LongPressDraggable<OrganizeGroupCloneDrag>(
              data: OrganizeGroupCloneDrag(target.id),
              dragAnchorStrategy: pointerDragAnchorStrategy,
              delay: OrganizeChronologyCanvas.dragStartDelay,
              onDragStarted: onGroupCloneDragStarted,
              onDragEnd: (_) => onGroupCloneDragEnded?.call(),
              feedback: OrganizeGroupCloneFeedback(item: target),
              childWhenDragging: _capturedBody(),
              child: GestureDetector(onTap: () {}, child: _capturedBody()),
            ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: OrganizeFloatingContextLayout.removeControlOutset,
            top: OrganizeFloatingContextLayout.removeControlOutset,
          ),
          child: tile,
        ),
        Positioned(
          left: 0,
          top: 0,
          child: _ContextDiscardAffordance(
            evidenceId: target.id,
            buttonKey: OrganizeChronologyCanvas.groupSelectDiscardKey(
              target.id,
            ),
            label: 'Remove this moment from the group',
            hint: 'Does not delete captured evidence',
            onPressed: () => onRemoveGroupClone?.call(target.id),
          ),
        ),
      ],
    );
  }
}

class _FloatingContextLayer extends StatelessWidget {
  const _FloatingContextLayer({
    required this.items,
    required this.canvasWidth,
    required this.allEvidence,
    this.anchoredAtByEvidenceId = const {},
    this.confirmingContextId,
    required this.placementEnabled,
    required this.onEvidenceSelected,
    required this.onContextPointerDown,
    required this.onContextPointerMove,
    required this.onContextPointerUp,
    required this.onContextDragStarted,
    required this.onContextDragUpdate,
    required this.onContextDragEnd,
    this.onDiscardUnsnapped,
  });

  final List<WorkspaceEvidenceItem> items;
  final double canvasWidth;
  final List<WorkspaceEvidenceItem> allEvidence;
  final Map<String, DateTime> anchoredAtByEvidenceId;
  final String? confirmingContextId;
  final bool placementEnabled;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;
  final ValueChanged<Offset> onContextPointerDown;
  final ValueChanged<Offset> onContextPointerMove;
  final VoidCallback onContextPointerUp;
  final VoidCallback onContextDragStarted;
  final ValueChanged<Offset> onContextDragUpdate;
  final ValueChanged<String> onContextDragEnd;
  final ValueChanged<String>? onDiscardUnsnapped;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: OrganizeChronologyCanvas.contextSpineKey,
      child: Stack(
        key: OrganizeChronologyCanvas.floatingLayerKey,
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < items.length; i++)
            Positioned(
              left:
                  OrganizeFloatingContextLayout.offsetFor(
                    index: i,
                    canvasWidth: canvasWidth,
                  ).dx -
                  OrganizeFloatingContextLayout.removeControlOutset,
              top:
                  OrganizeFloatingContextLayout.offsetFor(
                    index: i,
                    canvasWidth: canvasWidth,
                  ).dy -
                  OrganizeFloatingContextLayout.removeControlOutset,
              width:
                  OrganizeFloatingContextLayout.tileWidth +
                  OrganizeFloatingContextLayout.removeControlOutset,
              height:
                  OrganizeFloatingContextLayout.tileHeight +
                  OrganizeFloatingContextLayout.removeControlOutset,
              child: OrganizeUnsnappedContextObject(
                item: items[i],
                allEvidence: allEvidence,
                anchoredAtByEvidenceId: anchoredAtByEvidenceId,
                linked: false,
                wobbling: true,
                confirming: confirmingContextId == items[i].id,
                placementEnabled: placementEnabled,
                onEvidenceSelected: onEvidenceSelected,
                onContextPointerDown: onContextPointerDown,
                onContextPointerMove: onContextPointerMove,
                onContextPointerUp: onContextPointerUp,
                onContextDragStarted: onContextDragStarted,
                onContextDragUpdate: onContextDragUpdate,
                onContextDragEnd: onContextDragEnd,
                onDiscardUnsnapped: onDiscardUnsnapped,
              ),
            ),
        ],
      ),
    );
  }
}

class OrganizeUnsnappedContextObject extends StatefulWidget {
  const OrganizeUnsnappedContextObject({
    super.key,
    required this.item,
    required this.allEvidence,
    this.anchoredAtByEvidenceId = const {},
    this.linked = false,
    this.wobbling = true,
    required this.confirming,
    required this.placementEnabled,
    required this.onEvidenceSelected,
    this.onArmWobble,
    required this.onContextPointerDown,
    required this.onContextPointerMove,
    required this.onContextPointerUp,
    required this.onContextDragStarted,
    required this.onContextDragUpdate,
    required this.onContextDragEnd,
    this.onDiscardUnsnapped,
  });

  final WorkspaceEvidenceItem item;
  final List<WorkspaceEvidenceItem> allEvidence;
  final Map<String, DateTime> anchoredAtByEvidenceId;
  final bool linked;
  final bool wobbling;
  final bool confirming;
  final bool placementEnabled;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;
  final VoidCallback? onArmWobble;
  final ValueChanged<Offset> onContextPointerDown;
  final ValueChanged<Offset> onContextPointerMove;
  final VoidCallback onContextPointerUp;
  final VoidCallback onContextDragStarted;
  final ValueChanged<Offset> onContextDragUpdate;
  final ValueChanged<String> onContextDragEnd;
  final ValueChanged<String>? onDiscardUnsnapped;

  @override
  State<OrganizeUnsnappedContextObject> createState() =>
      _OrganizeUnsnappedContextObjectState();
}

class _OrganizeUnsnappedContextObjectState
    extends State<OrganizeUnsnappedContextObject> {
  bool _openQueued = false;

  void _onTap() {
    if (widget.linked && !widget.wobbling) {
      widget.onArmWobble?.call();
    }
  }

  void _onDoubleTap() {
    if (_openQueued) {
      return;
    }
    if (!widget.wobbling && !widget.linked) {
      return;
    }
    _openQueued = true;
    widget.onEvidenceSelected(widget.item);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _openQueued = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget tile = OrganizePlacementWobble(
      key: OrganizeChronologyCanvas.awaitingPlacementKey(widget.item.id),
      active: widget.wobbling && widget.placementEnabled,
      child: _ChronologyTile(
        item: widget.item,
        allEvidence: widget.allEvidence,
        anchoredAtByEvidenceId: widget.anchoredAtByEvidenceId,
        tileKey: OrganizeChronologyCanvas.contextTileKey(widget.item.id),
        isAddedContext: true,
        draggable: widget.wobbling && widget.placementEnabled,
        confirming: widget.confirming,
        onTap: widget.linked && !widget.wobbling ? _onTap : null,
        onDoubleTap: widget.wobbling || widget.linked ? _onDoubleTap : null,
        onPointerDown: widget.onContextPointerDown,
        onPointerMove: widget.onContextPointerMove,
        onPointerUp: widget.onContextPointerUp,
        onDragStarted: widget.onContextDragStarted,
        onDragUpdate: widget.onContextDragUpdate,
        onDragEnd: () => widget.onContextDragEnd(widget.item.id),
      ),
    );
    if (widget.wobbling) {
      tile = Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: OrganizeFloatingContextLayout.removeControlOutset,
              top: OrganizeFloatingContextLayout.removeControlOutset,
            ),
            child: KeyedSubtree(
              key: OrganizeChronologyCanvas.contextFrameKey(widget.item.id),
              child: tile,
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: _ContextDiscardAffordance(
              evidenceId: widget.item.id,
              onPressed: widget.onDiscardUnsnapped == null
                  ? null
                  : () async {
                      final confirmed = await showOrganizeContextDeleteDialog(
                        context,
                      );
                      if (confirmed) {
                        widget.onDiscardUnsnapped!(widget.item.id);
                      }
                    },
            ),
          ),
        ],
      );
    }
    return tile;
  }
}

class _ChronologyTile extends StatelessWidget {
  const _ChronologyTile({
    required this.item,
    required this.allEvidence,
    this.onTap,
    this.onDoubleTap,
    required this.tileKey,
    this.anchoredAtByEvidenceId = const {},
    this.isAddedContext = false,
    this.draggable = false,
    this.confirming = false,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final WorkspaceEvidenceItem item;
  final List<WorkspaceEvidenceItem> allEvidence;
  final Map<String, DateTime> anchoredAtByEvidenceId;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final Key tileKey;
  final bool isAddedContext;
  final bool draggable;
  final bool confirming;
  final ValueChanged<Offset>? onPointerDown;
  final ValueChanged<Offset>? onPointerMove;
  final VoidCallback? onPointerUp;
  final VoidCallback? onDragStarted;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final tile = _tileBody();
    if (!draggable) {
      return tile;
    }
    return Listener(
      onPointerDown: (event) => onPointerDown?.call(event.position),
      onPointerMove: (event) => onPointerMove?.call(event.position),
      onPointerUp: (_) => onPointerUp?.call(),
      onPointerCancel: (_) => onPointerUp?.call(),
      child: LongPressDraggable<String>(
        data: item.id,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        delay: OrganizeChronologyCanvas.dragStartDelay,
        onDragStarted: onDragStarted,
        onDragUpdate: (details) => onDragUpdate?.call(details.globalPosition),
        onDragEnd: (_) => onDragEnd?.call(),
        feedback: _LiftedContextFeedback(item: item),
        childWhenDragging: Opacity(opacity: 0.32, child: tile),
        child: _SnapConfirm(active: confirming, child: tile),
      ),
    );
  }

  Widget _tileBody() {
    if (isAddedContext) {
      return _contextThumbnailBody();
    }
    return _capturedTileBody();
  }

  Widget _contextThumbnailBody() {
    final dateLabel = OrganizeChronologyClock.compactDate(
      item: item,
      isAddedContext: true,
      anchoredAtByEvidenceId: anchoredAtByEvidenceId,
    );
    final timeLabel = OrganizeChronologyClock.compactTime(
      item: item,
      isAddedContext: true,
      anchoredAtByEvidenceId: anchoredAtByEvidenceId,
    );
    return Semantics(
      button: true,
      label:
          '${item.kind.label}, ${OrganizeChronologyCanvas.addedContextLabel}',
      child: ConstrainedBox(
        key: tileKey,
        constraints: const BoxConstraints(
          minWidth: AppAccessibility.minTouchTarget,
          maxWidth: 120,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: OrganizeWorkspaceView.rowKey(item.id),
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: SizedBox(
              width: JourneyEvidenceThumbnail.size,
              height: JourneyEvidenceThumbnail.size,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  JourneyEvidenceThumbnail(
                    item: item,
                    onTap: onDoubleTap == null ? onTap : null,
                    identifyingTextColor:
                        OrganizeEvidenceTypography.thumbnailText,
                  ),
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [Color(0x99071426), Color(0x00071426)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 5,
                    right: 5,
                    bottom: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dateLabel.isNotEmpty)
                          Text(
                            dateLabel,
                            key: OrganizeChronologyCanvas.contextDateKey(
                              item.id,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: OrganizeEvidenceTypography.date,
                              fontSize: 9,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        Text(
                          timeLabel,
                          key: Key('organize_evidence_clock_${item.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: OrganizeEvidenceTypography.timestamp,
                            fontSize: 10,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
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
      ),
    );
  }

  Widget _capturedTileBody() {
    final description = item.kind == WorkspaceEvidenceKind.note
        ? null
        : organizeEvidenceDescription(item, allEvidence);
    final person = organizeRelatedPersonLabel(item);
    final linked = organizeLinkedLabel(item, allEvidence);

    final isPriorObservation = OrganizeProactiveRecord.isPriorObservation(
      item: item,
      incidentEvidence: allEvidence,
    );
    final semanticRole = isPriorObservation
        ? OrganizeProactiveRecord.caption
        : OrganizeChronologyCanvas.capturedEvidenceLabel;

    return Semantics(
      button: true,
      label: '${item.kind.label}, $semanticRole',
      child: ConstrainedBox(
        key: tileKey,
        constraints: const BoxConstraints(
          minWidth: AppAccessibility.minTouchTarget,
          maxWidth: 120,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: InkWell(
            key: OrganizeWorkspaceView.rowKey(item.id),
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              child: Stack(
                children: [
                  const Positioned.fill(child: ThumbnailAtmosphereSurface()),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        JourneyEvidenceThumbnail(
                          item: item,
                          onTap: onTap,
                          identifyingTextColor:
                              OrganizeEvidenceTypography.thumbnailText,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.kind.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: OrganizeEvidenceTypography.thumbnailText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isPriorObservation)
                          Text(
                            OrganizeProactiveRecord.caption,
                            key:
                                OrganizeChronologyCanvas.priorObservationCaptionKey(
                                  item.id,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: OrganizeEvidenceTypography.thumbnailText,
                              fontSize: 10,
                              height: 1.2,
                            ),
                          ),
                        Text(
                          OrganizeChronologyClock.tileLabel(
                            item: item,
                            isAddedContext: false,
                            anchoredAtByEvidenceId: anchoredAtByEvidenceId,
                          ),
                          key: Key('organize_evidence_clock_${item.id}'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: OrganizeEvidenceTypography.timestamp,
                            fontSize: 11,
                            height: 1.25,
                          ),
                        ),
                        if (description != null)
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: OrganizeEvidenceTypography.thumbnailText,
                              height: 1.3,
                            ),
                          ),
                        if (person != null)
                          Text(
                            person,
                            key: Key('organize_related_person_${item.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: OrganizeEvidenceTypography.participant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (linked != null)
                          Text(
                            linked,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: OrganizeVisuals.meta,
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
      ),
    );
  }
}

class _LiftedContextFeedback extends StatefulWidget {
  const _LiftedContextFeedback({required this.item});

  final WorkspaceEvidenceItem item;

  @override
  State<_LiftedContextFeedback> createState() => _LiftedContextFeedbackState();
}

class _LiftedContextFeedbackState extends State<_LiftedContextFeedback> {
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _scale = OrganizeChronologyCanvas.liftScale;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: AppMotion.fast,
      curve: AppMotion.enter,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          const Positioned(
            left: -88,
            top: -96,
            width: 120,
            height: 120,
            child: IgnorePointer(
              child: CustomPaint(
                key: OrganizeChronologyCanvas.dragAuraKey,
                painter: OrganizeMilkyGalaxyPainter(intensity: 1),
                child: SizedBox.expand(),
              ),
            ),
          ),
          const Positioned(
            left: -56,
            top: -64,
            width: 88,
            height: 88,
            child: IgnorePointer(
              child: CustomPaint(
                painter: OrganizeMilkyGalaxyPainter(intensity: 0.7),
                child: SizedBox.expand(),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: Border.all(
                color: OrganizeVisuals.milkyCore.withValues(alpha: 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: OrganizeVisuals.milkyMid.withValues(alpha: 0.55),
                  blurRadius: 18,
                  offset: const Offset(-8, -10),
                ),
                const BoxShadow(
                  color: Color(0x1A071426),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: JourneyEvidenceThumbnail(
                item: widget.item,
                identifyingTextColor: OrganizeEvidenceTypography.thumbnailText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapConfirm extends StatefulWidget {
  const _SnapConfirm({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_SnapConfirm> createState() => _SnapConfirmState();
}

class _SnapConfirmState extends State<_SnapConfirm> {
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _scale = OrganizeChronologyCanvas.liftScale;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(_SnapConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _scale = OrganizeChronologyCanvas.liftScale;
    } else if (!widget.active && oldWidget.active) {
      _scale = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: AppMotion.medium,
      curve: AppMotion.enter,
      child: widget.child,
    );
  }
}

/// Repeating jiggle while context awaits placement. Presentation only.
class OrganizePlacementWobble extends StatefulWidget {
  const OrganizePlacementWobble({
    super.key,
    required this.active,
    required this.child,
    this.restartToken,
    this.maxAngle = 0.045,
  });

  final bool active;
  final Widget child;
  final Object? restartToken;
  final double maxAngle;

  static const Duration cycle = Duration(milliseconds: 640);

  @override
  State<OrganizePlacementWobble> createState() =>
      _OrganizePlacementWobbleState();
}

class _OrganizePlacementWobbleState extends State<OrganizePlacementWobble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OrganizePlacementWobble.cycle,
    );
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(OrganizePlacementWobble oldWidget) {
    super.didUpdateWidget(oldWidget);
    final addedWhileActive =
        widget.active &&
        widget.restartToken != null &&
        widget.restartToken != oldWidget.restartToken;
    if (addedWhileActive) {
      _controller
        ..stop()
        ..value = 0
        ..repeat();
      return;
    }
    _sync();
  }

  void _sync() {
    if (!widget.active) {
      _controller.stop();
      _controller.value = 0;
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.active || reduceMotion) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle =
            widget.maxAngle * math.sin(_controller.value * 2 * math.pi);
        return Transform.rotate(
          angle: angle,
          filterQuality: FilterQuality.low,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class OrganizeSoulTrailDot {
  const OrganizeSoulTrailDot(this.global, this.at);

  final Offset global;
  final DateTime at;

  static const Duration lifetime = Duration(milliseconds: 1000);
}

class OrganizeSoulTrailLayer extends StatelessWidget {
  const OrganizeSoulTrailLayer({super.key, required this.dots});

  final List<OrganizeSoulTrailDot> dots;

  @override
  Widget build(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return const SizedBox.expand();
    }
    final origin = box.localToGlobal(Offset.zero);
    return CustomPaint(
      painter: _SoulTrailPainter(
        points: [for (final dot in dots) dot.global - origin],
        ages: [
          for (final dot in dots)
            DateTime.now().difference(dot.at).inMilliseconds /
                OrganizeSoulTrailDot.lifetime.inMilliseconds,
        ],
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SoulTrailPainter extends CustomPainter {
  const _SoulTrailPainter({required this.points, required this.ages});

  final List<Offset> points;
  final List<double> ages;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }
    for (var i = 1; i < points.length; i++) {
      final age = ages[i].clamp(0.0, 1.0);
      final paint = Paint()
        ..color = OrganizeVisuals.milkyCore.withValues(alpha: 0.55 * (1 - age))
        ..strokeWidth = 5.5 * (1 - age * 0.6)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(points[i - 1], points[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoulTrailPainter oldDelegate) => true;
}

class _ContextDiscardAffordance extends StatelessWidget {
  const _ContextDiscardAffordance({
    required this.evidenceId,
    this.onPressed,
    this.buttonKey,
    this.label = 'Remove this floating context from Organize',
    this.hint = 'Does not delete captured evidence',
  });

  final String evidenceId;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      hint: hint,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: buttonKey ?? OrganizeChronologyCanvas.discardKey(evidenceId),
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: OrganizeFloatingContextLayout.removeControlExtent,
            height: OrganizeFloatingContextLayout.removeControlExtent,
            child: Center(
              child: Tooltip(
                message: '$label. $hint',
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
            ),
          ),
        ),
      ),
    );
  }
}

class _OrganizeWhiteOverflowScrollbar extends StatelessWidget {
  const _OrganizeWhiteOverflowScrollbar({
    required this.overflow,
    required this.controller,
    required this.scrollbarKey,
    required this.child,
  });

  final bool overflow;
  final ScrollController controller;
  final Key scrollbarKey;
  final Widget child;

  static const Color thumb = Color(0xF7FFFFFF);
  static const double thickness = 5;

  @override
  Widget build(BuildContext context) {
    if (!overflow) {
      return child;
    }
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(thumb),
        thickness: WidgetStateProperty.all(thickness),
        radius: const Radius.circular(3),
        crossAxisMargin: 1,
        mainAxisMargin: 1.5,
        thumbVisibility: WidgetStateProperty.all(true),
      ),
      child: Scrollbar(
        key: scrollbarKey,
        controller: controller,
        thumbVisibility: true,
        thickness: thickness,
        radius: const Radius.circular(3),
        child: child,
      ),
    );
  }
}

class _ContextCluster extends StatefulWidget {
  const _ContextCluster({
    required this.capturedId,
    required this.items,
    required this.onTap,
  });

  final String capturedId;
  final List<WorkspaceEvidenceItem> items;
  final VoidCallback onTap;

  @override
  State<_ContextCluster> createState() => _ContextClusterState();
}

class _ContextClusterState extends State<_ContextCluster> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overflow = widget.items.length > 4;
    return Material(
      color: const Color(0xFFF4F8FB),
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: OrganizeChronologyCanvas.clusterKey(widget.capturedId),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: SizedBox(
          width: JourneyEvidenceThumbnail.size,
          height: JourneyEvidenceThumbnail.size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ThumbnailAtmosphereSurface(),
              Padding(
                padding: const EdgeInsets.all(3),
                child: _OrganizeWhiteOverflowScrollbar(
                  overflow: overflow,
                  controller: _scrollController,
                  scrollbarKey:
                      OrganizeChronologyCanvas.clusterChipScrollbarKey(
                        widget.capturedId,
                      ),
                  child: IgnorePointer(
                    child: GridView.builder(
                      controller: overflow ? _scrollController : null,
                      primary: false,
                      physics: overflow
                          ? const BouncingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 3,
                            crossAxisSpacing: 3,
                          ),
                      itemCount: widget.items.length,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: FittedBox(
                            child: JourneyEvidenceThumbnail(
                              item: widget.items[index],
                              identifyingTextColor:
                                  OrganizeEvidenceTypography.thumbnailText,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrganizeContextClusterModal extends StatefulWidget {
  const OrganizeContextClusterModal({
    super.key,
    required this.items,
    required this.capturedEvidenceId,
    required this.onEvidenceSelected,
    required this.onDismiss,
    this.onUnlinkContext,
    this.onDiscardContext,
    this.onContextDragStarted,
    this.onContextDragUpdate,
    this.onContextDragEnd,
  });

  final List<WorkspaceEvidenceItem> items;
  final String capturedEvidenceId;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;
  final VoidCallback onDismiss;
  final void Function(String contextEvidenceId, Offset globalDrop)?
  onUnlinkContext;
  final ValueChanged<String>? onDiscardContext;
  final VoidCallback? onContextDragStarted;
  final ValueChanged<Offset>? onContextDragUpdate;
  final ValueChanged<String>? onContextDragEnd;

  @override
  State<OrganizeContextClusterModal> createState() =>
      _OrganizeContextClusterModalState();
}

class _OrganizeContextClusterModalState
    extends State<OrganizeContextClusterModal> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _panelKey = GlobalKey();
  String? _wobblingId;
  Offset? _lastGlobal;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _dropIsOutsidePanel(Offset global) {
    final box = _panelKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return true;
    }
    final origin = box.localToGlobal(Offset.zero);
    return !(origin & box.size).contains(global);
  }

  void _onDragEnd(String contextId) {
    final drop = _lastGlobal;
    if (drop != null && _dropIsOutsidePanel(drop)) {
      widget.onContextDragEnd?.call(contextId);
      widget.onUnlinkContext?.call(contextId, drop);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final overflow = widget.items.length > 4;
    Widget grid = GridView.builder(
      key: OrganizeChronologyCanvas.clusterModalScrollKey,
      controller: overflow ? _scrollController : null,
      primary: false,
      physics: overflow
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final wobbling = _wobblingId == item.id;
        Widget cell = OrganizePlacementWobble(
          key: OrganizeChronologyCanvas.awaitingPlacementKey(item.id),
          active: wobbling,
          child: JourneyEvidenceThumbnail(
            key: OrganizeChronologyCanvas.clusterItemKey(item.id),
            item: item,
            onTap: wobbling ? null : () => widget.onEvidenceSelected(item),
            identifyingTextColor: OrganizeEvidenceTypography.thumbnailText,
          ),
        );
        if (wobbling) {
          cell = Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: OrganizeFloatingContextLayout.removeControlOutset,
                  top: OrganizeFloatingContextLayout.removeControlOutset,
                ),
                child: KeyedSubtree(
                  key: OrganizeChronologyCanvas.contextFrameKey(item.id),
                  child: cell,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: _ContextDiscardAffordance(
                  evidenceId: item.id,
                  onPressed: widget.onDiscardContext == null
                      ? null
                      : () async {
                          final confirmed =
                              await showOrganizeContextDeleteDialog(context);
                          if (confirmed) {
                            widget.onDiscardContext!(item.id);
                          }
                        },
                ),
              ),
            ],
          );
        }
        return LongPressDraggable<String>(
          data: item.id,
          delay: OrganizeChronologyCanvas.dragStartDelay,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragStarted: () {
            setState(() {
              _wobblingId = item.id;
            });
            widget.onContextDragStarted?.call();
          },
          onDragUpdate: (details) {
            _lastGlobal = details.globalPosition;
            widget.onContextDragUpdate?.call(details.globalPosition);
          },
          onDragEnd: (_) => _onDragEnd(item.id),
          feedback: _LiftedContextFeedback(item: item),
          childWhenDragging: Opacity(opacity: 0.32, child: cell),
          child: cell,
        );
      },
    );
    if (overflow) {
      grid = _OrganizeWhiteOverflowScrollbar(
        overflow: true,
        controller: _scrollController,
        scrollbarKey: OrganizeChronologyCanvas.clusterModalScrollbarKey,
        child: grid,
      );
    }

    final panel = Material(
      key: OrganizeChronologyCanvas.clusterModalKey,
      color: const Color(0xFFF4F8FB),
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        key: _panelKey,
        width: OrganizeChronologyCanvas.clusterModalExtent,
        height: OrganizeChronologyCanvas.clusterModalExtent,
        child: Stack(
          children: [
            const Positioned.fill(child: ThumbnailAtmosphereSurface()),
            Padding(padding: const EdgeInsets.all(AppSpacing.xs), child: grid),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: OrganizeChronologyCanvas.clusterScrimKey,
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OrganizeContextAnchorArrow(
                key: OrganizeChronologyCanvas.clusterExpandedArrowKey(
                  widget.capturedEvidenceId,
                ),
                contextEvidenceId: 'cluster:${widget.capturedEvidenceId}',
                capturedEvidenceId: widget.capturedEvidenceId,
              ),
              const SizedBox(width: 8),
              panel,
            ],
          ),
        ),
      ],
    );
  }
}
