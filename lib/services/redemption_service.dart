import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service_bypass.dart';

class RedemptionService {
  /// Get catalog of available gift cards and donation partners
  /// GET /api/redemptions/users/:userId/catalog
  static Future<Map<String, dynamic>?> getCatalog(String userId, String? token) async {
    try {
      final response = await ApiService.get(
        '/redemptions/users/$userId/catalog',
        token: token,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsedJson = json.decode(response.body) is Map
            ? Map<String, dynamic>.from(json.decode(response.body) as Map)
            : <String, dynamic>{};
        
        if (parsedJson['success'] == true && parsedJson['data'] != null) {
          return Map<String, dynamic>.from(parsedJson['data'] as Map);
        }
      } else if (response.statusCode == 404) {
        debugPrint('RedemptionService: User not found');
        return null;
      }
      
      debugPrint('RedemptionService: Failed to load catalog - ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('RedemptionService: Error fetching catalog: $e');
      return null;
    }
  }

  /// Initiate redemption process
  /// POST /api/redemptions/redeem/init
  static Future<Map<String, dynamic>?> initiateRedemption({
    required String userId,
    required String type, // 'GIFT_CARD' or 'DONATION'
    required String brandOrOrg,
    required double amount,
    required String email,
    String? token,
    String? phone,
    String? fullName,
    String? address,
  }) async {
    try {
      final body = {
        'userId': userId,
        'type': type,
        'brandOrOrg': brandOrOrg,
        'amount': amount,
        'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
        if (address != null && address.isNotEmpty) 'address': address,
      };

      final response = await ApiService.post(
        '/redemptions/redeem/init',
        body: body,
        token: token,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsedJson = json.decode(response.body) is Map
            ? Map<String, dynamic>.from(json.decode(response.body) as Map)
            : <String, dynamic>{};
        
        if (parsedJson['success'] == true && parsedJson['data'] != null) {
          return Map<String, dynamic>.from(parsedJson['data'] as Map);
        }
      }
      
      // Handle error responses
      final Map<String, dynamic>? errorJson = json.decode(response.body) is Map
          ? Map<String, dynamic>.from(json.decode(response.body) as Map)
          : null;
      
      final errorMessage = errorJson?['message'] ?? 'Failed to initiate redemption';
      final errors = errorJson?['errors'] as List<dynamic>?;
      
      debugPrint('RedemptionService: Failed to initiate redemption - $errorMessage');
      if (errors != null) {
        debugPrint('RedemptionService: Validation errors: $errors');
      }
      
      return {
        'error': true,
        'message': errorMessage,
        'errors': errors,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      debugPrint('RedemptionService: Error initiating redemption: $e');
      return {
        'error': true,
        'message': 'An unexpected error occurred',
        'statusCode': 500,
      };
    }
  }

  /// Verify OTP and complete redemption
  /// POST /api/redemptions/redeem/verify-otp
  static Future<Map<String, dynamic>?> verifyOtp({
    required String userId,
    required String redemptionId,
    required String otp,
    String? token,
    String? email,
  }) async {
    try {
      final body = {
        'userId': userId,
        'redemptionId': redemptionId,
        'otp': otp,
        if (email != null && email.isNotEmpty) 'email': email,
      };

      final response = await ApiService.post(
        '/redemptions/redeem/verify-otp',
        body: body,
        token: token,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsedJson = json.decode(response.body) is Map
            ? Map<String, dynamic>.from(json.decode(response.body) as Map)
            : <String, dynamic>{};
        
        if (parsedJson['success'] == true) {
          return {
            'success': true,
            'message': parsedJson['message'] ?? 'OTP verified successfully',
          };
        }
      }
      
      // Handle error responses
      final Map<String, dynamic>? errorJson = json.decode(response.body) is Map
          ? Map<String, dynamic>.from(json.decode(response.body) as Map)
          : null;
      
      final errorMessage = errorJson?['message'] ?? 'Failed to verify OTP';
      
      debugPrint('RedemptionService: Failed to verify OTP - $errorMessage');
      
      return {
        'error': true,
        'message': errorMessage,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      debugPrint('RedemptionService: Error verifying OTP: $e');
      return {
        'error': true,
        'message': 'An unexpected error occurred',
        'statusCode': 500,
      };
    }
  }

  /// Calculate amount from points based on currency
  /// USD: 1000 points = $1
  /// INR: 1000 points = ₹50
  static double calculateAmount(int points, String currency) {
    if (currency == 'INR') {
      return (points / 1000) * 50;
    } else {
      // USD (default)
      return points / 1000;
    }
  }

  /// Get point options based on currency
  /// Allowed increments: 100, 5000, 10000, 25000, 50000
  static List<int> getPointOptions() {
    return [100, 5000, 10000, 25000, 50000];
  }

  /// Get amount options based on currency
  static List<double> getAmountOptions(String currency) {
    final points = getPointOptions();
    return points.map((p) => calculateAmount(p, currency)).toList();
  }
}









