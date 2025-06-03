import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/curved_background.dart';
import 'admin_user_details_screen.dart';

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
  List<Map<String, dynamic>> _filteredUsers = [];
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'name';
  bool _sortAscending = true;
  String _filterStatus = 'All';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterUsers);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse(
          'https://manage-receipt-backend-bnl1.onrender.com/api/admin/users');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> usersList =
            data is List ? data : (data['users'] ?? []);
        setState(() {
          _users = List<Map<String, dynamic>>.from(usersList);
          _applyFiltersAndSort();
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

  Future<void> _deleteUser(String userId) async {
    try {
      final url = Uri.parse(
          'https://manage-receipt-backend-bnl1.onrender.com/api/admin/users/$userId');

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Remove user from local list
        setState(() {
          _users.removeWhere((u) => u['id'] == userId);
          _applyFiltersAndSort();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: Color(0xFF7E5EFD),
          ),
        );
      } else {
        throw Exception('Failed to delete user: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete user'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateUser(String userId, Map<String, dynamic> userData) async {
    try {
      final url = Uri.parse(
          'https://manage-receipt-backend-bnl1.onrender.com/api/admin/users/$userId');

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(userData),
      );

      if (response.statusCode == 200) {
        // Update user in local list
        setState(() {
          for (var i = 0; i < _users.length; i++) {
            if (_users[i]['id'] == userId) {
              _users[i] = {..._users[i], ...userData};
              break;
            }
          }
          _applyFiltersAndSort();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: Color(0xFF7E5EFD),
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

  Future<void> _createUser(Map<String, dynamic> userData) async {
    try {
      final url = Uri.parse(
          'https://manage-receipt-backend-bnl1.onrender.com/api/admin/users');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(userData),
      );

      if (response.statusCode == 201) {
        final newUser = json.decode(response.body);

        // Add user to local list
        setState(() {
          _users.add(newUser);
          _applyFiltersAndSort();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User created successfully'),
            backgroundColor: Color(0xFF7E5EFD),
          ),
        );
      } else {
        throw Exception('Failed to create user: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error creating user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create user'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterUsers() {
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    final query = _searchController.text.toLowerCase();

    // Apply filters
    List<Map<String, dynamic>> filtered = _users.where((user) {
      // Apply status filter (case-insensitive)
      if (_filterStatus != 'All' &&
          (user['status']?.toString().toLowerCase() !=
              _filterStatus.toLowerCase())) {
        return false;
      }

      // Apply search filter
      if (query.isNotEmpty) {
        final name = user['name']?.toString().toLowerCase() ?? '';
        final email = user['email']?.toString().toLowerCase() ?? '';
        return name.contains(query) || email.contains(query);
      }

      return true;
    }).toList();

    // Apply sorting
    filtered.sort((a, b) {
      dynamic valueA = a[_sortBy];
      dynamic valueB = b[_sortBy];

      // Handle null values
      if (valueA == null && valueB == null) return 0;
      if (valueA == null) return _sortAscending ? 1 : -1;
      if (valueB == null) return _sortAscending ? -1 : 1;

      // Compare values
      int comparison;
      if (valueA is String && valueB is String) {
        comparison = valueA.compareTo(valueB);
      } else if (valueA is num && valueB is num) {
        comparison = valueA.compareTo(valueB);
      } else {
        // Try to parse dates
        try {
          final dateA = DateTime.parse(valueA.toString());
          final dateB = DateTime.parse(valueB.toString());
          comparison = dateA.compareTo(dateB);
        } catch (e) {
          comparison = valueA.toString().compareTo(valueB.toString());
        }
      }

      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredUsers = filtered;
    });
  }

  void _changeSortOrder(String field) {
    setState(() {
      if (_sortBy == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = field;
        _sortAscending = true;
      }
      _applyFiltersAndSort();
    });
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
                    // Search Bar
                    Container(
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
                          contentPadding: EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Options
                    Row(
                      children: [
                        const Text(
                          'Status:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip('All'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Active'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Inactive'),
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
                            child: _filteredUsers.isEmpty
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
                                              flex: 2,
                                              child: _buildSortableHeader(
                                                  'Status', 'status'),
                                            ),
                                            const SizedBox(
                                                width: 40), // Action column
                                          ],
                                        ),
                                      ),

                                      // Table Body
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: _filteredUsers.length,
                                          itemBuilder: (context, index) {
                                            final user = _filteredUsers[index];
                                            return _buildUserRow(user);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF7E5EFD),
        onPressed: () {
          _showAddUserDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String status) {
    final isSelected = _filterStatus == status;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = status;
          _applyFiltersAndSort();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: isSelected ? const Color(0xFF7E5EFD) : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
          Text(
            title,
            style: TextStyle(
              fontWeight:
                  isCurrentSortField ? FontWeight.bold : FontWeight.normal,
              color:
                  isCurrentSortField ? const Color(0xFF7E5EFD) : Colors.black,
            ),
          ),
          if (isCurrentSortField)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: const Color(0xFF7E5EFD),
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
                user['name'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                user['email'] ?? 'No email',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: user['status'] == 'Active'
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user['status'] ?? 'Unknown',
                  style: TextStyle(
                    color: user['status'] == 'Active'
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
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

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter user name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter user email',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter temporary password',
                  ),
                  obscureText: true,
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
                    emailController.text.isEmpty ||
                    passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                _createUser({
                  'name': nameController.text,
                  'email': emailController.text,
                  'password': passwordController.text,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
              ),
              child: const Text('Add User'),
            ),
          ],
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
          content: Text(
              'Are you sure you want to delete ${user['name']}? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteUser(user['id']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
