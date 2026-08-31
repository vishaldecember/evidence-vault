import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../controllers/workspace_evidence_controller.dart';
import '../../controllers/workspace_session.dart';
import '../../domain/capture/capture_session_status.dart';
import '../../models/workspace_capture_mode.dart';
import '../../services/capture/capture_session_manager.dart';
import '../../services/user_session_service.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/capture/capture_cockpit_modality_bar.dart';
import '../../widgets/investigation/investigate_incident_scope.dart';
import 'continuous_capture_session.dart';

/// Capture Cockpit — temporary immersive Photo / Video / Voice capture mode.
///
/// Entered from Home Capture Now (before Workspace) or from the Incident
/// Workspace sticky bar ([ContinuousCaptureScreen]). Exiting does not complete
/// the internal [CaptureSession]. Note / File belong on the workspace, not here.
///
/// Ergonomics: DONE mid-right; Close stacked directly below DONE for one-thumb
/// reach. Title stays top-centered; preview expands between chrome bands.
class CaptureCockpitScreen extends StatefulWidget {
  const CaptureCockpitScreen({
    super.key,
    this.initialMode,
    this.controller,
    this.boundIncidentId,
  });

  final WorkspaceCaptureMode? initialMode;
  final WorkspaceEvidenceController? controller;

  /// Incident this cockpit was opened for. Writes must not remap after switch.
  final String? boundIncidentId;

  /// Title band height (below SafeArea top).
  static const double headerHeight = 48;

  /// Side control hit target (visual icon may be smaller).
  static const double sideControlSize = 52;

  /// DONE label needs a wider chip than the circular Close control.
  static const double doneControlWidth = 72;

  /// Inset from safe horizontal edge to the control column.
  static const double sideControlMargin = 10;

  /// Vertical gap between DONE and Close in the right stack.
  static const double sideControlStackGap = 12;

  /// Extra gutter so a ~5° tilted AABB does not cover the right control stack.
  static const double tiltClearance = 14;

  /// Minimal left gutter — Close no longer occupies the left edge.
  static const double leftPreviewGutter = 12;

  /// Right gutter reserved for the DONE + Close stack.
  static double rightChromeInset(BuildContext context) {
    return sideControlMargin +
        doneControlWidth +
        AppSpacing.xs +
        tiltClearance;
  }

  /// Left gutter — thin; frees width for a substantially larger preview.
  static double leftChromeInset(BuildContext context) {
    return leftPreviewGutter + tiltClearance * 0.35;
  }

  /// Max horizontal chrome used when a single inset is required.
  static double sideChromeInset(BuildContext context) {
    return rightChromeInset(context);
  }

  /// Pushes Capture Cockpit. Does not begin a new incident — callers own
  /// incident identity ([HomeScreen] Capture Now or Workspace sticky bar).
  static Future<void> open(
    BuildContext context, {
    WorkspaceCaptureMode? initialMode,
    WorkspaceEvidenceController? controller,
    String? boundIncidentId,
  }) async {
    final session = WorkspaceSession.instance;
    final manager = CaptureSessionManager.instance;
    final userId = UserSessionService.account?.userId ?? '';
    final evidence = controller ?? session.controller;

    final boundIncidentIdAtStart =
        (boundIncidentId ?? evidence.currentIncident.id).trim();
    final incidentId = boundIncidentIdAtStart;
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
      return;
    }
    if (!InvestigateIncidentScope.sessionMatchesBound(
      boundIncidentIdAtStart,
      evidence.currentIncident.id,
    )) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CaptureCockpitScreen(
          initialMode: initialMode,
          controller: controller,
          boundIncidentId: boundIncidentIdAtStart,
        ),
      ),
    );
  }

  static WorkspaceCaptureMode resolveInitialModality(
    WorkspaceCaptureMode? mode,
  ) {
    return switch (mode) {
      WorkspaceCaptureMode.video => WorkspaceCaptureMode.video,
      WorkspaceCaptureMode.voice => WorkspaceCaptureMode.voice,
      WorkspaceCaptureMode.photo ||
      WorkspaceCaptureMode.note ||
      WorkspaceCaptureMode.file ||
      null =>
        WorkspaceCaptureMode.photo,
    };
  }

  @override
  State<CaptureCockpitScreen> createState() => _CaptureCockpitScreenState();
}

class _CaptureCockpitScreenState extends State<CaptureCockpitScreen> {
  late WorkspaceCaptureMode _modality;
  late final String _boundIncidentIdAtOpen;
  bool _exiting = false;
  Future<void> Function()? _releaseMedia;
  Future<void> Function({bool finalizeActiveVoice})? _commitPending;

  WorkspaceEvidenceController get _controller =>
      widget.controller ?? WorkspaceSession.instance.controller;

  bool get _operationOwnsBound =>
      InvestigateIncidentScope.sessionMatchesBound(
        _boundIncidentIdAtOpen,
        _controller.currentIncident.id,
      );

  bool get _isFlutterTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  bool get _controlsEnabled => !_exiting;

  @override
  void initState() {
    super.initState();
    _boundIncidentIdAtOpen =
        (widget.boundIncidentId ?? _controller.currentIncident.id).trim();
    _modality = CaptureCockpitScreen.resolveInitialModality(widget.initialMode);
    if (!_isFlutterTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_ensureInternalSession());
      });
    }
  }

  Future<void> _ensureInternalSession() async {
    final incidentId = _boundIncidentIdAtOpen;
    if (!_operationOwnsBound) {
      return;
    }
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
  }

  void _switchModality(WorkspaceCaptureMode mode) {
    if (!_controlsEnabled || mode == _modality) {
      return;
    }
    if (!CaptureCockpitModalityBar.modalities.contains(mode)) {
      return;
    }
    // Commit completed preview before ValueKey dispose drops the session.
    unawaited(_switchModalityAfterCommit(mode));
  }

  Future<void> _switchModalityAfterCommit(WorkspaceCaptureMode mode) async {
    try {
      await _commitPending?.call(finalizeActiveVoice: false);
    } catch (error) {
      debugPrint('[Capture] modality-switch commit failed: $error');
    }
    if (!mounted || _exiting) {
      return;
    }
    // ValueKey on the child session forces dispose → camera/mic release, then
    // a fresh engine for the new modality — same controller / incident / session.
    setState(() => _modality = mode);
  }

  /// Leaves Cockpit after committing any completed pending capture.
  ///
  /// Preview is not durable evidence — DONE/Close must flush a completed
  /// preview through CaptureEngine before navigation. Active recordings are
  /// not fabricated into evidence. Awaits media release before pop so
  /// Workspace → Cockpit again does not reuse a stale camera/mic session.
  Future<void> _exitCockpit({bool finalizeActiveVoice = false}) async {
    if (_exiting) {
      return;
    }
    setState(() => _exiting = true);
    try {
      await _commitPending?.call(finalizeActiveVoice: finalizeActiveVoice);
    } catch (error) {
      debugPrint('[Capture] cockpit pending commit failed: $error');
    }
    if (!_isFlutterTest) {
      try {
        await _releaseMedia?.call();
      } catch (error) {
        debugPrint('[Capture] cockpit media release failed: $error');
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _sideControl({
    required Key key,
    required bool circular,
    required Widget child,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    final shape = circular
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(22));
    return Tooltip(
      message: tooltip,
      child: Material(
        key: key,
        color: Colors.black.withValues(alpha: 0.45),
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: SizedBox(
            width: circular
                ? CaptureCockpitScreen.sideControlSize
                : CaptureCockpitScreen.doneControlWidth,
            height: CaptureCockpitScreen.sideControlSize,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomBarHeight = CaptureCockpitModalityBar.preferredHeight(context);

    return Scaffold(
      key: const Key('capture_cockpit_screen'),
      backgroundColor: Colors.black,
      // No AppBar — title + right-edge DONE/Close stack in the body Stack.
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final leftInset = CaptureCockpitScreen.leftChromeInset(context);
            final rightInset = CaptureCockpitScreen.rightChromeInset(context);
            // DONE stays at ~50% height (unchanged ergonomic anchor).
            final doneTop = (constraints.maxHeight * 0.5) -
                (CaptureCockpitScreen.sideControlSize / 2);
            final closeTop = doneTop +
                CaptureCockpitScreen.sideControlSize +
                CaptureCockpitScreen.sideControlStackGap;
            // Align circular Close under DONE's horizontal center.
            final doneRight = CaptureCockpitScreen.sideControlMargin;
            final closeRight = doneRight +
                (CaptureCockpitScreen.doneControlWidth -
                        CaptureCockpitScreen.sideControlSize) /
                    2;

            return Stack(
              fit: StackFit.expand,
              children: [
                ContinuousCaptureSession(
                  key: ValueKey<String>('cockpit-modality-${_modality.name}'),
                  controller: _controller,
                  boundIncidentId: _boundIncidentIdAtOpen,
                  mode: _modality,
                  embeddedInCockpit: true,
                  cockpitBottomInset: bottomBarHeight,
                  cockpitTopInset: CaptureCockpitScreen.headerHeight,
                  cockpitSideInset: rightInset,
                  cockpitLeftInset: leftInset,
                  cockpitRightInset: rightInset,
                  onProvideMediaRelease: (release) => _releaseMedia = release,
                  onProvideCommitPending: (commit) => _commitPending = commit,
                  onExitCockpit: () =>
                      unawaited(_exitCockpit(finalizeActiveVoice: true)),
                ),
                Positioned(
                  top: 0,
                  left: leftInset,
                  right: rightInset,
                  height: CaptureCockpitScreen.headerHeight,
                  child: Center(
                    child: Text(
                      'Capture Cockpit',
                      key: const Key('capture_cockpit_title'),
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 17,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                // DONE — right edge, ~50% height (must not move).
                Positioned(
                  right: doneRight,
                  top: doneTop,
                  child: _sideControl(
                    key: const Key('capture_cockpit_done'),
                    circular: false,
                    tooltip: 'Done',
                    onPressed: _exiting
                        ? null
                        : () => unawaited(
                              _exitCockpit(finalizeActiveVoice: true),
                            ),
                    child: Center(
                      child: Text(
                        'DONE',
                        style: AppTextStyles.label.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
                // Close — vertically below DONE, same right interaction zone.
                Positioned(
                  right: closeRight,
                  top: closeTop,
                  child: _sideControl(
                    key: const Key('capture_cockpit_close'),
                    circular: true,
                    tooltip: 'Close Capture Cockpit',
                    onPressed: _exiting
                        ? null
                        : () => unawaited(
                              _exitCockpit(finalizeActiveVoice: false),
                            ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: CaptureCockpitModalityBar(
                      activeModality: _modality,
                      enabled: _controlsEnabled,
                      onModalitySelected: _switchModality,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
