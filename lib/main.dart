import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/setting_provider.dart';
import 'providers/user_provider.dart';
import 'providers/receipt_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/verify_otp_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/update_password_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/filters_screen.dart';
import 'screens/receipt_details_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => ReceiptProvider()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: 'Manage Receipt',
            debugShowCheckedModeBanner: false,
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
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              cardColor: Colors.white,
              dividerColor: Colors.grey[300],
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.black87),
                bodyMedium: TextStyle(color: Colors.black87),
                titleLarge: TextStyle(color: Colors.black),
                titleMedium: TextStyle(color: Colors.black),
                titleSmall: TextStyle(color: Colors.black),
              ), dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
            ),
            // Force light mode by removing darkTheme and setting themeMode to light
            themeMode: ThemeMode.light,
            // Change initial route to splash screen
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(), // Changed from WelcomeScreen to SplashScreen
              '/welcome': (context) => const WelcomeScreen(), // Add route for welcome screen
              '/sign_in': (context) => SignInScreen(),
              '/sign_up': (context) => SignUpScreen(),
              '/forgot_password': (context) => ForgotPasswordScreen(),
              '/reset_password': (context) => ResetPasswordScreen(email: '', otp: '',),
              '/profile': (context) => const ProfileScreen(userId: '', token: '',),
              '/settings': (context) => const SettingsScreen(),
              '/update_password': (context) {
                final userId = Provider.of<UserProvider>(context, listen: false).userId;
                return UpdatePasswordScreen(userId: userId!);
              },
              '/reports': (context) {
                final userId = Provider.of<UserProvider>(context, listen: false).userId;
                return ReportsScreen(userId: userId!);
              },
              '/filters': (context) => const FiltersScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/dashboard') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => DashboardScreen(
                    userId: args['userId'],
                    token: args['token'],
                  ),
                );
              } else if (settings.name == '/receipt_details') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => ReceiptDetailsScreen(
                    receipt: args['receipt'],
                    imageUrl: args['imageUrl'],
                    userId: args['userId'],
                    imageId: args['imageId'],
                    isNewReceipt: args['isNewReceipt'] ?? false,
                  ),
                );
              } else if (settings.name == '/verify_otp') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => VerifyOtpScreen(
                    email: args['email'],
                  ),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}