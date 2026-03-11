/// Utility functions for country-based feature checks
class CountryUtils {
  /// Check if the user's country is India
  /// Supports various formats: "India", "india", "IN", etc.
  static bool isIndia(String? country) {
    if (country == null || country.isEmpty) {
      return false;
    }
    
    final countryLower = country.toLowerCase().trim();
    
    // Check for common India identifiers
    return countryLower == 'india' ||
        countryLower == 'in' ||
        countryLower.contains('india');
  }
  
  /// Check if a feature should be hidden for Indian users
  /// Returns true if the feature should be hidden (user is from India)
  static bool shouldHideFeatureForIndia(String? country) {
    return isIndia(country);
  }
}
