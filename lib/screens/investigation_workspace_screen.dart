import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../controllers/investigation_coaching_controller.dart';
import '../controllers/reconstruction_canvas_controller.dart';
import '../controllers/risk_coach_controller.dart';
import '../controllers/workspace_evidence_controller.dart';
import '../controllers/workspace_session.dart';
import '../domain/incident/current_incident.dart';
import '../domain/risk/incident_risk_assessment.dart';
import '../models/investigation_coaching_item.dart';
import '../models/investigation_coaching_target.dart';
import '../engines/narrative_builder.dart';
import '../models/investigation_methodology_stage.dart';
import '../models/investigation_workspace_tab.dart';
import '../models/workspace_resume_target.dart';
import '../navigation/investigation_journey_navigation.dart';
import '../models/connection_group_node.dart';
import '../models/relationship_group.dart';
import '../models/timeline_anchor_node.dart';
import '../models/timeline_workspace_filter.dart';
import '../models/workspace_evidence_item.dart';
import '../presentation/open_evidence_presentation.dart';
import '../models/reflection_model.dart';
import '../services/relationship/relationship_engine.dart';
import '../services/investigation_canvas_sync_engine.dart';
import '../services/narrative_validation_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/app_back_button.dart';
import '../widgets/common/space_canvas.dart';
import '../widgets/investigation/connections_workspace.dart';
import '../widgets/investigation/investigate_incident_scope.dart';
import '../widgets/investigation/investigation_coach_pocket.dart';
import '../widgets/investigation/investigation_coaching_panel.dart';
import '../widgets/investigation/investigation_header.dart';
import '../widgets/investigation/evidence_review_halo.dart';
import '../widgets/evidence_inspector/evidence_spatial_carousel.dart';
import '../widgets/investigation/investigation_evidence_inspector_modal.dart';
import '../widgets/investigation/investigation_graph_workspace.dart';
import '../widgets/investigation/investigation_stage_header.dart';
import '../widgets/investigation/investigation_workspace_tab_bar.dart';
import '../widgets/investigation/investigation_workspace_tab_stack.dart';
import '../widgets/investigation/reconstruction_workspace.dart';
import '../widgets/investigation/risk_coach_panel.dart';
import '../widgets/investigation/timeline_workspace.dart';

/// Parent Investigation Workspace — Timeline, Connections, and Reconstruction
/// are synchronized perspectives of one investigation.
class InvestigationWorkspaceScreen extends StatefulWidget {
  const InvestigationWorkspaceScreen({
    super.key,
    required this.controller,
    required this.onOpenFullEvidenceRecord,
    this.onShowEvidenceInspector,
    this.canvasController,
    this.initialTab = InvestigationWorkspaceTab.timeline,
    this.embeddedInShell = false,
    this.boundIncidentId,
  });

  final WorkspaceEvidenceController controller;
  final Future<void> Function(WorkspaceEvidenceItem) onOpenFullEvidenceRecord;
  final Future<void> Function(WorkspaceEvidenceItem)? onShowEvidenceInspector;
  final InvestigationCanvasController? canvasController;
  final InvestigationWorkspaceTab initialTab;
  final bool embeddedInShell;

  /// Workspace-bound incident for Investigate lists. When null, falls back to
  /// [WorkspaceEvidenceController.currentIncident].
  final String? boundIncidentId;

  @override
  State<InvestigationWorkspaceScreen> createState() =>
      InvestigationWorkspaceScreenState();
}

class InvestigationWorkspaceScreenState
    extends State<InvestigationWorkspaceScreen> {
  late final InvestigationCanvasController _canvasController;
  late final InvestigationCoachingController _coachingController;
  late final RiskCoachController _riskCoachController;
  TimelineWorkspaceFilter _timelineFilter = TimelineWorkspaceFilter.all;
  final Set<int> _visitedTabs = {};
  final GlobalKey _coachPocketKey = GlobalKey();
  Set<String> _reviewHaloEvidenceIds = const {};

  WorkspaceEvidenceController get _controller => widget.controller;

  String get _boundIncidentId {
    if (widget.boundIncidentId != null) {
      return widget.boundIncidentId!.trim();
    }
    return _controller.currentIncident.id;
  }

  bool get _sessionMatchesBound => InvestigateIncidentScope.sessionMatchesBound(
    _boundIncidentId,
    _controller.currentIncident.id,
  );

  bool _writeOwnsSnapshot(String boundIncidentIdAtStart) {
    return InvestigateIncidentScope.sessionMatchesBound(
      boundIncidentIdAtStart,
      _controller.currentIncident.id,
    );
  }

  CurrentIncident get _presentedIncident =>
      InvestigateIncidentScope.presentation(
        _controller.currentIncident,
        _boundIncidentId,
      );

  List<RelationshipGroup> get _boundGroups =>
      InvestigateIncidentScope.relationshipGroups(
        _controller.currentIncident.relationshipGroups,
        _boundIncidentId,
      );

  List<ReflectionModel> get _notes => _controller.sortedReflections;

  List<WorkspaceEvidenceItem> get _items => InvestigateIncidentScope.evidence(
    _controller.state.items,
    _boundIncidentId,
  );

  List<TimelineAnchorNode> get _timelineNodes =>
      InvestigateIncidentScope.timeline(
        _controller.anchoredTimeline,
        _boundIncidentId,
      );

  List<ConnectionGroupNode> get _connectionNodes =>
      InvestigateIncidentScope.connections(
        _controller.connectionGroupNodes,
        _boundIncidentId,
      );

  InvestigationGraphView get _graph => InvestigateIncidentScope.graph(
    _controller.investigationGraph,
    _boundIncidentId,
  );

  List<NarrativeEventViewModel> get _narrativeEvents =>
      InvestigateIncidentScope.reconstruction(
        _controller.narrativeEvents,
        _boundIncidentId,
      );

  NarrativeReconstructionHealth get _reconstructionHealth =>
      NarrativeValidationService.computeReconstructionHealth(
        _narrativeEvents
            .map((event) => event.validation)
            .toList(growable: false),
      );

  @override
  void initState() {
    super.initState();
    _canvasController =
        widget.canvasController ??
        WorkspaceSession.instance.obtainInvestigationCanvasController(
          initialTab: widget.initialTab,
        );
    _coachingController = InvestigationCoachingController(
      controller: _controller,
    );
    _riskCoachController = RiskCoachController(controller: _controller);
    if (widget.canvasController != null &&
        widget.canvasController!.state.activeTab != widget.initialTab) {
      _canvasController.setActiveTab(widget.initialTab);
    }

    if (!widget.embeddedInShell) {
      WorkspaceSession.instance.setActiveStage(
        InvestigationMethodologyStage.investigation,
        investigationTab: _canvasController.state.activeTab,
      );
      WorkspaceSession.instance.resumeTarget =
          WorkspaceResumeTarget.incidentWorkspace;
    }
    _visitedTabs.add(_canvasController.state.activeTab.index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ensureInvestigationRelationshipsIfBound();
    });
  }

  /// Bound-workspace relationship init. Skips when session ≠ bound.
  /// Does not call [RelationshipEngine.ensureRelationships] directly.
  @visibleForTesting
  void ensureInvestigationRelationshipsIfBound() {
    if (!_sessionMatchesBound) {
      return;
    }
    _controller.ensureInvestigationRelationships();
  }

  @override
  void dispose() {
    _riskCoachController.dispose();
    _coachingController.dispose();
    super.dispose();
  }

  void _refreshAfterMutation() {
    _coachingController.refresh();
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTimelineAnchorSelected(String anchorId) {
    _canvasController.selectTimelineAnchor(
      anchorId: anchorId,
      groups: _boundGroups,
      notes: _notes,
      items: _items,
      timelineNodes: _timelineNodes,
      narrativeEvents: _narrativeEvents,
    );
  }

  void _handleEvidenceSelected(WorkspaceEvidenceItem evidence) {
    _canvasController.selectEvidence(
      evidence: evidence,
      groups: _boundGroups,
      groupNodes: _connectionNodes,
      notes: _notes,
      items: _items,
      timelineNodes: _timelineNodes,
      narrativeEvents: _narrativeEvents,
    );
    _showEvidenceInspector(evidence);
  }

  Future<void> _showEvidenceInspector(WorkspaceEvidenceItem evidence) async {
    final incidentId = _boundIncidentId;
    if (!evidence.belongsToIncident(incidentId)) {
      debugPrint(
        '[Workspace] inspector blocked — evidence not bound to workspace\n'
        'EXPECTED INCIDENT:\n$incidentId\n\n'
        'ACTUAL INCIDENT:\n${evidence.incidentId}\n\n'
        'EXPECTED EVIDENCE:\n(owned by $incidentId)\n\n'
        'ACTUAL EVIDENCE:\n${evidence.id}',
      );
      return;
    }
    if (await OpenEvidencePresentation.openPdfIfNeeded(context, evidence)) {
      _refreshAfterMutation();
      return;
    }
    if (!mounted) {
      return;
    }
    final opener = widget.onShowEvidenceInspector;
    if (opener != null) {
      await opener(evidence);
    } else {
      await showInvestigationEvidenceInspectorModal(
        context: context,
        evidence: evidence,
        controller: _controller,
        boundIncidentId: incidentId,
        orderedEvidence: evidenceInspectorOrder(
          _controller.journeyEvidenceItems,
          incidentId: incidentId,
        ),
        onOpenAdvancedRecord: widget.onOpenFullEvidenceRecord,
      );
    }
    _refreshAfterMutation();
  }

  Widget _buildTimelineWorkspace() {
    final canvasState = _canvasController.state;
    final timelineNodes = _timelineNodes;
    final highlightedAnchors =
        InvestigationCanvasSyncEngine.highlightedTimelineAnchorIds(
          state: canvasState,
          groupNodes: _connectionNodes,
          notes: _notes,
          items: _items,
          groups: _boundGroups,
          timelineNodes: timelineNodes,
          narrativeEvents: _narrativeEvents,
        );

    return TimelineWorkspace(
      nodes: timelineNodes,
      selectedFilter: _timelineFilter,
      onFilterSelected: (filter) => setState(() => _timelineFilter = filter),
      incidentName: _presentedIncident.title,
      timelineAnchorCount: _presentedIncident.timelineAnchorCount,
      supportingEvidenceCount: _presentedIncident.evidence
          .where((item) => item.isSupportingEvidence)
          .length,
      relationshipGroupCount: _presentedIncident.relationshipGroupCount,
      highlightedAnchorIds: highlightedAnchors,
      onAnchorSelected: _handleTimelineAnchorSelected,
      onCapturedTap: _handleEvidenceSelected,
      onSupportingTap: _handleEvidenceSelected,
      resolveParticipantName: (participantId) =>
          _controller.participantDisplayName(participantId),
    );
  }

  Widget _buildGraphWorkspace() {
    return InvestigationGraphWorkspace(
      graph: _graph,
      organizeCreatedIds: _controller.organizeCreatedEvidenceIds,
      contextAnchors: _controller.organizeContextAnchors,
      onEvidenceTap: _handleEvidenceSelected,
    );
  }

  Widget _buildConnectionsWorkspace() {
    return ConnectionsWorkspace(
      incidentId: _boundIncidentId,
      evidence: InvestigateIncidentScope.evidence(_items, _boundIncidentId),
      relationships: InvestigateIncidentScope.relationships(
        _controller.state.relationships,
        _items,
        _boundIncidentId,
      ),
      collections: InvestigateIncidentScope.collections(
        _controller.currentIncident.evidenceCollections,
        _boundIncidentId,
      ),
      onEvidenceTap: _handleEvidenceSelected,
    );
  }

  Widget _buildReconstructionWorkspace() {
    return ReconstructionWorkspace(
      incidentId: _boundIncidentId,
      evidence: _items,
      collections: InvestigateIncidentScope.collections(
        _controller.currentIncident.evidenceCollections,
        _boundIncidentId,
      ),
      organizeCreatedIds: _controller.organizeCreatedEvidenceIds,
      contextAnchors: _controller.organizeContextAnchors,
      onEvidenceTap: _handleEvidenceSelected,
    );
  }

  @visibleForTesting
  void applyIncidentName(String name) {
    final boundIncidentIdAtStart = _boundIncidentId;
    if (!_writeOwnsSnapshot(boundIncidentIdAtStart) ||
        _controller.isArchivedReadOnly) {
      return;
    }
    _controller.updateIncidentName(name);
  }

  @visibleForTesting
  void applySetPrimaryEvidence(String evidenceId, bool isPrimary) {
    if (!_sessionMatchesBound) {
      return;
    }
    _controller.setPrimaryEvidence(
      evidenceId: evidenceId,
      isPrimary: isPrimary,
    );
    _refreshAfterMutation();
  }

  @visibleForTesting
  void applyCommitRelationshipGroup(List<String> evidenceIds) {
    if (!_sessionMatchesBound) {
      return;
    }
    _controller.commitRelationshipGroup(evidenceIds: evidenceIds);
    _refreshAfterMutation();
  }

  @visibleForTesting
  void applyNarrativeEventTitle(String eventId, String title) {
    if (!_sessionMatchesBound) {
      return;
    }
    _controller.updateNarrativeEventTitle(eventId: eventId, title: title);
    _refreshAfterMutation();
  }

  @visibleForTesting
  void applyNarrativeEventSummary(String eventId, String? summary) {
    if (!_sessionMatchesBound) {
      return;
    }
    _controller.updateNarrativeEventSummary(eventId: eventId, summary: summary);
    _refreshAfterMutation();
  }

  @visibleForTesting
  void applyMoveNarrativeEventUp(String eventId) {
    if (!_sessionMatchesBound) {
      return;
    }
    _controller.moveNarrativeEventUp(eventId: eventId);
    _refreshAfterMutation();
  }

  @visibleForTesting
  void applyMoveNarrativeEventDown(String eventId) {
    if (!_sessionMatchesBound) {
      return;
    }
    _controller.moveNarrativeEventDown(eventId: eventId);
    _refreshAfterMutation();
  }

  @visibleForTesting
  void applyInsertNarrativeEventBefore(String eventId, String beforeEventId) {
    if (!_sessionMatchesBound) {
      return;
    }
    _controller.insertNarrativeEventBefore(
      eventId: eventId,
      beforeEventId: beforeEventId,
    );
    _refreshAfterMutation();
  }

  @visibleForTesting
  void applyInsertNarrativeEventAfter(String eventId, String afterEventId) {
    if (!_sessionMatchesBound) {
      return;
    }
    _controller.insertNarrativeEventAfter(
      eventId: eventId,
      afterEventId: afterEventId,
    );
    _refreshAfterMutation();
  }

  void _handleNarrativeEventSelected(NarrativeEventViewModel event) {
    _canvasController.selectNarrativeSection(
      sectionId: event.event.id,
      notes: _notes,
      items: _items,
      groups: _boundGroups,
      timelineNodes: _timelineNodes,
      narrativeEvents: _narrativeEvents,
    );
  }

  void _handleRiskCoachAction(IncidentRiskAssessment assessment) {
    unawaited(_riskCoachController.markReviewed(assessment.id));
    switch (assessment.recommendedAction) {
      case RiskRecommendedAction.addEvidence:
        if (widget.embeddedInShell) {
          InvestigationJourneyNavigation.switchStageInShell(
            stage: InvestigationMethodologyStage.capture,
            canvasController: _canvasController,
          );
        } else {
          InvestigationJourneyNavigation.navigateToStage(
            context,
            stage: InvestigationMethodologyStage.capture,
            activeStage: WorkspaceSession.instance.activeMethodologyStage,
            controller: _controller,
            onOpenFullEvidenceRecord: widget.onOpenFullEvidenceRecord,
            canvasController: _canvasController,
          );
        }
        return;
      case RiskRecommendedAction.reviewEvidence:
        if (_items.isNotEmpty && assessment.sourceEvidenceIds.isNotEmpty) {
          final match = _items.where(
            (entry) => entry.id == assessment.sourceEvidenceIds.first,
          );
          _handleEvidenceSelected(
            match.isNotEmpty ? match.first : _items.first,
          );
        }
        _canvasController.setActiveTab(InvestigationWorkspaceTab.timeline);
        break;
      case RiskRecommendedAction.reviewInvestigation:
      case RiskRecommendedAction.addFollowUp:
        _canvasController.setActiveTab(InvestigationWorkspaceTab.graph);
        WorkspaceSession.instance.setActiveStage(
          InvestigationMethodologyStage.investigation,
          investigationTab: InvestigationWorkspaceTab.graph,
        );
        break;
      case RiskRecommendedAction.dismiss:
        unawaited(_riskCoachController.dismiss(assessment.id));
        return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _handleCoachingReview(InvestigationCoachingItem item) {
    final haloIds = <String>{...item.reviewEvidenceIds};
    if (item.targetEventId != null) {
      for (final event in _narrativeEvents) {
        if (event.event.id == item.targetEventId) {
          haloIds.addAll(event.displayEvidence.map((entry) => entry.id));
        }
      }
    }
    setState(() => _reviewHaloEvidenceIds = haloIds);

    final target = item.target;
    final methodologyStage = target.methodologyStage;
    final investigationTab = target.investigationTab;

    if (methodologyStage != InvestigationMethodologyStage.investigation) {
      if (widget.embeddedInShell) {
        InvestigationJourneyNavigation.switchStageInShell(
          stage: methodologyStage!,
          canvasController: _canvasController,
        );
      } else {
        InvestigationJourneyNavigation.navigateToStage(
          context,
          stage: methodologyStage!,
          activeStage: WorkspaceSession.instance.activeMethodologyStage,
          controller: _controller,
          onOpenFullEvidenceRecord: widget.onOpenFullEvidenceRecord,
          canvasController: _canvasController,
        );
      }
      return;
    }

    if (investigationTab != null &&
        _canvasController.state.activeTab != investigationTab) {
      _canvasController.setActiveTab(investigationTab);
      WorkspaceSession.instance.setActiveStage(
        InvestigationMethodologyStage.investigation,
        investigationTab: investigationTab,
      );
    }

    if (item.targetAnchorId != null) {
      _handleTimelineAnchorSelected(item.targetAnchorId!);
    } else if (item.targetEventId != null) {
      final event = _narrativeEvents.firstWhere(
        (entry) => entry.event.id == item.targetEventId,
        orElse: () => _narrativeEvents.first,
      );
      _handleNarrativeEventSelected(event);
    } else if (item.targetEvidenceId != null) {
      final evidence = _items.firstWhere(
        (entry) => entry.id == item.targetEvidenceId,
        orElse: () => _items.first,
      );
      _handleEvidenceSelected(evidence);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handleCoachRestore(InvestigationCoachingItem item) {
    _coachingController.restore(item.fingerprint);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final currentIncident = _presentedIncident;
        final workspace = CoachReviewHaloScope(
          evidenceIds: _reviewHaloEvidenceIds,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.xs,
              AppSpacing.screenHorizontal,
              0,
            ),
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final topMaxHeight = constraints.maxHeight.isFinite
                        ? constraints.maxHeight * 0.28
                        : 220.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: topMaxHeight),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.embeddedInShell)
                                  const InvestigationStageHeader(),
                                InvestigationHeader(
                                  key: ValueKey(currentIncident.id),
                                  incidentName: currentIncident.title,
                                  journeyStage: currentIncident.journeyStage,
                                  timelineAnchorCount:
                                      currentIncident.timelineAnchorCount,
                                  relationshipGroupCount:
                                      currentIncident.relationshipGroupCount,
                                  narrativeEventCount:
                                      currentIncident.narrativeEventCount,
                                  reconstructionHealth: _reconstructionHealth,
                                  onIncidentNameChanged:
                                      _controller.isArchivedReadOnly
                                      ? null
                                      : applyIncidentName,
                                ),
                                if (_sessionMatchesBound) ...[
                                  InvestigationCoachingPanel(
                                    controller: _coachingController,
                                    onReview: _handleCoachingReview,
                                    pocketKey: _coachPocketKey,
                                  ),
                                  RiskCoachPanel(
                                    controller: _riskCoachController,
                                    onAction: _handleRiskCoachAction,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        ListenableBuilder(
                          listenable: _canvasController,
                          builder: (context, _) {
                            return InvestigationWorkspaceTabBar(
                              activeTab: _canvasController.state.activeTab,
                              onTabSelected: (tab) {
                                _canvasController.setActiveTab(tab);
                                WorkspaceSession.instance.setActiveStage(
                                  InvestigationMethodologyStage.investigation,
                                  investigationTab: tab,
                                );
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                            );
                          },
                        ),
                        Expanded(
                          child: ListenableBuilder(
                            listenable: _canvasController,
                            builder: (context, _) {
                              final activeIndex =
                                  _canvasController.state.activeTab.index;
                              _visitedTabs.add(activeIndex);
                              return InvestigationWorkspaceTabStack(
                                activeIndex: activeIndex,
                                visitedIndexes: _visitedTabs,
                                children: [
                                  _visitedTabs.contains(
                                        InvestigationWorkspaceTab
                                            .timeline
                                            .index,
                                      )
                                      ? _buildTimelineWorkspace()
                                      : const SizedBox.shrink(),
                                  _visitedTabs.contains(
                                        InvestigationWorkspaceTab.graph.index,
                                      )
                                      ? _buildGraphWorkspace()
                                      : const SizedBox.shrink(),
                                  _visitedTabs.contains(
                                        InvestigationWorkspaceTab
                                            .connections
                                            .index,
                                      )
                                      ? _buildConnectionsWorkspace()
                                      : const SizedBox.shrink(),
                                  _visitedTabs.contains(
                                        InvestigationWorkspaceTab
                                            .reconstruction
                                            .index,
                                      )
                                      ? _buildReconstructionWorkspace()
                                      : const SizedBox.shrink(),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: InvestigationCoachPocket(
                    key: _coachPocketKey,
                    controller: _coachingController,
                    onRestore: _handleCoachRestore,
                  ),
                ),
              ],
            ),
          ),
        );

        if (widget.embeddedInShell) {
          return workspace;
        }

        return SpaceCanvas(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              foregroundColor: AppColors.onCanvas,
              leading: const AppBackButton(color: AppColors.onCanvas),
              title: Text(
                'Investigation Workspace',
                style: AppTextStyles.screenTitle.copyWith(
                  color: AppColors.onCanvas,
                ),
                maxLines: 2,
                softWrap: true,
              ),
            ),
            body: SafeArea(child: workspace),
          ),
        );
      },
    );
  }
}
