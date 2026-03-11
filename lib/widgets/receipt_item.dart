import 'package:flutter/material.dart';
import '../screens/receipt_details_screen.dart';
import '../widgets/duplicate_receipt_badge.dart';
import '../models/receipt_models.dart';

class ReceiptItem extends StatelessWidget {
  final Map<String, dynamic> receipt;

  const ReceiptItem({
    super.key,
    required this.receipt,
  });

  double _parseAmount(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    final str = raw.toString();
    final cleaned = str.replaceAll(RegExp(r'[^0-9.\\-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  bool _hasDuplicateInfo(Map<String, dynamic> receipt) {
    // Check if receipt has duplicate information
    if (receipt['duplicateReceipts'] != null && receipt['duplicateReceipts'] is List) {
      final duplicates = receipt['duplicateReceipts'] as List;
      return duplicates.isNotEmpty;
    }
    return false;
  }

  List<DuplicateReceipt> _extractDuplicateReceipts(Map<String, dynamic> receipt) {
    if (receipt['duplicateReceipts'] != null && receipt['duplicateReceipts'] is List) {
      return (receipt['duplicateReceipts'] as List)
          .map((item) => DuplicateReceipt.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  void _showDuplicateDialog(BuildContext context, Map<String, dynamic> receipt) {
    final duplicates = _extractDuplicateReceipts(receipt);
    if (duplicates.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => DuplicateReceiptDialog(
        duplicateReceipts: duplicates,
        onViewReceipt: (receiptId) {
          // Navigate to receipt details if needed
          // This would require receipt ID mapping
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extract userId and imageId from the receipt object (make sure these exist in the receipt)
    final userId = receipt['userId']; // Replace with your logic to get userId
    final imageId = receipt['imageId']; // Replace with your logic to get imageId

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptDetailsScreen(
              receipt: receipt,
              imageUrl: receipt['decryptedImageLink'] ?? receipt['decryptedImageUrl'] ?? receipt['imageUrl'] ?? receipt['imageLink'] ?? '', // Use decrypted URL
              userId: userId, // Pass the userId here
              imageId: imageId, // Pass the imageId here
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0E6FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Receipt thumbnail
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.receipt, color: Color(0xFF7E5EFD)),
                  ),
                  const SizedBox(width: 12),

                  // Receipt details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt['merchant'] ?? 'Unknown Merchant',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${receipt['amount'] ?? '0.00'}',
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                            // Show Price Breakup button if line items exist
                            if (receipt['lineItems'] != null && (receipt['lineItems'] as List).isNotEmpty) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  _showPriceBreakupDialog(context, receipt);
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Receipt Details',
                                      style: TextStyle(
                                        color: Color(0xFF7E5EFD),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Container(
                                      height: 1,
                                      width: 30,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7E5EFD),
                                        borderRadius: BorderRadius.circular(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Category and date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        receipt['category'] ?? 'Uncategorized',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        receipt['receiptDate'] ?? 'No date',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Duplicate badge if duplicates exist
              if (_hasDuplicateInfo(receipt))
                DuplicateReceiptBadge(
                  duplicateReceipts: _extractDuplicateReceipts(receipt),
                  onResolve: () {
                    _showDuplicateDialog(context, receipt);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPriceBreakupDialog(BuildContext context, Map<String, dynamic> receipt) {
    final lineItems = receipt['lineItems'] as List<dynamic>? ?? [];
    
    if (lineItems.isEmpty) return;

    // Prefer currency symbol from line items amount string (e.g., "$6.00").
    // Fallback to '$' if not present.
    String currencySymbol = (() {
      try {
        final firstAmount = lineItems.first['amount']?.toString() ?? '';
        final match = RegExp(r"^[^0-9\-.,]+").firstMatch(firstAmount.trim());
        final symbol = match?.group(0)?.trim();
        if (symbol != null && symbol.isNotEmpty) return symbol;
      } catch (_) {}
      return '4';
    })();

    if (currencySymbol == '\u00024') {
      currencySymbol = '4';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 520, 
            minHeight: 200, 
            maxHeight: 600
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF7E5EFD),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                width: double.infinity,
                child: const Text(
                  'Receipt Details',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 450),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Only show actual line items from response
                        ...List.generate(lineItems.length, (index) {
                          final item = lineItems[index];
                          final description = item['description']?.toString() ?? 'Item';
                          final merchant = item['merchant']?.toString() ?? '';
                          final amount = _parseAmount(item['amount']); // Defaults to 0.0 if null
                          final quantity = item['quantity']?.toString() ?? '1';
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      description, 
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                                    ),
                                  ),
                                  Text('$currencySymbol${amount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              if (merchant.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    merchant, 
                                    style: TextStyle(color: Colors.grey.shade600)
                                  ),
                                ),
                              if (index != lineItems.length - 1) const Divider(),
                            ],
                          );
                        }),
                        const SizedBox(height: 8),
                        const Divider(thickness: 1.5),
                        const SizedBox(height: 4),
                        Builder(builder: (context) {
                          final total = lineItems.fold<double>(0.0, (sum, e) => sum + _parseAmount(e['amount']));
                          
                          return _buildSummaryRow('Total', '$currencySymbol${total.toStringAsFixed(2)}', isBold: true);
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close', 
                      style: TextStyle(color: Color(0xFF7E5EFD), fontWeight: FontWeight.w600)
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? const Color(0xFF7E5EFD) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
