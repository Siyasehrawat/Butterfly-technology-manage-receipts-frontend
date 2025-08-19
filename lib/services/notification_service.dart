import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'fcm_service.dart';
import 'api_service_bypass.dart';

class NotificationService {
  // Send FCM token to backend
  static Future<void> sendTokenToBackend(String userId) async {
    try {
      final token = FCMService.fcmToken;
      if (token == null) {
        debugPrint('FCM token is null');
        return;
      }

      final response = await ApiService.post(
        '/users/update-fcm-token',
        body: {
          'userId': userId,
          'fcmToken': token,
        },
      );

      if (response.statusCode == 200) {
        debugPrint('FCM token sent to backend successfully');
      } else {
        debugPrint('Failed to send FCM token: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending FCM token to backend: $e');
    }
  }

  // Remove FCM token from backend (on logout)
  static Future<void> removeTokenFromBackend(String userId) async {
    try {
      final token = FCMService.fcmToken;
      if (token == null) return;

      // You might need to create a DELETE endpoint or use the same POST endpoint with empty token
      final response = await ApiService.post(
        '/users/update-fcm-token',
        body: {
          'userId': userId,
          'fcmToken': '', // Empty token to remove
        },
      );

      if (response.statusCode == 200) {
        debugPrint('FCM token removed from backend successfully');
      } else {
        debugPrint('Failed to remove FCM token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error removing FCM token from backend: $e');
    }
  }

  // Subscribe to user-specific topic
  static Future<void> subscribeToUserTopic(String userId) async {
    await FCMService.subscribeToTopic('user_$userId');
  }

  // Unsubscribe from user-specific topic
  static Future<void> unsubscribeFromUserTopic(String userId) async {
    await FCMService.unsubscribeFromTopic('user_$userId');
  }

  // Send token when user logs in
  static Future<void> onUserLogin(String userId) async {
    await sendTokenToBackend(userId);
    await subscribeToUserTopic(userId);
  }

  // Remove token when user logs out
  static Future<void> onUserLogout(String userId) async {
    await unsubscribeFromUserTopic(userId);
    await removeTokenFromBackend(userId);
  }
}
