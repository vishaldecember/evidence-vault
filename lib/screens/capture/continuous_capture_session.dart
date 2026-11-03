import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import '../../constants/app_spacing.dart';
import '../../controllers/workspace_evidence_controller.dart';
import '../../models/evidence_type.dart';
import '../../models/workspace_capture_mode.dart';
import '../../services/capture/capture_engine.dart';
import '../../services/storage/local_evidence_cache.dart';
import '../../widgets/investigation/investigate_incident_scope.dart';
import '../../services/audio_capture_service.dart';
import '../../services/permission_service.dart';
import '../../services/persistence/media_preprocess_service.dart';
import '../../services/storage/capture_media_service.dart';
import '../../services/storage/evidence_upload_coordinator.dart';
import '../../services/storage/evidence_upload_feedback.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/capture/capture_preview_overlay.dart';
import '../../widgets/capture/cockpit_voice_visualizer.dart';
import '../../widgets/capture/voice_preview_panel.dart';
import '../../widgets/common/app_snackbar.dart';

/// Instant Capture session — Capture → Confirm → Continue.
///
/// Camera / video / voice mode stays alive under confirmation UI.
/// When [embeddedInCockpit] is true, this widget is hosted by
/// [CaptureCockpitScreen] and must not push its own route.
class ContinuousCaptureSession extends StatefulWidget {
  const ContinuousCaptureSession({
    super.key,
    required this.controller,
    required this.mode,
    this.boundIncidentId,
    this.embeddedInCockpit = false,
    this.cockpitBottomInset = 0,
    this.cockpitTopInset = 0,
    this.cockpitSideInset = 0,
    this.cockpitLeftInset,
    this.cockpitRightInset,
    this.onExitCockpit,
    this.onProvideMediaRelease,
    this.onProvideCommitPending,
  });

  /// Test hook — DONE must not mint evidence when durability cannot be verified.
  @visibleForTesting
  static bool debugFailVoiceDurability = false;

  /// Test hook — Accept/DONE treat local commit as a durability failure.
  @visibleForTesting
  static bool debugFailLocalCommit = false;

  /// Test seam — delay / fail Stop-path video thumbnail without a camera.
  @visibleForTesting
  static Future<String?> Function(String videoPath)?
      debugGenerateVideoThumbnail;

  /// Last thumbnail path attached after Stop. Tests only.
  @visibleForTesting
  static String? debugLastAttachedVideoThumbnail;

  /// Shown when local durability/cache commit fails. Preview stays.
  static const localCommitFailureMessage =
      'The capture was not preserved. Please try again.';

  /// Shown when Accept would write to a different incident. Preview stays.
  static const staleIncidentFailureMessage =
      'This capture couldn’t be preserved because the incident changed. Try again.';

  /// Previous central voice control diameter (large [_RoundAction]).
  @visibleForTesting
  static const double previousVoiceCenterControlDiameter = 68;

  /// Max diameter of the subordinate central Play/Pause (55–70% of previous).
  @visibleForTesting
  static const double voiceCenterControlMaxDiameter = 46;

  final WorkspaceEvidenceController controller;
  final WorkspaceCaptureMode mode;

  /// Incident this session was opened for. Preserve must not remap after switch.
  final String? boundIncidentId;

  /// Hosted inside Capture Cockpit — modality switches without leaving.
  final bool embeddedInCockpit;

  /// Space reserved under shutter controls for the translucent modality bar.
  final double cockpitBottomInset;

  /// Space reserved above post-capture preview for the Cockpit title band.
  final double cockpitTopInset;

  /// Fallback horizontal gutter when left/right are unspecified.
  final double cockpitSideInset;

  /// Optional asymmetric left gutter (larger preview when Close is right-stacked).
  final double? cockpitLeftInset;

  /// Optional asymmetric right gutter for the DONE + Close stack.
  final double? cockpitRightInset;

  /// Invoked when the user exits capture while embedded (cockpit owns pop).
  final VoidCallback? onExitCockpit;

  /// Lets Capture Cockpit await media release before route pop.
  final ValueChanged<Future<void> Function()>? onProvideMediaRelease;

  /// Lets Capture Cockpit await pending preview commit before exit / modality switch.
  ///
  /// [finalizeActiveVoice] is true only for DONE — Close / modality switch
  /// must not turn an in-progress recording into evidence. DONE also
  /// finalizes an in-progress video onto the existing Stop → Preview path.
  ///
  /// Returns `false` when a completed preview could not be preserved — the
  /// preview must stay and the caller must not pop / switch modality.
  final ValueChanged<Future<bool> Function({bool finalizeActiveVoice})>?
      onProvideCommitPending;

  static Future<int> open({
    required BuildContext context,
    required WorkspaceEvidenceController controller,
    required WorkspaceCaptureMode mode,
  }) async {
    // LEGACY / SECONDARY: fullscreen titled camera/session route.
    // Primary Photo / Video / Voice journeys must use [CaptureCockpitScreen.open]
    // (Home Capture Now + Incident Workspace sticky). Prefer Cockpit embedding
    // with [embeddedInCockpit] = true instead of this entry point.
    final count = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ContinuousCaptureSession(
          controller: controller,
          mode: mode,
        ),
      ),
    );
    return count ?? 0;
  }

  @override
  State<ContinuousCaptureSession> createState() =>
      _ContinuousCaptureSessionState();
}

enum _PhotoPhase { active, preview }

enum _VideoPhase { ready, recording, paused, preview }

enum _VoicePhase { ready, recording, paused, preview }

class _ContinuousCaptureSessionState extends State<ContinuousCaptureSession> {
  late final String _boundIncidentIdAtOpen;
  int _capturedCount = 0;
  bool _busy = false;

  /// In-flight accept — DONE/exit must await this to avoid discard races / dupes.
  Future<bool>? _acceptInFlight;

  CameraController? _camera;
  String? _cameraError;
  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lensDirection = CameraLensDirection.back;
  bool _switchingCamera = false;

  double _minZoom = 1;
  double _maxZoom = 1;
  double _currentZoom = 1;
  double _baseZoom = 1;
  int _pointers = 0;

  _PhotoPhase _photoPhase = _PhotoPhase.active;
  String? _photoPreviewPath;

  _VideoPhase _videoPhase = _VideoPhase.ready;
  String? _videoPreviewPath;
  String? _videoThumbnailPath;
  int _videoPreviewGeneration = 0;
  DateTime? _videoStartedAt;
  Duration _videoElapsed = Duration.zero;
  Timer? _videoTicker;

  _VoicePhase _voicePhase = _VoicePhase.ready;
  String? _voicePreviewPath;
  Duration _voiceElapsed = Duration.zero;
  Timer? _voiceTicker;
  final List<double> _waveLevels = List<double>.filled(28, 0.12);
  StreamSubscription<Amplitude>? _ampSub;
  AudioPlayer? _voicePlayer;
  StreamSubscription<void>? _voiceCompleteSub;
  StreamSubscription<Duration>? _voicePositionSub;
  bool _voicePreviewPlaying = false;
  Duration _voicePreviewPosition = Duration.zero;

  bool get _hasPendingCompletedCapture =>
      (_photoPhase == _PhotoPhase.preview && _photoPreviewPath != null) ||
      (_videoPhase == _VideoPhase.preview && _videoPreviewPath != null) ||
      (_voicePhase == _VoicePhase.preview && _voicePreviewPath != null);

  bool get _isFlutterTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  String get _title => switch (widget.mode) {
        WorkspaceCaptureMode.photo => 'Camera',
        WorkspaceCaptureMode.video => 'Video',
        WorkspaceCaptureMode.voice => 'Voice',
        WorkspaceCaptureMode.file => 'File',
        WorkspaceCaptureMode.note => 'Note',
      };

  bool get _usesCamera =>
      widget.mode == WorkspaceCaptureMode.photo ||
      widget.mode == WorkspaceCaptureMode.video;

  bool get _canFlipCamera {
    if (_isFlutterTest) return true;
    return _alternateCamera() != null;
  }

  bool get _showZoomIndicator =>
      _usesCamera &&
      _photoPhase != _PhotoPhase.preview &&
      _videoPhase != _VideoPhase.preview &&
      _maxZoom > _minZoom + 0.01 &&
      _currentZoom > _minZoom + 0.05;

  bool get _operationOwnsBound =>
      InvestigateIncidentScope.sessionMatchesBound(
        _boundIncidentIdAtOpen,
        widget.controller.currentIncident.id,
      );

  @override
  void initState() {
    super.initState();
    _boundIncidentIdAtOpen =
        (widget.boundIncidentId ?? widget.controller.currentIncident.id).trim();
    widget.onProvideMediaRelease?.call(_releaseMediaResources);
    widget.onProvideCommitPending?.call(commitPendingCaptureIfNeeded);
    if (!_isFlutterTest) {
      unawaited(_bootstrap());
    }
  }

  /// Commits a completed Photo/Video/Voice preview if one exists.
  ///
  /// Idempotent: awaits any in-flight accept first. Photo never fabricates
  /// evidence from a live shutter. Voice DONE ([finalizeActiveVoice])
  /// finalizes a valid in-progress recording first, then preserves it —
  /// playback is not required. Video DONE uses the same flag to run the
  /// canonical [_finishVideo] path and stay on Preview (not auto-Accept).
  /// Close / modality switch pass [finalizeActiveVoice] false so
  /// discard/cancel stays non-saving.
  ///
  /// Returns `false` when the caller must stay — commit failed, or an
  /// in-progress video was finalized into Preview.
  Future<bool> commitPendingCaptureIfNeeded({
    bool finalizeActiveVoice = false,
  }) async {
    final inFlight = _acceptInFlight;
    if (inFlight != null) {
      await inFlight;
    }
    if (finalizeActiveVoice &&
        widget.mode == WorkspaceCaptureMode.voice &&
        (_voicePhase == _VoicePhase.recording ||
            _voicePhase == _VoicePhase.paused)) {
      await _finishVoice();
    }
    if (finalizeActiveVoice &&
        widget.mode == WorkspaceCaptureMode.video &&
        (_videoPhase == _VideoPhase.recording ||
            _videoPhase == _VideoPhase.paused)) {
      await _finishVideo();
      // Same destination as Stop. Preview is not yet durable evidence.
      return false;
    }
    if (!_hasPendingCompletedCapture) {
      return true;
    }
    if (_photoPhase == _PhotoPhase.preview && _photoPreviewPath != null) {
      return _acceptPhoto();
    }
    if (_videoPhase == _VideoPhase.preview && _videoPreviewPath != null) {
      return _acceptVideo();
    }
    if (_voicePhase == _VoicePhase.preview && _voicePreviewPath != null) {
      return _acceptVoice();
    }
    return true;
  }

  Future<bool> _trackAccept(Future<bool> future) async {
    _acceptInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_acceptInFlight, future)) {
        _acceptInFlight = null;
      }
    }
  }

  bool get _debugFailLocalCommit =>
      ContinuousCaptureSession.debugFailLocalCommit ||
      (ContinuousCaptureSession.debugFailVoiceDurability &&
          widget.mode == WorkspaceCaptureMode.voice);

  void _reportAcceptFailure({required bool staleIncident}) {
    if (!mounted) {
      return;
    }
    AppSnackBar.showError(
      context,
      staleIncident
          ? ContinuousCaptureSession.staleIncidentFailureMessage
          : ContinuousCaptureSession.localCommitFailureMessage,
    );
  }

  Future<void> _bootstrap() async {
    final evidenceType = switch (widget.mode) {
      WorkspaceCaptureMode.photo => EvidenceType.photo,
      WorkspaceCaptureMode.video => EvidenceType.video,
      WorkspaceCaptureMode.voice => EvidenceType.audio,
      WorkspaceCaptureMode.file || WorkspaceCaptureMode.note =>
        EvidenceType.document,
    };
    final permitted = await PermissionService.ensureAll(
      context,
      PermissionService.requiredFor(evidenceType),
    );
    if (!permitted || !mounted) return;

    if (_usesCamera) {
      await _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera available');
        return;
      }
      final rear = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        rear,
        ResolutionPreset.high,
        enableAudio: widget.mode == WorkspaceCaptureMode.video,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _cameras = cameras;
      _lensDirection = rear.lensDirection;
      setState(() {
        _camera = controller;
        _cameraError = null;
      });
      await _refreshZoomRange();
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('[Capture] camera init failed: $error');
      if (mounted) {
        setState(() => _cameraError = 'Camera unavailable');
      }
    }
  }

  @override
  void dispose() {
    _videoPreviewGeneration += 1;
    // Thorough release (stop streams/recording) — same path as Done exit.
    // Cannot await in dispose; Cockpit awaits via onProvideMediaRelease.
    unawaited(_releaseMediaResources());
    super.dispose();
  }

  /// Release camera / mic before popping so Home → Capture → Home → Capture
  /// does not leave a stale hardware session frozen.
  Future<void> _releaseMediaResources() async {
    _videoTicker?.cancel();
    _voiceTicker?.cancel();
    _pointers = 0;
    await _ampSub?.cancel();
    _ampSub = null;
    await _voiceCompleteSub?.cancel();
    _voiceCompleteSub = null;
    await _voicePositionSub?.cancel();
    _voicePositionSub = null;
    final player = _voicePlayer;
    _voicePlayer = null;
    await player?.dispose();
    final cam = _camera;
    _camera = null;
    if (cam != null) {
      try {
        if (cam.value.isInitialized) {
          if (cam.value.isStreamingImages) {
            await cam.stopImageStream();
          }
          if (cam.value.isRecordingVideo) {
            try {
              await cam.stopVideoRecording();
            } catch (_) {}
          }
        }
        await cam.dispose();
      } catch (error) {
        debugPrint('[Capture] camera release failed: $error');
      }
    }
    await AudioCaptureService.cancel();
  }

  Future<void> _done() async {
    // DONE must durably commit a completed preview before leaving.
    // Voice: finalize an in-progress recording first — playback is optional.
    final committed =
        await commitPendingCaptureIfNeeded(finalizeActiveVoice: true);
    if (!committed) {
      return;
    }
    if (!_isFlutterTest) {
      await _releaseMediaResources();
    } else {
      _camera = null;
    }
    if (widget.embeddedInCockpit) {
      widget.onExitCockpit?.call();
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(_capturedCount);
  }

  /// Local commit barrier. Preview dismissal is the caller's job on `true`.
  Future<bool> _acceptMedia({
    required WorkspaceCaptureMode mode,
    required String path,
    String? thumbnailPath,
  }) async {
    if (_busy) return false;
    final boundIncidentIdAtStart = _boundIncidentIdAtOpen;
    if (!_operationOwnsBound) {
      _reportAcceptFailure(staleIncident: true);
      return false;
    }
    setState(() => _busy = true);
    try {
      final file = File(path);
      if (!await file.exists()) {
        _reportAcceptFailure(staleIncident: false);
        return false;
      }
      if (!InvestigateIncidentScope.sessionMatchesBound(
        boundIncidentIdAtStart,
        widget.controller.currentIncident.id,
      )) {
        _reportAcceptFailure(staleIncident: true);
        return false;
      }
      final coordinator = EvidenceUploadCoordinator.instance;
      late final String id;
      try {
        id = await widget.controller.preserveEvidenceWithMedia(
          mode: mode,
          media: CapturedMediaFile(
            localPath: path,
            fileName: p.basename(path),
            fileSizeBytes: await file.length(),
            thumbnailPath: thumbnailPath ??
                (mode == WorkspaceCaptureMode.photo ? path : null),
          ),
          uploadCoordinator: coordinator,
        );
      } on StaleCaptureIncidentException {
        _reportAcceptFailure(staleIncident: true);
        return false;
      } on MediaDurabilityException {
        _reportAcceptFailure(staleIncident: false);
        return false;
      }
      if (!mounted) {
        return true;
      }
      if (!InvestigateIncidentScope.sessionMatchesBound(
        boundIncidentIdAtStart,
        widget.controller.currentIncident.id,
      )) {
        // Commit already succeeded for the original incident — do not attach
        // elsewhere. Caller still dismisses preview.
        return true;
      }
      setState(() => _capturedCount++);
      EvidenceUploadFeedback.listenAndReport(
        context: context,
        evidenceId: id,
        coordinator: coordinator,
        onRetry: () async {
          await widget.controller.retryEvidenceUpload(
            id,
            uploadCoordinator: coordinator,
          );
        },
      );
      return true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteIfExists(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // —— Photo ————————————————————————————————————————————————

  Future<void> _takePhoto() async {
    if (_busy || _photoPhase == _PhotoPhase.preview) return;
    if (_isFlutterTest) {
      setState(() {
        _photoPreviewPath = 'test://photo';
        _photoPhase = _PhotoPhase.preview;
      });
      return;
    }
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      // Fallback: system picker, then preview.
      final media = await CaptureMediaService.acquire(WorkspaceCaptureMode.photo);
      if (!mounted || media == null) return;
      setState(() {
        _photoPreviewPath = media.localPath;
        _photoPhase = _PhotoPhase.preview;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final shot = await cam.takePicture();
      if (!mounted) return;
      setState(() {
        _photoPreviewPath = shot.path;
        _photoPhase = _PhotoPhase.preview;
      });
    } catch (error) {
      debugPrint('[Capture] takePicture failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _acceptPhoto() async {
    final path = _photoPreviewPath;
    if (path == null) return true;
    if (_busy || _acceptInFlight != null) return false;

    if (_isFlutterTest) {
      if (_debugFailLocalCommit) {
        _reportAcceptFailure(staleIncident: false);
        return false;
      }
      if (!_operationOwnsBound) {
        _reportAcceptFailure(staleIncident: true);
        return false;
      }
      widget.controller.preserveForWidgetTest(WorkspaceCaptureMode.photo);
      _dismissPhotoPreview();
      if (mounted) setState(() => _capturedCount++);
      return true;
    }

    final ok = await _trackAccept(
      _acceptMedia(mode: WorkspaceCaptureMode.photo, path: path),
    );
    if (ok) {
      _dismissPhotoPreview();
    }
    return ok;
  }

  void _dismissPhotoPreview() {
    if (!mounted) return;
    setState(() {
      _photoPreviewPath = null;
      _photoPhase = _PhotoPhase.active;
    });
  }

  Future<void> _discardPhoto() async {
    final path = _photoPreviewPath;
    setState(() {
      _photoPreviewPath = null;
      _photoPhase = _PhotoPhase.active;
    });
    if (!_isFlutterTest) await _deleteIfExists(path);
  }

  CameraDescription? _alternateCamera() {
    if (_cameras.length < 2) return null;
    final current = _camera?.description;
    final currentDirection = current?.lensDirection ?? _lensDirection;
    final target = currentDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    for (final camera in _cameras) {
      if (camera.lensDirection == target) {
        return camera;
      }
    }
    for (final camera in _cameras) {
      if (current == null || camera.name != current.name) {
        return camera;
      }
    }
    return null;
  }

  Future<void> _refreshZoomRange() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    try {
      final minZ = await cam.getMinZoomLevel();
      final maxZ = await cam.getMaxZoomLevel();
      if (!mounted) return;
      _minZoom = minZ;
      _maxZoom = maxZ < minZ ? minZ : maxZ;
      _currentZoom = _currentZoom.clamp(_minZoom, _maxZoom);
    } catch (error) {
      debugPrint('[Capture] zoom range unavailable: $error');
      _minZoom = 1;
      _maxZoom = 1;
      _currentZoom = 1;
    }
  }

  Future<void> _applyZoom(double zoom) async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (_maxZoom <= _minZoom) return;
    final next = zoom.clamp(_minZoom, _maxZoom);
    if ((next - _currentZoom).abs() < 0.005) {
      return;
    }
    _currentZoom = next;
    try {
      await cam.setZoomLevel(next);
    } catch (error) {
      debugPrint('[Capture] setZoomLevel failed: $error');
      return;
    }
    if (mounted) setState(() {});
  }

  void _onPointerCountDelta(int delta) {
    _pointers = (_pointers + delta).clamp(0, 8);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_pointers != 2) return;
    unawaited(_applyZoom(_baseZoom * details.scale));
  }

  /// Front/back switch via [CameraController.setDescription].
  ///
  /// While recording, camera 0.11.x routes this to
  /// `setDescriptionWhileRecording` (Android CameraX requires the default
  /// `enablePersistentRecording: true`). The same [CameraController] and
  /// recording session are kept — one evidence item on stop.
  Future<void> _flipCamera() async {
    if (_busy || _switchingCamera) return;
    if (_photoPhase == _PhotoPhase.preview ||
        _videoPhase == _VideoPhase.preview) {
      return;
    }
    if (_isFlutterTest) {
      setState(() {
        _lensDirection = _lensDirection == CameraLensDirection.back
            ? CameraLensDirection.front
            : CameraLensDirection.back;
      });
      return;
    }
    if (!_canFlipCamera) return;
    final cam = _camera;
    final next = _alternateCamera();
    if (cam == null || !cam.value.isInitialized || next == null) return;

    setState(() => _switchingCamera = true);
    try {
      await cam.setDescription(next);
      if (!mounted) return;
      await _refreshZoomRange();
      if (!mounted) return;
      try {
        await cam.setZoomLevel(_currentZoom);
      } catch (error) {
        debugPrint('[Capture] zoom after flip failed: $error');
      }
      if (!mounted) return;
      setState(() {
        _lensDirection = next.lensDirection;
      });
    } catch (error) {
      debugPrint('[Capture] camera flip failed: $error');
    } finally {
      if (mounted) {
        setState(() => _switchingCamera = false);
      } else {
        _switchingCamera = false;
      }
    }
  }

  // —— Video ————————————————————————————————————————————————

  void _startVideoTicker() {
    _videoTicker?.cancel();
    _videoTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _videoPhase != _VideoPhase.recording) return;
      final start = _videoStartedAt;
      if (start == null) return;
      setState(() {
        _videoElapsed = _videoElapsed + const Duration(milliseconds: 200);
      });
    });
  }

  Future<void> _startOrResumeVideo() async {
    if (_busy) return;
    if (_isFlutterTest) {
      setState(() {
        _videoPhase = _VideoPhase.recording;
        _videoStartedAt = DateTime.now();
      });
      _startVideoTicker();
      return;
    }
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      // Fallback: one-shot picker → preview.
      final media =
          await CaptureMediaService.acquire(WorkspaceCaptureMode.video);
      if (!mounted || media == null) return;
      String? thumb = media.thumbnailPath;
      thumb ??= await MediaPreprocessService.generateVideoThumbnail(
        media.localPath,
      );
      if (!mounted) return;
      setState(() {
        _videoPreviewPath = media.localPath;
        _videoThumbnailPath = thumb;
        _videoPhase = _VideoPhase.preview;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      if (_videoPhase == _VideoPhase.paused) {
        await cam.resumeVideoRecording();
        setState(() => _videoPhase = _VideoPhase.recording);
        _startVideoTicker();
      } else if (_videoPhase == _VideoPhase.ready) {
        await cam.startVideoRecording(enablePersistentRecording: true);
        setState(() {
          _videoPhase = _VideoPhase.recording;
          _videoStartedAt = DateTime.now();
          _videoElapsed = Duration.zero;
        });
        _startVideoTicker();
      }
    } catch (error) {
      debugPrint('[Capture] video start/resume failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pauseVideo() async {
    if (_videoPhase != _VideoPhase.recording) return;
    if (_isFlutterTest) {
      _videoTicker?.cancel();
      setState(() => _videoPhase = _VideoPhase.paused);
      return;
    }
    final cam = _camera;
    if (cam == null) return;
    try {
      await cam.pauseVideoRecording();
      _videoTicker?.cancel();
      if (mounted) setState(() => _videoPhase = _VideoPhase.paused);
    } catch (error) {
      debugPrint('[Capture] pauseVideo failed: $error');
    }
  }

  Future<void> _finishVideo() async {
    if (_busy) return;
    if (_videoPhase != _VideoPhase.recording &&
        _videoPhase != _VideoPhase.paused) {
      return;
    }
    _videoTicker?.cancel();
    if (_isFlutterTest) {
      final generation = ++_videoPreviewGeneration;
      final path = 'test://video-$generation';
      setState(() {
        _videoPreviewPath = path;
        _videoThumbnailPath = null;
        _videoPhase = _VideoPhase.preview;
      });
      if (ContinuousCaptureSession.debugGenerateVideoThumbnail != null) {
        _scheduleVideoPreviewThumbnail(
          videoPath: path,
          generation: generation,
        );
      }
      return;
    }
    final cam = _camera;
    if (cam == null) return;
    setState(() => _busy = true);
    try {
      final file = await cam.stopVideoRecording();
      if (!mounted) return;
      final path = file.path;
      final generation = ++_videoPreviewGeneration;
      setState(() {
        _videoPreviewPath = path;
        _videoThumbnailPath = null;
        _videoPhase = _VideoPhase.preview;
      });
      _scheduleVideoPreviewThumbnail(
        videoPath: path,
        generation: generation,
      );
    } catch (error) {
      debugPrint('[Capture] stopVideo failed: $error');
      if (mounted) setState(() => _videoPhase = _VideoPhase.ready);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// First-frame JPEG is presentation-only. Never gates Preview or Accept.
  void _scheduleVideoPreviewThumbnail({
    required String videoPath,
    required int generation,
  }) {
    unawaited(() async {
      String? thumb;
      try {
        final override =
            ContinuousCaptureSession.debugGenerateVideoThumbnail;
        thumb = override != null
            ? await override(videoPath)
            : await MediaPreprocessService.generateVideoThumbnail(videoPath);
      } catch (error) {
        debugPrint('[Capture] video thumbnail skipped: $error');
      }
      if (thumb == null || thumb.isEmpty) {
        return;
      }
      if (!mounted ||
          _videoPhase != _VideoPhase.preview ||
          _videoPreviewPath != videoPath ||
          _videoPreviewGeneration != generation) {
        if (!thumb.startsWith('test://')) {
          await _deleteIfExists(thumb);
        }
        return;
      }
      ContinuousCaptureSession.debugLastAttachedVideoThumbnail = thumb;
      setState(() => _videoThumbnailPath = thumb);
    }());
  }

  Future<bool> _acceptVideo() async {
    final path = _videoPreviewPath;
    if (path == null) return true;
    if (_busy || _acceptInFlight != null) return false;
    final thumb = _videoThumbnailPath;

    if (_isFlutterTest) {
      if (_debugFailLocalCommit) {
        _reportAcceptFailure(staleIncident: false);
        return false;
      }
      if (!_operationOwnsBound) {
        _reportAcceptFailure(staleIncident: true);
        return false;
      }
      widget.controller.preserveForWidgetTest(WorkspaceCaptureMode.video);
      _dismissVideoPreview();
      if (mounted) setState(() => _capturedCount++);
      return true;
    }

    final ok = await _trackAccept(
      _acceptMedia(
        mode: WorkspaceCaptureMode.video,
        path: path,
        thumbnailPath: thumb,
      ),
    );
    if (ok) {
      _dismissVideoPreview();
    }
    return ok;
  }

  void _dismissVideoPreview() {
    if (!mounted) return;
    _videoPreviewGeneration += 1;
    setState(() {
      _videoPreviewPath = null;
      _videoThumbnailPath = null;
      _videoPhase = _VideoPhase.ready;
      _videoElapsed = Duration.zero;
    });
  }

  Future<void> _discardVideo() async {
    _videoTicker?.cancel();
    if (_videoPhase == _VideoPhase.recording ||
        _videoPhase == _VideoPhase.paused) {
      if (!_isFlutterTest) {
        final cam = _camera;
        if (cam != null && cam.value.isRecordingVideo) {
          try {
            final file = await cam.stopVideoRecording();
            await _deleteIfExists(file.path);
          } catch (error) {
            debugPrint('[Capture] discard recording failed: $error');
          }
        }
      }
      if (mounted) {
        _videoPreviewGeneration += 1;
        setState(() {
          _videoPreviewPath = null;
          _videoThumbnailPath = null;
          _videoPhase = _VideoPhase.ready;
          _videoElapsed = Duration.zero;
        });
      }
      return;
    }
    final path = _videoPreviewPath;
    final thumb = _videoThumbnailPath;
    _videoPreviewGeneration += 1;
    setState(() {
      _videoPreviewPath = null;
      _videoThumbnailPath = null;
      _videoPhase = _VideoPhase.ready;
      _videoElapsed = Duration.zero;
    });
    if (!_isFlutterTest) {
      await _deleteIfExists(path);
      await _deleteIfExists(thumb);
    }
  }

  // —— Voice ————————————————————————————————————————————————

  Future<void> _startOrResumeVoice() async {
    if (_busy) return;
    if (_isFlutterTest) {
      setState(() => _voicePhase = _VoicePhase.recording);
      _startVoiceTicker();
      return;
    }
    setState(() => _busy = true);
    try {
      if (_voicePhase == _VoicePhase.paused) {
        await AudioCaptureService.resume();
        setState(() => _voicePhase = _VoicePhase.recording);
        _startVoiceTicker();
        _listenAmplitude();
      } else if (_voicePhase == _VoicePhase.ready) {
        await AudioCaptureService.start();
        setState(() {
          _voicePhase = _VoicePhase.recording;
          _voiceElapsed = Duration.zero;
          for (var i = 0; i < _waveLevels.length; i++) {
            _waveLevels[i] = 0.12;
          }
        });
        _startVoiceTicker();
        _listenAmplitude();
      }
    } catch (error) {
      debugPrint('[Capture] voice start failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _listenAmplitude() {
    unawaited(_ampSub?.cancel() ?? Future<void>.value());
    _ampSub = AudioCaptureService.onAmplitudeChanged().listen((amp) {
      if (!mounted || _voicePhase != _VoicePhase.recording) return;
      // Normalize dB-ish current to 0–1 for bars.
      final level = ((amp.current + 45) / 45).clamp(0.08, 1.0);
      setState(() {
        _waveLevels.removeAt(0);
        _waveLevels.add(level);
      });
    });
  }

  void _startVoiceTicker() {
    _voiceTicker?.cancel();
    _voiceTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _voicePhase != _VoicePhase.recording) return;
      setState(() {
        _voiceElapsed += const Duration(milliseconds: 200);
      });
    });
  }

  Future<void> _pauseVoice() async {
    if (_voicePhase != _VoicePhase.recording) return;
    _voiceTicker?.cancel();
    if (_isFlutterTest) {
      setState(() => _voicePhase = _VoicePhase.paused);
      return;
    }
    await _ampSub?.cancel();
    _ampSub = null;
    await AudioCaptureService.pause();
    if (mounted) setState(() => _voicePhase = _VoicePhase.paused);
  }

  Future<void> _finishVoice() async {
    if (_voicePhase != _VoicePhase.recording &&
        _voicePhase != _VoicePhase.paused) {
      return;
    }
    _voiceTicker?.cancel();
    if (_isFlutterTest) {
      setState(() {
        _voicePreviewPath = 'test://voice';
        _voicePhase = _VoicePhase.preview;
      });
      return;
    }
    await _ampSub?.cancel();
    _ampSub = null;
    final path = await AudioCaptureService.stop();
    if (!mounted) return;
    setState(() {
      _voicePreviewPath = path;
      _voicePhase = _VoicePhase.preview;
    });
  }

  Future<bool> _acceptVoice() async {
    final path = _voicePreviewPath;
    if (path == null) return true;
    if (_busy || _acceptInFlight != null) return false;
    await _stopVoicePreviewPlayback();

    if (_isFlutterTest) {
      if (_debugFailLocalCommit) {
        _reportAcceptFailure(staleIncident: false);
        return false;
      }
      if (!_operationOwnsBound) {
        _reportAcceptFailure(staleIncident: true);
        return false;
      }
      widget.controller.preserveForWidgetTest(WorkspaceCaptureMode.voice);
      _dismissVoicePreview();
      if (mounted) setState(() => _capturedCount++);
      return true;
    }

    final ok = await _trackAccept(
      _acceptMedia(mode: WorkspaceCaptureMode.voice, path: path),
    );
    if (ok) {
      _dismissVoicePreview();
    }
    return ok;
  }

  void _dismissVoicePreview() {
    if (!mounted) return;
    setState(() {
      _voicePreviewPath = null;
      _voicePhase = _VoicePhase.ready;
      _voiceElapsed = Duration.zero;
      _voicePreviewPlaying = false;
      _voicePreviewPosition = Duration.zero;
    });
  }

  Future<void> _discardVoice() async {
    final path = _voicePreviewPath;
    await _stopVoicePreviewPlayback();
    if (_voicePhase == _VoicePhase.recording ||
        _voicePhase == _VoicePhase.paused) {
      _voiceTicker?.cancel();
      await _ampSub?.cancel();
      _ampSub = null;
      if (!_isFlutterTest) await AudioCaptureService.cancel();
    }
    setState(() {
      _voicePreviewPath = null;
      _voicePhase = _VoicePhase.ready;
      _voiceElapsed = Duration.zero;
      _voicePreviewPlaying = false;
      _voicePreviewPosition = Duration.zero;
    });
    if (!_isFlutterTest) await _deleteIfExists(path);
  }

  Future<void> _stopVoicePreviewPlayback() async {
    try {
      await _voicePlayer?.stop();
    } catch (_) {}
    _voicePreviewPosition = Duration.zero;
    if (mounted) {
      setState(() => _voicePreviewPlaying = false);
    } else {
      _voicePreviewPlaying = false;
    }
  }

  Future<void> _ensureVoicePlayer() async {
    _voicePlayer ??= AudioPlayer();
    _voiceCompleteSub ??= _voicePlayer!.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _voicePreviewPlaying = false;
        _voicePreviewPosition = Duration.zero;
      });
    });
    _voicePositionSub ??= _voicePlayer!.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _voicePreviewPosition = position);
    });
  }

  Future<void> _toggleVoicePreviewPlayback() async {
    if (_isFlutterTest) {
      setState(() => _voicePreviewPlaying = !_voicePreviewPlaying);
      return;
    }
    final path = _voicePreviewPath;
    if (path == null) return;
    try {
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        if (mounted) {
          setState(() => _voicePreviewPlaying = false);
        }
        return;
      }
      await _ensureVoicePlayer();
      if (_voicePreviewPlaying) {
        await _voicePlayer!.pause();
        if (mounted) setState(() => _voicePreviewPlaying = false);
        return;
      }
      if (_voicePlayer!.state == PlayerState.paused) {
        await _voicePlayer!.resume();
      } else {
        await _voicePlayer!.stop();
        await _voicePlayer!.play(DeviceFileSource(path));
      }
      if (mounted) setState(() => _voicePreviewPlaying = true);
    } catch (error) {
      debugPrint('[Voice] preview playback failed: $error');
      if (mounted) {
        setState(() => _voicePreviewPlaying = false);
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // —— Build ————————————————————————————————————————————————

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      fit: StackFit.expand,
      children: [
        _buildLiveSurface(),
        // Cockpit owns Close / DONE — avoid duplicate chrome over the preview.
        if (!widget.embeddedInCockpit)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Done — return to Workspace',
                    onPressed: () => unawaited(_done()),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.label.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_capturedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Text(
                        '$_capturedCount',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          )
        else
          // Modality chip + count sit under the shell title band (~48px).
          Positioned(
            top: 48,
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Row(
              children: [
                const Spacer(),
                Container(
                  key: const Key('cockpit_modality_label'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _title,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _capturedCount > 0
                        ? Text(
                            '$_capturedCount',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        if (_showZoomIndicator)
          Positioned(
            top: widget.embeddedInCockpit ? 80 : 56,
            left: 0,
            right: 0,
            child: Center(
              child: IgnorePointer(
                child: Container(
                  key: const Key('camera_zoom_indicator'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentZoom.toStringAsFixed(1)}×',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_photoPhase != _PhotoPhase.preview &&
            _videoPhase != _VideoPhase.preview &&
            _voicePhase != _VoicePhase.preview)
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.embeddedInCockpit ? widget.cockpitBottomInset : 0,
            child: SafeArea(
              top: false,
              bottom: !widget.embeddedInCockpit,
              child: _buildControls(),
            ),
          ),
        if (_photoPhase == _PhotoPhase.preview && _photoPreviewPath != null)
          CapturePreviewOverlay(
            useImmersivePreviewFrame: widget.embeddedInCockpit,
            skipImmersiveEntrance: _isFlutterTest,
            bottomChromeInset: widget.cockpitBottomInset,
            topChromeInset: widget.cockpitTopInset,
            sideChromeInset: widget.cockpitSideInset,
            leftChromeInset: widget.cockpitLeftInset,
            rightChromeInset: widget.cockpitRightInset,
            onAccept: () => unawaited(_acceptPhoto()),
            onDiscard: () => unawaited(_discardPhoto()),
            child: _isFlutterTest
                ? const ColoredBox(color: AppColors.navy)
                : CaptureImagePreview(path: _photoPreviewPath!),
          ),
        if (_videoPhase == _VideoPhase.preview && _videoPreviewPath != null)
          CapturePreviewOverlay(
            useImmersivePreviewFrame: widget.embeddedInCockpit,
            skipImmersiveEntrance: _isFlutterTest,
            bottomChromeInset: widget.cockpitBottomInset,
            topChromeInset: widget.cockpitTopInset,
            sideChromeInset: widget.cockpitSideInset,
            leftChromeInset: widget.cockpitLeftInset,
            rightChromeInset: widget.cockpitRightInset,
            onAccept: () => unawaited(_acceptVideo()),
            onDiscard: () => unawaited(_discardVideo()),
            child: CaptureVideoPreviewPlaceholder(
              videoPath: _videoPreviewPath,
              thumbnailPath: _videoThumbnailPath,
              durationLabel: _formatDuration(_videoElapsed),
            ),
          ),
        // Voice confirmation stays upright — no CockpitImmersivePreview tilt.
        if (widget.mode == WorkspaceCaptureMode.voice &&
            _voicePhase == _VoicePhase.preview)
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.embeddedInCockpit ? widget.cockpitBottomInset : 0,
            child: VoicePreviewPanel(
              levels: _waveLevels,
              durationLabel: _formatDuration(_voiceElapsed),
              positionLabel: _formatDuration(_voicePreviewPosition),
              isPlaying: _voicePreviewPlaying,
              progress: _voiceElapsed.inMilliseconds == 0
                  ? 0.0
                  : (_voicePreviewPosition.inMilliseconds /
                            _voiceElapsed.inMilliseconds)
                        .clamp(0.0, 1.0),
              onPlayPause: () => unawaited(_toggleVoicePreviewPlayback()),
              onAccept: () => unawaited(_acceptVoice()),
              onDiscard: () => unawaited(_discardVoice()),
            ),
          ),
      ],
    );

    // Embedded cockpit: straight live surface fills the shell (no nested Scaffold).
    if (widget.embeddedInCockpit) {
      return ColoredBox(
        key: const Key('cockpit_live_capture_surface'),
        color: Colors.black,
        child: body,
      );
    }

    final scaffold = Scaffold(
      backgroundColor: Colors.black,
      body: body,
    );

    // Widget tests drive exit via callbacks — no PopScope.
    if (_isFlutterTest) {
      return scaffold;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(_done());
      },
      child: scaffold,
    );
  }

  Widget _buildLiveSurface() {
    if (widget.mode == WorkspaceCaptureMode.voice) {
      return _buildVoiceLiveSurface();
    }

    final inMediaPreview = _photoPhase == _PhotoPhase.preview ||
        _videoPhase == _VideoPhase.preview;
    final cam = _camera;
    if (cam != null && cam.value.isInitialized) {
      // Live camera/video is always upright and full-bleed. Tilt applies only
      // to post-capture CockpitImmersivePreview — never to CameraPreview.
      return Listener(
        onPointerDown: (_) => _onPointerCountDelta(1),
        onPointerUp: (_) => _onPointerCountDelta(-1),
        onPointerCancel: (_) => _onPointerCountDelta(-1),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: cam.value.previewSize?.height ?? 1,
              height: cam.value.previewSize?.width ?? 1,
              child: CameraPreview(cam),
            ),
          ),
        ),
      );
    }

    // Preview owns the surface — do not paint fallback copy that would
    // composite through the play icon / tilted frame.
    if (inMediaPreview) {
      return const ColoredBox(color: Colors.black);
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Text(
          _cameraError ?? 'Preparing capture…',
          style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildVoiceLiveSurface() {
    final level = _waveLevels.isEmpty ? 0.1 : _waveLevels.last;
    final recording = _voicePhase == _VoicePhase.recording;
    final canToggleRecord =
        !_busy && _voicePhase != _VoicePhase.preview;
    return ColoredBox(
      color: CockpitVoiceVisualizer.fieldColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              _formatDuration(_voiceElapsed),
              key: const Key('voice_center_timer'),
              style: AppTextStyles.heading.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final extent = math.min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final controlSize = (extent * 0.14).clamp(
                  36.0,
                  ContinuousCaptureSession.voiceCenterControlMaxDiameter,
                );
                return Stack(
                  key: const Key('voice_ring_surface'),
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      key: const Key('voice_record'),
                      behavior: HitTestBehavior.opaque,
                      onTap: !canToggleRecord
                          ? null
                          : () {
                              if (_voicePhase == _VoicePhase.recording) {
                                unawaited(_pauseVoice());
                              } else {
                                unawaited(_startOrResumeVoice());
                              }
                            },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: CockpitVoiceVisualizer(
                          level: level,
                          active: recording ||
                              _voicePhase == _VoicePhase.paused,
                          idleMotion: _voicePhase == _VoicePhase.ready ||
                              _voicePhase == _VoicePhase.paused,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: _VoiceCenterPlayPause(
                        size: controlSize,
                        icon: _voiceCenterIcon,
                        tooltip: _voiceCenterTooltip,
                        onPressed: _busy ? null : _onVoiceCenterPressed,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData get _voiceCenterIcon {
    if (_voicePhase == _VoicePhase.preview) {
      return _voicePreviewPlaying
          ? Icons.pause_circle_filled
          : Icons.play_circle_filled;
    }
    if (_voicePhase == _VoicePhase.recording) {
      return Icons.pause;
    }
    return Icons.play_arrow;
  }

  String get _voiceCenterTooltip {
    if (_voicePhase == _VoicePhase.preview) {
      // Compact [VoicePreviewPanel] owns 'Play preview' / 'Pause preview'.
      return _voicePreviewPlaying ? 'Pause' : 'Play';
    }
    if (_voicePhase == _VoicePhase.recording) {
      return 'Pause';
    }
    if (_voicePhase == _VoicePhase.paused) {
      return 'Play';
    }
    return 'Record';
  }

  void _onVoiceCenterPressed() {
    if (_voicePhase == _VoicePhase.preview) {
      unawaited(_toggleVoicePreviewPlayback());
      return;
    }
    if (_voicePhase == _VoicePhase.recording) {
      unawaited(_pauseVoice());
      return;
    }
    unawaited(_startOrResumeVoice());
  }

  Widget _buildControls() {
    final controls = switch (widget.mode) {
      WorkspaceCaptureMode.photo => _PhotoControls(
          busy: _busy,
          canFlip: _canFlipCamera && !_switchingCamera,
          isFront: _lensDirection == CameraLensDirection.front,
          onShutter: () => unawaited(_takePhoto()),
          onFlip: () => unawaited(_flipCamera()),
        ),
      WorkspaceCaptureMode.video => _VideoControls(
          phase: _videoPhase,
          busy: _busy,
          elapsed: _formatDuration(_videoElapsed),
          canFlip: _canFlipCamera && !_switchingCamera,
          isFront: _lensDirection == CameraLensDirection.front,
          onRecord: () => unawaited(_startOrResumeVideo()),
          onResume: () => unawaited(_startOrResumeVideo()),
          onPause: () => unawaited(_pauseVideo()),
          onStop: () => unawaited(_finishVideo()),
          onDiscard: () => unawaited(_discardVideo()),
          onFlip: () => unawaited(_flipCamera()),
        ),
      WorkspaceCaptureMode.voice => _VoiceRecordingControls(
          phase: _voicePhase,
          busy: _busy,
          onStop: () => unawaited(_finishVoice()),
          onDiscard: () => unawaited(_discardVoice()),
        ),
      WorkspaceCaptureMode.file || WorkspaceCaptureMode.note => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton(
            onPressed: () => unawaited(_done()),
            child: const Text('Done'),
          ),
        ),
    };

    if (!widget.embeddedInCockpit) {
      return controls;
    }

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.32),
      child: controls,
    );
  }
}

class _PhotoControls extends StatelessWidget {
  const _PhotoControls({
    required this.busy,
    required this.canFlip,
    required this.isFront,
    required this.onShutter,
    required this.onFlip,
  });

  final bool busy;
  final bool canFlip;
  final bool isFront;
  final VoidCallback onShutter;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          const SizedBox(width: 48),
          const Spacer(),
          GestureDetector(
            key: const Key('photo_shutter'),
            onTap: busy ? null : onShutter,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: busy ? Colors.white38 : Colors.white,
                ),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 48,
            child: _CameraFlipButton(
              enabled: canFlip && !busy,
              isFront: isFront,
              onPressed: onFlip,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.phase,
    required this.busy,
    required this.elapsed,
    required this.canFlip,
    required this.isFront,
    required this.onRecord,
    required this.onResume,
    required this.onPause,
    required this.onStop,
    required this.onDiscard,
    required this.onFlip,
  });

  final _VideoPhase phase;
  final bool busy;
  final String elapsed;
  final bool canFlip;
  final bool isFront;
  final VoidCallback onRecord;
  final VoidCallback onResume;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final VoidCallback onDiscard;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final recording =
        phase == _VideoPhase.recording || phase == _VideoPhase.paused;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: recording
                    ? Text(
                        phase == _VideoPhase.paused
                            ? 'Ⅱ  $elapsed'
                            : '●  $elapsed',
                        key: const Key('video_control_timer'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.label.copyWith(
                          color: phase == _VideoPhase.paused
                              ? Colors.white70
                              : AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              SizedBox(
                width: 48,
                child: _CameraFlipButton(
                  enabled: canFlip && !busy,
                  isFront: isFront,
                  onPressed: onFlip,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // LEFT — Delete
              IconButton(
                tooltip: 'Discard',
                onPressed: busy || !recording ? null : onDiscard,
                icon: Icon(
                  Icons.delete_outline,
                  color: recording ? Colors.white : Colors.white24,
                  size: 28,
                ),
              ),
              // CENTER — Record / Stop
              if (!recording)
                _RoundAction(
                  key: const Key('video_record'),
                  tooltip: 'Record',
                  color: AppColors.danger,
                  icon: Icons.fiber_manual_record,
                  onPressed: busy ? null : onRecord,
                  large: true,
                )
              else
                _RoundAction(
                  key: const Key('video_stop'),
                  tooltip: 'Stop',
                  color: AppColors.primary,
                  icon: Icons.stop,
                  onPressed: busy ? null : onStop,
                  large: true,
                ),
              // RIGHT — Pause / Resume
              IconButton(
                tooltip: phase == _VideoPhase.paused ? 'Play' : 'Pause',
                onPressed: busy || !recording
                    ? null
                    : (phase == _VideoPhase.paused ? onResume : onPause),
                icon: Icon(
                  phase == _VideoPhase.paused ? Icons.play_arrow : Icons.pause,
                  color: recording ? Colors.white : Colors.white24,
                  size: 32,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Recording-only controls. Preview uses [VoicePreviewPanel] separately.
class _VoiceRecordingControls extends StatelessWidget {
  const _VoiceRecordingControls({
    required this.phase,
    required this.busy,
    required this.onStop,
    required this.onDiscard,
  });

  final _VoicePhase phase;
  final bool busy;
  final VoidCallback onStop;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final active =
        phase == _VoicePhase.recording || phase == _VoicePhase.paused;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: active
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'Discard',
                  onPressed: busy ? null : onDiscard,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white70,
                    size: 26,
                  ),
                ),
                _RoundAction(
                  key: const Key('voice_stop'),
                  tooltip: 'Stop',
                  color: Colors.white24,
                  icon: Icons.stop,
                  onPressed: busy ? null : onStop,
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Small Play/Pause affordance — sits in the innermost ring, not a second shutter.
class _VoiceCenterPlayPause extends StatelessWidget {
  const _VoiceCenterPlayPause({
    required this.size,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final double size;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        key: const Key('voice_center_play_pause'),
        color: Colors.white.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.92),
              size: size * 0.48,
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraFlipButton extends StatelessWidget {
  const _CameraFlipButton({
    required this.enabled,
    required this.isFront,
    required this.onPressed,
  });

  final bool enabled;
  final bool isFront;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('camera_flip'),
      tooltip: isFront ? 'Switch to back camera' : 'Switch to front camera',
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        Icons.flip_camera_ios,
        color: enabled ? Colors.white : Colors.white24,
        size: 28,
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onPressed,
    this.large = false,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 68.0 : 52.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: large ? 32 : 26),
          ),
        ),
      ),
    );
  }
}
