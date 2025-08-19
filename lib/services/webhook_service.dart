import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service_bypass.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class WebhookService {
  // Get base URL from environment variables with fallback
  static String get _baseUrl {
    final envBase = dotenv.env['API_BASE_URL'];
    final resolvedBase = (envBase != null && envBase.isNotEmpty)
        ? envBase
        : 'https://manage-receipt-backend-1.onrender.com';
    if (envBase == null || envBase.isEmpty) {
      debugPrint('⚠️ API_BASE_URL missing in .env. Falling back to $resolvedBase');
    }
    return '$resolvedBase/api';
  }

  /// Handles RevenueCat webhook data and forwards it to your backend
  /// This processes the webhook payload that RevenueCat sends
  static Future<bool> processRevenueCatWebhook({
    required Map<String, dynamic> webhookData,
    required String userId,
    String? token,
  }) async {
    try {
      debugPrint('Processing RevenueCat webhook for user: $userId');
      debugPrint('Webhook data: ${json.encode(webhookData)}');

      final response = await http.post(
        Uri.parse('$_baseUrl/revenuecat/webhook'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
          // Add any additional headers your backend expects
          'X-User-ID': userId,
        },
        body: json.encode({
          'event': webhookData,
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      debugPrint('Webhook response status: ${response.statusCode}');
      debugPrint('Webhook response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint('Webhook processed successfully: $responseData');
        return true;
      } else {
        debugPrint('Webhook processing failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error processing RevenueCat webhook: $e');
      return false;
    }
  }

  /// Syncs a purchase with your backend after RevenueCat processes it
  static Future<bool> syncPurchaseWithBackend({
    required String userId,
    required Map<String, dynamic> purchaseData,
    String? token,
  }) async {
    try {
      debugPrint('Syncing purchase with backend for user: $userId');

      final response = await ApiService.post(
        '/revenuecat/sync-purchase',
        body: {
          'userId': userId,
          'purchaseData': purchaseData,
          'timestamp': DateTime.now().toIso8601String(),
        },
        token: token,
      );

      if (response.statusCode == 200) {
        debugPrint('Purchase synced with backend successfully');
        return true;
      } else {
        debugPrint('Failed to sync purchase: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error syncing purchase with backend: $e');
      return false;
    }
  }

  /// Handles subscription status changes from RevenueCat
  static Future<bool> handleSubscriptionStatusChange({
    required String userId,
    required String eventType,
    required Map<String, dynamic> subscriptionData,
    String? token,
  }) async {
    try {
      debugPrint('Handling subscription status change: $eventType for user: $userId');

      final webhookPayload = {
        'api_version': '1.0',
        'event': {
          'type': eventType,
          'app_user_id': userId,
          'product_id': subscriptionData['productId'],
          'period_type': subscriptionData['periodType'] ?? 'normal',
          'purchased_at_ms': DateTime.now().millisecondsSinceEpoch,
          'expiration_at_ms': subscriptionData['expirationAtMs'],
          'environment': kDebugMode ? 'SANDBOX' : 'PRODUCTION',
          'entitlement_id': subscriptionData['entitlementId'],
          'entitlement_ids': subscriptionData['entitlementIds'] ?? [],
          'presented_offering_id': subscriptionData['offeringId'],
          'transaction_id': subscriptionData['transactionId'],
          'original_transaction_id': subscriptionData['originalTransactionId'],
          'is_family_share': subscriptionData['isFamilyShare'] ?? false,
          'country_code': subscriptionData['countryCode'] ?? 'US',
          'app_id': subscriptionData['appId'],
          'aliases': subscriptionData['aliases'] ?? [],
          'original_app_user_id': userId,
        }
      };

      return await processRevenueCatWebhook(
        webhookData: webhookPayload,
        userId: userId,
        token: token,
      );
    } catch (e) {
      debugPrint('Error handling subscription status change: $e');
      return false;
    }
  }

  /// Verifies webhook signature (implement based on your security requirements)
  static bool verifyWebhookSignature(String payload, String signature, String secret) {
    // Implement webhook signature verification here
    // This is important for security in production
    try {
      // Example implementation - replace with your actual verification logic
      // You might use HMAC-SHA256 or similar
      return true; // Placeholder - implement actual verification
    } catch (e) {
      debugPrint('Error verifying webhook signature: $e');
      return false;
    }
  }

  /// Handles different RevenueCat event types
  static Future<bool> handleRevenueCatEvent({
    required String eventType,
    required String userId,
    required Map<String, dynamic> eventData,
    String? token,
  }) async {
    try {
      debugPrint('Handling RevenueCat event: $eventType');

      switch (eventType) {
        case 'INITIAL_PURCHASE':
        case 'RENEWAL':
        case 'PRODUCT_CHANGE':
          return await handleSubscriptionStatusChange(
            userId: userId,
            eventType: eventType,
            subscriptionData: eventData,
            token: token,
          );

        case 'CANCELLATION':
        case 'EXPIRATION':
        case 'BILLING_ISSUE':
          return await handleSubscriptionStatusChange(
            userId: userId,
            eventType: eventType,
            subscriptionData: eventData,
            token: token,
          );

        case 'UNCANCELLATION':
          return await handleSubscriptionStatusChange(
            userId: userId,
            eventType: eventType,
            subscriptionData: eventData,
            token: token,
          );

        default:
          debugPrint('Unknown event type: $eventType');
          return false;
      }
    } catch (e) {
      debugPrint('Error handling RevenueCat event: $e');
      return false;
    }
  }
}
