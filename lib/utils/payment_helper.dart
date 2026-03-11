import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service_bypass.dart';

class PaymentHelper {
  /// Extract endpoint path from redirectUrl, removing /api prefix if present
  /// ApiService.baseUrl already includes /api, so we need to remove it from the path
  /// Example: http://backend.com/api/payments/open/google-pay -> /payments/open/google-pay
  static String _extractEndpointPath(String redirectUrl) {
    try {
      final uri = Uri.parse(redirectUrl);
      String path = uri.path; // e.g., /api/payments/open/google-pay
      
      // Remove /api prefix if present (since ApiService.baseUrl already includes /api)
      if (path.startsWith('/api/')) {
        path = path.substring(4); // Remove '/api' prefix
      } else if (path.startsWith('/api')) {
        path = path.substring(4); // Remove '/api' prefix
      }
      
      // Ensure path starts with /
      if (!path.startsWith('/')) {
        path = '/$path';
      }
      
      return path; // e.g., /payments/open/google-pay
    } catch (e) {
      debugPrint('Error extracting endpoint path: $e');
      return '';
    }
  }

  /// Result of opening payment app
  static const String resultSuccess = 'success';
  static const String resultAppNotInstalled = 'app_not_installed';
  static const String resultBackendError = 'backend_error';
  static const String resultNoDeepLink = 'no_deep_link';

  /// Open payment app using redirectUrl and optional deepLink/webUrl from catalog response
  /// Platform-specific behavior:
  /// - Web: Opens redirectUrl directly (backend handles redirect)
  /// - Mobile (iOS/Android): Uses deepLink from catalog if available, otherwise calls endpoint
  ///   If deepLink is not available, falls back to webUrl
  /// Returns result string indicating the outcome
  static Future<String> openPaymentAppFromRedirectUrl(String redirectUrl, String? token, {String? deepLink, String? webUrl}) async {
    try {
      debugPrint('🌐 Platform: ${kIsWeb ? "Web" : (Platform.isAndroid ? "Android" : Platform.isIOS ? "iOS" : "Unknown")}');

      // Platform-specific handling
      if (kIsWeb) {
        // WEB PLATFORM: Open redirectUrl directly
        // The backend will handle redirecting to the payment app or web page
        if (redirectUrl.isEmpty) {
          debugPrint('❌ redirectUrl is empty for web platform');
          return resultNoDeepLink;
        }

        debugPrint('🌐 Web platform: Opening redirectUrl directly: $redirectUrl');
        
        try {
          final uri = Uri.parse(redirectUrl);
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          
          if (launched) {
            debugPrint('✅ Successfully opened redirectUrl on web');
            return resultSuccess;
          } else {
            debugPrint('❌ Failed to open redirectUrl on web');
            return resultBackendError;
          }
        } catch (e) {
          debugPrint('❌ Error opening redirectUrl on web: $e');
          return resultBackendError;
        }
      } else {
        // MOBILE PLATFORM (iOS/Android): Use deepLink from catalog if available
        if (deepLink != null && deepLink.isNotEmpty) {
          // Use deepLink directly from catalog response (no API call needed!)
          debugPrint('📱 Mobile platform: Using deepLink from catalog: $deepLink');
          debugPrint('🚀 Opening payment app with deepLink...');
          
          final opened = await openPaymentApp(deepLink);
          
          if (opened) {
            debugPrint('✅ Successfully opened payment app');
            return resultSuccess;
          } else {
            debugPrint('❌ Failed to open payment app (app may not be installed)');
            return resultAppNotInstalled;
          }
        } else {
          // Fallback: Check if webUrl is available from catalog, otherwise call endpoint
          if (webUrl != null && webUrl.isNotEmpty) {
            // Use webUrl as fallback when deepLink is not available
            debugPrint('📱 Mobile platform: deepLink not available, using webUrl from catalog: $webUrl');
            debugPrint('🌐 Opening payment web URL...');
            
            try {
              final uri = Uri.parse(webUrl);
              final launched = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              
              if (launched) {
                debugPrint('✅ Successfully opened payment web URL');
                return resultSuccess;
              } else {
                debugPrint('❌ Failed to open payment web URL');
                return resultBackendError;
              }
            } catch (e) {
              debugPrint('❌ Error opening payment web URL: $e');
              return resultBackendError;
            }
          }
          
          // Fallback: Call endpoint to get deepLink/webUrl (if not in catalog response)
          debugPrint('📱 Mobile platform: deepLink and webUrl not in catalog, calling backend endpoint...');
          
          if (redirectUrl.isEmpty) {
            debugPrint('❌ redirectUrl is empty');
            return resultNoDeepLink;
          }

          // Extract the endpoint path (removing /api prefix since ApiService adds it)
          final endpoint = _extractEndpointPath(redirectUrl);
          
          if (endpoint.isEmpty) {
            debugPrint('❌ Could not extract endpoint from redirectUrl: $redirectUrl');
            return resultBackendError;
          }

          debugPrint('✅ Extracted endpoint path: $endpoint');
          debugPrint('📞 Calling backend endpoint to get deepLink/webUrl...');

          // Call the redirectUrl endpoint using ApiService
          // This calls: GET /api/payments/open/{paymentPartnerId}
          final response = await ApiService.get(endpoint, token: token);

          debugPrint('📥 Backend response status: ${response.statusCode}');

          // Check if response is successful
          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              debugPrint('📥 Backend response data: $responseData');
              
              // Extract deepLink from response
              String? fetchedDeepLink;
              String? fetchedWebUrl;
              if (responseData is Map) {
                fetchedDeepLink = responseData['deepLink']?.toString();
                fetchedWebUrl = responseData['webUrl']?.toString();
                
                if (fetchedDeepLink == null && responseData.containsKey('data')) {
                  final data = responseData['data'];
                  if (data is Map) {
                    fetchedDeepLink = data['deepLink']?.toString();
                    if (fetchedWebUrl == null) {
                      fetchedWebUrl = data['webUrl']?.toString();
                    }
                  }
                }
              }
              
              // Try deepLink first if available
              if (fetchedDeepLink != null && fetchedDeepLink.isNotEmpty) {
                debugPrint('✅ Got deepLink from endpoint: $fetchedDeepLink');
                debugPrint('🚀 Opening payment app with deepLink...');
                
                final opened = await openPaymentApp(fetchedDeepLink);
                
                if (opened) {
                  debugPrint('✅ Successfully opened payment app');
                  return resultSuccess;
                } else {
                  debugPrint('❌ Failed to open payment app (app may not be installed)');
                  return resultAppNotInstalled;
                }
              }
              
              // Fallback to webUrl if deepLink is not available
              if (fetchedWebUrl != null && fetchedWebUrl.isNotEmpty) {
                debugPrint('✅ Got webUrl from endpoint: $fetchedWebUrl');
                debugPrint('🌐 Opening payment web URL...');
                
                try {
                  final uri = Uri.parse(fetchedWebUrl);
                  final launched = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                  
                  if (launched) {
                    debugPrint('✅ Successfully opened payment web URL');
                    return resultSuccess;
                  } else {
                    debugPrint('❌ Failed to open payment web URL');
                    return resultBackendError;
                  }
                } catch (e) {
                  debugPrint('❌ Error opening payment web URL: $e');
                  return resultBackendError;
                }
              }
              
              // Neither deepLink nor webUrl found
              debugPrint('❌ No deepLink or webUrl found in endpoint response. Full response: ${response.body}');
              return resultNoDeepLink;
            } catch (e) {
              debugPrint('❌ Error parsing response body: $e');
              debugPrint('Response body: ${response.body}');
              return resultBackendError;
            }
          } else {
            debugPrint('❌ Backend endpoint failed: ${response.statusCode}');
            debugPrint('Response body: ${response.body}');
            return resultBackendError;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error in openPaymentAppFromRedirectUrl: $e');
      return resultBackendError;
    }
  }

  /// Open payment app using deep link
  /// Returns true if app opened, false if app not installed or launch failed
  static Future<bool> openPaymentApp(String deepLink) async {
    try {
      if (deepLink.isEmpty) return false;

      final uri = Uri.parse(deepLink);
      debugPrint('Attempting to open payment app with deepLink: $deepLink');

      // Try to launch directly first (canLaunchUrl can be unreliable for custom schemes)
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched) {
          debugPrint('Successfully launched payment app');
          return true;
        }
      } catch (e) {
        debugPrint('Direct launch failed: $e');
      }

      // Fallback: Check if URL can be launched
      try {
        final canLaunch = await canLaunchUrl(uri);
        if (canLaunch) {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) {
            debugPrint('Successfully launched payment app (via canLaunchUrl check)');
            return true;
          }
        }
      } catch (e) {
        debugPrint('canLaunchUrl check failed: $e');
      }

      debugPrint('Failed to launch payment app');
      return false;
    } catch (e) {
      debugPrint('Error opening payment app: $e');
      return false;
    }
  }

  /// Show error dialog when app is not installed
  static void showAppNotInstalledDialog({
    required BuildContext context,
    required String appName,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$appName Not Installed'),
          content: Text(
            '$appName is not installed on your device. '
            'Please install it first to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show error dialog when backend endpoint fails
  static void showBackendErrorDialog({
    required BuildContext context,
    required String appName,
    String? errorMessage,
  }) {
    // Check if we're on web (CORS issues are common on web)
    final isWeb = kIsWeb;
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Payment Service Unavailable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                errorMessage != null
                    ? 'Unable to open $appName: $errorMessage'
                    : 'Unable to connect to payment service.',
              ),
              if (isWeb) ...[
                const SizedBox(height: 12),
                const Text(
                  'Note: Payment apps can only be opened on mobile devices. '
                  'Please use the mobile app to make payments.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ] else if (isMobile) ...[
                const SizedBox(height: 12),
                const Text(
                  'Please check your internet connection and try again.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}


