import 'package:flutter/material.dart';
import '../services/auth_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  String? _userId;
  String? _username;
  String? _email;
  String? _token;
  bool _hasAdminAccess = false;
  String? _country;
  String? _currency;
  String? _currencySymbol;
  final AuthManager _authManager = AuthManager();

  // Getters
  String? get userId => _userId;
  String? get username => _username;
  String? get email => _email;
  String? get token => _token;
  bool get hasAdminAccess => _hasAdminAccess;
  String? get country => _country;
  String? get currency => _currency;
  String? get currencySymbol => _currencySymbol;
  bool get isLoggedIn => _userId != null && _token != null;

  // Initialize from stored data
  Future<void> initFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ?? '';
    _userId = prefs.getString('userId') ?? '';

    final email = await _authManager.getUserEmail();
    final name = await _authManager.getUserName();
    final hasAdminAccess = await _authManager.hasAdminAccess();

    // Load country and currency from SharedPreferences
    final country = prefs.getString('country');
    final currency = prefs.getString('currency');
    final currencySymbol = prefs.getString('currencySymbol');

    print('UserProvider - Retrieved Token: $_token');
    print('UserProvider - Retrieved User ID: $_userId');
    print('UserProvider - Retrieved Admin Access: $hasAdminAccess');
    print('UserProvider - Retrieved Country: $country');
    print('UserProvider - Retrieved Currency: $currency');
    print('UserProvider - Retrieved Currency Symbol: $currencySymbol');

    if (_token != null && _token!.isNotEmpty && _userId != null && _userId!.isNotEmpty) {
      _email = email;
      _username = name;
      _hasAdminAccess = hasAdminAccess; // Properly set admin access
      _country = country;
      _currency = currency;
      _currencySymbol = currencySymbol;

      print('UserProvider - Admin access set to: $_hasAdminAccess');
      notifyListeners();
    }
  }

  // Login
  void login(
      String userId,
      String username,
      String email,
      String token, {
        bool hasAdminAccess = false,
        String? currency,
        String? currencySymbol,
      }) async {
    _userId = userId;
    _username = username;
    _email = email;
    _token = token;
    _hasAdminAccess = hasAdminAccess;

    print('UserProvider - Login: Setting admin access to: $hasAdminAccess');

    // Set currency and symbol if provided
    if (currency != null && currencySymbol != null) {
      _currency = currency;
      _currencySymbol = currencySymbol;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currency', currency);
      await prefs.setString('currencySymbol', currencySymbol);
    }

    // Save auth data to persistent storage
    await _authManager.saveAuthData(
      token: token,
      userId: userId,
      email: email,
      name: username,
      hasAdminAccess: hasAdminAccess,
    );

    print('UserProvider - Auth data saved with admin access: $hasAdminAccess');
    notifyListeners();
  }

  // Set country
  Future<void> setCountry(String country) async {
    _country = country;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('country', country);
    notifyListeners();
  }

  // Set currency
  Future<void> setCurrency(String currency, String currencySymbol) async {
    _currency = currency;
    _currencySymbol = currencySymbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency);
    await prefs.setString('currencySymbol', currencySymbol);
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    _userId = null;
    _username = null;
    _email = null;
    _token = null;
    _hasAdminAccess = false;
    _country = null;
    _currency = null;
    _currencySymbol = null;

    // Clear country and currency from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('country');
    await prefs.remove('currency');
    await prefs.remove('currencySymbol');

    await _authManager.clearAuthData();
    print('UserProvider - Logout: Admin access cleared');
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
    print('UserProvider - setAdminAccess called with: $hasAccess');

    if (_userId != null && _token != null) {
      _authManager.saveAuthData(
        token: _token!,
        userId: _userId!,
        email: _email,
        name: _username,
        hasAdminAccess: hasAccess,
      );
      print('UserProvider - Admin access saved to storage: $hasAccess');
    }
    notifyListeners();
  }
}