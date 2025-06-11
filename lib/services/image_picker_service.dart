// Create this file to handle platform-specific image picking
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

// Use conditional imports to avoid loading web libraries on mobile
// ignore: uri_does_not_exist
import 'image_picker_web_stub.dart'
if (dart.library.html) 'image_picker_web_impl.dart';

class ImagePickerService {
  static Future<dynamic> pickImage(ImageSource source) async {
    if (kIsWeb) {
      // Call the web implementation
      return pickImage(source);
    } else {
      // Mobile implementation
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      return pickedFile;
    }
  }

  static Future<List<int>?> getImageBytes(dynamic image) async {
    if (kIsWeb) {
      // Call the web implementation
      return getImageBytes(image);
    } else {
      if (image != null) {
        return await image.readAsBytes();
      }
    }
    return null;
  }

  static String? getImageName(dynamic image) {
    if (kIsWeb) {
      // Call the web implementation
      return getImageName(image);
    } else {
      if (image != null) {
        return image.path.split('/').last;
      }
    }
    return null;
  }
}