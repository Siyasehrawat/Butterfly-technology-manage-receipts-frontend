import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'cloudinary_service.dart';
import 'share_intent_api_service.dart';
import '../models/receipt_models.dart';
import '../utils/line_items_debugger.dart';

class ShareIntentService {
  static const _storage = FlutterSecureStorage();
  
  /// Process only: Upload to Cloudinary → Process with OCR (DON'T save)
  /// Returns receipt details for user to review and decide to save/discard
  static Future<ShareIntentResult> handleSharedFilePreview(
    File file, {
    Function(ShareIntentStatus status, String? message)? onProgress,
  }) async {
    try {
      // Some devices show the App Group file with a short delay. Wait/retry.
      final visible = await _ensureFileVisible(file);
      if (!visible) {
        return ShareIntentResult.error('Shared file not found or not accessible');
      }
      // Validate file
      if (!await _validateFile(file)) {
        return ShareIntentResult.error('Invalid file type or size');
      }
      
      // Check user authentication
      final userAuth = await _getUserAuthentication();
      if (!userAuth['isAuthenticated']) {
        return ShareIntentResult.error('User not authenticated');
      }
      
      onProgress?.call(ShareIntentStatus.uploading, 'Uploading file...');
      
      // Step 1: Upload to Cloudinary
      String cloudinaryUrl;
      try {
        print('ShareIntentService: Starting upload for file: ${file.path}');
        print('ShareIntentService: File exists: ${await file.exists()}');
        final len = await _safeLength(file);
        print('ShareIntentService: File size: ${len ?? -1} bytes');
        
        cloudinaryUrl = await _uploadViaDashboardPreset(file);
        print('✅ ShareIntentService: Uploaded to Cloudinary: $cloudinaryUrl');
      } catch (e) {
        print('❌ ShareIntentService: Cloudinary upload error: $e');
        return ShareIntentResult.error('Upload failed: $e');
      }
      
      onProgress?.call(ShareIntentStatus.processing, 'Processing receipt...');
      
      // Step 2: Process with OCR using existing endpoint
      print('🔄 Starting OCR processing...');
      final processResponse = await _processReceiptWithOCR(
        cloudinaryUrl, 
        file,
        userAuth['userId'],
        userAuth['token'],
      );
      
      print('🔍 OCR Response - success: ${processResponse.success}, message: ${processResponse.message}');
      print('🔍 Has receiptDetails: ${processResponse.receiptDetails != null}');
      
      // ⚠️ CRITICAL: Check if line items are being processed
      if (processResponse.receiptDetails != null) {
        final receiptDetails = processResponse.receiptDetails!;
        print('🔍 Receipt Details - merchant: ${receiptDetails.merchant}, amount: ${receiptDetails.amount}, userId: ${receiptDetails.userId}');
        LineItemsDebugger.debugReceiptDetails(receiptDetails, 'OCR Completed');
      } else {
        print('❌ OCR response has NO receiptDetails');
        print('❌ OCR response object: ${processResponse.toString()}');
      }
      
      // Step 3: Return receipt details WITHOUT saving
      if (processResponse.receiptDetails == null) {
        print('❌ FATAL: Receipt details not found in OCR response');
        throw Exception('Receipt details not found in OCR response');
      }
      
      print('✅ Receipt processed successfully - returning for preview');
      return ShareIntentResult.preview(
        receiptDetails: processResponse.receiptDetails!,
      );
    } catch (e, stackTrace) {
      print('❌❌❌ EXCEPTION in handleSharedFilePreview: $e');
      print('Stack trace: $stackTrace');
      return ShareIntentResult.error('Share intent processing failed: $e');
    }
  }
  
  /// Complete flow: Upload to Cloudinary → Process → Save
  /// (Kept for backward compatibility if needed elsewhere)
  static Future<ShareIntentResult> handleSharedFile(
    File file, {
    Function(ShareIntentStatus status, String? message)? onProgress,
  }) async {
    try {
      final visible = await _ensureFileVisible(file);
      if (!visible) {
        return ShareIntentResult.error('Shared file not found or not accessible');
      }
      // Validate file
      if (!await _validateFile(file)) {
        return ShareIntentResult.error('Invalid file type or size');
      }
      
      // Check user authentication
      final userAuth = await _getUserAuthentication();
      if (!userAuth['isAuthenticated']) {
        return ShareIntentResult.error('User not authenticated');
      }
      
      onProgress?.call(ShareIntentStatus.uploading, 'Uploading file...');
      
      // Step 1: Upload to Cloudinary
      String cloudinaryUrl;
      try {
        print('ShareIntentService: Starting upload for file: ${file.path}');
        print('ShareIntentService: File exists: ${await file.exists()}');
        final len = await _safeLength(file);
        print('ShareIntentService: File size: ${len ?? -1} bytes');
        
        cloudinaryUrl = await _uploadViaDashboardPreset(file);
        print('✅ ShareIntentService: Uploaded to Cloudinary: $cloudinaryUrl');
      } catch (e) {
        print('❌ ShareIntentService: Cloudinary upload error: $e');
        return ShareIntentResult.error('Upload failed: $e');
      }
      
      onProgress?.call(ShareIntentStatus.processing, 'Processing receipt...');
      
      // Step 2: Process with OCR using existing endpoint
      print('🔄 Starting OCR processing...');
      final processResponse = await _processReceiptWithOCR(
        cloudinaryUrl, 
        file,
        userAuth['userId'],
        userAuth['token'],
      );
      
      print('🔍 OCR Response - success: ${processResponse.success}, message: ${processResponse.message}');
      print('🔍 Has receiptDetails: ${processResponse.receiptDetails != null}');
      
      // ⚠️ CRITICAL: Check if line items are being processed
      if (processResponse.receiptDetails != null) {
        final receiptDetails = processResponse.receiptDetails!;
        print('🔍 Receipt Details - merchant: ${receiptDetails.merchant}, amount: ${receiptDetails.amount}, userId: ${receiptDetails.userId}');
        LineItemsDebugger.debugReceiptDetails(receiptDetails, 'OCR Completed');
      } else {
        print('❌ OCR response has NO receiptDetails');
        print('❌ OCR response object: ${processResponse.toString()}');
      }
      
      onProgress?.call(ShareIntentStatus.saving, 'Saving receipt...');
      
      // Step 3: Save receipt using existing endpoint
      if (processResponse.receiptDetails == null) {
        print('❌ FATAL: Receipt details not found in OCR response');
        throw Exception('Receipt details not found in OCR response');
      }
      
      final saveResponse = await _saveReceipt(
        processResponse.receiptDetails!,
        userAuth['token'],
      );
      
      print('📋 Save response - success: ${saveResponse.success}, receiptId: ${saveResponse.receiptId}, message: ${saveResponse.message}');
      
      if (saveResponse.success && saveResponse.receiptId != null) {
        print('✅ Receipt saved successfully with ID: ${saveResponse.receiptId}');
        return ShareIntentResult.success(
          message: 'Receipt processed and saved successfully',
          receiptId: saveResponse.receiptId,
        );
      } else {
        print('❌ Save failed or missing receiptId: success=${saveResponse.success}, receiptId=${saveResponse.receiptId}');
        return ShareIntentResult.error(saveResponse.message.isNotEmpty ? saveResponse.message : 'Failed to save receipt');
      }
    } catch (e, stackTrace) {
      print('❌❌❌ EXCEPTION in handleSharedFile: $e');
      print('Stack trace: $stackTrace');
      return ShareIntentResult.error('Share intent processing failed: $e');
    }
  }

  /// Fallback upload using the exact dashboard route/preset
  static Future<String> _uploadViaDashboardPreset(File file) async {
    final isPdf = CloudinaryService.isPdfFile(file.path);
    final cloudinaryUrl = isPdf
        ? 'https://api.cloudinary.com/v1_1/ds1lqhvc3/raw/upload'
        : 'https://api.cloudinary.com/v1_1/ds1lqhvc3/image/upload';
    const uploadPreset = 'receipt_uploads';

    final uri = Uri.parse(cloudinaryUrl);
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 200) {
      final jsonMap = json.decode(body) as Map<String, dynamic>;
      final url = jsonMap['secure_url'] ?? jsonMap['url'];
      if (url == null || (url is String && url.isEmpty)) {
        throw Exception('Cloudinary response missing secure_url');
      }
      return url as String;
    }
    // ignore: avoid_print
    print('ShareIntentService: Dashboard upload failed ${streamed.statusCode} -> $body');
    throw Exception('Cloudinary upload failed: ${streamed.statusCode}');
  }
  
  /// Validate file type and size
  static Future<bool> _validateFile(File file) async {
    // Check file type
    if (!CloudinaryService.isValidFileType(file.path)) {
      return false;
    }
    
    // Ensure file exists and has a readable size (tolerate short delays)
    final visible = await _ensureFileVisible(file);
    if (!visible) return false;
    
    // Check file size (safe)
    try {
      if (!await CloudinaryService.isFileSizeValid(file)) {
        return false;
      }
    } catch (_) {
      return false;
    }
    
    // Check if file exists
    if (!await file.exists()) {
      return false;
    }
    
    return true;
  }

  /// Wait for the file to appear/become readable (handles App Group timing)
  static Future<bool> _ensureFileVisible(File file) async {
    const int maxAttempts = 10; // ~1s total
    for (int i = 0; i < maxAttempts; i++) {
      try {
        if (await file.exists()) {
          final len = await _safeLength(file);
          if (len != null && len > 0) return true;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  /// Safely get file length without throwing
  static Future<int?> _safeLength(File file) async {
    try {
      return await file.length();
    } catch (_) {
      return null;
    }
  }
  
  /// Get user authentication information
  static Future<Map<String, dynamic>> _getUserAuthentication() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      // Primary token storage in app is SharedPreferences under 'token'
      String? token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        // Fallback to secure storage if not present in SharedPreferences
        token = await _storage.read(key: 'auth_token');
      }
      
      return {
        'isAuthenticated': userId != null && token != null && token.isNotEmpty,
        'userId': userId,
        'token': token,
      };
    } catch (e) {
      return {
        'isAuthenticated': false,
        'userId': null,
        'token': null,
      };
    }
  }
  
  /// Process receipt with OCR (existing endpoint)
  static Future<ProcessReceiptResponse> _processReceiptWithOCR(
    String cloudinaryUrl, 
    File file,
    String userId,
    String token,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final country = prefs.getString('country') ?? 'US';
    
    final isPdf = CloudinaryService.isPdfFile(file.path);
    
    return await ShareIntentApiService.processReceipt(
      userId: userId,
      imageUrl: isPdf ? null : cloudinaryUrl,
      pdfUrl: isPdf ? cloudinaryUrl : null,
      country: country,
      token: token,
    );
  }
  
  /// Save receipt with line items promise support
  static Future<SaveReceiptResponse> _saveReceipt(
    ReceiptDetails receiptDetails,
    String token,
  ) async {
    // ⚠️ CRITICAL: Check if line items are being processed
    LineItemsDebugger.debugReceiptDetails(receiptDetails, 'Before Save');
    
    final response = await ShareIntentApiService.saveReceipt(
      receiptDetails: receiptDetails,
      token: token,
    );
    
    LineItemsDebugger.debugSaveResponse(response);
    
    return response;
  }
  
  /// Get user country preference
  static Future<String> getUserCountry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('country') ?? 'US';
    } catch (e) {
      return 'US';
    }
  }
  
  /// Check if user is authenticated
  static Future<bool> isUserAuthenticated() async {
    final auth = await _getUserAuthentication();
    return auth['isAuthenticated'];
  }
  
  /// Get user ID
  static Future<String?> getUserId() async {
    final auth = await _getUserAuthentication();
    return auth['userId'];
  }
  
  /// Get user token
  static Future<String?> getUserToken() async {
    final auth = await _getUserAuthentication();
    return auth['token'];
  }
  
  /// Process file from file picker (manual selection)
  static Future<ShareIntentResult> handleFilePicker(
    File file, {
    Function(ShareIntentStatus status, String? message)? onProgress,
  }) async {
    return await handleSharedFile(file, onProgress: onProgress);
  }
}
