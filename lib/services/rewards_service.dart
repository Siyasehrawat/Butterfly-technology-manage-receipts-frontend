import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service_bypass.dart';

class RewardsService {
  const RewardsService();

  Future<Map<String, dynamic>> getPointsSummary({
    required String userId,
    int limit = 10,
    int offset = 0,
  }) async {
    final endpoint = '/rewards/users/$userId/points/summary';
    final query = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    final http.Response response = await ApiService.get(
      endpoint,
      queryParameters: query,
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }

    debugPrint('Failed to fetch points summary: ${response.statusCode} ${response.body}');
    throw Exception('Failed to fetch points summary');
  }

  // Ledger and balance endpoints removed per latest API contract.
}


