import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

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
import 'screens/tax_calculator_screen.dart';
import 'screens/track_distance_screen.dart';
import 'utils/country_utils.dart';
import 'web/app/web_settings.dart';
import 'web/app/web_mr_bucks.dart';
import 'screens/workspace_dashboard_screen.dart';
import 'screens/workspace_intro_screen.dart';
import 'screens/workspace_onboarding_screen.dart';
import 'screens/manage_team_members_screen.dart';
import 'screens/pending_approvals_screen.dart';
import 'screens/workspace_analytics_screen.dart';
import 'screens/workspaces_list_screen.dart';
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
              textTheme: GoogleFonts.notoSansTextTheme().copyWith(
                bodyLarge: const TextStyle(color: Colors.black87),
                bodyMedium: const TextStyle(color: Colors.black87),
                titleLarge: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                titleMedium: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                titleSmall: const TextStyle(
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
            // Remove page transition animation - instant transition
            onGenerateRoute: (RouteSettings settings) {
              WidgetBuilder builder;
              
              // Map routes to their builders
              switch (settings.name) {
                case '/':
                  builder = (context) => const SplashScreen();
                  break;
                case '/welcome':
                  builder = (context) => const WelcomeScreen();
                  break;
                case '/sign_in':
                  builder = (context) => SignInScreen();
                  break;
                case '/sign_up':
                  builder = (context) => SignUpScreen();
                  break;
                case '/forgot_password':
                  builder = (context) => ForgotPasswordScreen();
                  break;
                case '/reset_password':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(
                      context,
                      listen: false,
                    );
                    return ResetPasswordScreen(
                      emailOrPhone: userProvider.email ?? '',
                      otp: userProvider.otp ?? '',
                    );
                  };
                  break;
                case '/profile':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(
                      context,
                      listen: false,
                    );
                    return ProfileScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                    );
                  };
                  break;
                case '/complete-profile':
                  builder = (context) {
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
                  };
                  break;
                case '/settings':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    if (kIsWeb) {
                      return WebSettingsScreen(
                        userId: userProvider.userId ?? '',
                        token: userProvider.token ?? '',
                      );
                    } else {
                      return const SettingsScreen();
                    }
                  };
                  break;
                case '/update_password':
                  builder = (context) {
                    final userId = Provider.of<UserProvider>(
                      context,
                      listen: false,
                    ).userId;
                    return UpdatePasswordScreen(userId: userId ?? '');
                  };
                  break;
                case '/reports':
                  builder = (context) => const ReportsHomeScreen();
                  break;
                case '/filters':
                  builder = (context) => const FiltersScreen();
                  break;
                case '/dashboard':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(
                      context,
                      listen: false,
                    );
                    return DashboardScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                    );
                  };
                  break;
                case '/subscription_plans':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(
                      context,
                      listen: false,
                    );
                    return SubscriptionPlansScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                    );
                  };
                  break;
                case '/subscription_management':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(
                      context,
                      listen: false,
                    );
                    return SubscriptionManagementScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                    );
                  };
                  break;
                case '/receipt_details':
                  builder = (context) {
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
                  };
                  break;
                case '/verify_otp':
                  builder = (context) {
                    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                    return VerifyOtpScreen(
                      emailOrPhone: args['emailOrPhone'] ?? args['email'] ?? '',
                    );
                  };
                  break;
                case '/split_receipts':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    return SplitReceiptsScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                    );
                  };
                  break;
                case '/edit_tags':
                  builder = (context) {
                    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    return EditTagsScreen(
                      initialValues: (args?['initialValues'] as List<dynamic>?)?.cast<String>() ?? [],
                      userId: userProvider.userId ?? '',
                    );
                  };
                  break;
                case '/bill_reminders':
                  builder = (context) => const BillRemindersScreen();
                  break;
                case '/more':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(
                      context,
                      listen: false,
                    );
                    return MoreOptionsScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                    );
                  };
                  break;
                case '/mr_bucks':
                  builder = (context) {
                    final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(
                      context,
                      listen: false,
                    );
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    
                    if (featureFlagsProvider.isMrBucksEnabled) {
                      if (kIsWeb) {
                        return WebMrBucksScreen(
                          userId: userProvider.userId ?? '',
                          token: userProvider.token ?? '',
                        );
                      } else {
                        return const MrBucksScreen();
                      }
                    } else {
                      // Feature is disabled, redirect to dashboard
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.of(context).pushReplacementNamed('/dashboard');
                      });
                      return const Scaffold(
                        body: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                  };
                  break;
                case '/mr_bucks_admin':
                  builder = (context) => const MrBucksAdminScreen();
                  break;
                case '/workspace':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    return WorkspaceOnboardingScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                    );
                  };
                  break;
                case '/workspace_dashboard':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    return WorkspaceDashboardScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                    );
                  };
                  break;
                case '/workspaces':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    return WorkspacesListScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                    );
                  };
                  break;
                case '/manage_team_members':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    return ManageTeamMembersScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                    );
                  };
                  break;
                case '/pending_approvals':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    return PendingApprovalsScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                    );
                  };
                  break;
                case '/workspace_analytics':
                  builder = (context) {
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    return WorkspaceAnalyticsScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                      workspaceId: null, // Optional; pass when available from navigation
                    );
                  };
                  break;
                case '/tax_calculator':
                  // Route guard: Hide Tax Calculator for Indian users
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  final userCountry = userProvider.country;
                  if (CountryUtils.isIndia(userCountry)) {
                    // Redirect to dashboard if user is from India
                    builder = (context) => DashboardScreen(
                      userId: userProvider.userId ?? '',
                      token: userProvider.token ?? '',
                    );
                  } else {
                    builder = (context) => const TaxCalculatorScreen();
                  }
                  break;
                case '/no_internet':
                  builder = (context) => NoInternetScreen(onRetry: _retryConnection);
                  break;
                default:
                  builder = (context) => Scaffold(
                    body: Center(
                      child: Text('Route not found: ${settings.name}'),
                    ),
                  );
              }
              
              // Return PageRouteBuilder with zero duration for instant transition
              return PageRouteBuilder(
                settings: settings,
                pageBuilder: (context, animation, secondaryAnimation) => builder(context),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              );
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
