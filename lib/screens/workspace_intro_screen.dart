import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'workspace_onboarding_screen.dart';
import 'workspaces_list_screen.dart';
import 'admin_dashboard_screen.dart';
import 'dashboard_screen.dart';

class WorkspaceIntroScreen extends StatelessWidget {
  final String userId;
  final String token;
  final bool isFromAdmin;

  const WorkspaceIntroScreen({
    Key? key,
    required this.userId,
    required this.token,
    this.isFromAdmin = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isFromAdmin
          ? AppBar(
              backgroundColor: const Color(0xFF7E5EFD),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.pushReplacement(
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
              actions: [
                // Option to return to user dashboard
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'user_dashboard') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DashboardScreen(
                            userId: userId,
                            token: token,
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'user_dashboard',
                      child: Row(
                        children: [
                          Icon(Icons.home, color: Color(0xFF7E5EFD)),
                          SizedBox(width: 8),
                          Text('Return to User Dashboard'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF7E5EFD),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header with MR logo and TeamHub text
                Padding(
                  padding: EdgeInsets.only(
                    top: isFromAdmin ? 20 : 40,
                    bottom: 20,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'MR',
                            style: TextStyle(
                              color: Color(0xFF7E5EFD),
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Manage Receipt',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Main content area
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        const Text(
                          'TeamHub - Collaborate with your team',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'With TeamHub, you can manage expenses and receipts across your entire team in one shared workspace.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildFeatureItem(
                          icon: Icons.people,
                          text: 'Manage team members with different roles',
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureItem(
                          icon: Icons.check_circle,
                          text: 'Streamlined expense approval workflow',
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureItem(
                          icon: Icons.bar_chart,
                          text: 'Team-wide analytics and insights',
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureItem(
                          icon: Icons.shield,
                          text: 'Secure document storage and sharing',
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Ready to get started?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Set up your TeamHub workspace and start collaborating with your team.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WorkspacesListScreen(
                                    userId: userId,
                                    token: token,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7E5EFD),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WorkspaceOnboardingScreen(
                                    userId: userId,
                                    token: token,
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: const BorderSide(color: Colors.grey, width: 1),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Restart tour',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF7E5EFD).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF7E5EFD),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
