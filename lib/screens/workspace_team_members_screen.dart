import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/workspace_service.dart';
import '../web/app/workspace_team_management_web_screen.dart';

class WorkspaceTeamMembersScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String workspaceId;
  final bool isReadOnly; // For regular users who can only view

  const WorkspaceTeamMembersScreen({
    Key? key,
    required this.userId,
    required this.token,
    required this.workspaceId,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  State<WorkspaceTeamMembersScreen> createState() => _WorkspaceTeamMembersScreenState();
}

class _WorkspaceTeamMembersScreenState extends State<WorkspaceTeamMembersScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await WorkspaceService.listMembers(
      workspaceId: widget.workspaceId,
      userId: widget.userId,
      token: widget.token,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      try {
        final data = result['data'] as Map<String, dynamic>;
        final membersList = (data['members'] ?? []) as List<dynamic>;

        setState(() {
          _members = membersList.map((m) => m as Map<String, dynamic>).toList();
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to parse team members data';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = result['error']?.toString() ?? 'Failed to load team members';
        _isLoading = false;
      });
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'U';
  }

  String _formatRole(String role) {
    // Capitalize first letter
    return role[0].toUpperCase() + role.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    // Redirect to web team management if on web platform and not read-only
    if (kIsWeb && !widget.isReadOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkspaceTeamManagementWebScreen(
              userId: widget.userId,
              token: widget.token,
              workspaceId: widget.workspaceId,
              workspaceName: 'Workspace',
            ),
          ),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
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
          'Team Members',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!widget.isReadOnly)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadMembers,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadMembers,
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

    if (_members.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No team members yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Invite team members to get started',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _members.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final member = _members[index];
        final name = member['name'] ?? member['email'] ?? 'Unknown';
        final email = member['email'] ?? '';
        final role = _formatRole(member['role'] ?? 'member');
        final isYou = member['userId'] == widget.userId;
        final licenseAssigned = member['licenseAssigned'] ?? false;

        return _MemberTile(
          initials: _getInitials(name),
          name: name,
          email: email,
          role: role,
          isYou: isYou,
          licenseAssigned: licenseAssigned,
        );
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String initials;
  final String name;
  final String email;
  final String role;
  final bool isYou;
  final bool licenseAssigned;

  const _MemberTile({
    Key? key,
    required this.initials,
    required this.name,
    required this.email,
    required this.role,
    required this.isYou,
    required this.licenseAssigned,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFF7E5EFD),
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (email.isNotEmpty)
            Text(
              email,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                role,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (licenseAssigned) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    'Licensed',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: isYou
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7E5EFD).withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'You',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7E5EFD),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : null,
    );
  }
}




