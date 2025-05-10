import 'package:flutter/material.dart';
import '../screens/receipt_details_screen.dart';

class ReceiptItem extends StatelessWidget {
  final Map<String, dynamic> receipt;

  const ReceiptItem({
    super.key,
    required this.receipt,
  });

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
              imageUrl: receipt['imageUrl'] ?? '', // Assuming receipt has 'imageUrl'
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
          child: Row(
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
                      receipt['store'] ?? 'Unknown Merchant',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '\$${receipt['amount'] ?? '0.00'}',
                      style: const TextStyle(
                        fontSize: 14,
                      ),
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
                    receipt['date'] ?? 'No date',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
