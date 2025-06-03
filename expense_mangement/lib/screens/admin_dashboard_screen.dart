import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/curved_background.dart';
import 'admin_analytics_screen.dart';
import 'admin_users_screen.dart';
import 'admin_receipts_screen.dart';
import 'admin_settings_screen.dart';
import 'dashboard_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String adminId;
  final String token;

  const AdminDashboardScreen({
    Key? key,
    required this.adminId,
    required this.token,
  }) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
      final url = Uri.parse(
          'https://manage-receipt-backend-bnl1.onrender.com/api/admin/summary');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load dashboard data: ${response.statusCode}';
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

  void _navigateToUsersScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminUsersScreen(
          adminId: widget.adminId,
          token: widget.token,
        ),
      ),
    );
  }

  void _navigateToReceiptsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminReceiptsScreen(
          adminId: widget.adminId,
          token: widget.token,
        ),
      ),
    );
  }

  void _navigateToAnalyticsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminAnalyticsScreen(
          adminId: widget.adminId,
          token: widget.token,
        ),
      ),
    );
  }

  void _navigateToSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminSettingsScreen(
          adminId: widget.adminId,
          token: widget.token,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildAdminDrawer(),
      body: SafeArea(
        bottom: true,
        child: CurvedBackground(
          child: Column(
            children: [
              // App Bar
              Container(
                padding: const EdgeInsets.only(
                    top: 8, left: 16, right: 16, bottom: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Admin Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
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
                  ],
                ),
              ),

              // Dashboard Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchDashboardData,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF7E5EFD),
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Welcome message
                                const Text(
                                  'Welcome, Admin!',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Here\'s an overview of your application',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // User Stats Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        'Total Users',
                                        _dashboardData['totalUsers']
                                                ?.toString() ??
                                            '0',
                                        Icons.people,
                                        Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Active Users',
                                        _dashboardData['activeUsers']
                                                ?.toString() ??
                                            '0',
                                        Icons.person_outline,
                                        Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Receipt Stats Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        'Total Receipts',
                                        _dashboardData['totalReceipts']
                                                ?.toString() ??
                                            '0',
                                        Icons.receipt_long,
                                        Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildStatCard(
                                        'New Users (7d)',
                                        _dashboardData['newUsersLast7Days']
                                                ?.toString() ??
                                            '0',
                                        Icons.person_add,
                                        Colors.purple,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Recent Activity Section
                                _buildRecentActivitySection(),
                                const SizedBox(height: 24),

                                // Quick Actions Section
                                _buildQuickActionsSection(),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7E5EFD),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildActivityItem(
            'New Users',
            '${_dashboardData['newUsersLast7Days'] ?? 0} new users in the last 7 days',
            Icons.person_add,
            Colors.green,
          ),
          const Divider(),
          _buildActivityItem(
            'New Receipts',
            '${_dashboardData['receiptsLast7Days'] ?? 0} new receipts in the last 7 days',
            Icons.receipt,
            Colors.blue,
          ),
          const Divider(),
          _buildActivityItem(
            'Average Usage',
            '${_dashboardData['averageReceiptsPerUser'] ?? 0} receipts per user on average',
            Icons.analytics,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
      String title, String subtitle, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Manage Users',
                  Icons.people,
                  _navigateToUsersScreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'View Receipts',
                  Icons.receipt_long,
                  _navigateToReceiptsScreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Analytics',
                  Icons.analytics,
                  _navigateToAnalyticsScreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Settings',
                  Icons.settings,
                  _navigateToSettingsScreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EAFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF7E5EFD), size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7E5EFD),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF7E5EFD),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'MR',
                      style: TextStyle(
                        color: Color(0xFF7E5EFD),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Manage Receipt App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: true,
            selectedTileColor: const Color(0xFFF0EAFF),
            selectedColor: const Color(0xFF7E5EFD),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Users'),
            onTap: () {
              Navigator.pop(context);
              _navigateToUsersScreen();
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Receipts'),
            onTap: () {
              Navigator.pop(context);
              _navigateToReceiptsScreen();
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Analytics'),
            onTap: () {
              Navigator.pop(context);
              _navigateToAnalyticsScreen();
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              _navigateToSettingsScreen();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Return to User Dashboard'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardScreen(
                    userId: widget.adminId,
                    token: widget.token,
                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/welcome',
                            (route) => false,
                          );
                        },
                        child: const Text('Logout',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
