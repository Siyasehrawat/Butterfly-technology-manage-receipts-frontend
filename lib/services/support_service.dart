import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service_bypass.dart';

class SupportService {
  final Logger _logger = Logger();

  /// Report an issue from unauthenticated screens (login/signup/welcome)
  Future<Map<String, dynamic>> reportIssueUnauthenticated({
    required String email,
    required String issueType,
    required String description,
    PlatformFile? screenshot,
  }) async {
    try {
      _logger.i('Reporting issue from: $email');

      // Validate description length
      if (description.trim().length < 10) {
        return {
          'success': false,
          'message': 'Description must be at least 10 characters long.'
        };
      }

      if (description.trim().length > 2000) {
        return {
          'success': false,
          'message': 'Description cannot exceed 2000 characters.'
        };
      }

      // Prepare fields
      final fields = {
        'email': email,
        'issueType': issueType,
        'description': description.trim(),
      };

      _logger.i('📝 Prepared fields for unauthenticated report:');
      _logger.i('  - email: $email');
      _logger.i('  - issueType: $issueType');
      _logger.i('  - description: ${description.trim()} (length: ${description.trim().length})');

      // Prepare file if provided
      http.MultipartFile? screenshotFile;
      if (screenshot != null) {
        if (screenshot.bytes != null) {
          // For web
          screenshotFile = http.MultipartFile.fromBytes(
            'screenshot',
            screenshot.bytes!,
            filename: screenshot.name,
          );
        } else if (screenshot.path != null) {
          // For mobile
          screenshotFile = await http.MultipartFile.fromPath(
            'screenshot',
            screenshot.path!,
            filename: screenshot.name,
          );
        }
      }

      _logger.i('Sending support request via ApiService');
      
      // Use ApiService.post with multipart support
      final response = await ApiService.post(
        '/support/report-issue/unauthenticated',
        fields: fields,
        file: screenshotFile,
      );

      _logger.i('Support request response status: ${response.statusCode}');
      _logger.i('Support request response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        _logger.i('Issue reported successfully');

        return {
          'success': true,
          'message': responseData['message'] ?? 'Issue reported successfully',
          'data': responseData,
        };
      } else {
        // Check if response body is HTML (error page) instead of JSON
        String errorMessage;
        if (response.body.trim().startsWith('<!DOCTYPE') || 
            response.body.trim().startsWith('<html') ||
            response.body.trim().startsWith('<pre>')) {
          // Server returned HTML error page
          errorMessage = 'Server error occurred. Please try again later.';
          _logger.w('Server returned HTML error page instead of JSON');
        } else {
          // Try to parse as JSON
          try {
            final errorData = json.decode(response.body);
            errorMessage = errorData['message'] ?? 
                          errorData['error'] ?? 
                          'Failed to submit issue report';
          } catch (e) {
            // If JSON parsing fails, use generic error message
            errorMessage = 'Failed to submit issue report. Please try again.';
            _logger.w('Failed to parse error response as JSON: $e');
          }
        }
        
        _logger.w('Failed to report issue: $errorMessage');
        
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e, stackTrace) {
      _logger.e('Error reporting issue', error: e, stackTrace: stackTrace);
      
      return {
        'success': false,
        'message': 'An error occurred while submitting your report. Please try again.',
        'error': e.toString(),
      };
    }
  }

  /// Report an issue from authenticated screens (dashboard)
  Future<Map<String, dynamic>> reportIssueAuthenticated({
    required String userId,
    required String token,
    required String issueType,
    required String description,
    PlatformFile? screenshot,
  }) async {
    try {
      _logger.i('Reporting issue from authenticated user: $userId');

      // Validate description length
      if (description.trim().length < 10) {
        return {
          'success': false,
          'message': 'Description must be at least 10 characters long.'
        };
      }

      if (description.trim().length > 2000) {
        return {
          'success': false,
          'message': 'Description cannot exceed 2000 characters.'
        };
      }

      // Prepare fields
      final fields = {
        'userId': userId,
        'issueType': issueType,
        'description': description.trim(),
      };

      // Prepare file if provided
      http.MultipartFile? screenshotFile;
      if (screenshot != null) {
        if (screenshot.bytes != null) {
          // For web
          screenshotFile = http.MultipartFile.fromBytes(
            'screenshot',
            screenshot.bytes!,
            filename: screenshot.name,
          );
        } else if (screenshot.path != null) {
          // For mobile
          screenshotFile = await http.MultipartFile.fromPath(
            'screenshot',
            screenshot.path!,
            filename: screenshot.name,
          );
        }
      }

      _logger.i('Sending authenticated support request via ApiService');
      
      // Use ApiService.post with multipart support and token
      final response = await ApiService.post(
        '/support/report-issue/authenticated',
        token: token,
        fields: fields,
        file: screenshotFile,
      );

      _logger.i('Authenticated support request response status: ${response.statusCode}');
      _logger.i('Authenticated support request response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        _logger.i('Issue reported successfully');

        return {
          'success': true,
          'message': responseData['message'] ?? 'Issue reported successfully',
          'data': responseData,
        };
      } else {
        // Check if response body is HTML (error page) instead of JSON
        String errorMessage;
        if (response.body.trim().startsWith('<!DOCTYPE') || 
            response.body.trim().startsWith('<html') ||
            response.body.trim().startsWith('<pre>')) {
          // Server returned HTML error page
          errorMessage = 'Server error occurred. Please try again later.';
          _logger.w('Server returned HTML error page instead of JSON');
        } else {
          // Try to parse as JSON
          try {
            final errorData = json.decode(response.body);
            errorMessage = errorData['message'] ?? 
                          errorData['error'] ?? 
                          'Failed to submit issue report';
          } catch (e) {
            // If JSON parsing fails, use generic error message
            errorMessage = 'Failed to submit issue report. Please try again.';
            _logger.w('Failed to parse error response as JSON: $e');
          }
        }
        
        _logger.w('Failed to report issue: $errorMessage');
        
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e, stackTrace) {
      _logger.e('Error reporting issue', error: e, stackTrace: stackTrace);
      
      return {
        'success': false,
        'message': 'An error occurred while submitting your report. Please try again.',
        'error': e.toString(),
      };
    }
  }

  /// Fetch active "What's New" items
  Future<Map<String, dynamic>> getWhatsNew() async {
    try {
      _logger.i('Fetching What\'s New items via ApiService');

      // Use ApiService.get which includes version and platform headers
      final response = await ApiService.get('/features/whats-new');

      _logger.i('What\'s New response status: ${response.statusCode}');
      _logger.i('What\'s New response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _logger.i('Successfully fetched What\'s New items');

        // Handle both old and new response structures
        List<dynamic> items = [];
        if (responseData['data'] != null) {
          items = responseData['data'] as List<dynamic>;
        } else if (responseData['items'] != null) {
          items = responseData['items'] as List<dynamic>;
        } else if (responseData is List) {
          items = responseData;
        }

        return {
          'success': true,
          'items': items,
          'data': responseData,
        };
      } else {
        // Check if response body is HTML (error page) instead of JSON
        String errorMessage;
        if (response.body.trim().startsWith('<!DOCTYPE') || 
            response.body.trim().startsWith('<html') ||
            response.body.trim().startsWith('<pre>')) {
          // Server returned HTML error page
          errorMessage = 'Server error occurred. Please try again later.';
          _logger.w('Server returned HTML error page instead of JSON');
        } else {
          // Try to parse as JSON
          try {
            final errorData = json.decode(response.body);
            errorMessage = errorData['message'] ?? 
                          errorData['error'] ?? 
                          'Failed to fetch What\'s New items';
          } catch (e) {
            // If JSON parsing fails, use generic error message
            errorMessage = 'Failed to fetch What\'s New items. Please try again.';
            _logger.w('Failed to parse error response as JSON: $e');
          }
        }
        
        _logger.w('Failed to fetch What\'s New: $errorMessage');
        
        return {
          'success': false,
          'message': errorMessage,
          'items': [],
        };
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching What\'s New', error: e, stackTrace: stackTrace);
      
      return {
        'success': false,
        'message': 'Failed to load What\'s New items',
        'error': e.toString(),
        'items': [],
      };
    }
  }
}

