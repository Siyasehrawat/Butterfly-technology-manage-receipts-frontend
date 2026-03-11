import 'package:image_picker/image_picker.dart';

/// Simple camera capture (no auto-crop or document scanner).
/// Uses [ImagePicker] to capture a photo from the device camera.
class DocumentScanService {
  static const int _defaultImageQuality = 85;
  static const double _defaultMaxSize = 1920;

  /// Opens the device camera and returns the captured image as an [XFile].
  ///
  /// Returns `null` if the user cancels.
  static Future<XFile?> captureCroppedDocumentImage() async {
    final picker = ImagePicker();
    return picker.pickImage(
      source: ImageSource.camera,
      imageQuality: _defaultImageQuality,
      maxWidth: _defaultMaxSize,
      maxHeight: _defaultMaxSize,
    );
  }
}
