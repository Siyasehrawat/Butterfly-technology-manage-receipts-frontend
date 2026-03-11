import 'package:flutter/material.dart';
import '../../services/workspace_service.dart';
import 'package:intl/intl.dart';

/// Workspace Receipts Screen - Web Optimized
/// Owner/Manager view to view and manage all workspace receipts
class WorkspaceReceiptsWebScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String workspaceId;

  const WorkspaceReceiptsWebScreen({
    Key? key,
    required this.userId,
    required this.token,
    required this.workspaceId,
  }) : super(key: key);

  @override
  State<WorkspaceReceiptsWebScreen> createState() => _WorkspaceReceiptsWebScreenState();
}

class _WorkspaceReceiptsWebScreenState extends State<WorkspaceReceiptsWebScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  
  // Filters
  String _selectedDateRange = 'Last 30 days';
  String _selectedCategory = 'All categories';
  String _selectedStatus = 'All statuses';
  String _selectedTeamMember = 'All members';
  
  // Data
  List<Map<String, dynamic>> _receipts = [];
  List<Map<String, dynamic>> _teamMembers = [];
  List<String> _categories = [];
  Set<String> _selectedReceiptIds = {};
  bool _isSelectAll = false;

  // Pagination
  int _currentPage = 1;
  int _pageSize = 50;
  int _totalCount = 0;
  bool _hasNextPage = false;
  bool _hasPrevPage = false;

  final List<Color> _userColors = [
    const Color(0xFF10B981),
    const Color(0xFF8B5CF6),
    const Color(0xFFF59E0B),
    const Color(0xFF3B82F6),
    const Color(0xFFEC4899),
    const Color(0xFF6366F1),
  ];

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
    _loadReceipts();
  }

  Future<void> _loadTeamMembers() async {
    try {
      final result = await WorkspaceService.listMembers(
        workspaceId: widget.workspaceId,
        userId: widget.userId,
        token: widget.token,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final members = data['members'] as List<dynamic>? ?? [];

        setState(() {
          _teamMembers = members.map((item) {
            final member = item as Map<String, dynamic>;
            final name = member['name'] ?? member['userName'] ?? 'Unknown';
            final initials = _getInitials(name);
            final colorIndex = name.hashCode.abs() % _userColors.length;
            
            return {
              'id': member['id'] ?? member['_id'] ?? '',
              'name': name,
              'email': member['email'] ?? member['userEmail'] ?? '',
              'initials': initials,
              'color': _userColors[colorIndex],
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading team members: $e');
    }
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Build query parameters for /receipts/all endpoint
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'pageSize': _pageSize.toString(),
      };

      // Add status filter
      if (_selectedStatus != 'All statuses') {
        queryParams['status'] = _selectedStatus.toLowerCase();
      }

      // Add category filter
      if (_selectedCategory != 'All categories') {
        queryParams['category'] = _selectedCategory;
      }

      // Add team member filter (use memberId instead of userId)
      if (_selectedTeamMember != 'All members') {
        final member = _teamMembers.firstWhere(
          (m) => m['name'] == _selectedTeamMember,
          orElse: () => {},
        );
        if (member.isNotEmpty && member['id'] != null) {
          queryParams['memberId'] = member['id'] as String;
        }
      }

      // Add date range filter (use dateFrom/dateTo instead of fromDate/toDate)
      if (_selectedDateRange != 'All time') {
        final dateRange = _getDateRange(_selectedDateRange);
        if (dateRange['from'] != null) {
          queryParams['dateFrom'] = dateRange['from']!;
        }
        if (dateRange['to'] != null) {
          queryParams['dateTo'] = dateRange['to']!;
        }
      }

      final result = await WorkspaceService.listAllWorkspaceReceipts(
        workspaceId: widget.workspaceId,
        userId: widget.userId,
        query: queryParams,
        token: widget.token,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final receipts = data['receipts'] as List<dynamic>? ?? [];
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        // Extract categories from receipts
        final categorySet = <String>{};
        for (var receipt in receipts) {
          final category = (receipt as Map<String, dynamic>)['category']?.toString();
          if (category != null && category.isNotEmpty) {
            categorySet.add(category);
          }
        }
        final categoriesList = categorySet.toList()..sort();

        setState(() {
          _receipts = receipts.map((item) => _parseReceipt(item)).toList();
          _categories = ['All categories', ...categoriesList];
          _totalCount = pagination['totalCount'] as int? ?? receipts.length;
          _currentPage = pagination['page'] as int? ?? 1;
          _hasNextPage = pagination['hasNextPage'] as bool? ?? false;
          _hasPrevPage = pagination['hasPrevPage'] as bool? ?? false;
          _isLoading = false;
          _selectedReceiptIds.clear();
          _isSelectAll = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error']?.toString() ?? 'Failed to load receipts';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _parseReceipt(dynamic item) {
    final receipt = item as Map<String, dynamic>;
    
    // Parse uploadedBy object (new format: { "id": "uuid", "name": "John Doe", "email": "john@example.com" })
    final uploadedBy = receipt['uploadedBy'] as Map<String, dynamic>? ?? {};
    final userId = uploadedBy['id']?.toString() ?? receipt['userId']?.toString() ?? '';
    final userName = uploadedBy['name']?.toString() ?? 
                     receipt['userName']?.toString() ?? 
                     receipt['uploadedBy']?.toString() ?? 
                     'Unknown User';
    final userEmail = uploadedBy['email']?.toString() ?? '';
    final initials = _getInitials(userName);
    final colorIndex = userName.hashCode.abs() % _userColors.length;

    // Format date (API returns YYYY-MM-DD format)
    String formattedDate = '';
    try {
      final dateStr = receipt['date']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        DateTime dateTime;
        if (dateStr.contains('T')) {
          dateTime = DateTime.parse(dateStr);
        } else {
          // Handle YYYY-MM-DD format
          dateTime = DateTime.parse(dateStr);
        }
        formattedDate = DateFormat('MMM d, yyyy').format(dateTime);
      }
    } catch (e) {
      formattedDate = receipt['date']?.toString() ?? '';
    }

    // Format receipt ID (may not be present in response, use index or generate)
    final receiptId = receipt['id']?.toString() ?? '';
    final displayId = receiptId.isNotEmpty && receiptId.length > 8 
        ? '#RCT-${receiptId.substring(0, 8).toUpperCase()}'
        : receiptId.isNotEmpty
            ? '#RCT-${receiptId.toUpperCase()}'
            : '#RCT-UNKNOWN';

    return {
      'id': receiptId.isNotEmpty ? receiptId : DateTime.now().millisecondsSinceEpoch.toString(),
      'displayId': displayId,
      'merchant': receipt['merchant']?.toString() ?? 'Unknown Merchant',
      'amount': (receipt['amount'] as num?)?.toDouble() ?? 0.0,
      'category': receipt['category']?.toString() ?? 'Other',
      'date': formattedDate,
      'status': (receipt['status']?.toString() ?? 'pending').toLowerCase(),
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userInitials': initials,
      'userColor': _userColors[colorIndex],
      'imageLink': receipt['imageLink'],
      'expenseReportId': receipt['expenseReportId'],
    };
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[parts.length - 1].substring(0, 1)}'.toUpperCase();
  }

  Map<String, String?> _getDateRange(String range) {
    final now = DateTime.now();
    switch (range) {
      case 'Last 7 days':
        return {
          'from': DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 7))),
          'to': DateFormat('yyyy-MM-dd').format(now),
        };
      case 'Last 30 days':
        return {
          'from': DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 30))),
          'to': DateFormat('yyyy-MM-dd').format(now),
        };
      case 'Last 90 days':
        return {
          'from': DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 90))),
          'to': DateFormat('yyyy-MM-dd').format(now),
        };
      case 'This month':
        return {
          'from': DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1)),
          'to': DateFormat('yyyy-MM-dd').format(now),
        };
      case 'Last month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 0);
        return {
          'from': DateFormat('yyyy-MM-dd').format(lastMonth),
          'to': DateFormat('yyyy-MM-dd').format(lastMonthEnd),
        };
      default:
        return {'from': null, 'to': null};
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _isSelectAll = value ?? false;
      if (_isSelectAll) {
        _selectedReceiptIds = Set.from(_receipts.map((r) => r['id'] as String));
      } else {
        _selectedReceiptIds.clear();
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
      _isSelectAll = _selectedReceiptIds.length == _receipts.length;
    });
  }

  void _applyFilters() {
    _currentPage = 1;
    _loadReceipts();
  }

  void _exportReceipts() {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon')),
    );
  }

  void _exportSelected() {
    if (_selectedReceiptIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select receipts to export')),
      );
      return;
    }
    // TODO: Implement export selected functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting ${_selectedReceiptIds.length} receipts...')),
    );
  }

  void _printReceipts() {
    if (_selectedReceiptIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select receipts to print')),
      );
      return;
    }
    // TODO: Implement print functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Printing ${_selectedReceiptIds.length} receipts...')),
    );
  }

  void _deleteReceipts() {
    if (_selectedReceiptIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select receipts to delete')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipts'),
        content: Text('Are you sure you want to delete ${_selectedReceiptIds.length} receipt(s)? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement delete functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleting ${_selectedReceiptIds.length} receipts...')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Container(
        color: const Color(0xFFF9FAFB),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadReceipts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF9FAFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(32),
            color: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'All Receipts',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'View and manage all receipts uploaded by team members',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _exportReceipts,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export Receipts'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    'Date Range',
                    _selectedDateRange,
                    ['All time', 'Last 7 days', 'Last 30 days', 'Last 90 days', 'This month', 'Last month'],
                    (value) {
                      setState(() {
                        _selectedDateRange = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFilterDropdown(
                    'Category',
                    _selectedCategory,
                    _categories.isEmpty ? ['All categories'] : _categories,
                    (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFilterDropdown(
                    'Status',
                    _selectedStatus,
                    ['All statuses', 'Pending', 'Approved', 'Rejected'],
                    (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFilterDropdown(
                    'Team Member',
                    _selectedTeamMember,
                    ['All members', ..._teamMembers.map((m) => m['name'] as String)],
                    (value) {
                      setState(() {
                        _selectedTeamMember = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: const Text('Apply Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Actions Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Checkbox(
                  value: _isSelectAll,
                  onChanged: _toggleSelectAll,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select all $_totalCount receipts',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
                const Spacer(),
                if (_selectedReceiptIds.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: _exportSelected,
                    icon: const Icon(Icons.download, size: 18),
                    label: Text('Export Selected (${_selectedReceiptIds.length})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _printReceipts,
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Print'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _deleteReceipts,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Receipts Table
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: Row(
                        children: const [
                          SizedBox(width: 48),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Receipt',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Amount',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Merchant',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Uploaded By',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text(
                              'Actions',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _receipts.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 64,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No receipts found',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try adjusting your filters',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _receipts.length,
                                  itemBuilder: (context, index) {
                                    final receipt = _receipts[index];
                                    final isSelected = _selectedReceiptIds.contains(receipt['id']);
                                    final status = receipt['status'] as String;
                                    final statusColor = _getStatusColor(status);

                                    return Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: index < _receipts.length - 1
                                                ? const Color(0xFFE5E7EB)
                                                : Colors.transparent,
                                          ),
                                        ),
                                        color: isSelected
                                            ? const Color(0xFFEEF2FF).withOpacity(0.5)
                                            : Colors.transparent,
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          // TODO: Navigate to receipt details
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 16,
                                          ),
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: isSelected,
                                                onChanged: (value) {
                                                  _toggleReceiptSelection(receipt['id'] as String);
                                                },
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF6366F1).withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Icon(
                                                        Icons.receipt_long,
                                                        size: 20,
                                                        color: Color(0xFF6366F1),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            receipt['displayId'] as String,
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w600,
                                                              color: Color(0xFF111827),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            receipt['merchant'] as String,
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              color: Color(0xFF6B7280),
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  receipt['date'] as String,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF374151),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  '\$${((receipt['amount'] as double).toStringAsFixed(2))}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF111827),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  receipt['category'] as String,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF374151),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  receipt['merchant'] as String,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF374151),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: receipt['userColor'] as Color,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          receipt['userInitials'] as String,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        receipt['userName'] as String,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Color(0xFF374151),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    status[0].toUpperCase() + status.substring(1),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 120,
                                                child: Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.visibility_outlined, size: 18),
                                                      color: const Color(0xFF6B7280),
                                                      onPressed: () {
                                                        // TODO: View receipt
                                                      },
                                                      tooltip: 'View',
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                                      color: const Color(0xFF6B7280),
                                                      onPressed: () {
                                                        // TODO: Edit receipt
                                                      },
                                                      tooltip: 'Edit',
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 18),
                                                      color: Colors.red,
                                                      onPressed: () {
                                                        _toggleReceiptSelection(receipt['id'] as String);
                                                        _deleteReceipts();
                                                      },
                                                      tooltip: 'Delete',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),

                    // Pagination
                    if (!_isLoading && _receipts.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing ${((_currentPage - 1) * _pageSize) + 1}-${((_currentPage - 1) * _pageSize) + _receipts.length} of $_totalCount receipts',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: _hasPrevPage
                                      ? () {
                                          setState(() {
                                            _currentPage--;
                                          });
                                          _loadReceipts();
                                        }
                                      : null,
                                ),
                                Text(
                                  'Page $_currentPage',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: _hasNextPage
                                      ? () {
                                          setState(() {
                                            _currentPage++;
                                          });
                                          _loadReceipts();
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF111827),
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF111827),
        ),
      ),
    );
  }
}

