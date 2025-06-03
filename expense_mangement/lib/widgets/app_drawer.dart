import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/welcome_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../services/auth_service.dart';
import '../services/auth_manager.dart';
import '../providers/user_provider.dart';

class AppDrawer extends StatelessWidget {
  final String userId;
  final String token;
  final Function? onLogout;

  const AppDrawer({
    super.key,
    required this.userId,
    this.token = '',
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final bool hasAdminAccess = userProvider.hasAdminAccess;

    return Drawer(
      child: Container(
        color: const Color(0xFF7E5EFD),
        child: Column(
          children: [
            // Logo or Manage Receipt text in a rectangle
            Container(
              padding: const EdgeInsets.only(top: 50, bottom: 20),
              alignment: Alignment.center,
            ),

            // Home
            _buildDrawerItem(
              context,
              icon: Icons.home,
              title: 'Home',
              onTap: () {
                Navigator.pop(context); // Close drawer first

                // Navigate to dashboard screen with a fresh instance
                // This ensures it will fetch only saved receipts
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DashboardScreen(
                      userId: userId,
                      token: token,
                    ),
                  ),
                );
              },
            ),

            // Divider after Home
            _buildDivider(),

            // Profile
            _buildDrawerItem(
              context,
              icon: Icons.person_outline,
              title: 'Profile',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      userId: userId,
                      token: token,
                    ),
                  ),
                );
              },
            ),

            // Divider after Profile
            _buildDivider(),

            // Reports
            _buildDrawerItem(
              context,
              icon: Icons.receipt_long,
              title: 'Reports',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportsScreen(
                      userId: userId,
                    ),
                  ),
                );
              },
            ),

            // Divider after Reports
            _buildDivider(),

            // Admin Panel (only shown if user has admin access)
            if (hasAdminAccess) ...[
              _buildDrawerItem(
                context,
                icon: Icons.admin_panel_settings,
                title: 'Admin Panel',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminDashboardScreen(
                        adminId: userId,
                        token: token,
                      ),
                    ),
                  );
                },
              ),
              _buildDivider(),
            ],

            // Settings
            _buildDrawerItem(
              context,
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),

            // Divider after Settings
            _buildDivider(),

            // Logout
            _buildDrawerItem(
              context,
              icon: Icons.logout,
              title: 'Logout',
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
      }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.white,
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              // Use the provided logout function if available
              if (onLogout != null) {
                onLogout!();
                return;
              }

              // Otherwise handle logout here
              final authService = AuthService();
              await authService.signOut();

              // Clear stored auth data
              final authManager = AuthManager();
              await authManager.clearAuthData();

              // Update user provider
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              await userProvider.logout();

              // Navigate to welcome screen and clear navigation stack
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}