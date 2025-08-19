import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';
import 'complete_profile_screen.dart';
import 'dashboard_screen.dart';
import '../widgets/app_logo.dart';
import '../widgets/curved_background.dart';
import '../widgets/social_login_buttons.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/setting_provider.dart';
import '../providers/feature_flags_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/support_service.dart';
import 'package:http/http.dart' as http;
import '../services/api_service_bypass.dart';
import 'package:flutter/services.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final AuthService _authService = AuthService();
  void _navigateToSignIn() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignInScreen(),
      ),
    );
  }

  void _navigateToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignUpScreen(),
      ),
    );
  }

  // Show Report an Issue Dialog
  void _showReportIssueDialog() {
    String? selectedIssueType;
    final TextEditingController emailController = TextEditingController();
    final TextEditingController issueDescriptionController = TextEditingController();
    PlatformFile? attachedFile;
    String? emailError;
    String? issueTypeError;
    String? descriptionError;
    bool hasAttemptedSubmit = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Full country list and controller for searchable input
            const List<String> allCountries = [
              'Afghanistan','Albania','Algeria','Andorra','Angola','Antigua and Barbuda','Argentina','Armenia','Australia','Austria','Azerbaijan',
              'Bahamas','Bahrain','Bangladesh','Barbados','Belarus','Belgium','Belize','Benin','Bhutan','Bolivia','Bosnia and Herzegovina','Botswana','Brazil','Brunei','Bulgaria','Burkina Faso','Burundi',
              'Cabo Verde','Cambodia','Cameroon','Canada','Central African Republic','Chad','Chile','China','Colombia','Comoros','Congo (Congo-Brazzaville)','Costa Rica','Cote d\'Ivoire','Croatia','Cuba','Cyprus','Czechia',
              'Democratic Republic of the Congo','Denmark','Djibouti','Dominica','Dominican Republic',
              'Ecuador','Egypt','El Salvador','Equatorial Guinea','Eritrea','Estonia','Eswatini','Ethiopia',
              'Fiji','Finland','France',
              'Gabon','Gambia','Georgia','Germany','Ghana','Greece','Grenada','Guatemala','Guinea','Guinea-Bissau','Guyana',
              'Haiti','Honduras','Hungary',
              'Iceland','India','Indonesia','Iran','Iraq','Ireland','Israel','Italy',
              'Jamaica','Japan','Jordan',
              'Kazakhstan','Kenya','Kiribati','Kuwait','Kyrgyzstan',
              'Laos','Latvia','Lebanon','Lesotho','Liberia','Libya','Liechtenstein','Lithuania','Luxembourg',
              'Madagascar','Malawi','Malaysia','Maldives','Mali','Malta','Marshall Islands','Mauritania','Mauritius','Mexico','Micronesia','Moldova','Monaco','Mongolia','Montenegro','Morocco','Mozambique','Myanmar',
              'Namibia','Nauru','Nepal','Netherlands','New Zealand','Nicaragua','Niger','Nigeria','North Korea','North Macedonia','Norway',
              'Oman',
              'Pakistan','Palau','Panama','Papua New Guinea','Paraguay','Peru','Philippines','Poland','Portugal',
              'Qatar',
              'Romania','Russia','Rwanda',
              'Saint Kitts and Nevis','Saint Lucia','Saint Vincent and the Grenadines','Samoa','San Marino','Sao Tome and Principe','Saudi Arabia','Senegal','Serbia','Seychelles','Sierra Leone','Singapore','Slovakia','Slovenia','Solomon Islands','Somalia','South Africa','South Korea','South Sudan','Spain','Sri Lanka','Sudan','Suriname','Sweden','Switzerland','Syria',
              'Taiwan','Tajikistan','Tanzania','Thailand','Timor-Leste','Togo','Tonga','Trinidad and Tobago','Tunisia','Turkey','Turkmenistan','Tuvalu',
              'Uganda','Ukraine','United Arab Emirates','United Kingdom','United States','Uruguay','Uzbekistan',
              'Vanuatu','Vatican City','Venezuela','Vietnam',
              'Yemen',
              'Zambia','Zimbabwe'
            ];
            // Validation function
            bool isValid() {
              emailError = null;
              issueTypeError = null;
              descriptionError = null;
              
              if (emailController.text.trim().isEmpty) {
                emailError = 'Please enter your email address';
              } else if (!RegExp(r'^[\w-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text.trim())) {
                emailError = 'Please enter a valid email address';
              }
              
              if (selectedIssueType == null) {
                issueTypeError = 'Please select an issue type';
              }
              
              if (issueDescriptionController.text.trim().isEmpty) {
                descriptionError = 'Please provide a description';
              } else if (RegExp(r'(<[^>]*>|`{3,}|</?script|javascript:)', caseSensitive: false)
                  .hasMatch(issueDescriptionController.text)) {
                descriptionError = 'Please avoid adding code or scripts in the description';
              } else if (issueDescriptionController.text.trim().length > 2000) {
                descriptionError = 'Description cannot exceed 2000 characters';
              }
              
              return emailError == null && issueTypeError == null && descriptionError == null;
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
                      
                      // Your Email Address
                      const Text(
                        'Your Email Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (value) {
                          setState(() {
                            if (hasAttemptedSubmit) {
                              emailError = null; // Clear error when user types
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter your email address',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          errorText: hasAttemptedSubmit ? emailError : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
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
                            child: Text('Performance '),
                          ),
                          DropdownMenuItem(
                            value: 'User Interface',
                            child: Text('User Interface'),
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
                        'Describe the Feedback',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(You can include Feedback screenshot)',
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
                          hintText: 'Please describe the Feedback you\'re experiencing in detail...',
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
                            Text(
                              attachedFile == null ? 'Choose File' : attachedFile!.name,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
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
                                  email: emailController.text.trim(),
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

  // Upload screenshot to Cloudinary and submit issue via API (unauthenticated)
  Future<void> _submitIssue({
    required String email,
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
        // Upload to Cloudinary using feedback_ss preset
        final uri = Uri.parse('https://api.cloudinary.com/v1_1/ds1lqhvc3/image/upload');
        final request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = 'feedback_ss';
        
        // Handle both web (bytes) and mobile (path)
        if (kIsWeb && attachedFile.bytes != null) {
          // Web: use bytes
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            attachedFile.bytes!,
            filename: attachedFile.name,
          ));
        } else if (attachedFile.path != null) {
          // Mobile: use path
          request.files.add(await http.MultipartFile.fromPath(
            'file',
            attachedFile.path!,
            filename: attachedFile.name,
          ));
        } else {
          // Fallback to bytes if available
          if (attachedFile.bytes != null) {
            request.files.add(http.MultipartFile.fromBytes(
              'file',
              attachedFile.bytes!,
              filename: attachedFile.name,
            ));
          }
        }
        
        if (request.files.isNotEmpty) {
          final uploadResponse = await request.send();
          final body = await uploadResponse.stream.bytesToString();
          if (uploadResponse.statusCode == 200) {
            final data = jsonDecode(body);
            screenshotUrl = data['secure_url'] ?? data['url'];
          }
        }
      }

      final result = await ApiService.post(
        '/support/report-issue/unauthenticated',
        body: {
          'email': email,
          'issueType': issueType,
          'description': description,
          'screenshotUrl': screenshotUrl ?? '',
        },
      );

      // Close loading indicator
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        if (result.statusCode == 200 || result.statusCode == 201) {
          // Success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Thank you for reporting the Feedback! We will look into it soon.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // Error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit Feedback. Please try again.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error submitting Feedback: $e');
      
      // Close loading indicator if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit Feedback. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: CurvedBackground(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight,
            ),
            child: Column(
              children: <Widget>[
                // Logo section
                SizedBox(height: screenHeight * 0.08), // 8% from top
                const Center(child: AppLogo()),

                // White card section
                Container(
                          width: screenWidth * 0.85, // 85% of screen width
                          margin: EdgeInsets.only(top: screenHeight * 0.02), // 5% from logo
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
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Welcome To Manage Receipt',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Capture, Store, Organize.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),

                                OutlinedButton(
                                  onPressed: _navigateToSignIn,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF7E5EFD)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    minimumSize: const Size(double.infinity, 50),
                                  ),
                                  child: const Text(
                                    'SIGN IN',
                                    style: TextStyle(
                                      color: Color(0xFF7E5EFD),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _navigateToSignUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7E5EFD),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    minimumSize: const Size(double.infinity, 50),
                                  ),
                                  child: const Text(
                                    'SIGN UP',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Consumer<FeatureFlagsProvider>(
                                  builder: (context, ff, _) => SocialLoginButtons(
                                    requireTermsAcceptance: false,
                                    termsAccepted: true,
                                    showGoogle: ff.isGoogleAuthEnabled,
                                    showApple: ff.isAppleAuthEnabled,
                                    onGoogle: () async {
                              final res = await _authService.signInWithGoogle(termsAccepted: true);
                              if (!mounted) return res;
                              if (res['success'] == true) {
                                final userProvider = Provider.of<UserProvider>(context, listen: false);
                                final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                                
                                // Use backend canUpdatePassword only
                                final bool canUpdatePassword = (res['canUpdatePassword'] == true) ||
                                    (res['canupdatepassword'] == true);
                                
                                userProvider.login(
                                  res['userId'],
                                  res['name'] ?? '',
                                  res['email'] ?? '',
                                  res['token'] ?? '',
                                  hasAdminAccess: res['hasAdminAccess'] ?? false,
                                  country: res['country'],
                                  currency: res['currency'],
                                  currencySymbol: res['currencySymbol'],
                                  canUpdatePassword: canUpdatePassword,
                                );
                                
                                if (res['country'] != null) {
                                  await userProvider.setCountry(res['country']);
                                }
                                if (res['currencySymbol'] != null) {
                                  await settingsProvider.setCurrencySymbol(res['currencySymbol']);
                                }
                                
                                // Navigate based on needsProfile flag
                                final dynamic npGoogle = res['needsProfile'] ?? res['needsprofile'] ?? res['needs_profile'];
                                final bool needsProfile = (npGoogle == true) ||
                                    (npGoogle is String && (npGoogle.toLowerCase() == 'true' || npGoogle == '1')) ||
                                    (npGoogle is num && npGoogle == 1);
                                if (needsProfile) {
                                  // User needs to complete profile
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CompleteProfileScreen(
                                        navigateToAfterSave: (ctx) => DashboardScreen(
                                          userId: res['userId'],
                                          token: res['token'] ?? '',
                                        ),
                                      ),
                                    ),
                                    (route) => false,
                                  );
                                } else {
                                  // User profile is complete, go directly to dashboard
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DashboardScreen(
                                        userId: res['userId'],
                                        token: res['token'] ?? '',
                                      ),
                                    ),
                                    (route) => false,
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res['message'] ?? 'Google sign-in failed')),
                                );
                              }
                              return res;
                            },
                            onApple: () async {
                              final res = await _authService.signInWithApple(termsAccepted: true);
                              if (!mounted) return res;
                              if (res['success'] == true) {
                                final userProvider = Provider.of<UserProvider>(context, listen: false);
                                final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                                
                                // Use backend canUpdatePassword only
                                final bool canUpdatePassword = (res['canUpdatePassword'] == true) ||
                                    (res['canupdatepassword'] == true);
                                
                                userProvider.login(
                                  res['userId'],
                                  res['name'] ?? '',
                                  res['email'] ?? '',
                                  res['token'] ?? '',
                                  hasAdminAccess: res['hasAdminAccess'] ?? false,
                                  country: res['country'],
                                  currency: res['currency'],
                                  currencySymbol: res['currencySymbol'],
                                  canUpdatePassword: canUpdatePassword,
                                );
                                
                                if (res['country'] != null) {
                                  await userProvider.setCountry(res['country']);
                                }
                                if (res['currencySymbol'] != null) {
                                  await settingsProvider.setCurrencySymbol(res['currencySymbol']);
                                }
                                
                                // Navigate based on needsProfile flag
                                final dynamic npApple = res['needsProfile'] ?? res['needsprofile'] ?? res['needs_profile'];
                                final bool needsProfile = (npApple == true) ||
                                    (npApple is String && (npApple.toLowerCase() == 'true' || npApple == '1')) ||
                                    (npApple is num && npApple == 1);
                                if (needsProfile) {
                                  // User needs to complete profile
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CompleteProfileScreen(
                                        navigateToAfterSave: (ctx) => DashboardScreen(
                                          userId: res['userId'],
                                          token: res['token'] ?? '',
                                        ),
                                      ),
                                    ),
                                    (route) => false,
                                  );
                                } else {
                                  // User profile is complete, go directly to dashboard
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DashboardScreen(
                                        userId: res['userId'],
                                        token: res['token'] ?? '',
                                      ),
                                    ),
                                    (route) => false,
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res['message'] ?? 'Apple sign-in failed')),
                                );
                              }
                              return res;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Report an Issue link at the bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 24, top: 16),
                  child: TextButton(
                    onPressed: _showReportIssueDialog,
                    child: const Text(
                      'Share Feedback',
                      style: TextStyle(
                        color: Color(0xFF7E5EFD),
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF7E5EFD),
                      ),
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
}