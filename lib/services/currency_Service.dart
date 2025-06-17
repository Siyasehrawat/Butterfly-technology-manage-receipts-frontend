class CurrencyService {
  // Comprehensive country to currency mapping
  static const Map<String, Map<String, String>> _countryToCurrency = {
    // Major currencies
    'United States': {'currency': 'USD', 'symbol': '\$'},
    'Canada': {'currency': 'CAD', 'symbol': 'C\$'},
    'United Kingdom': {'currency': 'GBP', 'symbol': '£'},
    'European Union': {'currency': 'EUR', 'symbol': '€'},
    'Germany': {'currency': 'EUR', 'symbol': '€'},
    'France': {'currency': 'EUR', 'symbol': '€'},
    'Italy': {'currency': 'EUR', 'symbol': '€'},
    'Spain': {'currency': 'EUR', 'symbol': '€'},
    'Netherlands': {'currency': 'EUR', 'symbol': '€'},
    'Belgium': {'currency': 'EUR', 'symbol': '€'},
    'Austria': {'currency': 'EUR', 'symbol': '€'},
    'Portugal': {'currency': 'EUR', 'symbol': '€'},
    'Ireland': {'currency': 'EUR', 'symbol': '€'},
    'Finland': {'currency': 'EUR', 'symbol': '€'},
    'Greece': {'currency': 'EUR', 'symbol': '€'},

    // Asian currencies
    'India': {'currency': 'INR', 'symbol': '₹'},
    'China': {'currency': 'CNY', 'symbol': '¥'},
    'Japan': {'currency': 'JPY', 'symbol': '¥'},
    'South Korea': {'currency': 'KRW', 'symbol': '₩'},
    'Singapore': {'currency': 'SGD', 'symbol': 'S\$'},
    'Hong Kong': {'currency': 'HKD', 'symbol': 'HK\$'},
    'Malaysia': {'currency': 'MYR', 'symbol': 'RM'},
    'Thailand': {'currency': 'THB', 'symbol': '฿'},
    'Indonesia': {'currency': 'IDR', 'symbol': 'Rp'},
    'Philippines': {'currency': 'PHP', 'symbol': '₱'},
    'Vietnam': {'currency': 'VND', 'symbol': '₫'},
    'Taiwan': {'currency': 'TWD', 'symbol': 'NT\$'},

    // Middle East & Africa
    'United Arab Emirates': {'currency': 'AED', 'symbol': 'د.إ'},
    'Saudi Arabia': {'currency': 'SAR', 'symbol': '﷼'},
    'Israel': {'currency': 'ILS', 'symbol': '₪'},
    'Turkey': {'currency': 'TRY', 'symbol': '₺'},
    'South Africa': {'currency': 'ZAR', 'symbol': 'R'},
    'Egypt': {'currency': 'EGP', 'symbol': '£'},
    'Nigeria': {'currency': 'NGN', 'symbol': '₦'},
    'Kenya': {'currency': 'KES', 'symbol': 'KSh'},

    // Americas
    'Brazil': {'currency': 'BRL', 'symbol': 'R\$'},
    'Mexico': {'currency': 'MXN', 'symbol': '\$'},
    'Argentina': {'currency': 'ARS', 'symbol': '\$'},
    'Chile': {'currency': 'CLP', 'symbol': '\$'},
    'Colombia': {'currency': 'COP', 'symbol': '\$'},
    'Peru': {'currency': 'PEN', 'symbol': 'S/'},

    // Oceania
    'Australia': {'currency': 'AUD', 'symbol': 'A\$'},
    'New Zealand': {'currency': 'NZD', 'symbol': 'NZ\$'},

    // Other European
    'Switzerland': {'currency': 'CHF', 'symbol': 'CHF'},
    'Norway': {'currency': 'NOK', 'symbol': 'kr'},
    'Sweden': {'currency': 'SEK', 'symbol': 'kr'},
    'Denmark': {'currency': 'DKK', 'symbol': 'kr'},
    'Poland': {'currency': 'PLN', 'symbol': 'zł'},
    'Czech Republic': {'currency': 'CZK', 'symbol': 'Kč'},
    'Hungary': {'currency': 'HUF', 'symbol': 'Ft'},
    'Romania': {'currency': 'RON', 'symbol': 'lei'},
    'Bulgaria': {'currency': 'BGN', 'symbol': 'лв'},
    'Croatia': {'currency': 'HRK', 'symbol': 'kn'},
    'Russia': {'currency': 'RUB', 'symbol': '₽'},
    'Ukraine': {'currency': 'UAH', 'symbol': '₴'},

    // Additional countries
    'Bangladesh': {'currency': 'BDT', 'symbol': '৳'},
    'Pakistan': {'currency': 'PKR', 'symbol': '₨'},
    'Sri Lanka': {'currency': 'LKR', 'symbol': '₨'},
    'Nepal': {'currency': 'NPR', 'symbol': '₨'},
    'Myanmar': {'currency': 'MMK', 'symbol': 'K'},
    'Cambodia': {'currency': 'KHR', 'symbol': '៛'},
    'Laos': {'currency': 'LAK', 'symbol': '₭'},
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
