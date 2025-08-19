import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'api_service_bypass.dart'; // Import the ApiService
import 'currency_helper_service.dart'; // Import the CurrencyHelperService
import '../utils/encryption_helper.dart'; // Import the EncryptionHelper

class ReceiptService {
  String userId;
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
    List<String>? tags, // NEW: Add tags parameter
    bool? isSplit, // NEW: Add isSplit parameter
    String? splitStatus, // NEW: Add splitStatus parameter
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
        if (tags != null && tags.isNotEmpty) 'tags': tags.join(','), // NEW: Add tags to query
        if (isSplit != null) 'isSplit': isSplit.toString(), // NEW: Add isSplit to query
        if (splitStatus != null && splitStatus.isNotEmpty) 'splitStatus': splitStatus, // NEW: Add splitStatus to query
      };

      // Build the endpoint with query parameters relative to ApiService.baseUrl
      final uri = Uri.parse('/receipts/$userId')
          .replace(queryParameters: queryParams);
      final endpoint = uri.toString();

      debugPrint('📥 Fetching receipts from ${ApiService.baseUrl}$endpoint');

      final response = await ApiService.get(endpoint); // Use ApiService.get

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        List<Map<String, dynamic>> receipts = [];

        // Ensure the response is a list of maps
        if (data is List) {
          receipts = data.map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (data is Map && data.containsKey('receipts')) {
          receipts = (data['receipts'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else {
          debugPrint('❌ Unexpected response format: $data');
          return [];
        }

        // Decrypt imageLink for each receipt
        debugPrint('🔐 Starting decryption for ${receipts.length} receipts...');
        for (var receipt in receipts) {
          final encryptedImageLink = receipt['imageLink'] as String?;
          if (encryptedImageLink != null) {
            final decryptedImageLink = EncryptionHelper.decryptUrl(encryptedImageLink);
            receipt['decryptedImageLink'] = decryptedImageLink;
            debugPrint('🔓 Decrypted URL for receipt ${receipt['id']}: $decryptedImageLink');
          } else {
            debugPrint('⚠️  No imageLink for receipt ${receipt['id']}');
          }
        }
        debugPrint('✅ Decryption complete for ${receipts.length} receipts');


        return receipts;
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

      final response = await ApiService.post(
        '/receipts/${receiptData['userId']}', // Endpoint relative to ApiService.baseUrl
        body: receiptData,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      logger.e('Error saving receipt details: $e');
      return false;
    }
  }

// Get single receipt details by receiptId
  Future<Map<String, dynamic>?> getReceiptDetails({
    required String receiptId,
    required String userId,
  }) async {
    try {
      logger.d('Fetching receipt details for receiptId: $receiptId, userId: $userId');

      final response = await ApiService.get(
        '/receipts/details/$receiptId?userId=$userId', // Endpoint with userId as query param
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        Map<String, dynamic> receipt;
        
        // Handle different response structures
        if (data is Map) {
          if (data.containsKey('receipt')) {
            receipt = Map<String, dynamic>.from(data['receipt']);
          } else {
            receipt = Map<String, dynamic>.from(data);
          }
        } else {
          logger.e('Unexpected response format: $data');
          return null;
        }

        // Decrypt imageLink if present
        final encryptedImageLink = receipt['imageLink'] as String?;
        if (encryptedImageLink != null) {
          final decryptedImageLink = EncryptionHelper.decryptUrl(encryptedImageLink);
          if (decryptedImageLink != null) {
            receipt['decryptedImageLink'] = decryptedImageLink;
            debugPrint('🔓 Decrypted URL for receipt $receiptId: $decryptedImageLink');
          }
        }

        return receipt;
      } else {
        logger.e('Failed to load receipt details: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      logger.e('Error fetching receipt details: $e');
      return null;
    }
  }

// Update receipt field
  Future<bool> updateReceiptField(
      String receiptId, String field, dynamic value) async {
    try {
      logger.d('Updating receipt $receiptId field $field to $value');

      final response = await ApiService.patch(
        '/receipts/$receiptId', // Endpoint relative to ApiService.baseUrl
        body: {field: value},
      );

      return response.statusCode == 200;
    } catch (e) {
      logger.e('Error updating receipt field: $e');
      return false;
    }
  }

// Delete receipt
  Future<bool> deleteReceipt(String imageId) async {
    try {
      final response = await ApiService.delete('/receipts/$imageId'); // Endpoint relative to ApiService.baseUrl
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting receipt: $e');
      return false;
    }
  }

// Get hardcoded categories - no API call
  Future<List<String>> getCategories() async {
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

// Get merchants
  Future<List<String>> getMerchants() async {
    try {
      logger.d('Fetching merchants');

      final response = await ApiService.get('/receipts/merchants'); // Endpoint relative to ApiService.baseUrl
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

// NEW: Get tags
  Future<List<String>> getTags({required String userId}) async {
    try {
      logger.d('Fetching tags for userId: $userId');
      final response = await ApiService.get('/receipts/tags?userId=$userId'); // Endpoint relative to ApiService.baseUrl
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('tags') && data['tags'] is List) {
          return List<String>.from(data['tags']);
        } else {
          logger.e('Unexpected tags response format: $data');
          return [];
        }
      } else {
        logger.e('Failed to load tags: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      logger.e('Error fetching tags: $e');
      return [];
    }
  }

// Upload image to Cloudinary
  Future<String?> uploadImageToCloudinary(dynamic image) async {
    const cloudinaryUrl =
        'https://api.cloudinary.com/v1_1/ds1lqhvc3/image/upload';
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
      String imageUrl, String userId, {String? country}) async {
    try {
      // Use CurrencyHelperService to build consistent payload
      final requestBody = CurrencyHelperService.buildProcessReceiptPayload(
        imageUrl: imageUrl,
        userId: userId,
        country: country,
      );

      final response = await ApiService.post(
        '/receipts/process-receipt', // Endpoint relative to ApiService.baseUrl
        body: requestBody,
        timeout: const Duration(seconds: 60), // Increased timeout for receipt processing
      );

      if (response.statusCode == 201) {
        final receiptData = json.decode(response.body)["receipt"];
        
        // Decrypt URLs from OCR response
        final encryptedImageUrl = receiptData['imageUrl'] as String?;
        final encryptedPdfUrl = receiptData['pdfUrl'] as String?;
        
        debugPrint('🔐 Decrypting OCR response URLs...');
        if (encryptedImageUrl != null) {
          final decryptedImageUrl = EncryptionHelper.decryptUrl(encryptedImageUrl);
          receiptData['decryptedImageUrl'] = decryptedImageUrl;
          debugPrint('🔓 Decrypted image URL: $decryptedImageUrl');
        }
        
        if (encryptedPdfUrl != null) {
          final decryptedPdfUrl = EncryptionHelper.decryptUrl(encryptedPdfUrl);
          receiptData['decryptedPdfUrl'] = decryptedPdfUrl;
          debugPrint('🔓 Decrypted PDF URL: $decryptedPdfUrl');
        }
        
        return receiptData;
      } else {
        throw Exception('Backend error: ${response.body}');
      }
    } catch (e) {
      logger.e("Backend Error: $e");
      return null;
    }
  }
}
