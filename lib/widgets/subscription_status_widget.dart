import 'package:flutter/material.dart';
import '../services/subscription_service_bypass.dart';
import '../services/revenuecat_service.dart';
import '../screens/subscription_plans_screen.dart';

class SubscriptionStatusWidget extends StatefulWidget {
  final String userId;
  final String token;

  const SubscriptionStatusWidget({
    Key? key,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<SubscriptionStatusWidget> createState() => _SubscriptionStatusWidgetState();
}

class _SubscriptionStatusWidgetState extends State<SubscriptionStatusWidget> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final RevenueCatService _revenueCatService = RevenueCatService();

  Map<String, dynamic>? _receiptLimitData;
  bool _isLoading = true;
  bool _isPremiumUser = false;

  @override
  void initState() {
    super.initState();
    _loadReceiptLimit();
  }

  Future<void> _loadReceiptLimit() async {
    try {
      // Initialize RevenueCat
      await _revenueCatService.initialize();

      // Check premium status from RevenueCat (source of truth)
      final isPremium = await _revenueCatService.isPremiumUser();

      // Get receipt limit data - FIXED: Use widget.userId instead of empty string
      final receiptLimit = await _subscriptionService.getReceiptLimit(
        token: widget.token,
        userId: widget.userId, // ✅ Fixed: was empty string before
      );

      setState(() {
        _isPremiumUser = isPremium;
        _receiptLimitData = receiptLimit;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading receipt limit: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
          ),
        ),
      );
    }

    if (_receiptLimitData == null) {
      return const SizedBox.shrink();
    }

    // If user is premium (from RevenueCat), show unlimited
    if (_isPremiumUser) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          children: [
            Icon(
              Icons.star,
              color: Colors.green.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium Active ✨',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'Unlimited receipts & all features',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Show usage for free users
    final currentCount = _receiptLimitData!['currentCount'] ?? 0;
    final limit = _receiptLimitData!['limit'] ?? 50;
    final isNearLimit = currentCount >= (limit * 0.8);
    final isAtLimit = currentCount >= limit;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAtLimit
            ? Colors.red.shade50
            : isNearLimit
            ? Colors.orange.shade50
            : const Color(0xFFE8E6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAtLimit
              ? Colors.red.shade300
              : isNearLimit
              ? Colors.orange.shade300
              : const Color(0xFF7E5EFD).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                color: isAtLimit
                    ? Colors.red.shade600
                    : isNearLimit
                    ? Colors.orange.shade600
                    : const Color(0xFF7E5EFD),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receipt Usage: $currentCount/$limit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isAtLimit
                            ? Colors.red.shade700
                            : isNearLimit
                            ? Colors.orange.shade700
                            : const Color(0xFF7E5EFD),
                      ),
                    ),
                    if (isAtLimit)
                      const Text(
                        'Limit reached! Upgrade to continue.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (isNearLimit)
                      const Text(
                        'Approaching limit. Consider upgrading.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubscriptionPlansScreen(
                        userId: widget.userId,
                        token: widget.token,
                      ),
                    ),
                  );
                },
                child: Text(
                  'Upgrade',
                  style: TextStyle(
                    color: isAtLimit
                        ? Colors.red.shade600
                        : const Color(0xFF7E5EFD),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: currentCount / limit,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              isAtLimit
                  ? Colors.red
                  : isNearLimit
                  ? Colors.orange
                  : const Color(0xFF7E5EFD),
            ),
          ),
        ],
      ),
    );
  }
}
