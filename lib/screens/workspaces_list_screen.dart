import 'package:flutter/material.dart';
import 'workspace_dashboard_screen.dart';
import 'workspace_manager_dashboard_screen.dart';
import 'workspace_user_dashboard_screen.dart';
import 'add_workspace_email_screen.dart';
import '../services/workspace_service.dart';

class WorkspacesListScreen extends StatefulWidget {
  final String userId;
  final String token;

  const WorkspacesListScreen({
    Key? key,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<WorkspacesListScreen> createState() => _WorkspacesListScreenState();
}

class _WorkspacesListScreenState extends State<WorkspacesListScreen> {
  List<Map<String, dynamic>> _workspaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWorkspaces();
  }

  Future<void> _fetchWorkspaces() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await WorkspaceService.getUserWorkspaces(
        userId: widget.userId,
        token: widget.token,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        setState(() {
          _workspaces = List<Map<String, dynamic>>.from(data['workspaces'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Failed to load workspaces'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading workspaces: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Workspaces',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Workspace',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose a workspace to continue or add a new one',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // "Your Workspaces" label
            const Text(
              'Your Workspaces',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // Show loading indicator or workspace tiles
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(
                    color: Color(0xFF7E5EFD),
                  ),
                ),
              )
            else if (_workspaces.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'No workspaces found. Add a new one below.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              ..._workspaces.map((workspace) {
                final role = workspace['role']?.toString() ?? 'member';
                final (roleColor, roleTextColor) = _getRoleColors(role);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildWorkspaceTile(
                    name: workspace['name'] ?? 'Unnamed Workspace',
                    membersText: workspace['companyEmail'] ?? '',
                    roleLabel: _formatRole(role),
                    roleColor: roleColor,
                    roleTextColor: roleTextColor,
              onTap: () {
                      _navigateToWorkspaceDashboard(workspace);
                    },
                  ),
                );
              }).toList(),

            const SizedBox(height: 20),

            // Add new workspace
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF7E5EFD).withOpacity(0.25),
                  style: BorderStyle.solid,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddWorkspaceEmailScreen(
                        userId: widget.userId,
                        token: widget.token,
                      ),
                    ),
                  );
                  
                  // Refresh workspaces list if a new workspace was added
                  if (result == true) {
                    _fetchWorkspaces();
                  }
                },
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E5EFD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Add New Workspace',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7E5EFD),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Help section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Need help with workspaces?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Each workspace is a separate company account with its own team members and expenses.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Wire to support screen when available
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Contact Support',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  // Helper method to format role text
  String _formatRole(String role) {
    return role[0].toUpperCase() + role.substring(1);
  }

  // Helper method to get role colors
  (Color, Color) _getRoleColors(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return (const Color(0xFFE5DDFF), const Color(0xFF7E5EFD));
      case 'manager':
        return (const Color(0xFFE5DDFF), const Color(0xFF7E5EFD));
      case 'member':
      case 'user':
        return (const Color(0xFFDFF3E3), const Color(0xFF22C55E));
      default:
        return (const Color(0xFFE5DDFF), const Color(0xFF7E5EFD));
    }
  }

  // Helper method to navigate to appropriate dashboard based on role
  void _navigateToWorkspaceDashboard(Map<String, dynamic> workspace) {
    final role = workspace['role']?.toString().toLowerCase() ?? 'member';
    final workspaceId = workspace['id']?.toString() ?? '';
    final workspaceName = workspace['name'] ?? 'Workspace';

    Widget dashboardScreen;
    
    switch (role) {
      case 'owner':
        dashboardScreen = WorkspaceDashboardScreen(
          userId: widget.userId,
          token: widget.token,
          workspaceId: workspaceId,
        );
        break;
      case 'manager':
        dashboardScreen = WorkspaceManagerDashboardScreen(
          userId: widget.userId,
          token: widget.token,
          workspaceId: workspaceId,
        );
        break;
      case 'member':
      case 'user':
      default:
        dashboardScreen = WorkspaceUserDashboardScreen(
          userId: widget.userId,
          token: widget.token,
          workspaceName: workspaceName,
          workspaceId: workspaceId,
        );
        break;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => dashboardScreen),
    );
  }

  Widget _buildWorkspaceTile({
    required String name,
    required String membersText,
    required String roleLabel,
    required Color roleColor,
    required Color roleTextColor,
    VoidCallback? onTap,
    VoidCallback? onRoleTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    membersText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onRoleTap ?? onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  roleLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: roleTextColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


