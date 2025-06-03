import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

class ReceiptService {
  String userId;
  String get baseApiUrl => 'https://manage-receipt-backend-bnl1.onrender.com/api/receipts';
  final Logger logger = Logger();

  ReceiptService({required this.userId});

  void setUserId(String userId) {
    this.userId = userId;
  }

  // Fetch receipts with optional filters
  Future<List<Map<String, dynamic>>> getReceipts({
    required String userId,
    String? merchant,
    String? category,
    int? categoryId,
    String? fromDate,
    String? toDate,
    String? minAmount,
    String? maxAmount,
  }) async {
    try {
      // Construct query parameters
      final queryParams = {
        if (merchant != null && merchant.isNotEmpty) 'merchant': merchant,
        if (category != null && category.isNotEmpty) 'category': category,
        if (categoryId != null) 'categoryId': categoryId.toString(),
        if (fromDate != null && fromDate.isNotEmpty) 'fromDate': fromDate,
        if (toDate != null && toDate.isNotEmpty) 'toDate': toDate,
        if (minAmount != null && minAmount.isNotEmpty) 'minAmount': minAmount,
        if (maxAmount != null && maxAmount.isNotEmpty) 'maxAmount': maxAmount,
      };

      // Build the URL with query parameters
      final uri = Uri.parse('$baseApiUrl/$userId')
          .replace(queryParameters: queryParams);

      logger.d('Fetching receipts from $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Ensure the response is a list of maps
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (data is Map && data.containsKey('receipts')) {
          return (data['receipts'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else {
          logger.e('Unexpected response format: $data');
          return [];
        }
      } else {
        logger.e(
            'Failed to load receipts: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      logger.e('Error fetching receipts: $e');
      return [];
    }
  }

  // Save receipt details
  Future<bool> saveReceiptDetails(Map<String, dynamic> receiptData) async {
    try {
      logger.d('Saving receipt details: $receiptData');

      final response = await http.post(
        Uri.parse('$baseApiUrl/${receiptData['userId']}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(receiptData),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      logger.e('Error saving receipt details: $e');
      return false;
    }
  }

  // Update receipt field
  Future<bool> updateReceiptField(
      String receiptId, String field, dynamic value) async {
    try {
      logger.d('Updating receipt $receiptId field $field to $value');

      final response = await http.patch(
        Uri.parse('$baseApiUrl/$receiptId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({field: value}),
      );

      return response.statusCode == 200;
    } catch (e) {
      logger.e('Error updating receipt field: $e');
      return false;
    }
  }

  // Delete receipt
  Future<bool> deleteReceipt(String imageId) async {
    final url = Uri.parse('$baseApiUrl/$imageId');
    try {
      final response = await http.delete(url);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting receipt: $e');
      return false;
    }
  }

  // Get categories
  Future<List<String>> getCategories() async {
    try {
      logger.d('Fetching categories');

      final response = await http.get(Uri.parse('https://manage-receipt-backend-bnl1.onrender.com/api/categories/get-all-categories'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((category) => category['name'].toString()).toList();
      } else {
        return [
          'Meal',
          'Education',
          'Medical',
          'Shopping',
          'Travel',
          'Rent',
          'Other'
        ];
      }
    } catch (e) {
      logger.e('Error fetching categories: $e');
      return [
        'Meal',
        'Education',
        'Medical',
        'Shopping',
        'Travel',
        'Rent',
        'Other'
      ];
    }
  }

  // Get merchants
  Future<List<String>> getMerchants() async {
    try {
      logger.d('Fetching merchants');

      final response = await http.get(Uri.parse('$baseApiUrl/merchants'));
      if (response.statusCode == 200) {
        return List<String>.from(json.decode(response.body));
      } else {
        return [];
      }
    } catch (e) {
      logger.e('Error fetching merchants: $e');
      return [];
    }
  }

  // Upload image to Cloudinary
  Future<String?> uploadImageToCloudinary(dynamic image) async {
    const cloudinaryUrl =
        'https://api.cloudinary.com/v1_1/dexex1gzu/image/upload';
    const uploadPreset = 'receipt_uploads';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
        ..fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        request.files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: image.name));
      } else {
        request.files
            .add(await http.MultipartFile.fromPath('file', image.path));
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);

      if (response.statusCode == 200) {
        return jsonResponse["secure_url"];
      } else {
        throw Exception(
            "Cloudinary error: ${jsonResponse['error']?['message'] ?? 'Unknown error'}");
      }
    } catch (e) {
      logger.e("Upload Error: $e");
      return null;
    }
  }

  // Process receipt image
  Future<Map<String, dynamic>?> processReceiptImage(
      String imageUrl, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseApiUrl/process-receipt'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'imageUrl': imageUrl,
          'userId': userId,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body)["receipt"];
      } else {
        throw Exception('Backend error: ${response.body}');
      }
    } catch (e) {
      logger.e("Backend Error: $e");
      return null;
    }
  }
}