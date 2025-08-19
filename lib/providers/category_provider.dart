import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CategoryProvider with ChangeNotifier {
  static String get baseUrl => '${dotenv.env['API_BASE_URL']}/api/receipts';

  // Exact fallback categories matching your API response
  static const List<String> _fallbackCategories = [
    'Books',
    'Clothing',
    'Electronics',
    'Groceries',
    'Shopping',
    'Toys',
  ];

  List<String> _categories = [];
  bool _isLoading = false;
  String? _error;
  bool _isUsingFallback = false;

  List<String> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUsingFallback => _isUsingFallback;

  List<String> getFallbackCategories() {
    return List.from(_fallbackCategories);
  }

  Future<List<String>> fetchCategories({required String userId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // UPDATED: Add userId as query parameter
      final uri = Uri.parse('$baseUrl/categories').replace(
        queryParameters: {'userId': userId},
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        List<String> fetchedCategories = [];

        // Handle the exact API response format you provided
        if (data['categories'] != null && data['categories'] is List) {
          fetchedCategories = List<String>.from(data['categories']);
        }

        // Also include user categories if available
        if (data['usercategories'] != null && data['usercategories'] is List) {
          final userCategories = List<String>.from(data['usercategories']);
          // Merge user categories with global categories, avoiding duplicates
          for (String userCategory in userCategories) {
            if (!fetchedCategories.contains(userCategory)) {
              fetchedCategories.add(userCategory);
            }
          }
        }

        // Always return something - fallback if API returns empty
        if (fetchedCategories.isEmpty) {
          _categories = List.from(_fallbackCategories);
          _isUsingFallback = true;
        } else {
          _categories = fetchedCategories;
          _isUsingFallback = false;
        }

        _isLoading = false;
        notifyListeners();

        return _categories;
      } else {
        // API returned an error status code, return fallback categories
        _categories = List.from(_fallbackCategories);
        _isUsingFallback = true;
        _isLoading = false;
        _error = 'Server error: ${response.statusCode}';
        notifyListeners();

        return _categories;
      }
    } catch (e) {
      // Network error or timeout, return fallback categories
      _categories = List.from(_fallbackCategories);
      _isUsingFallback = true;
      _error = e.toString();
      _isLoading = false;
      notifyListeners();

      return _categories;
    }
  }

  // Method to refresh categories
  Future<void> refreshCategories({required String userId}) async {
    await fetchCategories(userId: userId);
  }

  // Method to get immediate fallback categories without API call
  List<String> getImmediateCategories() {
    return List.from(_fallbackCategories);
  }
}
