import 'package:flutter/material.dart';
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
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignUpScreen extends StatefulWidget {
  SignUpScreen({super.key});

  final Logger _logger = Logger();

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _termsAccepted = false;
  String? _errorMessage;

  List<Country> _countries = [];
  bool _isCountriesLoading = true;
  Country? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _fetchCountries();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchCountries() async {
    setState(() {
      _isCountriesLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse('https://manage-receipt-backend-bnl1.onrender.com/api/countries/supported-countries'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> countryList = data['countries'] ?? [];
        final List<Country> countries = countryList
            .map((c) => Country.fromJson(c as Map<String, dynamic>))
            .toList();
        setState(() {
          _countries = countries;
          _isCountriesLoading = false;
        });
      } else {
        setState(() {
          _countries = [];
          _isCountriesLoading = false;
        });
        widget._logger.e('Failed to load countries: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _countries = [];
        _isCountriesLoading = false;
      });
      widget._logger.e('Error fetching countries: $e');
    }
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const TermsAndConditionsDialog();
      },
    );
  }

  Future<void> _signUp() async {
    if (!_termsAccepted) {
      setState(() {
        _errorMessage = 'Please accept the Terms and Conditions to continue.';
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
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final result = await _authService.signUp(
          name: _nameController.text,
          email: _emailController.text.trim(),
          password: _passwordController.text,
          country: _selectedCountry?.name ?? 'Not specified',
          termsAccepted: _termsAccepted,
        );

        if (result['success']) {
          // Update user provider with data from backend response
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

          // Get currency info from selected country if not provided by backend
          final countryName = result['country'] ?? _selectedCountry?.name;
          final currencyInfo = CurrencyService.getCurrencyForCountry(countryName ?? '');

          final finalCurrency = result['currency'] ?? currencyInfo['currency'];
          final finalCurrencySymbol = result['currencySymbol'] ?? currencyInfo['symbol'];

          print('SignUp - Country: $countryName');
          print('SignUp - Currency: $finalCurrency ($finalCurrencySymbol)');

          userProvider.login(
            result['userId'],
            _nameController.text,
            _emailController.text.trim(),
            result['token'] ?? '',
            country: countryName,
            currency: finalCurrency,
            currencySymbol: finalCurrencySymbol,
          );

          // Store the country and currency from backend response
          await userProvider.setCountry(countryName ?? 'Not specified');
          print('SignUp - Country set to: $countryName');

          // Set currency in settings provider from backend response
          if (finalCurrencySymbol != null) {
            await settingsProvider.setCurrencySymbol(finalCurrencySymbol);
          }

          if (mounted) {
            // Navigate directly to dashboard
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/dashboard',
                  (route) => false,
            );
          }
        } else {
          setState(() {
            _errorMessage = result['message'];
          });
        }
      } catch (e) {
        widget._logger.e('Sign-up error: $e');
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
        body: SafeArea(
          bottom: true,
          child: CurvedBackground(
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
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/welcome');
                      },
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                const Center(child: AppLogo()),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Container(
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
                                  'SIGN UP',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Join now and simplify your manage receipt.',
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
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    hintText: 'Name',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
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
                                      return 'Invalid email format. Please enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Country dropdown field
                                _isCountriesLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : DropdownButtonFormField<Country>(
                                  value: _selectedCountry,
                                  decoration: const InputDecoration(
                                    hintText: 'Country',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  items: _countries.map((Country country) {
                                    // Get currency info for display
                                    final currencyInfo = CurrencyService.getCurrencyForCountry(country.name);
                                    final displaySymbol = country.currencySymbol.isNotEmpty
                                        ? country.currencySymbol
                                        : currencyInfo['symbol'];
                                    final displayCurrency = country.currency.isNotEmpty
                                        ? country.currency
                                        : currencyInfo['currency'];

                                    return DropdownMenuItem<Country>(
                                      value: country,
                                      child: Text('${country.name} ($displaySymbol $displayCurrency)'),
                                    );
                                  }).toList(),
                                  onChanged: (Country? newValue) {
                                    setState(() {
                                      _selectedCountry = newValue;
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
                                      return 'Please enter your password';
                                    }
                                    if (value.length < 8) {
                                      return 'Password must be at least 8 characters long';
                                    }
                                    if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                      return 'Password must contain at least one capital letter';
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
                                const Text(
                                  'Password must be at least 8 characters with one capital letter and one special character',
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
                                    'Join Now',
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
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
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

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      name: json['name'],
      code: json['code'],
      currency: json['currency'],
      currencySymbol: json['currencySymbol'],
    );
  }
}
