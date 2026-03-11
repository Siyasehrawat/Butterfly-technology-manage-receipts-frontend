import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/workspace_service.dart';

class ManageTeamMembersScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String? workspaceId;

  const ManageTeamMembersScreen({
    Key? key,
    required this.userId,
    required this.token,
    this.workspaceId,
  }) : super(key: key);

  @override
  State<ManageTeamMembersScreen> createState() => _ManageTeamMembersScreenState();
}

class _ManageTeamMembersScreenState extends State<ManageTeamMembersScreen> {
  bool _isCopied = false;
  bool _isLoading = true;
  bool _isLoadingInvites = true;
  String? _errorMessage;
  String? _inviteErrorMessage;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _invites = [];

  String get _inviteLink =>
      'https://managereceipt.com/join?workspaceId=${widget.workspaceId ?? ''}';

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadInvites();
  }

  Future<void> _loadMembers() async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Workspace is required to load members';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await WorkspaceService.listMembers(
      workspaceId: widget.workspaceId!,
      userId: widget.userId, // Using userId as fallback until memberId is available
      token: widget.token,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      try {
        final data = result['data'] as Map<String, dynamic>;
        final membersList = (data['members'] ?? []) as List<dynamic>;
        setState(() {
          _members = membersList.map(_normalizeMember).toList();
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to parse team members';
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

  Future<void> _loadInvites() async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      setState(() {
        _isLoadingInvites = false;
        _inviteErrorMessage = 'Workspace is required to load invites';
      });
      return;
    }

    setState(() {
      _isLoadingInvites = true;
      _inviteErrorMessage = null;
    });

    final result = await WorkspaceService.listInvites(
      workspaceId: widget.workspaceId!,
      userId: widget.userId, // Using userId as fallback until memberId is available
      token: widget.token,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      try {
        final data = result['data'] as Map<String, dynamic>;
        final invitesList = (data['invites'] ?? data['pendingInvites'] ?? []) as List<dynamic>;
        setState(() {
          _invites = invitesList.map(_normalizeInvite).toList();
          _isLoadingInvites = false;
        });
      } catch (e) {
        setState(() {
          _inviteErrorMessage = 'Failed to parse invites';
          _isLoadingInvites = false;
        });
      }
    } else {
      setState(() {
        _inviteErrorMessage = result['error']?.toString() ?? 'Failed to load invites';
        _isLoadingInvites = false;
      });
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
          'Manage Team Members',
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
        child: _buildBody(),
      ),
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildInviteSection(),
        const SizedBox(height: 24),
        _buildPendingInvitesSection(),
        const SizedBox(height: 24),
        _buildTeamMembersSection(),
      ],
    );
  }

  Widget _buildInviteSection() {
    final workspaceMissing = widget.workspaceId == null || widget.workspaceId!.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Invite New Members',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            ElevatedButton.icon(
              onPressed: workspaceMissing ? null : () => _showCreateInviteDialog(),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Send Invite'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  workspaceMissing ? 'Workspace not selected' : _inviteLink,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: (workspaceMissing || _isCopied) ? null : _copyLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _isCopied ? 'Copied' : 'Copy',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Share this link with new team members to join your workspace',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPendingInvitesSection() {
    if (_isLoadingInvites) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
          ),
        ),
      );
    }

    if (_inviteErrorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _inviteErrorMessage!,
          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
        ),
      );
    }

    if (_invites.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Invites (${_invites.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _invites.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final invite = _invites[index];
            return _buildInviteCard(invite);
          },
        ),
      ],
    );
  }

  Widget _buildTeamMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Team Members (${_members.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddMemberDialog(),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add Member'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_members.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('No team members yet'),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _members.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final member = _members[index];
              final name = member['name'] ?? member['email'] ?? 'Unknown';
              final email = member['email'] ?? '';
              final role = _formatRole(member['role'] ?? 'member');
              final isOwner = (member['role'] ?? '').toString().toLowerCase() == 'owner';
              final isYou = member['userId'] == widget.userId;

              Color roleColor;
              Color roleTextColor;
              switch ((member['role'] ?? 'member').toString().toLowerCase()) {
                case 'owner':
                  roleColor = Colors.red.shade100;
                  roleTextColor = Colors.red.shade700;
                  break;
                case 'manager':
                  roleColor = Colors.green.shade100;
                  roleTextColor = Colors.green.shade700;
                  break;
                default:
                  roleColor = Colors.blue.shade100;
                  roleTextColor = Colors.blue.shade700;
              }

              return _buildTeamMemberCard(
                member: member,
                name: name,
                email: email,
                role: role,
                roleColor: roleColor,
                roleTextColor: roleTextColor,
                showRemove: !isOwner && !isYou,
              );
            },
          ),
      ],
    );
  }

  Widget _buildTeamMemberCard({
    required Map<String, dynamic> member,
    required String name,
    required String email,
    required String role,
    required Color roleColor,
    required Color roleTextColor,
    required bool showRemove,
  }) {
    final initials = name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF7E5EFD),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: roleTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => _showEditDialog(member),
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    color: Color(0xFF7E5EFD),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showRemove)
                TextButton(
                  onPressed: () => _showRemoveDialog(member),
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _inviteLink));
    setState(() {
      _isCopied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildRoleFieldWithDropdown({
    required GlobalKey fieldKey,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String selectedRole,
    required List<String> roles,
    required void Function(String) onRoleSelected,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Role',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'Select role',
            border: const OutlineInputBorder(),
            suffixIcon: GestureDetector(
              onTap: () => _showRoleMenu(context, fieldKey, roles, selectedRole, onRoleSelected),
              child: Icon(
                Icons.arrow_drop_down,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          style: const TextStyle(fontSize: 16),
          onTap: () => _showRoleMenu(context, fieldKey, roles, selectedRole, onRoleSelected),
        ),
      ],
    );
  }

  void _showRoleMenu(
    BuildContext context,
    GlobalKey fieldKey,
    List<String> roles,
    String selectedRole,
    void Function(String) onRoleSelected,
  ) {
    final RenderBox? renderBox = fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        MediaQuery.of(context).size.width - offset.dx - size.width,
        MediaQuery.of(context).size.height - offset.dy - size.height - 4,
      ),
      constraints: BoxConstraints(
        maxHeight: 200,
        minWidth: size.width,
        maxWidth: size.width,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      elevation: 8,
      items: roles.map((role) {
        final isSelected = selectedRole.toLowerCase() == role.toLowerCase();
        return PopupMenuItem<String>(
          value: role,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  role[0].toUpperCase() + role.substring(1),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF7E5EFD) : Colors.black,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check,
                  color: Color(0xFF7E5EFD),
                  size: 18,
                ),
            ],
          ),
        );
      }).toList(),
    ).then((selected) {
      if (selected != null) {
        onRoleSelected(selected);
      }
    });
  }

  void _showCreateInviteDialog() {
    final emailController = TextEditingController();
    final roleController = TextEditingController(text: 'Member');
    final roleFocusNode = FocusNode();
    final roleFieldKey = GlobalKey();
    String selectedRole = 'member';
    final roles = ['member', 'manager'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Send Invite'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      hintText: 'Enter email address',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildRoleFieldWithDropdown(
                    fieldKey: roleFieldKey,
                    controller: roleController,
                    focusNode: roleFocusNode,
                    selectedRole: selectedRole,
                    roles: roles,
                    onRoleSelected: (role) {
                      setDialogState(() {
                        selectedRole = role;
                        roleController.text = role[0].toUpperCase() + role.substring(1);
                      });
                    },
                    context: context,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  if (email.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter an email address')),
                    );
                    return;
                  }

                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid email address')),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  await _createInvite(email, selectedRole);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Send Invite'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddMemberDialog() {
    final emailController = TextEditingController();
    final roleController = TextEditingController(text: 'Member');
    final roleFocusNode = FocusNode();
    final roleFieldKey = GlobalKey();
    String selectedRole = 'member';
    bool assignLicense = true;
    final roles = ['member', 'manager'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Team Member'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      hintText: 'Enter member email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildRoleFieldWithDropdown(
                    fieldKey: roleFieldKey,
                    controller: roleController,
                    focusNode: roleFocusNode,
                    selectedRole: selectedRole,
                    roles: roles,
                    onRoleSelected: (role) {
                      setDialogState(() {
                        selectedRole = role;
                        roleController.text = role[0].toUpperCase() + role.substring(1);
                      });
                    },
                    context: context,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Switch(
                        activeColor: const Color(0xFF7E5EFD),
                        value: assignLicense,
                        onChanged: (val) {
                          setDialogState(() {
                            assignLicense = val;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Assign License'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  if (email.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter an email address')),
                    );
                    return;
                  }

                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid email address')),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  await _addMember(email, selectedRole, assignLicense);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Member'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> member) {
    String selectedRole = (member['role'] ?? 'member').toString().toLowerCase();
    bool licenseAssigned = member['licenseAssigned'] == true;
    final roleController = TextEditingController(
      text: selectedRole[0].toUpperCase() + selectedRole.substring(1),
    );
    final roleFocusNode = FocusNode();
    final roleFieldKey = GlobalKey();
    final roles = ['owner', 'manager', 'member'];

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Member',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildRoleFieldWithDropdown(
                    fieldKey: roleFieldKey,
                    controller: roleController,
                    focusNode: roleFocusNode,
                    selectedRole: selectedRole,
                    roles: roles,
                    onRoleSelected: (role) {
                      setDialogState(() {
                        selectedRole = role;
                        roleController.text = role[0].toUpperCase() + role.substring(1);
                      });
                    },
                    context: context,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Switch(
                        activeColor: const Color(0xFF7E5EFD),
                        value: licenseAssigned,
                        onChanged: (val) {
                          setDialogState(() {
                            licenseAssigned = val;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text('License assigned'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _updateMember(member, selectedRole, licenseAssigned);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRemoveDialog(Map<String, dynamic> member) {
    final memberId = member['id']?.toString() ?? '';
    final name = member['name'] ?? 'this member';
    if (memberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing member id')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeMember(memberId);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMember(
    Map<String, dynamic> member,
    String role,
    bool assignLicense,
  ) async {
    final memberId = member['id']?.toString() ?? '';
    if (memberId.isEmpty || widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing workspace or member id')),
      );
      return;
    }

      final res = await WorkspaceService.updateMember(
        workspaceId: widget.workspaceId!,
        memberId: memberId,
        userId: widget.userId, // Using userId as fallback until memberId is available
        body: {
        'role': role,
        'assignLicense': assignLicense,
      },
      token: widget.token,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member updated')),
      );
      await _loadMembers();
      await _loadInvites();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Update failed')),
      );
    }
  }

  Future<void> _addMember(String email, String role, bool assignLicense) async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace missing')),
      );
      return;
    }

    // Note: The API requires memberUserId for direct member addition.
    // Since we only have email, we'll use invites instead for email-based additions.
    // Direct member addition should be used when you have the user ID.
    
    // For now, we'll use invites when only email is provided
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
        ),
      ),
    );

    // Use invite API since we only have email
    final res = await WorkspaceService.createInvite(
      workspaceId: widget.workspaceId!,
      userId: widget.userId, // Using userId as fallback until memberId is available
      body: {
        'email': email,
        'role': role,
      },
      token: widget.token,
    );

    if (!mounted) return;

    Navigator.pop(context); // Close loading dialog

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite sent successfully. The user will be added as a member when they accept the invite.'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadMembers();
      await _loadInvites();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Failed to send invite'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeMember(String memberId) async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace missing')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
        ),
      ),
    );

      final res = await WorkspaceService.removeMember(
        workspaceId: widget.workspaceId!,
        memberId: memberId,
        userId: widget.userId, // Using userId as fallback until memberId is available
        token: widget.token,
      );

    if (!mounted) return;

    Navigator.pop(context); // Close loading dialog

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Member removed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadMembers();
      await _loadInvites();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Failed to remove member'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatRole(String role) {
    if (role.isEmpty) return 'Member';
    return role[0].toUpperCase() + role.substring(1);
  }

  Widget _buildInviteCard(Map<String, dynamic> invite) {
    final email = invite['email'] ?? '';
    final role = invite['role'] ?? 'member';
    final token = invite['token'] ?? '';
    final createdAt = invite['createdAt'] ?? '';
    final inviteLink = token.isNotEmpty
        ? 'https://managereceipt.com/join?token=$token'
        : _inviteLink;

    Color roleColor;
    Color roleTextColor;
    switch (role.toLowerCase()) {
      case 'manager':
        roleColor = Colors.green.shade100;
        roleTextColor = Colors.green.shade700;
        break;
      default:
        roleColor = Colors.blue.shade100;
        roleTextColor = Colors.blue.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Icon(
                Icons.mail_outline,
                color: Colors.orange,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatRole(role),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: roleTextColor,
                        ),
                      ),
                    ),
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (token.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: inviteLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite link copied')),
                      );
                    },
                    child: Row(
                      children: [
                        Icon(Icons.link, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            inviteLink,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => _showCancelInviteDialog(invite),
            tooltip: 'Cancel invite',
          ),
        ],
      ),
    );
  }

  Future<void> _createInvite(String email, String role) async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace missing')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
        ),
      ),
    );

    final res = await WorkspaceService.createInvite(
      workspaceId: widget.workspaceId!,
      userId: widget.userId, // Using userId as fallback until memberId is available
      body: {
        'email': email,
        'role': role,
      },
      token: widget.token,
    );

    if (!mounted) return;

    Navigator.pop(context); // Close loading dialog

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite sent successfully'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadInvites();
      await _loadMembers(); // Refresh members in case invite was accepted immediately
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Failed to send invite'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCancelInviteDialog(Map<String, dynamic> invite) {
    final email = invite['email'] ?? 'this invite';
    final inviteId = invite['id']?.toString() ?? '';

    if (inviteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite ID not available')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Invite'),
        content: Text('Are you sure you want to cancel the invite for $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelInvite(inviteId);
            },
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelInvite(String inviteId) async {
    // Note: If there's a delete invite endpoint, use it here
    // For now, we'll just remove it from the list
    // You may need to add a deleteInvite method to WorkspaceService
    
    setState(() {
      _invites.removeWhere((invite) => invite['id']?.toString() == inviteId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite cancelled')),
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateString;
    }
  }

  Map<String, dynamic> _normalizeInvite(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final email = map['email'] ?? '';
    final role = (map['role'] ?? 'member').toString().toLowerCase();
    final token = map['token'] ?? map['inviteToken'] ?? '';
    final createdAt = map['createdAt'] ?? map['created'] ?? map['invitedAt'] ?? '';
    final id = map['id'] ?? map['_id'] ?? map['inviteId'] ?? token;

    return {
      'id': id,
      'email': email,
      'role': role,
      'token': token,
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> _normalizeMember(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final name = map['name'] ??
        map['fullName'] ??
        map['displayName'] ??
        map['email'] ??
        'Unknown';
    final email = map['email'] ?? map['companyEmail'] ?? '';
    final role = (map['role'] ?? 'member').toString().toLowerCase();
    final licenseAssigned =
        map['licenseAssigned'] ?? map['assignLicense'] ?? map['hasLicense'] ?? false;
    final userId = map['userId'] ?? map['memberUserId'] ?? map['ownerId'] ?? '';
    final id = map['id'] ?? map['_id'] ?? map['memberId'] ?? userId ?? email;

    return {
      'id': id,
      'userId': userId,
      'name': name,
      'email': email,
      'role': role,
      'licenseAssigned': licenseAssigned,
    };
  }
}




