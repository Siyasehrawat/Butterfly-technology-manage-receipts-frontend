import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:crypto/crypto.dart';

/// Encryption/Decryption Helper for Cloudinary URLs
/// 
/// This utility provides AES encryption/decryption functionality
/// for securing Cloudinary URLs in the database.
/// Supports CryptoJS format (used by Node.js backend)
class EncryptionHelper {
  // Get encryption key from environment variables (hex string)
  static final String _encryptionKeyHex = dotenv.env['ENCRYPTION_KEY'] ?? '';
  
  /// Decrypt Cloudinary URL from backend response
  /// 
  /// Returns decrypted URL or null if decryption fails
  /// 
  /// Handles:
  /// - Null or empty strings
  /// - Special values like 'manual_receipt'
  /// - Already plain URLs (backward compatibility)
  /// - CryptoJS encrypted base64 strings (with "Salted__" prefix)
  static String? decryptUrl(String? encryptedUrl) {
    // Handle null or empty
    if (encryptedUrl == null || encryptedUrl.isEmpty) {
      return null;
    }
    
    // Handle special values
    if (encryptedUrl == 'manual_receipt') {
      return null;
    }
    
    // Backward compatibility - if already plain URL, return as is
    if (encryptedUrl.startsWith('http://') || 
        encryptedUrl.startsWith('https://')) {
      return encryptedUrl;
    }
    
    try {
      // Decode base64 to get encrypted bytes
      final encryptedBytes = base64.decode(encryptedUrl);
      
      // Check if it's CryptoJS format (starts with "Salted__")
      if (encryptedBytes.length >= 16 && 
          String.fromCharCodes(encryptedBytes.sublist(0, 8)) == 'Salted__') {
        return _decryptCryptoJS(encryptedBytes);
      }
      
      // Fallback to direct decryption for backward compatibility
      return _decryptDirect(encryptedUrl);
    } catch (e) {
      print('❌ Decryption error: $e');
      print('Encrypted value: $encryptedUrl');
      return null;
    }
  }
  
  /// Decrypt CryptoJS format (with salt)
  static String? _decryptCryptoJS(Uint8List encryptedData) {
    try {
      // Extract salt (bytes 8-15)
      final salt = encryptedData.sublist(8, 16);
      
      // Extract encrypted content (from byte 16 onwards)
      final ciphertext = encryptedData.sublist(16);
      
      // CryptoJS uses the encryption key as a UTF-8 passphrase, not as hex bytes
      // Convert the passphrase string to bytes
      final passphraseBytes = utf8.encode(_encryptionKeyHex);
      
      // Derive key and IV using EVP_BytesToKey (CryptoJS compatible)
      final derived = _evpBytesToKey(passphraseBytes, salt, keyLength: 32, ivLength: 16);
      
      // Create encrypter with derived key and IV
      final key = encrypt.Key(derived['key']!);
      final iv = encrypt.IV(derived['iv']!);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      
      // Decrypt
      final encrypted = encrypt.Encrypted(ciphertext);
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      
      if (decrypted.isEmpty) {
        print('⚠️ Decryption returned empty string');
        return null;
      }
      
      print('✅ CryptoJS decryption successful');
      return decrypted;
    } catch (e) {
      print('❌ CryptoJS decryption error: $e');
      return null;
    }
  }
  
  /// Direct decryption (backward compatibility)
  static String? _decryptDirect(String encryptedUrl) {
    try {
      final keyBytes = _hexToBytes(_encryptionKeyHex);
      if (keyBytes.length != 32) {
        print('❌ Key must be 32 bytes (256 bits), got ${keyBytes.length} bytes');
        return null;
      }
      
      final key = encrypt.Key(keyBytes);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      
      final encrypted = encrypt.Encrypted.fromBase64(encryptedUrl);
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      
      if (decrypted.isEmpty) {
        print('⚠️ Decryption returned empty string');
        return null;
      }
      
      return decrypted;
    } catch (e) {
      print('❌ Direct decryption error: $e');
      return null;
    }
  }
  
  /// Convert hex string to bytes
  static Uint8List _hexToBytes(String hex) {
    if (hex.isEmpty) return Uint8List(0);
    
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
  
  /// EVP_BytesToKey implementation (CryptoJS compatible)
  /// This derives a key and IV from a password and salt
  static Map<String, Uint8List> _evpBytesToKey(
    Uint8List password,
    Uint8List salt, {
    required int keyLength,
    required int ivLength,
    int iterations = 1,
  }) {
    final targetLength = keyLength + ivLength;
    final derivedBytes = <int>[];
    Uint8List? lastHash;
    
    while (derivedBytes.length < targetLength) {
      final hashData = <int>[];
      if (lastHash != null) {
        hashData.addAll(lastHash);
      }
      hashData.addAll(password);
      hashData.addAll(salt);
      
      var hash = md5.convert(hashData).bytes;
      
      for (int i = 1; i < iterations; i++) {
        hash = md5.convert(hash).bytes;
      }
      
      lastHash = Uint8List.fromList(hash);
      derivedBytes.addAll(hash);
    }
    
    return {
      'key': Uint8List.fromList(derivedBytes.sublist(0, keyLength)),
      'iv': Uint8List.fromList(derivedBytes.sublist(keyLength, keyLength + ivLength)),
    };
  }
  
  /// Decrypt multiple URLs at once
  /// 
  /// Useful for batch processing receipts
  static List<String?> decryptUrls(List<String?> encryptedUrls) {
    return encryptedUrls.map((url) => decryptUrl(url)).toList();
  }
  
  /// Encrypt URL (if needed for sending to backend)
  /// 
  /// Note: Currently backend expects plain URLs for OCR processing
  /// This is mainly for testing purposes
  static String? encryptUrl(String? plainUrl) {
    if (plainUrl == null || plainUrl.isEmpty) {
      return null;
    }
    
    try {
      final keyBytes = _hexToBytes(_encryptionKeyHex);
      if (keyBytes.length != 32) {
        print('❌ Key must be 32 bytes (256 bits), got ${keyBytes.length} bytes');
        return null;
      }
      
      final key = encrypt.Key(keyBytes);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      
      final encrypted = encrypter.encrypt(plainUrl, iv: iv);
      return encrypted.base64;
    } catch (e) {
      print('❌ Encryption error: $e');
      return null;
    }
  }
  
  /// Validate if encryption key is properly configured
  static bool isKeyConfigured() {
    final keyBytes = _hexToBytes(_encryptionKeyHex);
    return _encryptionKeyHex.isNotEmpty && keyBytes.length == 32;
  }
  
  /// Get encryption status for debugging
  static String getEncryptionStatus() {
    if (!isKeyConfigured()) {
      final keyBytes = _hexToBytes(_encryptionKeyHex);
      return '❌ Encryption key not configured properly (expected 32 bytes, got ${keyBytes.length} bytes)';
    }
    return '✅ Encryption configured with 32-byte (256-bit) key';
  }
}

