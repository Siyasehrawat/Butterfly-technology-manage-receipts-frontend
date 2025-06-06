import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/setting_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'full_image_view_screen.dart';
import 'pdf_viewer_screen.dart'; // Import the PDF viewer screen

class ReceiptDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> receipt;
  final String imageUrl;
  final String userId;
  final String imageId;
  final bool isNewReceipt;
  final bool isPdf; // New field to indicate if this receipt is a PDF

  const ReceiptDetailsScreen({
    super.key,
    required this.receipt,
    required this.imageUrl,
    required this.userId,
    required this.imageId,
    this.isNewReceipt = false,
    this.isPdf = false, // Default to false
  });

  @override
  State<ReceiptDetailsScreen> createState() => _ReceiptDetailsScreenState();
}

class _ReceiptDetailsScreenState extends State<ReceiptDetailsScreen> {
  bool _isDeleting = false;
  bool _isSaving = false;

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

    // Initialize category controller with the category from the receipt
    _categoryController = TextEditingController(
      text: widget.receipt['category'] ?? 'Uncategorized',
    );
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
      'category': _categoryController.text.trim(), // Use the category directly
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
        builder: (_) => FullImageViewScreen(imageUrl: widget.imageUrl),
      ),
    );
  }

  String get _currentPdfUrl {
    if (_isNewReceipt) {
      // Use pdfUrl while processing (before saving)
      return widget.receipt['pdfUrl']?.toString().trim() ?? '';
    } else {
      // Use imageLink after saving
      return widget.receipt['imageLink']?.toString().trim() ?? '';
    }
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
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    return SafeArea(
      bottom: true, // Ensure bottom padding for system navigation bar
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
                  // Receipt image or PDF preview with zoom/open button
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
                            // Open in-app PDF viewer
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
                                    () => setState(
                                        () => _editingDate = !_editingDate),
                              ),

                              // Amount field with decimal support
                              _buildEditableField(
                                'Amount',
                                _amountController,
                                _editingAmount,
                                    () => setState(
                                        () => _editingAmount = !_editingAmount),
                                prefix: _editingAmount ? currencySymbol : null,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                                formatText: (text) => '$currencySymbol$text',
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]')),
                                ],
                              ),

                              // Category field - now editable just like merchant and amount
                              _buildEditableField(
                                'Category',
                                _categoryController,
                                _editingCategory,
                                    () => setState(
                                        () => _editingCategory = !_editingCategory),
                              ),
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

                        // Add bottom padding to ensure content isn't covered by system navigation
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
                inputFormatters: inputFormatters,
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
}