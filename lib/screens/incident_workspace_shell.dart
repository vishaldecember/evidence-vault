import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../controllers/workspace_evidence_controller.dart';
import '../controllers/workspace_session.dart';
import '../models/investigation_methodology_stage.dart';
import '../models/investigation_workspace_tab.dart';
import '../models/workspace_capture_mode.dart';
import '../models/workspace_resume_target.dart';
import '../navigation/investigation_journey_navigation.dart';
import '../presentation/open_evidence_presentation.dart';
import '../services/storage/file_attach_flow.dart';
import '../theme/app_colors.dart';
import '../widgets/common/app_back_button.dart';
import '../widgets/common/layered_card.dart';
import '../widgets/common/space_canvas.dart';
import '../widgets/investigation/investigation_journey_header.dart';
import '../widgets/evidence_inspector/evidence_spatial_carousel.dart';
import '../widgets/investigation/investigation_evidence_inspector_modal.dart';
import '../widgets/workspace/file_attach_pop_barrier.dart';
import '../domain/incident/incident_title.dart';
import '../services/persistence/incident_library_service.dart';
import '../widgets/workspace/incident_product_header.dart';
import '../widgets/workspace/incident_workspace_more_menu.dart';
import 'evidence_workspace_content.dart';
import 'investigation_workspace_screen.dart';
import 'trust_package_screen.dart';
import '../models/workspace_evidence_item.dart';
import '../widgets/workspace/workspace_body_presentation.dart';

/// Unified incident workspace shell with global product navigation.
///
/// Stages mount lazily on first visit so Home → Resume paints in under ~300ms
/// instead of building Capture + Evidence + Investigation + Trust up front.
class IncidentWorkspaceShell extends StatefulWidget {
  const IncidentWorkspaceShell({
    super.key,
    this.incidentId,
    this.initialCaptureMode,
    this.controller,
    this.initialStage,
    this.initialInvestigationTab,
  });

  /// Authoritative incident identity for this visible workspace route.
  ///
  /// [WorkspaceSession.controller] is the working set only. It must not
  /// override this id after the route is bound.
  ///
  /// When null, the shell stamps [WorkspaceEvidenceController.currentIncident]
  /// once in [initState] and keeps that id for the route lifetime.
  final String? incidentId;

  final WorkspaceCaptureMode? initialCaptureMode;
  final WorkspaceEvidenceController? controller;
  final InvestigationMethodologyStage? initialStage;
  final InvestigationWorkspaceTab? initialInvestigationTab;

  static IncidentWorkspaceShellState? of(BuildContext context) {
    final ancestor = context
        .findAncestorStateOfType<IncidentWorkspaceShellState>();
    if (ancestor != null) {
      return ancestor;
    }

    if (context is StatefulElement &&
        context.state is IncidentWorkspaceShellState) {
      return context.state as IncidentWorkspaceShellState;
    }

    return null;
  }

  @override
  State<IncidentWorkspaceShell> createState() => IncidentWorkspaceShellState();
}

class IncidentWorkspaceShellState extends State<IncidentWorkspaceShell> {
  late WorkspaceEvidenceController _controller;
  late Listenable _shellListenable;
  late String _boundIncidentId;
  final Map<InvestigationMethodologyStage, Widget> _stageCache = {};
  final Set<InvestigationMethodologyStage> _visitedStages = {};
  bool _groupCompositionFrozen = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? WorkspaceSession.instance.controller;
    _boundIncidentId = _resolveBoundIncidentId();
    _shellListenable = _buildShellListenable();
    final session = WorkspaceSession.instance;

    if (widget.initialStage != null) {
      session.setActiveStage(
        widget.initialStage!,
        investigationTab: widget.initialInvestigationTab,
      );
    }

    session.resumeTarget = switch (session.activeMethodologyStage) {
      InvestigationMethodologyStage.trustPackage =>
        WorkspaceResumeTarget.trustPackageScreen,
      _ => WorkspaceResumeTarget.incidentWorkspace,
    };

    _visitedStages.add(session.activeMethodologyStage);
    FileAttachFlow.workspaceRouteVisible = true;
  }

  /// Incident this workspace route is bound to for its lifetime.
  @visibleForTesting
  String get boundIncidentId => _boundIncidentId;

  String _resolveBoundIncidentId() {
    final explicit = widget.incidentId?.trim() ?? '';
    if (explicit.isNotEmpty) {
      return explicit;
    }
    return _controller.currentIncident.id;
  }

  @override
  void dispose() {
    FileAttachFlow.workspaceRouteVisible = false;
    super.dispose();
  }

  Listenable _buildShellListenable() {
    // Stable merge per controller identity — recreating Listenable.merge every
    // build re-attaches listeners and can dispose mid-frame while dependents
    // still exist.
    return Listenable.merge([WorkspaceSession.instance, _controller]);
  }

  @override
  void didUpdateWidget(IncidentWorkspaceShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.controller ?? WorkspaceSession.instance.controller;
    if (!identical(next, _controller)) {
      _controller = next;
      _shellListenable = _buildShellListenable();
      _stageCache.clear();
      _visitedStages
        ..clear()
        ..add(WorkspaceSession.instance.activeMethodologyStage);
    }
    // Route-lifetime identity. Session controller swaps must not restamp it.
    // Only an explicit parent incidentId change restamps the bound id.
    if (widget.incidentId != oldWidget.incidentId) {
      _boundIncidentId = _resolveBoundIncidentId();
      _stageCache.clear();
    }
  }

  Widget _buildStage(InvestigationMethodologyStage stage) {
    return switch (stage) {
      InvestigationMethodologyStage.capture => EvidenceWorkspaceContent(
        key: ValueKey('capture-stage-$_boundIncidentId'),
        controller: _controller,
        boundIncidentId: _boundIncidentId,
        presentation: WorkspaceBodyPresentation.capture,
        initialCaptureMode: widget.initialCaptureMode,
        onShowEvidenceInspector: _showEvidenceInspector,
        onEnterInvestigation: () =>
            _handleStageSelected(InvestigationMethodologyStage.investigation),
        buildFileAttachWorkspace: _buildCaptureFileAttachWorkspace,
      ),
      InvestigationMethodologyStage.evidence => EvidenceWorkspaceContent(
        key: ValueKey('evidence-stage-$_boundIncidentId'),
        controller: _controller,
        boundIncidentId: _boundIncidentId,
        presentation: WorkspaceBodyPresentation.evidence,
        onShowEvidenceInspector: _showEvidenceInspector,
        onEnterInvestigation: _enterInvestigationConnections,
        buildFileAttachWorkspace: _buildOrganizeFileAttachWorkspace,
        onGroupCompositionChanged: (active) {
          if (_groupCompositionFrozen == active) {
            return;
          }
          setState(() {
            _groupCompositionFrozen = active;
          });
        },
      ),
      InvestigationMethodologyStage.investigation =>
        InvestigationWorkspaceScreen(
          key: ValueKey('investigation-stage-$_boundIncidentId'),
          controller: _controller,
          onShowEvidenceInspector: _showEvidenceInspector,
          onOpenFullEvidenceRecord: _openFullEvidenceRecord,
          initialTab: WorkspaceSession.instance.activeInvestigationTab,
          embeddedInShell: true,
          boundIncidentId: _boundIncidentId,
        ),
      InvestigationMethodologyStage.trustPackage => TrustPackageScreen(
        key: ValueKey('trust-package-stage-$_boundIncidentId'),
        controller: _controller,
        boundIncidentId: _boundIncidentId,
        onNavigateToInvestigation: () =>
            _handleStageSelected(InvestigationMethodologyStage.investigation),
        embeddedInShell: true,
      ),
    };
  }

  Widget _ensureStage(InvestigationMethodologyStage stage) {
    return _stageCache.putIfAbsent(stage, () => _buildStage(stage));
  }

  Widget _buildCaptureFileAttachWorkspace() {
    return IncidentWorkspaceShell(
      incidentId: _boundIncidentId,
      controller: _controller,
      initialStage: InvestigationMethodologyStage.capture,
    );
  }

  Widget _buildOrganizeFileAttachWorkspace() {
    return IncidentWorkspaceShell(
      incidentId: _boundIncidentId,
      controller: _controller,
      initialStage: InvestigationMethodologyStage.evidence,
    );
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
      return;
    }
    if (!mounted) {
      return;
    }
    await showInvestigationEvidenceInspectorModal(
      context: context,
      evidence: evidence,
      controller: _controller,
      boundIncidentId: incidentId,
      orderedEvidence: evidenceInspectorOrder(
        _controller.journeyEvidenceItems,
        incidentId: incidentId,
      ),
      onOpenAdvancedRecord: _openFullEvidenceRecord,
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openFullEvidenceRecord(WorkspaceEvidenceItem evidence) {
    return EvidenceWorkspaceContent.openEvidenceRecord(
      context: context,
      controller: _controller,
      evidence: evidence,
      boundIncidentId: _boundIncidentId,
      onStateChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  void _enterInvestigationConnections() {
    final session = WorkspaceSession.instance;
    session.setActiveStage(
      InvestigationMethodologyStage.investigation,
      investigationTab: InvestigationWorkspaceTab.connections,
    );
    InvestigationJourneyNavigation.switchStageInShell(
      stage: InvestigationMethodologyStage.investigation,
      canvasController: session.investigationCanvasController,
    );
  }

  void _handleStageSelected(InvestigationMethodologyStage stage) {
    if (stage == WorkspaceSession.instance.activeMethodologyStage) {
      return;
    }

    InvestigationJourneyNavigation.switchStageInShell(
      stage: stage,
      canvasController: WorkspaceSession.instance.investigationCanvasController,
    );
  }

  String _workspaceIncidentTitle() {
    final current = _controller.currentIncident;
    if (current.id == _boundIncidentId) {
      return current.displayTitle;
    }
    for (final summary in IncidentLibraryService.instance.summaries) {
      if (summary.id == _boundIncidentId) {
        return IncidentTitle.display(summary.title);
      }
    }
    return IncidentTitle.placeholder;
  }

  int _stageIndex(InvestigationMethodologyStage stage) {
    return InvestigationMethodologyStage.journeyOrder.indexOf(stage);
  }

  @override
  Widget build(BuildContext context) {
    return FileAttachPopBarrier(
      child: ListenableBuilder(
        listenable: FileAttachFlow.attachLock,
        builder: (context, _) => PopScope(
          canPop:
              !FileAttachFlow.blocksWorkspacePop && !_groupCompositionFrozen,
          child: ListenableBuilder(
            listenable: _shellListenable,
            builder: (context, _) {
              // Touch the shared collection so this shell rebuild participates in
              // CurrentIncident observation (Capture → Organize → Investigation → Trust).
              final _ = _controller.currentIncident.evidenceCount;
              final stage = WorkspaceSession.instance.activeMethodologyStage;
              _visitedStages.add(stage);

              final stageViews = [
                for (final candidate
                    in InvestigationMethodologyStage.journeyOrder)
                  if (_visitedStages.contains(candidate))
                    _ensureStage(candidate)
                  else
                    const SizedBox.shrink(),
              ];

              return SpaceCanvas(
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AbsorbPointer(
                          absorbing: _groupCompositionFrozen,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.screenHorizontal - 8,
                              AppSpacing.sm,
                              AppSpacing.screenHorizontal,
                              AppSpacing.xs,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Explicit back only when this shell was pushed (e.g. Home
                                // → Continue). Omit at root to avoid a no-op control.
                                if (Navigator.of(context).canPop())
                                  const AppBackButton(color: AppColors.onCanvas)
                                else
                                  const SizedBox(width: 48),
                                const Expanded(
                                  child: Center(child: IncidentProductHeader()),
                                ),
                                IncidentWorkspaceMoreMenu(
                                  incidentId: _boundIncidentId,
                                  title: _workspaceIncidentTitle(),
                                  controller: _controller,
                                  onDeleted: () {
                                    if (Navigator.of(context).canPop()) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        AbsorbPointer(
                          absorbing: _groupCompositionFrozen,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.screenHorizontal,
                              AppSpacing.xs,
                              AppSpacing.screenHorizontal,
                              AppSpacing.sm,
                            ),
                            child: LayeredCard(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.sm,
                                AppSpacing.sm,
                                AppSpacing.sm,
                                AppSpacing.xs,
                              ),
                              radius: AppSpacing.fieldRadius,
                              child: InvestigationJourneyHeader(
                                activeStage: stage,
                                onStageSelected: _handleStageSelected,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: RepaintBoundary(
                            child: IndexedStack(
                              index: _stageIndex(stage),
                              sizing: StackFit.expand,
                              children: stageViews,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
