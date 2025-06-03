import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/setting_provider.dart';
import '../providers/user_provider.dart';
import 'dashboard_screen.dart';
import '../widgets/app_logo.dart';

class CurrencySelectionScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String country;

  const CurrencySelectionScreen({
    Key? key,
    required this.userId,
    required this.token,
    required this.country,
  }) : super(key: key);

  @override
  State<CurrencySelectionScreen> createState() => _CurrencySelectionScreenState();
}

class _CurrencySelectionScreenState extends State<CurrencySelectionScreen> {
  String _selectedCurrency = 'US Dollar (\$)';
  bool _isLoading = false;

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
    // Set default currency based on country
    if (_countryCurrencyMap.containsKey(widget.country)) {
      _selectedCurrency = _countryCurrencyMap[widget.country]!;
    }
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

  void _continueToDashboard() {
    setState(() {
      _isLoading = true;
    });

    // Set the currency in the provider
    final settingsProvider = Provider.of<SettingsProvider>(
        context, listen: false);
    settingsProvider.setCurrencySymbol(_getCurrencySymbol(_selectedCurrency));

    // Navigate to dashboard
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DashboardScreen(
              userId: widget.userId,
              token: widget.token,
            ),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Purple header
            Container(
              color: const Color(0xFF7E5EFD),
              padding: const EdgeInsets.symmetric(vertical: 24),
              width: double.infinity,
              child: const Center(child: AppLogo()),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Select Your Currency',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Choose the currency you want to use for your receipts',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.4,
                        ),
                        itemCount: _availableCurrencies.length,
                        itemBuilder: (context, index) {
                          final currency = _availableCurrencies[index];
                          final isSelected = currency == _selectedCurrency;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCurrency = currency;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFF0E6FF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF7E5EFD)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _getCurrencySymbol(currency),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? const Color(
                                          0xFF7E5EFD) : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    currency.split(' ')[0] +
                                        ' ' +
                                        (currency
                                            .split(' ')
                                            .length > 1
                                            ? currency.split(' ')[1]
                                            : ''),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected ? const Color(
                                          0xFF7E5EFD) : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Continue button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _continueToDashboard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E5EFD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                              color: Colors.white)
                              : const Text(
                            'Continue',
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
      ),
    );
  }
}
