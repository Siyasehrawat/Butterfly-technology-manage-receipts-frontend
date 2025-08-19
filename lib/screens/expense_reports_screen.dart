import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';
import 'expense_report_detail_screen.dart';
import 'expense_report_create_screen.dart'; // Assuming this file exists

class ExpenseReportsScreen extends StatefulWidget {
  final String userId;
  final String token;

  const ExpenseReportsScreen({
    Key? key,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<ExpenseReportsScreen> createState() => _ExpenseReportsScreenState();
}

class _ExpenseReportsScreenState extends State<ExpenseReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _expenseReports = [];
  bool _isLoading = true;
  String _selectedTimeFilter = 'All';

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF7E5EFD),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    _fetchExpenseReports();
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchExpenseReports() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.get(
        '/expense-reports/?userId=${widget.userId}',
        token: widget.token,
      );

      debugPrint('Expense Reports API Response: ${response.statusCode}');
      debugPrint('Expense Reports API Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> reports = [];

        if (data is List) {
          reports = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('reports')) {
          reports = List<Map<String, dynamic>>.from(data['reports'] ?? []);
        } else {
          reports = [];
        }

        setState(() {
          _expenseReports = reports;
        });
      } else {
        debugPrint('Failed to load expense reports: ${response.statusCode}');
        setState(() {
          _expenseReports = [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching expense reports: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Updated delete expense report functionality - now works for all statuses
  Future<void> _deleteExpenseReport(String reportId, String reportTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense Report'),
        content: Text('Are you sure you want to delete "$reportTitle"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await ApiService.delete(
        '/expense-reports/$reportId',
        token: widget.token,
      );

      debugPrint('Delete Report API Response: ${response.statusCode}');
      debugPrint('Delete Report API Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense report deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        String errorMessage = 'Failed to delete expense report';
        if (response.statusCode == 404) {
          errorMessage = 'Report not found or already deleted';
        } else if (response.statusCode == 403) {
          errorMessage = 'You do not have permission to delete this report';
        }

        throw Exception('$errorMessage (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error deleting expense report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _fetchExpenseReports();
      }
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    List<Map<String, dynamic>> filtered = List.from(_expenseReports);

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((report) {
        final title = (report['title'] ?? '').toLowerCase();
        final description = (report['description'] ?? '').toLowerCase();
        return title.contains(searchQuery) || description.contains(searchQuery);
      }).toList();
    }

    // Apply time filter
    if (_selectedTimeFilter != 'All') {
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedTimeFilter) {
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'Last Month':
          final lastMonth = now.month == 1 ? 12 : now.month - 1;
          final year = now.month == 1 ? now.year - 1 : now.year;
          startDate = DateTime(year, lastMonth, 1);
          break;
        default:
          startDate = DateTime(1900);
      }

      filtered = filtered.where((report) {
        try {
          final createdAt = DateTime.parse(report['createdAt'] ?? report['created_at'] ?? '');
          if (_selectedTimeFilter == 'This Month') {
            return createdAt.year == now.year && createdAt.month == now.month;
          } else if (_selectedTimeFilter == 'Last Month') {
            final lastMonth = now.month == 1 ? 12 : now.month - 1;
            final year = now.month == 1 ? now.year - 1 : now.year;
            return createdAt.year == year && createdAt.month == lastMonth;
          }
          return true;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Sort by creation date (newest first)
    filtered.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['createdAt'] ?? a['created_at'] ?? '');
        final dateB = DateTime.parse(b['createdAt'] ?? b['created_at'] ?? '');
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    return filtered;
  }

  Widget _buildTimeFilterTab(String title) {
    final isSelected = _selectedTimeFilter == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeFilter = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8E6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: const Color(0xFF7E5EFD)) : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseReportCard(Map<String, dynamic> report) {
    final status = report['status'] ?? 'draft';
    final isSubmitted = status == 'submitted';
    final isPaid = status == 'paid';
    final isDraft = status == 'draft';
    final title = report['title'] ?? 'Untitled Report';
    final description = report['description'] ?? '';
    final reportId = report['id']?.toString() ?? report['_id']?.toString() ?? '';

    final List<dynamic> receiptsData = report['receipts'] ?? [];
    final receiptCount = receiptsData.length;
    double totalAmount = 0.0;
    for (final receipt in receiptsData) {
      totalAmount += (double.tryParse(receipt['amount']?.toString() ?? '0') ?? 0.0);
    }

    debugPrint('Report: $title, Receipt Count: $receiptCount, Total Amount: $totalAmount');

    final emailsSentTo = (report['emailsSentTo'] as List?)?.cast<String>() ?? [];

    final userProvider = Provider.of<UserProvider>(context);
    final currencySymbol = userProvider.effectiveCurrencySymbol;

    String formattedDate = 'No date';
    try {
      final createdAt = DateTime.parse(report['createdAt'] ?? report['created_at'] ?? '');
      formattedDate = DateFormat('MMM d, yyyy').format(createdAt);
    } catch (e) {
      debugPrint('Error parsing date: $e');
    }

    // Determine status color and text
    Color statusColor;
    Color statusBgColor;
    String statusText;

    if (isPaid) {
      statusColor = Colors.blue.shade700;
      statusBgColor = Colors.blue.shade100;
      statusText = 'Paid';
    } else if (isSubmitted) {
      statusColor = Colors.green.shade700;
      statusBgColor = Colors.green.shade100;
      statusText = 'Submitted';
    } else {
      statusColor = Colors.orange.shade700;
      statusBgColor = Colors.orange.shade100;
      statusText = 'Draft';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExpenseReportDetailScreen(
              reportId: reportId,
              userId: widget.userId,
              token: widget.token,
            ),
          ),
        ).then((result) {
          // If the detail screen indicates a change (e.g., by popping with true), refresh
          if (result == true) {
            _fetchExpenseReports();
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPaid ? Colors.blue : (isSubmitted ? Colors.green : Colors.orange),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  // Delete button for all reports (updated)
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _deleteExpenseReport(reportId, title),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Show emails sent to if any
              if (emailsSentTo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.email,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Sent to: ${emailsSentTo.join(', ')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$receiptCount receipts',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7E5EFD),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: Text(
                      '$currencySymbol${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredReports = _filteredReports;

    return Scaffold(
      body: Column(
        children: [
          // Purple header with MR logo
          Container(
            color: const Color(0xFF7E5EFD),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 16,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Expense Reports',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // MR Logo
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'MR',
                      style: TextStyle(
                        color: Color(0xFF7E5EFD),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          const Icon(Icons.search, color: Colors.grey),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search expense reports...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                              ),
                              onChanged: (value) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Time filter tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTimeFilterTab('All'),
                          const SizedBox(width: 8),
                          _buildTimeFilterTab('This Month'),
                          const SizedBox(width: 8),
                          _buildTimeFilterTab('Last Month'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Create expense report button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExpenseReportCreateScreen(
                              userId: widget.userId,
                              token: widget.token,
                            ),
                          ),
                        ).then((result) {
                          // Assuming ExpenseReportCreateScreen (and subsequent screens)
                          // will pop with 'true' if a report was saved/submitted.
                          if (result == true) {
                            _fetchExpenseReports();
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Create Expense Report',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Reports list
                  Expanded(
                    child: _isLoading
                        ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                      ),
                    )
                        : filteredReports.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assessment,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No expense reports found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your first expense report',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                        : RefreshIndicator(
                      onRefresh: _fetchExpenseReports,
                      color: const Color(0xFF7E5EFD),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredReports.length,
                        itemBuilder: (context, index) {
                          return _buildExpenseReportCard(filteredReports[index]);
                        },
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
}