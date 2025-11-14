import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_service_bypass.dart';
import '../widgets/calendar_auth_webview.dart';
import '../widgets/calendar_auth_fallback.dart';

class CalendarSyncService {
  static const String _base = '/calendar';

  /// Check if user has connected Google Calendar
  static Future<bool> isCalendarConnected(String userId, {String? token}) async {
    try {
      final http.Response res = await ApiService.get(
        '$_base/status?userId=$userId',
        token: token,
      );
      
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        return body['calendarSyncEnabled'] ?? false;
      }
      
      return false;
    } catch (e) {
      debugPrint('CalendarSyncService.isCalendarConnected error: $e');
      return false;
    }
  }

  /// Get calendar connection status details
  static Future<Map<String, dynamic>?> getCalendarStatus(String userId, {String? token}) async {
    try {
      final http.Response res = await ApiService.get(
        '$_base/status?userId=$userId',
        token: token,
      );
      
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
      
      return null;
    } catch (e) {
      debugPrint('CalendarSyncService.getCalendarStatus error: $e');
      return null;
    }
  }

  /// Get OAuth URL to connect calendar
  static Future<String?> getAuthUrl(String userId, {String? token}) async {
    try {
      final http.Response res = await ApiService.get(
        '$_base/auth/url?userId=$userId',
        token: token,
      );
      
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        return body['authUrl'];
      }
      
      return null;
    } catch (e) {
      debugPrint('CalendarSyncService.getAuthUrl error: $e');
      return null;
    }
  }

  /// Connect Google Calendar using WebView or external browser
  /// Returns true if successfully connected, false otherwise
  static Future<bool> connectCalendar(String userId, {String? token, BuildContext? context}) async {
    try {
      debugPrint('🔗 Starting calendar connection for userId: $userId');
      
      // Get the OAuth URL
      final authUrl = await getAuthUrl(userId, token: token);
      
      if (authUrl == null) {
        debugPrint('❌ Failed to get auth URL');
        return false;
      }
      
      debugPrint('📱 Got auth URL: $authUrl');
      
      // If context is provided, open WebView for OAuth
      if (context != null && context.mounted) {
        try {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => CalendarAuthWebView(
                authUrl: authUrl,
                userId: userId,
              ),
            ),
          );
          
          if (result == true) {
            debugPrint('✅ OAuth completed successfully');
            // Wait a moment for backend to process
            await Future.delayed(const Duration(seconds: 2));
            // Verify connection
            final isConnected = await isCalendarConnected(userId, token: token);
            debugPrint('📊 Connection verified: $isConnected');
            return isConnected;
          } else {
            debugPrint('❌ OAuth was cancelled or failed');
            return false;
          }
        } catch (e) {
          debugPrint('❌ WebView navigation failed: $e');
          // Fallback to external browser widget
          try {
            final fallbackResult = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => CalendarAuthFallback(
                  authUrl: authUrl,
                  userId: userId,
                ),
              ),
            );
            
            if (fallbackResult == true) {
              debugPrint('✅ Fallback OAuth completed successfully');
              // Wait a moment for backend to process
              await Future.delayed(const Duration(seconds: 2));
              // Verify connection
              final isConnected = await isCalendarConnected(userId, token: token);
              debugPrint('📊 Connection verified: $isConnected');
              return isConnected;
            } else {
              debugPrint('❌ Fallback OAuth was cancelled or failed');
              return false;
            }
          } catch (fallbackError) {
            debugPrint('❌ Fallback navigation also failed: $fallbackError');
            return false;
          }
        }
      } else {
        debugPrint('⚠️ No context provided, trying external browser');
        return await _connectWithExternalBrowser(authUrl, userId, token: token);
      }
    } catch (e) {
      debugPrint('❌ CalendarSyncService.connectCalendar error: $e');
      return false;
    }
  }
  
  /// Fallback method to connect using external browser
  static Future<bool> _connectWithExternalBrowser(String authUrl, String userId, {String? token}) async {
    try {
      debugPrint('🌐 Using external browser fallback');
      
      // Import url_launcher
      final url = Uri.parse(authUrl);
      
      // This would require importing url_launcher, but to avoid circular imports,
      // we'll return false and let the UI handle the external browser opening
      debugPrint('⚠️ External browser fallback not implemented in service layer');
      return false;
    } catch (e) {
      debugPrint('❌ External browser fallback failed: $e');
      return false;
    }
  }

  /// Disconnect Google Calendar
  static Future<bool> disconnectCalendar(String userId, {String? token}) async {
    try {
      final http.Response res = await ApiService.post(
        '$_base/disconnect',
        body: {'userId': userId},
        token: token,
      );
      
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('CalendarSyncService.disconnectCalendar error: $e');
      return false;
    }
  }

  /// Sync an existing reminder to Google Calendar
  static Future<bool> syncReminderToCalendar({
    required String reminderId,
    required String calendarId,
    required String calendarType,
    String? token,
  }) async {
    try {
      final http.Response res = await ApiService.post(
        '$_base/sync',
        body: {
          'reminderId': reminderId,
          'calendarId': calendarId,
          'calendarType': calendarType,
        },
        token: token,
      );
      
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('CalendarSyncService.syncReminderToCalendar error: $e');
      return false;
    }
  }

  /// Unsync a reminder from Google Calendar
  static Future<bool> unsyncReminderFromCalendar({
    required String reminderId,
    String? token,
  }) async {
    try {
      final http.Response res = await ApiService.post(
        '$_base/unsync',
        body: {
          'reminderId': reminderId,
        },
        token: token,
      );
      
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('CalendarSyncService.unsyncReminderFromCalendar error: $e');
      return false;
    }
  }
}