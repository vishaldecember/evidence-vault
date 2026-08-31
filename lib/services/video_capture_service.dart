import 'package:image_picker/image_picker.dart';

abstract final class VideoCaptureService {
  static final _picker = ImagePicker();

  static Future<String?> captureVideo() async {
    final video = await _picker.pickVideo(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxDuration: const Duration(minutes: 10),
    );

    return video?.path;
  }
}
