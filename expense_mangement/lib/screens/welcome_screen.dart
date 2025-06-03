import 'package:flutter/material.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';
import '../widgets/app_logo.dart';
import '../widgets/curved_background.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
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


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: CurvedBackground(
        child: Column(
          children: [
            // Logo section
            SizedBox(height: screenHeight * 0.08), // 8% from top
            const Center(child: AppLogo()),

            // White card section
            Expanded(
              child: Align(
                alignment: const Alignment(0, -0.6),
                child: SingleChildScrollView(
                  child: Container(
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
                          /*const SocialLoginButtons(
                            requireTermsAcceptance: false,
                            termsAccepted: true,
                          ),*/
                        ],
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