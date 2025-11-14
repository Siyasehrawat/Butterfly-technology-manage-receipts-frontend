import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service_bypass.dart';

class BillReminderService {
  static const String _base = '/bill-reminders';
  static const String _reminderBase = '/reminder';

  static Future<List<Map<String, dynamic>>> fetchReminders({
    required String userId,
    required String token,
    bool includeDisabled = true,
  }) async {
    try {
      final response = await ApiService.get(
        '$_base',
        token: token,
        queryParameters: {
          'userId': userId,
          'includeDisabled': includeDisabled.toString(),
        },
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final List<dynamic> items = (body is Map && body['data'] is List)
            ? (body['data'] as List)
            : (body is List ? body : []);
        return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('BillReminderService.fetchReminders error: $e');
    }
    return [];
  }

  static Future<bool> toggleReminder({
    required String reminderId,
    required bool enabled,
    String? token,
  }) async {
    try {
      final http.Response res = await ApiService.patch(
        '$_base/$reminderId',
        body: {'enabled': enabled},
        token: token,
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('BillReminderService.toggleReminder error: $e');
      return false;
    }
  }

  static Future<bool> deleteReminder({
    required String reminderId,
    String? token,
  }) async {
    try {
      final http.Response res = await ApiService.delete('$_base/$reminderId', token: token);
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('BillReminderService.deleteReminder error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> createReminder({
    required Map<String, dynamic> payload,
    String? token,
  }) async {
    try {
      final http.Response res = await ApiService.post(
        '$_base',
        body: payload,
        token: token,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = json.decode(res.body);
        if (body is Map && body['data'] != null) return Map<String, dynamic>.from(body['data']);
        if (body is Map) return Map<String, dynamic>.from(body);
      }
    } catch (e) {
      debugPrint('BillReminderService.createReminder error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> updateReminder({
    required String reminderId,
    required Map<String, dynamic> payload,
    String? token,
  }) async {
    try {
      final http.Response res = await ApiService.put(
        '$_base/$reminderId',
        body: payload,
        token: token,
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['data'] != null) return Map<String, dynamic>.from(body['data']);
        if (body is Map) return Map<String, dynamic>.from(body);
      }
    } catch (e) {
      debugPrint('BillReminderService.updateReminder error: $e');
    }
    return null;
  }

  // New API: POST /reminder/manual (create or update manual reminder without receipt)
  static Future<Map<String, dynamic>?> createOrUpdateManualReminder({
    required Map<String, dynamic> payload,
    String? token,
  }) async {
    try {
      final http.Response res = await ApiService.post(
        '$_reminderBase/manual',
        body: payload,
        token: token,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = json.decode(res.body);
        if (body is Map && body['data'] != null) return Map<String, dynamic>.from(body['data']);
        if (body is Map) return Map<String, dynamic>.from(body);
      }
    } catch (e) {
      debugPrint('BillReminderService.createOrUpdateManualReminder error: $e');
    }
    return null;
  }

  // New API: GET /reminder?userId=...&reminderId=... or &receiptId=...
  static Future<Map<String, dynamic>?> getReminder({
    required String userId,
    String? reminderId,
    String? receiptId,
    String? token,
  }) async {
    try {
      final params = <String, String>{'userId': userId};
      if (reminderId != null && reminderId.isNotEmpty) params['reminderId'] = reminderId;
      if (receiptId != null && receiptId.isNotEmpty) params['receiptId'] = receiptId;
      final http.Response res = await ApiService.get(
        _reminderBase,
        token: token,
        queryParameters: params,
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map) return Map<String, dynamic>.from(body);
      }
    } catch (e) {
      debugPrint('BillReminderService.getReminder error: $e');
    }
    return null;
  }

  // New API: DELETE /reminder with JSON body { userId, reminderId | receiptId }
  static Future<bool> deleteReminderV2({
    required String userId,
    String? reminderId,
    String? receiptId,
    String? token,
  }) async {
    try {
      final Map<String, dynamic> body = {'userId': userId};
      if (reminderId != null && reminderId.isNotEmpty) body['reminderId'] = reminderId;
      if (receiptId != null && receiptId.isNotEmpty) body['receiptId'] = receiptId;
      final http.Response res = await ApiService.delete(
        _reminderBase,
        token: token,
        body: body,
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('BillReminderService.deleteReminderV2 error: $e');
      return false;
    }
  }
}


