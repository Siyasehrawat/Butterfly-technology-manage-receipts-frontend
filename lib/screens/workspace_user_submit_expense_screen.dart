import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import '../services/workspace_service.dart';
import 'workspace_create_expense_report_screen.dart';

class WorkspaceUserSubmitExpenseScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String? workspaceId;
  final bool uploadFromGallery;
  final bool manualEntry;

  const WorkspaceUserSubmitExpenseScreen({
    Key? key,
    required this.userId,
    required this.token,
    this.workspaceId,
    this.uploadFromGallery = false,
    this.manualEntry = false,
  }) : super(key: key);

  @override
  State<WorkspaceUserSubmitExpenseScreen> createState() =>
      _WorkspaceUserSubmitExpenseScreenState();
}

class _WorkspaceUserSubmitExpenseScreenState
    extends State<WorkspaceUserSubmitExpenseScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _expenseReports = [];

  @override
  void initState() {
    super.initState();
    _loadExpenseReports();
  }

  Future<void> _loadExpenseReports() async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      setState(() {
        _expenseReports = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final res = await WorkspaceService.listExpenseReports(
        workspaceId: widget.workspaceId!,
        userId: widget.userId,
        query: {
          'status': 'all',
          'page': '1',
          'pageSize': '100',
        },
        token: widget.token,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final responseData = res['data'];
        Map<String, dynamic>? data;
        
        if (responseData is Map<String, dynamic>) {
          // Check if nested (has 'data' key)
          if (responseData.containsKey('data') && responseData['data'] is Map) {
            data = responseData['data'] as Map<String, dynamic>?;
          } else if (responseData.containsKey('reports')) {
            // Direct structure
            data = responseData;
          }
        }
        
        final reportsList = data?['reports'] as List<dynamic>? ?? [];
        final normalizedReports = reportsList.map(_normalizeReport).toList();
        
        setState(() {
          _expenseReports = normalizedReports;
          _isLoading = false;
        });
      } else {
        setState(() {
          _expenseReports = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading expense reports: $e');
      setState(() {
        _expenseReports = [];
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _normalizeReport(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    
    // Format date
    String formattedDate = '';
    final submittedAt = map['submittedAt'] ?? map['createdAt'];
    if (submittedAt != null) {
      try {
        final dateTime = DateTime.parse(submittedAt.toString());
        formattedDate = DateFormat('MMM d, yyyy').format(dateTime);
      } catch (e) {
        formattedDate = submittedAt.toString();
      }
    }
    
    return {
      'id': map['id']?.toString() ?? '',
      'title': map['title'] ?? 'Expense Report',
      'description': map['description'] ?? '',
      'status': (map['status'] ?? 'pending').toString().toLowerCase(),
      'receiptsCount': map['receiptCount'] ?? map['receiptsCount'] ?? 0,
      'totalAmount': (map['totalAmount'] ?? 0).toString(),
      'submittedDate': formattedDate,
    };
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Expense Reports',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(8)),
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
          ),
        ],
      ),
      body: Column(
        children: [
          // Create Expense Report Card
          Container(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () => _showCreateReportDialog(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7E5EFD), Color(0xFF9B7EFD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7E5EFD).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Expense Report',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Group multiple expenses together',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Reports List Section
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                    ),
                  )
                : _expenseReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Expense Reports Yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first report to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _expenseReports.length,
                        itemBuilder: (context, index) {
                          final report = _expenseReports[index];
                          return _buildReportCard(report);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final status = report['status'] as String;
    final isApproved = status == 'approved';
    final isPending = status == 'pending';

    Color statusColor;
    Color statusBgColor;
    String statusText;

    if (isApproved) {
      statusColor = const Color(0xFF22C55E);
      statusBgColor = const Color(0xFF22C55E);
      statusText = 'Approved';
    } else {
      statusColor = const Color(0xFFFACC15);
      statusBgColor = const Color(0xFFFACC15);
      statusText = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF7E5EFD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description,
                  color: Color(0xFF7E5EFD),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['title'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report['submittedDate'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBgColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
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
            ],
          ),
          const SizedBox(height: 12),
          if (report['description'] != null && (report['description'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                report['description'] as String,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      size: 18,
                      color: Color(0xFF7E5EFD),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${report['receiptsCount']} receipts',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7E5EFD),
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${report['totalAmount']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateReportDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7E5EFD).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.description,
                          color: Color(0xFF7E5EFD),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'New Expense Report',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(dialogContext),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Report Title *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Monthly Expenses - Dec 2025',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a report title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add notes or details about this report...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(dialogContext);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkspaceCreateExpenseReportScreen(
                                userId: widget.userId,
                                token: widget.token,
                                workspaceId: widget.workspaceId,
                                reportTitle: titleController.text.trim(),
                                reportDescription: descriptionController.text.trim(),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_forward, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Select Receipts',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
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
          ),
        );
      },
    );
  }
}
