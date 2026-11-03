import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../constants/app_spacing.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../evidence_media_source.dart';
import '../evidence_preview_renderer.dart';

/// Voice note preview with waveform, duration, play/pause, and seek.
class VoiceEvidenceRenderer extends EvidencePreviewRenderer {
  const VoiceEvidenceRenderer();

  @override
  Widget build(BuildContext context, EvidencePreviewContext preview) {
    return _VoicePreviewSurface(preview: preview);
  }
}

class _VoicePreviewSurface extends StatefulWidget {
  const _VoicePreviewSurface({required this.preview});

  final EvidencePreviewContext preview;

  @override
  State<_VoicePreviewSurface> createState() => _VoicePreviewSurfaceState();
}

class _VoicePreviewSurfaceState extends State<_VoicePreviewSurface> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;

  bool _playing = false;
  bool _hasFile = false;
  Duration _position = Duration.zero;
  late Duration _duration;
  Timer? _demoTimer;

  @override
  void initState() {
    super.initState();
    _duration = EvidenceMediaSource.parsedDuration(widget.preview.record);
    _preparePlayer();
  }

  Future<void> _preparePlayer() async {
    final path =
        EvidenceMediaSource.playbackPath(widget.preview.record.evidence);
    if (!EvidenceMediaSource.isReadableFile(path)) {
      return;
    }
    try {
      await _player.setSource(DeviceFileSource(path!));
      final duration = await _player.getDuration();
      _positionSub = _player.onPositionChanged.listen((position) {
        if (!mounted) return;
        setState(() => _position = position);
      });
      _completeSub = _player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      });
      if (!mounted) return;
      var playing = false;
      try {
        await InspectorAutoplay.startWhenReady(
          seekToStart: () => _player.seek(Duration.zero),
          play: () => _player.resume(),
        );
        playing = true;
      } catch (_) {
        // Keep the prepared player; the user can start playback.
      }
      if (!mounted) return;
      setState(() {
        _hasFile = true;
        _playing = playing;
        if (duration != null && duration > Duration.zero) {
          _duration = duration;
        }
      });
    } catch (_) {
      // Fall back to demo playback UI.
    }
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_hasFile) {
      final path =
          EvidenceMediaSource.playbackPath(widget.preview.record.evidence);
      if (_playing) {
        await _player.pause();
        setState(() => _playing = false);
      } else if (path != null) {
        try {
          if (_player.state == PlayerState.paused) {
            await _player.resume();
          } else {
            await _player.play(DeviceFileSource(path));
          }
          setState(() => _playing = true);
        } catch (_) {
          if (mounted) {
            setState(() => _playing = false);
          }
        }
      }
      return;
    }

    if (_playing) {
      _demoTimer?.cancel();
      setState(() => _playing = false);
      return;
    }

    setState(() => _playing = true);
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = _position + const Duration(milliseconds: 200);
      if (next >= _duration) {
        timer.cancel();
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
        return;
      }
      setState(() => _position = next);
    });
  }

  Future<void> _seek(double value) async {
    final target = Duration(
      milliseconds: (value * _duration.inMilliseconds).round(),
    );
    if (_hasFile) {
      await _player.seek(target);
    }
    setState(() => _position = target);
  }

  String _format(Duration value) {
    final totalSeconds = value.inSeconds.clamp(0, 359999);
    final minutes = (totalSeconds ~/ 60).toString().padLeft(1, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static const double _frameInset = 20;
  static const double _playSize = 52;
  static const double _playToTrackGap = 16;

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    final durationLabel = _duration > Duration.zero ? _format(_duration) : null;

    return Semantics(
      label: durationLabel == null
          ? 'Voice note evidence'
          : 'Voice note evidence. Duration $durationLabel',
      child: Padding(
        key: const Key('evidence_inspector_audio_player'),
        padding: const EdgeInsets.fromLTRB(
          _frameInset,
          AppSpacing.md,
          _frameInset,
          AppSpacing.md,
        ),
        child: Column(
          children: [
            Text(
              'Voice Note',
              style: AppTextStyles.label.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _PlayControl(
                    playing: _playing,
                    onPressed: _togglePlay,
                    size: _playSize,
                  ),
                  const SizedBox(width: _playToTrackGap),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: _seek,
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.border,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  _format(_position),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _format(_duration),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayControl extends StatelessWidget {
  const _PlayControl({
    required this.playing,
    required this.onPressed,
    required this.size,
  });

  final bool playing;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: playing ? 'Pause voice note' : 'Play voice note',
      child: Material(
        key: const Key('evidence_inspector_audio_play'),
        color: AppColors.primary,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AppColors.onPrimary,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
