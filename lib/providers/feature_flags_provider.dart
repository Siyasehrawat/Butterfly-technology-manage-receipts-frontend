import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/feature_flags.dart';
import '../services/api_service_bypass.dart';
import '../services/auth_manager.dart';

class FeatureFlagsProvider with ChangeNotifier {
  FeatureFlags _featureFlags = const FeatureFlags();
  bool _isLoading = false;
  String? _error;

  // Getters
  FeatureFlags get featureFlags => _featureFlags;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Convenience getters for wallet flags
  bool get isWalletEnabled => _featureFlags.walletEnabled;
  bool get isDocWalletPinRequired => _featureFlags.docWalletPinRequired;
  bool get isTaxReportsEnabled => _featureFlags.taxReportsEnabled;
  bool get isGoogleAuthEnabled => _featureFlags.googleAuthEnabled;
  bool get isAppleAuthEnabled => _featureFlags.appleAuthEnabled;
  bool get isCalendarSyncEnabled => _featureFlags.calendarSyncEnabled;
  bool get isAnalyticsEnabled => _featureFlags.analyticsEnabled;
  bool get isExpenseReportsEnabled => _featureFlags.expenseReportsEnabled;
  bool get isCustomReportsEnabled => _featureFlags.customReportsEnabled;
  bool get isEmailReceiptsEnabled => _featureFlags.emailReceiptsEnabled;

  // Cache keys
  static const String _cacheKey = 'feature_flags_cache';
  static const String _cacheTimestampKey = 'feature_flags_cache_timestamp';
  static const int _cacheValidityHours = 1; // Cache valid for 1 hour

  /// Initialize feature flags from cache
  Future<void> initFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey) ?? 0;
      
      if (cachedData != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        final cacheValidityMs = _cacheValidityHours * 60 * 60 * 1000;
        
        if (cacheAge < cacheValidityMs) {
          // Cache is still valid
          final Map<String, dynamic> jsonData = json.decode(cachedData);
          _featureFlags = FeatureFlags.fromJson(jsonData);
          debugPrint('FeatureFlagsProvider - Loaded from cache: $_featureFlags');
          notifyListeners();
          return;
        } else {
          debugPrint('FeatureFlagsProvider - Cache expired, will fetch fresh data');
        }
      }
    } catch (e) {
      debugPrint('FeatureFlagsProvider - Error loading from cache: $e');
    }
  }

  /// Fetch feature flags from API
  Future<void> fetchFeatureFlags({
    required String token,
    required String userId,
  }) async {
    // Resolve credentials with fallbacks
    String effectiveToken = token;
    String effectiveUserId = userId;
    if (effectiveToken.isEmpty || effectiveUserId.isEmpty) {
      try {
        final auth = AuthManager();
        final authData = await auth.getAllAuthData();
        if (authData != null) {
          effectiveToken = effectiveToken.isNotEmpty ? effectiveToken : (authData['token'] ?? '');
          effectiveUserId = effectiveUserId.isNotEmpty ? effectiveUserId : (authData['userId'] ?? '');
        }
      } catch (e) {
        debugPrint('FeatureFlagsProvider - Error resolving auth fallback: $e');
      }
    }

    if (effectiveToken.isEmpty || effectiveUserId.isEmpty) {
      debugPrint('FeatureFlagsProvider - Missing token or userId - Token: ${effectiveToken.isNotEmpty ? 'present' : 'missing'}, UserId: ${effectiveUserId.isNotEmpty ? 'present' : 'missing'}');
      _error = 'Missing authentication credentials';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('FeatureFlagsProvider - Fetching feature flags for user: $effectiveUserId with token: ${effectiveToken.isNotEmpty ? 'present' : 'missing'}');
      
      final response = await ApiService.get(
        '/users/feature-config',
        token: effectiveToken,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        debugPrint('FeatureFlagsProvider - Raw API response: $responseData');
        
        // Pass through entire response so model can handle 'config' or legacy shapes
        debugPrint('FeatureFlagsProvider - Processing flags data (passthrough)');

        _featureFlags = FeatureFlags.fromJson(responseData);
        _error = null;

        // Cache the response
        await _cacheFeatureFlags(responseData);
        
        debugPrint('FeatureFlagsProvider - Successfully fetched feature flags: $_featureFlags');
        debugPrint('FeatureFlagsProvider - walletEnabled: ${_featureFlags.walletEnabled}, docWalletPinRequired: ${_featureFlags.docWalletPinRequired}, taxReportsEnabled: ${_featureFlags.taxReportsEnabled}, splitBillEnabled: ${_featureFlags.splitBillEnabled}, remindersEnabled: ${_featureFlags.remindersEnabled}');
      } else {
        _error = 'Failed to fetch feature flags: ${response.statusCode}';
        debugPrint('FeatureFlagsProvider - API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _error = 'Error fetching feature flags: $e';
      debugPrint('FeatureFlagsProvider - Error: $e');
      // Keep existing cached flags or default flags on error
      debugPrint('FeatureFlagsProvider - Continuing with existing/default feature flags due to error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Public fetch for feature flags without authentication (for welcome/sign screens)
  Future<void> fetchPublicFeatureFlags() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('FeatureFlagsProvider - Public fetch of feature flags');
      final response = await ApiService.get(
        '/users/feature-config',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        debugPrint('FeatureFlagsProvider - Raw API response: $responseData');
        _featureFlags = FeatureFlags.fromJson(responseData);
        _error = null;
        await _cacheFeatureFlags(responseData);
        debugPrint('FeatureFlagsProvider - Public fetch success: $_featureFlags');
      } else {
        _error = 'Failed to fetch feature flags: ${response.statusCode}';
        debugPrint('FeatureFlagsProvider - Public API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _error = 'Error fetching feature flags: $e';
      debugPrint('FeatureFlagsProvider - Public fetch error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cache feature flags data
  Future<void> _cacheFeatureFlags(Map<String, dynamic> flagsData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(flagsData));
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('FeatureFlagsProvider - Cached feature flags');
    } catch (e) {
      debugPrint('FeatureFlagsProvider - Error caching feature flags: $e');
    }
  }

  /// Clear cached feature flags
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      debugPrint('FeatureFlagsProvider - Cleared feature flags cache');
    } catch (e) {
      debugPrint('FeatureFlagsProvider - Error clearing cache: $e');
    }
  }

  /// Refresh feature flags (clear cache and fetch fresh)
  Future<void> refreshFeatureFlags({
    required String token,
    required String userId,
  }) async {
    await clearCache();
    await fetchFeatureFlags(token: token, userId: userId);
  }

  /// Reset to default state
  void reset() {
    _featureFlags = const FeatureFlags();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Check if feature flags are properly initialized (no error and not loading)
  bool get isInitialized => !_isLoading && _error == null;

  /// Safe fetch with validation - returns true if fetch was attempted
  Future<bool> safeFetchFeatureFlags({
    required String token,
    required String userId,
  }) async {
    if (token.isEmpty || userId.isEmpty) {
      debugPrint('FeatureFlagsProvider - safeFetchFeatureFlags: Invalid credentials provided');
      return false;
    }

    await fetchFeatureFlags(token: token, userId: userId);
    return true;
  }
}
