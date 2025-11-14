/// Models for Share Intent Receipt Processing

/// Process Receipt Response Model
class ProcessReceiptResponse {
  final bool success;
  final String message;
  final ReceiptDetails? receiptDetails;
  
  ProcessReceiptResponse({
    required this.success,
    required this.message,
    this.receiptDetails,
  });
  
  factory ProcessReceiptResponse.fromJson(Map<String, dynamic> json) {
    // The backend might return receiptDetails without an explicit success flag
    // If receiptDetails exists, consider it a success
    final hasReceiptDetails = json['receiptDetails'] != null;
    final explicitSuccess = json['success'] == true;
    final success = explicitSuccess || hasReceiptDetails;
    
    return ProcessReceiptResponse(
      success: success,
      message: json['message'] ?? (hasReceiptDetails ? 'OCR processed successfully' : ''),
      receiptDetails: json['receiptDetails'] != null 
          ? ReceiptDetails.fromJson(json['receiptDetails']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (receiptDetails != null) 'receiptDetails': receiptDetails!.toJson(),
    };
  }
}

/// Receipt Details Model
class ReceiptDetails {
  final String userId;
  final String merchant;
  final String amount;
  final String receiptDate;
  final String category;
  final String imageId;
  final String? imageUrl;
  final String? pdfUrl;
  final String tags;
  final String comments;
  final String? ocrCurrency;
  final String? userCurrency;
  final bool needsCurrencyConversion;
  final List<LineItem>? lineItems;
  final String? lineItemsStatus;
  final dynamic lineItemsPromise; // ⚠️ CRITICAL: This must be preserved!
  
  ReceiptDetails({
    required this.userId,
    required this.merchant,
    required this.amount,
    required this.receiptDate,
    required this.category,
    required this.imageId,
    this.imageUrl,
    this.pdfUrl,
    required this.tags,
    required this.comments,
    this.ocrCurrency,
    this.userCurrency,
    required this.needsCurrencyConversion,
    this.lineItems,
    this.lineItemsStatus,
    this.lineItemsPromise, // ⚠️ CRITICAL: Must be included
  });
  
  factory ReceiptDetails.fromJson(Map<String, dynamic> json) {
    return ReceiptDetails(
      userId: json['userId'] ?? '',
      merchant: json['merchant'] ?? '',
      amount: json['amount']?.toString() ?? '',
      receiptDate: json['receiptDate'] ?? '',
      category: json['category'] ?? '',
      imageId: json['imageId']?.toString() ?? '',
      imageUrl: json['imageUrl'],
      pdfUrl: json['pdfUrl'],
      tags: json['tags'] ?? '',
      comments: json['comments'] ?? '',
      ocrCurrency: json['ocrCurrency'],
      userCurrency: json['userCurrency'],
      needsCurrencyConversion: json['needsCurrencyConversion'] ?? false,
      lineItems: json['lineItems'] != null 
          ? (json['lineItems'] as List)
              .map((item) => LineItem.fromJson(item))
              .toList()
          : null,
      lineItemsStatus: json['lineItemsStatus'],
      lineItemsPromise: json['_lineItemsPromise'], // ⚠️ CRITICAL: Preserve this!
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'merchant': merchant,
      'amount': amount,
      'receiptDate': receiptDate,
      'category': category,
      'imageId': imageId,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (pdfUrl != null) 'pdfUrl': pdfUrl,
      'tags': tags,
      'comments': comments,
      if (ocrCurrency != null) 'ocrCurrency': ocrCurrency,
      if (userCurrency != null) 'userCurrency': userCurrency,
      'needsCurrencyConversion': needsCurrencyConversion,
      if (lineItems != null) 'lineItems': lineItems!.map((item) => item.toJson()).toList(),
      if (lineItemsStatus != null) 'lineItemsStatus': lineItemsStatus,
      if (lineItemsPromise != null) '_lineItemsPromise': lineItemsPromise, // ⚠️ CRITICAL: Must be included!
    };
  }
}

/// Line Item Model
class LineItem {
  final int page;
  final String? merchant;
  final String? category;
  final String? description;
  final String amount;
  
  LineItem({
    required this.page,
    this.merchant,
    this.category,
    this.description,
    required this.amount,
  });
  
  factory LineItem.fromJson(Map<String, dynamic> json) {
    return LineItem(
      page: json['page'] ?? 0,
      merchant: json['merchant'],
      category: json['category'],
      description: json['description'],
      amount: json['amount'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'page': page,
      if (merchant != null) 'merchant': merchant,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      'amount': amount,
    };
  }
}

/// Save Receipt Response Model
class SaveReceiptResponse {
  final bool success;
  final String message;
  final String? receiptId;
  
  SaveReceiptResponse({
    required this.success,
    required this.message,
    this.receiptId,
  });
  
  factory SaveReceiptResponse.fromJson(Map<String, dynamic> json) {
    // Check if the response indicates success based on the actual API response structure
    final hasSuccessMessage = json['message']?.toString().toLowerCase().contains('success') ?? false;
    final hasReceipt = json['receipt'] != null;
    final hasReceiptDetails = json['receiptDetails'] != null;
    final success = hasSuccessMessage || hasReceipt || hasReceiptDetails;
    
    // Try multiple possible locations for receipt ID
    String? extractedReceiptId;
    
    // Option 1: receipt.id
    if (json['receipt']?['id'] != null) {
      extractedReceiptId = json['receipt']['id'].toString();
    }
    // Option 2: receiptDetails.id
    else if (json['receiptDetails']?['id'] != null) {
      extractedReceiptId = json['receiptDetails']['id'].toString();
    }
    // Option 3: receiptId at root
    else if (json['receiptId'] != null) {
      extractedReceiptId = json['receiptId'].toString();
    }
    // Option 4: id at root
    else if (json['id'] != null) {
      extractedReceiptId = json['id'].toString();
    }
    
    return SaveReceiptResponse(
      success: success,
      message: json['message'] ?? '',
      receiptId: extractedReceiptId,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (receiptId != null) 'receiptId': receiptId,
    };
  }
}

/// Share Intent Processing Status
enum ShareIntentStatus {
  idle,
  uploading,
  processing,
  saving,
  completed,
  error,
}

/// Share Intent Processing Result
class ShareIntentResult {
  final ShareIntentStatus status;
  final String? message;
  final String? receiptId;
  final String? error;
  final ReceiptDetails? receiptDetails; // For preview mode
  
  ShareIntentResult({
    required this.status,
    this.message,
    this.receiptId,
    this.error,
    this.receiptDetails,
  });
  
  factory ShareIntentResult.success({String? message, String? receiptId}) {
    return ShareIntentResult(
      status: ShareIntentStatus.completed,
      message: message ?? 'Receipt processed successfully',
      receiptId: receiptId,
    );
  }
  
  factory ShareIntentResult.error(String error) {
    return ShareIntentResult(
      status: ShareIntentStatus.error,
      error: error,
    );
  }
  
  factory ShareIntentResult.processing(ShareIntentStatus status, {String? message}) {
    return ShareIntentResult(
      status: status,
      message: message,
    );
  }
  
  factory ShareIntentResult.preview({required ReceiptDetails receiptDetails}) {
    return ShareIntentResult(
      status: ShareIntentStatus.completed,
      message: 'Receipt processed - ready for review',
      receiptDetails: receiptDetails,
    );
  }
}
