import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../services/workspace_service.dart';

class WorkspaceCreateExpenseReportScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String? workspaceId;
  final String reportTitle;
  final String reportDescription;

  const WorkspaceCreateExpenseReportScreen({
    Key? key,
    required this.userId,
    required this.token,
    this.workspaceId,
    required this.reportTitle,
    required this.reportDescription,
  }) : super(key: key);

  @override
  State<WorkspaceCreateExpenseReportScreen> createState() =>
      _WorkspaceCreateExpenseReportScreenState();
}

class _WorkspaceCreateExpenseReportScreenState
    extends State<WorkspaceCreateExpenseReportScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allReceipts = [];
  List<Map<String, dynamic>> _filteredReceipts = [];
  Set<String> _selectedReceiptIds = {};
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Upload progress indicators
  String _uploadStatus = 'Creating report...';
  int _currentStep = 0;
  final List<String> _uploadSteps = [
    'Creating report...',
    'Adding receipts...',
    'Notifying manager...',
    'Report created!'
  ];
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
    _searchController.addListener(_filterReceipts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  /// Load workspace receipts using the correct endpoint
  /// 
  /// ENDPOINT: GET /api/workspace/:workspaceId/receipts?userId=:userId&status=:status&page=:page&pageSize=:pageSize
  /// 
  /// This fetches all receipts for the workspace user to select for expense report
  Future<void> _loadReceipts() async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _allReceipts = [];
        _filteredReceipts = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all receipts (no status filter, get all receipts)
      final res = await WorkspaceService.listWorkspaceReceipts(
        workspaceId: widget.workspaceId!,
        userId: widget.userId,
        query: {
          'status': 'all', // Get all receipts regardless of status
          'page': '1',
          'pageSize': '100', // Load enough receipts for selection
        },
        token: widget.token,
      );

      if (!mounted) return;

      if (res['success'] == true) {
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
        final receiptsList = data?['receipts'] as List<dynamic>? ?? [];
        
        // Normalize receipts to match expected format
        final normalizedReceipts = receiptsList.map(_normalizeReceipt).toList();
        
        setState(() {
          _allReceipts = normalizedReceipts;
          _filteredReceipts = normalizedReceipts;
          _isLoading = false;
        });
      } else {
        setState(() {
          _allReceipts = [];
          _filteredReceipts = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading receipts: $e');
      setState(() {
        _allReceipts = [];
        _filteredReceipts = [];
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
  ///   "status": "pending" | "approved" | "rejected"
  /// }
  Map<String, dynamic> _normalizeReceipt(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    
    // Handle ID (can be string UUID or numeric)
    final id = map['id'];
    final idString = id?.toString() ?? '';
    
    // API returns 'merchant' field
    final merchant = map['merchant']?.toString() ?? 'Receipt';
    
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
      'merchant': merchant,
      'amount': amountValue, // Keep as number for calculations
      'category': map['category']?.toString() ?? '',
      'date': formattedDate,
      'status': (map['status']?.toString() ?? 'pending').toLowerCase(),
    };
  }

  void _filterReceipts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredReceipts = _allReceipts;
      } else {
        _filteredReceipts = _allReceipts.where((receipt) {
          final merchant = receipt['merchant'].toString().toLowerCase();
          final category = receipt['category'].toString().toLowerCase();
          return merchant.contains(query) || category.contains(query);
        }).toList();
      }
    });
  }

  void _toggleReceiptSelection(String receiptId) {
    setState(() {
      if (_selectedReceiptIds.contains(receiptId)) {
        _selectedReceiptIds.remove(receiptId);
      } else {
        _selectedReceiptIds.add(receiptId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedReceiptIds = _filteredReceipts.map((r) => r['id'] as String).toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedReceiptIds.clear();
    });
  }

  void _startProgressSimulation() {
    _currentStep = 0;
    _uploadStatus = _uploadSteps[_currentStep];

    _progressTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (_currentStep < _uploadSteps.length - 1) {
        setState(() {
          _currentStep++;
          _uploadStatus = _uploadSteps[_currentStep];
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _submitReport() async {
    if (_selectedReceiptIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one receipt'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workspace is required to create a report'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    _startProgressSimulation();

    try {
      // Calculate total amount
      double totalAmount = 0.0;
      for (final receiptId in _selectedReceiptIds) {
        final receipt = _allReceipts.firstWhere((r) => r['id'] == receiptId);
        final amount = receipt['amount'];
        totalAmount += amount is num ? amount.toDouble() : (double.tryParse(amount.toString()) ?? 0.0);
      }

      final res = await WorkspaceService.createExpenseReport(
        workspaceId: widget.workspaceId!,
        userId: widget.userId,
        body: {
          'title': widget.reportTitle,
          'description': widget.reportDescription,
          'amount': totalAmount,
          'receiptIds': _selectedReceiptIds.toList(),
        },
        token: widget.token,
      );

      if (!mounted) return;

      _progressTimer?.cancel();

      setState(() {
        _isSubmitting = false;
      });

      if (res['success'] == true) {
        // Show success dialog
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error']?.toString() ?? 'Failed to create report'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating expense report: $e');
      if (!mounted) return;

      _progressTimer?.cancel();

      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF22C55E),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Report Created!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your expense report "${widget.reportTitle}" has been created and submitted for approval.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to dashboard
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _calculateTotal() {
    double total = 0.0;
    for (final receiptId in _selectedReceiptIds) {
      final receipt = _allReceipts.firstWhere((r) => r['id'] == receiptId);
      total += double.tryParse(receipt['amount'].toString()) ?? 0.0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    // Show uploading progress overlay
    if (_isSubmitting) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF7E5EFD),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Creating Report',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
              ),
              const SizedBox(height: 24),
              Text(
                _uploadStatus,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we create your report',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _uploadSteps.length,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF7E5EFD),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Step ${_currentStep + 1} of ${_uploadSteps.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF7E5EFD),
      body: Column(
        children: [
          // Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.reportTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      'Select receipts for your expense report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header with selection count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Text(
                          '${_selectedReceiptIds.length} selected',
                          style: const TextStyle(
                            color: Color(0xFF7E5EFD),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_selectedReceiptIds.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'PDF',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        TextButton(
                          onPressed: _selectedReceiptIds.isEmpty ? _selectAll : _deselectAll,
                          child: Text(
                            _selectedReceiptIds.isEmpty ? 'Select All' : 'Deselect All',
                            style: const TextStyle(
                              color: Color(0xFF7E5EFD),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F0FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.grey, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search Receipts...',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Receipts list
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                            ),
                          )
                        : _filteredReceipts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No receipts found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: _filteredReceipts.length,
                                itemBuilder: (context, index) {
                                  final receipt = _filteredReceipts[index];
                                  final receiptId = receipt['id'] as String;
                                  final isSelected = _selectedReceiptIds.contains(receiptId);

                                  return _buildReceiptTile(receipt, isSelected);
                                },
                              ),
                  ),

                  // Bottom buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_selectedReceiptIds.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F0FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Amount:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '₹${_calculateTotal().toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7E5EFD),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _selectedReceiptIds.isEmpty ? null : _submitReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7E5EFD),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Create Report',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildReceiptTile(Map<String, dynamic> receipt, bool isSelected) {
    final receiptId = receipt['id'] as String;
    final merchant = receipt['merchant'] as String;
    // Handle amount as number or string
    final amountValue = receipt['amount'];
    final amount = amountValue is num 
        ? amountValue.toStringAsFixed(2) 
        : amountValue.toString();
    final category = receipt['category'] as String;
    final date = receipt['date'] as String;

    return GestureDetector(
      onTap: () => _toggleReceiptSelection(receiptId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F0FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF7E5EFD) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF7E5EFD) : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF7E5EFD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7E5EFD),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹$amount',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



