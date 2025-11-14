import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:Manage_Receipt/providers/user_provider.dart';
import 'package:Manage_Receipt/providers/feature_flags_provider.dart';
import 'package:Manage_Receipt/screens/profile_screen.dart';
import 'package:Manage_Receipt/screens/wallet_screen.dart';
import 'package:Manage_Receipt/screens/wallet_pin_entry_screen.dart';
import 'package:Manage_Receipt/screens/wallet_onboarding_screen.dart';
import 'package:Manage_Receipt/screens/split_receipts_screen.dart';
import 'package:Manage_Receipt/screens/bill_reminders_screen.dart';
import 'package:Manage_Receipt/screens/settings_screen.dart';
import 'package:Manage_Receipt/screens/sign_in_screen.dart';
import 'package:Manage_Receipt/screens/analytics_screen.dart';
import 'package:Manage_Receipt/screens/category_wise_spend_screen.dart';
import 'package:Manage_Receipt/screens/tax_reports_screen.dart';
import 'package:Manage_Receipt/screens/admin_users_screen.dart';
import 'package:Manage_Receipt/screens/admin_analytics_screen.dart';
import 'package:Manage_Receipt/screens/admin_dashboard_screen.dart';
import 'package:Manage_Receipt/screens/mr_bucks_screen.dart';
import 'package:Manage_Receipt/screens/refer_earn_screen.dart';
import 'package:Manage_Receipt/widgets/upload_bottom_sheet.dart';
import 'package:Manage_Receipt/services/api_service_bypass.dart';

class MoreOptionsScreen extends StatefulWidget {
  final String userId;
  final String token;

  const MoreOptionsScreen({
    Key? key,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<MoreOptionsScreen> createState() => _MoreOptionsScreenState();
}

class _MoreOptionsScreenState extends State<MoreOptionsScreen> {

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final bool hasAdminAccess = userProvider.hasAdminAccess;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: const Color(0xFF7E5EFD),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'More Options',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Center(
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
              ),
            ],
          ),
          body: ListView(
            children: [
              // Doc Wallet (moved here from bottom tab)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF7E5EFD)),
                  title: const Text('Doc Wallet'),
                  subtitle: const Text('Store and access your important documents'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _checkWalletStatusAndNavigate(context),
                ),
              ),

              // Email Receipts
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.email, color: Color(0xFF7E5EFD)),
                  title: const Text('Email Receipts'),
                  subtitle: const Text('Forward receipts via email'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showEmailReceiptsDialog(context),
                ),
              ),
              
              // Split Receipts
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.call_split, color: Colors.orange),
                  title: const Text('Split Receipts'),
                  subtitle: const Text('Split receipts with others'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _navigateToSplitReceipts(context),
                ),
              ),

              // Refer & Earn
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.card_giftcard, color: Colors.purple),
                  title: const Text('Refer & Earn'),
                  subtitle: const Text('Invite friends and earn rewards'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _navigateToReferEarn(context),
                ),
              ),

              // Bill Reminders
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.notifications, color: Colors.green),
                  title: const Text('Bill Reminders'),
                  subtitle: const Text('Set up payment reminders'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _navigateToBillReminders(context),
                ),
              ),

              // Admin Panel (only show for admin users)
              if (hasAdminAccess)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF7E5EFD)),
                    title: const Text('Admin Panel'),
                    subtitle: const Text('Manage users, points, and redemptions'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminDashboardScreen(
                            adminId: widget.userId,
                            token: widget.token,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Settings
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.settings, color: Colors.grey),
                  title: const Text('Settings'),
                  subtitle: const Text('App preferences and settings'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(),
                    ),
                  ),
                ),
              ),

              // Help & Support
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.help, color: Colors.red),
                  title: const Text('Share Feedback'),
                  subtitle: const Text('Share your Feedback after using app'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showHelpSupportDialog(context),
                ),
              ),

              // Logout
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE6E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Sign out of your account', style: TextStyle(color: Colors.red)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showLogoutDialog(context),
                ),
              ),
            ],
          ),
          bottomNavigationBar: Consumer<FeatureFlagsProvider>(
            builder: (context, featureFlagsProvider, child) {
              return BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                selectedItemColor: const Color(0xFF7E5EFD),
                unselectedItemColor: Colors.grey.shade600,
                selectedFontSize: 12,
                unselectedFontSize: 12,
                currentIndex: 4, // More is selected
                onTap: (index) {
                  _onBottomNavTap(context, index);
                },
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined, size: 26),
                    activeIcon: Icon(Icons.home, size: 28),
                    label: 'Home',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.analytics_outlined, size: 26),
                    activeIcon: Icon(Icons.analytics, size: 28),
                    label: 'Reports',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.add_circle_outline, size: 26),
                    activeIcon: Icon(Icons.add_circle, size: 28),
                    label: 'Upload',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.savings_outlined, size: 26),
                    activeIcon: Icon(Icons.savings, size: 28),
                    label: 'MR Bucks',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.more_horiz, size: 26),
                    activeIcon: Icon(Icons.more_horiz, size: 28),
                    label: 'More',
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }


  void _checkWalletStatusAndNavigate(BuildContext context) {
    _navigateToDocWallet(context);
  }

  void _navigateToSplitReceipts(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SplitReceiptsScreen(
          userId: widget.userId,
          token: widget.token,
        ),
      ),
    );
  }

  void _navigateToReferEarn(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReferEarnScreen(
          userId: widget.userId,
          token: widget.token,
        ),
      ),
    );
  }

  void _navigateToBillReminders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillRemindersScreen(),
      ),
    );
  }

  void _showEmailReceiptsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _EmailReceiptsDialog();
      },
    );
  }

  void _showHelpSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            String? selectedIssueType;
            String? issueTypeError;
            String? descriptionError;
            bool hasAttemptedSubmit = false;
            final issueDescriptionController = TextEditingController();
            PlatformFile? attachedFile;

            bool isValid() {
              issueTypeError = null;
              descriptionError = null;
              
              if (selectedIssueType == null) {
                issueTypeError = 'Please select an issue type';
              }
              
              if (issueDescriptionController.text.trim().isEmpty) {
                descriptionError = 'Please describe the issue';
              } else if (issueDescriptionController.text.trim().length < 10) {
                descriptionError = 'Description must be at least 10 characters';
              } else if (issueDescriptionController.text.contains(RegExp(r'[<>`]'))) {
                descriptionError = 'Please avoid adding code or scripts in the description';
              } else if (issueDescriptionController.text.trim().length > 2000) {
                descriptionError = 'Description cannot exceed 2000 characters';
              }
              
              return issueTypeError == null && descriptionError == null;
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Share Feedback',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7E5EFD),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogContext),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Issue Type Dropdown
                      const Text(
                        'Issue Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedIssueType,
                        decoration: InputDecoration(
                          hintText: 'Select Feedback type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          errorText: hasAttemptedSubmit ? issueTypeError : null,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Bug/Error',
                            child: Text('Bug/Error'),
                          ),
                          DropdownMenuItem(
                            value: 'Feature Request',
                            child: Text('Feature Request'),
                          ),
                          DropdownMenuItem(
                            value: 'Performance',
                            child: Text('Performance Issue'),
                          ),
                          DropdownMenuItem(
                            value: 'User Interface',
                            child: Text('UI/UX Issue'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedIssueType = value;
                            if (hasAttemptedSubmit) {
                              issueTypeError = null; // Clear error when user selects
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // Issue Description
                      const Text(
                        'Describe the issue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(You can include issue screenshot)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: issueDescriptionController,
                        maxLines: 5,
                        maxLength: 2000,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'[<>`]')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            if (hasAttemptedSubmit) {
                              descriptionError = null; // Clear error when user types
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Please describe the issue you\'re experiencing in detail...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          errorText: hasAttemptedSubmit ? descriptionError : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Attach Screenshot
                      const Text(
                        'Attach Screenshot (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            allowMultiple: false,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            setState(() {
                              attachedFile = result.files.first;
                            });
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey.shade400, style: BorderStyle.solid, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                attachedFile == null ? 'Choose File' : attachedFile!.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey,
                                side: const BorderSide(color: Colors.grey),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isValid() ? () async {
                                await _submitIssue(
                                  issueType: selectedIssueType!,
                                  description: issueDescriptionController.text.trim(),
                                  attachedFile: attachedFile,
                                );
                                
                                Navigator.pop(dialogContext);
                              } : () {
                                // Trigger validation and show errors
                                setState(() {
                                  hasAttemptedSubmit = true;
                                  isValid(); // This will set the error messages
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7E5EFD),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Submit Issue via API (Authenticated)
  Future<void> _submitIssue({
    required String issueType,
    required String description,
    PlatformFile? attachedFile,
  }) async {
    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      String? screenshotUrl;
      if (attachedFile != null) {
        try {
          final uri = Uri.parse('https://api.cloudinary.com/v1_1/ds1lqhvc3/image/upload');
          final request = http.MultipartRequest('POST', uri)
            ..fields['upload_preset'] = 'feedback_ss';
          if (attachedFile.bytes != null) {
            request.files.add(http.MultipartFile.fromBytes('file', attachedFile.bytes!, filename: attachedFile.name));
          } else if (attachedFile.path != null) {
            request.files.add(await http.MultipartFile.fromPath('file', attachedFile.path!, filename: attachedFile.name));
          }
          final uploadResponse = await request.send();
          final body = await uploadResponse.stream.bytesToString();
          if (uploadResponse.statusCode == 200) {
            final data = json.decode(body);
            screenshotUrl = data['secure_url'] ?? data['url'];
          }
        } catch (e) {
          // ignore upload failure and continue without screenshotUrl
        }
      }

      final response = await ApiService.post(
        '/support/report-issue/authenticated',
        body: {
          'userId': widget.userId,
          'issueType': issueType,
          'description': description,
          if (screenshotUrl != null) 'screenshotUrl': screenshotUrl,
        },
        token: widget.token,
      );

      // Close loading indicator
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you for reporting the issue! We will look into it soon.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // Error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to submit issue. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error submitting issue: $e');
      
      // Close loading indicator if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit issue. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _logout(context);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      // Clear user data from provider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.logout();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => SignInScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  Future<void> _navigateToDocWallet(BuildContext context) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final walletInfo = await userProvider.getWalletNavigationInfo(widget.token);

      if (mounted) {
        if (walletInfo['needsOnboarding']) {
          // User needs to set up wallet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyWalletOnboardingScreen(
                userId: widget.userId,
                token: widget.token,
              ),
            ),
          );
        } else if (walletInfo['needsPinEntry']) {
          // User has wallet but needs PIN entry
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocWalletPinEntryScreen(
                userId: widget.userId,
                token: widget.token,
                userEmail: userProvider.email,
              ),
            ),
          );
        } else if (walletInfo['canAccessWallet']) {
          // User can access wallet directly
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyWalletScreen(
                userId: widget.userId,
                token: widget.token,
              ),
            ),
          );
        } else {
          // Default to onboarding
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyWalletOnboardingScreen(
                userId: widget.userId,
                token: widget.token,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing Doc Wallet: $e')),
        );
      }
    }
  }

  void _onBottomNavTap(BuildContext context, int index) {
    switch (index) {
      case 0: // Home
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
        );
        break;
      case 1: // Reports
        Navigator.pushNamed(context, '/reports');
        break;
      case 2: // Upload
        UploadSheet.show(context, onAction: (action) async {
          final userId = widget.userId;
          switch (action) {
            case UploadAction.camera:
              await _handleUploadFromHere(context, userId, source: ImageSource.camera);
              break;
            case UploadAction.gallery:
              await _handleUploadFromHere(context, userId, source: ImageSource.gallery);
              break;
            case UploadAction.manual:
              await _openManualReceipt(context, userId);
              break;
          }
        });
        break;
            case 3: // MR Bucks
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MrBucksScreen(),
                ),
              );
              break;
      case 4: // More
        // Already on more screen, do nothing
        break;
    }
  }

  Future<void> _handleUploadFromHere(BuildContext context, String userId, {required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        // Handle the upload logic here
        // This would typically involve calling your upload service
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload functionality would be implemented here')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _openManualReceipt(BuildContext context, String userId) async {
    // Navigate to manual receipt creation
    Navigator.pushNamed(context, '/manual-receipt');
  }

}

class _EmailReceiptsDialog extends StatefulWidget {
  @override
  _EmailReceiptsDialogState createState() => _EmailReceiptsDialogState();
}

class _EmailReceiptsDialogState extends State<_EmailReceiptsDialog> {
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF7E5EFD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.email,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Email Receipts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You can email or forward your receipts from your registered email ID to the following address, and it will automatically process your receipt in the app:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text(
              'upload@managereceipt.com',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Color(0xFF7E5EFD),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isCopied ? null : _copyEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCopied ? Colors.green : const Color(0xFF7E5EFD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                _isCopied ? 'Copied' : 'Copy Email',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _copyEmail() async {
    try {
      await Clipboard.setData(const ClipboardData(text: 'upload@managereceipt.com'));
      setState(() {
        _isCopied = true;
      });
      
      // Reset the button after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isCopied = false;
          });
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to copy email: $e')),
      );
    }
  }
}
