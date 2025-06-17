import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'auth_manager.dart';
import 'currency_service.dart';

class AuthService {
  final Logger _logger = Logger();
  final AuthManager _authManager = AuthManager();

  AuthService() {
    _logger.i(
        'AuthService initialized for platform: ${kIsWeb ? 'Web' : Platform.operatingSystem}');
  }

  // Regular email/password signup
  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
    required String country,
    required bool termsAccepted,
  }) async {
    try {
      _logger.i('Starting email/password signup for: $email');

      if (!termsAccepted) {
        return {
          'success': false,
          'message': 'You must accept the Terms and Conditions to sign up.'
        };
      }

      final response = await http.post(
        Uri.parse("https://manage-receipt-backend-bnl1.onrender.com/api/users/signup"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "name": name,
          "email": email,
          "password": password,
          "country": country,
          "termsAccepted": termsAccepted,
        }),
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
          );
          _logger.i('Auth data saved with country: $userCountry, currency: $userCurrency, symbol: $userCurrencySymbol');
        }

        return {
          'success': true,
          'userId': userId,
          'token': token,
          'currency': userCurrency,
          'currencySymbol': userCurrencySymbol,
          'country': userCountry,
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
        "email": email,
        "password": "REDACTED",
        "termsAccepted": termsAccepted,
      })}');

      try {
        final pingResponse = await http.get(
          Uri.parse("https://manage-receipt-backend-bnl1.onrender.com/health"),
          headers: {"Accept": "application/json"},
        ).timeout(const Duration(seconds: 5));

        _logger.i('Backend health check status: ${pingResponse.statusCode}');
      } catch (e) {
        _logger.w('Backend health check failed: $e');
      }

      final response = await http.post(
        Uri.parse("https://manage-receipt-backend-bnl1.onrender.com/api/users/login"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": email,
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
              );

              return {
                'success': true,
                'userId': userId,
                'token': token,
                'hasAdminAccess': hasAdminAccess,
                'currency': finalCurrency,
                'currencySymbol': finalCurrencySymbol,
                'country': country,
                'name': responseData['user']?['name'],
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

  // Update Password
  Future<Map<String, dynamic>> updatePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final url =
    Uri.parse('https://manage-receipt-backend-bnl1.onrender.com/api/users/update-password');
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
        Uri.parse("https://manage-receipt-backend-bnl1.onrender.com/health"),
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

  // Placeholder methods for social login
  Future<Map<String, dynamic>> signInWithGoogle(
      {bool termsAccepted = true}) async {
    return {'success': false, 'message': 'Social login is currently disabled'};
  }

  Future<Map<String, dynamic>> signInWithFacebook(
      {bool termsAccepted = true}) async {
    return {'success': false, 'message': 'Social login is currently disabled'};
  }
}
