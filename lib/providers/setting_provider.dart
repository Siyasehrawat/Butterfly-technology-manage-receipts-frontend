import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  String _currencySymbol = '\$';
  ThemeMode _themeMode = ThemeMode.light;

  String get currencySymbol => _currencySymbol;
  ThemeMode get themeMode => _themeMode;

  void setCurrencySymbol(String symbol) {
    _currencySymbol = symbol;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}