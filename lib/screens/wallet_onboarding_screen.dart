import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_provider.dart';
import '../widgets/curved_background.dart';
import '../services/api_service_bypass.dart'; // Assuming ApiService is available
import 'wallet_screen.dart';
import 'dart:convert';

class MyWalletOnboardingScreen extends StatefulWidget {
  final String userId;
  final String token;

  const MyWalletOnboardingScreen({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<MyWalletOnboardingScreen> createState() => _MyWalletOnboardingScreenState();
}

class _MyWalletOnboardingScreenState extends State<MyWalletOnboardingScreen> {
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _agreedToTerms = false;
  String? _errorMessage;
  bool _showFullTerms = false; // New state to control full text visibility

  final String _fullTermsText =
      'User agrees to not upload any personal information or official documentation. Your data is secure on our app, and we are not liable for any data misuse.';
  final String _truncatedTermsPrefix = 'User agrees to not upload any personal information';

  @override
  void dispose() {
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _setDocWalletPin() async {
    if (_formKey.currentState!.validate()) {
      if (!_agreedToTerms) {
        setState(() {
          _errorMessage = 'You must agree to the terms and conditions.';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final response = await ApiService.post(
          '/doc-wallet/setup-pin',
          body: {
            'userId': widget.userId,
            'pin': _newPinController.text, // In a real app, send hashed PIN
          },
          token: widget.token,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Update UserProvider cache
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          await userProvider.updateDocWalletStatus(true);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('My Wallet PIN set successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            // Navigate to wallet screen upon successful PIN setup
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
            _errorMessage = errorData['message'] ?? 'Failed to set My Wallet PIN.';
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
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              child: Column(
                children: [
                  const Text(
                    'Doc Wallet Setup',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your trusted solution for storing and managing documents. Keep all your important documents and files securely protected with a personal PIN, while staying organized and easily accessing them anytime, anywhere. With Doc Wallet, managing your documents is fast, simple, and safe.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Align(
                alignment: const Alignment(0, -0.6),
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
                            const Text(
                              'Set Your Doc Wallet PIN',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'This PIN will be used to secure your documents.',
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
                              controller: _newPinController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: 'New PIN (4-6 digits)',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a PIN';
                                }
                                if (value.length < 4 || value.length > 6) {
                                  return 'PIN must be 4-6 digits';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPinController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: 'Confirm New PIN',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your PIN';
                                }
                                if (value != _newPinController.text) {
                                  return 'PINs do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _agreedToTerms,
                                    onChanged: (bool? newValue) {
                                      setState(() {
                                        _agreedToTerms = newValue ?? false;
                                        if (_agreedToTerms) {
                                          _errorMessage = null;
                                        }
                                      });
                                    },
                                    activeColor: const Color(0xFF7E5EFD),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 12, left: 8),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _showFullTerms = !_showFullTerms;
                                          });
                                        },
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Terms & Conditions',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: _showFullTerms
                                                        ? _fullTermsText
                                                        : '$_truncatedTermsPrefix...',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey.shade700,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                  if (!_showFullTerms)
                                                    const TextSpan(
                                                      text: ' Read More',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Color(0xFF7E5EFD),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  if (_showFullTerms)
                                                    const TextSpan(
                                                      text: ' Show Less',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Color(0xFF7E5EFD),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _setDocWalletPin,
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
                                  'SUBMIT',
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
