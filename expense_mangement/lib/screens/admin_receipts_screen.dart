import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AdminReceiptsScreen extends StatefulWidget {
  final String adminId;
  final String token;

  const AdminReceiptsScreen({
    Key? key,
    required this.adminId,
    required this.token,
  }) : super(key: key);

  @override
  State<AdminReceiptsScreen> createState() => _AdminReceiptsScreenState();
}

class _AdminReceiptsScreenState extends State<AdminReceiptsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _receipts = [];
  List<Map<String, dynamic>> _filteredReceipts = [];
  final TextEditingController _searchController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchReceipts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchReceipts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse(
          'https://manage-receipt-backend-bnl1.onrender.com/api/admin/receipts');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> receiptsData =
            data is List ? data : (data['receipts'] ?? []);

        setState(() {
          _receipts = List<Map<String, dynamic>>.from(receiptsData);
          _filteredReceipts = List.from(_receipts);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load receipts: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching receipts: $e');
      setState(() {
        _errorMessage = 'Network error: Unable to connect to server';
        _isLoading = false;
      });
    }
  }

  void _filterReceipts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredReceipts = List.from(_receipts);
      } else {
        _filteredReceipts = _receipts.where((receipt) {
          final merchant = (receipt['merchant'] ?? '').toLowerCase();
          final amount = (receipt['amount'] ?? '').toString().toLowerCase();
          final category = (receipt['category'] ?? '').toLowerCase();
          final userId = (receipt['userId'] ?? '').toString().toLowerCase();

          return merchant.contains(query.toLowerCase()) ||
              amount.contains(query.toLowerCase()) ||
              category.contains(query.toLowerCase()) ||
              userId.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _deleteReceipt(String receiptId) async {
    try {
      final url = Uri.parse(
          'https://manage-receipt-backend-bnl1.onrender.com/api/admin/receipts/$receiptId');

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchReceipts(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete receipt: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(String receiptId, String merchant) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Receipt'),
          content: Text(
              'Are you sure you want to delete the receipt from $merchant?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteReceipt(receiptId);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        title: const Text('Admin - Receipts'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search receipts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7E5EFD)),
                ),
              ),
              onChanged: _filterReceipts,
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7E5EFD),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchReceipts,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7E5EFD),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredReceipts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No receipts found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchReceipts,
                            color: const Color(0xFF7E5EFD),
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredReceipts.length,
                              itemBuilder: (context, index) {
                                final receipt = _filteredReceipts[index];
                                return _buildReceiptCard(receipt);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt) {
    final merchant = receipt['merchant'] ?? 'Unknown Merchant';
    final amount = receipt['amount']?.toString() ?? '0.00';
    final category = receipt['category'] ?? 'Uncategorized';
    final userId = receipt['userId']?.toString() ?? 'Unknown User';
    final receiptDate = receipt['receiptDate'] ?? '';
    final receiptId =
        receipt['id']?.toString() ?? receipt['imageId']?.toString() ?? '';

    // Format date
    String formattedDate = 'No date';
    if (receiptDate.isNotEmpty) {
      try {
        final DateTime date = DateTime.parse(receiptDate);
        formattedDate = DateFormat('MMM dd, yyyy').format(date);
      } catch (e) {
        formattedDate = receiptDate;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchant,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$$amount',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7E5EFD),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteConfirmation(receiptId, merchant);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip('Category', category, Icons.category),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      _buildInfoChip('Date', formattedDate, Icons.date_range),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoChip('User ID', userId, Icons.person),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EAFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7E5EFD)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7E5EFD),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
