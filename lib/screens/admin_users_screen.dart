import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../widgets/curved_background.dart';
import 'admin_user_details_screen.dart';
import '../models/pagination_model.dart';
import '../services/version_service.dart';

class AdminUsersScreen extends StatefulWidget {
  final String adminId;
  final String token;

  const AdminUsersScreen({
    Key? key,
    required this.adminId,
    required this.token,
  }) : super(key: key);

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'name';
  String _sortOrder = 'ASC';
  String? _isActiveFilter;
  PaginationMeta? _pagination;
  int _currentPage = 1;
  final int _limit = 50;
  String? _errorMessage;
  String? _timeRangeFilter;

  static const Map<String, String> _timeFilterOptions = {
    'today': 'Today',
    'yesterday': 'Yesterday',
    'week': 'Past Week',
    'sixMonths': 'Six Months',
  };

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(() {
      // Reset to page 1 on search change
      _currentPage = 1;
      _fetchUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers({int? page}) async {
    if (page != null) {
      _currentPage = page;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isTimeRangeFilterApplied = _timeRangeFilter != null;

      // When a time filter is selected, use simplified payload:
      // platform, currentVersion, userId, filter
      Uri uri;
      if (isTimeRangeFilterApplied) {
        final platform = VersionService.platform ?? 'unknown';
        final currentVersion = VersionService.currentVersion ?? '1.0.0';

        final filterParams = <String, String>{
          'platform': platform,
          'currentVersion': currentVersion,
          'userId': widget.adminId,
          'filter': _timeRangeFilter!,
        };

        uri = Uri.parse('${dotenv.env['API_BASE_URL']}/api/admin/users')
            .replace(queryParameters: filterParams);
      } else {
        final requestedPage = _currentPage;
        final requestedLimit = _limit;

        // Default pagination + sorting behavior when no time filter is applied
        final queryParams = <String, String>{
          'page': requestedPage.toString(),
          'limit': requestedLimit.toString(),
        };

        // Add search parameter
        if (_searchController.text.isNotEmpty) {
          queryParams['search'] = _searchController.text.trim();
        }

        // Add sort parameters (exclude receiptCount as backend doesn't support it)
        if (_sortBy != 'receiptCount') {
          // Map lastActive to lastActivity for backend
          final backendSortBy =
              _sortBy == 'lastActive' ? 'lastActivity' : _sortBy;
          queryParams['sortBy'] = backendSortBy;
          queryParams['sortOrder'] = _sortOrder;
        }

        // Add active filter if set
        if (_isActiveFilter != null) {
          queryParams['isActive'] = _isActiveFilter!;
        }

        uri = Uri.parse('${dotenv.env['API_BASE_URL']}/api/admin/users')
            .replace(queryParameters: queryParams);
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('Fetch Users - Response status: ${response.statusCode}');
      debugPrint('Fetch Users - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> usersList = data['users'] ?? [];
        
        // Parse pagination
        PaginationMeta? pagination;
        if (data['pagination'] != null) {
          pagination = PaginationMeta.fromJson(data['pagination']);
        }

        setState(() {
          _users = List<Map<String, dynamic>>.from(usersList);
          _sortUsersInPlace();
          _pagination = pagination;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load users: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      setState(() {
        _errorMessage = 'Network error: Unable to connect to server';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final url = Uri.parse(
          '${dotenv.env['API_BASE_URL']}/api/users/delete-account');

      debugPrint('Deleting user with URL: $url');
      debugPrint('User ID to delete: $userId');

      // Changed from http.delete to http.post
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userId': userId,
        }),
      );

      // Hide loading indicator
      Navigator.of(context).pop();

      debugPrint('Delete User - Response status: ${response.statusCode}');
      debugPrint('Delete User - Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Refresh the current page
        _fetchUsers();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "$userName" deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('Failed to delete user: ${response.statusCode}');
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      debugPrint('Error deleting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete user "$userName": ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _updateUser(String userId, Map<String, dynamic> userData) async {
    try {
      final url = Uri.parse(
          '${dotenv.env['API_BASE_URL']}/api/admin/users/$userId');

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(userData),
      );

      debugPrint('Update User - Response status: ${response.statusCode}');
      debugPrint('Update User - Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Refresh the current page
        _fetchUsers();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update user: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error updating user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update user'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _changeSortOrder(String field) {
    setState(() {
      if (_sortBy == field) {
        // Toggle sort order
        _sortOrder = _sortOrder == 'ASC' ? 'DESC' : 'ASC';
      } else {
        _sortBy = field;
        _sortOrder = 'ASC';
      }
      _currentPage = 1; // Reset to first page on sort change
      _fetchUsers();
    });
  }

  /// Parse last-active date from user map (supports lastActive, lastActiveAt, lastActivity).
  DateTime? _parseLastActive(Map<String, dynamic> user) {
    final raw = user['lastActive'] ?? user['lastActiveAt'] ?? user['lastActivity'];
    if (raw == null || raw.toString().isEmpty) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  /// Sort _users by current _sortBy and _sortOrder (ensures correct order for last login).
  void _sortUsersInPlace() {
    final ascending = _sortOrder == 'ASC';
    _users.sort((a, b) {
      switch (_sortBy) {
        case 'lastActivity':
          final da = _parseLastActive(a);
          final db = _parseLastActive(b);
          if (da == null && db == null) return 0;
          if (da == null) return ascending ? 1 : -1;
          if (db == null) return ascending ? -1 : 1;
          return ascending ? da.compareTo(db) : db.compareTo(da);
        case 'name':
          final na = (a['name'] ?? a['fullName'] ?? '').toString().toLowerCase();
          final nb = (b['name'] ?? b['fullName'] ?? '').toString().toLowerCase();
          return ascending ? na.compareTo(nb) : nb.compareTo(na);
        case 'email':
          final ea = (a['email'] ?? '').toString().toLowerCase();
          final eb = (b['email'] ?? '').toString().toLowerCase();
          return ascending ? ea.compareTo(eb) : eb.compareTo(ea);
        case 'receiptCount':
          final ra = (a['receiptCount'] ?? a['totalReceipts'] ?? 0) as num;
          final rb = (b['receiptCount'] ?? b['totalReceipts'] ?? 0) as num;
          return ascending ? ra.compareTo(rb) : rb.compareTo(ra);
        default:
          return 0;
      }
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Never';

    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString; // Return original string if parsing fails
    }
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Never';

    try {
      final raw = dateString.trim();
      // If backend sends only date (YYYY-MM-DD), show month, day and year
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
        final dateOnly = DateTime.parse(raw);
        return DateFormat('MMM dd, yyyy').format(dateOnly);
      }

      // Otherwise include time as well
      final dateTime = DateTime.parse(raw).toLocal();
      return DateFormat('MMM dd, yyyy, HH:mm').format(dateTime);
    } catch (e) {
      return dateString; // Return original string if parsing fails
    }
  }

  String _wrapNameAfterFirstName(String name) {
    if (name.isEmpty) return name;
    
    final nameParts = name.trim().split(' ');
    if (nameParts.length <= 1) return name;
    
    final firstName = nameParts[0];
    final remainingName = nameParts.sublist(1).join(' ');
    return '$firstName\n$remainingName';
  }

  String _wrapEmailAfterAt(String email) {
    if (email.isEmpty || !email.contains('@')) return email;
    
    final atIndex = email.indexOf('@');
    final beforeAt = email.substring(0, atIndex);
    final afterAt = email.substring(atIndex);
    return '$beforeAt\n$afterAt';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Manage Users',
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

              // Search and Filter Bar
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Flexible(
                          flex: 3,
                          child: SizedBox(
                            height: 56,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Search users by name or email',
                                  prefixIcon: Icon(Icons.search),
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 15),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 1,
                          child: SizedBox(
                            height: 56,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _timeRangeFilter,
                                  isExpanded: true,
                                  hint: const Text(
                                    'Filter',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('All Time'),
                                    ),
                                    ..._timeFilterOptions.entries.map(
                                      (entry) => DropdownMenuItem<String?>(
                                        value: entry.key,
                                        child: Text(entry.value),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _timeRangeFilter = value;
                                      _currentPage = 1;
                                    });
                                    _fetchUsers();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Users List
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
                        onPressed: _fetchUsers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF7E5EFD),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
                    : Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: _users.isEmpty
                      ? const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                      : Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildSortableHeader(
                                  'Name', 'name'),
                            ),
                            Expanded(
                              flex: 3,
                              child: _buildSortableHeader(
                                  'Email', 'email'),
                            ),
                            Expanded(
                              flex: 3,
                              child: _buildSortableHeader(
                                  'Last Login', 'lastActive'),
                            ),
                            Expanded(
                              flex: 2,
                              child: _buildSortableHeader(
                                  'Receipts', 'receiptCount'),
                            ),
                            const SizedBox(
                                width: 40), // Action column
                          ],
                        ),
                      ),

                      // Table Body
                      Expanded(
                        child: ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return _buildUserRow(user);
                          },
                        ),
                      ),

                      // Pagination Controls
                      if (_pagination != null)
                        _buildPaginationControls(),
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


  Widget _buildSortableHeader(String title, String field) {
    final isCurrentSortField = _sortBy == field;

    return GestureDetector(
      onTap: () => _changeSortOrder(field),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight:
                isCurrentSortField ? FontWeight.bold : FontWeight.normal,
                color:
                isCurrentSortField ? const Color(0xFF7E5EFD) : Colors.black,
              ),
            ),
          ),
          if (isCurrentSortField)
            Icon(
              _sortOrder == 'ASC' ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: const Color(0xFF7E5EFD),
            ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_pagination == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        color: Colors.grey.shade50,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page info
          Text(
            'Page ${_pagination!.page} of ${_pagination!.totalPages} (${_pagination!.total} total)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),

          // Navigation buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _pagination!.hasPrevious && !_isLoading
                    ? () => _fetchUsers(page: _currentPage - 1)
                    : null,
                tooltip: 'Previous page',
              ),
              Text(
                '${_pagination!.page}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _pagination!.hasMore && !_isLoading
                    ? () => _fetchUsers(page: _currentPage + 1)
                    : null,
                tooltip: 'Next page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminUserDetailsScreen(
              adminId: widget.adminId,
              token: widget.token,
              userId: user['id'],
              userData: user,
            ),
          ),
        ).then((_) => _fetchUsers());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                _wrapNameAfterFirstName(user['name'] ?? 'Unknown'),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _wrapEmailAfterAt(user['email'] ?? 'No email'),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatDateTime(user['lastActive']?.toString() ?? 
                    user['lastActiveAt']?.toString() ??
                    user['lastActivity']?.toString()),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${user['receiptCount']?.toString() ?? user['totalReceipts']?.toString() ?? '0'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showUserActions(user),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserActions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminUserDetailsScreen(
                        adminId: widget.adminId,
                        token: widget.token,
                        userId: user['id'],
                        userData: user,
                      ),
                    ),
                  ).then((_) => _fetchUsers());
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit User'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditUserDialog(user);
                },
              ),
              ListTile(
                leading: Icon(
                  user['status'] == 'Active' ? Icons.block : Icons.check_circle,
                  color: user['status'] == 'Active' ? Colors.red : Colors.green,
                ),
                title: Text(
                  user['status'] == 'Active'
                      ? 'Deactivate User'
                      : 'Activate User',
                  style: TextStyle(
                    color:
                    user['status'] == 'Active' ? Colors.red : Colors.green,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleUserStatus(user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete User',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteUser(user);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final nameController = TextEditingController(text: user['name']);
    final emailController = TextEditingController(text: user['email']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                  ),
                  keyboardType: TextInputType.emailAddress,
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
              onPressed: () {
                if (nameController.text.isEmpty ||
                    emailController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                _updateUser(user['id'], {
                  'name': nameController.text,
                  'email': emailController.text,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
              ),
              child: const Text('Update User'),
            ),
          ],
        );
      },
    );
  }

  void _toggleUserStatus(Map<String, dynamic> user) {
    final newStatus = user['status'] == 'Active' ? 'Inactive' : 'Active';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              '${user['status'] == 'Active' ? 'Deactivate' : 'Activate'} User'),
          content: Text(
              'Are you sure you want to ${user['status'] == 'Active' ? 'deactivate' : 'activate'} ${user['name']}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateUser(user['id'], {'status': newStatus});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                user['status'] == 'Active' ? Colors.red : Colors.green,
              ),
              child:
              Text(user['status'] == 'Active' ? 'Deactivate' : 'Activate'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "${user['name']}"?'),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone and will permanently remove:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              const Text('• User account and profile'),
              const Text('• All user receipts and data'),
              const Text('• User activity history'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteUser(user['id'], user['name'] ?? 'Unknown User');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete User'),
            ),
          ],
        );
      },
    );
  }
}
