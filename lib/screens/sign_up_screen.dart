import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'sign_in_screen.dart';
import '../widgets/app_logo.dart';
import '../widgets/curved_background.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../providers/user_provider.dart';
import '../providers/setting_provider.dart';
import '../widgets/terms_and_conditions_dialog.dart';
import '../widgets/social_login_buttons.dart';
import 'complete_profile_screen.dart';
import 'dashboard_screen.dart';
import 'phone_complete_profile_screen.dart';
import '../providers/feature_flags_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/support_service.dart';
import 'package:http/http.dart' as http;
import '../services/api_service_bypass.dart';
import '../utils/phone_formatter.dart';
import 'dart:async';

class SignUpScreen extends StatefulWidget {
  SignUpScreen({super.key});

  final Logger _logger = Logger();

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _termsAccepted = false;
  String? _errorMessage;
  int _selectedSignupType = 0; // 0 = Email, 1 = Phone
  bool _otpSent = false;
  bool _isSendingOtp = false;
  Timer? _rateLimitTimer;
  int? _rateLimitSeconds;

  // Hardcoded supported countries
  final List<Country> _countries = [
    Country(
      name: 'United States',
      code: 'US',
      currency: 'USD',
      currencySymbol: '\$',
    ),
    Country(
      name: 'India',
      code: 'IN',
      currency: 'INR',
      currencySymbol: '₹',
    ),
  ];

  Country? _selectedCountry;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _scrollController.dispose();
    _rateLimitTimer?.cancel();
    super.dispose();
  }
  
  void _startRateLimitCountdown(int seconds) {
    _rateLimitTimer?.cancel();
    setState(() {
      _rateLimitSeconds = seconds;
    });
    
    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_rateLimitSeconds != null && _rateLimitSeconds! > 0) {
        setState(() {
          _rateLimitSeconds = _rateLimitSeconds! - 1;
        });
      } else {
        timer.cancel();
        setState(() {
          _rateLimitSeconds = null;
        });
      }
    });
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const TermsAndConditionsDialog();
      },
    );
  }

  String _getDetailedErrorMessage(dynamic error) {
    // Handle different types of errors with specific messages
    if (error is Map<String, dynamic>) {
      // Handle structured error responses from backend
      if (error.containsKey('message')) {
        final message = error['message'].toString().toLowerCase();

        if (message.contains('email') && message.contains('already')) {
          return 'This email address is already registered. Please use a different email or try signing in.';
        }
        if (message.contains('password') && message.contains('weak')) {
          return 'Password is too weak. Please use at least 8 characters with one uppercase letter and one special character.';
        }
        if (message.contains('invalid') && message.contains('email')) {
          return 'Please enter a valid email address format (e.g., user@example.com).';
        }
        if (message.contains('name') && message.contains('required')) {
          return 'Name is required and cannot be empty.';
        }
        if (message.contains('country') && message.contains('required')) {
          return 'Please select your country from the dropdown list.';
        }
        if (message.contains('network') || message.contains('connection')) {
          return 'Network connection error. Please check your internet connection and try again.';
        }
        if (message.contains('server') || message.contains('internal')) {
          return 'Server error occurred. Please try again in a few moments.';
        }
        if (message.contains('timeout')) {
          return 'Request timed out. Please check your connection and try again.';
        }

        return error['message'].toString();
      }

      // Handle validation errors
      if (error.containsKey('errors')) {
        final errors = error['errors'];
        if (errors is List && errors.isNotEmpty) {
          return errors.first.toString();
        }
      }
    }

    // Handle string error messages
    if (error is String) {
      final errorLower = error.toLowerCase();

      if (errorLower.contains('email') && errorLower.contains('already')) {
        return 'This email address is already registered. Please use a different email or try signing in.';
      }
      if (errorLower.contains('password') && errorLower.contains('weak')) {
        return 'Password is too weak. Please use at least 8 characters with one uppercase letter and one special character.';
      }
      if (errorLower.contains('invalid') && errorLower.contains('email')) {
        return 'Please enter a valid email address format (e.g., user@example.com).';
      }
      if (errorLower.contains('network') || errorLower.contains('connection')) {
        return 'Network connection error. Please check your internet connection and try again.';
      }
      if (errorLower.contains('timeout')) {
        return 'Request timed out. Please check your connection and try again.';
      }
      if (errorLower.contains('server') || errorLower.contains('internal')) {
        return 'Server error occurred. Please try again in a few moments.';
      }

      return error;
    }

    // Default error message for unknown errors
    return 'Registration failed. Please check your information and try again.';
  }

  Future<void> _sendPhoneOTP() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number';
      });
      _scrollToTop();
      return;
    }

    // Normalize phone number to E.164 format
    final phone = PhoneFormatter.normalizePhone(_phoneController.text.trim());
    
    if (!AuthService.isValidE164Phone(phone)) {
      setState(() {
        _errorMessage = 'Invalid phone number format. Must be in E.164 format (e.g., +1234567890)';
      });
      _scrollToTop();
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
      _rateLimitSeconds = null;
    });

    try {
      final result = await _authService.sendPhoneOTP(phone: phone);
      
      if (result['success']) {
        setState(() {
          _otpSent = true;
          _errorMessage = null;
        });
        // In development, show OTP if available
        if (result['otp'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('OTP sent! (Dev: ${result['otp']})'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent successfully to your phone number'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Handle rate limiting
        if (result['retryAfter'] != null) {
          final retryAfter = result['retryAfter'] as int;
          _startRateLimitCountdown(retryAfter);
          
          String errorMsg = result['message'] ?? 'Please wait before requesting another OTP';
          if (retryAfter >= 3600) {
            // More than 1 hour - show hours
            final hours = (retryAfter / 3600).ceil();
            errorMsg = 'Daily limit reached. Please try again after $hours hour(s).';
          }
          
          setState(() {
            _errorMessage = errorMsg;
          });
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'Failed to send OTP. Please try again.';
          });
        }
        _scrollToTop();
      }
    } catch (e) {
      widget._logger.e('Error sending phone OTP: $e');
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
      _scrollToTop();
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }

  Future<void> _signUp() async {
    // Clear previous error
    setState(() {
      _errorMessage = null;
    });

    // Email signup flow (existing validations)
    if (!_termsAccepted) {
      setState(() {
        _errorMessage = 'Please accept the Terms and Conditions to continue.';
      });
      _scrollToTop();
      return;
    }

    if (_selectedCountry == null) {
      setState(() {
        _errorMessage = 'Please select your country to continue.';
      });
      _scrollToTop();
      return;
    }

    // Email signup flow (existing)
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match. Please make sure both password fields are identical.';
      });
      _scrollToTop();
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final result = await _authService.signUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          country: _selectedCountry?.name ?? 'Not specified',
          termsAccepted: _termsAccepted,
          referralCode: _referralCodeController.text.trim().isNotEmpty
              ? _referralCodeController.text.trim()
              : null,
        );

        if (result['success']) {
          await _handleSignupSuccess(result);
        } else {
          setState(() {
            _errorMessage = _getDetailedErrorMessage(result['message'] ?? result);
          });
          _scrollToTop();
        }
      } catch (e) {
        widget._logger.e('Sign-up error: $e');
        setState(() {
          _errorMessage = _getDetailedErrorMessage(e.toString());
        });
        _scrollToTop();
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      setState(() {
        _errorMessage = 'Please correct the highlighted fields and try again.';
      });
      _scrollToTop();
    }
  }

  Future<void> _handleSignupSuccess(Map<String, dynamic> result) async {
    // Update user provider with data from backend response
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

          // Debug the signup result
          print('SignUp - Full result from backend: $result');
          print('SignUp - Token from result: ${result['token'] ?? 'MISSING'}');
          print('SignUp - UserId from result: ${result['userId'] ?? 'MISSING'}');

          // Get currency info from selected country if not provided by backend
          final countryName = result['country'] ?? _selectedCountry?.name;
          final currencyInfo = CurrencyService.getCurrencyForCountry(countryName ?? '');

          final finalCurrency = result['currency'] ?? currencyInfo['currency'];
          final finalCurrencySymbol = result['currencySymbol'] ?? currencyInfo['symbol'];

          print('SignUp - Country: $countryName');
          print('SignUp - Currency: $finalCurrency ($finalCurrencySymbol)');

          final token = result['token'] ?? '';
          final userId = result['userId'];
          
          print('SignUp - About to call userProvider.login with token: ${token.isNotEmpty ? 'present (${token.length} chars)' : 'MISSING'}, userId: ${userId?.isNotEmpty == true ? 'present' : 'MISSING'}');

          await userProvider.login(
            userId,
            _nameController.text.trim(),
            _emailController.text.trim(),
            token,
            country: countryName,
            currency: finalCurrency,
            currencySymbol: finalCurrencySymbol,
            // Respect backend flag from signup response
            canUpdatePassword: (result['canUpdatePassword'] == true) || (result['canupdatepassword'] == true),
            context: context,
          );

          // Store the country and currency from backend response
          await userProvider.setCountry(countryName ?? 'Not specified');
          print('SignUp - Country set to: $countryName');

          // Set currency in settings provider from backend response
          if (finalCurrencySymbol != null) {
            await settingsProvider.setCurrencySymbol(finalCurrencySymbol);
          }

          // Initialize and fetch feature flags with proper validation
          final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
          await featureFlagsProvider.initFromCache();
          
          // Use the already defined token and userId variables
          final fetchAttempted = await featureFlagsProvider.safeFetchFeatureFlags(
            token: token,
            userId: userId ?? '',
          );
          
          if (!fetchAttempted) {
            print('SignUp - Warning: Could not fetch feature flags due to missing credentials');
          }

          // Verify UserProvider is properly set before navigating
          print('SignUp - Final verification before navigation:');
          print('SignUp - UserProvider token: ${userProvider.token?.isNotEmpty == true ? 'present (${userProvider.token!.length} chars)' : 'MISSING'}');
          print('SignUp - UserProvider userId: ${userProvider.userId?.isNotEmpty == true ? 'present' : 'MISSING'}');

          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/dashboard',
              (route) => false,
            );
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
                            child: Text('Performance'),
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
                    children: <Widget>[
                    // Back button
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
                              margin: EdgeInsets.only(top: screenHeight * 0.05),
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
                                        'Create your account',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Join now and simplify receipt management.',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),

                                      // Enhanced error message display
                                      if (_errorMessage != null)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          margin: const EdgeInsets.only(bottom: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.red.shade200),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                color: Colors.red.shade600,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _errorMessage!,
                                                  style: TextStyle(
                                                    color: Colors.red.shade800,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // Name field
                                      TextFormField(
                                        controller: _nameController,
                                        decoration: const InputDecoration(
                                          hintText: 'Full Name',
                                          prefixIcon: Icon(Icons.person_outline, color: Color(0xFF7E5EFD)),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Please enter your name';
                                          }
                                          if (value.trim().length < 2) {
                                            return 'Name must be at least 2 characters long';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      // Email field
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        decoration: const InputDecoration(
                                          hintText: 'Email Address',
                                          prefixIcon: Icon(Icons.alternate_email, color: Color(0xFF7E5EFD)),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Please enter your email address';
                                          }
                                          if (!RegExp(r'^[\w.]+@([\w-]+\.)+[\w-]{2,4}$')
                                              .hasMatch(value.trim())) {
                                            return 'Please enter a valid email address (e.g., user@example.com)';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      // Referral Code field (optional)
                                      TextFormField(
                                        controller: _referralCodeController,
                                        textCapitalization: TextCapitalization.characters,
                                        maxLength: 32,
                                        decoration: const InputDecoration(
                                          hintText: 'Referral Code (Optional)',
                                          prefixIcon: Icon(Icons.card_giftcard_outlined, color: Color(0xFF7E5EFD)),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                          counterText: '', // Hide character counter
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), // Allow alphanumeric
                                          TextInputFormatter.withFunction((oldValue, newValue) {
                                            return TextEditingValue(
                                              text: newValue.text.toUpperCase(),
                                              selection: newValue.selection,
                                            );
                                          }),
                                        ],
                                        // No validator - this field is optional
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Country dropdown field - hardcoded countries
                                      DropdownButtonFormField<Country>(
                                        value: _selectedCountry,
                                        decoration: const InputDecoration(
                                          hintText: 'Country',
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                        ),
                                        items: _countries.map((Country country) {
                                          return DropdownMenuItem<Country>(
                                            value: country,
                                            child: Text('${country.name} (${country.currencySymbol} ${country.currency})'),
                                          );
                                        }).toList(),
                                        onChanged: (Country? newValue) {
                                          setState(() {
                                            _selectedCountry = newValue;
                                            _errorMessage = null; // Clear error when country is selected
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null) {
                                            return 'Please select your country';
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
                                            return 'Please enter a password';
                                          }
                                          if (value.length < 8) {
                                            return 'Password must be at least 8 characters long';
                                          }
                                          if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                            return 'Password must contain at least one uppercase letter';
                                          }
                                          if (!RegExp(r'[0-9]').hasMatch(value)) {
                                            return 'Password must contain at least one digit';
                                          }
                                          if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                                            return 'Password must contain at least one special character';
                                          }
                                          return null;
                                        },
                                      ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: _confirmPasswordController,
                                        obscureText: _obscureConfirmPassword,
                                        decoration: InputDecoration(
                                          hintText: 'Confirm Password',
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscureConfirmPassword
                                                  ? Icons.visibility_outlined
                                                  : Icons.visibility_off_outlined,
                                              color: const Color(0xFF7E5EFD),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscureConfirmPassword = !_obscureConfirmPassword;
                                              });
                                            },
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please confirm your password';
                                          }
                                          if (value != _passwordController.text) {
                                            return 'Passwords do not match';
                                          }
                                          return null;
                                        },
                                      ),
                                        const SizedBox(height: 8),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Password must be at least 8 characters with one capital letter and one special character and one digit',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // Terms and Conditions Checkbox
                                      Row(
                                        children: [
                                          Checkbox(
                                            value: _termsAccepted,
                                            onChanged: (value) {
                                              setState(() {
                                                _termsAccepted = value ?? false;
                                                if (_termsAccepted) {
                                                  _errorMessage = null;
                                                }
                                              });
                                            },
                                            activeColor: const Color(0xFF7E5EFD),
                                          ),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: _showTermsAndConditions,
                                              child: RichText(
                                                text: const TextSpan(
                                                  text: 'I agree to the ',
                                                  style: TextStyle(color: Colors.black87),
                                                  children: [
                                                    TextSpan(
                                                      text: 'Terms and Conditions',
                                                      style: TextStyle(
                                                        color: Color(0xFF7E5EFD),
                                                        fontWeight: FontWeight.bold,
                                                        decoration: TextDecoration.underline,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),

                                      ElevatedButton(
                                        onPressed: _isLoading ? null : _signUp,
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(double.infinity, 50),
                                        ),
                                        child: _isLoading
                                            ? const CircularProgressIndicator(color: Colors.white)
                                            : const Text(
                                          'Create Account',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // Add "Already have an account? Sign In" text
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            "Already have an account? ",
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => SignInScreen(),
                                                ),
                                              );
                                            },
                                            child: const Text(
                                              "Sign In",
                                              style: TextStyle(
                                                color: Color(0xFF7E5EFD),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Consumer<FeatureFlagsProvider>(
                                        builder: (context, ff, _) => SocialLoginButtons(
                                          requireTermsAcceptance: false,
                                          termsAccepted: true,
                                          showGoogle: ff.isGoogleAuthEnabled,
                                          showApple: ff.isAppleAuthEnabled,
                                          onGoogle: () async {
                                            // Will be handled in AuthService; keep UI responsive
                                            final res = await _authService.signInWithGoogle(
                                              termsAccepted: true,
                                              name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
                                              country: _selectedCountry?.code,
                                            );
                                            if (!mounted) return res;
                                            if (res['success'] == true) {
                                              final userProvider = Provider.of<UserProvider>(context, listen: false);
                                              final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                                              
                                              // Extract canUpdatePassword exactly as provided by backend
                                              final canUpdatePassword = (res['canUpdatePassword'] == true) || (res['canupdatepassword'] == true);
                                              
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
                                                context: context,
                                              );
                                              
                                              if (res['country'] != null) {
                                                await userProvider.setCountry(res['country']);
                                              }
                                              if (res['currencySymbol'] != null) {
                                                await settingsProvider.setCurrencySymbol(res['currencySymbol']);
                                              }
                                              
                                              // Fetch feature flags before navigating with proper validation
                                              final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
                                              await featureFlagsProvider.initFromCache();
                                              
                                              final token = res['token'] ?? '';
                                              final userId = res['userId'] ?? '';
                                              
                                              final fetchAttempted = await featureFlagsProvider.safeFetchFeatureFlags(
                                                token: token,
                                                userId: userId,
                                              );
                                              
                                              if (!fetchAttempted) {
                                                print('Social SignUp - Warning: Could not fetch feature flags due to missing credentials');
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
                                                _errorMessage = _getDetailedErrorMessage(res['message'] ?? 'Google sign-in failed');
                                              });
                                            }
                                            return res;
                                          },
                                          onApple: () async {
                                            // For Apple Sign In, don't pass additional name/country as Apple provides this info
                                            final res = await _authService.signInWithApple(
                                              termsAccepted: true,
                                            );
                                            if (!mounted) return res;
                                            if (res['success'] == true) {
                                              final userProvider = Provider.of<UserProvider>(context, listen: false);
                                              final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                                              
                                              // Extract canUpdatePassword exactly as provided by backend
                                              final canUpdatePassword = (res['canUpdatePassword'] == true) || (res['canupdatepassword'] == true);
                                              
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
                                                context: context,
                                              );
                                              
                                              if (res['country'] != null) {
                                                await userProvider.setCountry(res['country']);
                                              }
                                              if (res['currencySymbol'] != null) {
                                                await settingsProvider.setCurrencySymbol(res['currencySymbol']);
                                              }
                                              
                                              // Fetch feature flags before navigating with proper validation
                                              final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
                                              await featureFlagsProvider.initFromCache();
                                              
                                              final token = res['token'] ?? '';
                                              final userId = res['userId'] ?? '';
                                              
                                              final fetchAttempted = await featureFlagsProvider.safeFetchFeatureFlags(
                                                token: token,
                                                userId: userId,
                                              );
                                              
                                              if (!fetchAttempted) {
                                                print('Social SignUp - Warning: Could not fetch feature flags due to missing credentials');
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
                                                _errorMessage = _getDetailedErrorMessage(res['message'] ?? 'Apple sign-in failed');
                                              });
                                            }
                                            return res;
                                          },
                                        ),
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

class Country {
  final String name;
  final String code;
  final String currency;
  final String currencySymbol;

  Country({
    required this.name,
    required this.code,
    required this.currency,
    required this.currencySymbol,
  });
}