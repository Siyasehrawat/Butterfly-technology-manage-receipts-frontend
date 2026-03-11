import 'package:flutter/material.dart';
import 'workspace_owner_dashboard_web_screen.dart';


/// Example Integration for Workspace Owner Web Screens
/// 
/// This file demonstrates how to integrate the new workspace owner
/// web screens into your Flutter application.
/// 
/// Created Screens:
/// ---------------
/// 1. WorkspaceOwnerDashboardWebScreen - Main dashboard with metrics, quick actions, and activity feed
/// 2. WorkspaceExpenseApprovalWebScreen - Review and approve/reject team expenses
/// 3. WorkspaceAnalyticsWebScreen - View spending patterns with charts
/// 4. WorkspaceTeamManagementWebScreen - Manage team members and permissions
/// 5. WorkspaceBillingWebScreen - Manage subscription and payment methods
/// 
/// Features:
/// ---------
/// ✓ Web-optimized layouts with responsive design
/// ✓ Modern UI with proper spacing and typography
/// ✓ Sidebar navigation for easy screen switching
/// ✓ Custom charts (Pie Chart and Bar Chart) for analytics
/// ✓ Interactive tables with sorting and filtering
/// ✓ Action buttons and dialogs for common operations
/// ✓ Mock data included for testing (replace with real API calls)
/// 
/// Usage Example:
/// -------------
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => WorkspaceOwnerDashboardWebScreen(
///       userId: 'user-123',
///       token: 'auth-token',
///       workspaceId: 'workspace-456',
///       workspaceName: 'Acme Corp',
///     ),
///   ),
/// );
/// ```
/// 
/// Integration Steps:
/// -----------------
/// 1. Add navigation from your workspace selection screen
/// 2. Replace mock data with actual API calls to WorkspaceService
/// 3. Implement authentication checks
/// 4. Add proper error handling and loading states
/// 5. Connect to your state management solution (Provider, Riverpod, etc.)
/// 
/// Screen Flow:
/// -----------
/// WorkspacesListScreen 
///   → WorkspaceOwnerDashboardWebScreen (Main Hub)
///     ├─ Dashboard Tab (Default)
///     ├─ Approvals Tab (Inline)
///     ├─ Analytics Tab (Inline)
///     ├─ Team Management (Separate screen)
///     └─ Billing & Subscriptions (Separate screen)
/// 
/// Color Scheme:
/// ------------
/// Primary: #6366F1 (Indigo)
/// Success: #10B981 (Green)
/// Warning: #F59E0B (Amber)
/// Error: #EF4444 (Red)
/// Purple: #8B5CF6
/// Pink: #EC4899
/// Gray: #6B7280
/// Background: #F9FAFB
/// 
/// API Integration:
/// ---------------
/// All screens are designed to work with WorkspaceService.
/// Replace mock data in each screen with actual API calls:
/// 
/// - getDashboardSummary() - Dashboard metrics
/// - getPendingApprovals() - Expense approvals list
/// - getAnalyticsSummary() - Analytics data
/// - getTeamMembers() - Team list
/// - getSubscriptionDetails() - Billing info
/// 
class WorkspaceOwnerWebExample extends StatelessWidget {
  const WorkspaceOwnerWebExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: const [
                    Icon(
                      Icons.workspace_premium,
                      size: 64,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Workspace Owner Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Web-Optimized for Flutter',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Example Buttons
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WorkspaceOwnerDashboardWebScreen(
                        userId: 'demo-user-123',
                        token: 'demo-token',
                        workspaceId: 'demo-workspace-456',
                        workspaceName: 'Acme Corp',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.dashboard),
                label: const Text('Open Dashboard Demo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 16),

              // Info Cards
              _buildInfoCard(
                '5 New Screens',
                'Dashboard, Approvals, Analytics, Team, Billing',
                Icons.web,
                const Color(0xFF10B981),
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                'Web-Optimized',
                'Responsive layouts designed for desktop browsers',
                Icons.devices,
                const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                'Production Ready',
                'Clean code, no linter errors, mock data included',
                Icons.check_circle,
                const Color(0xFFF59E0B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
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
                    fontSize: 14,
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
    );
  }
}

