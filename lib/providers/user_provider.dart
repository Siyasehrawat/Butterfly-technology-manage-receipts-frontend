import 'package:flutter/material.dart';
import '../services/auth_manager.dart';
import '../services/currency_service.dart';
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

  // Get currency symbol with fallback logic
  String get effectiveCurrencySymbol {
    // First try user's stored currency symbol
    if (_currencySymbol != null && _currencySymbol!.isNotEmpty) {
      return _currencySymbol!;
    }

    // Then try to get from country mapping
    if (_country != null && _country!.isNotEmpty) {
      return CurrencyService.getCurrencySymbol(_country!);
    }

    // Default fallback
    return '\$';
  }

  // Get currency code with fallback logic
  String get effectiveCurrencyCode {
    // First try user's stored currency
    if (_currency != null && _currency!.isNotEmpty) {
      return _currency!;
    }

    // Then try to get from country mapping
    if (_country != null && _country!.isNotEmpty) {
      return CurrencyService.getCurrencyCode(_country!);
    }

    // Default fallback
    return 'USD';
  }

  // Initialize from stored data
  Future<void> initFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ?? '';
    _userId = prefs.getString('userId') ?? '';

    final email = await _authManager.getUserEmail();
    final name = await _authManager.getUserName();
    final hasAdminAccess = await _authManager.hasAdminAccess();
    final country = await _authManager.getUserCountry();

    // Load currency from SharedPreferences
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
      _hasAdminAccess = hasAdminAccess;
      _country = country;
      _currency = currency;
      _currencySymbol = currencySymbol;

      // If we have country but no currency, map it
      if (_country != null && _country!.isNotEmpty &&
          (_currency == null || _currencySymbol == null)) {
        final currencyInfo = CurrencyService.getCurrencyForCountry(_country!);
        _currency = _currency ?? currencyInfo['currency'];
        _currencySymbol = _currencySymbol ?? currencyInfo['symbol'];

        // Save the mapped currency
        await prefs.setString('currency', _currency!);
        await prefs.setString('currencySymbol', _currencySymbol!);

        print('UserProvider - Mapped country to currency: $_currency ($_currencySymbol)');
      }

      print('UserProvider - Final currency: $_currency ($_currencySymbol)');
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
        String? country,
        String? currency,
        String? currencySymbol,
      }) async {
    _userId = userId;
    _username = username;
    _email = email;
    _token = token;
    _hasAdminAccess = hasAdminAccess;

    print('UserProvider - Login: Setting admin access to: $hasAdminAccess');

    // Set country if provided
    if (country != null) {
      _country = country;
      await setCountry(country);
      print('UserProvider - Login: Setting country to: $country');
    }

    // Set currency and symbol if provided, otherwise map from country
    if (currency != null && currencySymbol != null) {
      _currency = currency;
      _currencySymbol = currencySymbol;
    } else if (_country != null) {
      // Map currency from country
      final currencyInfo = CurrencyService.getCurrencyForCountry(_country!);
      _currency = currency ?? currencyInfo['currency'];
      _currencySymbol = currencySymbol ?? currencyInfo['symbol'];
      print('UserProvider - Mapped currency from country: $_currency ($_currencySymbol)');
    }

    // Save currency to SharedPreferences
    if (_currency != null && _currencySymbol != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currency', _currency!);
      await prefs.setString('currencySymbol', _currencySymbol!);
    }

    // Save auth data to persistent storage
    await _authManager.saveAuthData(
      token: token,
      userId: userId,
      email: email,
      name: username,
      hasAdminAccess: hasAdminAccess,
      country: country,
    );

    print('UserProvider - Auth data saved with currency: $_currency ($_currencySymbol)');
    notifyListeners();
  }

  // Set country and update currency accordingly
  Future<void> setCountry(String country) async {
    _country = country;

    // Map currency from country
    final currencyInfo = CurrencyService.getCurrencyForCountry(country);
    _currency = currencyInfo['currency'];
    _currencySymbol = currencyInfo['symbol'];

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('country', country);
    await prefs.setString('currency', _currency!);
    await prefs.setString('currencySymbol', _currencySymbol!);

    // Also save to AuthManager
    if (_userId != null && _token != null) {
      await _authManager.saveAuthData(
        token: _token!,
        userId: _userId!,
        email: _email,
        name: _username,
        hasAdminAccess: _hasAdminAccess,
        country: country,
      );
    }

    print('UserProvider - Country set to: $country, Currency: $_currency ($_currencySymbol)');
    notifyListeners();
  }

  // Set currency manually
  Future<void> setCurrency(String currency, String currencySymbol) async {
    _currency = currency;
    _currencySymbol = currencySymbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency);
    await prefs.setString('currencySymbol', currencySymbol);
    notifyListeners();
  }

  // Logout - preserve currency settings
  Future<void> logout() async {
    // Store current currency before logout
    final currentCurrency = _currency;
    final currentCurrencySymbol = _currencySymbol;
    final currentCountry = _country;

    _userId = null;
    _username = null;
    _email = null;
    _token = null;
    _hasAdminAccess = false;

    // Clear auth data but preserve currency settings
    await _authManager.clearAuthData();

    // Restore currency settings
    if (currentCountry != null) {
      _country = currentCountry;
      _currency = currentCurrency;
      _currencySymbol = currentCurrencySymbol;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('country', currentCountry);
      if (currentCurrency != null) await prefs.setString('currency', currentCurrency);
      if (currentCurrencySymbol != null) await prefs.setString('currencySymbol', currentCurrencySymbol);
    }

    print('UserProvider - Logout: User data cleared, currency preserved');
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
          country: _country,
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
          country: _country,
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
        country: _country,
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
        country: _country,
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
        country: _country,
      );
      print('UserProvider - Admin access saved to storage: $hasAccess');
    }
    notifyListeners();
  }
}
