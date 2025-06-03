import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/receipt_provider.dart';

class EditCategoryScreen extends StatefulWidget {
  final String? initialValue;

  const EditCategoryScreen({
    Key? key,
    this.initialValue,
  }) : super(key: key);

  @override
  State<EditCategoryScreen> createState() => _EditCategoryScreenState();
}

class _EditCategoryScreenState extends State<EditCategoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];
  List<int> _selectedCategoryIds = [];
  List<String> _selectedCategoryNames = [];
  final TextEditingController _customCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCategories().then((_) {
      // Initialize selected categories if initialValue is provided
      if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
        final initialCategory = _categories.firstWhere(
              (cat) => cat['name'] == widget.initialValue,
          orElse: () => {'categoryId': 0, 'name': 'Other'},
        );

        setState(() {
          _selectedCategoryIds = [initialCategory['categoryId']];
          _selectedCategoryNames = [initialCategory['name']];
        });
      }
    });
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final url = Uri.parse(
        'https://manage-receipt-backend-bnl1.onrender.com/api/categories/get-all-categories',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> categoryList = json.decode(response.body);
        List<Map<String, dynamic>> fetchedCategories =
        List<Map<String, dynamic>>.from(categoryList);

        setState(() {
          _categories = fetchedCategories;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      setState(() {
        // Default categories if API fails
        _categories = [
          {'categoryId': 1, 'name': 'Meal'},
          {'categoryId': 2, 'name': 'Education'},
          {'categoryId': 3, 'name': 'Medical'},
          {'categoryId': 4, 'name': 'Shopping'},
          {'categoryId': 5, 'name': 'Travel'},
          {'categoryId': 6, 'name': 'Rent'},
          {'categoryId': 0, 'name': 'Other'},
        ];
        _isLoading = false;
      });
    }
  }

  void _toggleCategory(int categoryId, String categoryName) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
        _selectedCategoryNames.remove(categoryName);
      } else {
        // For single selection (like in receipt details), clear previous selections
        if (widget.initialValue != null) {
          _selectedCategoryIds = [categoryId];
          _selectedCategoryNames = [categoryName];
        } else {
          // For multi-selection (like in filters), add to existing selections
          _selectedCategoryIds.add(categoryId);
          _selectedCategoryNames.add(categoryName);
        }
      }
    });
  }

  void _applyFilter() {
    if (widget.initialValue != null) {
      // For receipt details screen, return the selected category
      Navigator.pop(context, {
        'categoryIds': _selectedCategoryIds,
        'names': _selectedCategoryNames,
      });
    } else {
      // For filters screen, update the receipt provider
      final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
      receiptProvider.updateFilter('categoryIds', _selectedCategoryIds);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        title: const Text('Select Category'),
        actions: [
          TextButton(
            onPressed: () {
              if (widget.initialValue != null) {
                Navigator.pop(context);
              } else {
                // Clear category filter
                final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
                receiptProvider.updateFilter('categoryIds', null);
                Navigator.pop(context);
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7E5EFD)))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final categoryId = category['categoryId'];
                final categoryName = category['name'];
                final isSelected = _selectedCategoryIds.contains(categoryId);

                return ListTile(
                  title: Text(categoryName),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF7E5EFD))
                      : const Icon(Icons.circle_outlined),
                  onTap: () => _toggleCategory(categoryId, categoryName),
                  selected: isSelected,
                  selectedTileColor: const Color(0xFFE8E6FF),
                );
              },
            ),
          ),
          // Custom category input (only shown when "Other" is selected)
          if (_selectedCategoryIds.contains(0))
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _customCategoryController,
                decoration: const InputDecoration(
                  labelText: 'Custom Category',
                  hintText: 'Enter custom category name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          // Apply button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _applyFilter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}