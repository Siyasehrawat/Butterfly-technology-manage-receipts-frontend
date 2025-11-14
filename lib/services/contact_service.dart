import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service_bypass.dart';

class ContactService {
  static Future<List<Map<String, dynamic>>> fetchContacts(String userId, String token) async {
    try {
      debugPrint('Fetching contacts for userId: $userId');
      
      final response = await ApiService.get(
        '/split-bill/contacts/$userId',
        token: token,
      );

      debugPrint('Contact response status: ${response.statusCode}');
      debugPrint('Contact response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['contacts'] != null) {
          return List<Map<String, dynamic>>.from(data['data']['contacts']);
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('Error fetching contacts: $e');
      return [];
    }
  }
}
