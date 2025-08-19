import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service_bypass.dart';

class SubscriptionProvider with ChangeNotifier {
  // BYPASS: Always premium subscription status
  String _subscriptionStatus = 'active';
  String _planName = 'Premium Tier';
  bool _isUnlimited = true;

  // BYPASS: Unlimited receipt access
  int _receiptLimit = 999999;
  int _currentReceiptCount = 0;
  bool _isLimitReached = false;

  // Loading states
  bool _isLoading = false;
  bool _isInitialized = false;

  // Cache management
  DateTime? _lastFetched;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  // Getters - BYPASS: Always return premium values
  String get subscriptionStatus => 'active';
  String get planName => 'Premium Tier';
  bool get isUnlimited => true;
  int get receiptLimit => 999999;
  int get currentReceiptCount => _currentReceiptCount;
  bool get isLimitReached => false; // BYPASS: Never reached
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  // BYPASS: Always allow adding receipts
  bool canAddReceipt() {
    debugPrint('BYPASS MODE: canAddReceipt always returns true');
    return true; // BYPASS: Always allow
  }

  // Initialize from cache - BYPASS: Set premium values
  Future<void> initFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // BYPASS: Always load premium values regardless of cache
      _subscriptionStatus = 'active';
      _planName = 'Premium Tier';
      _isUnlimited = true;
      _receiptLimit = 999999;
      _currentReceiptCount = prefs.getInt('current_receipt_count') ?? 0;
      _isLimitReached = false;

      _isInitialized = true;
      notifyListeners();

      debugPrint('BYPASS MODE: Loaded premium subscription from cache');
    } catch (e) {
      debugPrint('Error loading from cache (BYPASS MODE): $e');
      _setBypassValues();
    }
  }

  // BYPASS: Set premium default values
  void _setBypassValues() {
    _subscriptionStatus = 'active';
    _planName = 'Premium Tier';
    _isUnlimited = true;
    _receiptLimit = 999999;
    _currentReceiptCount = 0;
    _isLimitReached = false;
    _isInitialized = true;
    notifyListeners();
    debugPrint('BYPASS MODE: Set premium default values');
  }

  // Check if cache is valid
  bool _isCacheValid() {
    if (_lastFetched == null) return false;
    return DateTime.now().difference(_lastFetched!) < _cacheValidDuration;
  }

  // BYPASS: Always return premium subscription status
  Future<void> fetchSubscriptionStatus({
    required String token,
    required String userId,
    bool forceRefresh = false,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('BYPASS MODE: Simulating premium subscription fetch for user: $userId');

      // BYPASS: Always set premium values
      _subscriptionStatus = 'active';
      _planName = 'Premium Tier';
      _isUnlimited = true;

      await _cacheSubscriptionData();
      debugPrint('BYPASS MODE: Set premium subscription status');
    } catch (e) {
      debugPrint('Error fetching subscription status (BYPASS MODE): $e');
      _setBypassValues();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // BYPASS: Always return unlimited receipt access
  Future<void> fetchReceiptLimit({
    required String token,
    required String userId,
    bool forceRefresh = false,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('BYPASS MODE: Simulating unlimited receipt access for user: $userId');

      // BYPASS: Always set unlimited values
      // Keep current count but remove all limits
      _receiptLimit = 999999;
      _planName = 'Premium Tier';
      _isLimitReached = false;
      _isUnlimited = true;

      await _cacheReceiptLimitData();
      debugPrint('BYPASS MODE: Set unlimited receipt access');
    } catch (e) {
      debugPrint('Error fetching receipt limit (BYPASS MODE): $e');
      _setBypassValues();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh receipt limit - BYPASS: Always unlimited
  Future<void> refreshReceiptLimit({
    required String token,
    required String userId,
  }) async {
    await fetchReceiptLimit(
      token: token,
      userId: userId,
      forceRefresh: true,
    );
  }

  // Refresh all subscription data - BYPASS: Always premium
  Future<void> refreshSubscriptionData({
    required String token,
    required String userId,
    required String userI,
  }) async {
    await Future.wait([
      fetchSubscriptionStatus(token: token, userId: userId, forceRefresh: true),
      fetchReceiptLimit(token: token, userId: userId, forceRefresh: true),
    ]);
  }

  // Increment receipt count locally (keep for UI consistency)
  void incrementReceiptCount() {
    _currentReceiptCount++;
    // BYPASS: Never set limit reached
    _isLimitReached = false;
    notifyListeners();
    _cacheReceiptLimitData();
    debugPrint('BYPASS MODE: Incremented receipt count to: $_currentReceiptCount (no limits)');
  }

  // Decrement receipt count locally
  void decrementReceiptCount() {
    if (_currentReceiptCount > 0) {
      _currentReceiptCount--;
      _isLimitReached = false; // BYPASS: Never limit reached
      notifyListeners();
      _cacheReceiptLimitData();
      debugPrint('BYPASS MODE: Decremented receipt count to: $_currentReceiptCount (no limits)');
    }
  }

  // Cache subscription data - BYPASS: Always cache premium values
  Future<void> _cacheSubscriptionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subscription_status', 'active');
      await prefs.setString('plan_name', 'Premium Tier');
      await prefs.setBool('is_unlimited', true);
      await prefs.setString('last_fetched', DateTime.now().toIso8601String());
      _lastFetched = DateTime.now();
      debugPrint('BYPASS MODE: Cached premium subscription data');
    } catch (e) {
      debugPrint('Error caching subscription data (BYPASS MODE): $e');
    }
  }

  // Cache receipt limit data - BYPASS: Always cache unlimited values
  Future<void> _cacheReceiptLimitData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('receipt_limit', 999999);
      await prefs.setInt('current_receipt_count', _currentReceiptCount);
      await prefs.setBool('is_limit_reached', false);
      await prefs.setString('last_fetched', DateTime.now().toIso8601String());
      _lastFetched = DateTime.now();
      debugPrint('BYPASS MODE: Cached unlimited receipt data');
    } catch (e) {
      debugPrint('Error caching receipt limit data (BYPASS MODE): $e');
    }
  }

  // Clear all cached data - BYPASS: Reset to premium values
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('subscription_status');
      await prefs.remove('plan_name');
      await prefs.remove('is_unlimited');
      await prefs.remove('receipt_limit');
      await prefs.remove('current_receipt_count');
      await prefs.remove('is_limit_reached');
      await prefs.remove('last_fetched');

      _setBypassValues(); // BYPASS: Set premium values instead of defaults
      _lastFetched = null;

      debugPrint('BYPASS MODE: Cache cleared, reset to premium values');
    } catch (e) {
      debugPrint('Error clearing cache (BYPASS MODE): $e');
    }
  }
}
