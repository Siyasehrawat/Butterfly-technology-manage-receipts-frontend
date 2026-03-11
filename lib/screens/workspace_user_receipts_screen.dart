import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../services/workspace_service.dart';
import '../services/api_service_bypass.dart';
import '../utils/encryption_helper.dart';
import 'receipt_details_screen.dart';

class WorkspaceUserReceiptsScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String workspaceId;

  const WorkspaceUserReceiptsScreen({
    Key? key,
    required this.userId,
    required this.token,
    required this.workspaceId,
  }) : super(key: key);

  @override
  State<WorkspaceUserReceiptsScreen> createState() =>
      _WorkspaceUserReceiptsScreenState();
}

class _WorkspaceUserReceiptsScreenState
    extends State<WorkspaceUserReceiptsScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Pending', 'Approved', 'Rejected'];

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _receipts = [];

  // Submit form controllers
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Load workspace receipts using the correct endpoint
  /// 
  /// ENDPOINT: GET /api/workspace/:workspaceId/receipts?userId=:userId&status=:status&page=:page&pageSize=:pageSize
  /// 
  /// This is the ONLY way to retrieve workspace receipts (per Workspace Receipts Guide)
  /// 
  /// Response: { "success": true, "data": { "receipts": [...], "pagination": {...} } }
  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Use the correct workspace receipts endpoint (NOT getUserDashboard)
    // Endpoint: GET /api/workspace/:workspaceId/receipts
    final statusParam = _selectedFilter.toLowerCase() == 'all'
        ? 'all'
        : _selectedFilter.toLowerCase();

    final res = await WorkspaceService.listWorkspaceReceipts(
      workspaceId: widget.workspaceId,
      userId: widget.userId,
      query: {
        'status': statusParam,
        'userId': widget.userId,
        'page': '1',
        'pageSize': '50', // Load more receipts for the receipts screen
      },
      token: widget.token,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      try {
        // Handle nested response structure
        // API returns: { "success": true, "data": { "receipts": [...], "pagination": {...} } }
        // Service wraps it: { "success": true, "data": <decoded response> }
        final responseData = res['data'];
        Map<String, dynamic>? data;
        
        if (responseData is Map<String, dynamic>) {
          // Check if nested (has 'data' key)
          if (responseData.containsKey('data') && responseData['data'] is Map) {
            data = responseData['data'] as Map<String, dynamic>?;
          } else if (responseData.containsKey('receipts')) {
            // Direct structure
            data = responseData;
          }
        }
        
        // Extract receipts array
        // API format: { "id": "receipt-uuid", "merchant": "Starbucks", "amount": 45.50, "category": "Food & Dining", "date": "2025-12-17T10:30:00Z", "status": "pending", "imageLink": "encrypted-url" }
        final receiptsList = data?['receipts'] as List<dynamic>? ?? [];
        
        setState(() {
          _receipts = receiptsList.map(_normalizeReceipt).toList();
          _isLoading = false;
        });
      } catch (e) {
        debugPrint('Error parsing receipts: $e');
        setState(() {
          _error = 'Failed to parse receipts: $e';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _error = res['error']?.toString() ?? 'Failed to load receipts';
        _isLoading = false;
      });
    }
  }

  /// Normalize receipt data from API response
  /// 
  /// API Response Format (from GET /api/workspace/:workspaceId/receipts):
  /// {
  ///   "id": "receipt-uuid" or 419 (numeric),
  ///   "merchant": "Starbucks",
  ///   "amount": 45.50,
  ///   "category": "Food & Dining",
  ///   "date": "2025-12-17T10:30:00Z" (ISO format) or "2025-04-01" (date-only),
  ///   "status": "pending" | "approved" | "rejected",
  ///   "imageLink": "encrypted-image-url",
  ///   "expenseReportId": "report-uuid" or null
  /// }
  Map<String, dynamic> _normalizeReceipt(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    
    // Handle ID (can be string UUID or numeric)
    final id = map['id'];
    final idString = id?.toString() ?? '';
    
    // API returns 'merchant' field (per Workspace Receipts Guide)
    // Also handle 'title' for compatibility with recentSubmissions format
    final merchant = map['merchant']?.toString() ?? map['title']?.toString() ?? 'Receipt';
    
    // Format date - API can return ISO format ("2025-12-17T10:30:00Z") or date-only ("2025-04-01")
    String formattedDate = map['date']?.toString() ?? '';
    if (formattedDate.isNotEmpty) {
      try {
        DateTime dateTime;
        if (formattedDate.contains('T')) {
          // ISO format: "2025-12-17T10:30:00Z"
          dateTime = DateTime.parse(formattedDate);
        } else {
          // Date-only format: "2025-04-01"
          dateTime = DateTime.parse(formattedDate);
        }
        formattedDate = DateFormat('MMM d, yyyy').format(dateTime);
      } catch (e) {
        // Keep original format if parsing fails
        debugPrint('Date parsing error: $e');
      }
    }
    
    // Format amount (API returns numeric: 45.50 or 7000)
    final amount = map['amount'];
    final amountValue = amount is num ? amount.toDouble() : (double.tryParse(amount?.toString() ?? '0') ?? 0.0);
    
    return {
      'id': idString,
      'title': merchant, // Use merchant as title for display
      'merchant': merchant,
      'category': map['category']?.toString() ?? '',
      'amount': amountValue,
      'date': formattedDate,
      'status': (map['status']?.toString() ?? 'pending').toLowerCase(),
      'imageLink': map['imageLink'], // Encrypted image URL
      'expenseReportId': map['expenseReportId'], // Links receipt to expense report
      'rejectionReason': map['rejectionReason'], // Rejection reason if status is rejected
    };
  }

  Future<void> _submitReceipt() async {
    final merchant = _merchantController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final category = _categoryController.text.trim();
    final date = _dateController.text.trim();
    final description = _descriptionController.text.trim();

    if (merchant.isEmpty ||
        amount == null ||
        category.isEmpty ||
        date.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final res = await WorkspaceService.submitWorkspaceReceipt(
      workspaceId: widget.workspaceId,
      userId: widget.userId,
      body: {
        'userId': widget.userId,
        'merchant': merchant,
        'amount': amount,
        'category': category,
        'date': date,
        'description': description,
      },
      token: widget.token,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      Navigator.pop(context);
      _merchantController.clear();
      _amountController.clear();
      _categoryController.clear();
      _dateController.clear();
      _descriptionController.clear();
      await _loadReceipts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt submitted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Submit failed')),
      );
    }
  }

  void _showSubmitSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Submit Receipt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _merchantController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E5EFD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _submitReceipt,
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Receipts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                        _loadReceipts();
                      },
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFF7E5EFD),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      checkmarkColor: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadReceipts,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _receipts.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1ECFF),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 64,
                                      color: Color(0xFF7E5EFD),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'No receipts yet',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Your submitted receipts will appear here',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadReceipts,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _receipts.length,
                              itemBuilder: (context, index) {
                                final r = _receipts[index];
                                final status = r['status']?.toString() ?? 'pending';
                                final statusColor = _statusColor(status);
                                final amount = r['amount'];
                                final amountText = amount is num 
                                    ? '₹${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}'
                                    : '₹${amount?.toString() ?? '0'}';
                                final receiptTitle = r['title'] ?? r['merchant'] ?? 'Receipt';
                                final receiptMerchant = r['merchant']?.toString() ?? '';
                                final receiptCategory = r['category']?.toString() ?? '';
                                
                                // Use category as subtitle if merchant is empty or same as title
                                final subtitle = (receiptMerchant.isEmpty || receiptMerchant == receiptTitle)
                                    ? receiptCategory
                                    : receiptMerchant;
                                
                                return _buildReceiptCard(
                                  receiptId: r['id']?.toString() ?? '',
                                  title: receiptTitle,
                                  merchant: subtitle,
                                  category: receiptCategory,
                                  amount: amountText,
                                  date: r['date'] ?? '',
                                  status: _formatStatus(status),
                                  statusColor: statusColor,
                                  hasImage: r['imageLink'] != null && r['imageLink'].toString().isNotEmpty,
                                  rejectionReason: r['rejectionReason']?.toString(),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF22C55E);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFFACC15);
    }
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return 'Pending';
    return status[0].toUpperCase() + status.substring(1);
  }

  Widget _buildReceiptCard({
    required String receiptId,
    required String title,
    required String merchant,
    required String category,
    required String amount,
    required String date,
    required String status,
    required Color statusColor,
    required bool hasImage,
    String? rejectionReason,
  }) {
    return InkWell(
      onTap: () {
        if (receiptId.isNotEmpty) {
          _openReceiptDetails(receiptId);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF7E5EFD).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                hasImage ? Icons.receipt_long : Icons.edit_note,
                color: const Color(0xFF7E5EFD),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    merchant,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (rejectionReason != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            rejectionReason,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFEF4444),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Open receipt details using API endpoint
  Future<void> _openReceiptDetails(String receiptId) async {
    if (receiptId.isEmpty) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
        ),
      ),
    );

    try {
      // Fetch fresh receipt details from API
      final response = await ApiService.get(
        '/receipts/details/$receiptId?userId=${widget.userId}',
        token: widget.token,
      );

      // Close loading indicator
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final freshReceipt = data['receipt'] ?? data;

        // Decrypt image URL
        final encryptedImageLink = freshReceipt['imageLink'] as String?;
        String decryptedImageUrl = '';
        if (encryptedImageLink != null) {
          final decrypted = EncryptionHelper.decryptUrl(encryptedImageLink);
          if (decrypted != null) {
            decryptedImageUrl = decrypted;
            freshReceipt['decryptedImageLink'] = decryptedImageUrl;
            debugPrint('🔓 Workspace Receipts - Decrypted image URL: $decryptedImageUrl');
          }
        }

        final isPdfFresh = decryptedImageUrl.toLowerCase().endsWith('.pdf');
        final isManualFresh = _isManualReceipt(freshReceipt);

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptDetailsScreen(
              receipt: freshReceipt,
              imageUrl: decryptedImageUrl,
              userId: widget.userId,
              imageId: freshReceipt['imageId']?.toString() ?? '',
              isNewReceipt: false,
              isPdf: isPdfFresh,
              isManualReceipt: isManualFresh,
            ),
          ),
        );

        // Refresh receipts if receipt was modified
        if (result == true && mounted) {
          await _loadReceipts();
        }
      } else {
        // API failed, show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load receipt details. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading indicator if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      debugPrint('Error opening receipt details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isManualReceipt(Map<String, dynamic> receipt) {
    final imageUrl = receipt['decryptedImageLink'] ?? receipt['imageLink'] ?? '';
    return receipt['isManual'] == true ||
        imageUrl.contains('placeholder') ||
        imageUrl.contains('Manual+Receipt') ||
        imageUrl.isEmpty;
  }

  void _showReceiptDetails({
    required String title,
    required String merchant,
    required String category,
    required String amount,
    required String date,
    required String status,
    required Color statusColor,
    required bool hasImage,
    String? rejectionReason,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Receipt Details',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (hasImage) ...[
                          Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Receipt Image',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        _buildDetailRow('Amount', amount),
                        const SizedBox(height: 16),
                        _buildDetailRow('Merchant', merchant),
                        const SizedBox(height: 16),
                        _buildDetailRow('Category', category),
                        const SizedBox(height: 16),
                        _buildDetailRow('Date', date),
                        const SizedBox(height: 16),
                        _buildDetailRow('Title', title),
                        if (rejectionReason != null) ...[
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            'Rejection Reason',
                            rejectionReason,
                            isError: true,
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7E5EFD),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isError ? const Color(0xFFEF4444) : Colors.black87,
          ),
        ),
      ],
    );
  }
}



