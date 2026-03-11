import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
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
import 'workspace_expense_approval_screen.dart';
import 'workspace_needs_requests_screen.dart';
import 'workspace_team_members_screen.dart';
import 'receipt_details_screen.dart';

class WorkspaceManagerDashboardScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String workspaceId;

  const WorkspaceManagerDashboardScreen({
    Key? key,
    required this.userId,
    required this.token,
    required this.workspaceId,
  }) : super(key: key);

  @override
  State<WorkspaceManagerDashboardScreen> createState() => _WorkspaceManagerDashboardScreenState();
}

class _WorkspaceManagerDashboardScreenState extends State<WorkspaceManagerDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUploading = false;
  
  // Summary data
  int? _pendingApprovals;
  double? _monthlySpend;
  int? _teamMembersCount;
  int? _needsRequestsCount;
  
  // Recent activity
  List<Map<String, dynamic>> _recentActivity = [];
  
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

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await WorkspaceService.getManagerDashboard(
        workspaceId: widget.workspaceId,
        userId: widget.userId,
        token: widget.token,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Handle nested response structure
        // API returns: { "success": true, "data": { "summary": {...}, "recentActivity": [...] } }
        // Service wraps it: { "success": true, "data": <decoded response> }
        final responseData = result['data'];
        Map<String, dynamic>? data;
        
        if (responseData is Map<String, dynamic>) {
          // Check if nested (has 'data' key)
          if (responseData.containsKey('data') && responseData['data'] is Map) {
            data = responseData['data'] as Map<String, dynamic>?;
          } else if (responseData.containsKey('summary')) {
            // Direct structure
            data = responseData;
          }
        }
        
        final summary = data?['summary'] as Map<String, dynamic>?;
        final recentActivity = data?['recentActivity'] as List<dynamic>?;

        setState(() {
          // Map summary values
          _pendingApprovals = _parseInt(summary?['pendingApprovals']);
          _monthlySpend = _parseDouble(summary?['monthlySpend']);
          _teamMembersCount = _parseInt(summary?['teamMembersCount']);
          _needsRequestsCount = _parseInt(summary?['needsRequestsCount']);
          
          // Map recent activity
          _recentActivity = recentActivity?.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            }
            return <String, dynamic>{};
          }).toList() ?? [];
          
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error']?.toString() ?? 'Failed to load dashboard';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading manager dashboard: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load dashboard: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF905CFF), Color(0xFF7A4BD9)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'MR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TeamHub Manager',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Manager',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Consumer<UserProvider>(
                        builder: (context, userProvider, child) {
                          final userName = userProvider.username ?? 'Manager';
                          final firstName = userName.split(' ').first;
                          return Text(
                            'Welcome, $firstName! 👋',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Manage team expenses and approvals',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Stat cards 2x2
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Pending Approvals',
                              value: _pendingApprovals?.toString() ?? '0',
                              borderColor: const Color(0xFF7E5EFD),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Monthly Spend',
                              value: _monthlySpend != null
                                  ? '₹${_monthlySpend!.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}' 
                                  : '₹0',
                              borderColor: const Color(0xFF7E5EFD),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Team Members',
                              value: _teamMembersCount?.toString() ?? '0',
                              borderColor: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Needs Requests',
                              value: _needsRequestsCount?.toString() ?? '0',
                              borderColor: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

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

                      // Quick actions row
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              emoji: '✅',
                              label: 'Approve\nExpenses',
                              borderColor: Colors.green,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WorkspaceExpenseApprovalScreen(
                                      userId: widget.userId,
                                      token: widget.token,
                                      workspaceId: widget.workspaceId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              emoji: '👥',
                              label: 'Team\nMembers',
                              borderColor: const Color(0xFF7E5EFD),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WorkspaceTeamMembersScreen(
                                      userId: widget.userId,
                                      token: widget.token,
                                      workspaceId: widget.workspaceId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
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
                                      workspaceId: widget.workspaceId,
                                      isManager: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

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
                            child: _buildActionCard(
                              emoji: '📷',
                              label: 'Scan',
                              borderColor: const Color(0xFF7E5EFD),
                              onTap: _isUploading ? null : _pickAndUploadImageFromCamera,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              emoji: '📤',
                              label: 'Upload',
                              borderColor: Colors.green,
                              onTap: _isUploading ? null : _showUploadDialog,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              emoji: '📝',
                              label: 'Manual',
                              borderColor: Colors.blue,
                              onTap: _isUploading ? null : _createManualReceipt,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Recent Uploads
                      const Text(
                        'Recent Uploads',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your latest receipts at a glance!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_recentActivity.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 56,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No recent activity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Receipts will appear here',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._recentActivity.map((activity) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildActivityCard(activity),
                            )),
                    ],
                  ),
                ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final type = activity['type']?.toString() ?? '';
    final title = activity['title']?.toString() ?? 'Activity';
    final description = activity['description']?.toString() ?? '';
    final timestamp = activity['timestamp']?.toString() ?? '';
    final amount = activity['amount']?.toString() ?? '';
    final status = activity['status']?.toString() ?? '';

    // Format date
    String formattedDate = '';
    if (timestamp.isNotEmpty) {
      try {
        final date = DateTime.parse(timestamp);
        formattedDate = DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        formattedDate = timestamp;
      }
    }

    // Get emoji and colors based on activity type
    String emoji = '📄';
    Color borderColor = const Color(0xFF7E5EFD);
    Color statusColor = Colors.orange;
    String statusLabel = 'Pending';
    
    if (type.contains('expense')) {
      emoji = '🍽️';
      borderColor = const Color(0xFF7E5EFD);
    } else if (type.contains('member')) {
      emoji = '👤';
      borderColor = Colors.green;
    } else if (type.contains('approval')) {
      emoji = '✅';
      borderColor = Colors.green;
    }

    if (status.toLowerCase().contains('approved')) {
      statusColor = Colors.green;
      statusLabel = 'Approved';
    } else if (status.toLowerCase().contains('rejected')) {
      statusColor = Colors.red;
      statusLabel = 'Rejected';
    }

    return Container(
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: borderColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (formattedDate.isNotEmpty)
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (amount.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '₹$amount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color borderColor,
  }) {
    return Container(
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
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
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
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: borderColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
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

  /// Upload receipt with OCR processing to workspace
  /// 
  /// WORKFLOW (per Workspace Receipts Guide):
  /// Step 1: Process OCR using /api/receipts/process-receipt (does NOT save receipt)
  /// Step 2: Save to workspace using /api/workspace/:workspaceId/receipts (SINGLE SOURCE OF TRUTH)
  /// 
  /// ⚠️ IMPORTANT:
  /// - Workspace receipts MUST use /api/workspace/:workspaceId/receipts
  /// - Regular /api/receipts endpoint is for personal receipts only (workspaceId = null)
  /// - OCR endpoint only processes images, it does NOT save receipts
  Future<void> _sendImageUrlToBackend(String imageUrl) async {
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
            workspaceId: widget.workspaceId,
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
              
              // Add to recent activity list immediately for instant UI update
              if (receiptData != null) {
                setState(() {
                  // Transform POST response to match _buildActivityCard format
                  _recentActivity.insert(0, {
                    'type': 'expense',  // Type for emoji selection (🍽️)
                    'title': receiptData['merchant']?.toString() ?? 'Receipt',
                    'description': receiptData['category']?.toString() ?? '',
                    'timestamp': receiptData['submittedAt']?.toString() ?? DateTime.now().toIso8601String(),
                    'amount': receiptData['amount']?.toString() ?? '0',
                    'status': receiptData['status']?.toString() ?? 'pending',
                  });
                  // Keep only last 10 items for performance
                  if (_recentActivity.length > 10) {
                    _recentActivity = _recentActivity.take(10).toList();
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

  /// Upload PDF receipt with OCR processing to workspace
  /// 
  /// WORKFLOW (per Workspace Receipts Guide):
  /// Step 1: Process OCR using /api/receipts/process-receipt (does NOT save receipt)
  /// Step 2: Save to workspace using /api/workspace/:workspaceId/receipts (SINGLE SOURCE OF TRUTH)
  Future<void> _sendPdfUrlToBackend(String pdfUrl) async {
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
            workspaceId: widget.workspaceId,
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
              // Response format: { "success": true, "data": { "id": 418, "merchant": "Elite fitness club", ... } }
              final receiptData = saveResult['data'];
              
              // Add to recent activity list immediately for instant UI update
              if (receiptData != null) {
                setState(() {
                  // Transform POST response to match _buildActivityCard format
                  _recentActivity.insert(0, {
                    'type': 'expense',  // Type for emoji selection (🍽️)
                    'title': receiptData['merchant']?.toString() ?? 'Receipt',
                    'description': receiptData['category']?.toString() ?? '',
                    'timestamp': receiptData['submittedAt']?.toString() ?? DateTime.now().toIso8601String(),
                    'amount': receiptData['amount']?.toString() ?? '0',
                    'status': receiptData['status']?.toString() ?? 'pending',
                  });
                  // Keep only last 10 items for performance
                  if (_recentActivity.length > 10) {
                    _recentActivity = _recentActivity.take(10).toList();
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

  // Navigate to manual receipt entry
  void _createManualReceipt() async {
    debugPrint('Creating manual receipt for workspace');

    // For manager dashboard, we'll show a dialog to enter receipt details
    // and then save directly to workspace
    _showManualReceiptDialog();
  }

  void _showManualReceiptDialog() {
    final merchantController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount *',
                    hintText: 'Enter amount',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    hintText: 'Enter category',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional description',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text('Date: ${DateFormat('MM-dd-yyyy').format(selectedDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                      });
                    }
                  },
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
                final merchant = merchantController.text.trim();
                final amount = double.tryParse(amountController.text.trim());
                final category = categoryController.text.trim();
                final description = descriptionController.text.trim();

                if (merchant.isEmpty || amount == null || category.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }

                Navigator.pop(context);

                // Save to workspace
                final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
                final saveResult = await WorkspaceService.submitWorkspaceReceipt(
                  workspaceId: widget.workspaceId,
                  userId: widget.userId,
                  body: {
                    'merchant': merchant,
                    'amount': amount,
                    'category': category,
                    'date': formattedDate,
                    if (description.isNotEmpty) 'description': description,
                  },
                  token: widget.token,
                );

                if (mounted) {
                  if (saveResult['success'] == true) {
                    // Extract receipt data from POST response
                    final receiptData = saveResult['data'];
                    
                    // Add to recent activity list immediately for instant UI update
                    if (receiptData != null) {
                      setState(() {
                        // Transform POST response to match _buildActivityCard format
                        _recentActivity.insert(0, {
                          'type': 'expense',  // Type for emoji selection (🍽️)
                          'title': receiptData['merchant']?.toString() ?? 'Receipt',
                          'description': receiptData['category']?.toString() ?? '',
                          'timestamp': receiptData['submittedAt']?.toString() ?? DateTime.now().toIso8601String(),
                          'amount': receiptData['amount']?.toString() ?? '0',
                          'status': receiptData['status']?.toString() ?? 'pending',
                        });
                        // Keep only last 10 items for performance
                        if (_recentActivity.length > 10) {
                          _recentActivity = _recentActivity.take(10).toList();
                        }
                      });
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Receipt added to workspace successfully!'),
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


