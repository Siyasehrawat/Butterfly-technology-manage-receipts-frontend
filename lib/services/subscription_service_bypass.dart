import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service_bypass.dart';
import 'revenuecat_service.dart';
import 'webhook_service.dart';

class SubscriptionService {
  final RevenueCatService _revenueCatService = RevenueCatService();

  Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    try {
      final response = await ApiService.get('/subscriptions/plans');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to load subscription plans: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching subscription plans: $e');
      return _getMockPlans();
    }
  }

  List<Map<String, dynamic>> _getMockPlans() {
    // Only return mock data in debug mode
    if (!kDebugMode) {
      throw Exception('Unable to load subscription plans from server');
    }

    debugPrint('⚠️ Using mock subscription plans (debug mode only)');
    return [
      {
        'id': 'free_plan',
        'name': 'Free Tier',
        'description': 'Basic features for getting started',
        'receiptLimit': 25,
        'hasExportAccess': false,
        'price': {
          'USD': {'monthly': 0, 'annual': 0}
        },
        'features': [
          {'name': '25 receipts per month', 'isEnabled': true},
          {'name': 'Basic reporting', 'isEnabled': true},
          {'name': 'Email support', 'isEnabled': true},
          {'name': 'Advanced features', 'isEnabled': false},
        ]
      },
      {
        'id': 'premium_plan',
        'name': 'Premium Tier',
        'description': 'Advanced features for power users and businesses',
        'receiptLimit': 999999,
        'hasExportAccess': true,
        'price': {
          'USD': {'monthly': 9.99, 'annual': 99.99}
        },
        'features': [
          {'name': 'Unlimited receipts', 'isEnabled': true},
          {'name': 'Advanced reporting', 'isEnabled': true},
          {'name': 'Priority support', 'isEnabled': true},
          {'name': 'Export to Excel/PDF', 'isEnabled': true},
          {'name': 'Early Access', 'isEnabled': true},
        ]
      }
    ];
  }

  Future<Map<String, dynamic>?> getCurrentSubscription({
    String? token,
    required String userId,
  }) async {
    try {
      // First check RevenueCat for real-time subscription status
      if (_revenueCatService.isPluginAvailable) {
        final isPremium = await _revenueCatService.isPremiumUser();
        if (isPremium) {
          debugPrint('User has active premium subscription via RevenueCat');
          return {
            'Plan': {
              'id': 'premium_plan',
              'name': 'Premium Tier',
              'description': 'Advanced features for power users and businesses',
              'receiptLimit': 999999,
              'hasExportAccess': true,
            },
            'paymentStatus': 'active',
            'source': 'revenuecat',
          };
        }
      }

      // Fallback to backend API (which should be synced via webhooks)
      final endpoint = '/subscriptions/current?userId=$userId';
      debugPrint('Making GET request to: ${ApiService.baseUrl}$endpoint');

      final response = await ApiService.get(endpoint, token: token);
      debugPrint('getCurrentSubscription response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final subscription = data['subscription'] ?? data;
        subscription['source'] = 'backend';
        return subscription;
      } else if (response.statusCode == 404) {
        debugPrint('No subscription found for user: $userId');
        return _getFreePlanData();
      } else if (response.statusCode == 401) {
        debugPrint('Unauthorized access to subscription API for user: $userId');
        return _getFreePlanData();
      } else {
        throw Exception('Failed to load current subscription: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching current subscription for user $userId: $e');
      return _getFreePlanData();
    }
  }

  Map<String, dynamic> _getFreePlanData() {
    return {
      'Plan': {
        'id': 'free_plan',
        'name': 'Free Tier',
        'description': 'Basic features for getting started',
        'receiptLimit': 25,
        'hasExportAccess': false,
      },
      'paymentStatus': 'active',
      'source': 'default',
    };
  }

  /// Creates a subscription via RevenueCat (which will trigger webhook to backend)
  Future<PurchaseResult> createPremiumSubscription({
    required String productId,
    required String userId,
    String? token,
  }) async {
    try {
      debugPrint('Creating premium subscription for user: $userId, product: $productId');

      // Validate product ID
      if (!_isValidProductId(productId)) {
        return PurchaseResult(
          success: false,
          error: 'Invalid product ID: $productId. Expected: ${RevenueCatService.premiumMonthlyProductId} or ${RevenueCatService.premiumYearlyProductId}',
        );
      }

      // Use RevenueCat for the actual purchase
      final result = await _revenueCatService.purchasePremium(
        productId: productId,
        userId: userId,
        token: token,
      );

      if (result.success) {
        debugPrint('Premium subscription created successfully');

        // The webhook should automatically sync this with your backend
        // But we can also manually sync as a backup
        await _syncSubscriptionStatus(userId: userId, token: token);
      }

      return result;
    } catch (e) {
      debugPrint('Error creating premium subscription: $e');
      return PurchaseResult(
        success: false,
        error: 'Failed to create subscription: $e',
      );
    }
  }

  bool _isValidProductId(String productId) {
    return productId == RevenueCatService.premiumMonthlyProductId ||
        productId == RevenueCatService.premiumYearlyProductId;
  }

  /// Legacy method for backend-only subscription creation
  Future<bool> createSubscription(String planId, {
    String? token,
    required String userId,
  }) async {
    try {
      final response = await ApiService.post(
        '/subscriptions/create',
        body: {
          'planId': planId,
          'userId': userId,
          'source': 'direct', // Indicate this is a direct backend creation
        },
        token: token,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to create subscription');
      }
    } catch (e) {
      debugPrint('Error creating subscription for user $userId: $e');
      return false;
    }
  }

  Future<bool> cancelSubscription({
    String? token,
    required String userId,
  }) async {
    try {
      // Note: RevenueCat cancellation should be handled through the app store
      // This method handles backend cancellation
      final response = await ApiService.post(
        '/subscriptions/cancel?userId=$userId',
        body: {
          'reason': 'user_requested',
          'cancelledAt': DateTime.now().toIso8601String(),
        },
        token: token,
      );

      if (response.statusCode == 200) {
        debugPrint('Subscription cancelled successfully for user: $userId');
        return true;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to cancel subscription');
      }
    } catch (e) {
      debugPrint('Error cancelling subscription for user $userId: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getReceiptLimit({
    String? token,
    required String userId,
  }) async {
    try {
      // Check RevenueCat first for real-time status
      if (_revenueCatService.isPluginAvailable) {
        final isPremium = await _revenueCatService.isPremiumUser();
        if (isPremium) {
          return {
            'currentCount': 0,
            'limit': -1,
            'isUnlimited': true,
            'source': 'revenuecat',
          };
        }
      }

      // Fallback to backend API
      final endpoint = '/subscriptions/current?userId=$userId';
      debugPrint('Getting receipt limit from: $endpoint');

      final response = await ApiService.get(endpoint, token: token);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final subscription = data['subscription'] ?? data;
        final plan = subscription['Plan'];

        if (plan != null) {
          final receiptLimit = plan['receiptLimit'] ?? 25;
          final currentCount = subscription['currentReceiptCount'] ?? 0;

          return {
            'currentCount': currentCount,
            'limit': receiptLimit,
            'isUnlimited': receiptLimit >= 999999,
            'source': 'backend',
          };
        }
      }

      // Fallback for free users or API errors
      debugPrint('Falling back to free plan limits for user: $userId');
      return {
        'currentCount': 0,
        'limit': 25,
        'isUnlimited': false,
        'source': 'default',
      };
    } catch (e) {
      debugPrint('Error fetching receipt limit for user $userId: $e');
      return {
        'currentCount': 0,
        'limit': 25,
        'isUnlimited': false,
        'source': 'error',
      };
    }
  }

  /// Syncs subscription status between RevenueCat and backend
  Future<bool> _syncSubscriptionStatus({
    required String userId,
    String? token,
  }) async {
    try {
      if (!_revenueCatService.isPluginAvailable) return false;

      final customerInfo = await _revenueCatService.getCustomerInfo();
      if (customerInfo == null) return false;

      final syncData = {
        'userId': userId,
        'revenueCatUserId': customerInfo.originalAppUserId,
        'entitlements': customerInfo.entitlements.active.keys.toList(),
        'allEntitlements': customerInfo.entitlements.all.keys.toList(),
        'syncedAt': DateTime.now().toIso8601String(),
      };

      return await WebhookService.syncPurchaseWithBackend(
        userId: userId,
        purchaseData: syncData,
        token: token,
      );
    } catch (e) {
      debugPrint('Error syncing subscription status: $e');
      return false;
    }
  }

  bool isPremiumSubscription(Map<String, dynamic>? subscription) {
    if (subscription == null) return false;

    final plan = subscription['Plan'];
    if (plan == null) return false;

    final planName = plan['name']?.toString().toLowerCase() ?? '';
    return planName.contains('premium') || planName.contains('pro');
  }

  bool hasActiveSubscription(Map<String, dynamic>? subscription) {
    if (subscription == null) return false;

    final status = subscription['paymentStatus']?.toString().toLowerCase() ?? '';
    return status == 'active' || status == 'paid';
  }

  /// Restore purchases through RevenueCat
  Future<PurchaseResult> restorePurchases({
    required String userId,
    String? token,
  }) async {
    try {
      final result = await _revenueCatService.restorePurchases(token: token);

      if (result.success) {
        // Sync restored purchases with backend
        await _syncSubscriptionStatus(userId: userId, token: token);
      }

      return result;
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      return PurchaseResult(
        success: false,
        error: 'Failed to restore purchases: $e',
      );
    }
  }
}
