import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class CurrencyConversionService {
  // ExchangeRate-API Free tier endpoint
  static const String _baseUrl = 'https://v6.exchangerate-api.com/v6';
  
  // ExchangeRate-API key
  static const String _apiKey = 'd2f1aaacbe6c4a2261df5acf';
  
  /// Convert amount from one currency to another
  /// 
  /// [amount] - The amount to convert
  /// [fromCurrency] - Source currency code (e.g., 'USD')
  /// [toCurrency] - Target currency code (e.g., 'INR')
  /// 
  /// Returns a [CurrencyConversionResult] with the converted amount and exchange rate
  static Future<CurrencyConversionResult> convertCurrency({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    try {
      // If converting from same currency, return original amount
      if (fromCurrency.toUpperCase() == toCurrency.toUpperCase()) {
        return CurrencyConversionResult(
          originalAmount: amount,
          convertedAmount: amount,
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          exchangeRate: 1.0,
          lastUpdated: DateTime.now(),
        );
      }

      final String url = '$_baseUrl/$_apiKey/pair/$fromCurrency/$toCurrency';
      
      debugPrint('Currency conversion request: $url');
      debugPrint('Converting $amount $fromCurrency to $toCurrency');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Currency conversion request timed out');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Check if the API returned success
        if (data['result'] == 'success') {
          final double exchangeRate = data['conversion_rate'].toDouble();
          final double convertedAmount = amount * exchangeRate;
          
          return CurrencyConversionResult(
            originalAmount: amount,
            convertedAmount: convertedAmount,
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            exchangeRate: exchangeRate,
            lastUpdated: DateTime.now(),
          );
        } else {
          throw Exception('Currency conversion failed: ${data['error-type'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to fetch exchange rate');
      }
    } catch (e) {
      debugPrint('Currency conversion error: $e');
      
      // Fallback to approximate rates if API fails
      return _getFallbackConversion(
        amount: amount,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      );
    }
  }

  /// Get supported currency codes from the API
  static Future<List<String>> getSupportedCurrencies() async {
    try {
      final String url = '$_baseUrl/$_apiKey/codes';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['result'] == 'success') {
          final List<dynamic> codes = data['supported_codes'];
          return codes.map<String>((code) => code[0].toString()).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching supported currencies: $e');
    }
    
    // Return common currencies as fallback
    return _getCommonCurrencies();
  }

  /// Get fallback conversion using approximate exchange rates
  /// This is used when the API is unavailable
  static CurrencyConversionResult _getFallbackConversion({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) {
    // Approximate exchange rates (these should be updated regularly in production)
    final Map<String, double> usdRates = {
      'USD': 1.0,
      'EUR': 0.85,
      'GBP': 0.73,
      'INR': 83.0,
      'JPY': 110.0,
      'CAD': 1.25,
      'AUD': 1.35,
      'CHF': 0.92,
      'CNY': 6.4,
      'SEK': 8.6,
      'RSD': 100.0, // Serbian Dinar
    };

    double exchangeRate = 1.0;
    
    if (fromCurrency.toUpperCase() == 'USD') {
      exchangeRate = usdRates[toCurrency.toUpperCase()] ?? 1.0;
    } else if (toCurrency.toUpperCase() == 'USD') {
      exchangeRate = 1.0 / (usdRates[fromCurrency.toUpperCase()] ?? 1.0);
    } else {
      // Convert through USD
      final fromToUsd = 1.0 / (usdRates[fromCurrency.toUpperCase()] ?? 1.0);
      final usdToTarget = usdRates[toCurrency.toUpperCase()] ?? 1.0;
      exchangeRate = fromToUsd * usdToTarget;
    }

    final double convertedAmount = amount * exchangeRate;

    return CurrencyConversionResult(
      originalAmount: amount,
      convertedAmount: convertedAmount,
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      exchangeRate: exchangeRate,
      lastUpdated: DateTime.now(),
      isApproximate: true,
    );
  }

  /// Get list of common currency codes
  static List<String> _getCommonCurrencies() {
    return [
      'USD', 'EUR', 'GBP', 'INR', 'JPY', 'CAD', 'AUD', 'CHF', 'CNY', 'SEK',
      'NOK', 'DKK', 'PLN', 'CZK', 'HUF', 'RON', 'BGN', 'HRK', 'RUB', 'TRY',
      'BRL', 'MXN', 'ZAR', 'KRW', 'SGD', 'HKD', 'NZD', 'THB', 'MYR', 'PHP',
      'RSD' // Serbian Dinar
    ];
  }

  /// Get currency symbol for common currencies
  static String getCurrencySymbol(String currencyCode) {
    final Map<String, String> currencySymbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'INR': '₹',
      'JPY': '¥',
      'CAD': 'C\$',
      'AUD': 'A\$',
      'CHF': 'CHF',
      'CNY': '¥',
      'SEK': 'kr',
      'NOK': 'kr',
      'DKK': 'kr',
      'PLN': 'zł',
      'CZK': 'Kč',
      'HUF': 'Ft',
      'RON': 'lei',
      'BGN': 'лв',
      'HRK': 'kn',
      'RUB': '₽',
      'TRY': '₺',
      'BRL': 'R\$',
      'MXN': '\$',
      'ZAR': 'R',
      'KRW': '₩',
      'SGD': 'S\$',
      'HKD': 'HK\$',
      'NZD': 'NZ\$',
      'THB': '฿',
      'MYR': 'RM',
      'PHP': '₱',
      'RSD': 'дин', // Serbian Dinar
    };
    
    return currencySymbols[currencyCode.toUpperCase()] ?? currencyCode.toUpperCase();
  }

  /// Get full currency name for display
  static String getCurrencyName(String currencyCode) {
    final Map<String, String> currencyNames = {
      'USD': 'US Dollar',
      'EUR': 'Euro',
      'GBP': 'British Pound',
      'INR': 'Indian Rupee',
      'JPY': 'Japanese Yen',
      'CAD': 'Canadian Dollar',
      'AUD': 'Australian Dollar',
      'CHF': 'Swiss Franc',
      'CNY': 'Chinese Yuan',
      'SEK': 'Swedish Krona',
      'NOK': 'Norwegian Krone',
      'DKK': 'Danish Krone',
      'PLN': 'Polish Zloty',
      'CZK': 'Czech Koruna',
      'HUF': 'Hungarian Forint',
      'RON': 'Romanian Leu',
      'BGN': 'Bulgarian Lev',
      'HRK': 'Croatian Kuna',
      'RUB': 'Russian Ruble',
      'TRY': 'Turkish Lira',
      'BRL': 'Brazilian Real',
      'MXN': 'Mexican Peso',
      'ZAR': 'South African Rand',
      'KRW': 'South Korean Won',
      'SGD': 'Singapore Dollar',
      'HKD': 'Hong Kong Dollar',
      'NZD': 'New Zealand Dollar',
      'THB': 'Thai Baht',
      'MYR': 'Malaysian Ringgit',
      'PHP': 'Philippine Peso',
      'RSD': 'Serbian Dinar',
    };
    
    return currencyNames[currencyCode.toUpperCase()] ?? currencyCode.toUpperCase();
  }
}

/// Result class for currency conversion
class CurrencyConversionResult {
  final double originalAmount;
  final double convertedAmount;
  final String fromCurrency;
  final String toCurrency;
  final double exchangeRate;
  final DateTime lastUpdated;
  final bool isApproximate;

  CurrencyConversionResult({
    required this.originalAmount,
    required this.convertedAmount,
    required this.fromCurrency,
    required this.toCurrency,
    required this.exchangeRate,
    required this.lastUpdated,
    this.isApproximate = false,
  });

  @override
  String toString() {
    return 'CurrencyConversionResult(original: $originalAmount $fromCurrency, '
        'converted: $convertedAmount $toCurrency, rate: $exchangeRate, '
        'approximate: $isApproximate)';
  }

  /// Format the converted amount with appropriate decimal places
  String get formattedConvertedAmount {
    if (convertedAmount < 1) {
      return convertedAmount.toStringAsFixed(4);
    } else if (convertedAmount < 100) {
      return convertedAmount.toStringAsFixed(2);
    } else {
      return convertedAmount.toStringAsFixed(0);
    }
  }

  /// Format the original amount with appropriate decimal places
  String get formattedOriginalAmount {
    if (originalAmount < 1) {
      return originalAmount.toStringAsFixed(4);
    } else if (originalAmount < 100) {
      return originalAmount.toStringAsFixed(2);
    } else {
      return originalAmount.toStringAsFixed(0);
    }
  }
}