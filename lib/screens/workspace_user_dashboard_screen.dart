/// Workspace User Dashboard Screen
/// 
/// WORKSPACE RECEIPTS IMPLEMENTATION (per Official Guide)
/// ======================================================
/// 
/// ⚠️ SINGLE SOURCE OF TRUTH:
/// - Workspace receipts MUST use: POST /api/workspace/:workspaceId/receipts
/// - Regular receipts MUST use: POST /api/receipts (workspaceId = null)
/// - DO NOT mix endpoints - this ensures clear separation
/// 
/// ENDPOINTS USED:
/// --------------
/// Dashboard Data:
///   → GET /api/workspace/:workspaceId/user-dashboard?userId=:userId
///   → Returns: { "summary": {...}, "recentSubmissions": [...] }
///   → Used for: Summary stats and recent submissions display
/// 
/// Full Receipts List:
///   → GET /api/workspace/:workspaceId/receipts?userId=:userId&status=:status&page=:page&pageSize=:pageSize
///   → Returns: { "receipts": [...], "pagination": {...} }
///   → Used by: WorkspaceUserReceiptsScreen (accessed via "My Receipts" button)
/// 
/// UPLOAD WORKFLOW (User Role):
/// ---------------------------
/// Flow 1: Manual Entry (No OCR)
///   → POST /api/workspace/:workspaceId/receipts
///   → Required: userId, merchant, amount, date
///   → Optional: category, imageLink, description
///   → Status: 'pending' (awaits manager approval)
/// 
/// Flow 2: With OCR Processing
///   Step 1: POST /api/receipts/process-receipt
///           (Processes OCR but does NOT save)
///   Step 2: POST /api/workspace/:workspaceId/receipts
///           (Saves OCR result to workspace)
///   → Status: 'pending' (awaits manager approval)
/// 
/// RECEIPT STATUS:
/// --------------
/// - 'pending': Awaiting manager approval
/// - 'approved': Manager approved via expense report
/// - 'rejected': Manager rejected via expense report
/// 
/// IMAGE LINKS:
/// -----------
/// - All imageLink values are ENCRYPTED
/// - Must decrypt using EncryptionHelper.decryptImagePath() before display
/// 
/// See: Workspace Receipts - Upload & Retrieve Guide

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io' show File;
import '../services/workspace_service.dart';
import '../services/api_service_bypass.dart';
import '../services/document_scan_service.dart';
import '../providers/user_provider.dart';
import '../utils/encryption_helper.dart';
import 'workspace_user_receipts_screen.dart';
import 'workspace_user_submit_expense_screen.dart';
import 'workspace_needs_requests_screen.dart';
import 'receipt_details_screen.dart';

class WorkspaceUserDashboardScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String? workspaceId;
  final String? workspaceName;

  const WorkspaceUserDashboardScreen({
    Key? key,
    required this.userId,
    required this.token,
    this.workspaceId,
    this.workspaceName,
  }) : super(key: key);

  @override
  State<WorkspaceUserDashboardScreen> createState() => _WorkspaceUserDashboardScreenState();
}

class _WorkspaceUserDashboardScreenState extends State<WorkspaceUserDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUploading = false;
  
  // Summary data
  int? _pendingExpenses;
  int? _approvedExpenses;
  double? _thisMonthSpend;
  double? _totalSpend;
  
  // Recent submissions
  List<Map<String, dynamic>> _recentSubmissions = [];
  
  // Upload progress
  String _uploadStatus = 'Uploading receipt...';
  int _currentStep = 0;
  final List<String> _uploadSteps = [
    'Uploading receipt...',
    'Scanning for data...',
    'Filling in missing pieces...',
    'Processing complete!'
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  /// Load dashboard data from backend
  /// 
  /// ENDPOINT: GET /api/workspace/:workspaceId/user-dashboard?userId=:userId
  /// 
  /// This endpoint returns:
  /// - Summary statistics (pendingExpenses, approvedExpenses, thisMonthSpend, totalSpend)
  /// - Recent submissions array (limited recent receipts)
  /// 
  /// For full receipts list, use: GET /api/workspace/:workspaceId/receipts (via WorkspaceUserReceiptsScreen)
  Future<void> _loadDashboard() async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Workspace ID is required';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Fetch dashboard data using user-dashboard endpoint
    // Response: { "success": true, "data": { "summary": {...}, "recentSubmissions": [...] } }
    final result = await WorkspaceService.getUserDashboard(
      workspaceId: widget.workspaceId!,
      userId: widget.userId,
      token: widget.token,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      // ============================================================================
      // RESPONSE STRUCTURE HANDLING
      // ============================================================================
      // API returns: { "success": true, "data": { "summary": {...}, "recentSubmissions": [...] } }
      // WorkspaceService wraps it: { "success": true, "data": <decoded response body> }
      // So result['data'] = { "success": true, "data": { "summary": {...}, "recentSubmissions": [...] } }
      // We need: result['data']['data'] to get { "summary": {...}, "recentSubmissions": [...] }
      // ============================================================================
      final responseData = result['data'];
      
      // Debug: Log raw response structure
      debugPrint('=== Dashboard Data Extraction ===');
      debugPrint('result keys: ${result.keys}');
      debugPrint('result[data] type: ${responseData.runtimeType}');
      
      Map<String, dynamic>? data;
      
      if (responseData is Map<String, dynamic>) {
        debugPrint('result[data] keys: ${responseData.keys}');
        
        // Check if nested structure exists (API response wrapped by service)
        if (responseData.containsKey('data') && responseData['data'] is Map<String, dynamic>) {
          // Nested: result['data']['data']
          data = responseData['data'] as Map<String, dynamic>;
          debugPrint('✓ Using nested structure: result[data][data]');
        } else if (responseData.containsKey('summary') || responseData.containsKey('recentSubmissions')) {
          // Direct: result['data'] already contains summary/recentSubmissions
          data = responseData;
          debugPrint('✓ Using direct structure: result[data]');
        } else {
          debugPrint('⚠ Warning: Unexpected response structure');
          debugPrint('  Response data: $responseData');
        }
      } else {
        debugPrint('⚠ Error: result[data] is not a Map');
      }
      
      final summary = data?['summary'] as Map<String, dynamic>?;
      final recentSubmissions = data?['recentSubmissions'] as List<dynamic>?;
      
      debugPrint('Extracted summary: $summary');
      debugPrint('Extracted recentSubmissions count: ${recentSubmissions?.length ?? 0}');
      debugPrint('================================');

      // ============================================================================
      // MAP SUMMARY DATA FROM API RESPONSE
      // API Response: { "summary": { "pendingExpenses": 1, "approvedExpenses": 0, "thisMonthSpend": 0, "totalSpend": 7000 } }
      // ============================================================================
      setState(() {
        // Map pending expenses count
        _pendingExpenses = summary?['pendingExpenses'] is int
            ? summary!['pendingExpenses'] as int
            : int.tryParse('${summary?['pendingExpenses']}');
        
        // Map approved expenses count
        _approvedExpenses = summary?['approvedExpenses'] is int
            ? summary!['approvedExpenses'] as int
            : int.tryParse('${summary?['approvedExpenses']}');
        
        // Map this month's spending amount
        _thisMonthSpend = summary?['thisMonthSpend'] is num
            ? (summary!['thisMonthSpend'] as num).toDouble()
            : double.tryParse('${summary?['thisMonthSpend']}');
        
        // Map total spending amount
        _totalSpend = summary?['totalSpend'] is num
            ? (summary!['totalSpend'] as num).toDouble()
            : double.tryParse('${summary?['totalSpend']}');
        
        // ============================================================================
        // MAP RECENT SUBMISSIONS FROM API RESPONSE
        // API Response: [{ "id": 419, "title": "Elite fitness club", "category": "Services", "amount": 7000, "status": "pending", "date": "2025-04-01" }]
        // ============================================================================
        _recentSubmissions = recentSubmissions?.map((item) {
          final submission = item as Map<String, dynamic>;
          return {
            'id': submission['id']?.toString() ?? '',            // Receipt ID for opening details
            'title': submission['title']?.toString() ?? '',      // "Elite fitness club"
            'category': submission['category']?.toString() ?? '', // "Services"
            'status': submission['status']?.toString() ?? 'pending', // "pending"
            'amount': submission['amount'],                      // 7000 (numeric)
            'date': submission['date']?.toString() ?? '',        // "2025-04-01" (YYYY-MM-DD)
          };
        }).toList() ?? [];
        
        _isLoading = false;
        
        // Debug: Log fetched data
        debugPrint('Dashboard Data Loaded:');
        debugPrint('  Summary: $summary');
        debugPrint('  Recent Submissions Raw: $recentSubmissions');
        debugPrint('  Pending Expenses: $_pendingExpenses');
        debugPrint('  Approved Expenses: $_approvedExpenses');
        debugPrint('  This Month Spend: $_thisMonthSpend');
        debugPrint('  Total Spend: $_totalSpend');
        debugPrint('  Recent Submissions Count: ${_recentSubmissions.length}');
      });
    } else {
      setState(() {
        _errorMessage = result['error']?.toString() ?? 'Failed to load dashboard';
        _isLoading = false;
      });
    }
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
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
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
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.workspaceName ?? 'TeamHub',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'User',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
              ),
            )
          : _isUploading
              ? Center(
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
                        'Please wait while we process your receipt',
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
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
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
                )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDashboard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E5EFD),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Welcome to TeamHub!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4C3A9A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const SizedBox(height: 20),

                      // Stat cards 2x2
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Pending',
                              value: _pendingExpenses?.toString() ?? '0',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Approved',
                              value: _approvedExpenses?.toString() ?? '0',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'This Month',
                              value: _thisMonthSpend != null
                                  ? '₹${_thisMonthSpend!.toStringAsFixed(0)}'
                                  : '₹0',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Total',
                              value: _totalSpend != null
                                  ? '₹${_totalSpend!.toStringAsFixed(0)}'
                                  : '₹0',
                            ),
                          ),
                        ],
                      ),
            const SizedBox(height: 24),

            // Quick Actions Section
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7E5EFD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick actions
            Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    emoji: '➕',
                    label: 'Submit\nExpense',
                    borderColor: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkspaceUserSubmitExpenseScreen(
                            userId: widget.userId,
                            token: widget.token,
                            workspaceId: widget.workspaceId ?? '',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    emoji: '📁',
                    label: 'My\nReceipts',
                    borderColor: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkspaceUserReceiptsScreen(
                            userId: widget.userId,
                            token: widget.token,
                            workspaceId: widget.workspaceId ?? '',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    emoji: '📋',
                    label: 'Needs\nRequests',
                    borderColor: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkspaceNeedsRequestsScreen(
                            userId: widget.userId,
                            token: widget.token,
                            workspaceId: widget.workspaceId ?? '',
                            isManager: false,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Add Receipt Section
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7E5EFD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Add Receipt',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Receipt action cards - 3 cards in one row
            Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    emoji: '📷',
                    label: 'Scan',
                    borderColor: const Color(0xFF7E5EFD),
                    onTap: _isUploading ? null : _pickAndUploadImageFromCamera,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    emoji: '📤',
                    label: 'Upload',
                    borderColor: Colors.green,
                    onTap: _isUploading ? null : _showUploadDialog,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    emoji: '📝',
                    label: 'Manual',
                    borderColor: Colors.blue,
                    onTap: _isUploading ? null : _createManualReceipt,
                  ),
                ),
              ],
            ),
                      const SizedBox(height: 24),

                      // Recent Submissions Section
                      // Uses: GET /api/workspace/:workspaceId/user-dashboard (for recent submissions)
                      // Full receipts: GET /api/workspace/:workspaceId/receipts (via "My Receipts" screen)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recent Submissions',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Track your expense approvals',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WorkspaceUserSubmitExpenseScreen(
                                    userId: widget.userId,
                                    token: widget.token,
                                    workspaceId: widget.workspaceId,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7E5EFD),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Empty state when no submissions
                      if (_recentSubmissions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1ECFF),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 48,
                                  color: Color(0xFF7E5EFD),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No submissions yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Submit your first expense to get started',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._recentSubmissions.map((submission) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildRecentSubmissionCard(submission),
                            )),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRecentSubmissionCard(Map<String, dynamic> submission) {
    final title = submission['title']?.toString() ?? 'Expense';
    final category = submission['category']?.toString() ?? '';
    final status = submission['status']?.toString() ?? 'pending';
    final amount = submission['amount'];
    final date = submission['date']?.toString() ?? '';
    final receiptId = submission['id']?.toString() ?? '';

    // Format amount
    String amountText = '₹0';
    if (amount != null) {
      if (amount is num) {
        amountText = '₹${amount.toStringAsFixed(0)}';
      } else {
        amountText = '₹$amount';
      }
    }

    // Format date
    // API format: "2025-04-01" (YYYY-MM-DD)
    String formattedDate = '';
    if (date.isNotEmpty) {
      try {
        // Handle both ISO format (with time) and date-only format (YYYY-MM-DD)
        DateTime dateTime;
        if (date.contains('T')) {
          // ISO format: "2025-04-01T10:30:00Z"
          dateTime = DateTime.parse(date);
        } else {
          // Date-only format: "2025-04-01"
          dateTime = DateTime.parse(date);
        }
        formattedDate = DateFormat('MMM d, yyyy').format(dateTime);
      } catch (e) {
        // If parsing fails, use the original date string
        formattedDate = date;
      }
    }

    // Status color and label
    Color statusColor = const Color(0xFFFACC15);
    String statusLabel = 'Pending';
    if (status.toLowerCase() == 'approved') {
      statusColor = const Color(0xFF22C55E);
      statusLabel = 'Approved';
    } else if (status.toLowerCase() == 'rejected') {
      statusColor = Colors.red;
      statusLabel = 'Rejected';
    }

    return GestureDetector(
      onTap: () {
        if (receiptId.isNotEmpty) {
          _openReceiptDetails(receiptId);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1ECFF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Color(0xFF7E5EFD),
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
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
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
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (formattedDate.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amountText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7E5EFD),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required String emoji,
    required String label,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFF1F5FF),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    color: borderColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: borderColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.3,
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
      ),
    );
  }

  Widget _buildReceiptActionCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFF1F5FF),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    color: borderColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: borderColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
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
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Workspace Options',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.help_outline, color: Color(0xFF7E5EFD)),
                title: const Text('Need Help?'),
                subtitle: const Text('Contact your workspace admin'),
                onTap: () {
                  Navigator.pop(context);
                  _showContactAdminDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Color(0xFF7E5EFD)),
                title: const Text('Workspace Info'),
                subtitle: const Text('View workspace details'),
                onTap: () {
                  Navigator.pop(context);
                  _showWorkspaceInfo(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showContactAdminDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Contact Admin'),
          content: const Text(
            'To request access, purchase additional licenses, or get help with your workspace, please contact your workspace administrator or support.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showWorkspaceInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Workspace Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workspace: ${widget.workspaceName ?? "TeamHub"}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Role: User'),
              const SizedBox(height: 8),
              const Text(
                'As a user, you can submit expenses and track their approval status.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Start upload progress animation
  void _startUploadProgress() {
    if (mounted) {
      setState(() {
        _currentStep = 0;
        _uploadStatus = _uploadSteps[0];
      });
    }

    Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted || !_isUploading) {
        timer.cancel();
        return;
      }

      if (_currentStep < _uploadSteps.length - 1) {
        if (mounted) {
          setState(() {
            _currentStep++;
            _uploadStatus = _uploadSteps[_currentStep];
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  // Camera upload
  Future<void> _pickAndUploadImageFromCamera() async {
    final image = await DocumentScanService.captureCroppedDocumentImage();
    if (image != null) {
      await _uploadImageToCloudinary(image);
    }
  }

  // Gallery upload
  Future<void> _pickAndUploadImageFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _uploadImageToCloudinary(image);
    }
  }

  // Show upload dialog
  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Upload Receipt',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF7E5EFD),
            ),
          ),
          content: const Text(
            'Choose how you want to upload your receipt:',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickAndUploadImageFromGallery();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, color: Color(0xFF7E5EFD)),
                  SizedBox(width: 8),
                  Text(
                    'Photos',
                    style: TextStyle(
                      color: Color(0xFF7E5EFD),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickAndUploadFile();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder, color: Color(0xFF7E5EFD)),
                  SizedBox(width: 8),
                  Text(
                    'Documents',
                    style: TextStyle(
                      color: Color(0xFF7E5EFD),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final isPdf = file.extension?.toLowerCase() == 'pdf';
      await _uploadFileToCloudinary(file, isPdf);
    }
  }

  Future<void> _uploadImageToCloudinary(dynamic image) async {
    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }

    _startUploadProgress();

    const cloudinaryUrl = 'https://api.cloudinary.com/v1_1/ds1lqhvc3/image/upload';
    const uploadPreset = 'receipt_uploads';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
        ..fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: image.name),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('file', image.path),
        );
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);

      if (response.statusCode == 200) {
        await _sendImageUrlToBackend(jsonResponse["secure_url"] ?? '');
      } else {
        throw Exception("Cloudinary error: ${jsonResponse['error']?['message'] ?? 'Unknown error'}");
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image. Please try again.')),
        );
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _uploadFileToCloudinary(PlatformFile file, bool isPdf) async {
    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }

    _startUploadProgress();

    final cloudinaryUrl = isPdf
        ? 'https://api.cloudinary.com/v1_1/ds1lqhvc3/raw/upload'
        : 'https://api.cloudinary.com/v1_1/ds1lqhvc3/image/upload';
    const uploadPreset = 'receipt_uploads';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
        ..fields['upload_preset'] = uploadPreset;

      if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
        );
      } else if (file.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path!, filename: file.name),
        );
      } else {
        throw Exception('File data not available');
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);

      if (response.statusCode == 200) {
        final url = jsonResponse["secure_url"] ?? '';
        if (isPdf) {
          await _sendPdfUrlToBackend(url);
        } else {
          await _sendImageUrlToBackend(url);
        }
      } else {
        throw Exception("Cloudinary error: ${jsonResponse['error']?['message'] ?? 'Unknown error'}");
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload file. Please try again.')),
        );
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  /// Upload receipt with OCR processing to workspace (User role)
  /// 
  /// WORKFLOW (per Workspace Receipts Guide):
  /// Step 1: Process OCR using /api/receipts/process-receipt (does NOT save receipt)
  /// Step 2: Save to workspace using /api/workspace/:workspaceId/receipts (SINGLE SOURCE OF TRUTH)
  /// 
  /// ⚠️ IMPORTANT:
  /// - Workspace receipts MUST use /api/workspace/:workspaceId/receipts
  /// - Regular /api/receipts endpoint is for personal receipts only (workspaceId = null)
  /// - OCR endpoint only processes images, it does NOT save receipts
  /// - User submissions will have status='pending' until manager approves
  Future<void> _sendImageUrlToBackend(String imageUrl) async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workspace ID is required')),
        );
      }
      return;
    }

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userCountry = userProvider.country ?? '';

      // ============================================================================
      // STEP 1: Process OCR (Does NOT save the receipt)
      // Endpoint: POST /api/receipts/process-receipt
      // Purpose: Extract receipt data from image using OCR
      // ============================================================================
      final ocrResponse = await ApiService.post(
        '/receipts/process-receipt',
        body: {
          'imageUrl': imageUrl,
          'userId': widget.userId,
          'country': userCountry,
        },
        token: widget.token,
        timeout: const Duration(seconds: 60),
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }

      if (ocrResponse.statusCode == 200 || ocrResponse.statusCode == 201) {
        final ocrBody = json.decode(ocrResponse.body);
        final receiptDetails = ocrBody["receiptDetails"] ?? ocrBody["receipt"];

        if (receiptDetails != null) {
          // ============================================================================
          // STEP 2: Save to workspace (SINGLE SOURCE OF TRUTH)
          // Endpoint: POST /api/workspace/:workspaceId/receipts
          // Purpose: Save OCR-processed receipt to workspace
          // Status: Will be 'pending' until added to an approved expense report
          // ============================================================================
          final imageLink = receiptDetails['imageUrl'] ?? receiptDetails['pdfUrl'] ?? '';
          final receiptDate = receiptDetails['receiptDate'] ?? DateFormat('MM-dd-yyyy').format(DateTime.now());
          
          // Convert date to ISO format (YYYY-MM-DDTHH:mm:ssZ) as required by workspace API
          DateTime? parsedDate;
          try {
            if (receiptDate.contains('T')) {
              parsedDate = DateTime.parse(receiptDate);
            } else {
              parsedDate = DateFormat('MM-dd-yyyy').parse(receiptDate);
            }
          } catch (e) {
            parsedDate = DateTime.now();
          }
          final formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);

          // Save to workspace using the ONLY correct endpoint for workspace receipts
          final saveResult = await WorkspaceService.submitWorkspaceReceipt(
            workspaceId: widget.workspaceId!,
            userId: widget.userId,
            body: {
              // Required fields
              'merchant': receiptDetails['merchant']?.toString() ?? '',
              'amount': double.tryParse(receiptDetails['amount']?.toString() ?? '0') ?? 0.0,
              'date': formattedDate,
              // Optional fields
              'category': receiptDetails['category']?.toString() ?? 'Other',
              if (imageLink.isNotEmpty) 'imageLink': imageLink,  // Encrypted image URL
              if (receiptDetails['description'] != null) 'description': receiptDetails['description'],
            },
            token: widget.token,
          );

          if (mounted) {
            if (saveResult['success'] == true) {
              // Extract receipt data from POST response
              // Response format: { "success": true, "data": { "id": 418, "merchant": "Elite fitness club", ... } }
              final receiptData = saveResult['data'];
              
              // Add to recent submissions list immediately for instant UI update
              if (receiptData != null) {
                setState(() {
                  // Transform POST response to match _buildRecentSubmissionCard format
                  _recentSubmissions.insert(0, {
                    'id': receiptData['id']?.toString() ?? '',
                    'title': receiptData['merchant']?.toString() ?? 'Receipt',
                    'category': receiptData['category']?.toString() ?? '',
                    'status': receiptData['status']?.toString() ?? 'pending',
                    'amount': receiptData['amount'],
                    'date': receiptData['submittedAt']?.toString() ?? DateTime.now().toIso8601String(),
                  });
                  // Keep only last 10 items for performance
                  if (_recentSubmissions.length > 10) {
                    _recentSubmissions = _recentSubmissions.take(10).toList();
                  }
                });
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Receipt uploaded to workspace successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              // Refresh full dashboard data in background
              await _loadDashboard();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(saveResult['error']?.toString() ?? 'Failed to save receipt to workspace'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          throw Exception('Unexpected response structure: Missing receiptDetails');
        }
      } else {
        final error = json.decode(ocrResponse.body)['error'] ?? 'Unknown error';
        throw Exception('OCR processing error: $error');
      }
    } catch (e) {
      debugPrint("Backend Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  /// Upload PDF receipt with OCR processing to workspace (User role)
  /// 
  /// WORKFLOW (per Workspace Receipts Guide):
  /// Step 1: Process OCR using /api/receipts/process-receipt (does NOT save receipt)
  /// Step 2: Save to workspace using /api/workspace/:workspaceId/receipts (SINGLE SOURCE OF TRUTH)
  Future<void> _sendPdfUrlToBackend(String pdfUrl) async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workspace ID is required')),
        );
      }
      return;
    }

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userCountry = userProvider.country ?? '';

      // ============================================================================
      // STEP 1: Process OCR from PDF (Does NOT save the receipt)
      // Endpoint: POST /api/receipts/process-receipt
      // Purpose: Extract receipt data from PDF using OCR
      // ============================================================================
      final ocrResponse = await ApiService.post(
        '/receipts/process-receipt',
        body: {
          'pdfUrl': pdfUrl,  // Use pdfUrl instead of imageUrl
          'userId': widget.userId,
          'country': userCountry,
        },
        token: widget.token,
        timeout: const Duration(seconds: 60),
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }

      if (ocrResponse.statusCode == 200 || ocrResponse.statusCode == 201) {
        final ocrBody = json.decode(ocrResponse.body);
        final receiptDetails = ocrBody["receiptDetails"] ?? ocrBody["receipt"];

        if (receiptDetails != null) {
          // ============================================================================
          // STEP 2: Save to workspace (SINGLE SOURCE OF TRUTH)
          // Endpoint: POST /api/workspace/:workspaceId/receipts
          // Purpose: Save OCR-processed receipt to workspace
          // ============================================================================
          final imageLink = receiptDetails['imageUrl'] ?? receiptDetails['pdfUrl'] ?? '';
          final receiptDate = receiptDetails['receiptDate'] ?? DateFormat('MM-dd-yyyy').format(DateTime.now());
          
          // Convert date to ISO format as required by workspace API
          DateTime? parsedDate;
          try {
            if (receiptDate.contains('T')) {
              parsedDate = DateTime.parse(receiptDate);
            } else {
              parsedDate = DateFormat('MM-dd-yyyy').parse(receiptDate);
            }
          } catch (e) {
            parsedDate = DateTime.now();
          }
          final formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);

          // Save to workspace using the ONLY correct endpoint for workspace receipts
          final saveResult = await WorkspaceService.submitWorkspaceReceipt(
            workspaceId: widget.workspaceId!,
            userId: widget.userId,
            body: {
              // Required fields
              'merchant': receiptDetails['merchant']?.toString() ?? '',
              'amount': double.tryParse(receiptDetails['amount']?.toString() ?? '0') ?? 0.0,
              'date': formattedDate,
              // Optional fields
              'category': receiptDetails['category']?.toString() ?? 'Other',
              if (imageLink.isNotEmpty) 'imageLink': imageLink,  // Encrypted PDF URL
              if (receiptDetails['description'] != null) 'description': receiptDetails['description'],
            },
            token: widget.token,
          );

          if (mounted) {
            if (saveResult['success'] == true) {
              // Extract receipt data from POST response
              final receiptData = saveResult['data'];
              
              // Add to recent submissions list immediately for instant UI update
              if (receiptData != null) {
                setState(() {
                  // Transform POST response to match _buildRecentSubmissionCard format
                  _recentSubmissions.insert(0, {
                    'id': receiptData['id']?.toString() ?? '',
                    'title': receiptData['merchant']?.toString() ?? 'Receipt',
                    'category': receiptData['category']?.toString() ?? '',
                    'status': receiptData['status']?.toString() ?? 'pending',
                    'amount': receiptData['amount'],
                    'date': receiptData['submittedAt']?.toString() ?? DateTime.now().toIso8601String(),
                  });
                  // Keep only last 10 items for performance
                  if (_recentSubmissions.length > 10) {
                    _recentSubmissions = _recentSubmissions.take(10).toList();
                  }
                });
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Receipt uploaded to workspace successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              // Refresh full dashboard data in background
              await _loadDashboard();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(saveResult['error']?.toString() ?? 'Failed to save receipt to workspace'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          throw Exception('Unexpected response structure: Missing receiptDetails');
        }
      } else {
        final error = json.decode(ocrResponse.body)['error'] ?? 'Unknown error';
        throw Exception('OCR processing error: $error');
      }
    } catch (e) {
      debugPrint("Backend Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isUploading = false;
        });
      }
    }
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
            debugPrint('🔓 Workspace Dashboard - Decrypted image URL: $decryptedImageUrl');
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

        // Refresh dashboard if receipt was modified
        if (result == true && mounted) {
          await _loadDashboard();
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

  // Navigate to manual receipt entry
  void _createManualReceipt() async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace ID is required')),
      );
      return;
    }

    debugPrint('Creating manual receipt for workspace');
    _showManualReceiptDialog();
  }

  void _showManualReceiptDialog() {
    final merchantController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final dateController = TextEditingController(
      text: DateFormat('MM-dd-yyyy').format(selectedDate),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Add Manual Receipt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: merchantController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant *',
                    hintText: 'Enter merchant name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount *',
                    hintText: 'Enter amount',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    hintText: 'Enter category',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && picked != selectedDate) {
                      setDialogState(() {
                        selectedDate = picked;
                        dateController.text = DateFormat('MM-dd-yyyy').format(picked);
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        hintText: 'Select date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (merchantController.text.trim().isEmpty ||
                    amountController.text.trim().isEmpty ||
                    categoryController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Convert date to yyyy-MM-dd format
                String formattedDate;
                try {
                  final parsedDate = DateFormat('MM-dd-yyyy').parse(dateController.text.trim());
                  formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
                } catch (e) {
                  formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
                }

                Navigator.pop(context);

                // Show loading
                setState(() {
                  _isUploading = true;
                });

                try {
                  final saveResult = await WorkspaceService.submitWorkspaceReceipt(
                    workspaceId: widget.workspaceId!,
                    userId: widget.userId,
                    body: {
                      'merchant': merchantController.text.trim(),
                      'amount': amount,
                      'date': formattedDate,
                      'category': categoryController.text.trim(),
                      if (descriptionController.text.trim().isNotEmpty)
                        'description': descriptionController.text.trim(),
                    },
                    token: widget.token,
                  );

                  if (mounted) {
                    if (saveResult['success'] == true) {
                      final receiptData = saveResult['data'];
                      
                      // Add to recent submissions list immediately
                      if (receiptData != null) {
                        setState(() {
                          _recentSubmissions.insert(0, {
                            'id': receiptData['id']?.toString() ?? '',
                            'title': receiptData['merchant']?.toString() ?? 'Receipt',
                            'category': receiptData['category']?.toString() ?? '',
                            'status': receiptData['status']?.toString() ?? 'pending',
                            'amount': receiptData['amount'],
                            'date': receiptData['submittedAt']?.toString() ?? DateTime.now().toIso8601String(),
                          });
                          if (_recentSubmissions.length > 10) {
                            _recentSubmissions = _recentSubmissions.take(10).toList();
                          }
                        });
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Manual receipt added successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      await _loadDashboard();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(saveResult['error']?.toString() ?? 'Failed to add receipt'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  debugPrint('Error creating manual receipt: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create receipt: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isUploading = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

