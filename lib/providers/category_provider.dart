import 'package:flutter/material.dart';

class CategoryProvider with ChangeNotifier {
  // Hardcoded categories - no API calls
  final List<Map<String, dynamic>> _categories = [
    {'categoryId': 1, 'name': 'Meal'},
    {'categoryId': 2, 'name': 'Education'},
    {'categoryId': 3, 'name': 'Medical'},
    {'categoryId': 4, 'name': 'Shopping'},
    {'categoryId': 5, 'name': 'Travel'},
    {'categoryId': 6, 'name': 'Rent'},
    {'categoryId': 7, 'name': 'Other'},
  ];

  bool _isLoading = false;
  String _error = '';

  List<Map<String, dynamic>> get categories => _categories;
  bool get isLoading => _isLoading;
  String get error => _error;

  // Return hardcoded categories immediately
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    // Simulate a small delay for UI consistency
    await Future.delayed(const Duration(milliseconds: 100));

    _isLoading = false;
    notifyListeners();
    return _categories;
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