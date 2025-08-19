import 'dart:convert';
import 'dart:io'; // For SocketException
import 'dart:async'; // For TimeoutException
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'version_service.dart';
import '../widgets/force_update_dialog.dart';
import '../main.dart'; // To access navigatorKey

class ApiService {
  static String get baseUrl {
    final envBase = dotenv.env['API_BASE_URL'];
    final resolvedBase = (envBase != null && envBase.isNotEmpty)
        ? envBase
        : 'https://manage-receipt-backend-1.onrender.com'; // Fallback backend if .env is missing
    if (envBase == null || envBase.isEmpty) {
      debugPrint('⚠️ API_BASE_URL missing in .env. Falling back to $resolvedBase');
    }
    return '$resolvedBase/api';
  }

  static BuildContext? _currentContext;
  static bool _isForceUpdateDialogShowing = false;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static void setContext(BuildContext context) {
    _currentContext = context;
    debugPrint('ApiService context set: ${context.mounted}');
  }

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

// Helper to handle network errors and navigate to NoInternetScreen
  static void _handleNetworkError(dynamic e) {
    debugPrint('API Service Network Error: $e');

    // Get the context from the navigator key
    final BuildContext? navContext = _navigatorKey?.currentState?.context;

    String? currentRouteName;
    if (navContext != null) {
      currentRouteName = ModalRoute.of(navContext)?.settings.name;
    }

    // Optionally, show a snackbar if context is available
    if (_currentContext != null && _currentContext!.mounted) {
      ScaffoldMessenger.of(_currentContext!).showSnackBar(
        const SnackBar(
          content: Text('Network error. Please check your internet connection.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

// BYPASS: Intercept subscription-related API calls
  static Future<http.Response> get(String endpoint, {String? token, Map<String, String>? queryParameters}) async {
    Uri url;
    if (queryParameters != null && queryParameters.isNotEmpty) {
      url = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParameters);
    } else {
      url = Uri.parse('$baseUrl$endpoint');
    }

    final headers = await _getHeaders(token: token);

    try {
      debugPrint('Making GET request to: $url');

      // BYPASS: Intercept subscription-related endpoints
      if (endpoint.contains('subscriptions/current')) {
        debugPrint('BYPASS MODE: Intercepting subscription current endpoint');
        return _createBypassSubscriptionResponse();
      }

      if (endpoint.contains('subscriptions/receipt-status')) {
        debugPrint('BYPASS MODE: Intercepting receipt status endpoint');
        return _createBypassReceiptStatusResponse();
      }

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));
      debugPrint('Response status: ${response.statusCode}');

      await _handleResponse(response);
      return response;
    } on SocketException catch (e) {
      _handleNetworkError(e);
      return http.Response('{"error": "No internet connection"}', 503);
    } on TimeoutException catch (e) {
      _handleNetworkError(e);
      return http.Response('{"error": "Request timed out"}', 504);
    } catch (e) {
      debugPrint('API GET Error: $e');
      return http.Response('{"error": "An unexpected error occurred"}', 500);
    }
  }

// BYPASS: Create mock subscription response
  static http.Response _createBypassSubscriptionResponse() {
    final mockResponse = {
      'subscription': {
        'Plan': {
          'id': 'premium_plan',
          'name': 'Premium Tier',
          'description': 'Advanced features for power users and businesses',
          'receiptLimit': 999999,
          'hasExportAccess': true,
        },
        'paymentStatus': 'active',
        'source': 'bypass_mode',
        'startDate': DateTime.now().toIso8601String(),
      }
    };

    return http.Response(
      json.encode(mockResponse),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

// BYPASS: Create mock receipt status response
  static http.Response _createBypassReceiptStatusResponse() {
    final mockResponse = {
      'used': 0,
      'limit': 999999,
      'plan': 'Premium Tier',
      'isLimitReached': false,
      'isUnlimited': true,
    };

    return http.Response(
      json.encode(mockResponse),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  static Future<http.Response> post(String endpoint, {
    Map<String, dynamic>? body,
    String? token,
    Map<String, String>? additionalHeaders,
    // Added for multipart form data
    http.MultipartFile? file,
    Map<String, String>? fields,
    // Added timeout parameter with default of 15 seconds
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(token: token);

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    try {
      debugPrint('Making POST request to: $url');

      // BYPASS: Intercept subscription creation endpoints
      if (endpoint.contains('subscriptions/create')) {
        debugPrint('BYPASS MODE: Intercepting subscription creation endpoint');
        return _createBypassSuccessResponse('Subscription created successfully');
      }

      if (endpoint.contains('subscriptions/cancel')) {
        debugPrint('BYPASS MODE: Intercepting subscription cancellation endpoint');
        return _createBypassSuccessResponse('Subscription cancelled successfully');
      }

      if (file != null && fields != null) {
        // Handle multipart/form-data (only when there's a file)
        debugPrint('📤 Creating multipart request to: $url');
        var request = http.MultipartRequest('POST', url);
        
        // Add headers but exclude Content-Type to let MultipartRequest set it automatically
        final multipartHeaders = Map<String, String>.from(headers);
        multipartHeaders.remove('Content-Type'); // Remove to avoid conflicts with multipart boundary
        request.headers.addAll(multipartHeaders);
        
        debugPrint('📋 Headers (without Content-Type): $multipartHeaders');
        
        request.files.add(file);
        debugPrint('📎 File attached: ${file.filename}');
        
        debugPrint('📝 Adding fields to multipart request:');
        fields.forEach((key, value) {
          debugPrint('  - $key: $value (length: ${value.length})');
          request.fields[key] = value;
        });
        debugPrint('✅ Total fields added: ${request.fields.length}');
        debugPrint('🔍 Final request.fields: ${request.fields}');
        
        debugPrint('🚀 Sending multipart request with ${request.files.length} file(s) and ${request.fields.length} field(s)');
        final streamedResponse = await request.send().timeout(timeout);
        final response = await http.Response.fromStream(streamedResponse);
        debugPrint('📥 Response status: ${response.statusCode}');
        debugPrint('📥 Response body: ${response.body}');
        await _handleResponse(response);
        return response;
      } else if (fields != null && file == null) {
        // Handle application/x-www-form-urlencoded (when there's no file)
        debugPrint('📤 Sending form-urlencoded request to: $url');
        debugPrint('📝 Form fields: $fields');
        
        // Use application/x-www-form-urlencoded
        headers['Content-Type'] = 'application/x-www-form-urlencoded';
        
        // Convert fields to URL-encoded string
        final encodedBody = fields.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        
        debugPrint('📤 Encoded body: $encodedBody');
        
        final response = await http.post(
          url,
          headers: headers,
          body: encodedBody,
        ).timeout(timeout);
        
        debugPrint('📥 Response status: ${response.statusCode}');
        debugPrint('📥 Response body: ${response.body}');
        await _handleResponse(response);
        return response;
      } else {
        // Handle application/json
        final response = await http.post(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        ).timeout(timeout);
        debugPrint('Response status: ${response.statusCode}');
        await _handleResponse(response);
        return response;
      }
    } on SocketException catch (e) {
      _handleNetworkError(e);
      return http.Response('{"error": "No internet connection"}', 503);
    } on TimeoutException catch (e) {
      _handleNetworkError(e);
      return http.Response('{"error": "Request timed out"}', 504);
    } catch (e) {
      debugPrint('API POST Error: $e');
      return http.Response('{"error": "An unexpected error occurred"}', 500);
    }
  }

// BYPASS: Create mock success response
  static http.Response _createBypassSuccessResponse(String message) {
    final mockResponse = {
      'success': true,
      'message': message,
    };

    return http.Response(
      json.encode(mockResponse),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  static Future<http.Response> put(String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(token: token);

    try {
      debugPrint('Making PUT request to: $url');
      final response = await http.put(
        url,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      ).timeout(const Duration(seconds: 15));
      debugPrint('Response status: ${response.statusCode}');
      await _handleResponse(response);
      return response;
    } on SocketException catch (e) {
      _handleNetworkError(e);
      return http.Response('{"error": "No internet connection"}', 503);
    } on TimeoutException catch (e) {
      _handleNetworkError(e);
      return http.Response('{"error": "Request timed out"}', 504);
    } catch (e) {
      debugPrint('API PUT Error: $e');
      return http.Response('{"error": "An unexpected error occurred"}', 500);
    }
  }

  static Future<http.Response> patch(String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(token: token);

    try {
      debugPrint('Making PATCH request to: $url');
      final response = await http.patch(
        url,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      ).timeout(const Duration(seconds: 15));
      debugPrint('Response status: ${response.statusCode}');
      await _handleResponse(response);
      return response;
    } on SocketException catch (e) {
      _handleNetworkError(e);
      return http.Response('{"error": "No internet connection"}', 503);
    } on TimeoutException catch (e) {
      _handleNetworkError(e);
      return http.Response('{"error": "Request timed out"}', 504);
    } catch (e) {
      debugPrint('API PATCH Error: $e');
      return http.Response('{"error": "An unexpected error occurred"}', 500);
    }
  }

// MODIFIED: Added queryParameters for DELETE requests
  static Future<http.Response> delete(String endpoint, {String? token, Map<String, dynamic>? body, Map<String, String>? queryParameters}) async {
    Uri url;
    if (queryParameters != null && queryParameters.isNotEmpty) {
      url = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParameters);
    } else {
      url = Uri.parse('$baseUrl$endpoint');
    }
    final headers = await _getHeaders(token: token);

    try {
      debugPrint('Making DELETE request to: $url');
      final response = await http.delete(
        url,
        headers: headers,
        body: body != null ? json.encode(body) : null, // Encode body if present
      ).timeout(const Duration(seconds: 15));
      debugPrint('Response status: ${response.statusCode}');
      await _handleResponse(response);
      return response;
    } on SocketException catch (e) {
      _handleNetworkError(e);
      return http.Response('{"error": "No internet connection"}', 503);
    } on TimeoutException catch (e) {
      _handleNetworkError(e);
      return http.Response('{"error": "Request timed out"}', 504);
    } catch (e) {
      debugPrint('API DELETE Error: $e');
      return http.Response('{"error": "An unexpected error occurred"}', 500);
    }
  }

  static Future<http.Response> postWebhook(String endpoint, {
    required Map<String, dynamic> webhookData,
    String? userId,
    String? token,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(token: token);

    headers['Content-Type'] = 'application/json';
    if (userId != null) {
      headers['X-User-ID'] = userId;
    }

    try {
      debugPrint('Making RevenueCat webhook request to: $url');
      debugPrint('Webhook data: ${json.encode(webhookData)}');

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(webhookData),
      ).timeout(const Duration(seconds: 15));

      debugPrint('Webhook response status: ${response.statusCode}');
      debugPrint('Webhook response body: ${response.body}');

      await _handleResponse(response);
      return response;
    } on SocketException catch (e) {
      _handleNetworkError(e);
      return http.Response('{"error": "No internet connection"}', 503);
    } on TimeoutException catch (e) {
      _handleNetworkError(e);
      return http.Response('{"error": "Request timed out"}', 504);
    } catch (e) {
      debugPrint('Webhook API Error: $e');
      return http.Response('{"error": "An unexpected error occurred"}', 500);
    }
  }

  static Future<Map<String, String>> _getHeaders({String? token}) async {
    if (!VersionService.isInitialized) {
      await VersionService.initialize();
    }
    // VersionService.getHeaders is assumed to add 'currentversion' and 'platform' headers
    return VersionService.getHeaders(token: token);
  }

  static Future<Map<String, String>> getHeaders({String? token}) async {
    return await _getHeaders(token: token);
  }

  static Future<void> _handleResponse(http.Response response) async {
    if (response.statusCode == 426) {
      debugPrint('🚨 426 Upgrade Required received - attempting to show force update dialog');

      if (_isForceUpdateDialogShowing) {
        debugPrint('Force update dialog already showing, skipping...');
        throw Exception('App update required - 426 Upgrade Required');
      }

      bool dialogShown = false;

      try {
        if (_currentContext != null && _currentContext!.mounted) {
          debugPrint('Attempting to show dialog with current context');
          dialogShown = await _showForceUpdateDialogWithContext(_currentContext!);
        }

        // Use _navigatorKey?.currentState?.context instead of currentContext
        if (!dialogShown && _navigatorKey?.currentState?.context != null) {
          debugPrint('Attempting to show dialog with navigator key context');
          dialogShown = await _showForceUpdateDialogWithContext(_navigatorKey!.currentState!.context);
        }

        if (!dialogShown && _navigatorKey?.currentState != null) {
          debugPrint('Attempting to show dialog with global navigator state');
          dialogShown = await _showForceUpdateDialogWithNavigator(_navigatorKey!.currentState!);
        }

      } catch (e) {
        debugPrint('Error showing force update dialog: $e');
        dialogShown = false;
      }

      if (!dialogShown) {
        debugPrint('All dialog approaches failed, showing fallback');
        await _showFallbackUpdateDialog();
      }

      throw Exception('App update required - 426 Upgrade Required');
    }
  }

  static Future<bool> _showForceUpdateDialogWithContext(BuildContext context) async {
    if (!context.mounted) {
      debugPrint('Context not mounted, cannot show dialog');
      return false;
    }

    try {
      _isForceUpdateDialogShowing = true;
      debugPrint('Setting dialog showing flag to true');

      final appInfo = await VersionService.getCurrentAppInfo();
      final currentVersion = appInfo['version'] ?? '1.0.0';
      final platform = appInfo['platform'] ?? 'unknown';

      String storeUrl;
      String storeName;

      if (platform.toLowerCase() == 'android') {
        storeUrl = 'https://play.google.com/store/apps/details?id=com.ButterflyTchnology.managereceipt';
        storeName = 'Play Store';
      } else if (platform.toLowerCase() == 'ios') {
        storeUrl = 'https://apps.apple.com/in/app/manage-receipt-track-expenses/id6746782746';
        storeName = 'App Store';
      } else {
        storeUrl = 'https://managereceipt.com/';
        storeName = 'Download Page';
      }

      debugPrint('Showing force update dialog...');

      await showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (BuildContext dialogContext) {
          return WillPopScope(
            onWillPop: () async => false,
            child: ForceUpdateDialog(
              currentVersion: currentVersion,
              latestVersion: 'Latest',
              minRequiredVersion: 'Required',
              message: 'A new version of the app is required to continue. Please update from the $storeName to access all features.',
              downloadUrl: storeUrl,
              forceUpdate: true,
              optionalUpdate: false,
              isVersionConflict: false,
            ),
          );
        },
      );

      _isForceUpdateDialogShowing = false;
      debugPrint('Force update dialog completed');
      return true;

    } catch (e) {
      _isForceUpdateDialogShowing = false;
      debugPrint('Error in _showForceUpdateDialogWithContext: $e');
      return false;
    }
  }

  static Future<bool> _showForceUpdateDialogWithNavigator(NavigatorState navigator) async {
    try {
      _isForceUpdateDialogShowing = true;

      final appInfo = await VersionService.getCurrentAppInfo();
      final currentVersion = appInfo['version'] ?? '1.0.0';
      final platform = appInfo['platform'] ?? 'unknown';

      String storeUrl;
      String storeName;

      if (platform.toLowerCase() == 'android') {
        storeUrl = 'https://play.google.com/store/apps/details?id=com.ButterflyTchnology.managereceipt';
        storeName = 'Play Store';
      } else if (platform.toLowerCase() == 'ios') {
        storeUrl = 'https://apps.apple.com/in/app/manage-receipt-track-expenses/id6746782746';
        storeName = 'App Store';
      } else {
        storeUrl = 'https://managereceipt.com/';
        storeName = 'Download Page';
      }

      await navigator.push(
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: false,
          pageBuilder: (BuildContext context, _, __) {
            return ForceUpdateDialog(
              currentVersion: currentVersion,
              latestVersion: 'Latest',
              minRequiredVersion: 'Required',
              message: 'A new version of the app is required to continue. Please update from the $storeName to access all features.',
              downloadUrl: storeUrl,
              forceUpdate: true,
              optionalUpdate: false,
              isVersionConflict: false,
            );
          },
        ),
      );

      _isForceUpdateDialogShowing = false;
      return true;

    } catch (e) {
      _isForceUpdateDialogShowing = false;
      debugPrint('Error in _showForceUpdateDialogWithNavigator: $e');
      return false;
    }
  }

  static Future<void> _showFallbackUpdateDialog() async {
    debugPrint('Showing fallback update dialog');

    try {
      final context = _currentContext ?? _navigatorKey?.currentState?.context; // Corrected access

      if (context != null && context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.system_update, color: Colors.orange, size: 28),
                    SizedBox(width: 12),
                    Text('Update Required'),
                  ],
                ),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'A new version of the app is required to continue. Please update your app from the store.',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'This update is mandatory to access the app.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      // This will close the app or redirect to store
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Update Now'),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        debugPrint('No context available for fallback dialog');
      }
    } catch (e) {
      debugPrint('Fallback dialog also failed: $e');
    }
  }

  static void resetDialogState() {
    _isForceUpdateDialogShowing = false;
    debugPrint('Dialog state reset');
  }

  static Future<void> testForceUpdateDialog() async {
    debugPrint('🧪 Testing force update dialog...');
    await _handleResponse(http.Response('Upgrade Required', 426));
  }
}
