import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
// Removed unused import for receipt_provider.dart
import '../providers/setting_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ReceiptDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> receipt;
  final String imageUrl;
  final String userId;
  final String imageId;
  final bool isNewReceipt;

  const ReceiptDetailsScreen({
    super.key,
    required this.receipt,
    required this.imageUrl,
    required this.userId,
    required this.imageId,
    this.isNewReceipt = false,
  });

  @override
  State<ReceiptDetailsScreen> createState() => _ReceiptDetailsScreenState();
}

class _ReceiptDetailsScreenState extends State<ReceiptDetailsScreen> {
  bool _isLoadingCategories = true;
  bool _isDeleting = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  String _selectedCategoryName = 'Uncategorized';

  // Text editing controllers for inline editing
  late TextEditingController _merchantController;
  late TextEditingController _dateController;
  final TextEditingController _timeController = TextEditingController();
  late TextEditingController _amountController;
  final TextEditingController _categoryController = TextEditingController();
  TextEditingController _customCategoryController = TextEditingController();

  // Editing state flags
  bool _editingMerchant = false;
  bool _editingDate = false;
  bool _editingAmount = false;
  bool _editingCategory = false;

  bool _isNewReceipt = false;

  @override
  void initState() {
    super.initState();

    _isNewReceipt = widget.isNewReceipt;

    // Method to clean merchant name
    String cleanMerchant(String? merchant) {
      if (merchant == null || merchant.isEmpty) {
        return 'Unknown Merchant';
      }
      return merchant.trim();
    }

    // Initialize controllers with cleaned or default values
    _merchantController = TextEditingController(
      text: cleanMerchant(widget.receipt['merchant']),
    );

    // Use the receiptDate directly if it's already in the correct format
    _dateController = TextEditingController(
      text: widget.receipt['receiptDate'] ?? '',
    );

    _amountController = TextEditingController(
      text: widget.receipt['amount']?.toString() ?? '0.00',
    );
    _customCategoryController = TextEditingController();

    // Initialize category controller
    _categoryController.text = widget.receipt['category'] ?? 'Uncategorized';
    _selectedCategoryName = _categoryController.text;

    // Fetch categories
    fetchCategories();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> fetchCategories() async {
    final url = Uri.parse(
      'https://manage-receipt-backend-bnl1.onrender.com/api/categories/get-all-categories',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> categoryList = json.decode(response.body);
        List<Map<String, dynamic>> fetchedCategories =
        List<Map<String, dynamic>>.from(categoryList);

        setState(() {
          _categories = fetchedCategories;

          // Find the selected category based on categoryId or name
          if (widget.receipt['categoryId'] != null) {
            // If we have a categoryId, find the category by ID
            final categoryId =
                int.tryParse(widget.receipt['categoryId'].toString()) ?? 0;
            final matchingCategories = _categories
                .where((cat) => cat['categoryId'] == categoryId)
                .toList();

            if (matchingCategories.isNotEmpty) {
              _selectedCategoryId = categoryId;
              _selectedCategoryName = matchingCategories.first['name'];
              _categoryController.text = _selectedCategoryName;
            } else {
              // Default to "Other" if no match found
              _selectedCategoryId = 0;
              _selectedCategoryName = 'Other';
              _categoryController.text = 'Other';
            }
          } else {
            // Otherwise try to find by name
            final initialCategoryName =
                widget.receipt['category']?.toString() ?? '';
            final matchingCategories = _categories
                .where((cat) =>
            cat['name'].toString().toLowerCase() ==
                initialCategoryName.toLowerCase())
                .toList();

            if (matchingCategories.isNotEmpty) {
              _selectedCategoryId = matchingCategories.first['categoryId'];
              _selectedCategoryName = matchingCategories.first['name'];
              _categoryController.text = _selectedCategoryName;
            } else {
              // Default to "Other" if no match found
              _selectedCategoryId = 0;
              _selectedCategoryName = 'Other';
              _categoryController.text = 'Other';
            }
          }

          _isLoadingCategories = false;
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

        // Set default selected category
        _selectedCategoryId = 0;
        _selectedCategoryName = 'Other';
        _categoryController.text = 'Other';
        _isLoadingCategories = false;
      });
    }
  }

  String? _formatDate(String date) {
    if (date.isEmpty || date.toLowerCase() == 'no date') return null;

    // Define supported date formats
    final formats = [
      DateFormat('MM-dd-yyyy'), // Format: 05-01-2025
      DateFormat('yyyy-MM-dd'), // Format: 2025-05-01
      DateFormat('MM/dd/yyyy'), // Format: 05/01/2025
      DateFormat('dd-MM-yyyy'), // Format: 01-05-2025
    ];

    for (final format in formats) {
      try {
        final parsedDate = format.parse(date);
        return DateFormat('MM-dd-yyyy')
            .format(parsedDate); // Convert to standard format
      } catch (_) {
        // Continue to the next format if parsing fails
      }
    }

    debugPrint('Error parsing date: Unsupported format for "$date"');
    return null; // Return null if no format matches
  }

  Future<void> _saveReceiptToBackend() async {
    setState(() {
      _isSaving = true;
    });

    // Get the categoryId from the selected category
    final customCategory = _selectedCategoryName == 'Other'
        ? _customCategoryController.text.trim()
        : null;

    // Format the date
    final rawDate = _dateController.text.trim();
    final formattedDate = _formatDate(rawDate);

    if (formattedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid date format'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

    // Prepare receipt data
    final receiptData = {
      'userId': widget.userId,
      'merchant': _merchantController.text.trim(),
      'receiptDate': formattedDate, // Use the correctly formatted date
      'amount': _amountController.text.trim().replaceAll(RegExp(r'[^\d.]'), ''),
      'categoryId': _selectedCategoryId,
      'category': _selectedCategoryName, // Include both categoryId and name
      'customCategory': customCategory,
      'imageUrl': widget.imageUrl,
      'imageId': widget.imageId,
    };

    Uri url;
    http.Response response;

    try {
      if (_isNewReceipt) {
        // Save new receipt
        url =
            Uri.parse('https://manage-receipt-backend-bnl1.onrender.com/api/receipts/${widget.userId}');
        response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(receiptData),
        );
      } else {
        // Update existing receipt
        url = Uri.parse('https://manage-receipt-backend-bnl1.onrender.com/api/receipts/update');
        response = await http.put(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'id': widget.receipt['id'],
            ...receiptData,
          }),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final successMsg =
        _isNewReceipt ? 'Receipt saved!' : 'Receipt updated!';

        setState(() {
          _isNewReceipt = false;
          _isSaving = false;
        });

        if (mounted) {
          // Pop and return true to indicate the receipt was saved
          Navigator.pop(context, true);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMsg),
              backgroundColor: const Color(0xFF7E5EFD),
            ),
          );
        }
      } else {
        debugPrint('Save/update failed: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error while saving receipt'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSaving = false;
        });
      }
    } catch (e) {
      debugPrint('Error saving receipt: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while saving the receipt'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _deleteReceipt(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Receipt'),
          content: const Text(
            'Are you sure you want to delete this receipt? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close the dialog

                setState(() {
                  _isDeleting = true;
                });

                try {
                  // Use the direct DELETE endpoint with the imageId
                  final url = Uri.parse(
                      'https://manage-receipt-backend-bnl1.onrender.com/api/receipts/${widget.imageId}');
                  final response = await http.delete(url);

                  if (response.statusCode == 200) {
                    // Successfully deleted
                    if (mounted) {
                      // Pop and return false to indicate the receipt was deleted
                      Navigator.pop(context, false);

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Receipt deleted successfully'),
                          backgroundColor: Color(0xFF7E5EFD),
                        ),
                      );
                    }
                  } else {
                    // Error deleting receipt
                    if (mounted) {
                      setState(() {
                        _isDeleting = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Error deleting receipt: ${response.statusCode}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  // Exception occurred
                  if (mounted) {
                    setState(() {
                      _isDeleting = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _openZoom(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Receipt Image'),
            backgroundColor: const Color(0xFF7E5EFD),
          ),
          body: PhotoView(
            imageProvider: NetworkImage(widget.imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            backgroundDecoration: const BoxDecoration(
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Add WillPopScope to handle back button press
      onWillPop: () async {
        // If this is a new receipt and user tries to go back without saving,
        // show a confirmation dialog
        if (_isNewReceipt) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Discard Receipt?'),
              content: const Text(
                'This receipt has not been saved. Are you sure you want to discard it?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );

          // If user confirms discard, return true to allow navigation
          // Otherwise, return false to prevent navigation
          return shouldDiscard ?? false;
        }

        // For existing receipts, just return true to allow navigation
        return true;
      },
      child: Scaffold(
        body: _isLoadingCategories
            ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF7E5EFD)))
            : _isDeleting
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF7E5EFD)),
              SizedBox(height: 16),
              Text(
                'Deleting receipt...',
                style: TextStyle(
                  color: Color(0xFF7E5EFD),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        )
            : _buildMainView(),
      ),
    );
  }

  Widget _buildMainView() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    return Column(
      children: [
        // Purple header with logo
        Container(
          color: const Color(0xFF7E5EFD),
          padding: const EdgeInsets.only(top: 40, bottom: 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  // If this is a new receipt, show confirmation dialog
                  if (_isNewReceipt) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Discard Receipt?'),
                        content: const Text(
                          'This receipt has not been saved. Are you sure you want to discard it?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context); // Close dialog
                              Navigator.pop(context,
                                  false); // Return to previous screen with false
                            },
                            child: const Text('Discard',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // For existing receipts, just go back
                    Navigator.pop(context);
                  }
                },
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    '',
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

        // Content area
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Receipt image with zoom button
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _openZoom(context), // Allow zooming on tap
                      child: Image.network(
                        widget
                            .imageUrl, // Use the imageUrl passed from the backend
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 300,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.broken_image,
                                size: 50, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.zoom_out_map,
                              color: Colors.white),
                          onPressed: () => _openZoom(context), // Open zoom view
                        ),
                      ),
                    ),
                  ],
                ),

                // Receipt details section
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text(
                        'Receipt Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All receipt information in one organized view.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Editable fields container
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E6FF),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Merchant field
                            _buildEditableField(
                              'Merchant',
                              _merchantController,
                              _editingMerchant,
                                  () => setState(
                                      () => _editingMerchant = !_editingMerchant),
                            ),

                            // Date field
                            _buildEditableField(
                              'Date',
                              _dateController,
                              _editingDate,
                                  () =>
                                  setState(() => _editingDate = !_editingDate),
                            ),

                            // Amount field
                            _buildEditableField(
                              'Amount',
                              _amountController,
                              _editingAmount,
                                  () => setState(
                                      () => _editingAmount = !_editingAmount),
                              prefix: _editingAmount ? currencySymbol : null,
                              keyboardType: TextInputType.number,
                              formatText: (text) => '$currencySymbol$text',
                            ),

                            // Category field
                            _buildEditableField(
                              'Category',
                              _categoryController,
                              _editingCategory,
                                  () => setState(
                                      () => _editingCategory = !_editingCategory),
                              onTap:
                              _editingCategory ? _showCategoryPicker : null,
                            ),

                            // Custom category field (only shown when "Other" is selected)
                            if (_selectedCategoryName == 'Other') ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: _customCategoryController,
                                decoration: const InputDecoration(
                                  labelText: 'Custom Category',
                                  hintText: 'Enter custom category name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveReceiptToBackend,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E5EFD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSaving
                              ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Saving...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                              : const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Delete button (only for existing receipts)
                      if (!widget.isNewReceipt) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: _isDeleting
                                ? null
                                : () => _deleteReceipt(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Delete Receipt',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField(
      String label,
      TextEditingController controller,
      bool isEditing,
      VoidCallback onEditToggle, {
        String? prefix,
        TextInputType? keyboardType,
        String Function(String)? formatText,
        VoidCallback? onTap,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: isEditing
                  ? TextField(
                controller: controller,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 0),
                  isDense: true,
                  border: InputBorder.none,
                  prefixText: prefix,
                ),
                keyboardType: keyboardType,
                onTap: onTap,
                readOnly: onTap != null,
              )
                  : Text(
                formatText != null
                    ? formatText(controller.text)
                    : controller.text,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                isEditing ? Icons.check : Icons.edit,
                size: 20,
                color: const Color(0xFF7E5EFD),
              ),
              onPressed: onEditToggle,
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Category',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return ListTile(
                      title: Text(category['name']),
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = category['categoryId'];
                          _selectedCategoryName = category['name'];
                          _categoryController.text = category['name'];
                          _editingCategory = false;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}