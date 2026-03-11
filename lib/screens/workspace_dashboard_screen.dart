import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../services/workspace_service.dart';
import 'manage_team_members_screen.dart';
import 'pending_approvals_screen.dart';
import 'workspace_analytics_screen.dart';
import 'upgrade_plan_screen.dart';
import '../web/app/workspace_owner_dashboard_web_screen.dart';
import '../web/app/workspace_analytics_web_screen.dart';
import '../web/app/workspace_team_management_web_screen.dart';
import '../web/app/workspace_expense_approval_web_screen.dart';

class WorkspaceDashboardScreen extends StatefulWidget {
  final String userId;
  final String token;

  /// Optional workspace id for owner dashboard API.
  /// If null/empty, the dashboard will show placeholder values.
  final String? workspaceId;

  const WorkspaceDashboardScreen({
    Key? key,
    required this.userId,
    required this.token,
    this.workspaceId,
  }) : super(key: key);

  @override
  State<WorkspaceDashboardScreen> createState() => _WorkspaceDashboardScreenState();
}

class _WorkspaceDashboardScreenState extends State<WorkspaceDashboardScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  int? _licensesUsed;
  int? _licenseTotal;
  double? _monthlySpend;
  int? _pendingApprovalsCount;
  double? _totalExpenses;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final workspaceId = widget.workspaceId;
    if (workspaceId == null || workspaceId.isEmpty) {
      // No workspace id yet – keep showing static placeholders.
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await WorkspaceService.getDashboardSummary(
      workspaceId: workspaceId,
      userId: widget.userId, // Using userId as fallback until memberId is available
      token: widget.token,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      try {
        final data = result['data'] as Map<String, dynamic>;
        final summary = (data['summary'] ?? {}) as Map<String, dynamic>;

        setState(() {
          _licensesUsed = summary['licensesUsed'] is int
              ? summary['licensesUsed'] as int
              : int.tryParse('${summary['licensesUsed']}');
          _licenseTotal = summary['licenseTotal'] is int
              ? summary['licenseTotal'] as int
              : int.tryParse('${summary['licenseTotal']}');
          _monthlySpend = summary['monthlySpend'] is num
              ? (summary['monthlySpend'] as num).toDouble()
              : double.tryParse('${summary['monthlySpend']}');
          _pendingApprovalsCount = summary['pendingApprovalsCount'] is int
              ? summary['pendingApprovalsCount'] as int
              : int.tryParse('${summary['pendingApprovalsCount']}');
          _totalExpenses = summary['totalExpenses'] is num
              ? (summary['totalExpenses'] as num).toDouble()
              : double.tryParse('${summary['totalExpenses']}');
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to parse dashboard data';
        });
      }
    } else {
      setState(() {
        _errorMessage = result['error']?.toString() ?? 'Failed to load dashboard';
      });
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Redirect to web dashboard if on web platform
    if (kIsWeb && widget.workspaceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkspaceOwnerDashboardWebScreen(
              userId: widget.userId,
              token: widget.token,
              workspaceId: widget.workspaceId!,
              workspaceName: 'Workspace', // You can pass actual name if available
            ),
          ),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final licensesLabel = _licensesUsed != null && _licenseTotal != null
        ? '${_licensesUsed!}/${_licenseTotal!}'
        : '1/1';
    final monthlySpendLabel =
        _monthlySpend != null ? '₹${_monthlySpend!.toStringAsFixed(0)}' : '₹0';
    final pendingApprovalsLabel =
        _pendingApprovalsCount != null ? '$_pendingApprovalsCount' : '0';
    final totalExpensesLabel =
        _totalExpenses != null ? '₹${_totalExpenses!.toStringAsFixed(0)}' : '0';

    final licenseUsageText = (_licensesUsed != null && _licenseTotal != null && _licenseTotal! > 0)
        ? '${_licensesUsed!} of ${_licenseTotal!} licenses used (${(_licensesUsed! * 100 / _licenseTotal!).toStringAsFixed(0)}%)'
        : '1 of 1 licenses used (100%)';

    final licenseUsageValue = (_licensesUsed != null && _licenseTotal != null && _licenseTotal! > 0)
        ? (_licensesUsed! / _licenseTotal!.clamp(1, _licenseTotal!))
        : 1.0;

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
            const Text(
              'TeamHub Owner',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
              'Owner',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Welcome, Owner!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4C3A9A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage your workspace and team',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            // Metrics Cards Grid (2x2 compact chips)
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    value: licensesLabel,
                    label: 'Licenses Used',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    value: monthlySpendLabel,
                    label: 'Monthly Spend',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    value: pendingApprovalsLabel,
                    label: 'Pending Approvals',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    value: totalExpensesLabel,
                    label: 'Total Expenses',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Quick actions row with emojis
            Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    emoji: '👥',
                    label: 'Manage\nTeam',
                    onTap: () {
                      if (kIsWeb && widget.workspaceId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkspaceTeamManagementWebScreen(
                              userId: widget.userId,
                              token: widget.token,
                              workspaceId: widget.workspaceId!,
                              workspaceName: 'Workspace',
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManageTeamMembersScreen(
                              userId: widget.userId,
                              token: widget.token,
                              workspaceId: widget.workspaceId,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    emoji: '✅',
                    label: 'Approve\nExpenses',
                    onTap: () {
                      if (kIsWeb && widget.workspaceId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkspaceExpenseApprovalWebScreen(
                              userId: widget.userId,
                              token: widget.token,
                              workspaceId: widget.workspaceId!,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PendingApprovalsScreen(
                              userId: widget.userId,
                              token: widget.token,
                              workspaceId: widget.workspaceId,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    emoji: '📊',
                    label: 'View\nAnalytics',
                    onTap: () {
                      if (kIsWeb && widget.workspaceId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkspaceAnalyticsWebScreen(
                              userId: widget.userId,
                              token: widget.token,
                              workspaceId: widget.workspaceId!,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkspaceAnalyticsScreen(
                              userId: widget.userId,
                              token: widget.token,
                              workspaceId: widget.workspaceId,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // License Usage Section with upgrade
            _buildLicenseUsageSection(
              context,
              progressValue: licenseUsageValue,
              description: licenseUsageText,
            ),
            const SizedBox(height: 24),
            
            // Recent Activity Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Latest workspace updates',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Empty state when no activity
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
                      Icons.update_outlined,
                      size: 48,
                      color: Color(0xFF7E5EFD),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No recent activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Activity will appear here',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({required String value, required String label}) {
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
            label,
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseUsageSection(
    BuildContext context, {
    required double progressValue,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Text(
                '🎫 License Usage',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  _showLicenseTooltip(context);
                },
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.help_outline,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressValue.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UpgradePlanScreen(
                      userId: widget.userId,
                      token: widget.token,
                      workspaceId: widget.workspaceId,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('⬆️', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text(
                    'Upgrade Plan',
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
    );
  }

  void _showLicenseTooltip(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.grey.shade900,
        content: const Text(
          'Licenses determine how many team members can use TeamHub. Each active team member requires one license. Upgrade your plan to add more team members.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard({
    required String title,
    required String description,
    required String statusLabel,
    required Color statusColor,
    required String emoji,
  }) {
    return Container(
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
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
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
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
        ],
      ),
    );
  }
}

