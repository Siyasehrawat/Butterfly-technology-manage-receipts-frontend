import 'receipt_models.dart';

class ReceiptSaveResult {
  final bool saved;
  final int? pointsAwarded;
  final String? duplicateWarning;
  final List<DuplicateReceipt>? duplicateReceipts;

  const ReceiptSaveResult({
    required this.saved,
    this.pointsAwarded,
    this.duplicateWarning,
    this.duplicateReceipts,
  });

  bool get hasPoints => (pointsAwarded ?? 0) > 0;
  bool get hasDuplicates => duplicateWarning != null && duplicateReceipts != null && duplicateReceipts!.isNotEmpty;

  static ReceiptSaveResult? maybeFrom(dynamic result) {
    if (result is ReceiptSaveResult) {
      return result;
    }

    if (result == true) {
      return const ReceiptSaveResult(saved: true);
    }

    if (result is Map) {
      final dynamic savedValue = result['saved'];
      final bool didSave = savedValue == null ? false : savedValue == true;
      if (!didSave) return null;

      // Extract duplicate information
      String? duplicateWarning;
      List<DuplicateReceipt>? duplicateReceipts;
      
      if (result['duplicateWarning'] != null) {
        duplicateWarning = result['duplicateWarning'].toString();
      }
      
      if (result['duplicateReceipts'] != null && result['duplicateReceipts'] is List) {
        duplicateReceipts = (result['duplicateReceipts'] as List)
            .map((item) => DuplicateReceipt.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      return ReceiptSaveResult(
        saved: true,
        pointsAwarded: parsePoints(result['pointsAwarded'] ?? result['points_awarded']),
        duplicateWarning: duplicateWarning,
        duplicateReceipts: duplicateReceipts,
      );
    }

    return null;
  }

  static int? parsePoints(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

