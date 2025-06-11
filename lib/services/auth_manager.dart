import 'package:shared_preferences/shared_preferences.dart';

class AuthManager {
  // Keys for SharedPreferences
  static const String _tokenKey = 'token'; // Changed key to 'token'
  static const String _userIdKey = 'userId'; // Changed key to 'userId'
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _adminAccessKey =
      'admin_access'; // Added key for admin access

  // Save authentication data
  Future<void> saveAuthData({
    required String token,
    required String userId,
    String? email,
    String? name,
    bool hasAdminAccess = false, // Added parameter for admin access
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);

    if (email != null) {
      await prefs.setString(_userEmailKey, email);
    }

    if (name != null) {
      await prefs.setString(_userNameKey, name);
    }

    // Save admin access status
    await prefs.setBool(_adminAccessKey, hasAdminAccess);
  }

  // Get token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
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

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    final userId = await getUserId();
    return token != null && userId != null;
  }

  // Clear authentication data
  Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_adminAccessKey); // Clear admin access status
  }
}
