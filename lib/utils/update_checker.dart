import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/version_service.dart';
import '../widgets/force_update_dialog.dart';
import 'dart:io';

class UpdateChecker {
  static Future<void> checkForUpdates(BuildContext context) async {
    if (!VersionService.isInitialized) {
      await VersionService.initialize();
    }

    try {
      debugPrint('🔍 UpdateChecker: Starting update check...');

      // Get current app info
      final appInfo = await VersionService.getCurrentAppInfo();
      final currentVersion = appInfo['version'] ?? '1.0.0';
      final platform = appInfo['platform'] ?? 'unknown';

      debugPrint('UpdateChecker: Current version: $currentVersion, Platform: $platform');

      // Check for updates from backend
      final updateInfo = await VersionService.checkForUpdates('');

      debugPrint('UpdateChecker: Update info received: $updateInfo');

      if (updateInfo.containsKey('forceUpdate') && updateInfo['forceUpdate'] == true) {
        debugPrint('🚨 UpdateChecker: Force update required!');

        // Determine store URLs based on platform
        String storeUrl;
        String storeName;

        if (platform.toLowerCase() == 'android') {
          storeUrl = 'https://play.google.com/store/apps/details?id=com.ButterflyTchnology.managereceipt';
          storeName = 'Play Store';
        } else if (platform.toLowerCase() == 'ios') {
          storeUrl = 'https://apps.apple.com/in/app/manage-receipt-track-expenses/id6746782746';
          storeName = 'App Store';
        } else {
          storeUrl = 'https://managereceipt.com/';
          storeName = 'Download Page';
        }

        // Show force update dialog
        if (context.mounted) {
          await _showForceUpdateDialog(
            context: context,
            currentVersion: currentVersion,
            latestVersion: updateInfo['latestVersion'] ?? 'Latest',
            minRequiredVersion: updateInfo['minRequiredVersion'] ?? 'Required',
            storeUrl: storeUrl,
            storeName: storeName,
          );
        }
      } else if (updateInfo.containsKey('optionalUpdate') && updateInfo['optionalUpdate'] == true) {
        debugPrint('📱 UpdateChecker: Optional update available');
        // Handle optional update if needed
      } else {
        debugPrint('✅ UpdateChecker: App is up to date');
      }

    } catch (e) {
      debugPrint('❌ UpdateChecker: Error checking for updates: $e');
      // Don't block app startup if update check fails
    }
  }

  static Future<void> _showForceUpdateDialog({
    required BuildContext context,
    required String currentVersion,
    required String latestVersion,
    required String minRequiredVersion,
    required String storeUrl,
    required String storeName,
  }) async {
    try {
      debugPrint('🎯 UpdateChecker: Showing force update dialog');

      await showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (BuildContext dialogContext) {
          return WillPopScope(
            onWillPop: () async => false, // Prevent dismissal
            child: ForceUpdateDialog(
              currentVersion: currentVersion,
              latestVersion: latestVersion,
              minRequiredVersion: minRequiredVersion,
              message: 'A new version of the app is required to continue. Please update from the $storeName to access all features.',
              downloadUrl: storeUrl,
              forceUpdate: true,
              optionalUpdate: false,
              isVersionConflict: false,
            ),
          );
        },
      );

      debugPrint('✅ UpdateChecker: Force update dialog completed');

    } catch (e) {
      debugPrint('❌ UpdateChecker: Error showing force update dialog: $e');
    }
  }
}
