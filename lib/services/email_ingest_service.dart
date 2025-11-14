import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service_bypass.dart';

class EmailIngestService {
  const EmailIngestService();

  /// Forwards a Postmark-like payload to backend to create a receipt
  /// Backend is expected to award points automatically
  Future<Map<String, dynamic>> ingestReceiptFromEmail({
    required Map<String, dynamic> payload,
  }) async {
    final http.Response response = await ApiService.post(
      '/email-ingest/receipt',
      body: payload,
      // Email payloads can be large; give a bit more time
      timeout: const Duration(seconds: 30),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }

    debugPrint('Failed email ingest: ${response.statusCode} ${response.body}');
    throw Exception('Failed to ingest email receipt');
  }
}




