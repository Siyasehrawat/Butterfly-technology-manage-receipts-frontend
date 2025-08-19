import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/curved_background.dart';
import '../services/api_service_bypass.dart'; // Assuming ApiService is available
import 'wallet_screen.dart';
import 'wallet_forgot_pin_screen.dart';


class DocWalletPinEntryScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String? userEmail; // Added userEmail for pre-filling

  const DocWalletPinEntryScreen({
    super.key,
    required this.userId,
    required this.token,
    this.userEmail, // Made optional for now, but can be required if always available
  });

  @override
  State<DocWalletPinEntryScreen> createState() => _DocWalletPinEntryScreenState();
}

class _DocWalletPinEntryScreenState extends State<DocWalletPinEntryScreen> {
  late TextEditingController _emailController;
  final _pinController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // General loading for PIN verification and OTP verification
  bool _isSendingOtpLoading = false; // Specific loading for Send OTP button
  String? _errorMessage;
  bool _isOtpMode = false; // State to toggle between PIN and OTP input
  bool _otpSent = false; // State for "Send OTP" button text

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.userEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    if (_formKey.currentState!.validate()) {
      if (_isOtpMode) {
        if (_otpSent) {
          await _verifyOtpAndLogin();
        } else {
          setState(() {
            _errorMessage = 'Please send OTP first.';
          });
        }
      } else {
        await _verifyDocWalletPin();
      }
    }
  }

  Future<void> _verifyDocWalletPin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.post(
        '/doc-wallet/verify-pin',
        body: {
          'userId': widget.userId,
          'pin': _pinController.text,
        },
        token: widget.token,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Doc Wallet unlocked!'),
              backgroundColor: Color(0xFF7E5EFD),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MyWalletScreen(
                userId: widget.userId,
                token: widget.token,
              ),
            ),
          );
        }
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _errorMessage = errorData['message'] ?? 'Invalid PIN. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendOtpForLogin() async {
    setState(() {
      _isSendingOtpLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.post(
        "/doc-wallet/send-otp",
        body: {"userId": widget.userId},
        token: widget.token,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          //  Updated message to inform user about email delivery
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent to your registered email address'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4), // Show longer for better visibility
            ),
          );
          setState(() {
            _otpSent = true;
          });
          _otpController.clear();
          FocusScope.of(context).requestFocus(FocusNode());
        }
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _errorMessage = errorData['message'] ?? 'Failed to send OTP. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtpLoading = false;
        });
      }
    }
  }
  Future<void> _verifyOtpAndLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.post(
        "/doc-wallet/verify-otp",
        body: {
          "userId": widget.userId,
          "otp": _otpController.text,
        },
        token: widget.token,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logged in successfully with OTP!'),
              backgroundColor: Color(0xFF7E5EFD),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MyWalletScreen(
                userId: widget.userId,
                token: widget.token,
              ),
            ),
          );
        }
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _errorMessage = errorData['message'] ?? 'Invalid OTP. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onForgotPinPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyWalletForgotPinScreen(
          userId: widget.userId,
          token: widget.token,
          userEmail: widget.userEmail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CurvedBackground(
        child: Column(
          children: [
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              child: Column(
                children: [
                  Text(
                    'Doc Wallet',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your trusted solution for storing and managing documents. Keep all your important documents and files securely protected with a personal PIN, while staying organized and easily accessing them anytime, anywhere. With Doc Wallet, managing your documents is fast, simple, and safe.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 0),
                  Text(
                    ''
                    ''
                    '',
                    style: TextStyle(
                      fontSize: 0,
                      color: Colors.white,
                      height: 0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Align(
                alignment: const Alignment(0, -0.8),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
                            // Toggle Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _isOtpMode = true;
                                        _errorMessage = null;
                                        _otpSent = false; // Reset OTP sent status
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isOtpMode ? const Color(0xFF7E5EFD) : Colors.grey[200],
                                      foregroundColor: _isOtpMode ? Colors.white : Colors.black87,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    child: const Text(
                                      'UNLOCK WITH OTP',
                                      style: TextStyle(fontSize: 12), // Smaller text
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _isOtpMode = false;
                                        _errorMessage = null;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: !_isOtpMode ? const Color(0xFF7E5EFD) : Colors.grey[200],
                                      foregroundColor: !_isOtpMode ? Colors.white : Colors.black87,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    child: const Text(
                                      'UNLOCK WITH PIN',
                                      style: TextStyle(fontSize: 12), // Smaller text
                                    ),
                                  ),
                                ),
                              ],
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
                            // Conditional Input Fields based on mode
                            if (!_isOtpMode) // PIN mode
                              Column(
                                children: [
                                  TextFormField(
                                    controller: _pinController,
                                    keyboardType: TextInputType.number,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      hintText: 'Enter PIN',
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      suffixIcon: const Icon(Icons.lock_outline),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[200],
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your PIN';
                                      }
                                      if (value.length < 4 || value.length > 6) {
                                        return 'PIN must be 4-6 digits';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _onForgotPinPressed,
                                      child: const Text(
                                        'Forgot PIN?',
                                        style: TextStyle(
                                          color: Color(0xFF7E5EFD),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else // OTP mode
                              Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _otpController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            hintText: 'Enter OTP',
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                            suffixIcon: const Icon(Icons.lock_outline),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey[200],
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please enter the OTP';
                                            }
                                            if (value.length != 6) {
                                              return 'OTP must be 6 digits';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8), // Gap between OTP input and button
                                      SizedBox(
                                        width: 100, // Adjust width as needed for "Send OTP" button
                                        height: 50, // Match height of TextFormField
                                        child: ElevatedButton(
                                          onPressed: _isSendingOtpLoading || _otpSent ? null : _sendOtpForLogin,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _otpSent ? Colors.grey : const Color(0xFF7E5EFD),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: EdgeInsets.zero, // Remove default padding
                                          ),
                                          child: _isSendingOtpLoading
                                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                              : Text(
                                            _otpSent ? 'OTP Sent' : 'Send OTP',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12, // Smaller text for button
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_otpSent) // Show Resend OTP only after OTP is sent
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _isSendingOtpLoading ? null : _sendOtpForLogin,
                                        child: const Text(
                                          'Resend OTP',
                                          style: TextStyle(
                                            color: Color(0xFF7E5EFD),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading || (_isOtpMode && !_otpSent) ? null : _handleUnlock,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (_isOtpMode && !_otpSent) ? Colors.grey : const Color(0xFF7E5EFD), // Change color of Unlock button
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text(
                                  'UNLOCK',
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

  Widget _buildFeatureRow(String emoji, String title, String description) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}