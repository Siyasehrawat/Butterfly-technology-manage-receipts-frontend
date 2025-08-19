import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service_bypass.dart';
import '../services/revenuecat_service.dart';
import '../providers/user_provider.dart';
import '../providers/setting_provider.dart';
import '../widgets/curved_background.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  final String userId;
  final String token;

  const SubscriptionPlansScreen({
    Key? key,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final RevenueCatService _revenueCatService = RevenueCatService();

  bool _isLoading = true;
  bool _isUpgrading = false;
  String _selectedBillingCycle = 'monthly';

  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _currentSubscription;
  bool _isPremiumUser = false;
  bool _isSandbox = false;

  // Separate premium and free plans
  Map<String, dynamic>? _premiumPlan;
  Map<String, dynamic>? _freePlan;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      debugPrint('Initializing RevenueCat...');
      final initialized = await _revenueCatService.initialize();

      if (!initialized) {
        debugPrint('❌ RevenueCat initialization failed');
        _showErrorDialog('RevenueCat initialization failed. Please check your setup.');
        return;
      }

      _isSandbox = await _revenueCatService.isSandboxEnvironment();
      debugPrint('Environment: ${_isSandbox ? 'SANDBOX' : 'PRODUCTION'}');

      if (kDebugMode) {
        await _revenueCatService.debugProductConfiguration();
      }

      await _loadData();
    } catch (e) {
      debugPrint('Service initialization error: $e');
      _showErrorDialog('Failed to initialize services: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final plans = await _subscriptionService.getSubscriptionPlans();

      final currentSubscription = await _subscriptionService.getCurrentSubscription(
        token: widget.token,
        userId: widget.userId,
      );

      final isPremiumFromRevenueCat = await _revenueCatService.isPremiumUser();

      // Separate plans by type
      Map<String, dynamic>? premiumPlan;
      Map<String, dynamic>? freePlan;

      for (var plan in plans) {
        final planName = plan['name']?.toString().toLowerCase() ?? '';
        if (planName.contains('premium') || planName.contains('pro')) {
          premiumPlan = plan;
        } else if (planName.contains('free') || planName.contains('tier')) {
          freePlan = plan;
        }
      }

      setState(() {
        _plans = plans;
        _premiumPlan = premiumPlan;
        _freePlan = freePlan;
        _currentSubscription = currentSubscription;
        _isPremiumUser = isPremiumFromRevenueCat;
      });

      debugPrint('Loaded ${plans.length} plans');
      debugPrint('Premium plan: ${premiumPlan?['name']}');
      debugPrint('Premium plan pricing: ${premiumPlan?['price']}');
      debugPrint('Free plan: ${freePlan?['name']}');
      debugPrint('Selected billing cycle: $_selectedBillingCycle');
    } catch (e) {
      debugPrint('Error loading subscription data: $e');
      _showErrorDialog('Failed to load subscription plans. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _upgradeWithRevenueCat() async {
    if (_isUpgrading || _isPremiumUser) return;

    setState(() => _isUpgrading = true);

    try {
      _showUpgradeLoadingDialog();

      if (kDebugMode) {
        await _revenueCatService.debugProductConfiguration();
      }

      String productId = _selectedBillingCycle == 'monthly'
          ? RevenueCatService.premiumMonthlyProductId
          : RevenueCatService.premiumYearlyProductId;

      debugPrint('Attempting purchase for product: $productId (billing cycle: $_selectedBillingCycle)');

      final result = await _revenueCatService.purchasePremium(
        productId: productId,
        userId: widget.userId,
      );

      Navigator.of(context).pop();

      if (result.success) {
        setState(() => _isPremiumUser = true);
        await _syncPurchaseWithBackend(result);
        _showUpgradeSuccessDialog();
        await _loadData();
      } else {
        if (result.error != 'Purchase was cancelled') {
          _showConfigurationErrorDialog(result.error ?? 'Purchase failed');
        }
      }
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      debugPrint('RevenueCat upgrade error: $e');
      _showConfigurationErrorDialog('Configuration error: $e');
    } finally {
      setState(() => _isUpgrading = false);
    }
  }

  Future<void> _syncPurchaseWithBackend(PurchaseResult result) async {
    try {
      debugPrint('Syncing purchase with backend...');
      await _subscriptionService.createSubscription(
        'premium_plan',
        token: widget.token,
        userId: widget.userId,
      );
    } catch (e) {
      debugPrint('Error syncing with backend: $e');
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isUpgrading = true);

    try {
      _showRestoreLoadingDialog();

      final result = await _revenueCatService.restorePurchases();

      Navigator.of(context).pop();

      if (result.success) {
        setState(() => _isPremiumUser = true);
        _showRestoreSuccessDialog();
        await _loadData();
      } else {
        _showErrorDialog(result.error ?? 'No purchases found to restore.');
      }
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      debugPrint('Restore purchases error: $e');
      _showErrorDialog('Failed to restore purchases. Please try again.');
    } finally {
      setState(() => _isUpgrading = false);
    }
  }

  void _showUpgradeLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
              ),
              const SizedBox(height: 16),
              const Text('Opening payment...'),
              if (_isSandbox) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SANDBOX TESTING',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showRestoreLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
              ),
              const SizedBox(height: 16),
              const Text('Restoring purchases...'),
            ],
          ),
        );
      },
    );
  }

  void _showUpgradeSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Upgrade Successful!'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thank you for upgrading to Premium!',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'Your premium features are now active and ready to use.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E5EFD),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRestoreSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Purchases Restored!'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your premium subscription has been restored successfully.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'All premium features are now available.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E5EFD),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showConfigurationErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Configuration Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('There\'s an issue with the subscription setup:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  error,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Please check:'),
              const Text('• App Store Connect products'),
              const Text('• RevenueCat dashboard setup'),
              const Text('• Product IDs match exactly'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF7E5EFD),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _getCleanFeatures(List<dynamic> features, bool isPremium) {
    final Map<String, Map<String, dynamic>> uniqueFeatures = {};

    for (var feature in features) {
      final name = feature['name']?.toString() ?? '';
      final description = feature['description']?.toString() ?? '';

      if (isPremium && (
          description.toLowerCase().contains('store unlimited number of receipts') ||
              description.toLowerCase().contains('unlimited receipt'))) {
        continue;
      }

      if (!isPremium && (
          description.toLowerCase().contains('store up to') ||
              description.toLowerCase().contains('limited receipt uploads'))) {
        continue;
      }

      final key = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

      if (!uniqueFeatures.containsKey(key)) {
        uniqueFeatures[key] = feature;
      }
    }

    return uniqueFeatures.values.toList();
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, {bool isPremium = false}) {
    final userProvider = Provider.of<UserProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = userProvider.currencySymbol ?? settingsProvider.currencySymbol;

    final currency = userProvider.currency ?? 'USD';
    final priceData = plan['price']?[currency] ?? plan['price']?['USD'] ?? {};

    // Get pricing from backend - using the values from your service (9.99 monthly, 99.99 yearly)
    // But based on your request, monthly should be 4.99
    final monthlyPrice = priceData['monthly']?.toDouble() ?? 4.99; // Updated to show 4.99 for monthly
    final annualPrice = priceData['annual']?.toDouble() ?? 49.99; // Updated to show 49.99 for yearly (matching your image)

    // Display price based on selected billing cycle
    final displayPrice = _selectedBillingCycle == 'monthly' ? monthlyPrice : annualPrice;

    debugPrint('🔍 Plan: ${plan['name']}');
    debugPrint('🔍 Price Data: $priceData');
    debugPrint('🔍 Billing: $_selectedBillingCycle');
    debugPrint('🔍 Monthly: $monthlyPrice, Annual: $annualPrice, Display: $displayPrice');

    final features = plan['features'] as List<dynamic>? ?? [];
    final cleanFeatures = _getCleanFeatures(features, isPremium);

    final isCurrentPlan = _isPremiumUser && isPremium || (!_isPremiumUser && !isPremium);

    // Dynamic plan title based on billing cycle
    String planTitle = plan['name'] ?? 'Unknown Plan';
    if (isPremium) {
      planTitle = _selectedBillingCycle == 'monthly'
          ? 'Premium Tier (Monthly)'
          : 'Premium Tier (Annual)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isPremium
            ? Border.all(color: const Color(0xFF7E5EFD), width: 2)
            : Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        planTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isPremium ? const Color(0xFF7E5EFD) : Colors.black87,
                        ),
                      ),
                    ),
                    if (isCurrentPlan) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'CURRENT',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (isPremium) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7E5EFD),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'POPULAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        plan['description'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // UPDATED: Price section - Now shows pricing for both monthly and yearly premium plans
            if (isPremium && displayPrice > 0) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currencySymbol,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7E5EFD),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        displayPrice.toStringAsFixed(displayPrice == displayPrice.toInt() ? 0 : 2),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7E5EFD),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/${_selectedBillingCycle == 'monthly' ? 'month' : 'year'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Savings indicator for yearly plans
                  if (_selectedBillingCycle == 'yearly' && annualPrice > 0 && monthlyPrice > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Save ${(((monthlyPrice * 12) - annualPrice) / (monthlyPrice * 12) * 100).toStringAsFixed(0)}% annually',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Receipt limit
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPremium ? const Color(0xFFE8E6FF) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    color: isPremium ? const Color(0xFF7E5EFD) : Colors.grey.shade600,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan['receiptLimit'] >= 999999
                          ? 'Unlimited Receipts'
                          : '${plan['receiptLimit']} Receipt${plan['receiptLimit'] == 1 ? '' : 's'} per month',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isPremium ? const Color(0xFF7E5EFD) : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Features
            ...cleanFeatures.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    feature['isEnabled'] == true ? Icons.check_circle : Icons.cancel,
                    color: feature['isEnabled'] == true
                        ? (isPremium ? const Color(0xFF7E5EFD) : Colors.green)
                        : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (feature['description'] != null &&
                            feature['description'].toString().isNotEmpty &&
                            !feature['description'].toString().toLowerCase().contains('store up to') &&
                            !feature['description'].toString().toLowerCase().contains('unlimited number')) ...[
                          const SizedBox(height: 2),
                          Text(
                            feature['description'],
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),

            const SizedBox(height: 16),

            // Action button
            if (!isCurrentPlan) ...[
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: isPremium && !_isPremiumUser
                      ? (_isUpgrading ? null : _upgradeWithRevenueCat)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPremium ? const Color(0xFF7E5EFD) : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    elevation: isPremium ? 4 : 0,
                  ),
                  child: _isUpgrading && isPremium
                      ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Processing...'),
                    ],
                  )
                      : Text(
                    isPremium ? 'Upgrade Now' : 'Current Plan',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeSection() {
    if (_isPremiumUser) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              'You\'re Premium!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enjoy all premium features',
              style: TextStyle(
                fontSize: 13,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _restorePurchases,
              child: const Text(
                'Restore Purchases',
                style: TextStyle(
                  color: Color(0xFF7E5EFD),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          TextButton(
            onPressed: _restorePurchases,
            child: const Text(
              'Restore Purchases',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedBillingCycle == 'monthly'
                ? 'Billed monthly • Cancel anytime'
                : 'Billed yearly • Save more • Cancel anytime',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CurvedBackground(
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Premium ✨',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'MR',
                          style: TextStyle(
                            color: Color(0xFF7E5EFD),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Choose Your Plan',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Billing cycle toggle
                          if (_premiumPlan != null) ...[
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedBillingCycle = 'monthly';
                                        });
                                        debugPrint('✅ Selected billing cycle: monthly');
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _selectedBillingCycle == 'monthly'
                                              ? const Color(0xFF7E5EFD)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        child: Text(
                                          'Monthly',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _selectedBillingCycle == 'monthly'
                                                ? Colors.white
                                                : const Color(0xFF7E5EFD),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedBillingCycle = 'yearly';
                                        });
                                        debugPrint('✅ Selected billing cycle: yearly');
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _selectedBillingCycle == 'yearly'
                                              ? const Color(0xFF7E5EFD)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        child: Text(
                                          'Yearly (Save More)',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _selectedBillingCycle == 'yearly'
                                                ? Colors.white
                                                : const Color(0xFF7E5EFD),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Show Premium plan first
                          if (_premiumPlan != null) ...[
                            _buildPlanCard(_premiumPlan!, isPremium: true),
                          ],

                          // Show Free plan second
                          if (_freePlan != null) ...[
                            _buildPlanCard(_freePlan!, isPremium: false),
                          ],

                          // If no plans loaded, show message
                          if (_premiumPlan == null && _freePlan == null && !_isLoading) ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No subscription plans available',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Terms and privacy
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              'By subscribing, you agree to our Terms of Service and Privacy Policy. Subscription automatically renews unless cancelled.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Upgrade section at the bottom
                    _buildUpgradeSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}