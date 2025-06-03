import 'package:flutter/foundation.dart';
import '../services/receipts_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ReceiptProvider with ChangeNotifier {
  final ReceiptService _receiptService;

  ReceiptProvider() : _receiptService = ReceiptService(userId: '');

  void initializeReceiptService(String userId) {
    _userId = userId;
    _receiptService.setUserId(userId);
    notifyListeners();
  }


  List<Map<String, dynamic>> _receipts = [];
  Map<String, dynamic>? _currentReceipt;
  final Map<String, dynamic> _filters = {};
  bool _isLoading = false;
  String _errorMessage = '';
  String _userId = '';

  // Getters
  List<Map<String, dynamic>> get receipts => _receipts;
  Map<String, dynamic>? get currentReceipt => _currentReceipt;
  Map<String, dynamic> get filters => _filters;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get userId => _userId;

  // Set user ID
  void setUserId(String userId) {
    _userId = userId;
    notifyListeners();
  }

  // Fetch receipts with optional filters
  Future<void> fetchReceipts() async {
    if (_userId.isEmpty) {
      _errorMessage = 'User ID is not set';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _receipts = await _receiptService.getReceipts(
        userId: _userId,
        merchant: _filters['merchant'],
        category: _filters['category'],
        categoryId: _filters['categoryId'],
        fromDate: _filters['fromDate'],
        toDate: _filters['toDate'],
        minAmount: _filters['minAmount'],
        maxAmount: _filters['maxAmount'],
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load receipts: $e';
      notifyListeners();
    }
  }

  // Set current receipt
  void setCurrentReceipt(Map<String, dynamic> receipt) {
    _currentReceipt = receipt;
    notifyListeners();
  }

  // Update filter
  void updateFilter(String key, dynamic value) {
    filters[key] = value;
    notifyListeners();
  }

  void clearFilters() {
    _filters.clear();
    notifyListeners();
  }

  // Save receipt details
  Future<bool> saveReceiptDetails(Map<String, dynamic> receiptData) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final success = await _receiptService.saveReceiptDetails(receiptData);
      _isLoading = false;
      if (success) {
        await fetchReceipts(); // Refresh the list
      } else {
        _errorMessage = 'Failed to save receipt details';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error saving receipt details: $e';
      notifyListeners();
      return false;
    }
  }

  // Update receipt field
  Future<bool> updateReceiptField(
      String receiptId, String field, dynamic value) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final success =
      await _receiptService.updateReceiptField(receiptId, field, value);
      _isLoading = false;
      if (success &&
          _currentReceipt != null &&
          _currentReceipt!['id'] == receiptId) {
        _currentReceipt![field] = value;
      }
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error updating receipt field: $e';
      notifyListeners();
      return false;
    }
  }

  // Delete receipt
  Future<bool> deleteReceipt(String receiptId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Use the correct delete route
      final success = await _receiptService.deleteReceipt(receiptId);
      _isLoading = false;

      if (success) {
        // Remove the deleted receipt from the local list
        _receipts.removeWhere((receipt) => receipt['id'] == receiptId);

        // Clear the current receipt if it matches the deleted one
        if (_currentReceipt != null && _currentReceipt!['id'] == receiptId) {
          _currentReceipt = null;
        }
      } else {
        _errorMessage = 'Failed to delete receipt';
      }

      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error deleting receipt: $e';
      notifyListeners();
      return false;
    }
  }

  // Get categories
  Future<List<String>> getCategories() async {
    return await _receiptService.getCategories();
  }

  // Get merchants
  Future<List<String>> getMerchants() async {
    return await _receiptService.getMerchants();
  }

  // Upload and process receipt image
  Future<Map<String, dynamic>?> uploadAndProcessReceipt(
      ImageSource source) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile == null) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final imageFile = kIsWeb ? pickedFile : File(pickedFile.path);
      final imageUrl = await _receiptService.uploadImageToCloudinary(imageFile);

      if (imageUrl == null) {
        _isLoading = false;
        _errorMessage = 'Failed to upload image';
        notifyListeners();
        return null;
      }

      final receiptData =
      await _receiptService.processReceiptImage(imageUrl, _userId);
      _isLoading = false;

      if (receiptData != null) {
        await fetchReceipts(); // Refresh the list
      } else {
        _errorMessage = 'Failed to process receipt';
      }

      notifyListeners();
      return receiptData;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error processing receipt: $e';
      notifyListeners();
      return null;
    }
  }
}