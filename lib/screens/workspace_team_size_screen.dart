import 'package:flutter/material.dart';

import 'workspace_dashboard_screen.dart';
import 'upgrade_plan_screen.dart';
import '../services/workspace_service.dart';

class WorkspaceTeamSizeScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String workspaceName;
  final String? workspaceId;
  final String? companyEmail;

  const WorkspaceTeamSizeScreen({
    Key? key,
    required this.userId,
    required this.token,
    this.workspaceName = 'My Workspace',
    this.workspaceId,
    this.companyEmail,
  }) : super(key: key);

  @override
  State<WorkspaceTeamSizeScreen> createState() => _WorkspaceTeamSizeScreenState();
}

class _WorkspaceTeamSizeScreenState extends State<WorkspaceTeamSizeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _teamSizeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  @override
  void dispose() {
    _teamSizeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Team Size',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Team Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please provide your team details. Each member requires one license.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Full Name
              const Text(
                'Full Name *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., John Doe',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Email Address
              const Text(
                'Email Address *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'e.g., john@company.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Contact Number
              const Text(
                'Contact Number *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'e.g., +91 98765 43210',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your contact number';
                  }
                  if (value.trim().length < 10) {
                    return 'Please enter a valid contact number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Number of Team Members
              const Text(
                'Number of Team Members *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _teamSizeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g., 25',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.group, color: Colors.grey),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter team size';
                  }
                  final number = int.tryParse(value.trim());
                  if (number == null || number < 1) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Pricing Information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3ECFF),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Color(0xFF7E5EFD),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Pricing Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7E5EFD),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPricingRow(
                      icon: Icons.check_circle,
                      title: 'Less than 50 members',
                      price: '\$5/member/month',
                      subtitle: '₹250/member/month',
                    ),
                    const SizedBox(height: 12),
                    _buildPricingRow(
                      icon: Icons.check_circle,
                      title: '50+ members',
                      price: 'Enterprise pricing',
                      subtitle: 'Contact sales for custom quote',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF22C55E).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_offer,
                            color: Color(0xFF22C55E),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Annual payment: ',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(
                                    text: 'Get 10% off',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF22C55E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Each member requires one license. You can add more members later.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Contact Sales Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _sendSalesQuery();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E5EFD),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.email_outlined, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Contact Sales Team',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Back Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingRow({
    required IconData icon,
    required String title,
    required String price,
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFF7E5EFD),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          price,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF7E5EFD),
          ),
        ),
      ],
    );
  }

  void _sendSalesQuery() async {
    final licensesNeeded = int.tryParse(_teamSizeController.text.trim());
    if (licensesNeeded == null || licensesNeeded <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid team size')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
        ),
      ),
    );

    try {
      String currentWorkspaceId = widget.workspaceId ?? '';

      // If no workspace exists, create one first
      if (currentWorkspaceId.isEmpty) {
        final email = widget.companyEmail ?? _emailController.text.trim();
        // Ensure workspace name is not empty
        final workspaceName = widget.workspaceName.trim().isEmpty 
            ? 'My Workspace' 
            : widget.workspaceName.trim();
        
        debugPrint('📤 Creating workspace: $workspaceName for $email');
        
        final createResult = await WorkspaceService.createWorkspace(
          userId: widget.userId,
          name: workspaceName,
          companyEmail: email,
          token: widget.token,
        );

        if (createResult['success'] == true) {
          currentWorkspaceId = createResult['data']['workspace']['id'];
        } else {
          // If workspace creation fails, still continue with the sales query
          // The backend can handle it without workspace in some cases
          debugPrint('Warning: Could not create workspace: ${createResult['error']}');
        }
      }

      // For teams with less than 50 members, try direct purchase
      if (licensesNeeded < 50 && currentWorkspaceId.isNotEmpty) {
        // Try to initiate purchase for direct purchase flow
        final purchaseResult = await WorkspaceService.initiatePurchase(
          workspaceId: currentWorkspaceId,
          userId: widget.userId,
          numberOfLicenses: licensesNeeded,
          currency: 'USD',
          paymentPeriod: 'monthly',
          token: widget.token,
        );

        if (!mounted) return;
        Navigator.pop(context); // Close loading

        if (purchaseResult['success'] == true) {
          // Show purchase options dialog
          _showPurchaseOptionsDialog(currentWorkspaceId, purchaseResult['data'], licensesNeeded);
          return;
        } else {
          // If purchase initiation fails, fall back to custom plan request
          debugPrint('Purchase initiation failed, falling back to custom plan request');
        }
      }

      // For 50+ members or if purchase initiation failed, use custom plan request
      if (!mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
            ),
          ),
        );
      }

      final result = await WorkspaceService.createCustomPlanRequest(
        workspaceId: currentWorkspaceId.isNotEmpty ? currentWorkspaceId : 'temp',
        userId: widget.userId,
        body: {
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phoneNumber': _contactController.text.trim(),
          'licensesNeeded': licensesNeeded,
          'purpose': licensesNeeded >= 50 ? 'scale' : 'Workspace team setup inquiry',
        },
        token: widget.token,
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      if (result['success'] == true) {
        _showSuccessDialog(currentWorkspaceId);
      } else {
        // Show error
        _showErrorDialog(result['error'] ?? 'Failed to submit request');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      _showErrorDialog('An error occurred: $e');
    }
  }

  void _showPurchaseOptionsDialog(String workspaceId, Map<String, dynamic> purchaseData, int licensesNeeded) {
    // Map the actual API response structure
    final numberOfLicenses = purchaseData['numberOfLicenses'] ?? licensesNeeded;
    final paymentPeriod = purchaseData['paymentPeriod'] ?? 'monthly';
    final pricePerLicense = purchaseData['pricePerLicense'];
    final totalPrice = purchaseData['totalPrice'];
    final discount = purchaseData['discount'] ?? 0;
    final finalPrice = purchaseData['finalPrice'];
    final currency = purchaseData['currency'] ?? 'USD';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.all(24),
        title: const Row(
          children: [
            Icon(Icons.shopping_cart, color: Color(0xFF7E5EFD)),
            SizedBox(width: 8),
            Text('Purchase Options'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your team size qualifies for direct purchase. You can proceed with payment or request a custom quote.',
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
                  _buildPurchaseDetailRow('Number of Licenses', numberOfLicenses.toString()),
                  if (pricePerLicense != null) _buildPurchaseDetailRow('Price per License', '$currency $pricePerLicense'),
                  if (totalPrice != null) _buildPurchaseDetailRow('Subtotal', '$currency $totalPrice'),
                  if (discount > 0) _buildPurchaseDetailRow('Discount', '$currency $discount'),
                  if (finalPrice != null) _buildPurchaseDetailRow('Final Price', '$currency $finalPrice'),
                  _buildPurchaseDetailRow('Payment Period', paymentPeriod.toString().toUpperCase()),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to upgrade plan screen for payment
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UpgradePlanScreen(
                    userId: widget.userId,
                    token: widget.token,
                    workspaceId: workspaceId,
                  ),
                ),
              );
            },
            child: const Text('Proceed to Payment'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Continue with custom plan request
              _sendCustomPlanRequest(workspaceId, licensesNeeded);
            },
            child: const Text('Request Custom Quote'),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseDetailRow(String label, String value) {
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

  Future<void> _sendCustomPlanRequest(String workspaceId, int licensesNeeded) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
        ),
      ),
    );

    try {
      final result = await WorkspaceService.createCustomPlanRequest(
        workspaceId: workspaceId.isNotEmpty ? workspaceId : 'temp',
        userId: widget.userId,
        body: {
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phoneNumber': _contactController.text.trim(),
          'licensesNeeded': licensesNeeded,
          'purpose': 'scale',
        },
        token: widget.token,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (result['success'] == true) {
        _showSuccessDialog(workspaceId);
      } else {
        _showErrorDialog(result['error'] ?? 'Failed to submit request');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorDialog('An error occurred: $e');
    }
  }

  void _showSuccessDialog(String workspaceId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF22C55E),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Query Sent Successfully!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Thank you for your interest! Our sales team has received your query and will contact you shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3ECFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      color: Color(0xFF7E5EFD),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _emailController.text,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7E5EFD),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkspaceDashboardScreen(
                        userId: widget.userId,
                        token: widget.token,
                        workspaceId: workspaceId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Go to Dashboard',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Request Failed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}


