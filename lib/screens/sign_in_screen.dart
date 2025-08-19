import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';
import '../widgets/app_logo.dart';
import '../widgets/curved_background.dart';
import '../widgets/social_login_buttons.dart';
import 'package:logger/logger.dart';
import 'dashboard_screen.dart';
import 'complete_profile_screen.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';
import '../providers/setting_provider.dart';
import '../providers/feature_flags_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/support_service.dart';
import 'package:http/http.dart' as http;
import '../services/api_service_bypass.dart';

class SignInScreen extends StatefulWidget {
  SignInScreen({super.key});

  final Logger _logger = Logger();

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final result = await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          termsAccepted: true,
        );

        if (result['success']) {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

          // Check if user has admin access
          final bool hasAdminAccess = result['hasAdminAccess'] ?? false;

          print('SignIn - Admin access from backend: $hasAdminAccess');
          print('SignIn - Country from backend: ${result['country']}');
          print('SignIn - Currency from backend: ${result['currency']} (${result['currencySymbol']})');

          userProvider.login(
            result['userId'],
            result['name'] ?? '',
            _emailController.text.trim(),
            result['token'] ?? '',
            hasAdminAccess: hasAdminAccess,
            country: result['country'],
            currency: result['currency'],
            currencySymbol: result['currencySymbol'],
            canUpdatePassword: (result['canUpdatePassword'] == true) || (result['canupdatepassword'] == true),
          );

          // Set country and currency from backend response
          if (result['country'] != null) {
            await userProvider.setCountry(result['country']);
            print('SignIn - Country set to: ${result['country']}');
          }

          if (result['currencySymbol'] != null) {
            await settingsProvider.setCurrencySymbol(result['currencySymbol']);
            print('SignIn - Currency symbol set to: ${result['currencySymbol']}');
          }

          print('SignIn - User provider admin access after login: ${userProvider.hasAdminAccess}');
          print('SignIn - User provider country after login: ${userProvider.country}');
          print('SignIn - User provider currency after login: ${userProvider.currency} (${userProvider.currencySymbol})');

          if (mounted) {
            // Email/password login always goes to dashboard
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  userId: result['userId'],
                  token: result['token'] ?? '',
                ),
              ),
              (route) => false,
            );
          }
        } else {
          setState(() {
            _errorMessage = result['message'];
          });
          _scrollToTop();
        }
      } catch (e) {
        widget._logger.e('Error during login: $e');
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
        });
        _scrollToTop();
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.minScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // Show Report an Issue Dialog
  void _showReportIssueDialog() {
    String? selectedIssueType;
    final TextEditingController emailController = TextEditingController(text: _emailController.text);
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
                        'Describe the Feedback ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(You can include Feedback  screenshot)',
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

  // Submit Issue via API
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
      widget._logger.e('Error submitting Feedback: $e');
      
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

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, '/welcome');
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: SafeArea(
            top: false,
            bottom: true,
            child: CurvedBackground(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: screenHeight,
                  ),
                  child: Column(
                    children: [
                      // Back button added at the top
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/welcome');
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      const Center(child: AppLogo()),
                      Container(
                        width: screenWidth * 0.85,
                        margin: EdgeInsets.only(top: screenHeight * 0.02),
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
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Welcome Back!',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Sign in to manage your receipts.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                if (_errorMessage != null)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(color: Colors.red.shade800),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    hintText: 'Email',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!RegExp(r'^[\w-]+@([\w-]+\.)+[\w-]{2,4}$')
                                        .hasMatch(value)) {
                                      return 'Invalid email format';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    hintText: 'Password',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: const Color(0xFF7E5EFD),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _signIn,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                      : const Text(
                                    'SIGN IN',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: Color(0xFF7E5EFD),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
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
                                        setState(() {
                                          _errorMessage = res['message'] ?? 'Google sign-in failed';
                                        });
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
                                        setState(() {
                                          _errorMessage = res['message'] ?? 'Apple sign-in failed';
                                        });
                                      }
                                      return res;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Add "Don't have an account? Sign Up" text
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      "Don't have an account? ",
                                      style: TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SignUpScreen(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        "Sign Up",
                                        style: TextStyle(
                                          color: Color(0xFF7E5EFD),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
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
          ),
        ),
      ),
    );
  }
}