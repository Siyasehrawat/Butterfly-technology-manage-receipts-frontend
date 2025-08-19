import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Providers
import 'providers/setting_provider.dart';
import 'providers/user_provider.dart';
import 'providers/receipt_provider.dart';
import 'providers/subscription_provider_bypass.dart';
import 'providers/category_provider.dart';
import 'providers/feature_flags_provider.dart';

// Services
import 'services/version_service.dart';
import 'services/api_service_bypass.dart';
import 'services/fcm_service.dart';
import 'services/share_intent_api_service.dart';
import 'services/cloudinary_service.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/verify_otp_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/update_password_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/reports_home_screen.dart';
import 'screens/filters_screen.dart';
import 'screens/receipt_details_screen.dart';
import 'screens/subscription_plans_screen.dart';
import 'screens/subscription_management_screen.dart';
import 'screens/split_receipts_screen.dart';
import 'screens/edit_tags_screen.dart';
import 'screens/no_internet_screen.dart';
import 'screens/bill_reminders_screen.dart';
import 'screens/more_options_screen.dart';
import 'screens/mr_bucks_screen.dart';
import 'screens/mr_bucks_admin_screen.dart';
// import 'screens/refer_earn_screen.dart'; // Handled via direct navigation

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

// Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('Environment variables loaded successfully');
  } catch (e) {
    debugPrint('Error loading environment variables: $e');
  }

// Initialize FCM Service
  try {
    await FCMService.initialize();
    debugPrint('FCM Service initialized successfully');
  } catch (e) {
    debugPrint('Error initializing FCM Service: $e');
  }

// Initialize version service
  try {
    await VersionService.initialize();
    debugPrint('VersionService initialized successfully');
  } catch (e) {
    debugPrint('Error initializing VersionService: $e');
  }

// Set navigator key for ApiService
  ApiService.setNavigatorKey(navigatorKey);

// Initialize subscription service
  try {
    debugPrint('Subscription service ready');
  } catch (e) {
    debugPrint('Error initializing subscription service: $e');
  }

// Initialize share intent services
  try {
    ShareIntentApiService.configure();
    CloudinaryService.initialize();
    debugPrint('Share intent services initialized successfully');
  } catch (e) {
    debugPrint('Error initializing share intent services: $e');
  }

// Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Handle Flutter errors gracefully
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log errors in debug mode but don't crash the app
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isConnected = true; // Assume connected initially

  @override
  void initState() {
    super.initState();
    _checkConnectivity(); // Initial check
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      setState(() {
        _isConnected = results.contains(ConnectivityResult.mobile) ||
            results.contains(ConnectivityResult.wifi) ||
            results.contains(ConnectivityResult.ethernet);
      });
      // The MaterialApp builder will handle showing/hiding NoInternetScreen
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    setState(() {
      _isConnected = connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.ethernet);
    });
    // The MaterialApp builder will handle showing/hiding NoInternetScreen
  }

  void _retryConnection() {
    _checkConnectivity();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => ReceiptProvider()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
        ChangeNotifierProvider(create: (context) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (context) => CategoryProvider()),
        ChangeNotifierProvider(create: (context) => FeatureFlagsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: 'Manage Receipt',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: ThemeData(
              brightness: Brightness.light,
              primaryColor: const Color(0xFF7E5EFD),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF7E5EFD),
                primary: const Color(0xFF7E5EFD),
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF7E5EFD),
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7E5EFD),
                  side: const BorderSide(color: Color(0xFF7E5EFD)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16, // Adjusted to match dashboard buttons
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7E5EFD),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF7E5EFD)),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              cardTheme: const CardThemeData(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              dividerColor: Colors.grey[300],
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.black87),
                bodyMedium: TextStyle(color: Colors.black87),
                titleLarge: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                titleMedium: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                titleSmall: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
              dialogTheme: const DialogThemeData(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              snackBarTheme: SnackBarThemeData(
                backgroundColor: const Color(0xFF7E5EFD),
                contentTextStyle: const TextStyle(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            ),
            themeMode: ThemeMode.light,
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/welcome': (context) => const WelcomeScreen(),
              '/sign_in': (context) => SignInScreen(),
              '/sign_up': (context) => SignUpScreen(),
              '/forgot_password': (context) => ForgotPasswordScreen(),
              '/reset_password': (context) {
                final userProvider = Provider.of<UserProvider>(
                  context,
                  listen: false,
                );
                return ResetPasswordScreen(
                  email: userProvider.email ?? '',
                  otp: userProvider.otp ?? '',
                );
              },
              '/profile': (context) {
                final userProvider = Provider.of<UserProvider>(
                  context,
                  listen: false,
                );
                return ProfileScreen(
                  userId: userProvider.userId ?? '',
                  token: userProvider.token ?? '',
                );
              },
              '/complete-profile': (context) {
                return CompleteProfileScreen(
                  navigateToAfterSave: (ctx) {
                    final userProvider = Provider.of<UserProvider>(
                      ctx,
                      listen: false,
                    );
                    return DashboardScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                    );
                  },
                );
              },
              '/settings': (context) => const SettingsScreen(),
              '/update_password': (context) {
                final userId = Provider.of<UserProvider>(
                  context,
                  listen: false,
                ).userId;
                return UpdatePasswordScreen(userId: userId ?? '');
              },
              '/reports': (context) => const ReportsHomeScreen(),
              '/filters': (context) => const FiltersScreen(),
              '/dashboard': (context) {
                final userProvider = Provider.of<UserProvider>(
                  context,
                  listen: false,
                );
                return DashboardScreen(
                  userId: userProvider.userId ?? '',
                  token: userProvider.token ?? '',
                );
              },
              '/subscription_plans': (context) {
                final userProvider = Provider.of<UserProvider>(
                  context,
                  listen: false,
                );
                return SubscriptionPlansScreen(
                  userId: userProvider.userId ?? '',
                  token: userProvider.token ?? '',
                );
              },
              '/subscription_management': (context) {
                final userProvider = Provider.of<UserProvider>(
                  context,
                  listen: false,
                );
                return SubscriptionManagementScreen(
                  userId: userProvider.userId ?? '',
                  token: userProvider.token ?? '',
                );
              },
              '/receipt_details': (context) {
                final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                return ReceiptDetailsScreen(
                  receipt: args['receipt'] ?? {},
                  imageUrl: args['imageUrl'] ?? '',
                  userId: args['userId'] ?? '',
                  imageId: args['imageId'] ?? '',
                  isNewReceipt: args['isNewReceipt'] ?? false,
                  isPdf: args['isPdf'] ?? false,
                  isManualReceipt: args['isManualReceipt'] ?? false,
                );
              },
              '/verify_otp': (context) {
                final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                return VerifyOtpScreen(
                  email: args['email'] ?? '',
                );
              },
              '/split_receipts': (context) {
                final userProvider = Provider.of<UserProvider>(context, listen: false);
                return SplitReceiptsScreen(
                  userId: userProvider.userId ?? '',
                  token: userProvider.token ?? '',
                );
              },
              '/edit_tags': (context) {
                final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
                final userProvider = Provider.of<UserProvider>(context, listen: false);
                return EditTagsScreen(
                  initialValues: (args?['initialValues'] as List<dynamic>?)?.cast<String>() ?? [],
                  userId: userProvider.userId ?? '',
                );
              },
              '/bill_reminders': (context) => const BillRemindersScreen(),
              '/more': (context) {
                final userProvider = Provider.of<UserProvider>(
                  context,
                  listen: false,
                );
                return MoreOptionsScreen(
                  userId: userProvider.userId ?? '',
                  token: userProvider.token ?? '',
                );
              },
              '/mr_bucks': (context) => const MrBucksScreen(),
              '/mr_bucks_admin': (context) => const MrBucksAdminScreen(),
              // '/refer_earn': Handled via direct navigation in MoreOptionsScreen
              '/no_internet': (context) => NoInternetScreen(onRetry: _retryConnection),
            },
            builder: (context, child) {
              // Set context for ApiService
              if (child != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ApiService.setContext(context);
                });
              }

              // Conditionally show NoInternetScreen
              if (!_isConnected) {
                return NoInternetScreen(onRetry: _retryConnection);
              }
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaleFactor: 1.0,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
