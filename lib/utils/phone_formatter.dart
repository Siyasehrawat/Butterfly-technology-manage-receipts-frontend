import 'package:flutter/services.dart';

/// Phone number formatter for E.164 format
/// Ensures phone numbers are formatted correctly as user types
class PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    
    // Remove all non-digit characters except +
    text = text.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Ensure it starts with +
    if (text.isNotEmpty && !text.startsWith('+')) {
      text = '+$text';
    }
    
    // Limit to 15 digits after + (E.164 max length is 15 digits)
    if (text.length > 1) {
      final digits = text.substring(1);
      if (digits.length > 15) {
        text = '+${digits.substring(0, 15)}';
      }
    }
    
    // Ensure country code starts with 1-9 (not 0)
    if (text.length > 1 && text[1] == '0') {
      return oldValue; // Don't allow 0 as first digit after +
    }
    
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
  
  /// Normalize phone number to E.164 format
  /// Removes spaces, dashes, parentheses, etc.
  static String normalizePhone(String phone) {
    // Remove all non-digit characters except +
    String normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Ensure it starts with +
    if (normalized.isNotEmpty && !normalized.startsWith('+')) {
      normalized = '+$normalized';
    }
    
    return normalized;
  }
  
  /// Validate E.164 format
  static bool isValidE164(String phone) {
    // E.164 format: + followed by 1-15 digits, first digit must be 1-9
    final e164Regex = RegExp(r'^\+[1-9]\d{1,14}$');
    return e164Regex.hasMatch(phone);
  }
}











