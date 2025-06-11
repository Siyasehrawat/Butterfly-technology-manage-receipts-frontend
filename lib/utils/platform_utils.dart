import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class PlatformUtils {
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isMobile => isIOS || isAndroid;

  static get Share => null;

  // Platform-specific haptic feedback
  static void hapticFeedback() {
    if (isIOS) {
      HapticFeedback.lightImpact();
    } else if (isAndroid) {
      HapticFeedback.vibrate();
    }
  }

  // Platform-specific status bar style
  static void setStatusBarStyle({required bool isDark}) {
    if (isIOS) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      );
    } else {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      );
    }
  }

  // Platform-specific file paths
  static Future<String> getAppDocumentsPath() async {
    if (isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } else {
      final directory = await getExternalStorageDirectory();
      return directory?.path ?? '';
    }
  }

  // Platform-specific sharing
  static Future<void> shareFile(String filePath, String fileName) async {
    if (isIOS) {
      // iOS-specific sharing implementation
      await Share.shareFiles([filePath], text: fileName);
    } else {
      // Android-specific sharing implementation
      await Share.shareFiles([filePath], text: fileName);
    }
  }
}