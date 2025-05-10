import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthManager {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';

  static final AuthManager _instance = AuthManager._internal();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  factory AuthManager() {
    return _instance;
  }

  AuthManager._internal();

  // Save authentication data
  Future<void> saveAuthData({
    required String token,
    required String userId,
    String? email,
    String? name,
  }) async {
    // Store in secure storage
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);

    if (email != null) {
      await _storage.write(key: _userEmailKey, value: email);
    }

    if (name != null) {
      await _storage.write(key: _userNameKey, value: name);
    }

    // Also store in SharedPreferences for faster access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('userId', userId);
    if (email != null) await prefs.setString('email', email);
    if (name != null) await prefs.setString('name', name);
  }

  // Get the stored token
  Future<String?> getToken() async {
    try {
      // Try to get from secure storage first
      String? token = await _storage.read(key: _tokenKey);

      // If not found, try SharedPreferences
      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('token');

        // If found in SharedPreferences but not in secure storage, restore it
        if (token != null) {
          await _storage.write(key: _tokenKey, value: token);
        }
      }

      return token;
    } catch (e) {
      // Fallback to SharedPreferences if secure storage fails
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    }
  }

  // Get the stored user ID
  Future<String?> getUserId() async {
    try {
      String? userId = await _storage.read(key: _userIdKey);

      if (userId == null) {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('userId');
      }

      return userId;
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userId');
    }
  }

  // Get the stored email
  Future<String?> getUserEmail() async {
    try {
      String? email = await _storage.read(key: _userEmailKey);

      if (email == null) {
        final prefs = await SharedPreferences.getInstance();
        email = prefs.getString('email');
      }

      return email;
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('email');
    }
  }

  // Get the stored name
  Future<String?> getUserName() async {
    try {
      String? name = await _storage.read(key: _userNameKey);

      if (name == null) {
        final prefs = await SharedPreferences.getInstance();
        name = prefs.getString('name');
      }

      return name;
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('name');
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null) return false;

    // Check if token is expired
    try {
      final isExpired = JwtDecoder.isExpired(token);
      return !isExpired;
    } catch (e) {
      // If there's an error decoding the token, consider the user not logged in
      return false;
    }
  }

  // Extract user ID from token
  String? extractUserIdFromToken(String token) {
    try {
      final decodedToken = JwtDecoder.decode(token);
      return decodedToken['id'];
    } catch (e) {
      return null;
    }
  }

  // Clear authentication data (logout)
  Future<void> clearAuthData() async {
    try {
      // Clear secure storage
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userIdKey);
      await _storage.delete(key: _userEmailKey);
      await _storage.delete(key: _userNameKey);
    } catch (e) {
      // Ignore errors when clearing secure storage
    }

    // Also clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}