import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service_bypass.dart';

class ContactService {
  /// Fetch contacts with optional query parameters
  /// Query parameters:
  /// - search: Filter contacts by name, email, or phone (case-insensitive partial match)
  /// - page: Page number for pagination (default: 1)
  /// - limit: Number of contacts per page (default: 50)
  /// - groupId: If provided, excludes contacts that are already members of this group
  static Future<List<Map<String, dynamic>>> fetchContacts(
    String userId,
    String token, {
    String? search,
    int? page,
    int? limit,
    String? groupId,
  }) async {
    try {
      debugPrint('Fetching contacts for userId: $userId');
      debugPrint('   search: $search');
      debugPrint('   page: $page');
      debugPrint('   limit: $limit');
      debugPrint('   groupId: $groupId');
      
      final queryParams = <String, String>{};
      if (groupId != null && groupId.isNotEmpty) {
        queryParams['groupId'] = groupId;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (page != null) {
        queryParams['page'] = page.toString();
      }
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }
      
      final response = await ApiService.get(
        '/split-bill/contacts/$userId',
        token: token,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
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
