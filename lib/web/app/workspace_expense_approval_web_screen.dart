import 'package:flutter/material.dart';
import '../../services/workspace_service.dart';

/// Workspace Expense Approvals Screen - Web Optimized
/// Owner/Manager view to review and approve team expense submissions
class WorkspaceExpenseApprovalWebScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String workspaceId;

  const WorkspaceExpenseApprovalWebScreen({
    Key? key,
    required this.userId,
    required this.token,
    required this.workspaceId,
  }) : super(key: key);

  @override
  State<WorkspaceExpenseApprovalWebScreen> createState() => _WorkspaceExpenseApprovalWebScreenState();
}

class _WorkspaceExpenseApprovalWebScreenState extends State<WorkspaceExpenseApprovalWebScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedTab = 'pending'; // pending, approved, rejected
  
  List<Map<String, dynamic>> _expenses = [];

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
    _loadApprovals();
  }

  Future<void> _loadApprovals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await WorkspaceService.listApprovals(
        workspaceId: widget.workspaceId,
        userId: widget.userId,
        query: {'status': _selectedTab},
        token: widget.token,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final approvals = data['approvals'] as List<dynamic>? ?? [];

        setState(() {
          _expenses = approvals.map((item) => _parseExpense(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error']?.toString() ?? 'Failed to load approvals';
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

  Map<String, dynamic> _parseExpense(dynamic item) {
    final expense = item as Map<String, dynamic>;
    final userName = expense['userName'] as String? ?? 'Unknown User';
    final initials = _getInitials(userName);
    final colorIndex = userName.hashCode.abs() % _userColors.length;

    return {
      'id': expense['id'] ?? expense['_id'] ?? '',
      'user': userName,
      'userInitials': initials,
      'userColor': _userColors[colorIndex],
      'receipt': expense['description'] ?? expense['title'] ?? 'No description',
      'amount': (expense['amount'] as num?)?.toDouble() ?? 0.0,
      'category': expense['category'] ?? 'Other',
      'notes': expense['notes'] ?? expense['comment'] ?? '',
      'status': expense['status'] ?? _selectedTab,
      'date': expense['date'] ?? expense['createdAt'] ?? '',
    };
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[parts.length - 1].substring(0, 1)}'.toUpperCase();
  }

  List<Map<String, dynamic>> get _filteredExpenses {
    return _expenses.where((e) => e['status'] == _selectedTab).toList();
  }

  int get _submittedCount => _expenses.where((e) => e['status'] == 'pending').length;
  int get _approvedCount => _expenses.where((e) => e['status'] == 'approved').length;
  int get _rejectedCount => _expenses.where((e) => e['status'] == 'rejected').length;

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
                onPressed: _loadApprovals,
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
                      'Expense Approvals',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Review and approve team expense submissions',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _approveAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Approve All'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                _buildTab('Pending', 'pending', _submittedCount),
                const SizedBox(width: 16),
                _buildTab('Approved', 'approved', _approvedCount),
                const SizedBox(width: 16),
                _buildTab('Rejected', 'rejected', _rejectedCount),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Expense Table
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
                          Expanded(
                            flex: 2,
                            child: Text(
                              'User',
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
                            flex: 1,
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
                            flex: 1,
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
                              'Notes',
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
                      child: _filteredExpenses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 64,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No $_selectedTab expenses',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredExpenses.length,
                              itemBuilder: (context, index) {
                                final expense = _filteredExpenses[index];
                                return _buildExpenseRow(expense);
                              },
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

  Widget _buildTab(String label, String value, int count) {
    final isSelected = _selectedTab == value;
    return InkWell(
      onTap: () {
        if (_selectedTab != value) {
          setState(() {
            _selectedTab = value;
          });
          _loadApprovals();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.1) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF6366F1) 
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseRow(Map<String, dynamic> expense) {
    final showActions = expense['status'] == 'pending';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6)),
        ),
      ),
      child: Row(
        children: [
          // User
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: expense['userColor'],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      expense['userInitials'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  expense['user'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          
          // Receipt
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(Icons.receipt, size: 18, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    expense['receipt'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          // Amount
          Expanded(
            flex: 1,
            child: Text(
              '\$${expense['amount'].toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          
          // Category
          Expanded(
            flex: 1,
            child: Text(
              expense['category'],
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          
          // Notes
          Expanded(
            flex: 2,
            child: Text(
              expense['notes'],
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Actions
          SizedBox(
            width: 120,
            child: showActions
                ? Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, size: 20),
                        color: const Color(0xFF10B981),
                        tooltip: 'Approve',
                        onPressed: () => _approveExpense(expense['id']),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: const Color(0xFFEF4444),
                        tooltip: 'Reject',
                        onPressed: () => _rejectExpense(expense['id']),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.message, size: 18),
                        color: const Color(0xFF6366F1),
                        tooltip: 'Comment',
                        onPressed: () => _commentExpense(expense['id']),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  )
                : Container(),
          ),
        ],
      ),
    );
  }

  Future<void> _approveExpense(String expenseId) async {
    try {
      final result = await WorkspaceService.updateApprovalStatus(
        workspaceId: widget.workspaceId,
        approvalId: expenseId,
        userId: widget.userId,
        body: {'status': 'approved'},
        token: widget.token,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense approved'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
        _loadApprovals();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: ${result['error']}'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _rejectExpense(String expenseId) async {
    try {
      final result = await WorkspaceService.updateApprovalStatus(
        workspaceId: widget.workspaceId,
        approvalId: expenseId,
        userId: widget.userId,
        body: {'status': 'rejected'},
        token: widget.token,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense rejected'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 2),
          ),
        );
        _loadApprovals();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: ${result['error']}'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _commentExpense(String expenseId) {
    // Show comment dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: const TextField(
          decoration: InputDecoration(
            hintText: 'Enter your comment...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Comment added')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveAll() async {
    final pendingExpenses = _expenses.where((e) => e['status'] == 'pending').toList();
    
    if (pendingExpenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pending expenses to approve'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      int successCount = 0;
      for (var expense in pendingExpenses) {
        final result = await WorkspaceService.updateApprovalStatus(
          workspaceId: widget.workspaceId,
          approvalId: expense['id'],
          userId: widget.userId,
          body: {'status': 'approved'},
          token: widget.token,
        );
        
        if (result['success'] == true) {
          successCount++;
        }
      }

      if (!mounted) return;

      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount expense(s) approved'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadApprovals();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}



