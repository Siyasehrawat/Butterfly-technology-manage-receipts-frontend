import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  String _currencySymbol = '\$';
  ThemeMode _themeMode = ThemeMode.light;

  String get currencySymbol => _currencySymbol;
  ThemeMode get themeMode => _themeMode;

  // Initialize settings from storage
  Future<void> initFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _currencySymbol = prefs.getString('currencySymbol') ?? '\$';
    final themeModeIndex = prefs.getInt('themeMode') ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex];
    notifyListeners();
  }

  Future<void> setCurrencySymbol(String symbol) async {
    _currencySymbol = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currencySymbol', symbol);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  // Helper method to get currency symbol from currency name
  String getCurrencySymbolFromName(String currencyName) {
    if (currencyName.contains('\$')) return '\$';
    if (currencyName.contains('£')) return '£';
    if (currencyName.contains('€')) return '€';
    if (currencyName.contains('C\$')) return 'C\$';
    if (currencyName.contains('A\$')) return 'A\$';
    if (currencyName.contains('₹')) return '₹';
    if (currencyName.contains('RSD')) return 'RSD';
    if (currencyName.contains('¥')) return '¥';
    if (currencyName.contains('Дин.')) return 'Дин.';
    return '\$'; // Default
  }

  // Get currency symbol from code
  String getCurrencySymbolFromCode(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'INR':
        return '₹';
      default:
        return '\$';
    }
  }
}
