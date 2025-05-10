import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';

class EditCategoryScreen extends StatefulWidget {
  final String initialValue;

  const EditCategoryScreen({
    super.key,
    required this.initialValue,
  });

  @override
  State<EditCategoryScreen> createState() => _EditCategoryScreenState();
}

class _EditCategoryScreenState extends State<EditCategoryScreen> {
  List<Map<String, dynamic>> _categories = [];
  List<int> _selectedCategoryIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the CategoryProvider to fetch categories
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final categories = await categoryProvider.fetchCategories();

      setState(() {
        _categories = categories;

        // If there's an initial value, try to find and select it
        if (widget.initialValue.isNotEmpty) {
          final matchingCategories = _categories.where(
                  (cat) => cat['name'].toString().toLowerCase() == widget.initialValue.toLowerCase()
          ).toList();

          if (matchingCategories.isNotEmpty) {
            // Safely convert categoryId to int
            final categoryId = matchingCategories.first['categoryId'];
            if (categoryId != null) {
              int? id;
              if (categoryId is int) {
                id = categoryId;
              } else if (categoryId is String) {
                id = int.tryParse(categoryId);
              }

              if (id != null) {
                _selectedCategoryIds = [id];
              }
            }
          }
        }

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');

      // Fallback to hardcoded categories if API fails
      setState(() {
        _categories = [
          {'categoryId': 1, 'name': 'Meal'},
          {'categoryId': 2, 'name': 'Education'},
          {'categoryId': 3, 'name': 'Medical'},
          {'categoryId': 4, 'name': 'Shopping'},
          {'categoryId': 5, 'name': 'Travel'},
          {'categoryId': 6, 'name': 'Rent'},
          {'categoryId': 0, 'name': 'Other'},
        ];

        // If there's an initial value, try to find and select it
        if (widget.initialValue.isNotEmpty) {
          final matchingCategories = _categories.where(
                  (cat) => cat['name'].toString().toLowerCase() == widget.initialValue.toLowerCase()
          ).toList();

          if (matchingCategories.isNotEmpty) {
            _selectedCategoryIds = [matchingCategories.first['categoryId']];
          }
        }

        _isLoading = false;
      });
    }
  }

  void _toggleCategory(int categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Purple header with back button and logo
          Container(
            color: const Color(0xFF7E5EFD),
            padding: const EdgeInsets.only(top: 40, bottom: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Categories',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/logo.png',
                      width: 30,
                      height: 30,
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          'MR',
                          style: TextStyle(
                            color: Color(0xFF7E5EFD),
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // White content area
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  const Text(
                    'Select Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'You can select multiple categories',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Category list with checkboxes
                  if (_isLoading)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                        ),
                      ),
                    )
                  else
                    _buildCategoryList(),

                  // Save button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, top: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          // Get selected category names
                          final selectedCategories = _categories
                              .where((cat) => _selectedCategoryIds.contains(cat['categoryId']))
                              .toList();

                          // Return both category names and IDs
                          Navigator.pop(context, {
                            'names': selectedCategories.map((cat) => cat['name']).toList(),
                            'categoryIds': _selectedCategoryIds,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E5EFD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return Expanded(
      child: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final categoryId = category['categoryId'];
          final isSelected = _selectedCategoryIds.contains(categoryId);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleCategory(categoryId),
              activeColor: const Color(0xFF7E5EFD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            title: Text(
              category['name'],
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF7E5EFD) : Colors.black,
              ),
            ),
            onTap: () => _toggleCategory(categoryId),
          );
        },
      ),
    );
  }
}