/*import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';
import '../screens/dashboard_screen.dart';

class SocialLoginButtons extends StatefulWidget {
  final bool requireTermsAcceptance;
  final bool termsAccepted;

  const SocialLoginButtons({
    super.key,
    required this.requireTermsAcceptance,
    required this.termsAccepted
  });

  @override
  State<SocialLoginButtons> createState() => _SocialLoginButtonsState();
}

class _SocialLoginButtonsState extends State<SocialLoginButtons> {
  final AuthService _authService = AuthService();
  bool _isGoogleLoading = false;
  bool _isFacebookLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    if (widget.requireTermsAcceptance && !widget.termsAccepted) {
      setState(() {
        _errorMessage = "You must accept the Terms and Conditions to continue.";
      });
      return;
    }

    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithGoogle(termsAccepted: widget.termsAccepted);

      if (result['success']) {
        // Update user provider
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.login(
            result['userId'],
            '', // We'll get this from the backend if needed
            '', // We'll get this from the backend if needed
            result['token'] ?? ''
        );

        if (mounted) {
          // Navigate to dashboard
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
        if (mounted) {
          setState(() {
            _errorMessage = result['message'];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'])),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> _handleFacebookSignIn(BuildContext context) async {
    if (widget.requireTermsAcceptance && !widget.termsAccepted) {
      setState(() {
        _errorMessage = "You must accept the Terms and Conditions to continue.";
      });
      return;
    }

    setState(() {
      _isFacebookLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithFacebook(termsAccepted: widget.termsAccepted);

      if (result['success']) {
        // Update user provider
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.login(
            result['userId'],
            '', // We'll get this from the backend if needed
            '', // We'll get this from the backend if needed
            result['token'] ?? ''
        );

        if (mounted) {
          // Navigate to dashboard
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
        if (mounted) {
          setState(() {
            _errorMessage = result['message'];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'])),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFacebookLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return an empty container to hide social login buttons
    return Container();


    return Column(
      children: [
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

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Or Connect Using',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Google Button
            InkWell(
              onTap: _isGoogleLoading ? null : () => _handleGoogleSignIn(context),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _isGoogleLoading
                        ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                      ),
                    )
                        : Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Image.asset(
                        'lib/assets/google.png',
                        width: 24,
                        height: 24,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.g_mobiledata,
                          color: Colors.red,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Google',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Facebook Button
            InkWell(
              onTap: _isFacebookLoading ? null : () => _handleFacebookSignIn(context),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _isFacebookLoading
                        ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                      ),
                    )
                        : const Icon(
                      Icons.facebook,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Facebook',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Apple Button - Keep the same UI (no functionality yet)
            InkWell(
              onTap: null, // No functionality for Apple yet
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Icon(
                      Icons.apple,
                      color: Colors.black,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Apple',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );*/

