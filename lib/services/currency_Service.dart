class CurrencyService {
  // Hardcoded supported countries with currency mapping
  static const Map<String, Map<String, String>> _countryToCurrency = {
    'United States': {'currency': 'USD', 'symbol': '\$'},
    'India': {'currency': 'INR', 'symbol': '₹'},
    'Serbia': {'currency': 'RSD', 'symbol': 'дин'}
  };

  /// Get currency information for a country
  static Map<String, String> getCurrencyForCountry(String country) {
    // Try exact match first
    if (_countryToCurrency.containsKey(country)) {
      return _countryToCurrency[country]!;
    }

    // Try partial match (case insensitive)
    final lowerCountry = country.toLowerCase();
    for (final entry in _countryToCurrency.entries) {
      if (entry.key.toLowerCase().contains(lowerCountry) ||
          lowerCountry.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    // Default to USD if no match found
    return {'currency': 'USD', 'symbol': '\$'};
  }

  /// Get currency symbol for a country
  static String getCurrencySymbol(String country) {
    return getCurrencyForCountry(country)['symbol'] ?? '\$';
  }

  /// Get currency code for a country
  static String getCurrencyCode(String country) {
    return getCurrencyForCountry(country)['currency'] ?? 'USD';
  }

  /// Check if a country has a known currency mapping
  static bool hasMapping(String country) {
    return _countryToCurrency.containsKey(country) ||
        _countryToCurrency.keys.any((key) =>
        key.toLowerCase().contains(country.toLowerCase()) ||
            country.toLowerCase().contains(key.toLowerCase()));
  }

  /// Get all supported countries
  static List<String> getSupportedCountries() {
    return _countryToCurrency.keys.toList()..sort();
  }

  /// Get currency info with fallback to user preferences
  static Map<String, String> getCurrencyWithFallback(
      String? country,
      String? fallbackSymbol,
      String? fallbackCurrency
      ) {
    if (country != null && country.isNotEmpty) {
      return getCurrencyForCountry(country);
    }

    return {
      'currency': fallbackCurrency ?? 'USD',
      'symbol': fallbackSymbol ?? '\$',
    };
  }
}
