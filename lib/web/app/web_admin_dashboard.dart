import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service_bypass.dart';
import '../../screens/admin_analytics_screen.dart';
import '../../screens/admin_users_screen.dart';
import '../../screens/mr_bucks_admin_screen.dart';
import '../../screens/workspaces_list_screen.dart';
import '../../screens/welcome_screen.dart';

/// Web-optimized Admin Dashboard with modern design
class WebAdminDashboard extends StatefulWidget {
  final String adminId;
  final String token;

  const WebAdminDashboard({
    Key? key,
    required this.adminId,
    required this.token,
  }) : super(key: key);

  @override
  State<WebAdminDashboard> createState() => _WebAdminDashboardState();
}

class _WebAdminDashboardState extends State<WebAdminDashboard> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.get('/admin/summary', token: widget.token);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load dashboard data: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      setState(() {
        _errorMessage = 'Network error: Unable to connect to server';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Row(
        children: [
          // Left Sidebar
          _buildSidebar(context),
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Header
                _buildTopHeader(context),
                // Main Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? _buildErrorView()
                          : SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(48.0),
                                child: _buildDashboardContent(context),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        children: [
          // Logo/Brand
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7E5EFD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'MR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Navigation Sections
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildNavSection(
                  context,
                  'ADMIN',
                  [
                    _buildNavItem(context, Icons.dashboard, 'Dashboard', true, () {}),
                    _buildNavItem(context, Icons.people, 'Users', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminUsersScreen(
                            adminId: widget.adminId,
                            token: widget.token,
                          ),
                        ),
                      );
                    }),
                    _buildNavItem(context, Icons.analytics, 'Analytics', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminAnalyticsScreen(
                            adminId: widget.adminId,
                            token: widget.token,
                          ),
                        ),
                      );
                    }),
                    _buildNavItem(context, Icons.card_giftcard, 'MR Bucks Admin', false, () {
                      Navigator.pushNamed(context, '/mr_bucks_admin');
                    }),
                    _buildNavItem(context, Icons.business, 'Workspaces', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkspacesListScreen(
                            userId: widget.adminId,
                            token: widget.token,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                _buildNavSection(
                  context,
                  'ACCOUNT',
                  [
                    _buildNavItem(context, Icons.arrow_back, 'Return to Dashboard', false, () {
                      Navigator.pop(context);
                    }),
                    _buildNavItem(context, Icons.logout, 'Logout', false, () async {
                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                      await userProvider.logout();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                        (route) => false,
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          // User Profile Section
          _buildUserProfile(context),
        ],
      ),
    );
  }

  Widget _buildNavSection(BuildContext context, String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFF0E6FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? const Color(0xFF7E5EFD) : Colors.grey.shade600,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF7E5EFD) : Colors.grey.shade800,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true,
      ),
    );
  }

  Widget _buildUserProfile(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF7E5EFD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                userProvider.username?.isNotEmpty == true
                    ? userProvider.username![0].toUpperCase()
                    : 'A',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userProvider.username ?? 'Admin',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Administrator',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Admin Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.grey.shade600),
                onPressed: _fetchDashboardData,
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.grey),
                    onPressed: () {},
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Section
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back, Admin!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Here\'s an overview of your application',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Stats Grid
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Users',
              _dashboardData['totalUsers']?.toString() ?? '0',
              Icons.people,
              Colors.blue,
              const Color(0xFFE3F2FD),
            ),
            _buildStatCard(
              'Active Users',
              _dashboardData['activeUsers']?.toString() ?? '0',
              Icons.person_outline,
              Colors.green,
              const Color(0xFFE8F5E9),
            ),
            _buildStatCard(
              'Total Receipts',
              _dashboardData['totalReceipts']?.toString() ?? '0',
              Icons.receipt_long,
              Colors.orange,
              const Color(0xFFFFF3E0),
            ),
            _buildStatCard(
              'New Users (7d)',
              _dashboardData['newUsersLast7Days']?.toString() ?? '0',
              Icons.person_add,
              const Color(0xFF7E5EFD),
              const Color(0xFFF0E6FF),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Additional Stats Grid
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 2,
          children: [
            _buildStatCard(
              'New Receipts (7d)',
              _dashboardData['newReceiptsLast7Days']?.toString() ?? '0',
              Icons.receipt_outlined,
              Colors.teal,
              const Color(0xFFE0F2F1),
            ),
            _buildStatCard(
              'Avg Receipts/User',
              _dashboardData['averageReceiptsPerUser']?.toString() ?? '0.0',
              Icons.analytics,
              Colors.indigo,
              const Color(0xFFE8EAF6),
            ),
            _buildStatCard(
              'System Health',
              'Excellent',
              Icons.health_and_safety,
              Colors.green,
              const Color(0xFFE8F5E9),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Recent Activity Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildActivityItem(
                'New Users',
                '${_dashboardData['newUsersLast7Days'] ?? 0} new users joined in the last 7 days',
                Icons.person_add,
                Colors.green,
              ),
              const Divider(height: 32),
              _buildActivityItem(
                'New Receipts',
                '${_dashboardData['newReceiptsLast7Days'] ?? 0} receipts uploaded in the last 7 days',
                Icons.receipt,
                Colors.blue,
              ),
              const Divider(height: 32),
              _buildActivityItem(
                'Average Usage',
                '${_dashboardData['averageReceiptsPerUser'] ?? 0} receipts per user on average',
                Icons.analytics,
                Colors.orange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Quick Actions
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildQuickActionButton(
                    context,
                    'Manage Users',
                    Icons.people,
                    const Color(0xFF7E5EFD),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminUsersScreen(
                            adminId: widget.adminId,
                            token: widget.token,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildQuickActionButton(
                    context,
                    'View Analytics',
                    Icons.analytics,
                    Colors.blue,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminAnalyticsScreen(
                            adminId: widget.adminId,
                            token: widget.token,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildQuickActionButton(
                    context,
                    'MR Bucks Admin',
                    Icons.card_giftcard,
                    Colors.orange,
                    () {
                      Navigator.pushNamed(context, '/mr_bucks_admin');
                    },
                  ),
                  _buildQuickActionButton(
                    context,
                    'Workspaces',
                    Icons.business,
                    Colors.teal,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkspacesListScreen(
                            userId: widget.adminId,
                            token: widget.token,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildQuickActionButton(
                    context,
                    'System Settings',
                    Icons.settings,
                    Colors.grey,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('System settings coming soon')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color backgroundColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchDashboardData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E5EFD),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

