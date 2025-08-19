import 'package:flutter/material.dart';

class SubscriptionUpgradeDialog {
  // BYPASS: Never show upgrade dialog, always return without action
  static Future<void> show(
      BuildContext context, { // Changed userId and token to named parameters
        required String userId,
        required String token,
        String title = 'Premium Feature',
        String message = 'This feature requires a premium subscription.',
      }) async {
    debugPrint('BYPASS MODE: Upgrade dialog suppressed - user has unlimited access');

    // BYPASS: Show a brief message that feature is available (optional)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feature unlocked! Enjoy unlimited access.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );

    // BYPASS: Don't show any blocking dialog
    return;
  }
}
