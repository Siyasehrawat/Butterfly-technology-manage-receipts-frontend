import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';

class EditCategoryScreen extends StatefulWidget {
  final String? initialValue;

  const EditCategoryScreen({
    Key? key,
    this.initialValue,
    required String userId,
  }) : super(key: key);

  @override
  State<EditCategoryScreen> createState() => _EditCategoryScreenState();
}

class _EditCategoryScreenState extends State<EditCategoryScreen> {
  List<String> _categories = [];
  List<String> _selectedCategories = [];
  bool _isFromReceiptDetails = false;
  bool _isLoading = true;
  bool _isInitializing = true;
  String? _userId;

  // Exact fallback categories matching your API response
  static const List<String> _fallbackCategories = [
    'Books',
    'Clothing',
    'Electronics',
    'Groceries',
    'Shopping',
    'Toys',
  ];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    debugPrint('=== EditCategoryScreen Initialization Started ===');

    // First, ensure UserProvider is initialized from storage
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // If user data is not available, try to initialize from storage
    if (userProvider.userId == null || userProvider.userId!.isEmpty) {
      debugPrint('UserProvider not initialized, loading from storage...');
      try {
        await userProvider.initFromStorage();
        debugPrint('UserProvider initialized from storage');
      } catch (e) {
        debugPrint('Error initializing UserProvider from storage: $e');
      }
    }

    // Get userId after initialization
    _userId = userProvider.userId;

    debugPrint('userId from UserProvider: "$_userId"');
    debugPrint('userId isEmpty: ${_userId?.isEmpty ?? true}');
    debugPrint('initialValue: "${widget.initialValue}"');
    debugPrint('isLoggedIn: ${userProvider.isLoggedIn}');

    // Check if userId is available after initialization
    if (_userId == null || _userId!.isEmpty) {
      debugPrint('ERROR: userId is still null or empty after initialization!');
      setState(() {
        _isInitializing = false;
        _isLoading = false;
      });
      _showUserIdError();
      return;
    }

    // Check if this is being called from receipt details (single selection mode)
    _isFromReceiptDetails = widget.initialValue != null;

    // Initialize selected categories if initialValue is provided
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      setState(() {
        _selectedCategories = [widget.initialValue!];
      });
    }

    setState(() {
      _isInitializing = false;
    });

    // Load categories from API
    await _loadCategories();
  }

  void _showUserIdError() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Authentication Error'),
          content: const Text('User session not found. Please log in again.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close screen
                // Navigate to login screen
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/sign_in',
                      (route) => false,
                );
              },
              child: const Text('Login'),
            ),
          ],
        ),
      );
    }
  }

  // UPDATED: Now uses ApiService with proper headers
  Future<void> _loadCategories() async {
    if (_userId == null || _userId!.isEmpty) {
      debugPrint('Cannot load categories: userId is null or empty');
      return;
    }

    debugPrint('=== Loading Categories ===');
    debugPrint('userId being used: "$_userId"');

    setState(() {
      _isLoading = true;
    });

    try {
      // UPDATED: Using ApiService instead of direct HTTP call
      final response = await ApiService.get('/receipts/categories?userId=$_userId');

      debugPrint('Categories API Response Status: ${response.statusCode}');
      debugPrint('Categories API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Parsed API Response: $data');

        if (data['categories'] != null && data['categories'] is List) {
          List<String> fetchedCategories = List<String>.from(data['categories']);
          debugPrint('Fetched categories: $fetchedCategories');

          // Also include user categories if available
          if (data['usercategories'] != null && data['usercategories'] is List) {
            final userCategories = List<String>.from(data['usercategories']);
            debugPrint('User categories: $userCategories');

            // Merge user categories with global categories, avoiding duplicates
            for (String userCategory in userCategories) {
              if (!fetchedCategories.contains(userCategory)) {
                fetchedCategories.add(userCategory);
              }
            }
          }

          if (mounted) {
            setState(() {
              _categories = fetchedCategories;
              _isLoading = false;
            });
            debugPrint('Successfully loaded ${_categories.length} categories: $_categories');
          }
        } else {
          debugPrint('API response structure unexpected: ${data.keys}');
          // Fallback to hardcoded categories if API response is unexpected
          if (mounted) {
            setState(() {
              _categories = List.from(_fallbackCategories);
              _isLoading = false;
            });
            debugPrint('Using fallback categories due to unexpected API response structure');
          }
        }
      } else {
        debugPrint('API request failed with status: ${response.statusCode}');
        debugPrint('Error response body: ${response.body}');

        // Fallback to hardcoded categories if API fails
        if (mounted) {
          setState(() {
            _categories = List.from(_fallbackCategories);
            _isLoading = false;
          });
          debugPrint('Using fallback categories due to API error: ${response.statusCode}');

          // Show error message to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load categories (${response.statusCode}). Using default categories.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Exception loading categories: $e');
      debugPrint('Stack trace: ${StackTrace.current}');

      // Fallback to hardcoded categories on error
      if (mounted) {
        setState(() {
          _categories = List.from(_fallbackCategories);
          _isLoading = false;
        });
        debugPrint('Using fallback categories due to exception: $e');

        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleCategory(String categoryName) {
    debugPrint('Toggling category: $categoryName');
    setState(() {
      if (_isFromReceiptDetails) {
        // Single selection mode for receipt details
        if (_selectedCategories.contains(categoryName)) {
          _selectedCategories.clear();
        } else {
          _selectedCategories = [categoryName];
        }
      } else {
        // Multi-selection mode for filters
        if (_selectedCategories.contains(categoryName)) {
          _selectedCategories.remove(categoryName);
        } else {
          _selectedCategories.add(categoryName);
        }
      }
    });
    debugPrint('Selected categories: $_selectedCategories');
  }

  void _applyFilter() {
    debugPrint('Applying filter/selection');
    debugPrint('Selected categories: $_selectedCategories');
    debugPrint('Is from receipt details: $_isFromReceiptDetails');

    if (_isFromReceiptDetails) {
      // For receipt details screen, return the selected category
      if (_selectedCategories.isNotEmpty) {
        final result = {
          'name': _selectedCategories.first,
          'names': _selectedCategories,
        };
        debugPrint('Returning result for receipt details: $result');
        Navigator.pop(context, result);
      } else {
        debugPrint('No category selected, returning null');
        Navigator.pop(context);
      }
    } else {
      // For filters screen, return selected categories
      final result = {
        'names': _selectedCategories,
        'categoryIds': _selectedCategories, // For backward compatibility
      };
      debugPrint('Returning result for filters: $result');
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Show initialization loading
        if (_isInitializing) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF7E5EFD),
              foregroundColor: Colors.white,
              title: const Text('Categories'),
            ),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                  ),
                  SizedBox(height: 16),
                  Text('Initializing...'),
                ],
              ),
            ),
          );
        }

        // Check if user is logged in after initialization
        if (!userProvider.isLoggedIn || userProvider.userId == null || userProvider.userId!.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF7E5EFD),
              foregroundColor: Colors.white,
              title: const Text('Categories'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Not logged in',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Please log in to view categories',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/sign_in',
                            (route) => false,
                      );
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF7E5EFD),
            foregroundColor: Colors.white,
            title: Text(_isFromReceiptDetails ? 'Select Category' : 'Filter by Category'),
            actions: [
              TextButton(
                onPressed: () {
                  debugPrint('Clear button pressed');
                  if (_isFromReceiptDetails) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pop(context, {
                      'names': [],
                      'categoryIds': [],
                    });
                  }
                },
                child: const Text(
                  'Clear',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                ),
                SizedBox(height: 16),
                Text('Loading categories...'),
              ],
            ),
          )
              : Column(
            children: [
              // Instructions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                color: const Color(0xFFF5F5F5),
                child: Text(
                  _isFromReceiptDetails
                      ? 'Select a category for this receipt'
                      : 'Select one or more categories to filter receipts',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),

              // Categories list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadCategories,
                  color: const Color(0xFF7E5EFD),
                  child: _categories.isEmpty
                      ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No categories available',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Pull down to refresh',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final categoryName = _categories[index];
                      final isSelected = _selectedCategories.contains(categoryName);

                      return ListTile(
                        title: Text(
                          categoryName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xFF7E5EFD))
                            : const Icon(Icons.circle_outlined, color: Colors.grey),
                        onTap: () => _toggleCategory(categoryName),
                        selected: isSelected,
                        selectedTileColor: const Color(0xFFE8E6FF),
                      );
                    },
                  ),
                ),
              ),

              // Apply button
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _selectedCategories.isNotEmpty || !_isFromReceiptDetails ? _applyFilter : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E5EFD),
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isFromReceiptDetails ? 'Apply Category' : 'Apply Filter',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}