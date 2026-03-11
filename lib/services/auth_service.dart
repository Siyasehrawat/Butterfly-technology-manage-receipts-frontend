import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_manager.dart';
import 'currency_service.dart';
import 'fcm_service.dart';
import 'notification_service.dart';
import 'version_service.dart';

class AuthService {
  final Logger _logger = Logger();
  final AuthManager _authManager = AuthManager();
  
  // Get base URL from environment with fallback
  static String get baseUrl {
    final envBase = dotenv.env['API_BASE_URL'];
    final resolvedBase = (envBase != null && envBase.isNotEmpty)
        ? envBase
        : 'https://manage-receipt-backend-1.onrender.com';
    if (envBase == null || envBase.isEmpty) {
      Logger().w('⚠️ API_BASE_URL missing in .env. Falling back to $resolvedBase');
    }
    return '$resolvedBase/api';
  }

  // (Facebook removed)

  static const String _appleClientId = String.fromEnvironment(
      'APPLE_CLIENT_ID',
      defaultValue: 'com.ButterflyTchnology.ReceiptManagerapp'); // Service ID used as client_id on web
  static const String _appleRedirectUri = String.fromEnvironment(
      'APPLE_REDIRECT_URI',
      defaultValue:
      'https://managereceipt.com/web-app/apple-callback'); // must be allowed in Apple settings

  AuthService() {
    _logger.i(
        'AuthService initialized for platform: ${kIsWeb ? 'Web' : Platform.operatingSystem}');

    // Facebook SDK initialization removed
  }
  // Regular email/password signup
  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
    required String country,
    required bool termsAccepted,
    String? referralCode,
  }) async {
    try {
      _logger.i('Starting email/password signup for: $email');

      if (!termsAccepted) {
        return {
          'success': false,
          'message': 'You must accept the Terms and Conditions to sign up.'
        };
      }

      final requestBody = {
        "name": name,
        "email": email,
        "password": password,
        "country": country,
        "termsAccepted": termsAccepted,
      };

      // Add referral code if provided (auto-uppercase as per API docs)
      if (referralCode != null && referralCode.trim().isNotEmpty) {
        requestBody["referralCode"] = referralCode.trim().toUpperCase();
      }

      final response = await http.post(
        Uri.parse("$baseUrl/users/signup"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(requestBody),
      );

      _logger.i('Signup response status: ${response.statusCode}');
      _logger.i('Signup response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        _logger.i('Signup successful');

        final userId = responseData['user']?['id']?.toString();
        final token = responseData['token']?.toString();
        final userCountry = responseData['user']?['country'] ?? country;

        // Get currency info from country
        final currencyInfo = CurrencyService.getCurrencyForCountry(userCountry);
        final userCurrency = responseData['user']?['currency'] ?? currencyInfo['currency'];
        final userCurrencySymbol = responseData['user']?['currencySymbol'] ?? currencyInfo['symbol'];

        if (userId != null && token != null) {
          await _authManager.saveAuthData(
            token: token,
            userId: userId,
            email: email,
            name: name,
            country: userCountry,
            canUpdatePassword: responseData['canUpdatePassword'] ?? responseData['canupdatepassword'],
          );

          // Also cache username redundantly in SharedPreferences for faster boot retrieval
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_name_$userId', name);
            await prefs.setString('cached_username', name);
          } catch (_) {}

          // Initialize FCM for new user
          if (!kIsWeb) {
            FCMService.setCurrentUserId(userId);
            await NotificationService.onUserLogin(userId);
          }

          _logger.i('Auth data saved with country: $userCountry, currency: $userCurrency, symbol: $userCurrencySymbol');
        }

        return {
          'success': true,
          'userId': userId,
          'token': token,
          'currency': userCurrency,
          'currencySymbol': userCurrencySymbol,
          'country': userCountry,
          // Force true for email/password signups so we don't block on profile completion
          'canUpdatePassword': responseData['canUpdatePassword'] ?? responseData['canupdatepassword'],
          'message': 'Signup successful'
        };
      } else {
        String errorMessage = 'Registration failed. Please try again.';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;

          if (errorMessage.toLowerCase().contains('already exists') ||
              errorMessage.toLowerCase().contains('already registered') ||
              errorMessage.toLowerCase().contains('already in use')) {
            errorMessage =
            'Email already exists. Please use a different email address.';
          }

          _logger.w('Signup failed: $errorMessage');
        } catch (e) {
          _logger.e('Failed to parse error response: $e');
        }

        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      _logger.e('Sign-up error: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again.'
      };
    }
  }

  // Regular email/password login
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
    bool termsAccepted = true,
  }) async {
    try {
      _logger.i('Starting email/password login for: $email');
      if (!termsAccepted) {
        return {
          'success': false,
          'message': 'You must accept the Terms and Conditions to sign up.'
        };
      }

      _logger.i('Login request payload: ${jsonEncode({
        "emailOrPhone": email,
        "password": "REDACTED",
        "termsAccepted": termsAccepted,
      })}');

      try {
        final pingResponse = await http.get(
          Uri.parse("${dotenv.env['API_BASE_URL']}/health"),
          headers: {"Accept": "application/json"},
        ).timeout(const Duration(seconds: 5));

        _logger.i('Backend health check status: ${pingResponse.statusCode}');
      } catch (e) {
        _logger.w('Backend health check failed: $e');
      }

      final response = await http.post(
        Uri.parse("$baseUrl/users/login"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "emailOrPhone": email,
          "password": password,
          "termsAccepted": termsAccepted,
        }),
      );

      _logger.i('Login response status: ${response.statusCode}');
      _logger.i('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final token = responseData['token'];

        final List<dynamic> screens = responseData['screens'] ?? [];
        final bool hasAdminAccess = screens.contains('AdminPanel');
        final userCountry = responseData['country'] ?? responseData['user']?['country'];

        _logger.i('Login response country: $userCountry');

        if (token != null) {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = json.decode(
              utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
            );
            final userId = payload['id'];

            if (userId != null) {
              _logger.i('Login successful for user: $userId');

              // Get currency info from country
              String? country = userCountry;
              if (country == null) {
                country = await _authManager.getUserCountry();
                _logger.i('Retrieved country from storage: $country');
              }

              // Map country to currency using CurrencyService
              Map<String, String> currencyInfo = {'currency': 'USD', 'symbol': '\$'};
              if (country != null && country.isNotEmpty) {
                currencyInfo = CurrencyService.getCurrencyForCountry(country);
                _logger.i('Mapped country "$country" to currency: ${currencyInfo['currency']} (${currencyInfo['symbol']})');
              }

              // Use backend response if available, otherwise use mapped currency
              final finalCurrency = responseData['user']?['currency'] ?? currencyInfo['currency'];
              final finalCurrencySymbol = responseData['user']?['currencySymbol'] ?? currencyInfo['symbol'];

              await _authManager.saveAuthData(
                token: token,
                userId: userId,
                email: email,
                hasAdminAccess: hasAdminAccess,
                name: responseData['user']?['name'],
                country: country,
                canUpdatePassword: responseData['canUpdatePassword'] ?? responseData['canupdatepassword'],
              );

              // Initialize FCM after successful login
              if (!kIsWeb) {
                FCMService.setCurrentUserId(userId);
                await NotificationService.onUserLogin(userId);
              }

              return {
                'success': true,
                'userId': userId,
                'token': token,
                'hasAdminAccess': hasAdminAccess,
                'currency': finalCurrency,
                'currencySymbol': finalCurrencySymbol,
                'country': country,
                'name': responseData['user']?['name'],
              // Include canUpdatePassword from login response if present
              'canUpdatePassword': responseData['canUpdatePassword'] ?? responseData['canupdatepassword'],
                'message': 'Login successful'
              };
            } else {
              _logger.w('User ID missing in token payload');
              return {
                'success': false,
                'message': 'User ID missing in token payload'
              };
            }
          } else {
            _logger.w('Invalid token format');
            return {'success': false, 'message': 'Invalid token format'};
          }
        } else {
          _logger.w('Token missing in response');
          return {'success': false, 'message': 'Token missing in response'};
        }
      } else {
        String errorMessage = 'Login failed: Invalid email or password';
        try {
          final responseData = json.decode(response.body);
          errorMessage = responseData['message'] ?? errorMessage;
        } catch (e) {
          _logger.e('Failed to parse error response: $e');
        }

        _logger.w('Login failed: $errorMessage');
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      _logger.e('Error during login: $e');

      String errorMessage = 'An error occurred. Please try again.';

      if (e is http.ClientException) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e is SocketException) {
        errorMessage =
        'Cannot connect to server. Please check your internet connection.';
      } else if (e is FormatException) {
        errorMessage = 'Invalid response from server. Please try again later.';
      } else if (e is TimeoutException) {
        errorMessage =
        'Server is taking too long to respond. Please try again later.';
      }

      return {'success': false, 'message': errorMessage};
    }
  }

  // Helper function to validate E.164 phone format
  static bool isValidE164Phone(String phone) {
    // E.164 format: must start with +, followed by country code and number
    // No spaces or special characters except +
    final e164Regex = RegExp(r'^\+[1-9]\d{1,14}$');
    return e164Regex.hasMatch(phone);
  }

  // Helper function to check if input is email or phone
  static bool isEmail(String input) {
    final emailRegex = RegExp(r'^[\w-]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(input);
  }

  // Helper function to check if input is phone (E.164)
  static bool isPhone(String input) {
    return isValidE164Phone(input);
  }

  // Send Phone OTP for Signup
  Future<Map<String, dynamic>> sendPhoneOTP({
    required String phone,
  }) async {
    try {
      _logger.i('Sending phone OTP for: $phone');

      if (!isValidE164Phone(phone)) {
        return {
          'success': false,
          'message': 'Invalid phone number format. Must be in E.164 format (e.g., +1234567890)'
        };
      }

      // Get headers with version and platform information
      final headers = await _getHeaders();
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';

      final response = await http.post(
        Uri.parse("$baseUrl/users/auth/phone/send-otp"),
        headers: headers,
        body: jsonEncode({
          "phone": phone,
        }),
      );

      _logger.i('Send phone OTP response status: ${response.statusCode}');
      _logger.i('Send phone OTP response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': responseData['message'],
          'phone': responseData['phone'],
          'otp': responseData['otp'], // Only in development mode
        };
      } else {
        String errorMessage = 'Failed to send OTP. Please try again.';
        int? retryAfter;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
          retryAfter = errorData['retryAfter'];
        } catch (e) {
          _logger.e('Failed to parse error response: $e');
        }

        return {
          'success': false,
          'message': errorMessage,
          'retryAfter': retryAfter,
        };
      }
    } catch (e) {
      _logger.e('Error sending phone OTP: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again.'
      };
    }
  }

  // Verify Phone OTP for Signup
  Future<Map<String, dynamic>> verifyPhoneOTP({
    required String phone,
    required String otp,
  }) async {
    try {
      _logger.i('Verifying phone OTP for: $phone');

      if (!isValidE164Phone(phone)) {
        return {
          'success': false,
          'message': 'Invalid phone number format. Must be in E.164 format (e.g., +1234567890)'
        };
      }

      // Get headers with version and platform information
      final headers = await _getHeaders();
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';

      final response = await http.post(
        Uri.parse("$baseUrl/users/auth/phone/verify-otp"),
        headers: headers,
        body: jsonEncode({
          "phone": phone,
          "otp": otp,
        }),
      );

      _logger.i('Verify phone OTP response status: ${response.statusCode}');
      _logger.i('Verify phone OTP response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': responseData['message'],
          'verified': responseData['verified'] ?? true,
          'userExists': responseData['userExists'] ?? false,
          'requiresPassword': responseData['requiresPassword'] ?? false,
        };
      } else {
        String errorMessage = 'Invalid or expired OTP. Please try again.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          _logger.e('Failed to parse error response: $e');
        }

        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      _logger.e('Error verifying phone OTP: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again.'
      };
    }
  }

  // Complete Phone Login/Registration
  Future<Map<String, dynamic>> completePhoneLogin({
    required String phone,
    required String email,
    required String password,
    required String country,
    String? name, // Required for new users only
    bool termsAccepted = true,
    String? referralCode,
  }) async {
    try {
      _logger.i('Completing phone login/registration for: $phone');

      if (!termsAccepted) {
        return {
          'success': false,
          'message': 'You must accept the Terms and Conditions to continue.'
        };
      }

      if (!isValidE164Phone(phone)) {
        return {
          'success': false,
          'message': 'Invalid phone number format. Must be in E.164 format (e.g., +1234567890)'
        };
      }

      final payload = {
        "phone": phone,
        "email": email,
        "password": password,
        "country": country,
      };

      if (name != null && name.isNotEmpty) {
        payload["name"] = name;
      }

      // Add referral code if provided (auto-uppercase as per API docs)
      if (referralCode != null && referralCode.trim().isNotEmpty) {
        payload["referralCode"] = referralCode.trim().toUpperCase();
      }

      _logger.i('Complete phone login payload: ${jsonEncode({
        ...payload,
        "password": "REDACTED",
      })}');

      // Get headers with version and platform information
      final headers = await _getHeaders();
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';

      final response = await http.post(
        Uri.parse("$baseUrl/users/auth/phone/complete"),
        headers: headers,
        body: jsonEncode(payload),
      );

      _logger.i('Complete phone login response status: ${response.statusCode}');
      _logger.i('Complete phone login response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final token = responseData['token'];
        final user = responseData['user'] ?? {};
        final userId = user['id']?.toString() ?? responseData['userId']?.toString();
        final userEmail = user['email'] ?? email;
        final userName = user['name'] ?? name ?? '';
        final userCountry = user['country'] ?? country;
        final List<dynamic> screens = responseData['screens'] ?? [];
        final bool hasAdminAccess = screens.contains('AdminPanel');

        // Get currency info from country
        Map<String, String> currencyInfo = {'currency': 'USD', 'symbol': '\$'};
        if (userCountry != null && userCountry.isNotEmpty) {
          currencyInfo = CurrencyService.getCurrencyForCountry(userCountry);
        }
        final finalCurrency = user['currency'] ?? currencyInfo['currency'];
        final finalCurrencySymbol = user['currencySymbol'] ?? currencyInfo['symbol'];

        if (token != null && userId != null) {
          await _authManager.saveAuthData(
            token: token,
            userId: userId,
            email: userEmail,
            name: userName,
            country: userCountry,
            hasAdminAccess: hasAdminAccess,
            canUpdatePassword: responseData['canUpdatePassword'] ?? responseData['canupdatepassword'] ?? true,
          );

          // Initialize FCM after successful login
          if (!kIsWeb) {
            FCMService.setCurrentUserId(userId);
            await NotificationService.onUserLogin(userId);
          }

          return {
            'success': true,
            'userId': userId,
            'token': token,
            'hasAdminAccess': hasAdminAccess,
            'currency': finalCurrency,
            'currencySymbol': finalCurrencySymbol,
            'country': userCountry,
            'name': userName,
            'email': userEmail,
            'canUpdatePassword': responseData['canUpdatePassword'] ?? responseData['canupdatepassword'] ?? true,
            'message': responseData['message'] ?? 'Registration/Login successful'
          };
        } else {
          return {
            'success': false,
            'message': 'Invalid response from server'
          };
        }
      } else {
        String errorMessage = 'Failed to complete registration/login. Please try again.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          _logger.e('Failed to parse error response: $e');
        }

        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      _logger.e('Error completing phone login: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again.'
      };
    }
  }

  // Forgot Password (Updated to support emailOrPhone)
  Future<Map<String, dynamic>> forgotPassword({
    required String emailOrPhone,
  }) async {
    try {
      _logger.i('Forgot password request for: $emailOrPhone');

      final response = await http.post(
        Uri.parse("$baseUrl/users/forgot-password"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "emailOrPhone": emailOrPhone,
        }),
      );

      _logger.i('Forgot password response status: ${response.statusCode}');
      _logger.i('Forgot password response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': responseData['message'] ?? 'OTP sent successfully',
        };
      } else {
        String errorMessage = 'Failed to send reset OTP. Please try again.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          _logger.e('Failed to parse error response: $e');
        }

        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      _logger.e('Error in forgot password: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again.'
      };
    }
  }

  // Verify OTP (Updated to support emailOrPhone)
  Future<Map<String, dynamic>> verifyOTP({
    required String emailOrPhone,
    required String otp,
  }) async {
    try {
      _logger.i('Verifying OTP for: $emailOrPhone');

      final headers = await _getHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await http.post(
        Uri.parse("$baseUrl/users/verify-otp"),
        headers: headers,
        body: jsonEncode({
          "emailOrPhone": emailOrPhone,
          "otp": otp,
        }),
      );

      _logger.i('Verify OTP response status: ${response.statusCode}');
      _logger.i('Verify OTP response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': responseData['message'] ?? 'OTP verified successfully',
        };
      } else {
        String errorMessage = 'Invalid or expired OTP. Please try again.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          _logger.e('Failed to parse error response: $e');
        }

        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      _logger.e('Error verifying OTP: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again.'
      };
    }
  }

  // Reset Password (Updated to support emailOrPhone)
  Future<Map<String, dynamic>> resetPassword({
    required String emailOrPhone,
    required String otp,
    required String newPassword,
  }) async {
    try {
      _logger.i('Resetting password for: $emailOrPhone');

      final response = await http.post(
        Uri.parse("$baseUrl/users/reset-password"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "emailOrPhone": emailOrPhone,
          "otp": otp,
          "newPassword": newPassword,
        }),
      );

      _logger.i('Reset password response status: ${response.statusCode}');
      _logger.i('Reset password response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': responseData['message'] ?? 'Password reset successfully',
        };
      } else {
        String errorMessage = 'Failed to reset password. Please try again.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          _logger.e('Failed to parse error response: $e');
        }

        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      _logger.e('Error resetting password: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again.'
      };
    }
  }

  // Helper method to get headers (for verifyOTP)
  Future<Map<String, String>> _getHeaders() async {
    if (!VersionService.isInitialized) {
      await VersionService.initialize();
    }
    return VersionService.getHeaders();
  }

  // Update Password
  Future<Map<String, dynamic>> updatePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final url =
    Uri.parse('$baseUrl/users/update-password');
    try {
      _logger.i('Sending password update request for user ID: $userId');

      final body = jsonEncode({
        'userId': userId,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        _logger.i('Password updated successfully for user ID: $userId');
        return {'success': true, 'message': 'Password updated successfully'};
      } else {
        final responseBody = jsonDecode(response.body);
        _logger.w('Password update failed: ${responseBody['message']}');
        return {'success': false, 'message': responseBody['message']};
      }
    } catch (error) {
      _logger.e('Error updating password: $error');
      return {'success': false, 'message': 'Error updating password'};
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _logger.i('Starting sign out process');

      // Clear FCM data before clearing auth data
      if (!kIsWeb) {
        FCMService.clearCurrentUser();
      }

      await _authManager.clearAuthData();
      _logger.i('Cleared stored authentication data');
      _logger.i('Successfully signed out');
    } catch (e) {
      _logger.e('Sign out error: $e');
    }
  }

  // Helper method to check if the backend is available
  Future<bool> isBackendAvailable() async {
    try {
      final response = await http
          .get(
        Uri.parse("${dotenv.env['API_BASE_URL']}/health"),
      )
          .timeout(const Duration(seconds: 5));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      _logger.w('Backend availability check failed: $e');
      return false;
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    return await _authManager.isLoggedIn();
  }

  // Check if user has admin access
  Future<bool> hasAdminAccess() async {
    return await _authManager.hasAdminAccess();
  }

  // Get user country
  Future<String?> getUserCountry() async {
    return await _authManager.getUserCountry();
  }

  // Social login - Google
  Future<Map<String, dynamic>> signInWithGoogle({bool termsAccepted = true, String? name, String? country}) async {
    try {
      if (!termsAccepted) {
        return {'success': false, 'message': 'You must accept the Terms and Conditions to continue.'};
      }

      final GoogleSignIn googleSignIn = kIsWeb
          ? GoogleSignIn(
              scopes: const ['openid', 'email', 'profile'],
              // On web, use clientId not serverClientId
              clientId:
                  '964886436743-tj9r29rfqir0781h9p54vv3abbh28h4e.apps.googleusercontent.com',
            )
          : GoogleSignIn(
              scopes: const ['email', 'profile'],
              // On mobile, set serverClientId so an ID token is issued for backend
              serverClientId:  Platform.isIOS
                 ? '964886436743-3vtji86ff4kql2n780l3u7ht8gloi9rl.apps.googleusercontent.com'
                 : null,

              clientId: Platform.isIOS
                  ? '964886436743-3vtji86ff4kql2n780l3u7ht8gloi9rl.apps.googleusercontent.com'
                  : null,

            );

      GoogleSignInAccount? account;
      if (kIsWeb) {
        // Preferred web flow: attempt a silent sign-in, then fall back to an interactive popup.
        account = await googleSignIn.signInSilently();
        account ??= await googleSignIn.signIn();
      } else {
        // On Android, explicitly sign out/disconnect to force the account chooser UI
        if (Platform.isAndroid) {
          try { await googleSignIn.signOut(); } catch (_) {}
          try { await googleSignIn.disconnect(); } catch (_) {}
        }
        account = await googleSignIn.signIn();
      }
      if (account == null) {
        return {'success': false, 'message': 'Google sign-in was cancelled'};
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null) {
        return {'success': false, 'message': 'Failed to obtain Google ID token'};
      }

      final Map<String, dynamic> payload = {
        "token": idToken,
        "termsAccepted": termsAccepted,
      };
      if (name != null && name.isNotEmpty) {
        payload["name"] = name;
      }
      if (country != null && country.isNotEmpty) {
        payload["country"] = country;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/users/auth/google-signup'),
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode(payload),
      );

      return await _handleSocialResponse(response, fallbackEmail: account.email, fallbackName: account.displayName);
    } catch (e) {
      _logger.e('Google sign-in error: $e');
      return {'success': false, 'message': 'Google sign-in failed. Please try again.'};
    }
  }

  // (Facebook sign-in removed)

  // Social login - Apple
  Future<Map<String, dynamic>> signInWithApple({bool termsAccepted = true, String? name, String? country}) async {
    try {
      if (!termsAccepted) {
        return {'success': false, 'message': 'You must accept the Terms and Conditions to continue.'};
      }

      final AuthorizationCredentialAppleID credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        // On Web and Android you MUST provide these options (Android uses web flow)
        webAuthenticationOptions: (kIsWeb || Platform.isAndroid)
            ? WebAuthenticationOptions(
          clientId: _appleClientId,
          redirectUri: Uri.parse(_appleRedirectUri),
        )
            : null,
      );

      // Apple only returns name/email on the very first auth. Capture and forward if present.
      final String combinedAppleName = [credential.givenName, credential.familyName]
          .where((p) => p != null && p!.trim().isNotEmpty)
          .map((p) => p!.trim())
          .join(' ');
      final String? appleEmail = (credential.email != null && credential.email!.trim().isNotEmpty)
          ? credential.email!.trim()
          : null;

      final String? idToken = credential.identityToken;
      if (idToken == null) {
        return {'success': false, 'message': 'Failed to obtain Apple ID token'};
      }

      final Map<String, dynamic> payload = {
        "idToken": idToken,
        "termsAccepted": termsAccepted,
      };
      // Prefer Apple's provided values when available on first auth
      if (combinedAppleName.isNotEmpty) {
        payload["name"] = combinedAppleName;
      } else if (name != null && name.isNotEmpty) {
        payload["name"] = name; // optional FE-provided fallback
      }
      if (appleEmail != null && appleEmail.isNotEmpty) {
        payload["email"] = appleEmail;
      }
      if (country != null && country.isNotEmpty) {
        payload["country"] = country;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/users/auth/apple-signup'),
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode(payload),
      );

      // Log the final request URL for debugging route mismatches
      _logger.i('Apple sign-in request url: ${response.request?.url}');

      final fallbackName = combinedAppleName;
      return await _handleSocialResponse(response, fallbackEmail: appleEmail, fallbackName: fallbackName.isEmpty ? null : fallbackName);
    } catch (e) {
      _logger.e('Apple sign-in error: $e');
      return {'success': false, 'message': 'Apple sign-in failed. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> _handleSocialResponse(http.Response response, {String? fallbackEmail, String? fallbackName}) async {
    try {
      _logger.i('Social login response status: ${response.statusCode}');
      _logger.i('Social login request url: ${response.request?.url}');
      _logger.i('Social login response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String? token = data['token'];
        final dynamic user = data['user'];
        final String? userId = user?['id']?.toString() ?? data['userId']?.toString();
        // Prefer backend email; otherwise use provider fallback; otherwise use any previously stored email
        String? email = user?['email'] ?? data['email'] ?? fallbackEmail;
        if (email == null || email.isEmpty) {
          try {
            final storedEmail = await _authManager.getUserEmail();
            if (storedEmail != null && storedEmail.isNotEmpty) {
              email = storedEmail;
            }
          } catch (_) {}
        }
        final String? name = user?['name'] ?? data['name'] ?? fallbackName;
        final String? country = user?['country'] ?? data['country'];

        // Check for admin access from screens array or user role
        final List<dynamic> screens = data['screens'] ?? [];
        final String? userRole = user?['role'];
        final bool hasAdminAccess = screens.contains('AdminPanel') || userRole == 'admin';

        // Map country to currency if provided
        Map<String, String> currencyInfo = {'currency': 'USD', 'symbol': '\$'};
        if (country != null && country.isNotEmpty) {
          currencyInfo = CurrencyService.getCurrencyForCountry(country);
        }
        final String? currency = data['user']?['currency'] ?? data['currency'] ?? currencyInfo['currency'];
        final String? currencySymbol = data['user']?['currencySymbol'] ?? data['currencySymbol'] ?? currencyInfo['symbol'];

        if (token != null && userId != null && email != null) {
          await _authManager.saveAuthData(
            token: token,
            userId: userId,
            email: email,
            name: name,
            country: country,
            hasAdminAccess: hasAdminAccess,
            canUpdatePassword: data['canUpdatePassword'] ?? data['canupdatepassword'],
          );

          if (!kIsWeb) {
            FCMService.setCurrentUserId(userId);
            await NotificationService.onUserLogin(userId);
          }

          return {
            'success': true,
            'userId': userId,
            'token': token,
            'hasAdminAccess': hasAdminAccess,
            'currency': currency,
            'currencySymbol': currencySymbol,
            'country': country,
            'name': name,
            // Normalize flag for social flows
            'canUpdatePassword': data['canUpdatePassword'] ?? data['canupdatepassword'],
            'needsProfile': data['needsProfile'] ?? false, // Default to false if not provided
          };
        }

        return {'success': false, 'message': 'Invalid response from server'};
      } else {
        String message = 'Social login failed';
        try {
          final body = json.decode(response.body);
          message = body['message'] ?? body['error'] ?? message;
        } catch (_) {}
        return {'success': false, 'message': message};
      }
    } catch (e) {
      _logger.e('Error handling social response: $e');
      return {'success': false, 'message': 'Social login failed'};
    }
  }
}

