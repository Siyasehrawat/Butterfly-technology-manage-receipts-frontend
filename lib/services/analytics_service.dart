import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service_bypass.dart';

class AnalyticsService {
  // Get analytics summary for a user
  static Future<Map<String, dynamic>> getAnalyticsSummary(String userId, {String? token}) async {
    try {
      debugPrint('Fetching analytics summary for user: $userId');
      
      final response = await ApiService.get(
        '/analytics/summary/$userId',
        token: token,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint('Analytics summary response: $responseData');
        
        if (responseData['success'] == true && responseData['data'] != null) {
          return {
            'success': true,
            'data': responseData['data'],
          };
        } else {
          debugPrint('API returned success: false or missing data');
          return {
            'success': false,
            'error': 'API returned success: false or missing data',
          };
        }
      } else {
        debugPrint('Failed to fetch analytics summary: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to fetch analytics summary',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('Error fetching analytics summary: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get category-wise spending for a user
  static Future<Map<String, dynamic>> getCategoryWiseSpending(
    String userId, {
    String? token,
    String period = 'monthly',
  }) async {
    try {
      debugPrint('Fetching category-wise spending for user: $userId, period: $period');
      
      final response = await ApiService.get(
        '/analytics/category-wise/$userId',
        token: token,
        queryParameters: {'period': period},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint('Category-wise spending response: $responseData');
        
        if (responseData['success'] == true && responseData['data'] != null) {
          return {
            'success': true,
            'data': responseData['data'],
          };
        } else {
          debugPrint('API returned success: false or missing data');
          return {
            'success': false,
            'error': 'API returned success: false or missing data',
          };
        }
      } else {
        debugPrint('Failed to fetch category-wise spending: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to fetch category-wise spending',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('Error fetching category-wise spending: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get monthly trend for a user
  static Future<Map<String, dynamic>> getMonthlyTrend(
    String userId, {
    String? token,
    String period = '6months',
  }) async {
    try {
      debugPrint('Fetching monthly trend for user: $userId, period: $period');
      
      final response = await ApiService.get(
        '/analytics/monthly-trend/$userId',
        token: token,
        queryParameters: {
          'period': period,
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint('Monthly trend response: $responseData');
        
        if (responseData['success'] == true && responseData['data'] != null) {
          return {
            'success': true,
            'data': responseData['data'],
          };
        } else {
          debugPrint('API returned success: false or missing data');
          return {
            'success': false,
            'error': 'API returned success: false or missing data',
          };
        }
      } else {
        debugPrint('Failed to fetch monthly trend: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to fetch monthly trend',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('Error fetching monthly trend: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
