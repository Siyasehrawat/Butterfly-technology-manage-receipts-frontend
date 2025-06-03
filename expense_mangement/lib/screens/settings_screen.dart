import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_screen.dart';
import 'update_password_screen.dart';
import '../providers/setting_provider.dart';
import '../providers/user_provider.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  String _selectedCurrency = 'US Dollar (\$)';

  // Map of countries to their default currencies
  final Map<String, String> _countryCurrencyMap = {
    'United States': 'US Dollar (\$)',
    'United Kingdom': 'British Pound (£)',
    'Canada': 'Canadian Dollar (C\$)',
    'Australia': 'Australian Dollar (A\$)',
    'India': 'Indian Rupee (₹)',
    'Serbia': 'Serbian Dinar (RSD)',
    'Germany': 'Euro (€)',
    'France': 'Euro (€)',
    'Japan': 'Japanese Yen (¥)',
    'China': 'Chinese Yuan (¥)',
  };

  // List of available currencies
  final List<String> _availableCurrencies = [
    'US Dollar (\$)',
    'British Pound (£)',
    'Euro (€)',
    'Canadian Dollar (C\$)',
    'Australian Dollar (A\$)',
    'Indian Rupee (₹)',
    'Serbian Dinar (RSD)',
    'Japanese Yen (¥)',
    'Chinese Yuan (¥)',
  ];

  @override
  void initState() {
    super.initState();
    // Set currency based on user's country when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

      // Get user's country
      final userCountry = userProvider.country;

      // Set currency based on country
      if (userCountry != null && _countryCurrencyMap.containsKey(userCountry)) {
        final currencyForCountry = _countryCurrencyMap[userCountry]!;
        _selectedCurrency = currencyForCountry;

        // Set the currency symbol in the provider
        if (currencyForCountry == 'US Dollar (\$)') {
          settingsProvider.setCurrencySymbol('\$');
        } else if (currencyForCountry == 'British Pound (£)') {
          settingsProvider.setCurrencySymbol('£');
        } else if (currencyForCountry == 'Euro (€)') {
          settingsProvider.setCurrencySymbol('€');
        } else if (currencyForCountry == 'Canadian Dollar (C\$)') {
          settingsProvider.setCurrencySymbol('C\$');
        } else if (currencyForCountry == 'Australian Dollar (A\$)') {
          settingsProvider.setCurrencySymbol('A\$');
        } else if (currencyForCountry == 'Indian Rupee (₹)') {
          settingsProvider.setCurrencySymbol('₹');
        } else if (currencyForCountry == 'Serbian Dinar (RSD)') {
          settingsProvider.setCurrencySymbol('RSD');
        } else if (currencyForCountry == 'Japanese Yen (¥)') {
          settingsProvider.setCurrencySymbol('¥');
        } else if (currencyForCountry == 'Chinese Yuan (¥)') {
          settingsProvider.setCurrencySymbol('¥');
        } else {
          settingsProvider.setCurrencySymbol('\$'); // Default
        }
      } else {
        // Default to US Dollar if country not found
        settingsProvider.setCurrencySymbol('\$');
      }

      // Ensure light mode is set
      settingsProvider.setThemeMode(ThemeMode.light);
    });
  }

  // Helper method to get currency symbol from currency name
  String _getCurrencySymbol(String currencyName) {
    if (currencyName.contains('\$')) return '\$';
    if (currencyName.contains('£')) return '£';
    if (currencyName.contains('€')) return '€';
    if (currencyName.contains('C\$')) return 'C\$';
    if (currencyName.contains('A\$')) return 'A\$';
    if (currencyName.contains('₹')) return '₹';
    if (currencyName.contains('RSD')) return 'RSD';
    if (currencyName.contains('¥')) return '¥';
    return '\$'; // Default
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          // Purple header with back button
          Container(
            color: const Color(0xFF7E5EFD),
            padding: const EdgeInsets.only(top: 40, bottom: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 16),
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

          // White content area
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width > 600 ? 48 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Manage your account and preferences easily.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Account section
                    const Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text(
                              'Edit Profile',
                              style: TextStyle(color: Colors.black),
                            ),
                            trailing: const Icon(
                              Icons.edit,
                              color: Color(0xFF7E5EFD),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(
                                    userId: userProvider.userId ?? '',
                                    token: userProvider.token ?? '',
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: const Text(
                              'Update Password',
                              style: TextStyle(color: Colors.black),
                            ),
                            trailing: const Icon(
                              Icons.edit,
                              color: Color(0xFF7E5EFD),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UpdatePasswordScreen(
                                    userId: userProvider.userId ?? '',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Notifications section
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text(
                              'Email Notifications',
                              style: TextStyle(color: Colors.black),
                            ),
                            value: _emailNotifications,
                            activeColor: const Color(0xFF7E5EFD),
                            onChanged: (value) {
                              setState(() {
                                _emailNotifications = value;
                              });
                            },
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text(
                              'Push Notifications',
                              style: TextStyle(color: Colors.black),
                            ),
                            value: _pushNotifications,
                            activeColor: const Color(0xFF7E5EFD),
                            onChanged: (value) {
                              setState(() {
                                _pushNotifications = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Appearance section
                    const Text(
                      'Appearance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Theme Mode',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border:
                              Border.all(color: const Color(0xFF7E5EFD)),
                            ),
                            child: const Text(
                              'Light Mode',
                              style: TextStyle(
                                color: Color(0xFF7E5EFD),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Currency section - now with dropdown
                    const Text(
                      'Currency',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Currency',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border:
                              Border.all(color: const Color(0xFF7E5EFD)),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedCurrency,
                              underline: Container(), // Remove underline
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7E5EFD)),
                              style: const TextStyle(
                                color: Color(0xFF7E5EFD),
                                fontWeight: FontWeight.bold,
                              ),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedCurrency = newValue;
                                    // Update the currency symbol in the provider
                                    final settingsProvider = Provider.of<SettingsProvider>(
                                        context,
                                        listen: false
                                    );
                                    settingsProvider.setCurrencySymbol(
                                        _getCurrencySymbol(newValue)
                                    );
                                  });
                                }
                              },
                              items: _availableCurrencies
                                  .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Delete account button
                    Center(
                      child: TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white,
                              title: const Text(
                                'Delete Account',
                                style: TextStyle(color: Colors.black),
                              ),
                              content: const Text(
                                'Are you sure you want to delete your account? This action cannot be undone.',
                                style: TextStyle(color: Colors.black87),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(
                                        context); // Close the confirmation dialog

                                    final userId = userProvider.userId ?? '';
                                    final token = userProvider.token ?? '';

                                    if (userId.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'User ID is missing. Cannot delete account.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    if (token.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Authentication token is missing. Please log in again.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    try {
                                      final response = await http.post(
                                        Uri.parse(
                                            'https://manage-receipt-backend-bnl1.onrender.com/api/users/delete-account'),
                                        headers: {
                                          'Content-Type': 'application/json',
                                          'Authorization': 'Bearer $token',
                                        },
                                        body: jsonEncode({'userId': userId}),
                                      );

                                      if (response.statusCode == 200) {
                                        // Show success message
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Account deleted successfully.'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );

                                        // Clear user state before navigating
                                        await userProvider.logout();

                                        // Navigate to WelcomeScreen and clear navigation stack
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                              const WelcomeScreen()),
                                              (route) => false,
                                        );
                                      } else if (response.statusCode == 404) {
                                        // Handle user not found
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('User not found.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      } else {
                                        // Handle other errors
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to delete account: ${response.body}',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      // Handle network or unexpected errors
                                      debugPrint('Error deleting account: $e');
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'An error occurred. Please try again later.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text(
                          'Delete Account',
                          style: TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Version info
                    const Center(
                      child: Text(
                        'Version 3.0',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Settings saved successfully!'),
                              backgroundColor: Color(0xFF7E5EFD),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E5EFD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
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
        ],
      ),
    );
  }
}