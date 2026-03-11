import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/phone_formatter.dart';
import '../services/currency_service.dart';
import '../providers/user_provider.dart';
import '../providers/setting_provider.dart';
import '../providers/feature_flags_provider.dart';
import 'dashboard_screen.dart';
import '../widgets/curved_background.dart';

class PhoneCompleteProfileScreen extends StatefulWidget {
  final String phone;
  final String otp;

  const PhoneCompleteProfileScreen({
    super.key,
    required this.phone,
    required this.otp,
  });

  @override
  State<PhoneCompleteProfileScreen> createState() => _PhoneCompleteProfileScreenState();
}

class _PhoneCompleteProfileScreenState extends State<PhoneCompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final AuthService _authService = AuthService();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  Country? _selectedCountry;

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _completeSignup() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage = 'Please correct the highlighted fields and try again.';
      });
      return;
    }

    if (_selectedCountry == null) {
      setState(() {
        _errorMessage = 'Please select your country to continue.';
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match. Please make sure both password fields are identical.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Ensure phone is in E.164 format
      final normalizedPhone = PhoneFormatter.normalizePhone(widget.phone);
      
      final result = await _authService.completePhoneLogin(
        phone: normalizedPhone,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        country: _selectedCountry?.name ?? 'Not specified',
        termsAccepted: true,
        referralCode: _referralCodeController.text.trim().isNotEmpty
            ? _referralCodeController.text.trim()
            : null,
      );

      if (result['success']) {
        // Update user provider with data from backend response
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

        final countryName = result['country'] ?? _selectedCountry?.name;
        final currencyInfo = CurrencyService.getCurrencyForCountry(countryName ?? '');
        final finalCurrency = result['currency'] ?? currencyInfo['currency'];
        final finalCurrencySymbol = result['currencySymbol'] ?? currencyInfo['symbol'];

        final token = result['token'] ?? '';
        final userId = result['userId'];

        await userProvider.login(
          userId,
          _nameController.text.trim(),
          _emailController.text.trim(),
          token,
          country: countryName,
          currency: finalCurrency,
          currencySymbol: finalCurrencySymbol,
          canUpdatePassword: (result['canUpdatePassword'] == true) || (result['canupdatepassword'] == true),
          context: context,
        );

        await userProvider.setCountry(countryName ?? 'Not specified');

        if (finalCurrencySymbol != null) {
          await settingsProvider.setCurrencySymbol(finalCurrencySymbol);
        }

        // Initialize and fetch feature flags
        final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
        await featureFlagsProvider.initFromCache();
        
        final fetchAttempted = await featureFlagsProvider.safeFetchFeatureFlags(
          token: token,
          userId: userId ?? '',
        );
        
        if (!fetchAttempted) {
          print('Phone SignUp - Warning: Could not fetch feature flags due to missing credentials');
        }

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(
                userId: userId ?? '',
                token: token,
              ),
            ),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to complete signup. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          top: false,
          bottom: true,
          child: CurvedBackground(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight,
                ),
                child: Column(
                  children: [
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
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    
                    // Title
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Complete Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please provide your details to complete signup',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),

                    // Main content
                    Container(
                      width: screenWidth * 0.85,
                      margin: EdgeInsets.only(top: screenHeight * 0.03),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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

                              // Email field (optional)
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
                                  if (value != null && value.trim().isNotEmpty) {
                                    if (!RegExp(r'^[\w.]+@([\w-]+\.)+[\w-]{2,4}$')
                                        .hasMatch(value.trim())) {
                                      return 'Please enter a valid email address';
                                    }
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

                              // Country dropdown
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
                                    _errorMessage = null;
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

                              // Password field
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
                                      ),
                                      color: const Color(0xFF7E5EFD),
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

                              // Confirm Password field
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
                                    ),
                                    color: const Color(0xFF7E5EFD),
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
                              const Text(
                                'Password must be at least 8 characters with one capital letter, one special character and one digit',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Complete Sign Up button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _completeSignup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7E5EFD),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text(
                                          'Complete Sign Up',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Sign In link
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
                                      Navigator.pushNamedAndRemoveUntil(
                                        context,
                                        '/sign_in',
                                        (route) => false,
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
                            ],
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

