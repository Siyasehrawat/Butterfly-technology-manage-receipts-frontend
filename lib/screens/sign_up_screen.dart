import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'dashboard_screen.dart';
import '../widgets/app_logo.dart';
import '../widgets/social_login_buttons.dart';
import '../widgets/curved_background.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';
import '../widgets/terms_and_conditions_dialog.dart';

class SignUpScreen extends StatefulWidget {
  SignUpScreen({super.key});

  // Create a logger instance
  final Logger _logger = Logger();

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _termsAccepted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        );

        if (result['success']) {
          // Update user provider
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          userProvider.login(
              result['userId'],
              _nameController.text,
              _emailController.text.trim(),
              result['token'] ?? ''
          );

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  userId: result['userId'],
                  token: result['token'] ?? '',
                ),
              ),
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

    return Scaffold(
      // Removed the AppBar to match sign-in screen layout
      body: CurvedBackground(
        child: Column(
          children: [
            // Back button
            SafeArea(
              child: Padding(
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
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: screenHeight * 0.04),
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
                           /* SocialLoginButtons(
                              requireTermsAcceptance: true,
                              termsAccepted: _termsAccepted,
                            ),*/
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
    );
  }
}