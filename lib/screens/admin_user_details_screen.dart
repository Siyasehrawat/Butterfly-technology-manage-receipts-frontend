import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/curved_background.dart';
import '../services/api_service_bypass.dart'; // Import the ApiService

class AdminUserDetailsScreen extends StatefulWidget {
  final String adminId;
  final String token;
  final String userId;
  final Map<String, dynamic> userData;

  const AdminUserDetailsScreen({
    Key? key,
    required this.adminId,
    required this.token,
    required this.userId,
    required this.userData,
  }) : super(key: key);

  @override
  State<AdminUserDetailsScreen> createState() => _AdminUserDetailsScreenState();
}

class _AdminUserDetailsScreenState extends State<AdminUserDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _userDetails = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Set the context for ApiService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ApiService.setContext(context);
    });
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Fetching user details for userId: ${widget.userId}');

      // Use ApiService instead of direct HTTP call
      final response = await ApiService.get(
        '/admin/users/${widget.userId}',
        token: widget.token,
      );

      debugPrint('User Details - Response status: ${response.statusCode}');
      debugPrint('User Details - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle different response structures
        Map<String, dynamic>? userInfo = {};

        if (data is List && data.length >= 1) {
          // If response is array with user data
          userInfo = data[0] as Map<String, dynamic>? ?? {};
          debugPrint('User Details - Array format: User info');
        } else if (data is Map) {
          // If response is object with user properties
          userInfo = (data['user'] as Map<String, dynamic>? ?? data).cast<String, dynamic>();
          debugPrint('User Details - Object format: User info');
        } else {
          // Fallback to passed user data
          userInfo = widget.userData;
          debugPrint('User Details - Using fallback user data');
        }

        // Map API response fields to expected field names
        if (userInfo != null && userInfo.isNotEmpty) {
          // Map totalReceipts to receiptsCount for consistency
          if (userInfo.containsKey('totalReceipts') && !userInfo.containsKey('receiptsCount')) {
            userInfo['receiptsCount'] = userInfo['totalReceipts'];
          }
          // Map lastActivity to lastLogin for consistency
          if (userInfo.containsKey('lastActivity') && !userInfo.containsKey('lastLogin')) {
            userInfo['lastLogin'] = userInfo['lastActivity'];
          }
        }

        setState(() {
          _userDetails = (userInfo!.isNotEmpty ? userInfo : widget.userData)!;
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        // User not found, use passed data
        setState(() {
          _userDetails = widget.userData;
          _errorMessage = 'User details not found on server';
          _isLoading = false;
        });
      } else {
        setState(() {
          _userDetails = widget.userData;
          _errorMessage = 'Failed to load user details: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user details: $e');
      setState(() {
        _userDetails = widget.userData;
        _errorMessage = 'Network error: Unable to connect to server';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserDetails(Map<String, dynamic> updatedData) async {
    try {
      debugPrint('Updating user details for userId: ${widget.userId}');

      // Use ApiService instead of direct HTTP call
      final response = await ApiService.put(
        '/admin/users/${widget.userId}',
        body: updatedData,
        token: widget.token,
      );

      debugPrint('Update User Details - Response status: ${response.statusCode}');
      debugPrint('Update User Details - Response body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _userDetails = {..._userDetails, ...updatedData};
        });

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
        SnackBar(
          content: Text('Failed to update user: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetUserPassword(String newPassword) async {
    try {
      debugPrint('Resetting password for userId: ${widget.userId}');

      // Use ApiService for password reset
      final response = await ApiService.put(
        '/admin/users/${widget.userId}/reset-password',
        body: {'newPassword': newPassword},
        token: widget.token,
      );

      debugPrint('Reset Password - Response status: ${response.statusCode}');
      debugPrint('Reset Password - Response body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to reset password: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error resetting password: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset password: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Not available';

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
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return dateString; // Return original string if parsing fails
    }
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
                          'User Details',
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

              // User Details Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchUserDetails,
                  color: const Color(0xFF7E5EFD),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Loading indicator
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),

                        // Error message
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.orange.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // User Profile Card
                        Container(
                          margin: const EdgeInsets.all(16),
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
                            children: [
                              // User Avatar
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: const Color(0xFFF0EAFF),
                                child: Text(
                                  (_userDetails['name']?.toString() ?? 'U')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7E5EFD),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // User Name
                              Text(
                                _userDetails['name']?.toString() ?? 'Unknown User',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // User Email
                              Text(
                                _userDetails['email']?.toString() ?? 'No email',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Action Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _showEditUserDialog();
                                    },
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Edit'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7E5EFD),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      _showResetPasswordDialog();
                                    },
                                    icon: const Icon(Icons.lock_reset),
                                    label: const Text('Reset Password'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF7E5EFD),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // User Information Card
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
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
                                'User Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // User ID
                              _buildInfoRow(
                                'User ID',
                                _userDetails['id']?.toString() ?? 'Not available',
                                Icons.fingerprint,
                              ),
                              const Divider(),

                              // Country
                              _buildInfoRow(
                                'Country',
                                _userDetails['country']?.toString() ?? 'Not provided',
                                Icons.public,
                              ),
                              const Divider(),

                              // Joining Date (Created At)
                              _buildInfoRow(
                                'Joining Date',
                                _formatDate(_userDetails['createdAt']?.toString() ??
                                    _userDetails['joinedAt']?.toString()),
                                Icons.calendar_today,
                              ),
                              const Divider(),

                              // Last Login Date
                              _buildInfoRow(
                                'Last Login',
                                _formatDateTime(_userDetails['lastLogin']?.toString() ??
                                    _userDetails['lastLoginAt']?.toString()),
                                Icons.login,
                              ),
                              const Divider(),

                              // Receipts Count
                              _buildInfoRow(
                                'Total Receipts',
                                '${_userDetails['receiptsCount']?.toString() ?? '0'}',
                                Icons.receipt_long,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EAFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF7E5EFD),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _showEditUserDialog() {
    final nameController = TextEditingController(text: _userDetails['name']?.toString());
    final emailController = TextEditingController(text: _userDetails['email']?.toString());
    final countryController = TextEditingController(text: _userDetails['country']?.toString());

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
                const SizedBox(height: 16),
                TextField(
                  controller: countryController,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                  ),
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
                Navigator.pop(context);
                _updateUserDetails({
                  'name': nameController.text,
                  'email': emailController.text,
                  'country': countryController.text,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
              ),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showResetPasswordDialog() {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter a new password for this user.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
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
                if (passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a password'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (passwordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Passwords do not match'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                _resetUserPassword(passwordController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
              ),
              child: const Text('Reset Password'),
            ),
          ],
        );
      },
    );
  }

}