import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

abstract final class AudioCaptureService {
  static final _recorder = AudioRecorder();
  static String? _activePath;

  static Future<bool> get isRecording => _recorder.isRecording();

  static Future<bool> get isPaused => _recorder.isPaused();

  /// Live amplitude for waveform visualization (not fake audio content).
  static Stream<Amplitude> onAmplitudeChanged([
    Duration interval = const Duration(milliseconds: 80),
  ]) {
    return _recorder.onAmplitudeChanged(interval);
  }

  static Future<void> start() async {
    if (await _recorder.isRecording()) return;

    final tempDir = await getTemporaryDirectory();
    _activePath = p.join(
      tempDir.path,
      'evidence_audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _activePath!,
    );
  }

  static Future<void> pause() async {
    if (await _recorder.isRecording()) {
      await _recorder.pause();
    }
  }

  static Future<void> resume() async {
    if (await _recorder.isPaused()) {
      await _recorder.resume();
    }
  }

  static Future<String?> stop() async {
    final path = await _recorder.stop();
    _activePath = null;
    return path;
  }

  static Future<void> cancel() async {
    if (await _recorder.isRecording() || await _recorder.isPaused()) {
      await _recorder.stop();
    }

    if (_activePath != null) {
      final file = File(_activePath!);
      if (await file.exists()) {
        await file.delete();
      }
      _activePath = null;
    }
  }

  static Future<void> dispose() async {
    await _recorder.dispose();
  }
}
