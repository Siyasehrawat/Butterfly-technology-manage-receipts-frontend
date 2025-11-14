import 'dart:convert';
import '../services/api_service_bypass.dart';

class ReferralService {
  /// Get referral dashboard for a user
  /// Returns their referral code, stats, and invite history
  static Future<Map<String, dynamic>?> getReferralDashboard(
    String userId,
    String token,
  ) async {
    try {
      final response = await ApiService.get(
        '/referrals/users/$userId',
        token: token,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        print('Failed to fetch referral dashboard: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching referral dashboard: $e');
      return null;
    }
  }

  /// Apply a referral code
  /// Validates the code, links the users, and grants referral rewards
  static Future<Map<String, dynamic>> applyReferralCode(
    String userId,
    String referralCode,
    String token,
  ) async {
    try {
      final response = await ApiService.post(
        '/referrals/apply',
        body: {
          'userId': userId,
          'referralCode': referralCode,
        },
        token: token,
      );

      final responseData = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Referral code applied successfully!',
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? responseData['error'] ?? 'Failed to apply referral code',
        };
      }
    } catch (e) {
      print('Error applying referral code: $e');
      return {
        'success': false,
        'message': 'An error occurred while applying the code',
      };
    }
  }
}

