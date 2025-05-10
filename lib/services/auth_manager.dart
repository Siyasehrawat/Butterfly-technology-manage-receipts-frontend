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
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);

    if (email != null) {
      await _storage.write(key: _userEmailKey, value: email);
    }

    if (name != null) {
      await _storage.write(key: _userNameKey, value: name);
    }
  }

  // Get the stored token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Save the token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // Get the stored user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  // Get the stored email
  Future<String?> getUserEmail() async {
    return await _storage.read(key: _userEmailKey);
  }

  // Get the stored name
  Future<String?> getUserName() async {
    return await _storage.read(key: _userNameKey);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
