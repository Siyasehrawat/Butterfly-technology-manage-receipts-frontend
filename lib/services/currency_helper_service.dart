import 'package:flutter/foundation.dart';
import 'currency_conversion_service.dart';
import 'currency_Service.dart';
import '../providers/user_provider.dart';

/// Comprehensive currency helper service that integrates:
/// - CurrencyConversionService (ExchangeRate-API integration)
/// - CurrencyService (Country to currency mapping)
/// - User preferences and receipt processing workflow
class CurrencyHelperService {
  
  /// Get user's currency from UserProvider
  static String getUserCurrency(UserProvider userProvider) {
    return userProvider.currency ?? 'USD';
  }
  
  /// Get user's currency symbol from UserProvider
  static String getUserCurrencySymbol(UserProvider userProvider) {
    return userProvider.effectiveCurrencySymbol;
  }
  
  /// Prepare process receipt payload with country
  static Map<String, dynamic> buildProcessReceiptPayload({
    required String imageUrl,
    required String userId,
    String? country,
  }) {
    final payload = {
      'imageUrl': imageUrl,
      'userId': userId,
    };

    // Add country to payload if provided
    if (country != null && country.isNotEmpty) {
      payload['country'] = country;
      debugPrint('✅ Building process receipt payload with country: $country');
    } else {
      debugPrint('⚠️ WARNING: Building process receipt payload WITHOUT country!');
      debugPrint('   This means currency conversion detection may not work properly.');
    }

    debugPrint('📤 Final process receipt payload: $payload');
    return payload;
  }
  /// Build save receipt payload with currency conversion metadata
  static Map<String, dynamic> buildSaveReceiptPayload({
    required Map<String, dynamic> baseReceiptData,
    CurrencyConversionResult? conversionResult,
    bool hasAcceptedConversion = false,
  }) {
    final payload = Map<String, dynamic>.from(baseReceiptData);
    
    // Add currency conversion metadata if conversion was performed and accepted
    if (conversionResult != null && hasAcceptedConversion) {
      final currencyData = {
        'originalCurrency': conversionResult.fromCurrency,
        'convertedCurrency': conversionResult.toCurrency,
        'conversionRate': conversionResult.exchangeRate,
        'originalAmount': conversionResult.originalAmount,
        'convertedAmount': conversionResult.convertedAmount,
        'conversionDate': conversionResult.lastUpdated.toIso8601String(),
        'isApproximate': conversionResult.isApproximate,
      };
      
      payload.addAll(currencyData);
      debugPrint('Added currency conversion metadata to save payload: $currencyData');
    }
    
    return payload;
  }
  
  /// Check if currency conversion is needed
  static bool needsCurrencyConversion({
    String? ocrCurrency,
    String? userCurrency,
  }) {
    if (ocrCurrency == null || userCurrency == null) return false;
    return ocrCurrency.toUpperCase() != userCurrency.toUpperCase();
  }
  
  /// Perform currency conversion using ExchangeRate-API
  static Future<CurrencyConversionResult?> performConversion({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    try {
      if (amount <= 0) {
        debugPrint('Invalid amount for conversion: $amount');
        return null;
      }
      
      debugPrint('Performing currency conversion: $amount $fromCurrency -> $toCurrency');
      
      final result = await CurrencyConversionService.convertCurrency(
        amount: amount,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      );
      
      debugPrint('Conversion result: ${result.toString()}');
      return result;
      
    } catch (e) {
      debugPrint('Currency conversion failed: $e');
      return null;
    }
  }
  
  /// Get currency info from country (using CurrencyService)
  static Map<String, String> getCurrencyFromCountry(String country) {
    return CurrencyService.getCurrencyForCountry(country);
  }
  
  /// Get currency symbol for currency code (using CurrencyConversionService)
  static String getCurrencySymbol(String currencyCode) {
    return CurrencyConversionService.getCurrencySymbol(currencyCode);
  }
  
  /// Get currency name for currency code (using CurrencyConversionService)
  static String getCurrencyName(String currencyCode) {
    return CurrencyConversionService.getCurrencyName(currencyCode);
  }
  
  /// Format amount with currency symbol
  static String formatAmountWithCurrency(double amount, String currencyCode) {
    final symbol = getCurrencySymbol(currencyCode);
    
    if (amount < 1) {
      return '$symbol${amount.toStringAsFixed(4)}';
    } else if (amount < 100) {
      return '$symbol${amount.toStringAsFixed(2)}';
    } else {
      return '$symbol${amount.toStringAsFixed(0)}';
    }
  }
  
  /// Validate currency code
  static bool isValidCurrencyCode(String currencyCode) {
    final commonCurrencies = [
      'USD', 'EUR', 'GBP', 'INR', 'JPY', 'CAD', 'AUD', 'CHF', 'CNY', 'SEK',
      'NOK', 'DKK', 'PLN', 'CZK', 'HUF', 'RON', 'BGN', 'HRK', 'RUB', 'TRY',
      'BRL', 'MXN', 'ZAR', 'KRW', 'SGD', 'HKD', 'NZD', 'THB', 'MYR', 'PHP',
      'RSD' // Add Serbian Dinar
    ];
    
    return commonCurrencies.contains(currencyCode.toUpperCase());
  }
  
  /// Parse receipt data and extract currency information
  static Map<String, String?> parseReceiptCurrencyData(Map<String, dynamic> receiptData) {
    return {
      'ocrCurrency': receiptData['ocrCurrency']?.toString(),
      'userCurrency': receiptData['userCurrency']?.toString(),
      'originalCurrency': receiptData['originalCurrency']?.toString(),
      'convertedCurrency': receiptData['convertedCurrency']?.toString(),
      'conversionRate': receiptData['conversionRate']?.toString(),
    };
  }
  
  /// Create conversion result from receipt data (for loading existing conversions)
  static CurrencyConversionResult? createConversionFromReceiptData(Map<String, dynamic> receiptData) {
    try {
      final originalAmount = double.tryParse(receiptData['originalAmount']?.toString() ?? '');
      final convertedAmount = double.tryParse(receiptData['convertedAmount']?.toString() ?? '');
      final conversionRate = double.tryParse(receiptData['conversionRate']?.toString() ?? '');
      final originalCurrency = receiptData['originalCurrency']?.toString();
      final convertedCurrency = receiptData['convertedCurrency']?.toString();
      final conversionDate = receiptData['conversionDate']?.toString();
      final isApproximate = receiptData['isApproximate'] == true;
      
      if (originalAmount == null || convertedAmount == null || conversionRate == null ||
          originalCurrency == null || convertedCurrency == null) {
        return null;
      }
      
      DateTime lastUpdated = DateTime.now();
      if (conversionDate != null) {
        lastUpdated = DateTime.tryParse(conversionDate) ?? DateTime.now();
      }
      
      return CurrencyConversionResult(
        originalAmount: originalAmount,
        convertedAmount: convertedAmount,
        fromCurrency: originalCurrency,
        toCurrency: convertedCurrency,
        exchangeRate: conversionRate,
        lastUpdated: lastUpdated,
        isApproximate: isApproximate,
      );
    } catch (e) {
      debugPrint('Error creating conversion result from receipt data: $e');
      return null;
    }
  }
  
  /// Get all supported currencies
  static Future<List<String>> getSupportedCurrencies() async {
    return await CurrencyConversionService.getSupportedCurrencies();
  }
  
  /// Log currency conversion flow for debugging
  static void logCurrencyFlow({
    required String step,
    String? ocrCurrency,
    String? userCurrency,
    double? amount,
    CurrencyConversionResult? conversionResult,
    Map<String, dynamic>? additionalData,
  }) {
    debugPrint('=== Currency Flow Debug ===');
    debugPrint('Step: $step');
    debugPrint('OCR Currency: $ocrCurrency');
    debugPrint('User Currency: $userCurrency');
    debugPrint('Amount: $amount');
    
    if (conversionResult != null) {
      debugPrint('Conversion Result: ${conversionResult.toString()}');
    }
    
    if (additionalData != null) {
      debugPrint('Additional Data: $additionalData');
    }
    debugPrint('========================');
  }
}

/// Extension methods for UserProvider to simplify currency operations
extension CurrencyUserProviderExtensions on UserProvider {
  
  /// Get currency code (e.g., 'USD', 'INR')
  String get currencyCode => currency ?? 'USD';
  
  /// Get currency symbol (e.g., '$', '₹')
  String get userCurrencySymbol => CurrencyHelperService.getCurrencySymbol(currencyCode);
  
  /// Get currency name (e.g., 'US Dollar', 'Indian Rupee')
  String get currencyName => CurrencyHelperService.getCurrencyName(currencyCode);
  
  /// Format amount with user's currency
  String formatAmount(double amount) {
    return CurrencyHelperService.formatAmountWithCurrency(amount, currencyCode);
  }
}
