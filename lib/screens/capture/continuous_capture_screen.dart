import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../controllers/workspace_evidence_controller.dart';
import '../../controllers/workspace_session.dart';
import '../../diagnostics/file_p0_trace.dart';
import '../../diagnostics/sprint6c_file_trace.dart';
import '../../domain/capture/capture_session.dart';
import '../../domain/capture/capture_session_status.dart';
import '../../models/investigation_methodology_stage.dart';
import '../../models/workspace_capture_mode.dart';
import '../../models/workspace_evidence_item.dart';
import '../../models/workspace_resume_target.dart';
import '../../navigation/app_navigation.dart';
import '../../navigation/app_navigator.dart';
import '../../presentation/open_evidence_presentation.dart';
import '../../services/capture/capture_session_manager.dart';
import '../../services/storage/file_attach_flow.dart';
import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/capture/capture_sticky_bar.dart';
import '../../widgets/capture/cockpit_incident_header.dart';
import '../../widgets/capture/live_evidence_timeline.dart';
import '../../widgets/capture/text_note_capture_sheet.dart';
import '../../widgets/capture/workspace_preserving_status.dart';
import '../../widgets/common/app_snackbar.dart';
import '../../widgets/common/space_canvas.dart';
import '../../widgets/investigation/investigate_incident_scope.dart';
import '../../widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'capture_cockpit_screen.dart';

/// Primary Incident Workspace — continuous capture hub for one incident.
///
/// Home Capture Now (after Cockpit) and Continue Preserving open this screen.
/// Photo / Video / Voice from the sticky bar push [CaptureCockpitScreen] and
/// return here on exit. Organize / Investigation / Trust Pack remain reachable
/// without replacing this as the primary incident home.
///
/// [CaptureSession] remains an internal grouping/recovery concept. The UI
/// never exposes timers, pause/resume, or session lifecycle language.
class ContinuousCaptureScreen extends StatefulWidget {
  const ContinuousCaptureScreen({super.key, this.initialMode, this.controller});

  /// Retained for API compatibility; Cockpit is not auto-opened from Workspace.
  final WorkspaceCaptureMode? initialMode;
  final WorkspaceEvidenceController? controller;

  /// Opens the Incident Workspace (this screen).
  ///
  /// Does not auto-enter Capture Cockpit. Capture Now opens Cockpit from Home
  /// before this route; sticky-bar modalities open Cockpit explicitly.
  static Future<void> open(
    BuildContext context, {
    WorkspaceCaptureMode? initialMode,
    bool beginNewIncident = false,
  }) async {
    final session = WorkspaceSession.instance;
    final manager = CaptureSessionManager.instance;
    final userId = UserSessionService.account?.userId ?? '';

    if (beginNewIncident) {
      // Capture Now callers that still use this flag always start a new incident.
      await session.beginNewCaptureIncident();
    } else if (!kIsWeb &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        await session.ensureLocalHydrateSettled().timeout(
          const Duration(seconds: 3),
        );
      } on TimeoutException {
        debugPrint(
          '[Workspace] local hydrate wait timed out before Capture hub',
        );
      } catch (error) {
        debugPrint('[Workspace] local hydrate wait failed: $error');
      }
    }

    final incidentId = session.controller.currentIncident.id;
    final open = manager.getOpenSession(incidentId);
    if (open?.status == CaptureSessionStatus.paused) {
      await manager.resumeSession(sessionId: open!.id);
    } else {
      await manager.getOrCreateActiveSession(
        incidentId: incidentId,
        userId: userId,
      );
    }
    if (!context.mounted) {
      // SAF / async session work can unmount the originating context. Still
      // open Workspace via the root navigator so File never lands on Home.
      FileP0Trace.step(
        'CONTINUOUS_OPEN_UNMOUNTED_FALLBACK',
        incidentId: incidentId,
        mounted: false,
      );
      Sprint6cFileTrace.workspace(
        'ContinuousCaptureScreen.open context unmounted — '
        'ensureWorkspaceVisible fallback',
      );
      await FileAttachFlow.ensureWorkspaceVisible(
        buildWorkspace: () => ContinuousCaptureScreen(
          initialMode: initialMode,
          controller: WorkspaceSession.instance.controller,
        ),
      );
      return;
    }

    session.resumeTarget = WorkspaceResumeTarget.incidentWorkspace;
    session.enterCapture();

    Sprint6cFileTrace.workspace('push ContinuousCapture incident=$incidentId');
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'ContinuousCaptureScreen'),
        builder: (_) => ContinuousCaptureScreen(initialMode: initialMode),
      ),
    );
  }

  @override
  State<ContinuousCaptureScreen> createState() =>
      _ContinuousCaptureScreenState();
}

class _ContinuousCaptureScreenState extends State<ContinuousCaptureScreen> {
  bool _busy = false;
  final ScrollController _timelineScroll = ScrollController();
  int _lastTimelineLength = 0;
  late final String _boundIncidentId;

  WorkspaceEvidenceController get _controller =>
      widget.controller ?? WorkspaceSession.instance.controller;

  bool get _isFlutterTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  CaptureSession? get _session {
    final incidentId = _controller.currentIncident.id;
    return CaptureSessionManager.instance.getOpenSession(incidentId) ??
        CaptureSessionManager.instance.getActiveSession(incidentId);
  }

  bool get _canCapture => !_busy;

  @override
  void initState() {
    super.initState();
    _boundIncidentId = _controller.currentIncident.id;
    FileAttachFlow.workspaceRouteVisible = true;
    FileP0Trace.step(
      'WORKSPACE_INIT',
      incidentId: _controller.currentIncident.id,
      extra: 'route=ContinuousCaptureScreen',
    );
    Sprint6cFileTrace.workspace(
      'ContinuousCapture INIT '
      'incident=${_controller.currentIncident.id}',
    );
    if (_isFlutterTest) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureInternalSession();
    });
  }

  @override
  void dispose() {
    FileP0Trace.step(
      'WORKSPACE_DISPOSE',
      incidentId: _controller.currentIncident.id,
      extra:
          'attachInProgress=${FileAttachFlow.attachInProgress} '
          '← if mid-picker, Workspace was torn down',
    );
    FileAttachFlow.workspaceRouteVisible = false;
    Sprint6cFileTrace.workspace(
      'ContinuousCapture DISPOSE '
      'incident=${_controller.currentIncident.id} '
      '← if this fires mid-picker, Workspace was torn down',
    );
    _timelineScroll.dispose();
    super.dispose();
  }

  Future<void> _ensureInternalSession() async {
    final incidentId = _controller.currentIncident.id;
    final userId = UserSessionService.account?.userId ?? '';
    final open = CaptureSessionManager.instance.getOpenSession(incidentId);
    if (open?.status == CaptureSessionStatus.paused) {
      await CaptureSessionManager.instance.resumeSession(sessionId: open!.id);
    } else {
      await CaptureSessionManager.instance.getOrCreateActiveSession(
        incidentId: incidentId,
        userId: userId,
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Chronological ascending — oldest at top, newest at bottom.
  ///
  /// Always the full incident journey. CaptureSession.evidenceIds is only an
  /// internal grouping/recovery list for the *current* capturing burst — after
  /// Continue Preserving it often contains only newly captured ids. Filtering
  /// the Workspace timeline to that subset made prior evidence disappear after
  /// Cockpit exit even though the controller still held E1…En.
  List<WorkspaceEvidenceItem> _timelineItems() {
    final items = List<WorkspaceEvidenceItem>.of(
      _controller.journeyEvidenceItems.where(
        (item) => item.belongsToIncident(_boundIncidentId),
      ),
    );
    items.sort((a, b) => a.lastPreservedAt.compareTo(b.lastPreservedAt));
    return items;
  }

  Future<void> _openEvidenceInspector(WorkspaceEvidenceItem evidence) async {
    if (!mounted) {
      return;
    }
    if (!evidence.belongsToIncident(_boundIncidentId)) {
      debugPrint(
        '[Workspace] inspector blocked — evidence not bound to workspace\n'
        'EXPECTED INCIDENT:\n$_boundIncidentId\n\n'
        'ACTUAL INCIDENT:\n${evidence.incidentId}\n\n'
        'EXPECTED EVIDENCE:\n(owned by $_boundIncidentId)\n\n'
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
    final ordered = _timelineItems();
    await showInvestigationEvidenceInspectorModal(
      context: context,
      evidence: evidence,
      controller: _controller,
      boundIncidentId: _boundIncidentId,
      orderedEvidence: ordered,
    );
  }

  void _scrollToNewestIfGrew(int length) {
    if (length <= _lastTimelineLength) {
      _lastTimelineLength = length;
      return;
    }
    _lastTimelineLength = length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_timelineScroll.hasClients) {
        return;
      }
      _timelineScroll.animateTo(
        _timelineScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _runCapture(WorkspaceCaptureMode mode) async {
    final boundIncidentIdAtStart = _boundIncidentId;
    if (!_canCapture ||
        !InvestigateIncidentScope.sessionMatchesBound(
          boundIncidentIdAtStart,
          _controller.currentIncident.id,
        )) {
      return;
    }
    setState(() => _busy = true);
    try {
      // Always keep an internal ACTIVE session for grouping — invisible to UI.
      if (_session?.status != CaptureSessionStatus.active) {
        await _ensureInternalSession();
      }
      // File attach continues even if this State was disposed during session
      // ensure (SAF). Other modalities still need a mounted surface.
      if (!mounted && mode != WorkspaceCaptureMode.file) {
        Sprint6cFileTrace.workspace(
          '_runCapture($mode) abort — unmounted after ensureSession',
        );
        return;
      }

      bool operationOwnsBound() => InvestigateIncidentScope.sessionMatchesBound(
        boundIncidentIdAtStart,
        _controller.currentIncident.id,
      );

      if (_isFlutterTest) {
        if (!operationOwnsBound()) {
          return;
        }
        if (mode == WorkspaceCaptureMode.note) {
          await _controller.preserveTextNote('Preserved note');
        } else if (mode == WorkspaceCaptureMode.photo ||
            mode == WorkspaceCaptureMode.video ||
            mode == WorkspaceCaptureMode.voice) {
          await CaptureCockpitScreen.open(
            context,
            initialMode: mode,
            controller: _controller,
            boundIncidentId: boundIncidentIdAtStart,
          );
        } else if (mode == WorkspaceCaptureMode.file) {
          _controller.preserveForWidgetTest(WorkspaceCaptureMode.file);
        } else {
          await _controller.preserveEvidenceWithMedia(mode: mode);
        }
        return;
      }

      if (mode == WorkspaceCaptureMode.note) {
        final text = await TextNoteCaptureSheet.open(context);
        if (!mounted || text == null || text.trim().isEmpty) {
          return;
        }
        if (!operationOwnsBound()) {
          return;
        }
        await _controller.preserveTextNote(text);
        return;
      }

      if (mode == WorkspaceCaptureMode.photo ||
          mode == WorkspaceCaptureMode.video ||
          mode == WorkspaceCaptureMode.voice) {
        if (!mounted || !operationOwnsBound()) {
          return;
        }
        await CaptureCockpitScreen.open(
          context,
          initialMode: mode,
          controller: _controller,
          boundIncidentId: boundIncidentIdAtStart,
        );
        return;
      }

      // File: do NOT abort on !mounted — picker/persist are session-scoped.
      if (mode == WorkspaceCaptureMode.file) {
        final sourceIncidentId = _controller.currentIncident.id;
        try {
          final result = await FileAttachFlow.attach(
            origin: FileAttachOrigin.workspaceSticky,
            context: mounted ? context : null,
            buildWorkspace: () => ContinuousCaptureScreen(
              controller: WorkspaceSession.instance.controller,
            ),
          );
          if (result.outcome == FileAttachOutcome.failed) {
            final msg =
                result.userMessage ?? 'Couldn’t attach that file. Try again.';
            final snackCtx = mounted ? context : appNavigatorKey.currentContext;
            if (snackCtx != null && snackCtx.mounted) {
              AppSnackBar.showError(snackCtx, msg);
            }
          }
          assert(
            result.sourceIncidentId == sourceIncidentId ||
                result.outcome != FileAttachOutcome.succeeded,
            'Workspace File must keep the same incident',
          );
          return;
        } catch (error, stack) {
          FileP0Trace.failure(
            'WORKSPACE_FILE_CAPTURE',
            error: error,
            stackTrace: stack,
            mounted: mounted,
          );
          Sprint6cFileTrace.file('_runCapture(file) error: $error');
          final snackCtx = mounted ? context : appNavigatorKey.currentContext;
          if (snackCtx != null && snackCtx.mounted) {
            AppSnackBar.showError(
              snackCtx,
              'Couldn’t attach that file. Try again.',
            );
          }
          return;
        }
      }
    } catch (error, stack) {
      if (mode == WorkspaceCaptureMode.file) {
        FileP0Trace.failure(
          'WORKSPACE_FILE_CAPTURE',
          error: error,
          stackTrace: stack,
          mounted: mounted,
        );
      }
      Sprint6cFileTrace.file('_runCapture($mode) error: $error');
      if (mounted && mode == WorkspaceCaptureMode.file) {
        AppSnackBar.showError(context, 'Couldn’t attach that file. Try again.');
      }
    } finally {
      final incidentId = _controller.currentIncident.id;
      await CaptureSessionManager.instance.restoreForIncident(
        incidentId: incidentId,
        userId: UserSessionService.account?.userId,
      );
      if (mounted) {
        setState(() => _busy = false);
      } else {
        FileP0Trace.step(
          'WORKSPACE_CAPTURE_FINALLY_UNMOUNTED',
          incidentId: incidentId,
          mounted: false,
          extra: 'mode=$mode',
        );
        Sprint6cFileTrace.workspace(
          '_runCapture($mode) finally — UNMOUNTED (Workspace gone)',
        );
      }
    }
  }

  void _saveTitle(String title) {
    // Identity guard: only rename the incident this header was bound to.
    final boundId = _boundIncidentId;
    if (boundId.isEmpty || _controller.currentIncident.id != boundId) {
      return;
    }
    _controller.updateIncidentName(title);
  }

  Future<void> _openMethodologyStage(
    InvestigationMethodologyStage stage,
  ) async {
    await AppNavigation.openIncidentWorkspace(context, initialStage: stage);
  }

  /// Next ends this preservation phase and continues into Organize.
  Future<void> _done() async {
    FileP0Trace.step(
      'WORKSPACE_NEXT_ORGANIZE',
      incidentId: _controller.currentIncident.id,
      mounted: mounted,
      extra: '← Capture → Organize for the same incident',
    );
    Sprint6cFileTrace.nav(
      'ContinuousCapture Next → Organize (same incident)',
    );
    final session = _session;
    if (session != null &&
        session.status != CaptureSessionStatus.completed &&
        session.status != CaptureSessionStatus.archived) {
      await CaptureSessionManager.instance.completeSession(
        sessionId: session.id,
      );
    }
    if (mounted) {
      await AppNavigation.openIncidentWorkspace(
        context,
        initialStage: InvestigationMethodologyStage.evidence,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FileAttachPopBarrier(
      child: ListenableBuilder(
        listenable: FileAttachFlow.attachLock,
        builder: (context, _) => PopScope(
          // Block SAF/system back while attach is in flight or still settling.
          canPop: !FileAttachFlow.blocksWorkspacePop,
          onPopInvokedWithResult: (didPop, result) {
            FileP0Trace.step(
              'WORKSPACE_POP_INVOKED',
              incidentId: _controller.currentIncident.id,
              mounted: mounted,
              result: didPop ? 'DID_POP' : 'BLOCKED',
              extra:
                  'attachInProgress=${FileAttachFlow.attachInProgress} '
                  'settling=${FileAttachFlow.fileAttachSettling} '
                  '← SYSTEM/APPBAR BACK SURFACES HOME UNDER Workspace',
            );
            Sprint6cFileTrace.nav(
              'ContinuousCapture onPopInvoked didPop=$didPop '
              'attachInProgress=${FileAttachFlow.attachInProgress} '
              'settling=${FileAttachFlow.fileAttachSettling} '
              '← SYSTEM/APPBAR BACK SURFACES HOME UNDER Workspace',
            );
          },
          child: SpaceCanvas(
          child: Scaffold(
          key: const Key('incident_workspace_screen'),
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(
              'Incident Workspace',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading.copyWith(color: AppColors.onCanvas),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.onCanvas,
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              PopupMenuButton<InvestigationMethodologyStage>(
                key: const Key('incident_workspace_journey_menu'),
                tooltip: 'Investigation journey',
                onSelected: (stage) => unawaited(_openMethodologyStage(stage)),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: InvestigationMethodologyStage.evidence,
                    child: Text('Organize'),
                  ),
                  const PopupMenuItem(
                    value: InvestigationMethodologyStage.investigation,
                    child: Text('Investigate'),
                  ),
                  const PopupMenuItem(
                    value: InvestigationMethodologyStage.trustPackage,
                    child: Text('Trust Package'),
                  ),
                ],
              ),
              TextButton(
                key: const Key('continuous_capture_done'),
                onPressed: _busy ? null : () => unawaited(_done()),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Next'),
              ),
            ],
          ),
          body: KeyedSubtree(
            key: const Key('continuous_capture_screen'),
            child: SafeArea(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final timeline = _timelineItems();
                  _scrollToNewestIfGrew(timeline.length);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WorkspacePreservingStatus(evidenceCount: timeline.length),
                      Expanded(
                        child: LiveEvidenceTimeline(
                          items: timeline,
                          scrollController: _timelineScroll,
                          onEvidenceTap: (item) =>
                              unawaited(_openEvidenceInspector(item)),
                        ),
                      ),
                      Material(
                        elevation: 4,
                        color: AppColors.captureSurface,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CockpitIncidentHeader(
                              // Recreate on incident switch so prior title text
                              // cannot save onto a new Capture Now id.
                              key: ValueKey(_boundIncidentId),
                              incidentTitle:
                                  _controller.currentIncident.id ==
                                      _boundIncidentId
                                  ? _controller.currentIncident.title
                                  : '',
                              enabled: _canCapture,
                              showPreservingLabel: false,
                              onTitleSaved: _saveTitle,
                            ),
                            CaptureStickyBar(
                              enabled: _canCapture,
                              onModalitySelected: (mode) =>
                                  unawaited(_runCapture(mode)),
                              onNoteTap: () => unawaited(
                                _runCapture(WorkspaceCaptureMode.note),
                              ),
                              onFileTap: () => unawaited(
                                _runCapture(WorkspaceCaptureMode.file),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
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

/// Live [PopEntry] so SAF/system [Navigator.maybePop] is blocked as soon as
/// [FileAttachFlow.blocksWorkspacePop] becomes true — without waiting a frame.
class _FileAttachPopBarrier extends StatefulWidget {
  const _FileAttachPopBarrier({required this.child});

  final Widget child;

  @override
  State<_FileAttachPopBarrier> createState() => _FileAttachPopBarrierState();
}

class _FileAttachPopBarrierState extends State<_FileAttachPopBarrier>
    implements PopEntry<void> {
  ModalRoute<dynamic>? _route;

  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier<bool>(
    !FileAttachFlow.blocksWorkspacePop,
  );

  @override
  void initState() {
    super.initState();
    FileAttachFlow.attachLock.addListener(_syncCanPop);
    _syncCanPop();
  }

  void _syncCanPop() {
    final next = !FileAttachFlow.blocksWorkspacePop;
    if (canPopNotifier.value != next) {
      canPopNotifier.value = next;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route?.unregisterPopEntry(this);
      _route = route;
      _route?.registerPopEntry(this);
    }
  }

  @override
  void dispose() {
    FileAttachFlow.attachLock.removeListener(_syncCanPop);
    _route?.unregisterPopEntry(this);
    canPopNotifier.dispose();
    super.dispose();
  }

  @override
  void onPopInvoked(bool didPop) {}

  @override
  void onPopInvokedWithResult(bool didPop, void result) {}

  @override
  Widget build(BuildContext context) => widget.child;
}
