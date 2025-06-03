import 'package:flutter/material.dart';
import '../services/auth_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  String? _userId;
  String? _username;
  String? _email;
  String? _token;
  bool _hasAdminAccess = false;
  String? _country; // Added country field
  final AuthManager _authManager = AuthManager();

  // Getters
  String? get userId => _userId;
  String? get username => _username;
  String? get email => _email;
  String? get token => _token;
  bool get hasAdminAccess => _hasAdminAccess;
  String? get country => _country; // Added country getter
  bool get isLoggedIn => _userId != null && _token != null;

  // Initialize from stored data
  Future<void> initFromStorage() async {
    final token = await _authManager.getToken();
    final userId = await _authManager.getUserId();
    final email = await _authManager.getUserEmail();
    final name = await _authManager.getUserName();
    final hasAdminAccess = await _authManager.hasAdminAccess();

    // Load country from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final country = prefs.getString('country');

    print('Retrieved Token: $token');
    print('Retrieved User ID: $userId');
    print('Retrieved Country: $country');

    if (token != null && userId != null) {
      _token = token;
      _userId = userId;
      _email = email;
      _username = name;
      _hasAdminAccess = hasAdminAccess;
      _country = country; // Set country
      notifyListeners();
    }
  }

  // Login
  void login(String userId, String username, String email, String token, {bool hasAdminAccess = false}) {
    _userId = userId;
    _username = username;
    _email = email;
    _token = token;
    _hasAdminAccess = hasAdminAccess;

    // Save auth data to persistent storage
    _authManager.saveAuthData(
      token: token,
      userId: userId,
      email: email,
      name: username,
      hasAdminAccess: hasAdminAccess,
    );

    notifyListeners();
  }

  // Set country
  Future<void> setCountry(String country) async {
    _country = country;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('country', country);
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    _userId = null;
    _username = null;
    _email = null;
    _token = null;
    _hasAdminAccess = false;
    _country = null; // Clear country

    // Clear country from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('country');

    await _authManager.clearAuthData();
    notifyListeners();
  }

  // Update user info
  void updateUserInfo({String? username, String? email}) {
    if (username != null) {
      _username = username;
      if (_userId != null && _token != null) {
        _authManager.saveAuthData(
          token: _token!,
          userId: _userId!,
          email: _email,
          name: username,
          hasAdminAccess: _hasAdminAccess,
        );
      }
    }

    if (email != null) {
      _email = email;
      if (_userId != null && _token != null) {
        _authManager.saveAuthData(
          token: _token!,
          userId: _userId!,
          email: email,
          name: _username,
          hasAdminAccess: _hasAdminAccess,
        );
      }
    }

    notifyListeners();
  }

  void setToken(String token) {
    _token = token;
    if (_userId != null) {
      _authManager.saveAuthData(
        token: token,
        userId: _userId!,
        email: _email,
        name: _username,
        hasAdminAccess: _hasAdminAccess,
      );
    }
    notifyListeners();
  }

  void setUserId(String userId) {
    _userId = userId;
    if (_token != null) {
      _authManager.saveAuthData(
        token: _token!,
        userId: userId,
        email: _email,
        name: _username,
        hasAdminAccess: _hasAdminAccess,
      );
    }
    notifyListeners();
  }

  void setAdminAccess(bool hasAccess) {
    _hasAdminAccess = hasAccess;
    if (_userId != null && _token != null) {
      _authManager.saveAuthData(
        token: _token!,
        userId: _userId!,
        email: _email,
        name: _username,
        hasAdminAccess: hasAccess,
      );
    }
    notifyListeners();
  }
}