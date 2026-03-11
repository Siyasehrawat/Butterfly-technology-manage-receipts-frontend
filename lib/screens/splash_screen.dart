import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_provider.dart';
import '../providers/subscription_provider_bypass.dart';
import '../providers/feature_flags_provider.dart';
import '../services/version_service.dart';
import '../services/share_intent_service.dart';
import '../services/share_intent_handler.dart';
import '../services/receipts_service.dart';
import '../services/api_service_bypass.dart';
import 'welcome_screen.dart';
import 'dashboard_screen.dart';
import 'receipt_details_screen.dart';
import '../models/receipt_models.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // Set status bar style for splash screen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF7E5EFD),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('=== App Initialization Started ===');

      // Initialize UserProvider from storage
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.initFromStorage();

      debugPrint('UserProvider initialized from storage');
      debugPrint('User logged in: ${userProvider.isLoggedIn}');
      debugPrint('User ID: ${userProvider.userId}');
      debugPrint('Doc Wallet Setup: ${userProvider.hasDocWalletSetup}');

      // Initialize version service
      await VersionService.initialize();

      // Initialize feature flags from cache and fetch public flags for welcome/sign screens
      final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
      await featureFlagsProvider.initFromCache();
      await featureFlagsProvider.fetchPublicFeatureFlags();

      // Initialize subscription provider from cache first
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      await subscriptionProvider.initFromCache();

      // Check for saved user session
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('token');
      final username = prefs.getString('username');

      debugPrint('SplashScreen - Retrieved from SharedPreferences: userId=${userId?.isNotEmpty == true ? 'present' : 'missing'}, token=${token?.isNotEmpty == true ? 'present (${token?.length} chars)' : 'missing'}, username=${username ?? 'missing'}');

      if (userId != null && token != null && userId.isNotEmpty && token.isNotEmpty) {
        debugPrint('SplashScreen - User session found, updating UserProvider');
        // User is logged in, update providers
        // Try multiple sources for a cached username; do NOT default to 'User'
        final cachedName =
            (prefs.getString('user_name_$userId') ??
                prefs.getString('cached_username') ??
                username);

        userProvider.updateUserInfo(
          userId: userId,
          token: token,
          username: cachedName,
        );

        // Ensure username is refreshed from cache after storage init
        await userProvider.refreshUsernameFromCache();

        // Initialize subscription data in background
        subscriptionProvider.fetchSubscriptionStatus(
          token: token,
          userId: userId,
        );
        subscriptionProvider.fetchReceiptLimit(
          token: token,
          userId: userId,
        );

        userProvider.checkAndCacheDocWalletStatus(token);

        setState(() {
          _isInitialized = true;
        });

        // Wait for animation to complete
        await _controller.forward();
        await Future.delayed(const Duration(milliseconds: 500));

        // Defer share-intent handling to Dashboard to avoid blocking splash
        // Dashboard will process any pending shared file on resume/open

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
        // No saved session, go to welcome screen
        setState(() {
          _isInitialized = true;
        });

        await _controller.forward();
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const WelcomeScreen(),
            ),
          );
        }
      }

      debugPrint('=== App Initialization Completed ===');
    } catch (e) {
      debugPrint('Splash - Initialization error: $e');

      setState(() {
        _isInitialized = true;
      });

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const WelcomeScreen(),
          ),
        );
      }
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
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _animation.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'MR',
                        style: TextStyle(
                          color: Color(0xFF7E5EFD),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Opacity(
                  opacity: _animation.value,
                  child: const Column(
                    children: [
                      Text(
                        'Manage Receipt',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Track expenses with ease',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 60),
            if (!_isInitialized)
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
