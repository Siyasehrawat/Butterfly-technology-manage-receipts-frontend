import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service_bypass.dart';
import '../services/auth_manager.dart';
import '../services/currency_service.dart';
import '../services/fcm_service.dart';
import '../services/notification_service.dart';
import '../providers/feature_flags_provider.dart';
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
  bool? _hasDocWalletSetup;
  bool _canUpdatePassword = false;
  bool _hasWallet = false;
  bool _isPinRequired = false;

  // Getters
  String? get userId => _userId;
  String? get username => _username;
  String? get email => _email;
  // Non-null convenience getter for places that need an email for UX defaults
  String get effectiveEmail => (_email ?? '').isNotEmpty ? _email! : '';
  // Safe username for UI: prefer explicit name, then email prefix, else 'User'
  String get effectiveUsername {
    if (_username != null && _username!.trim().isNotEmpty) {
      return _username!;
    }
    if (_email != null && _email!.isNotEmpty) {
      final prefix = _email!.split('@').first;
      if (prefix.isNotEmpty) return prefix;
    }
    return 'User';
  }
  String? get token => _token;
  bool get hasAdminAccess => _hasAdminAccess;
  String? get country => _country;
  String? get currency => _currency;
  String? get currencySymbol => _currencySymbol;
  bool get isLoggedIn => _userId != null && _token != null;
  bool get hasDocWalletSetup => _hasDocWalletSetup ?? false;
  bool get canUpdatePassword {
    print('UserProvider - canUpdatePassword getter called, returning: $_canUpdatePassword');
    return _canUpdatePassword;
  }

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

  get otp => null;


 
  

  // Initialize from stored data - Enhanced to properly load username and feature flags
  Future<void> initFromStorage([BuildContext? context]) async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ?? '';
    _userId = prefs.getString('userId') ?? '';
    
    print('UserProvider - initFromStorage: Retrieved from SharedPreferences - Token: ${_token?.isNotEmpty == true ? 'present (${_token?.length} chars)' : 'MISSING'}, UserId: ${_userId?.isNotEmpty == true ? 'present' : 'MISSING'}');
    
    if (_userId != null && _userId!.isNotEmpty) {
      _hasDocWalletSetup = prefs.getBool('has_doc_wallet_pin_$_userId');
      _hasWallet = prefs.getBool('has_wallet_$_userId') ?? false;
      _isPinRequired = prefs.getBool('pin_required_$_userId') ?? false;
      print('UserProvider - Retrieved Doc Wallet Status: $_hasDocWalletSetup, hasWallet: $_hasWallet, pinRequired: $_isPinRequired');
    }
    _canUpdatePassword = prefs.getBool('canUpdatePassword') ?? false;
    print('UserProvider - initFromStorage: Loaded canUpdatePassword from SharedPreferences: $_canUpdatePassword');
    notifyListeners();
    
    final email = await _authManager.getUserEmail();
    final name = await _authManager.getUserName(); // This loads the cached username
    final hasAdminAccess = await _authManager.hasAdminAccess();
    final country = await _authManager.getUserCountry();

    // Load currency from SharedPreferences
    final currency = prefs.getString('currency');
    final currencySymbol = prefs.getString('currencySymbol');

    print('UserProvider - Retrieved Token: $_token');
    print('UserProvider - Retrieved User ID: $_userId');
    print('UserProvider - Retrieved Username: $name'); // Enhanced logging
    print('UserProvider - Retrieved Admin Access: $hasAdminAccess');
    print('UserProvider - Retrieved Country: $country');
    print('UserProvider - Retrieved Currency: $currency');
    print('UserProvider - Retrieved Currency Symbol: $currencySymbol');

    // Make email/username available to UI ASAP, regardless of token/userId availability
    if ((email != null && email.isNotEmpty) || (name != null && name.isNotEmpty)) {
      if (email != null && email.isNotEmpty) {
        _email = email;
      }
      if (name != null && name.isNotEmpty) {
        _username = name;
      }
      notifyListeners();
    }

    if (_token != null && _token!.isNotEmpty && _userId != null && _userId!.isNotEmpty) {
      _email = email ?? _email;
      _username = name ?? _username; // Set the cached username
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

      // Initialize FCM for existing user session
      if (!kIsWeb && _userId != null) {
        FCMService.setCurrentUserId(_userId!);
        await NotificationService.onUserLogin(_userId!);
      }

      // Initialize feature flags if context is available
      if (context != null) {
        await _initializeFeatureFlags(context);
      }

      print('UserProvider - Final currency: $_currency ($_currencySymbol)');
      print('UserProvider - Final username: $_username'); // Enhanced logging
      notifyListeners();
    }
  }

  // Login
  Future<void> login(
      String userId,
      String username,
      String email,
      String token, {
        bool hasAdminAccess = false,
        String? country,
        String? currency,
        String? currencySymbol,
        bool? canUpdatePassword,
        BuildContext? context,
      }) async {
    _userId = userId;
    _username = username;
    _email = email;
    _token = token;
    _hasAdminAccess = hasAdminAccess;
    // Respect backend flag passed in; default to false if not provided
    _canUpdatePassword = canUpdatePassword ?? false;

    print('UserProvider - Login: Setting admin access to: $hasAdminAccess');
    print('UserProvider - Login: Setting username to: $username'); // Enhanced logging
    print('UserProvider - Login: Setting canUpdatePassword to: $_canUpdatePassword (received: $canUpdatePassword)');

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

    // Persist canUpdatePassword
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('canUpdatePassword', _canUpdatePassword);
    } catch (e) {
      print('UserProvider - Error saving canUpdatePassword: $e');
    }

    // Save auth data to persistent storage - This will cache the username
    print('UserProvider - login: About to save token: ${token.isNotEmpty ? 'present (${token.length} chars)' : 'MISSING'}, userId: ${userId.isNotEmpty ? 'present' : 'MISSING'}');
    
    await _authManager.saveAuthData(
      token: token,
      userId: userId,
      email: email,
      name: username, // This caches the username in AuthManager
      hasAdminAccess: hasAdminAccess,
      country: country,
    );
    
    print('UserProvider - login: Auth data saved to AuthManager');

    // Initialize FCM after successful login
    if (!kIsWeb) {
      FCMService.setCurrentUserId(userId);
      await NotificationService.onUserLogin(userId);
    }

    // Initialize feature flags after successful login
    if (context != null) {
      await _initializeFeatureFlags(context);
    }

    print('UserProvider - Auth data saved with currency: $_currency ($_currencySymbol)');
    print('UserProvider - Auth data saved with username: $username'); // Enhanced logging
    print('UserProvider - canUpdatePassword: $_canUpdatePassword');
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

    // Clear FCM data before logout
    if (!kIsWeb) {
      FCMService.clearCurrentUser();
    }

    _userId = null;
    _username = null; // Clear username on logout
    _email = null;
    _token = null;
    _hasAdminAccess = false;
    _canUpdatePassword = false;

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

  // Update canUpdatePassword and persist
  Future<void> setCanUpdatePassword(bool canUpdate) async {
    print('UserProvider - setCanUpdatePassword called with: $canUpdate');
    _canUpdatePassword = canUpdate;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('canUpdatePassword', canUpdate);
      print('UserProvider - canUpdatePassword saved to SharedPreferences: $canUpdate');
    } catch (e) {
      print('UserProvider - Error persisting canUpdatePassword: $e');
    }
    notifyListeners();
  }

  // Method to update canUpdatePassword from API response
  Future<void> updateCanUpdatePasswordFromApi(bool canUpdate) async {
    print('UserProvider - updateCanUpdatePasswordFromApi called with: $canUpdate');
    await setCanUpdatePassword(canUpdate);
  }

  // Enhanced update user info method with better caching and immediate notification
  void updateUserInfo({String? username, String? email, required String userId, required String token}) async {
    bool shouldNotify = false;

    // Update token if provided and different
    if (token.isNotEmpty && token != _token) {
      final oldToken = _token;
      _token = token;
      shouldNotify = true;
      print('UserProvider - Token updated from ${oldToken?.isNotEmpty == true ? 'present' : 'missing'} to: ${token.isNotEmpty ? 'present (${token.length} chars)' : 'missing'}');
    }

    // Update userId if provided and different
    if (userId.isNotEmpty && userId != _userId) {
      final oldUserId = _userId;
      _userId = userId;
      shouldNotify = true;
      print('UserProvider - UserId updated from ${oldUserId ?? 'missing'} to: $userId');
    }

    if (username != null && username != _username) {
      final oldUsername = _username;
      _username = username;
      shouldNotify = true;
      print('UserProvider - Username updated from $oldUsername to: $username');

      // Immediately update cached username in SharedPreferences
      if (_userId != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name_$_userId', username);
          print('UserProvider - Updated cached username in SharedPreferences');
        } catch (e) {
          print('UserProvider - Error updating cached username: $e');
        }
      }

      // Update in persistent storage
      if (_userId != null && _token != null) {
        await _authManager.saveAuthData(
          token: _token!,
          userId: _userId!,
          email: _email,
          name: username, // Cache the updated username
          hasAdminAccess: _hasAdminAccess,
          country: _country,
        );
        print('UserProvider - Updated username in AuthManager');
      }
    }

    if (email != null && email != _email) {
      _email = email;
      shouldNotify = true;

      // Update in persistent storage
      if (_userId != null && _token != null) {
        await _authManager.saveAuthData(
          token: _token!,
          userId: _userId!,
          email: email,
          name: _username, // Preserve username when updating email
          hasAdminAccess: _hasAdminAccess,
          country: _country,
        );
      }
    }

    if (shouldNotify) {
      print('UserProvider - Notifying listeners of user info update');
      notifyListeners();
    }
  }

  void setToken(String token) {
    _token = token;
    if (_userId != null) {
      _authManager.saveAuthData(
        token: token,
        userId: _userId!,
        email: _email,
        name: _username, // Preserve username when updating token
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
        name: _username, // Preserve username when updating userId
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
        name: _username, // Preserve username when updating admin access
        hasAdminAccess: hasAccess,
        country: _country,
      );
      print('UserProvider - Admin access saved to storage: $hasAccess');
    }
    notifyListeners();
  }

  // Method to update doc wallet status
  Future<void> updateDocWalletStatus(bool isSetup) async {
    if (_userId != null) {
      _hasDocWalletSetup = isSetup;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_doc_wallet_pin_$_userId', isSetup);
      print('UserProvider - Doc Wallet Status updated: $isSetup');
      notifyListeners();
    }
  }

  // Method to check doc wallet status from API with caching
  Future<void> checkAndCacheDocWalletStatus(String token) async {
    if (_userId == null) return;

    try {
      final response = await ApiService.get(
        '/doc-wallet/status?userId=$_userId',
        token: token,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final isSetup = data['data']['isSetup'] ?? false;
        final hasWallet = data['data']['hasWallet'] ?? false;
        final pinRequired = data['data']['pinRequired'] ?? false;
        
        await updateDocWalletStatus(isSetup);
        
        // Update local variables
        _hasWallet = hasWallet;
        _isPinRequired = pinRequired;
        
        // Store additional wallet info in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_wallet_$_userId', hasWallet);
        await prefs.setBool('pin_required_$_userId', pinRequired);
        
        notifyListeners();
        print('UserProvider - Doc Wallet Status fetched from API: isSetup=$isSetup, hasWallet=$hasWallet, pinRequired=$pinRequired');
      }
    } catch (e) {
      print('UserProvider - Error fetching Doc Wallet status: $e');
      // Keep existing cached value, don't update
    }
  }

  // Getter for wallet status
  bool get hasWallet => _hasWallet;
  bool get isPinRequired => _isPinRequired;

  // Method to get cached wallet info
  Future<bool> getHasWallet() async {
    if (_userId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_wallet_$_userId') ?? false;
  }

  Future<bool> getIsPinRequired() async {
    if (_userId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('pin_required_$_userId') ?? false;
  }

  // Method to handle wallet navigation based on API status
  Future<Map<String, dynamic>> getWalletNavigationInfo(String token) async {
    try {
      // First check cached status
      final isSetup = _hasDocWalletSetup ?? false;
      final hasWallet = _hasWallet;
      final pinRequired = _isPinRequired;

      // If we have cached data, use it
      if (isSetup || hasWallet) {
        return {
          'isSetup': isSetup,
          'hasWallet': hasWallet,
          'pinRequired': pinRequired,
          'needsPinEntry': isSetup && pinRequired,
          'needsOnboarding': !isSetup && !hasWallet,
          'canAccessWallet': isSetup && !pinRequired,
        };
      }

      // If no cached data, fetch from API
      await checkAndCacheDocWalletStatus(token);
      
      return {
        'isSetup': _hasDocWalletSetup ?? false,
        'hasWallet': _hasWallet,
        'pinRequired': _isPinRequired,
        'needsPinEntry': (_hasDocWalletSetup ?? false) && _isPinRequired,
        'needsOnboarding': !(_hasDocWalletSetup ?? false) && !_hasWallet,
        'canAccessWallet': (_hasDocWalletSetup ?? false) && !_isPinRequired,
      };
    } catch (e) {
      print('UserProvider - Error getting wallet navigation info: $e');
      // Default to onboarding on error
      return {
        'isSetup': false,
        'hasWallet': false,
        'pinRequired': false,
        'needsPinEntry': false,
        'needsOnboarding': true,
        'canAccessWallet': false,
      };
    }
  }

  // Method to clear user data (for logout)
  void clearUser() {
    // Clear FCM data before clearing user data
    if (!kIsWeb) {
      FCMService.clearCurrentUser();
    }

    _userId = null;
    _username = null;
    _email = null;
    _token = null;
    _hasAdminAccess = false;
    _country = null;
    _currency = null;
    _currencySymbol = null;
    notifyListeners();
  }

  // Method to force refresh username from cache
  Future<void> refreshUsernameFromCache() async {
    if (_userId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedName = prefs.getString('user_name_$_userId');
        if (cachedName != null && cachedName != _username) {
          _username = cachedName;
          print('UserProvider - Refreshed username from cache: $cachedName');
          notifyListeners();
        }
      } catch (e) {
        print('UserProvider - Error refreshing username from cache: $e');
      }
    }
  }

  // <CHANGE> Fixed empty updateUserName method to properly update and cache username
  void updateUserName(String userName) async {
    if (userName.isNotEmpty && userName != _username) {
      final oldUsername = _username;
      _username = userName;
      print('UserProvider - updateUserName: Updated from $oldUsername to: $userName');

      // Cache username in SharedPreferences with multiple keys for compatibility
      if (_userId != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name_$_userId', userName);
          await prefs.setString('cached_username', userName);
          print('UserProvider - updateUserName: Cached username in SharedPreferences');
        } catch (e) {
          print('UserProvider - updateUserName: Error caching username: $e');
        }
      }

      // Update in persistent storage via AuthManager
      if (_userId != null && _token != null) {
        await _authManager.saveAuthData(
          token: _token!,
          userId: _userId!,
          email: _email,
          name: userName,
          hasAdminAccess: _hasAdminAccess,
          country: _country,
        );
        print('UserProvider - updateUserName: Updated username in AuthManager');
      }

      notifyListeners();
      print('UserProvider - updateUserName: Notified listeners');
    }
  }

  // Initialize feature flags
  Future<void> _initializeFeatureFlags(BuildContext context) async {
    if (_userId == null || _token == null) return;
    
    try {
      final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
      
      // Initialize from cache first
      await featureFlagsProvider.initFromCache();
      
      // Then safely fetch fresh data from API
      final fetchAttempted = await featureFlagsProvider.safeFetchFeatureFlags(
        token: _token!,
        userId: _userId!,
      );
      
      if (fetchAttempted) {
        print('UserProvider - Feature flags initialized successfully');
      } else {
        print('UserProvider - Feature flags fetch skipped due to invalid credentials');
      }
    } catch (e) {
      print('UserProvider - Error initializing feature flags: $e');
    }
  }
}
