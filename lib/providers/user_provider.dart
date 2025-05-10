import 'package:flutter/material.dart';
import '../services/auth_manager.dart';

class UserProvider with ChangeNotifier {
  String? _userId;
  String? _username;
  String? _email;
  String? _token;
  final AuthManager _authManager = AuthManager();

  // Getters
  String? get userId => _userId;
  String? get username => _username;
  String? get email => _email;
  String? get token => _token;

  bool get isLoggedIn => _userId != null && _token != null;

  // Initialize from stored data
  Future<void> initFromStorage() async {
    final token = await _authManager.getToken();
    final userId = await _authManager.getUserId();
    print('Retrieved Token: $token');
    print('Retrieved User ID: $userId');

    if (token != null && userId != null) {
      _token = token;
      _userId = userId;
      notifyListeners();
    }
  }

  // Login
  void login(String userId, String username, String email, String token) {
    _userId = userId;
    _username = username;
    _email = email;
    _token = token;

    // Save token to persistent storage
    _authManager.saveToken(token);

    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    _userId = null;
    _username = null;
    _email = null;
    _token = null;
    await _authManager.clearAuthData();
    notifyListeners();
  }

  // Update user info
  void updateUserInfo({String? username, String? email}) {
    if (username != null) _username = username;
    if (email != null) _email = email;
    notifyListeners();
  }

  void setToken(String token) {
    _token = token;
    notifyListeners();
  }

  void setUserId(String userId) {
    _userId = userId;
    notifyListeners();
  }
}
