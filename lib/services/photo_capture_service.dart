import 'package:image_picker/image_picker.dart';

abstract final class PhotoCaptureService {
  static final _picker = ImagePicker();

  static Future<String?> capturePhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 90,
    );

    return image?.path;
  }
}
