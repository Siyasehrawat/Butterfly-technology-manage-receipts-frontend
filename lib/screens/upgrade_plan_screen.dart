import 'package:flutter/material.dart';
import '../services/workspace_service.dart';

class UpgradePlanScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String? workspaceId;

  const UpgradePlanScreen({
    Key? key,
    required this.userId,
    required this.token,
    this.workspaceId,
  }) : super(key: key);

  @override
  State<UpgradePlanScreen> createState() => _UpgradePlanScreenState();
}

class _UpgradePlanScreenState extends State<UpgradePlanScreen> {
  bool _isLoading = true;
  bool _isProcessingPurchase = false;
  String? _errorMessage;
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _pricingPreview;
  final TextEditingController _licenseController = TextEditingController(text: '5');
  String _selectedCurrency = 'USD';
  String _selectedPaymentPeriod = 'monthly';

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Workspace is required to load subscription';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

      final res = await WorkspaceService.getSubscription(
        workspaceId: widget.workspaceId!,
        userId: widget.userId, // Using userId as fallback until memberId is available
        token: widget.token,
      );

    if (!mounted) return;

    if (res['success'] == true) {
      final data = res['data'] as Map<String, dynamic>?;
      final subscription = data?['subscription'];
      
      setState(() {
        _subscription = data;
        _isLoading = false;
        // Set default currency from subscription if available
        if (subscription != null && subscription['currency'] != null) {
          _selectedCurrency = subscription['currency'].toString();
        }
        if (subscription != null && subscription['paymentPeriod'] != null) {
          _selectedPaymentPeriod = subscription['paymentPeriod'].toString();
        }
      });
    } else {
      setState(() {
        _errorMessage = res['error']?.toString() ?? 'Failed to load subscription';
        _isLoading = false;
      });
    }
  }

  Future<void> _previewPricing() async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace missing')),
      );
      return;
    }

    final count = int.tryParse(_licenseController.text.trim());
    if (count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid license count')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final res = await WorkspaceService.initiatePurchase(
      workspaceId: widget.workspaceId!,
      userId: widget.userId,
      numberOfLicenses: count,
      currency: _selectedCurrency,
      paymentPeriod: _selectedPaymentPeriod,
      token: widget.token,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res['success'] == true) {
      setState(() {
        _pricingPreview = res['data'] as Map<String, dynamic>?;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Failed to preview pricing')),
      );
    }
  }

  Future<void> _proceedToPurchase() async {
    if (_pricingPreview == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please preview pricing first')),
      );
      return;
    }

    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace missing')),
      );
      return;
    }

    final numberOfLicenses = _pricingPreview!['numberOfLicenses'];
    final finalPrice = _pricingPreview!['finalPrice'];
    final currency = _pricingPreview!['currency'] ?? _selectedCurrency;
    final paymentPeriod = _pricingPreview!['paymentPeriod'] ?? _selectedPaymentPeriod;
    final pricePerLicense = _pricingPreview!['pricePerLicense'];
    final totalPrice = _pricingPreview!['totalPrice'];
    final discount = _pricingPreview!['discount'] ?? 0;

    _showOrderConfirmationDialog(
      numberOfLicenses,
      finalPrice,
      currency,
      paymentPeriod,
      pricePerLicense,
      totalPrice,
      discount,
    );
  }

  void _showOrderConfirmationDialog(
    dynamic numberOfLicenses,
    dynamic finalPrice,
    String currency,
    String paymentPeriod,
    dynamic pricePerLicense,
    dynamic totalPrice,
    dynamic discount,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.shopping_cart, color: Color(0xFF7E5EFD)),
            SizedBox(width: 8),
            Text('Purchase Summary'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your purchase order has been created successfully. Please complete the payment to activate your licenses.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderDetailRow('Number of Licenses', numberOfLicenses?.toString() ?? '—'),
                  _buildOrderDetailRow('Price per License', '$currency ${pricePerLicense ?? '—'}'),
                  if (discount != null && discount > 0)
                    _buildOrderDetailRow('Discount', '$currency $discount'),
                  _buildOrderDetailRow('Total Price', '$currency ${totalPrice ?? '—'}'),
                  _buildOrderDetailRow('Final Price', '$currency ${finalPrice ?? '—'}'),
                  _buildOrderDetailRow('Payment Period', paymentPeriod.toUpperCase()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7E5EFD).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFF7E5EFD)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment will be processed via webhook. Licenses will be activated automatically after successful payment.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7E5EFD)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Upgrade Your Plan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: const Center(
                child: Text(
                  'MR',
                  style: TextStyle(
                    color: Color(0xFF7E5EFD),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSubscription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final subscription = _subscription?['subscription'] as Map<String, dynamic>?;
    final status = subscription?['status'] ?? 'inactive';
    final licensesUsed = subscription?['licensesUsed'] ?? 0;
    final licenseTotal = subscription?['licensesUsed'] ?? 1;
    final isActive = status == 'active';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Plan Status - Compact Card
          _buildCurrentPlanCard(subscription, isActive, licensesUsed, licenseTotal),
          const SizedBox(height: 16),
          
          // License Selection & Options - Combined Card
          _buildSelectionCard(),
          
          // Pricing Preview
          if (_pricingPreview != null) ...[
            const SizedBox(height: 16),
            _buildPricingPreview(),
          ],
          
          // Action Buttons
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard(Map<String, dynamic>? subscription, bool isActive, int licensesUsed, int licenseTotal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF22C55E).withOpacity(0.3) : Colors.grey.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive 
                      ? const Color(0xFF22C55E).withOpacity(0.1)
                      : const Color(0xFF7E5EFD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isActive ? Icons.check_circle : Icons.workspace_premium,
                  color: isActive ? const Color(0xFF22C55E) : const Color(0xFF7E5EFD),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'Active Plan' : 'Inactive Plan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isActive ? const Color(0xFF22C55E) : const Color(0xFF7E5EFD),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$licensesUsed / $licenseTotal licenses used',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _FeatureChip(icon: Icons.analytics, label: 'Analytics'),
              _FeatureChip(icon: Icons.support_agent, label: 'Priority Support'),
              _FeatureChip(icon: Icons.file_download, label: 'Custom Export'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // License Input
          const Text(
            'Number of Licenses',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _licenseController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintText: 'Enter license count',
            ),
          ),
          const SizedBox(height: 16),
          
          // Currency & Period - Side by Side
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Currency',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: _buildCurrencyOption('USD', 'USD')),
                        const SizedBox(width: 6),
                        Expanded(child: _buildCurrencyOption('INR', 'INR')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Period',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: _buildPeriodOption('monthly', 'Monthly')),
                        const SizedBox(width: 6),
                        Expanded(child: _buildPeriodOption('yearly', 'Yearly')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyOption(String value, String label) {
    final isSelected = _selectedCurrency == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCurrency = value;
          _pricingPreview = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7E5EFD).withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? const Color(0xFF7E5EFD) : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodOption(String value, String label) {
    final isSelected = _selectedPaymentPeriod == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentPeriod = value;
          _pricingPreview = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7E5EFD).withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? const Color(0xFF7E5EFD) : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPricingPreview() {
    final numberOfLicenses = _pricingPreview?['numberOfLicenses'];
    final paymentPeriod = _pricingPreview?['paymentPeriod'] ?? _selectedPaymentPeriod;
    final pricePerLicense = _pricingPreview?['pricePerLicense'];
    final totalPrice = _pricingPreview?['totalPrice'];
    final discount = _pricingPreview?['discount'] ?? 0;
    final finalPrice = _pricingPreview?['finalPrice'];
    final currency = _pricingPreview?['currency'] ?? _selectedCurrency;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7E5EFD).withOpacity(0.1),
            const Color(0xFF7E5EFD).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF7E5EFD).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E5EFD).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF7E5EFD),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Pricing Preview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7E5EFD),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPricingRow('Licenses', numberOfLicenses?.toString() ?? '—'),
          _buildPricingRow('Price per License', '$currency ${pricePerLicense ?? '—'}'),
          _buildPricingRow('Period', paymentPeriod.toString().toUpperCase()),
          if (discount > 0) _buildPricingRow('Discount', '$currency $discount', isDiscount: true),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Final Price',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$currency ${finalPrice ?? totalPrice ?? '—'}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7E5EFD),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDiscount ? const Color(0xFF22C55E) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E5EFD),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : _previewPricing,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Preview Pricing',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        if (_pricingPreview != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _isProcessingPurchase ? null : _proceedToPurchase,
              child: _isProcessingPurchase
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Proceed to Purchase',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF7E5EFD).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xFF7E5EFD),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7E5EFD),
            ),
          ),
        ],
      ),
    );
  }
}
