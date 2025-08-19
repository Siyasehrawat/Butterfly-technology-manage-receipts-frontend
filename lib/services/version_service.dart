import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class VersionService {
  static PackageInfo? _packageInfo;
  static String? _currentVersion;
  static String? _platform;
  
  // Get base URL from environment with fallback
  static String get baseUrl {
    final envBase = dotenv.env['API_BASE_URL'];
    final resolvedBase = (envBase != null && envBase.isNotEmpty)
        ? envBase
        : 'https://manage-receipt-backend-1.onrender.com';
    if (envBase == null || envBase.isEmpty) {
      print('⚠️ API_BASE_URL missing in .env. Falling back to $resolvedBase');
    }
    return '$resolvedBase/api';
  }

  // Public getters to access private fields
  static String? get currentVersion => _currentVersion;
  static String? get platform => _platform;
  static PackageInfo? get packageInfo => _packageInfo;

  // Initialize version info
  static Future<void> initialize() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = _packageInfo?.version ?? '1.0.0';

      if (kIsWeb) {
        _platform = 'web';
      } else if (Platform.isAndroid) {
        _platform = 'android';
      } else if (Platform.isIOS) {
        _platform = 'ios';
      } else {
        _platform = 'unknown';
      }

      print('VersionService initialized - Version: $_currentVersion, Platform: $_platform');
    } catch (e) {
      print('Error initializing VersionService: $e');
      _currentVersion = '1.0.0';
      _platform = 'unknown';
    }
  }

  // Get headers with version and platform info
  static Map<String, String> getHeaders({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'currentVersion': _currentVersion ?? '1.0.0',
      'platform': _platform ?? 'unknown',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Get current app info
  static Future<Map<String, String>> getCurrentAppInfo() async {
    if (_packageInfo == null) {
      await initialize();
    }

    return {
      'version': _currentVersion ?? '1.0.0',
      'platform': _platform ?? 'unknown',
      'buildNumber': _packageInfo?.buildNumber ?? '1',
      'appName': _packageInfo?.appName ?? 'Manage Receipt',
    };
  }

  // Check if service is properly initialized
  static bool get isInitialized => _currentVersion != null && _platform != null;

  // Method to get version info as a formatted string
  static String get versionInfo => '${_currentVersion ?? "Unknown"} (${_platform ?? "Unknown"})';

  // Method to reset/reinitialize if needed
  static Future<void> reinitialize() async {
    _packageInfo = null;
    _currentVersion = null;
    _platform = null;
    await initialize();
  }

  // Compare version strings
  static int compareVersions(String version1, String version2) {
    List<int> v1Parts = version1.split('.').map(int.parse).toList();
    List<int> v2Parts = version2.split('.').map(int.parse).toList();

    int maxLength = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      int v1Part = i < v1Parts.length ? v1Parts[i] : 0;
      int v2Part = i < v2Parts.length ? v2Parts[i] : 0;

      if (v1Part < v2Part) return -1;
      if (v1Part > v2Part) return 1;
    }

    return 0;
  }

  // Check app version settings from backend
  static Future<Map<String, dynamic>> getAppVersionSettings(String token, String platform) async {
    try {
      final url = Uri.parse('$baseUrl/admin/version-settings/$platform');
      final headers = getHeaders(token: token);

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get version settings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting version settings: $e');
      rethrow;
    }
  }

  // Update app version settings (admin only)
  static Future<bool> updateAppVersionSettings(
      String token,
      String platform,
      String latestVersion,
      String minRequiredVersion,
      ) async {
    try {
      final url = Uri.parse('$baseUrl/admin/version-settings');
      final headers = getHeaders(token: token);

      final body = json.encode({
        'platform': platform,
        'latestVersion': latestVersion,
        'minRequiredVersion': minRequiredVersion,
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to update version settings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating version settings: $e');
      rethrow;
    }
  }

  // Check if app needs update
  static Future<Map<String, dynamic>> checkForUpdates(String token) async {
    try {
      final url = Uri.parse('$baseUrl/version/check');
      final headers = getHeaders(token: token);

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to check for updates: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking for updates: $e');
      rethrow;
    }
  }
}
