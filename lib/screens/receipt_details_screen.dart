import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/setting_provider.dart';
import '../providers/user_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'full_image_view_screen.dart';
import 'pdf_viewer_screen.dart';
import 'edit_category_screen.dart';

class ReceiptDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> receipt;
  final String imageUrl;
  final String userId;
  final String imageId;
  final bool isNewReceipt;
  final bool isPdf;
  final bool isManualReceipt;

  const ReceiptDetailsScreen({
    super.key,
    required this.receipt,
    required this.imageUrl,
    required this.userId,
    required this.imageId,
    this.isNewReceipt = false,
    this.isPdf = false,
    this.isManualReceipt = false,
  });

  @override
  State<ReceiptDetailsScreen> createState() => _ReceiptDetailsScreenState();
}

class _ReceiptDetailsScreenState extends State<ReceiptDetailsScreen> {
  bool _isDeleting = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = false;

  // Text editing controllers for inline editing
  late TextEditingController _merchantController;
  late TextEditingController _dateController;
  final TextEditingController _timeController = TextEditingController();
  late TextEditingController _amountController;
  late TextEditingController _categoryController;

  // Editing state flags
  bool _editingMerchant = false;
  bool _editingDate = false;
  bool _editingAmount = false;
  bool _editingCategory = false;

  bool _isNewReceipt = false;
  bool _isManualReceipt = false;

  @override
  void initState() {
    super.initState();

    _isNewReceipt = widget.isNewReceipt;
    _isManualReceipt = widget.isManualReceipt;

    debugPrint('ReceiptDetails - Init: isNew=$_isNewReceipt, isManual=$_isManualReceipt');
    debugPrint('ReceiptDetails - Receipt data: ${widget.receipt}');

    // Fetch categories for dropdown
    _fetchCategories();

    // Method to clean merchant name
    String cleanMerchant(String? merchant) {
      if (merchant == null || merchant.isEmpty) {
        return _isManualReceipt ? '' : 'Unknown Merchant';
      }
      return merchant.trim();
    }

    // Initialize controllers with cleaned or default values
    _merchantController = TextEditingController(
      text: cleanMerchant(widget.receipt['merchant']),
    );

    _dateController = TextEditingController(
      text: widget.receipt['receiptDate'] ?? '',
    );

    _amountController = TextEditingController(
      text: widget.receipt['amount']?.toString() ?? (_isManualReceipt ? '' : '0.00'),
    );

    _categoryController = TextEditingController(
      text: widget.receipt['category'] ?? (_isManualReceipt ? '' : 'Uncategorized'),
    );

    // For manual receipts, start in editing mode for all fields
    if (_isManualReceipt && _isNewReceipt) {
      _editingMerchant = true;
      _editingDate = true;
      _editingAmount = true;
      _editingCategory = true;
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

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
        _isLoadingCategories = false;
      });
    }
  }

  void _showCategoryDropdown() {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categories are still loading...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Category',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7E5EFD),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final categoryName = category['name'];
                    final isSelected = _categoryController.text == categoryName;

                    return ListTile(
                      title: Text(
                        categoryName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF7E5EFD) : Colors.black,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Color(0xFF7E5EFD))
                          : null,
                      onTap: () {
                        setState(() {
                          _categoryController.text = categoryName;
                        });
                        Navigator.pop(context);
                      },
                      selected: isSelected,
                      selectedTileColor: const Color(0xFFE8E6FF),
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

  String? _formatDate(String date) {
    if (date.isEmpty || date.toLowerCase() == 'no date') return null;

    final formats = [
      DateFormat('MM-dd-yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('dd-MM-yyyy'),
    ];

    for (final format in formats) {
      try {
        final parsedDate = format.parse(date);
        return DateFormat('MM-dd-yyyy').format(parsedDate);
      } catch (_) {
        // Continue to the next format if parsing fails
      }
    }

    debugPrint('Error parsing date: Unsupported format for "$date"');
    return null;
  }

  Future<void> _saveReceiptToBackend() async {
    debugPrint('ReceiptDetails - Starting save process');

    // Validate required fields for manual receipts
    if (_isManualReceipt) {
      if (_merchantController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a merchant name'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_amountController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter an amount'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_dateController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a date'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    // Format the date
    final rawDate = _dateController.text.trim();
    final formattedDate = _formatDate(rawDate);

    if (formattedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid date format. Please use MM-dd-yyyy format'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

    final imageId = widget.imageId.isNotEmpty
        ? widget.imageId
        : (_isManualReceipt
        ? 'manual_${DateTime.now().millisecondsSinceEpoch}_${widget.userId}'
        : '');

    final imageUrlToSave = _isManualReceipt
        ? 'https://via.placeholder.com/300x400/E8E6FF/7E5EFD?text=Manual+Receipt'
        : widget.imageUrl;

    final receiptData = {
      'userId': widget.userId,
      'merchant': _merchantController.text.trim(),
      'receiptDate': formattedDate,
      'amount': _amountController.text.trim().replaceAll(RegExp(r'[^\d.]'), ''),
      'category': _categoryController.text.trim().isEmpty
          ? 'Uncategorized'
          : _categoryController.text.trim(),
      'imageUrl': imageUrlToSave,
      'imageId': imageId,
      'isManual': _isManualReceipt,
      'isSaved': true,
    };

    debugPrint('ReceiptDetails - Saving receipt data: $receiptData');

    Uri url;
    http.Response response;

    try {
      if (_isNewReceipt) {
        url = Uri.parse('https://manage-receipt-backend-bnl1.onrender.com/api/receipts/${widget.userId}');
        debugPrint('ReceiptDetails - Saving new receipt to: $url');

        response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(receiptData),
        );
      } else {
        url = Uri.parse('https://manage-receipt-backend-bnl1.onrender.com/api/receipts/update');
        debugPrint('ReceiptDetails - Updating existing receipt at: $url');

        response = await http.put(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'id': widget.receipt['id'],
            ...receiptData,
          }),
        );
      }

      debugPrint('ReceiptDetails - Save response: ${response.statusCode}');
      debugPrint('ReceiptDetails - Save response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final successMsg = _isNewReceipt
            ? (_isManualReceipt ? 'Manual receipt saved!' : 'Receipt saved!')
            : 'Receipt updated!';

        setState(() {
          _isNewReceipt = false;
          _isSaving = false;
          if (_isManualReceipt) {
            _editingMerchant = false;
            _editingDate = false;
            _editingAmount = false;
            _editingCategory = false;
          }
        });

        debugPrint('ReceiptDetails - Save successful, returning true');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMsg),
              backgroundColor: const Color(0xFF7E5EFD),
            ),
          );

          Navigator.pop(context, true);
        }
      } else {
        debugPrint('ReceiptDetails - Save failed: ${response.body}');
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
      debugPrint('ReceiptDetails - Error saving receipt: $e');
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
                Navigator.pop(context);

                setState(() {
                  _isDeleting = true;
                });

                try {
                  final deleteImageId = widget.imageId.isNotEmpty
                      ? widget.imageId
                      : widget.receipt['imageId']?.toString() ?? '';

                  debugPrint('ReceiptDetails - Deleting receipt with imageId: $deleteImageId');

                  final url = Uri.parse(
                      'https://manage-receipt-backend-bnl1.onrender.com/api/receipts/$deleteImageId');
                  final response = await http.delete(url);

                  debugPrint('ReceiptDetails - Delete response: ${response.statusCode}');

                  if (response.statusCode == 200) {
                    debugPrint('ReceiptDetails - Delete successful, returning false');

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Receipt deleted successfully'),
                          backgroundColor: Color(0xFF7E5EFD),
                        ),
                      );

                      Navigator.pop(context, false);
                    }
                  } else {
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
                  debugPrint('ReceiptDetails - Delete error: $e');
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
        builder: (_) => FullImageViewScreen(imageUrl: widget.imageUrl),
      ),
    );
  }

  String get _currentPdfUrl {
    if (_isNewReceipt) {
      return widget.receipt['pdfUrl']?.toString().trim() ?? '';
    } else {
      return widget.receipt['imageLink']?.toString().trim() ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isNewReceipt) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(_isManualReceipt ? 'Discard Manual Receipt?' : 'Discard Receipt?'),
              content: Text(
                _isManualReceipt
                    ? 'This manual receipt has not been saved. Are you sure you want to discard it?'
                    : 'This receipt has not been saved. Are you sure you want to discard it?',
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

          if (shouldDiscard == true) {
            debugPrint('ReceiptDetails - Discarding new receipt, returning false');
            Navigator.pop(context, false);
            return false;
          }
          return false;
        }

        return true;
      },
      child: Scaffold(
        body: _isDeleting
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
    final userProvider = Provider.of<UserProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    final currencySymbol = userProvider.currencySymbol ?? settingsProvider.currencySymbol;

    return SafeArea(
      bottom: true,
      child: Column(
        children: [
          // Purple header with logo
          Container(
            color: const Color(0xFF7E5EFD),
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (_isNewReceipt) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(_isManualReceipt ? 'Discard Manual Receipt?' : 'Discard Receipt?'),
                          content: Text(
                            _isManualReceipt
                                ? 'This manual receipt has not been saved. Are you sure you want to discard it?'
                                : 'This receipt has not been saved. Are you sure you want to discard it?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                debugPrint('ReceiptDetails - Discarding via back button, returning false');
                                Navigator.pop(context, false);
                              },
                              child: const Text('Discard',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _isManualReceipt ? 'Manual Receipt' : 'Receipt Details',
                      style: const TextStyle(
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
                  // Receipt image or PDF preview with zoom/open button (only for non-manual receipts)
                  if (!_isManualReceipt) ...[
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            if (widget.isPdf) {
                              final url = _currentPdfUrl;
                              if (url.isEmpty ||
                                  (!url.startsWith('http://') && !url.startsWith('https://'))) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invalid PDF URL')),
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PdfViewerScreen(pdfUrl: url),
                                ),
                              );
                            } else {
                              _openZoom(context);
                            }
                          },
                          child: widget.isPdf
                              ? Container(
                            width: double.infinity,
                            height: 300,
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(
                                Icons.picture_as_pdf,
                                size: 100,
                                color: Colors.red[400],
                              ),
                            ),
                          )
                              : Image.network(
                            widget.imageUrl,
                            width: double.infinity,
                            height: 300,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  height: 300,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(Icons.broken_image,
                                        size: 50, color: Colors.grey),
                                  ),
                                ),
                          ),
                        ),
                        if (!widget.isPdf)
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
                                onPressed: () => _openZoom(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ] else ...[
                    // Manual receipt indicator
                    Container(
                      width: double.infinity,
                      height: 200,
                      color: const Color(0xFFE8E6FF),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_note,
                              size: 80,
                              color: Color(0xFF7E5EFD),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Manual Receipt',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7E5EFD),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Fill in the details below',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF7E5EFD),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Receipt details section
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          _isManualReceipt ? 'Receipt Information' : 'Receipt Details',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isManualReceipt
                              ? 'Enter your receipt details manually.'
                              : 'All receipt information in one organized view.',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
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
                                isRequired: _isManualReceipt,
                              ),

                              // Date field
                              _buildEditableField(
                                'Date (MM-dd-yyyy)',
                                _dateController,
                                _editingDate,
                                    () => setState(
                                        () => _editingDate = !_editingDate),
                                isRequired: _isManualReceipt,
                              ),

                              // Amount field with decimal support and currency symbol
                              _buildEditableField(
                                'Amount',
                                _amountController,
                                _editingAmount,
                                    () => setState(
                                        () => _editingAmount = !_editingAmount),
                                prefix: _editingAmount ? '$currencySymbol ' : null,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                                formatText: (text) => '$currencySymbol $text',
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]')),
                                ],
                                isRequired: _isManualReceipt,
                              ),

                              // Category field with dropdown for manual receipts
                              _buildCategoryField(),
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
                                : Text(
                              _isManualReceipt ? 'Save Manual Receipt' : 'Save',
                              style: const TextStyle(
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

                        const SizedBox(height: 16),
                      ],
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

  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (_isManualReceipt)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _isManualReceipt ? _showCategoryDropdown : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _categoryController.text.isEmpty && _isManualReceipt
                              ? 'Tap to select category'
                              : _categoryController.text,
                          style: TextStyle(
                            fontSize: 16,
                            color: _categoryController.text.isEmpty && _isManualReceipt
                                ? Colors.grey.shade500
                                : Colors.black,
                            fontStyle: _categoryController.text.isEmpty && _isManualReceipt
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                      if (_isManualReceipt) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_drop_down,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (!_isManualReceipt)
              IconButton(
                icon: Icon(
                  _editingCategory ? Icons.check : Icons.edit,
                  size: 20,
                  color: const Color(0xFF7E5EFD),
                ),
                onPressed: () => setState(() => _editingCategory = !_editingCategory),
              ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 8),
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
        List<TextInputFormatter>? inputFormatters,
        bool isRequired = false,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
          ],
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
                  hintText: isRequired ? 'Required field' : null,
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                onTap: onTap,
                readOnly: onTap != null,
              )
                  : Text(
                formatText != null
                    ? formatText(controller.text)
                    : controller.text.isEmpty && isRequired
                    ? 'Tap to enter ${label.toLowerCase()}'
                    : controller.text,
                style: TextStyle(
                  fontSize: 16,
                  color: controller.text.isEmpty && isRequired
                      ? Colors.grey.shade500
                      : Colors.black,
                  fontStyle: controller.text.isEmpty && isRequired
                      ? FontStyle.italic
                      : FontStyle.normal,
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
}