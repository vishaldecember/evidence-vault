import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/relationship_group.dart';
import '../../models/journey_stage.dart';
import '../../models/reflection_model.dart';
import '../../models/workspace_capture_mode.dart';
import '../../models/workspace_evidence_item.dart';
import '../../services/workspace_coaching_service.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_motion.dart';
import '../common/modern_art_material.dart';
import 'continue_capturing_section.dart';
import 'evidence_completeness_card.dart';
import 'evidence_map_section.dart';
import 'incident_identity_drawer.dart';
import 'incident_journey_card.dart';
import 'relationship_group_summary.dart';
import '../reflection/reflection_section.dart';
import 'workspace_body_presentation.dart';

/// Fallback until the Action Layer is measured on first layout (~20% tighter).
const double kWorkspaceActionLayerFallbackHeight = 150;

/// Composes the Evidence Workspace into scrollable Information and sticky Action layers.
class WorkspaceBody extends StatefulWidget {
  const WorkspaceBody({
    super.key,
    required this.evidence,
    required this.relationshipGroups,
    required this.activeCaptureMode,
    required this.onCaptureModeSelected,
    required this.reflections,
    required this.onAddReflection,
    required this.onEditReflection,
    required     this.onJourneyEvidenceTap,
    this.onConnectPressed,
    this.onCancelConnect,
    this.connectModeActive = false,
    this.connectSelectedEvidenceIds = const {},
    this.connectPendingColorIndex = 0,
    this.showConnectAction = false,
    this.onViewConnections,
    this.onViewTimeline,
    this.onOpenReconstruction,
    this.currentStage = JourneyStage.empty,
    required this.currentCoaching,
    required this.journeyEvidence,
    this.timelineAnchorCount = 0,
    this.supportingEvidenceCount = 0,
    this.incidentName = '',
    this.incidentId = '',
    this.onIncidentNameChanged,
    this.animateEvidenceId,
    this.presentation = WorkspaceBodyPresentation.capture,
    this.onEnterInvestigation,
    this.resolveParticipantName,
    this.suggestedCollectionsPanel,
  });

  final List<WorkspaceEvidenceItem> evidence;
  final List<RelationshipGroup> relationshipGroups;
  final List<ReflectionModel> reflections;
  final WorkspaceCaptureMode? activeCaptureMode;
  final ValueChanged<WorkspaceCaptureMode> onCaptureModeSelected;
  final VoidCallback onAddReflection;
  final ValueChanged<ReflectionModel> onEditReflection;
  final ValueChanged<WorkspaceEvidenceItem> onJourneyEvidenceTap;
  final VoidCallback? onConnectPressed;
  final VoidCallback? onCancelConnect;
  final bool connectModeActive;
  final Set<String> connectSelectedEvidenceIds;
  final int connectPendingColorIndex;
  final bool showConnectAction;
  final VoidCallback? onViewConnections;
  final VoidCallback? onViewTimeline;
  final VoidCallback? onOpenReconstruction;
  final JourneyStage currentStage;
  final WorkspaceCoaching currentCoaching;
  final List<WorkspaceEvidenceItem> journeyEvidence;
  final int timelineAnchorCount;
  final int supportingEvidenceCount;
  final String incidentName;
  /// Stable identity for title-field remount (Clear Vault / Capture Now).
  final String incidentId;
  final ValueChanged<String>? onIncidentNameChanged;
  final String? animateEvidenceId;
  final WorkspaceBodyPresentation presentation;
  final VoidCallback? onEnterInvestigation;
  final String? Function(String participantId)? resolveParticipantName;
  final Widget? suggestedCollectionsPanel;

  bool get _showCaptureLayer =>
      presentation == WorkspaceBodyPresentation.capture;

  bool get _showEvidenceEnrichment =>
      presentation == WorkspaceBodyPresentation.evidence;
  bool get _showIdentityDrawer =>
      _showCaptureLayer &&
      evidence.isNotEmpty &&
      onIncidentNameChanged != null;

  @override
  State<WorkspaceBody> createState() => _WorkspaceBodyState();
}

class _WorkspaceBodyState extends State<WorkspaceBody> {
  final GlobalKey _actionLayerKey = GlobalKey();
  double _actionLayerHeight = kWorkspaceActionLayerFallbackHeight;
  bool _identityDrawerExpanded = false;
  bool _userCollapsedDrawer = false;
  bool _animateIdentityEntry = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_measureActionLayer);
  }

  void _measureActionLayer(_) {
    final actionContext = _actionLayerKey.currentContext;
    if (actionContext == null) {
      return;
    }

    final measuredHeight = actionContext.size?.height;
    if (measuredHeight == null ||
        measuredHeight <= 0 ||
        measuredHeight == _actionLayerHeight) {
      return;
    }

    setState(() => _actionLayerHeight = measuredHeight);
  }

  @override
  void didUpdateWidget(WorkspaceBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_userCollapsedDrawer &&
        oldWidget.evidence.isEmpty &&
        widget.evidence.isNotEmpty) {
      _identityDrawerExpanded = true;
      _animateIdentityEntry = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _animateIdentityEntry = false);
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback(_measureActionLayer);
  }

  void _toggleIdentityDrawer() {
    setState(() {
      if (_identityDrawerExpanded) {
        _identityDrawerExpanded = false;
        _userCollapsedDrawer = true;
      } else {
        _identityDrawerExpanded = true;
      }
    });
  }

  List<EvidenceCompletenessItem> _completenessItems() {
    final kinds = widget.evidence.map((item) => item.kind).toSet();

    return [
      EvidenceCompletenessItem(
        label: 'Photos',
        isPreserved: kinds.contains(WorkspaceEvidenceKind.image),
      ),
      EvidenceCompletenessItem(
        label: 'Voice Note',
        isPreserved: kinds.contains(WorkspaceEvidenceKind.voice),
      ),
      EvidenceCompletenessItem(
        label: 'Text Note',
        isPreserved: kinds.contains(WorkspaceEvidenceKind.note),
      ),
      EvidenceCompletenessItem(
        label: 'Attachments',
        isPreserved: kinds.contains(WorkspaceEvidenceKind.attachment),
      ),
      EvidenceCompletenessItem(
        label: 'Metadata',
        isPreserved: widget.evidence.isNotEmpty,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final informationMinHeight = (constraints.maxHeight -
                (widget._showCaptureLayer ? _actionLayerHeight : 0))
            .clamp(0.0, double.infinity);

        return Stack(
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                }
                return false;
              },
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: AnimatedPadding(
                  duration: AppMotion.layer,
                  curve: AppMotion.enter,
                  padding: EdgeInsets.only(
                    left: AppSpacing.screenHorizontal,
                    right: AppSpacing.screenHorizontal,
                    top: AppSpacing.sm,
                    bottom: (widget._showCaptureLayer ? _actionLayerHeight : 0) +
                        AppSpacing.sm,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: informationMinHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget._showCaptureLayer ||
                            widget._showEvidenceEnrichment) ...[
                          IncidentJourneyCard(
                            currentStage: widget.currentStage,
                            currentCoaching: widget._showEvidenceEnrichment
                                ? WorkspaceCoachingService.organizeCoachingFrom(
                                    widget.currentCoaching,
                                    relationshipGroupCount:
                                        widget.relationshipGroups.length,
                                  )
                                : widget.currentCoaching,
                            journeyEvidence: widget.journeyEvidence,
                            onEvidenceSelected: widget.onJourneyEvidenceTap,
                            animateEvidenceId: widget.animateEvidenceId,
                            relationshipGroups: widget.relationshipGroups,
                            connectModeActive: widget.connectModeActive,
                            selectedEvidenceIds: widget.connectModeActive
                                ? widget.connectSelectedEvidenceIds
                                : const {},
                            connectPendingColorIndex:
                                widget.connectPendingColorIndex,
                            resolveParticipantName:
                                widget.resolveParticipantName,
                            isOrganizeStage: widget._showEvidenceEnrichment,
                            onConnectPressed: widget._showEvidenceEnrichment
                                ? widget.onConnectPressed
                                : null,
                            onCancelConnect: widget.onCancelConnect,
                            showConnectAction: widget.showConnectAction,
                            suggestedCollectionsPanel:
                                widget._showEvidenceEnrichment
                                    ? widget.suggestedCollectionsPanel
                                    : null,
                          ),
                        ],
                        if (widget._showEvidenceEnrichment) ...[
                          EvidenceMapSection(
                            evidence: widget.evidence,
                            onEvidenceSelected: widget.onJourneyEvidenceTap,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          RelationshipGroupSummary(
                            relationshipGroups: widget.relationshipGroups,
                            onViewConnections: widget.onEnterInvestigation,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ReflectionSection(
                            reflections: widget.reflections,
                            onAddReflection: widget.onAddReflection,
                            onEditReflection: widget.onEditReflection,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          EvidenceCompletenessCard(
                            items: _completenessItems(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget._showCaptureLayer)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.cardRadius),
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: ChromeAtmosphereSurface()),
                      DecoratedBox(
                        decoration: AppDecorations.stickyLayer().copyWith(
                          color: Colors.transparent,
                        ),
                        child: KeyedSubtree(
                    key: _actionLayerKey,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.screenHorizontal,
                            ),
                            child: ContinueCapturingSection(
                              activeMode: widget.activeCaptureMode,
                              onModeSelected: widget.onCaptureModeSelected,
                              identityDrawer: widget._showIdentityDrawer
                                  ? IncidentIdentityDrawer(
                                      key: ValueKey(
                                        widget.incidentId.isEmpty
                                            ? widget.incidentName
                                            : widget.incidentId,
                                      ),
                                      isExpanded: _identityDrawerExpanded,
                                      onToggle: _toggleIdentityDrawer,
                                      incidentName: widget.incidentName,
                                      onIncidentNameChanged:
                                          widget.onIncidentNameChanged!,
                                      animateEntry: _animateIdentityEntry,
                                    )
                                  : null,
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
              ),
          ],
        );
      },
    );
  }
}
