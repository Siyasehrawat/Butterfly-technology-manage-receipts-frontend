import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../screens/profile_screen.dart';
import '../../screens/update_password_screen.dart';
import '../../providers/user_provider.dart';
import '../../screens/welcome_screen.dart';
import '../../screens/expense_reports_screen.dart';
import '../../screens/tax_reports_screen.dart';
import '../../screens/analytics_screen.dart';
import '../../screens/bill_reminders_screen.dart';
import '../../screens/split_receipts_screen.dart';
import '../../screens/mr_bucks_screen.dart';
import '../../screens/refer_earn_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/wallet_screen.dart' show MyWalletScreen;
import '../../screens/workspaces_list_screen.dart';
import 'web_admin_dashboard.dart';

class WebSettingsScreen extends StatelessWidget {
  final String userId;
  final String token;

  const WebSettingsScreen({
    Key? key,
    required this.userId,
    required this.token,
  }) : super(key: key);

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
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: _buildSettingsContent(context),
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
                  'Manage Receipt',
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
                  'MAIN',
                  [
                    _buildNavItem(context, Icons.home, 'Dashboard', false, () {
                      Navigator.pop(context);
                    }),
                    _buildNavItem(context, Icons.search, 'Search Receipts', false, () {}),
                    _buildNavItem(context, Icons.email, 'Email Receipts', false, () {}),
                  ],
                ),
                const SizedBox(height: 8),
                _buildNavSection(
                  context,
                  'REPORTS',
                  [
                    _buildNavItem(context, Icons.description, 'Expense Reports', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ExpenseReportsScreen(userId: userId, token: token)),
                      );
                    }),
                    _buildNavItem(context, Icons.receipt_long, 'Tax Reports', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TaxReportsScreen(userId: userId)),
                      );
                    }),
                    _buildNavItem(context, Icons.bar_chart, 'Analytics', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                _buildNavSection(
                  context,
                  'FEATURES',
                  [
                    _buildNavItem(context, Icons.notifications, 'Bill Reminders', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BillRemindersScreen()),
                      );
                    }),
                    _buildNavItem(context, Icons.people, 'Split Receipts', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SplitReceiptsScreen(userId: userId, token: token)),
                      );
                    }),
                    _buildNavItem(context, Icons.folder, 'Document Wallet', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MyWalletScreen(userId: userId, token: token)),
                      );
                    }),
                    _buildNavItem(context, Icons.monetization_on, 'MR Bucks', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MrBucksScreen()),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                // ADMIN section - only shown if user has admin access
                if (Provider.of<UserProvider>(context).hasAdminAccess) ...[
                  _buildNavSection(
                    context,
                    'ADMIN',
                    [
                      _buildNavItem(context, Icons.admin_panel_settings, 'Admin Panel', false, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WebAdminDashboard(
                              adminId: userId,
                              token: token,
                            ),
                          ),
                        );
                      }),
                      _buildNavItem(context, Icons.business, 'Workspaces', false, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkspacesListScreen(
                              userId: userId,
                              token: token,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                _buildNavSection(
                  context,
                  'ACCOUNT',
                  [
                    _buildNavItem(context, Icons.person_add, 'Refer & Earn', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ReferEarnScreen(userId: userId, token: token)),
                      );
                    }),
                    _buildNavItem(context, Icons.settings, 'Settings', true, () {}),
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
                    : 'U',
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
                  userProvider.username ?? 'User',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Premium Account',
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
    final userProvider = Provider.of<UserProvider>(context);
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
            'Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9500), Color(0xFFFF7300)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '1,250 MR Bucks',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
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

  Widget _buildSettingsContent(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Settings Card
        _buildSettingsCard(
          context,
          title: 'PROFILE SETTINGS',
          description: 'Update your personal information and preferences',
          buttonText: 'Edit Profile',
          icon: Icons.person,
          iconColor: const Color(0xFF7E5EFD),
          iconBgColor: const Color(0xFFF0E6FF),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(
                  userId: userProvider.userId ?? '',
                  token: userProvider.token ?? '',
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 24),
        
        // Email Preferences Card
        _buildSettingsCard(
          context,
          title: 'EMAIL PREFERENCES',
          description: 'Manage notification and receipt forwarding settings',
          buttonText: 'Configure',
          icon: Icons.email,
          iconColor: const Color(0xFF2196F3),
          iconBgColor: const Color(0xFFE3F2FD),
          onTap: () {
            // Open email preferences dialog or screen
            _showEmailPreferencesDialog(context);
          },
        ),
        
        const SizedBox(height: 24),
        
        // Security Card
        _buildSettingsCard(
          context,
          title: 'SECURITY',
          description: 'Two-factor authentication and password settings',
          buttonText: 'Security Settings',
          icon: Icons.security,
          iconColor: const Color(0xFFFF9500),
          iconBgColor: const Color(0xFFFFF3E0),
          onTap: () {
            if (userProvider.canUpdatePassword) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UpdatePasswordScreen(
                    userId: userProvider.userId ?? '',
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password update not available for social login'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    required String description,
    required String buttonText,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onTap,
                  icon: Icon(Icons.edit, size: 16),
                  label: Text(buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
        ],
      ),
    );
  }

  void _showEmailPreferencesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Email Preferences'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Configure your email notification and receipt forwarding settings.'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Email Notifications'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
                activeColor: const Color(0xFF7E5EFD),
              ),
            ),
            ListTile(
              title: const Text('Receipt Forwarding'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
                activeColor: const Color(0xFF7E5EFD),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

