import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/receipt_models.dart';
import 'version_service.dart';

class ShareIntentApiService {
  static final Dio _dio = Dio();
  static String get baseUrl {
    final envBase = dotenv.env['API_BASE_URL'];
    final resolvedBase = (envBase != null && envBase.isNotEmpty)
        ? envBase
        : 'https://manage-receipt-backend-1.onrender.com';
    if (envBase == null || envBase.isEmpty) {
      print('⚠️ API_BASE_URL missing in .env. Falling back to $resolvedBase');
    }
    return '$resolvedBase/api';
  }
  
  static void configure() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    
    // Add interceptors for logging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (object) => print('ShareIntentApiService: $object'),
    ));
  }
  
  static void _ensureConfigured() {
    if ((_dio.options.baseUrl).isEmpty) {
      print('⚠️ Dio baseUrl was empty. Reconfiguring...');
      configure();
    }
  }
  
  /// Process receipt with OCR (existing endpoint)
  static Future<ProcessReceiptResponse> processReceipt({
    required String userId,
    String? imageUrl,
    String? pdfUrl,
    String? country,
    String? token,
  }) async {
    try {
      _ensureConfigured();
      Map<String, dynamic> data = {
        'userId': userId,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (pdfUrl != null) 'pdfUrl': pdfUrl,
        if (country != null) 'country': country,
      };
      
      // Get proper headers with version and platform info
      final headers = VersionService.getHeaders(token: token);
      
      print('🔍 OCR Request: ${data.toString()}');
      print('🌐 POST ${_dio.options.baseUrl}/receipts/process-receipt');
      
      Response response = await _dio.post(
        '/receipts/process-receipt',
        data: data,
        options: Options(
          headers: headers,
          followRedirects: true,
          validateStatus: (code) => code != null && code < 500,
        ),
      );
      
      print('📥 OCR Response: ${response.data}');
      
      // Debug line items information
      if (response.data != null && response.data['receiptDetails'] != null) {
        final receiptDetails = response.data['receiptDetails'];
        print('🔍 Line items status: ${receiptDetails['lineItemsStatus']}');
        print('🔍 Has line items: ${receiptDetails['lineItems']?.length ?? 0}');
        print('🔍 Has line items promise: ${receiptDetails['_lineItemsPromise'] != null}');
        if (receiptDetails['_lineItemsPromise'] != null) {
          print('🔍 Line items promise type: ${receiptDetails['_lineItemsPromise'].runtimeType}');
        }
      }
      
      print('📊 OCR Response Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ OCR returned success status code');
        final processResponse = ProcessReceiptResponse.fromJson(response.data);
        print('✅ Parsed ProcessReceiptResponse - success: ${processResponse.success}');
        return processResponse;
      } else {
        // ignore: avoid_print
        print('❌ ShareIntentApiService: OCR endpoint error ${response.statusCode} -> ${response.data}');
        throw Exception('OCR failed: ${response.data is Map ? (response.data['error'] ?? 'Unknown error') : response.statusMessage}');
      }
    } catch (e, stackTrace) {
      print('❌❌❌ OCR processing error: $e');
      print('Stack trace: $stackTrace');
      throw Exception('OCR processing failed: $e');
    }
  }
  
  /// Save receipt with line items promise support
  static Future<SaveReceiptResponse> saveReceipt({
    required ReceiptDetails receiptDetails,
    String? tags,
    String? comments,
    String? token,
  }) async {
    try {
      _ensureConfigured();
      // Create the save payload from receipt details
      final savePayload = receiptDetails.toJson();
      
      // Override with custom tags/comments if provided
      if (tags != null) savePayload['tags'] = tags;
      if (comments != null) savePayload['comments'] = comments;
      
      // ⚠️ CRITICAL: Ensure _lineItemsPromise is included
      if (receiptDetails.lineItemsPromise != null) {
        savePayload['_lineItemsPromise'] = receiptDetails.lineItemsPromise;
        print('✅ Including _lineItemsPromise in save request');
      } else {
        print('⚠️ No _lineItemsPromise found in receipt details');
      }
      
      print('🔍 Save payload includes lineItemsPromise: ${savePayload.containsKey('_lineItemsPromise')}');
      print('🔍 Line items status: ${receiptDetails.lineItemsStatus}');
      print('🔍 Has line items: ${receiptDetails.lineItems?.length ?? 0}');
      print('📤 Save payload: ${savePayload.toString()}');
      
      // Get proper headers with version and platform info
      final headers = VersionService.getHeaders(token: token);
      
      print('🌐 POST ${_dio.options.baseUrl}/receipts/${receiptDetails.userId}');
      Response response = await _dio.post(
        '/receipts/${receiptDetails.userId}',
        data: savePayload,
        options: Options(
          headers: headers,
          followRedirects: true,
          validateStatus: (code) => code != null && code < 500,
        ),
      );
      
      print('📥 Save response: ${response.data}');
      print('📥 Save response status: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Log the full response structure
        print('🔍 Full response.data type: ${response.data.runtimeType}');
        print('🔍 Full response.data: ${response.data}');
        
        final saveResponse = SaveReceiptResponse.fromJson(response.data);
        print('🔍 Parsed save response - success: ${saveResponse.success}, receiptId: ${saveResponse.receiptId}, message: ${saveResponse.message}');
        
        // Log duplicate information if present
        if (saveResponse.hasDuplicates) {
          print('⚠️ Duplicate receipt detected: ${saveResponse.duplicateReceipts?.length ?? 0} duplicate(s) found');
        }
        
        return saveResponse;
      } else {
        print('ShareIntentApiService: Save endpoint error ${response.statusCode} -> ${response.data}');
        throw Exception('Save receipt failed: ${response.data is Map ? (response.data['error'] ?? 'Unknown error') : response.statusMessage}');
      }
    } catch (e) {
      print('❌ Save receipt error: $e');
      throw Exception('Save receipt failed: $e');
    }
  }
  
  /// Legacy save receipt method (for backward compatibility)
  static Future<SaveReceiptResponse> saveReceiptLegacy({
    required String userId,
    required String merchant,
    required String amount,
    required String receiptDate,
    required String category,
    required String imageId,
    String? imageUrl,
    String? pdfUrl,
    String? tags,
    String? comments,
    String? originalCurrency,
    bool? requireCurrencyConvert,
    List<dynamic>? lineItems,
    String? token,
  }) async {
    try {
      _ensureConfigured();
      Map<String, dynamic> data = {
        'userId': userId,
        'merchant': merchant,
        'amount': amount,
        'receiptDate': receiptDate,
        'category': category,
        'imageId': imageId,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (pdfUrl != null) 'pdfUrl': pdfUrl,
        if (tags != null) 'tags': tags,
        if (comments != null) 'comments': comments,
        if (originalCurrency != null) 'originalCurrency': originalCurrency,
        if (requireCurrencyConvert != null) 'requireCurrencyConvert': requireCurrencyConvert,
        if (lineItems != null) 'lineItems': lineItems,
      };
      
      // Get proper headers with version and platform info
      final headers = VersionService.getHeaders(token: token);
      
      print('🌐 POST ${_dio.options.baseUrl}/receipts/save-receipt');
      Response response = await _dio.post(
        '/receipts/save-receipt',
        data: data,
        options: Options(headers: headers),
      );
      
      return SaveReceiptResponse.fromJson(response.data);
    } catch (e) {
      throw Exception('Save receipt failed: $e');
    }
  }
  
  /// Get user profile information
  static Future<Map<String, dynamic>> getUserProfile({
    required String userId,
    String? token,
  }) async {
    try {
      // Get proper headers with version and platform info
      final headers = VersionService.getHeaders(token: token);
      
      Response response = await _dio.get(
        '/users/profile',
        queryParameters: {'userId': userId},
        options: Options(headers: headers),
      );
      
      return response.data;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }
  
  /// Get user settings
  static Future<Map<String, dynamic>> getUserSettings({
    required String userId,
    String? token,
  }) async {
    try {
      // Get proper headers with version and platform info
      final headers = VersionService.getHeaders(token: token);
      
      Response response = await _dio.get(
        '/users/settings',
        queryParameters: {'userId': userId},
        options: Options(headers: headers),
      );
      
      return response.data;
    } catch (e) {
      throw Exception('Failed to get user settings: $e');
    }
  }
  
  /// Test API connection
  static Future<bool> testConnection() async {
    try {
      Response response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
