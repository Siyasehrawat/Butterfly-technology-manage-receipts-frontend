import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/auth_manager.dart';
import 'dashboard_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthManager _authManager = AuthManager();
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    // Check login status after a short delay to show splash screen
    Future.delayed(const Duration(seconds: 2), () {
      _checkLoginStatus();
    });
  }

  Future<void> _checkLoginStatus() async {
    setState(() {
      _isCheckingAuth = true;
    });

    try {
      final isLoggedIn = await _authManager.isLoggedIn();

      if (isLoggedIn) {
        // Get stored user data
        final userId = await _authManager.getUserId();
        final email = await _authManager.getUserEmail();
        final name = await _authManager.getUserName();
        final token = await _authManager.getToken();
        final hasAdminAccess = await _authManager.hasAdminAccess(); // Get admin access status

        if (userId != null && token != null) {
          // Update the user provider with all stored data including admin access
          final userProvider = Provider.of<UserProvider>(context, listen: false);

          // Initialize from storage first to get all data
          await userProvider.initFromStorage();

          // Then explicitly set admin access to ensure it's properly set
          userProvider.setAdminAccess(hasAdminAccess);

          print('Splash: Admin access restored: $hasAdminAccess');

          // Navigate to dashboard
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  userId: userId,
                  token: token,
                ),
              ),
            );
          }
        } else {
          // Something is wrong with the stored data, go to welcome screen
          _navigateToWelcome();
        }
      } else {
        // Not logged in, go to welcome screen
        _navigateToWelcome();
      }
    } catch (e) {
      print('Splash screen error: $e');
      // Error occurred, go to welcome screen
      _navigateToWelcome();
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  void _navigateToWelcome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const WelcomeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7E5EFD),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Image.asset(
                  'assets/logo.png',
                  width: 80,
                  height: 80,
                  errorBuilder: (context, error, stackTrace) {
                    return const Text(
                      'MR',
                      style: TextStyle(
                        color: Color(0xFF7E5EFD),
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Manage Receipt',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            if (_isCheckingAuth)
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}