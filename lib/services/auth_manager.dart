import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthManager {
  // Keys for SharedPreferences
  static const String _tokenKey = 'token';
  static const String _userIdKey = 'userId';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _adminAccessKey = 'admin_access';
  static const String _userCountryKey = 'user_country';
  static const String _canUpdatePasswordKey = 'canUpdatePassword';

  // Save authentication data
  Future<void> saveAuthData({
    required String token,
    required String userId,
    String? email,
    String? name,
    String? country,
    bool hasAdminAccess = false,
    bool? canUpdatePassword,
  }) async {
    debugPrint('AuthManager: saveAuthData called with token: ${token.isNotEmpty ? 'present (${token.length} chars)' : 'MISSING'}, userId: ${userId.isNotEmpty ? 'present' : 'MISSING'}');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);

    if (email != null) {
      await prefs.setString(_userEmailKey, email);
    }

    if (name != null) {
      await prefs.setString(_userNameKey, name);
    }

    if (country != null) {
      await prefs.setString(_userCountryKey, country);
    }

    await prefs.setBool(_adminAccessKey, hasAdminAccess);

    if (canUpdatePassword != null) {
      await prefs.setBool(_canUpdatePasswordKey, canUpdatePassword);
    }

    debugPrint('AuthManager: Saved auth data for user: $userId with token: ${token.isNotEmpty ? 'present' : 'MISSING'}');
  }

  // Get token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null && token.isNotEmpty && token.length >= 20) {
      debugPrint('AuthManager: Retrieved token: ${token.substring(0, 20)}...');
    } else if (token != null && token.isNotEmpty) {
      debugPrint('AuthManager: Retrieved token: $token');
    } else {
      debugPrint('AuthManager: No token found');
    }
    return token;
  }

  // Get user ID
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Get user email
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  // Get user name
  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  // Get admin access status
  Future<bool> hasAdminAccess() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adminAccessKey) ?? false;
  }

  // Get user country
  Future<String?> getUserCountry() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userCountryKey);
  }

  // Get canUpdatePassword
  Future<bool> getCanUpdatePassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_canUpdatePasswordKey) ?? false;
  }

  // Validate token format
  bool isValidTokenFormat(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        debugPrint('AuthManager: Invalid token format - wrong number of parts');
        return false;
      }

      if (token.length < 50) {
        debugPrint('AuthManager: Invalid token format - too short');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('AuthManager: Error validating token format: $e');
      return false;
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    final userId = await getUserId();
    final isValid = token != null && userId != null && token.isNotEmpty && userId.isNotEmpty;
    debugPrint('AuthManager: User logged in: $isValid');
    return isValid;
  }

  // Clear authentication data
  Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userCountryKey);
    await prefs.remove(_adminAccessKey);
    await prefs.remove(_canUpdatePasswordKey);
    debugPrint('AuthManager: Cleared all auth data');
  }

  // Get all auth data at once
  Future<Map<String, dynamic>?> getAllAuthData() async {
    try {
      final token = await getToken();
      final userId = await getUserId();
      final email = await getUserEmail();
      final name = await getUserName();
      final hasAdmin = await hasAdminAccess();
      final country = await getUserCountry();
      final canUpdatePassword = await getCanUpdatePassword();

      if (token == null || userId == null) {
        return null;
      }

      return {
        'token': token,
        'userId': userId,
        'email': email,
        'name': name,
        'hasAdminAccess': hasAdmin,
        'country': country,
        'canUpdatePassword': canUpdatePassword,
      };
    } catch (e) {
      debugPrint('AuthManager: Error getting all auth data: $e');
      return null;
    }
  }
}
