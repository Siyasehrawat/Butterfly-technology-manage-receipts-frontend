import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'profile_screen.dart';
import 'update_password_screen.dart';
import '../providers/user_provider.dart';
import 'welcome_screen.dart';
import 'complete_profile_screen.dart';
import 'dashboard_screen.dart';
import '../services/api_service_bypass.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _emailNotifications;
  bool? _pushNotifications;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  // Load current notification settings from API
  Future<void> _loadNotificationSettings() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    final token = userProvider.token;

    if (userId == null || token == null) {
      setState(() {
        _emailNotifications = true;
        _pushNotifications = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.get(
        '/users/notification-settings/$userId',
        token: token,
      );

      debugPrint('Load notification settings response status: ${response.statusCode}');
      debugPrint('Load notification settings response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 304) {
        final data = jsonDecode(response.body);
        debugPrint('Parsed notification settings data: $data');

        setState(() {
          if (data is Map<String, dynamic>) {
            _emailNotifications = data['emailNotificationsEnabled'] ?? true;
            _pushNotifications = data['pushNotificationsEnabled'] ?? true;
          } else {
            _emailNotifications = true;
            _pushNotifications = true;
          }
        });

        debugPrint('Set email notifications to: $_emailNotifications');
        debugPrint('Set push notifications to: $_pushNotifications');
      } else {
        debugPrint('Failed to load notification settings: ${response.statusCode}');
        setState(() {
          _emailNotifications = true;
          _pushNotifications = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load notification settings'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      setState(() {
        _emailNotifications = true;
        _pushNotifications = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Update push notification setting
  Future<void> _updatePushNotification(bool value) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    final token = userProvider.token;

    if (userId == null || token == null) return;

    final originalValue = _pushNotifications;

    setState(() {
      _pushNotifications = value;
    });

    try {
      final response = await ApiService.put(
        '/users/notification-settings/$userId/push',
        body: {'pushNotificationsEnabled': value},
        token: token,
      );

      debugPrint('Update push notification response status: ${response.statusCode}');
      debugPrint('Update push notification response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final updatedValue = responseData['pushNotificationsEnabled'] ?? value;

        setState(() {
          _pushNotifications = updatedValue;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Push notifications ${updatedValue ? 'enabled' : 'disabled'}'),
              backgroundColor: const Color(0xFF7E5EFD),
            ),
          );
        }
      } else {
        setState(() {
          _pushNotifications = originalValue;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update push notification setting'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating push notification: $e');
      setState(() {
        _pushNotifications = originalValue;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating push notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Update email notification setting
  Future<void> _updateEmailNotification(bool value) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    final token = userProvider.token;

    if (userId == null || token == null) return;

    final originalValue = _emailNotifications;

    setState(() {
      _emailNotifications = value;
    });

    try {
      final response = await ApiService.put(
        '/users/notification-settings/$userId/email',
        body: {'emailNotificationsEnabled': value},
        token: token,
      );

      debugPrint('Update email notification response status: ${response.statusCode}');
      debugPrint('Update email notification response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final updatedValue = responseData['emailNotificationsEnabled'] ?? value;

        setState(() {
          _emailNotifications = updatedValue;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email notifications ${updatedValue ? 'enabled' : 'disabled'}'),
              backgroundColor: const Color(0xFF7E5EFD),
            ),
          );
        }
      } else {
        setState(() {
          _emailNotifications = originalValue;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update email notification setting'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating email notification: $e');
      setState(() {
        _emailNotifications = originalValue;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating email notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Save all settings (batch update)
  Future<void> _saveAllSettings() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    final token = userProvider.token;

    if (userId == null || token == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final responses = await Future.wait([
        ApiService.put(
          '/users/notification-settings/$userId/push',
          body: {'pushNotificationsEnabled': _pushNotifications ?? true},
          token: token,
        ),
        ApiService.put(
          '/users/notification-settings/$userId/email',
          body: {'emailNotificationsEnabled': _emailNotifications ?? true},
          token: token,
        ),
      ]);

      debugPrint('Save all settings responses: ${responses.map((r) => r.statusCode).toList()}');

      bool allSuccessful = responses.every((response) => response.statusCode == 200);

      if (allSuccessful && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Color(0xFF7E5EFD),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Some settings failed to save'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    // Debug logging to check the canUpdatePassword flag
    debugPrint('SettingsScreen - canUpdatePassword: ${userProvider.canUpdatePassword}');
    debugPrint('SettingsScreen - userId: ${userProvider.userId}');

    return Scaffold(
      body: Column(
        children: [
          // Purple header with back button
          Container(
            color: const Color(0xFF7E5EFD),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 10,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 16),
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

          // White content area
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width > 600 ? 48 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Account section
                    const Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text(
                              'Your Profile',
                              style: TextStyle(color: Colors.black),
                            ),
                            trailing: const Icon(
                              Icons.edit,
                              color: Color(0xFF7E5EFD),
                            ),
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
                          if (userProvider.canUpdatePassword) ...[
                            const Divider(height: 1),
                            ListTile(
                              title: const Text(
                                'Update Password',
                                style: TextStyle(color: Colors.black),
                              ),
                              trailing: const Icon(
                                Icons.edit,
                                color: Color(0xFF7E5EFD),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UpdatePasswordScreen(
                                      userId: userProvider.userId ?? '',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Notifications section
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text(
                              'Email Notifications',
                              style: TextStyle(color: Colors.black),
                            ),
                            subtitle: _isLoading
                                ? const Text('Loading...', style: TextStyle(color: Colors.grey))
                                : Text(
                              _emailNotifications == true ? 'Enabled' : 'Disabled',
                              style: TextStyle(
                                color: _emailNotifications == true
                                    ? const Color(0xFF7E5EFD)
                                    : Colors.grey,
                              ),
                            ),
                            value: _isLoading ? true : (_emailNotifications ?? true),
                            activeColor: const Color(0xFF7E5EFD),
                            onChanged: (_isLoading || _emailNotifications == null) ? null : (value) {
                              _updateEmailNotification(value);
                            },
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text(
                              'Push Notifications',
                              style: TextStyle(color: Colors.black),
                            ),
                            subtitle: _isLoading
                                ? const Text('Loading...', style: TextStyle(color: Colors.grey))
                                : Text(
                              _pushNotifications == true ? 'Enabled' : 'Disabled',
                              style: TextStyle(
                                color: _pushNotifications == true
                                    ? const Color(0xFF7E5EFD)
                                    : Colors.grey,
                              ),
                            ),
                            value: _isLoading ? true : (_pushNotifications ?? true),
                            activeColor: const Color(0xFF7E5EFD),
                            onChanged: (_isLoading || _pushNotifications == null) ? null : (value) {
                              _updatePushNotification(value);
                            },
                          ),
                        ],
                      ),
                    ),

                    // Show loading indicator when loading settings
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF7E5EFD),
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Delete account button
                    Center(
                      child: TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white,
                              title: const Text(
                                'Delete Account',
                                style: TextStyle(color: Colors.black),
                              ),
                              content: const Text(
                                'Are you sure you want to delete your account? This action cannot be undone.',
                                style: TextStyle(color: Colors.black87),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final userId = userProvider.userId ?? '';
                                    final token = userProvider.token ?? '';

                                    debugPrint('UserID: $userId, Token: $token');

                                    if (userId.isEmpty) {
                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('User ID is missing. Cannot delete account.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    if (token.isEmpty) {
                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Authentication token is missing. Please log in again.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    try {
                                      debugPrint('Sending delete account request...');
                                      final response = await ApiService.post(
                                        '/users/delete-account',
                                        body: {'userId': userId},
                                        token: token,
                                      );

                                      debugPrint('Delete account response status: ${response.statusCode}');
                                      debugPrint('Delete account response body: ${response.body}');

                                      if (response.statusCode == 200) {
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Account deleted successfully.'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }

                                        await userProvider.logout();

                                        if (mounted) {
                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                                                (route) => false,
                                          );
                                        }
                                      } else {
                                        String errorMsg = 'Failed to delete account.';
                                        try {
                                          final decoded = jsonDecode(response.body);
                                          if (decoded is Map && decoded['error'] != null) {
                                            errorMsg = decoded['error'].toString();
                                          }
                                        } catch (_) {
                                          debugPrint('Error parsing backend response.');
                                        }
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(errorMsg),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint('Error deleting account: $e');
                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('An error occurred: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text(
                          'Delete Account',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    // Version info
                    const Center(
                      child: Text(
                        'Version 3.0',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}