import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'sign_in_screen.dart';
import '../widgets/curved_background.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;

  ResetPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
  }) {
    Logger()
        .i('Navigated to ResetPasswordScreen with email: $email, otp: $otp');
  }

  final Logger _logger = Logger();

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final payload = {
          "email": widget.email,
          "otp": widget.otp,
          "newPassword": _newPasswordController.text,
        };

        widget._logger.i('Payload: ${jsonEncode(payload)}');

        final response = await http.post(
          Uri.parse(
              "https://manage-receipt-backend-bnl1.onrender.com/api/users/reset-password"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          final successData = jsonDecode(response.body);
          widget._logger
              .i('✅ Password reset successfully: ${successData['message']}');
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => SignInScreen()),
                  (route) => false,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password reset successfully! Please sign in.'),
                backgroundColor: Color(0xFF7E5EFD),
              ),
            );
          }
        } else {
          final errorData = jsonDecode(response.body);
          setState(() {
            _errorMessage = errorData['message'] ?? 'Failed to reset password.';
          });
        }
      } catch (e) {
        widget._logger.e('❌ Reset password error: $e');
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
    return Scaffold(
      body: CurvedBackground(
        child: Column(
          children: [
            // Back button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/logo.png',
                          width: 30,
                          height: 30,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text(
                              'MR',
                              style: TextStyle(
                                color: Color(0xFF7E5EFD),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Title
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // Main content
            Expanded(
              child: Align(
                alignment: const Alignment(0, -0.6),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const Text(
                              'Create New Password',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your new password must be different from previous passwords.',
                              style: TextStyle(
                                fontSize: 14,
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
                              controller: _newPasswordController,
                              obscureText: _obscureNewPassword,
                              decoration: InputDecoration(
                                hintText: 'New Password',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureNewPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFF7E5EFD),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureNewPassword = !_obscureNewPassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a new password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
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
                                      _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _newPasswordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _resetPassword,
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
                                  'RESET PASSWORD',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }
}