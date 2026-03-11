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

/// Duplicate Receipt Model
class DuplicateReceipt {
  final int id;
  final String merchant;
  final double amount;
  final String receiptDate;
  
  DuplicateReceipt({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.receiptDate,
  });
  
  factory DuplicateReceipt.fromJson(Map<String, dynamic> json) {
    return DuplicateReceipt(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      merchant: json['merchant']?.toString() ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : double.tryParse(json['amount'].toString()) ?? 0.0,
      receiptDate: json['receiptDate']?.toString() ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant': merchant,
      'amount': amount,
      'receiptDate': receiptDate,
    };
  }
}

/// Save Receipt Response Model
class SaveReceiptResponse {
  final bool success;
  final String message;
  final String? receiptId;
  final int? pointsAwarded;
  final String? warning;
  final List<DuplicateReceipt>? duplicateReceipts;
  
  SaveReceiptResponse({
    required this.success,
    required this.message,
    this.receiptId,
    this.pointsAwarded,
    this.warning,
    this.duplicateReceipts,
  });
  
  bool get hasDuplicates => warning != null && duplicateReceipts != null && duplicateReceipts!.isNotEmpty;
  
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
    
    // Extract duplicate information
    String? warning;
    List<DuplicateReceipt>? duplicateReceipts;
    
    if (json['warning'] != null) {
      warning = json['warning'].toString();
    }
    
    if (json['duplicateReceipts'] != null && json['duplicateReceipts'] is List) {
      duplicateReceipts = (json['duplicateReceipts'] as List)
          .map((item) => DuplicateReceipt.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    
    return SaveReceiptResponse(
      success: success,
      message: json['message'] ?? '',
      receiptId: extractedReceiptId,
      pointsAwarded: _extractPointsAwarded(json),
      warning: warning,
      duplicateReceipts: duplicateReceipts,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (receiptId != null) 'receiptId': receiptId,
      if (pointsAwarded != null) 'pointsAwarded': pointsAwarded,
      if (warning != null) 'warning': warning,
      if (duplicateReceipts != null) 'duplicateReceipts': duplicateReceipts!.map((d) => d.toJson()).toList(),
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

int? _extractPointsAwarded(Map<String, dynamic> source) {
  const possibleKeys = [
    'pointsAwarded',
    'points_awarded',
    'mrBucksAwarded',
    'mr_bucks_awarded',
    'points',
    'pointsEarned',
  ];

  for (final key in possibleKeys) {
    if (source.containsKey(key)) {
      final parsed = _parsePointsValue(source[key]);
      if (parsed != null) return parsed;
    }
  }

  for (final key in ['data', 'result', 'payload', 'receipt', 'receiptDetails']) {
    final nested = source[key];
    if (nested is Map<String, dynamic>) {
      final nestedPoints = _extractPointsAwarded(nested);
      if (nestedPoints != null) return nestedPoints;
    }
  }

  return null;
}

int? _parsePointsValue(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}
