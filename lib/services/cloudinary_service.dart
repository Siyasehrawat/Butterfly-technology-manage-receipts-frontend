import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class CloudinaryService {
  static bool _isInitialized = false;
  static String? _cloudName;
  static String? _apiKey;
  static String? _apiSecret;
  static String? _uploadPreset; // Unsigned preset for images
  static String? _rawUploadPreset; // Unsigned preset for PDFs/raw
  
  /// Initialize Cloudinary service with credentials from environment variables
  static void initialize() {
    if (_isInitialized) return;
    
    _cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    _apiKey = dotenv.env['CLOUDINARY_API_KEY'];
    _apiSecret = dotenv.env['CLOUDINARY_API_SECRET'];
    _uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];
    _rawUploadPreset = dotenv.env['CLOUDINARY_RAW_UPLOAD_PRESET'] ?? _uploadPreset;
    
    // Safe fallbacks to avoid breaking direct upload when .env is missing
    _cloudName ??= 'ds1lqhvc3';
    _uploadPreset = (_uploadPreset == null || _uploadPreset!.isEmpty)
        ? 'receipt_uploads'
        : _uploadPreset;
    _rawUploadPreset = (_rawUploadPreset == null || _rawUploadPreset!.isEmpty)
        ? _uploadPreset
        : _rawUploadPreset;
    
    _isInitialized = true;
  }
  
  /// Upload file directly to Cloudinary using HTTP multipart request
  static Future<String> uploadFile(File file) async {
    if (!_isInitialized) {
      initialize();
    }
    
    try {
      final bool isPdf = isPdfFile(file.path);
      final String resourceType = isPdf ? 'raw' : 'image';
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');
      
      final request = http.MultipartRequest('POST', uri);
      
      // Add file to request
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
      );
      request.files.add(multipartFile);
      
      // Match dashboard flow: only send unsigned preset + file
      final preset = isPdf ? _rawUploadPreset : _uploadPreset;
      if (preset != null && preset.isNotEmpty) {
        request.fields['upload_preset'] = preset;
      }
      
      // Avoid attempting signature-based upload when using unsigned presets.
      // If no preset is provided but API credentials are present, you can add a proper signature here.
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final responseData = json.decode(responseBody);
        return responseData['secure_url'];
      } else {
        throw Exception('Cloudinary upload failed: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      throw Exception('Cloudinary upload failed: $e');
    }
  }
  
  /// Upload file with progress callback
  static Future<String> uploadFileWithProgress(
    File file,
    Function(double progress)? onProgress,
  ) async {
    if (!_isInitialized) {
      initialize();
    }
    
    try {
      final bool isPdf = isPdfFile(file.path);
      final String resourceType = isPdf ? 'raw' : 'image';
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');
      
      final request = http.MultipartRequest('POST', uri);
      
      // Add file to request
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
      );
      request.files.add(multipartFile);
      
      // Match dashboard flow: only send unsigned preset + file
      final preset = isPdf ? _rawUploadPreset : _uploadPreset;
      if (preset != null && preset.isNotEmpty) {
        request.fields['upload_preset'] = preset;
      }
      
      // Avoid attempting signature-based upload when using unsigned presets.
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final responseData = json.decode(responseBody);
        return responseData['secure_url'];
      } else {
        // Verbose diagnostics
        // ignore: avoid_print
        print('CloudinaryService: Upload failed');
        // ignore: avoid_print
        print('  cloudName=$_cloudName resourceType=$resourceType preset=${isPdf ? _rawUploadPreset : _uploadPreset}');
        // ignore: avoid_print
        print('  status=${response.statusCode} body=$responseBody');
        throw Exception('Cloudinary upload failed: ${response.statusCode}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('CloudinaryService: Exception during upload: $e');
      throw Exception('Cloudinary upload failed: $e');
    }
  }
  
  /// Generate signature for authenticated uploads
  static String _generateSignature(Map<String, String> fields) {
    // Simple signature generation - in production, use proper crypto library
    final sortedKeys = fields.keys.toList()..sort();
    final signatureString = sortedKeys.map((key) => '$key=${fields[key]}').join('&');
    return '$signatureString$_apiSecret'.hashCode.toString();
  }
  
  /// Get file size in bytes
  static Future<int> getFileSize(File file) async {
    return await file.length();
  }
  
  /// Check if file size is within limits (e.g., 10MB)
  static Future<bool> isFileSizeValid(File file, {int maxSizeInMB = 10}) async {
    final size = await getFileSize(file);
    final maxSizeInBytes = maxSizeInMB * 1024 * 1024;
    return size <= maxSizeInBytes;
  }
  
  /// Validate file type
  static bool isValidFileType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    const validExtensions = ['jpg', 'jpeg', 'png', 'pdf', 'gif', 'webp', 'bmp', 'tiff'];
    return validExtensions.contains(extension);
  }
  
  /// Get file extension
  static String getFileExtension(String filePath) {
    return filePath.toLowerCase().split('.').last;
  }
  
  /// Check if file is PDF
  static bool isPdfFile(String filePath) {
    return getFileExtension(filePath) == 'pdf';
  }
  
  /// Check if file is image
  static bool isImageFile(String filePath) {
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff'];
    return imageExtensions.contains(getFileExtension(filePath));
  }
}
