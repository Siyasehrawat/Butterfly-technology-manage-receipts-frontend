import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../services/workspace_service.dart';
import 'workspace_receipts_web_screen.dart';
import 'workspace_expense_approval_web_screen.dart';
import 'workspace_analytics_web_screen.dart';
import 'workspace_team_management_web_screen.dart';
import 'workspace_billing_web_screen.dart';

/// Workspace Owner Dashboard - Web Optimized
/// Displays comprehensive workspace metrics, quick actions, and recent activity
class WorkspaceOwnerDashboardWebScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String workspaceId;
  final String workspaceName;

  const WorkspaceOwnerDashboardWebScreen({
    Key? key,
    required this.userId,
    required this.token,
    required this.workspaceId,
    required this.workspaceName,
  }) : super(key: key);

  @override
  State<WorkspaceOwnerDashboardWebScreen> createState() => _WorkspaceOwnerDashboardWebScreenState();
}

class _WorkspaceOwnerDashboardWebScreenState extends State<WorkspaceOwnerDashboardWebScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedNavIndex = 0;

  // User information
  String _userName = '';
  String _userInitials = '';

  // Workspace management
  List<Map<String, dynamic>> _availableWorkspaces = [];
  String _currentWorkspaceId = '';
  String _currentWorkspaceName = '';
  String _currentWorkspaceEmail = '';
  bool _isLoadingWorkspaces = false;

  // Dashboard metrics
  int _licensesUsed = 0;
  int _licenseTotal = 0;
  double _monthlySpend = 0.0;
  int _pendingApprovalsCount = 0;
  double _totalExpenses = 0.0;
  
  // Additional metrics
  int _licensesAddedThisMonth = 0;
  double _spendChangePercent = 0.0;
  int _newApprovalsToday = 0;
  double _expensesChangePercent = 0.0;

  // Activity feed
  List<Map<String, dynamic>> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _currentWorkspaceId = widget.workspaceId;
    _currentWorkspaceName = widget.workspaceName;
    _currentWorkspaceEmail = '';
    _loadWorkspaces();
    _loadDashboard();
  }

  Future<void> _loadWorkspaces() async {
    setState(() {
      _isLoadingWorkspaces = true;
    });

    try {
      final result = await WorkspaceService.getUserWorkspaces(
        userId: widget.userId,
        token: widget.token,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final workspaces = data['workspaces'] as List<dynamic>? ?? [];

        setState(() {
          _availableWorkspaces = workspaces.map((ws) {
            final workspace = ws as Map<String, dynamic>;
            return {
              'id': workspace['id'] ?? '',
              'name': workspace['name'] ?? '',
              'role': workspace['role'] ?? '',
              'companyEmail': workspace['companyEmail'] ?? '',
              'licenseTotal': workspace['licenseTotal'] ?? 0,
              'licenseAllocated': workspace['licenseAllocated'] ?? 0,
            };
          }).toList();
          
          // Set current workspace details if available
          final currentWorkspace = _availableWorkspaces.firstWhere(
            (ws) => ws['id'] == _currentWorkspaceId,
            orElse: () => {},
          );
          if (currentWorkspace.isNotEmpty) {
            _currentWorkspaceName = currentWorkspace['name'] ?? '';
            _currentWorkspaceEmail = currentWorkspace['companyEmail'] ?? '';
          }
          
          _isLoadingWorkspaces = false;
        });
      } else {
        setState(() {
          _isLoadingWorkspaces = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingWorkspaces = false;
      });
    }
  }

  Future<void> _switchWorkspace(String workspaceId, String workspaceName, String workspaceEmail) async {
    if (workspaceId == _currentWorkspaceId) return;

    setState(() {
      _currentWorkspaceId = workspaceId;
      _currentWorkspaceName = workspaceName;
      _currentWorkspaceEmail = workspaceEmail;
      _isLoading = true;
    });

    // Reload dashboard for new workspace
    await _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load dashboard summary
      final dashboardResult = await WorkspaceService.getDashboardSummary(
        workspaceId: _currentWorkspaceId,
        userId: widget.userId,
        token: widget.token,
      );

      // Load recent activities
      final activitiesResult = await WorkspaceService.listActivities(
        workspaceId: _currentWorkspaceId,
        userId: widget.userId,
        query: {'limit': '5'},
        token: widget.token,
      );

      if (!mounted) return;

      if (dashboardResult['success'] == true) {
        final data = dashboardResult['data'] as Map<String, dynamic>;
        final summary = (data['summary'] ?? data) as Map<String, dynamic>;
        
        setState(() {
          // Parse user information
          _userName = summary['userName'] as String? ?? 
                     data['userName'] as String? ?? 
                     data['user']?['name'] as String? ?? 
                     'User';
          _userInitials = _getInitials(_userName);

          _licensesUsed = _parseInt(summary['licensesUsed']) ?? 
                         _parseInt(summary['usedLicenses']) ?? 0;
          _licenseTotal = _parseInt(summary['licenseTotal']) ?? 
                         _parseInt(summary['numberOfLicenses']) ?? 0;
          _monthlySpend = _parseDouble(summary['monthlySpend']) ?? 0.0;
          _pendingApprovalsCount = _parseInt(summary['pendingApprovalsCount']) ?? 
                                   _parseInt(summary['pendingApprovals']) ?? 0;
          _totalExpenses = _parseDouble(summary['totalExpenses']) ?? 0.0;
          
          // Parse additional metrics if available
          _licensesAddedThisMonth = _parseInt(summary['licensesAddedThisMonth']) ?? 0;
          _spendChangePercent = _parseDouble(summary['spendChangePercent']) ?? 0.0;
          _newApprovalsToday = _parseInt(summary['newApprovalsToday']) ?? 0;
          _expensesChangePercent = _parseDouble(summary['expensesChangePercent']) ?? 0.0;
          
          // Parse activities
          if (activitiesResult['success'] == true) {
            final activitiesData = activitiesResult['data'] as Map<String, dynamic>;
            final activities = activitiesData['activities'] as List<dynamic>? ?? [];
            _recentActivities = _parseActivities(activities);
          } else {
            _recentActivities = [];
          }
          
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = dashboardResult['error']?.toString() ?? 'Failed to load dashboard';
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

  List<Map<String, dynamic>> _parseActivities(List<dynamic> activities) {
    if (activities.isEmpty) return [];

    return activities.map((item) {
      final activity = item as Map<String, dynamic>;
      final type = activity['type'] ?? activity['activityType'] ?? 'general';
      
      return {
        'icon': _getActivityIcon(type),
        'iconColor': _getActivityIconColor(type),
        'iconBg': _getActivityIconBg(type),
        'title': activity['title'] ?? activity['description'] ?? 'Activity',
        'subtitle': activity['subtitle'] ?? activity['details'] ?? '',
        'time': _formatActivityTime(activity['createdAt'] ?? activity['timestamp']),
      };
    }).toList();
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'member_joined':
      case 'user_added':
        return Icons.person_add;
      case 'receipt_uploaded':
      case 'expense_submitted':
        return Icons.receipt_long;
      case 'report_generated':
        return Icons.assessment;
      case 'expense_approved':
      case 'approval':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color _getActivityIconColor(String type) {
    switch (type) {
      case 'member_joined':
      case 'user_added':
        return const Color(0xFF6366F1);
      case 'receipt_uploaded':
      case 'expense_submitted':
        return const Color(0xFF8B5CF6);
      case 'report_generated':
        return const Color(0xFF3B82F6);
      case 'expense_approved':
      case 'approval':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getActivityIconBg(String type) {
    return _getActivityIconColor(type).withOpacity(0.1);
  }

  String _formatActivityTime(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      final dateTime = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${(difference.inDays / 7).floor()} weeks ago';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String _getWorkspaceInitials(String workspaceName) {
    if (workspaceName.isEmpty) return 'W';
    final parts = workspaceName.trim().split(' ');
    if (parts.length == 1) {
      return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String _getEmailUsername(String email) {
    if (email.isEmpty) return 'User';
    final atIndex = email.indexOf('@');
    if (atIndex == -1) return email;
    return email.substring(0, atIndex);
  }

  String _getEmailInitials(String email) {
    if (email.isEmpty) return 'WS';
    final username = _getEmailUsername(email);
    if (username.isEmpty) return 'WS';
    if (username.length == 1) return username.toUpperCase();
    return username.substring(0, 2).toUpperCase();
  }

  Widget _buildWorkspaceDropdown() {
    if (_isLoadingWorkspaces) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_availableWorkspaces.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          _currentWorkspaceName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _currentWorkspaceId,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
          dropdownColor: Colors.white,
          items: _availableWorkspaces.map((workspace) {
            return DropdownMenuItem<String>(
              value: workspace['id'],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    workspace['name'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getRoleBadgeColor(workspace['role']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          workspace['role'].toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getRoleBadgeColor(workspace['role']),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${workspace['licenseAllocated']}/${workspace['licenseTotal']} licenses',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null && newValue != _currentWorkspaceId) {
              final selectedWorkspace = _availableWorkspaces.firstWhere(
                (ws) => ws['id'] == newValue,
                orElse: () => {},
              );
              if (selectedWorkspace.isNotEmpty) {
                _switchWorkspace(
                  newValue, 
                  selectedWorkspace['name'],
                  selectedWorkspace['companyEmail'] ?? '',
                );
              }
            }
          },
        ),
      ),
    );
  }

  Color _getRoleBadgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return const Color(0xFF6366F1);
      case 'admin':
      case 'manager':
        return const Color(0xFF8B5CF6);
      case 'member':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _buildCurrentScreen() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return WorkspaceReceiptsWebScreen(
          userId: widget.userId,
          token: widget.token,
          workspaceId: _currentWorkspaceId,
        );
      case 2:
        return WorkspaceExpenseApprovalWebScreen(
          userId: widget.userId,
          token: widget.token,
          workspaceId: _currentWorkspaceId,
        );
      case 4:
        return WorkspaceAnalyticsWebScreen(
          userId: widget.userId,
          token: widget.token,
          workspaceId: _currentWorkspaceId,
        );
      case 5:
        return WorkspaceTeamManagementWebScreen(
          userId: widget.userId,
          token: widget.token,
          workspaceId: _currentWorkspaceId,
          workspaceName: _currentWorkspaceName,
          isEmbedded: true,
        );
      case 6:
        return WorkspaceBillingWebScreen(
          userId: widget.userId,
          token: widget.token,
          workspaceId: _currentWorkspaceId,
          workspaceName: _currentWorkspaceName,
          isEmbedded: true,
        );
      default:
        return _buildDashboardContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Row(
        children: [
          // Sidebar Navigation
          _buildSidebar(),
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _buildCurrentScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo and Workspace Name
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'MR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'ManageReceipt',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildWorkspaceDropdown(),
              ],
            ),
          ),
          const Divider(height: 1),
          // Navigation Items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Text(
                      'WORKSPACE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildNavItem(0, Icons.dashboard, 'Dashboard'),
                  _buildNavItem(1, Icons.receipt_long, 'Receipts'),
                  _buildNavItem(2, Icons.approval, 'Approvals'),
                  _buildNavItem(3, Icons.assessment, 'Reports'),
                  _buildNavItem(4, Icons.analytics, 'Analytics'),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Text(
                      'MANAGEMENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildNavItem(5, Icons.people, 'Team'),
                  _buildNavItem(6, Icons.credit_card, 'Billing'),
                  _buildNavItem(7, Icons.settings, 'Settings'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {VoidCallback? onTap}) {
    final isSelected = _selectedNavIndex == index;
    return InkWell(
      onTap: onTap ?? () {
        setState(() {
          _selectedNavIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    // Get current workspace role
    final currentWorkspace = _availableWorkspaces.firstWhere(
      (ws) => ws['id'] == _currentWorkspaceId,
      orElse: () => {'role': 'member'},
    );
    final role = currentWorkspace['role'] as String? ?? 'member';
    final roleColor = _getRoleBadgeColor(role);

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            _currentWorkspaceName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              role[0].toUpperCase() + role.substring(1).toLowerCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: roleColor,
              ),
            ),
          ),
          const Spacer(),
          // Workspace Profile
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                _getEmailInitials(_currentWorkspaceEmail),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboard,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentWorkspaceEmail.isNotEmpty 
                ? 'Welcome back, ${_getEmailUsername(_currentWorkspaceEmail)}. Here\'s what\'s happening with your team.'
                : 'Welcome back. Here\'s what\'s happening with your team.',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 32),
          
          // Metrics Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Licenses Used',
                  '$_licensesUsed/$_licenseTotal',
                  '$_licensesAddedThisMonth added this month',
                  true,
                  const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildMetricCard(
                  'Monthly Spend',
                  '\$${_monthlySpend.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                  '${_spendChangePercent.abs().toStringAsFixed(0)}% vs last month',
                  _spendChangePercent < 0,
                  const Color(0xFFEC4899),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildMetricCard(
                  'Pending Approvals',
                  '$_pendingApprovalsCount',
                  '$_newApprovalsToday new today',
                  false,
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildMetricCard(
                  'Total Expenses',
                  '\$${_totalExpenses.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                  '${_expensesChangePercent.toStringAsFixed(0)}% vs last quarter',
                  true,
                  const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Quick Actions and License Usage
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Actions
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildActionCard(
                          'Manage Team',
                          'Add or remove members, assign roles',
                          Icons.people,
                          const Color(0xFF6366F1),
                          () {
                            setState(() {
                              _selectedNavIndex = 5;
                            });
                          },
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _buildActionCard(
                          'Approve Expenses',
                          '$_pendingApprovalsCount pending approvals',
                          Icons.check_circle,
                          const Color(0xFF10B981),
                          () {
                            setState(() {
                              _selectedNavIndex = 2;
                            });
                          },
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildActionCard(
                          'View Analytics',
                          'Spend trends and insights',
                          Icons.analytics,
                          const Color(0xFF8B5CF6),
                          () {
                            setState(() {
                              _selectedNavIndex = 4;
                            });
                          },
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _buildActionCard(
                          'Upload Receipts',
                          'Upload and categorize receipts',
                          Icons.upload_file,
                          const Color(0xFFF59E0B),
                          () {},
                        )),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // License Usage
              Expanded(
                flex: 1,
                child: _buildLicenseUsage(),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Recent Activity
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, bool isPositive, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
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

  Widget _buildLicenseUsage() {
    final usagePercent = (_licensesUsed / _licenseTotal) * 100;
    
    return Container(
      padding: const EdgeInsets.all(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'License Usage',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: const Text('Upgrade Plan', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'You\'re using $_licensesUsed out of $_licenseTotal licenses (${usagePercent.toStringAsFixed(0)}%)',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _licensesUsed / _licenseTotal,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '0 licenses',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
              Text(
                '$_licenseTotal licenses',
                style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              if (_recentActivities.isNotEmpty)
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_recentActivities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.history,
                        size: 32,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No recent activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Activity will appear here as your team works',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_recentActivities.length, (index) {
              final activity = _recentActivities[index];
              final isLast = index == _recentActivities.length - 1;
              return _buildActivityItem(
                activity['icon'] as IconData,
                activity['iconColor'] as Color,
                activity['iconBg'] as Color,
                activity['title'] as String,
                activity['subtitle'] as String,
                activity['time'] as String,
                isLast: isLast,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    IconData icon, 
    Color iconColor, 
    Color iconBg, 
    String title, 
    String subtitle, 
    String time, 
    {bool isLast = false}
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      decoration: BoxDecoration(
        border: isLast 
          ? null 
          : const Border(
              bottom: BorderSide(
                color: Color(0xFFF3F4F6),
                width: 1,
              ),
            ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

