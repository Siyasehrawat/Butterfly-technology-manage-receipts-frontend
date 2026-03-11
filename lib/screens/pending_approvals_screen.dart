import 'package:flutter/material.dart';
import '../services/workspace_service.dart';
import 'workspace_dashboard_screen.dart';

class PendingApprovalsScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String? workspaceId;

  const PendingApprovalsScreen({
    Key? key,
    required this.userId,
    required this.token,
    this.workspaceId,
  }) : super(key: key);

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _approvals = [];

  @override
  void initState() {
    super.initState();
    _loadApprovals();
  }

  Future<void> _loadApprovals() async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Workspace is required to load approvals';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await WorkspaceService.listApprovals(
      workspaceId: widget.workspaceId!,
      userId: widget.userId,
      token: widget.token,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      try {
        final data = res['data'] as Map<String, dynamic>;
        final items = (data['approvals'] ?? data['items'] ?? []) as List<dynamic>;
        setState(() {
          _approvals = items.map(_normalizeApproval).toList();
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to parse approvals';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = res['error']?.toString() ?? 'Failed to load approvals';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateApproval(Map<String, dynamic> approval, String action) async {
    final approvalId = approval['id']?.toString() ?? '';
    if (approvalId.isEmpty || widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing workspace or approval id')),
      );
      return;
    }

      final res = await WorkspaceService.updateApprovalStatus(
        workspaceId: widget.workspaceId!,
        approvalId: approvalId,
        userId: widget.userId, // Using userId as fallback until memberId is available
        body: {'action': action},
      token: widget.token,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approval ${action == 'approved' ? 'approved' : 'rejected'}')),
      );
      await _loadApprovals();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Update failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Pending Approvals',
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
      body: _buildBody(),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkspaceDashboardScreen(
                    userId: widget.userId,
                    token: widget.token,
                    workspaceId: widget.workspaceId,
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7E5EFD),
              side: const BorderSide(color: Color(0xFF7E5EFD)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'BACK TO DASHBOARD',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
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
                onPressed: _loadApprovals,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_approvals.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No pending approvals right now'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          ..._approvals.map((approval) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildExpenseCard(
                amount: approval['amountDisplay'] ?? '₹0',
                merchant: approval['merchant'] ?? approval['title'] ?? 'Expense',
                category: approval['category'] ?? 'General',
                date: approval['date'] ?? '',
                description: approval['description'] ?? '',
                submittedBy: approval['submittedBy'] ?? 'Unknown',
                onApprove: () => _updateApproval(approval, 'approved'),
                onReject: () => _updateApproval(approval, 'rejected'),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildExpenseCard({
    required String amount,
    required String merchant,
    required String category,
    required String date,
    required String description,
    required String submittedBy,
    required VoidCallback onApprove,
    required VoidCallback onReject,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E5EFD),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            merchant,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            category,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            date,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Submitted by: $submittedBy',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onReject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _normalizeApproval(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final amount = map['amount'] ?? map['totalAmount'] ?? 0;
    final amountDisplay = amount is num ? '₹${amount.toStringAsFixed(0)}' : '$amount';

    return {
      'id': map['id'] ?? map['_id'] ?? map['approvalId'] ?? '',
      'amountDisplay': amountDisplay,
      'merchant': map['merchant'] ?? map['title'] ?? 'Expense',
      'category': map['category'] ?? map['type'] ?? 'General',
      'description': map['description'] ?? '',
      'submittedBy': (map['submittedBy']?['name']) ?? map['submittedBy'] ?? 'Unknown',
      'date': map['date'] ?? map['submittedAt'] ?? '',
    };
  }
}




