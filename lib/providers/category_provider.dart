import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CategoryProvider with ChangeNotifier {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  String _error = '';

  List<Map<String, dynamic>> get categories => _categories;
  bool get isLoading => _isLoading;
  String get error => _error;

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Fixed URL - using the render.com URL
      final url = Uri.parse('https://manage-receipt-backend-bnl1.onrender.com/api/categories/get-all-categories');

      final response = await http.get(url).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('The connection has timed out, please try again!');
        },
      );

      debugPrint('Category API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        // Process the data to ensure all categoryId values are integers
        // and explicitly cast each map to Map<String, dynamic>
        final List<Map<String, dynamic>> processedData = [];

        for (var item in data) {
          // Ensure item is Map<String, dynamic>
          final Map<String, dynamic> typedItem = Map<String, dynamic>.from(item);

          var categoryId = typedItem['categoryId'];

          // Convert categoryId to int if it's a string or null
          if (categoryId == null) {
            categoryId = 0; // Default to 0 if null
          } else if (categoryId is String) {
            categoryId = int.tryParse(categoryId) ?? 0;
          }

          typedItem['categoryId'] = categoryId;
          processedData.add(typedItem);
        }

        // Ensure each category has a unique ID
        final uniqueCategories = <Map<String, dynamic>>[];
        final seenIds = <int>{};

        for (var category in processedData) {
          final id = category['categoryId'];
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            uniqueCategories.add(category);
          }
        }

        _categories = uniqueCategories;
        _isLoading = false;
        _error = '';
        notifyListeners();
        return _categories;
      } else {
        debugPrint('Failed to load categories: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();

      // Fallback to hardcoded categories
      _categories = [
        {'categoryId': 1, 'name': 'Meal'},
        {'categoryId': 2, 'name': 'Education'},
        {'categoryId': 3, 'name': 'Medical'},
        {'categoryId': 4, 'name': 'Shopping'},
        {'categoryId': 5, 'name': 'Travel'},
        {'categoryId': 6, 'name': 'Rent'},
        {'categoryId': 0, 'name': 'Other'},
      ];

      return _categories;
    }
  }

  // Get a category name by ID
  String getCategoryNameById(int categoryId) {
    final category = _categories.firstWhere(
          (cat) => cat['categoryId'] == categoryId,
      orElse: () => {'name': 'Unknown'} as Map<String, dynamic>,
    );
    return category['name'].toString();
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}