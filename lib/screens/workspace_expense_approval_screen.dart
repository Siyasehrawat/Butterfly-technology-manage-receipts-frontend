import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../services/workspace_service.dart';
import '../web/app/workspace_expense_approval_web_screen.dart';

class WorkspaceExpenseApprovalScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String workspaceId;

  const WorkspaceExpenseApprovalScreen({
    Key? key,
    required this.userId,
    required this.token,
    required this.workspaceId,
  }) : super(key: key);

  @override
  State<WorkspaceExpenseApprovalScreen> createState() => _WorkspaceExpenseApprovalScreenState();
}

class _WorkspaceExpenseApprovalScreenState extends State<WorkspaceExpenseApprovalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _approved = [];
  List<Map<String, dynamic>> _rejected = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadApprovals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadApprovals() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await WorkspaceService.listExpenseReports(
        workspaceId: widget.workspaceId,
        userId: widget.userId, // Using userId as fallback until memberId is available
        query: {'status': 'all', 'page': '1', 'pageSize': '100'},
        token: widget.token,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        try {
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
          final normalized = reportsList.map(_normalizeApproval).toList();
          setState(() {
            _pending = normalized.where((a) => a['status'] == 'pending').toList();
            _approved = normalized.where((a) => a['status'] == 'approved').toList();
            _rejected = normalized.where((a) => a['status'] == 'rejected').toList();
            _loading = false;
          });
        } catch (e) {
          setState(() {
            _error = 'Failed to parse expense reports';
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = res['error']?.toString() ?? 'Failed to load expense reports';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading expense reports: $e');
      setState(() {
        _error = 'Failed to load expense reports';
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _normalizeApproval(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    
    // Format submittedBy
    String submittedByName = '';
    if (map['submittedBy'] != null) {
      if (map['submittedBy'] is Map) {
        submittedByName = map['submittedBy']?['name'] ?? '';
      } else {
        submittedByName = map['submittedBy'].toString();
      }
    }
    
    return {
      'id': map['id']?.toString() ?? '',
      'title': map['title'] ?? 'Expense Report',
      'amount': map['totalAmount'] ?? map['amount'] ?? 0,
      'meta': '${map['receiptCount'] ?? map['receiptsCount'] ?? 0} receipts',
      'details': map['description'] ?? '',
      'status': (map['status'] ?? 'pending').toString().toLowerCase(),
      'submittedBy': submittedByName,
      'submittedAt': map['submittedAt'] ?? map['createdAt'] ?? '',
    };
  }

  Future<void> _updateApproval(Map<String, dynamic> approval, String action, {String? rejectionReason}) async {
    final id = approval['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final res = await WorkspaceService.updateExpenseReport(
      workspaceId: widget.workspaceId,
      reportId: id,
      userId: widget.userId, // Using userId as fallback until memberId is available
      body: {
        'status': action,
        if (rejectionReason != null && rejectionReason.isNotEmpty) 'rejectionReason': rejectionReason,
      },
      token: widget.token,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      await _loadApprovals();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Expense report ${action == 'approved' ? 'approved' : 'rejected'}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Update failed')),
      );
    }
  }

  void _showRejectDialog(Map<String, dynamic> approval) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reject Expense Report',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.black87,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Are you sure you want to reject "${approval['title'] ?? 'this report'}"?',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Reason (Optional):',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter reason for rejection...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        final reason = reasonController.text.trim();
                        Navigator.pop(context);
                        _updateApproval(
                          approval,
                          'rejected',
                          rejectionReason: reason.isNotEmpty ? reason : null,
                        );
                      },
                      child: const Text(
                        'Reject',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showApproveDialog(Map<String, dynamic> approval) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Approve Expense Report',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.black87,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Are you sure you want to approve "${approval['title'] ?? 'this report'}"?',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _updateApproval(approval, 'approved');
                      },
                      child: const Text(
                        'Approve',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
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
    // Redirect to web expense approval if on web platform
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkspaceExpenseApprovalWebScreen(
              userId: widget.userId,
              token: widget.token,
              workspaceId: widget.workspaceId,
            ),
          ),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Expense Approval',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black87,
                indicator: BoxDecoration(
                  color: const Color(0xFF7E5EFD),
                  borderRadius: BorderRadius.circular(999),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Approved'),
                  Tab(text: 'Rejected'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(_pending, showActions: true),
          _buildList(_approved),
          _buildList(_rejected),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, {bool showActions = false}) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadApprovals,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: showActions ? Icons.hourglass_empty : Icons.description_outlined,
        title: showActions ? 'No pending approvals' : 'No items',
        subtitle: showActions ? 'Pending expenses will appear here' : 'Nothing to show',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadApprovals,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final a = items[index];
          final status = a['status'] ?? 'pending';
          Color statusColor;
          switch (status) {
            case 'approved':
              statusColor = Colors.green;
              break;
            case 'rejected':
              statusColor = Colors.red;
              break;
            default:
              statusColor = Colors.orange;
          }
          final amountValue = a['amount'];
          final amountStr = amountValue is num 
              ? amountValue.toStringAsFixed(2)
              : (amountValue?.toString() ?? '0.00');
          
          return _buildExpenseCard(
            title: a['title'] ?? 'Expense Report',
            amount: '₹$amountStr',
            meta: a['meta'] ?? '',
            details: a['details'] ?? '',
            statusLabel: status[0].toUpperCase() + status.substring(1),
            statusColor: statusColor,
            showPrimarySecondary: showActions,
            onApprove: showActions ? () => _showApproveDialog(a) : null,
            onReject: showActions ? () => _showRejectDialog(a) : null,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
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
              child: Icon(
                icon,
                size: 64,
                color: const Color(0xFF7E5EFD),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard({
    required String title,
    required String amount,
    required String meta,
    required String details,
    required String statusLabel,
    required Color statusColor,
    bool showPrimarySecondary = true,
    VoidCallback? onApprove,
    VoidCallback? onReject,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E5EFD),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            meta,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          if (details.isNotEmpty) const SizedBox(height: 4),
          if (details.isNotEmpty)
            Text(
              details,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
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
          if (showPrimarySecondary) const SizedBox(height: 14),
          if (showPrimarySecondary)
            Row(
              children: [
                Expanded(
                  child: _buildFooterButton(
                    label: 'Approve',
                    backgroundColor: const Color(0xFF22C55E),
                    textColor: Colors.white,
                    onTap: onApprove,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFooterButton(
                    label: 'Reject',
                    backgroundColor: const Color(0xFFEF4444),
                    textColor: Colors.white,
                    onTap: onReject,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFooterButton(
                    label: 'Details',
                    backgroundColor: Colors.grey.shade100,
                    textColor: Colors.black87,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFooterButton({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}




