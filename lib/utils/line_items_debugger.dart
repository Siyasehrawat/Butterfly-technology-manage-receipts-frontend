import '../models/receipt_models.dart';

/// Line Items Debugger Utility
/// 
/// This utility provides comprehensive debugging and logging for line items processing
/// to help track the flow from OCR response to save request.
class LineItemsDebugger {
  static const String _prefix = '🔍 [LineItemsDebugger]';
  
  /// Debug OCR response for line items information
  static void debugOcrResponse(Map<String, dynamic> response) {
    print('$_prefix OCR Response Analysis:');
    print('$_prefix ==========================================');
    
    if (response['success'] == true) {
      print('$_prefix ✅ OCR processing successful');
    } else {
      print('$_prefix ❌ OCR processing failed: ${response['message']}');
      return;
    }
    
    if (response['receiptDetails'] != null) {
      final receiptDetails = response['receiptDetails'];
      _debugReceiptDetails(receiptDetails, 'OCR Response');
    } else {
      print('$_prefix ⚠️ No receipt details in OCR response');
    }
    
    print('$_prefix ==========================================');
  }
  
  /// Debug save request payload for line items information
  static void debugSaveRequest(Map<String, dynamic> payload) {
    print('$_prefix Save Request Analysis:');
    print('$_prefix ==========================================');
    
    // Check if _lineItemsPromise is present
    if (payload.containsKey('_lineItemsPromise')) {
      print('$_prefix ✅ _lineItemsPromise found in save request');
      print('$_prefix 🔍 Promise type: ${payload['_lineItemsPromise'].runtimeType}');
      print('$_prefix 🔍 Promise value: ${payload['_lineItemsPromise']}');
    } else {
      print('$_prefix ❌ _lineItemsPromise MISSING from save request');
    }
    
    // Check line items status
    if (payload.containsKey('lineItemsStatus')) {
      print('$_prefix 🔍 Line items status: ${payload['lineItemsStatus']}');
    }
    
    // Check line items array
    if (payload.containsKey('lineItems')) {
      final lineItems = payload['lineItems'];
      if (lineItems != null) {
        print('$_prefix 🔍 Line items count: ${lineItems.length}');
        if (lineItems.isNotEmpty) {
          print('$_prefix 🔍 First line item: ${lineItems[0]}');
        }
      } else {
        print('$_prefix ⚠️ Line items is null');
      }
    }
    
    // Check other important fields
    _debugReceiptDetails(payload, 'Save Request');
    
    print('$_prefix ==========================================');
  }
  
  /// Debug receipt details object
  static void _debugReceiptDetails(Map<String, dynamic> receiptDetails, String source) {
    print('$_prefix $source Receipt Details:');
    print('$_prefix   - Merchant: ${receiptDetails['merchant'] ?? 'N/A'}');
    print('$_prefix   - Amount: ${receiptDetails['amount'] ?? 'N/A'}');
    print('$_prefix   - Category: ${receiptDetails['category'] ?? 'N/A'}');
    print('$_prefix   - Image ID: ${receiptDetails['imageId'] ?? 'N/A'}');
    print('$_prefix   - User ID: ${receiptDetails['userId'] ?? 'N/A'}');
    
    // Line items specific fields
    if (receiptDetails.containsKey('lineItemsStatus')) {
      print('$_prefix   - Line items status: ${receiptDetails['lineItemsStatus']}');
    }
    
    if (receiptDetails.containsKey('lineItems')) {
      final lineItems = receiptDetails['lineItems'];
      if (lineItems != null) {
        print('$_prefix   - Line items count: ${lineItems.length}');
      } else {
        print('$_prefix   - Line items: null');
      }
    }
    
    if (receiptDetails.containsKey('_lineItemsPromise')) {
      final promise = receiptDetails['_lineItemsPromise'];
      if (promise != null) {
        print('$_prefix   - _lineItemsPromise: present (${promise.runtimeType})');
      } else {
        print('$_prefix   - _lineItemsPromise: null');
      }
    }
  }
  
  /// Debug ReceiptDetails object
  static void debugReceiptDetails(ReceiptDetails receiptDetails, String source) {
    print('$_prefix $source ReceiptDetails Object:');
    print('$_prefix ==========================================');
    print('$_prefix   - Merchant: ${receiptDetails.merchant}');
    print('$_prefix   - Amount: ${receiptDetails.amount}');
    print('$_prefix   - Category: ${receiptDetails.category}');
    print('$_prefix   - Image ID: ${receiptDetails.imageId}');
    print('$_prefix   - User ID: ${receiptDetails.userId}');
    print('$_prefix   - Line items status: ${receiptDetails.lineItemsStatus ?? 'N/A'}');
    print('$_prefix   - Line items count: ${receiptDetails.lineItems?.length ?? 0}');
    print('$_prefix   - Has line items promise: ${receiptDetails.lineItemsPromise != null}');
    
    if (receiptDetails.lineItemsPromise != null) {
      print('$_prefix   - Promise type: ${receiptDetails.lineItemsPromise.runtimeType}');
    }
    
    if (receiptDetails.lineItems != null && receiptDetails.lineItems!.isNotEmpty) {
      print('$_prefix   - First line item: ${receiptDetails.lineItems!.first.toJson()}');
    }
    
    print('$_prefix ==========================================');
  }
  
  /// Debug save response
  static void debugSaveResponse(SaveReceiptResponse response) {
    print('$_prefix Save Response Analysis:');
    print('$_prefix ==========================================');
    
    if (response.success) {
      print('$_prefix ✅ Receipt saved successfully');
      print('$_prefix 📄 Receipt ID: ${response.receiptId ?? 'N/A'}');
      print('$_prefix 📝 Message: ${response.message}');
      if (response.pointsAwarded != null) {
        print('$_prefix 🪙 Points awarded: ${response.pointsAwarded}');
      }
    } else {
      print('$_prefix ❌ Receipt save failed');
      print('$_prefix 📝 Error: ${response.message}');
    }
    
    print('$_prefix ==========================================');
  }
  
  /// Debug complete flow from OCR to save
  static void debugCompleteFlow({
    required Map<String, dynamic> ocrResponse,
    required Map<String, dynamic> savePayload,
    required SaveReceiptResponse saveResponse,
  }) {
    print('$_prefix Complete Flow Analysis:');
    print('$_prefix ==========================================');
    
    // OCR Response
    debugOcrResponse(ocrResponse);
    
    // Save Request
    debugSaveRequest(savePayload);
    
    // Save Response
    debugSaveResponse(saveResponse);
    
    // Summary
    print('$_prefix Summary:');
    final hasOcrPromise = ocrResponse['receiptDetails']?['_lineItemsPromise'] != null;
    final hasSavePromise = savePayload.containsKey('_lineItemsPromise');
    final saveSuccess = saveResponse.success;
    
    print('$_prefix   - OCR has _lineItemsPromise: ${hasOcrPromise ? '✅' : '❌'}');
    print('$_prefix   - Save includes _lineItemsPromise: ${hasSavePromise ? '✅' : '❌'}');
    print('$_prefix   - Save successful: ${saveSuccess ? '✅' : '❌'}');
    
    if (hasOcrPromise && hasSavePromise && saveSuccess) {
      print('$_prefix 🎉 Line items flow is working correctly!');
    } else {
      print('$_prefix ⚠️ Line items flow has issues - check the details above');
    }
    
    print('$_prefix ==========================================');
  }
  
  /// Create a test payload for debugging
  static Map<String, dynamic> createTestPayload() {
    return {
      'userId': 'test-user-123',
      'merchant': 'Test Store',
      'amount': '25.50',
      'receiptDate': DateTime.now().toIso8601String(),
      'category': 'Food & Dining',
      'imageId': 'test-image-456',
      'imageUrl': 'https://example.com/test-image.jpg',
      'tags': 'test,debug',
      'comments': 'Test receipt for debugging',
      'needsCurrencyConversion': false,
      'lineItemsStatus': 'processing',
      'lineItems': [
        {
          'page': 1,
          'merchant': 'Test Store',
          'category': 'Food & Dining',
          'description': 'Test item 1',
          'amount': '15.50',
        },
        {
          'page': 1,
          'merchant': 'Test Store',
          'category': 'Food & Dining',
          'description': 'Test item 2',
          'amount': '10.00',
        },
      ],
      '_lineItemsPromise': {
        'id': 'test-promise-789',
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      },
    };
  }
  
  /// Test the debugger with sample data
  static void runTest() {
    print('$_prefix Running Line Items Debugger Test...');
    
    // Create test OCR response
    final ocrResponse = {
      'success': true,
      'message': 'OCR processing completed',
      'receiptDetails': createTestPayload(),
    };
    
    // Create test save payload
    final savePayload = Map<String, dynamic>.from(createTestPayload());
    
    // Create test save response
    final saveResponse = SaveReceiptResponse(
      success: true,
      message: 'Receipt saved successfully',
      receiptId: 'test-receipt-123',
    );
    
    // Run complete flow debug
    debugCompleteFlow(
      ocrResponse: ocrResponse,
      savePayload: savePayload,
      saveResponse: saveResponse,
    );
  }
}


