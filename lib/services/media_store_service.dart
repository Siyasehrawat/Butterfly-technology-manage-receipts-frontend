import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class MediaStoreService {
  static final MediaStoreService _instance = MediaStoreService._internal();
  factory MediaStoreService() => _instance;
  MediaStoreService._internal();

  /// Request appropriate permissions based on Android version
  Future<bool> requestMediaPermissions() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    try {
      // For Android 13+ (API 33+), use granular media permissions
      if (await _isAndroid13OrHigher()) {
        final permissions = [
          Permission.photos, // READ_MEDIA_IMAGES
        ];

        final statuses = await permissions.request();
        return statuses.values.every((status) =>
        status == PermissionStatus.granted ||
            status == PermissionStatus.limited
        );
      } else {
        // For Android 12 and below, use READ_EXTERNAL_STORAGE
        final status = await Permission.storage.request();
        return status == PermissionStatus.granted;
      }
    } catch (e) {
      debugPrint('Error requesting media permissions: $e');
      return false;
    }
  }

  /// Check if device is running Android 13 or higher
  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 33; // Android 13 is API level 33
    } catch (e) {
      debugPrint('Error checking Android version: $e');
      return false; // Default to older Android behavior
    }
  }

  /// Check current permission status
  Future<PermissionStatus> getMediaPermissionStatus() async {
    if (kIsWeb || !Platform.isAndroid) {
      return PermissionStatus.granted;
    }

    try {
      if (await _isAndroid13OrHigher()) {
        return await Permission.photos.status;
      } else {
        return await Permission.storage.status;
      }
    } catch (e) {
      debugPrint('Error checking permission status: $e');
      return PermissionStatus.denied;
    }
  }

  /// Pick image using MediaStore API (through image_picker)
  Future<XFile?> pickImageFromGallery() async {
    try {
      final hasPermission = await requestMediaPermissions();
      if (!hasPermission) {
        throw Exception('Media access permission denied');
      }

      final picker = ImagePicker();
      return await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Compress to reduce file size
        maxWidth: 1920,
        maxHeight: 1920,
      );
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      rethrow;
    }
  }

  /// Pick image using camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      final cameraPermission = await Permission.camera.request();
      if (cameraPermission != PermissionStatus.granted) {
        throw Exception('Camera permission denied');
      }

      final picker = ImagePicker();
      return await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Compress to reduce file size
        maxWidth: 1920,
        maxHeight: 1920,
      );
    } catch (e) {
      debugPrint('Error taking photo with camera: $e');
      rethrow;
    }
  }

  /// Pick files using MediaStore API (through file_picker)
  Future<PlatformFile?> pickDocument() async {
    try {
      final hasPermission = await requestMediaPermissions();
      if (!hasPermission) {
        throw Exception('Media access permission denied');
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
        withData: true, // Important for web compatibility
      );

      return result?.files.first;
    } catch (e) {
      debugPrint('Error picking document: $e');
      rethrow;
    }
  }

  /// Show permission rationale dialog
  Future<bool> showPermissionRationale(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Media Access Required'),
        content: const Text(
          'This app needs access to your photos and documents to upload receipts. '
              'We only access the files you specifically select.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Grant Access'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Handle permission denied scenarios
  Future<void> handlePermissionDenied(BuildContext context) async {
    final status = await getMediaPermissionStatus();

    if (status == PermissionStatus.permanentlyDenied) {
      await _showPermanentlyDeniedDialog(context);
    } else {
      await _showPermissionDeniedDialog(context);
    }
  }

  /// Show dialog for permanently denied permissions
  Future<void> _showPermanentlyDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Media access permission is required to upload receipts. '
              'Please enable it in the app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show dialog for denied permissions
  Future<void> _showPermissionDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: const Text(
          'Media access permission is required to upload receipts. '
              'Please grant the permission to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Check if we should show permission rationale
  Future<bool> shouldShowRequestPermissionRationale() async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    try {
      if (await _isAndroid13OrHigher()) {
        return await Permission.photos.shouldShowRequestRationale;
      } else {
        return await Permission.storage.shouldShowRequestRationale;
      }
    } catch (e) {
      debugPrint('Error checking if should show rationale: $e');
      return false;
    }
  }

  /// Request permission with proper flow
  Future<bool> requestPermissionWithRationale(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    // Check current status
    final currentStatus = await getMediaPermissionStatus();

    if (currentStatus == PermissionStatus.granted) {
      return true;
    }

    if (currentStatus == PermissionStatus.permanentlyDenied) {
      await handlePermissionDenied(context);
      return false;
    }

    // Show rationale if needed
    if (await shouldShowRequestPermissionRationale()) {
      final shouldRequest = await showPermissionRationale(context);
      if (!shouldRequest) {
        return false;
      }
    }

    // Request permission
    final hasPermission = await requestMediaPermissions();

    if (!hasPermission) {
      await handlePermissionDenied(context);
    }

    return hasPermission;
  }
}
