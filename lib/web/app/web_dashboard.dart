import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;
import '../../screens/dashboard_screen.dart';
import '../../providers/user_provider.dart';
import '../../providers/setting_provider.dart';
import '../../providers/subscription_provider_bypass.dart';
import '../../providers/feature_flags_provider.dart';
import '../../utils/category_icons.dart';
import '../../services/api_service_bypass.dart';
import '../../utils/encryption_helper.dart';
import 'dart:convert';
import '../../screens/receipt_details_screen.dart';
import '../../screens/bill_reminders_screen.dart';
import '../../screens/split_receipts_screen.dart';
import '../../screens/wallet_onboarding_screen.dart';
import '../../screens/wallet_pin_entry_screen.dart';
import '../../screens/wallet_screen.dart';
import '../../screens/mr_bucks_screen.dart';
import '../../screens/refer_earn_screen.dart';
import '../../screens/tax_calculator_screen.dart';
import '../../screens/welcome_screen.dart';
import '../../screens/edit_category_screen.dart';
import '../../screens/split_contacts_screen.dart';
import '../../screens/workspaces_list_screen.dart';
import '../../utils/country_utils.dart';
import 'web_admin_dashboard.dart';
import 'web_settings.dart';

/// Web-optimized dashboard layout with sidebar navigation
class WebDashboardLayout extends StatelessWidget {
  final String userId;
  final String token;
  final List<dynamic> savedReceipts;
  final bool isLoading;
  final bool isLoadingUserName;
  final String userName;
  final Function() onRefresh;
  final Function() onPickAndUploadImageFromCamera;
  final Function() onShowUploadDialog;
  final Function(BuildContext) onPickFilesDirectly;
  final Function() onCreateManualReceipt;
  final Function() onCreateTrackDistanceReceipt;
  final Function() onEmailReceiptInfo;
  final Function() onCreateExpenseReport;
  final Function(BuildContext, dynamic) onReceiptTap;
  final Function() onLogout;
  final Function() onNavigateToReports;
  final List<dynamic> banners;
  final bool isLoadingBanners;
  final bool isUploading;
  final String uploadStatus;
  final int currentStep;
  final List<String> uploadSteps;

  const WebDashboardLayout({
    Key? key,
    required this.userId,
    required this.token,
    required this.savedReceipts,
    required this.isLoading,
    required this.isLoadingUserName,
    required this.userName,
    required this.onRefresh,
    required this.onPickAndUploadImageFromCamera,
    required this.onShowUploadDialog,
    required this.onPickFilesDirectly,
    required this.onCreateManualReceipt,
    required this.onCreateTrackDistanceReceipt,
    required this.onEmailReceiptInfo,
    required this.onCreateExpenseReport,
    required this.onReceiptTap,
    required this.onLogout,
    required this.onNavigateToReports,
    required this.banners,
    required this.isLoadingBanners,
    required this.isUploading,
    required this.uploadStatus,
    required this.currentStep,
    required this.uploadSteps,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    // Show upload progress overlay if uploading
    if (isUploading) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              _buildSidebar(context),
              Expanded(
                child: Column(
                  children: [
                    _buildTopHeader(context),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  uploadStatus,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please wait while we process your receipt',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  constraints: const BoxConstraints(maxWidth: 400),
                                  child: LinearProgressIndicator(
                                    value: (currentStep + 1) / uploadSteps.length,
                                    backgroundColor: Colors.grey.shade300,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF7E5EFD),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Step ${currentStep + 1} of ${uploadSteps.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            // Left Sidebar
            _buildSidebar(context),
            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Top Header
                  _buildTopHeader(context),
                  // Main Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16.0 : 32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Greeting
                            _buildGreeting(context),
                            SizedBox(height: constraints.maxWidth < 600 ? 16 : 32),
                            // Summary Cards
                            _buildSummaryCards(context),
                            SizedBox(height: constraints.maxWidth < 600 ? 16 : 32),
                            // Quick Actions
                            _buildQuickActions(context),
                            SizedBox(height: constraints.maxWidth < 600 ? 16 : 32),
                            // Recent Receipts
                            _buildRecentReceiptsSection(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth < 1200 ? 240.0 : 280.0;
    
    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo Section
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF905CFF), Color(0xFF7A4BD9)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'MR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Manage Receipt',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Navigation Sections
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildNavSection(
                  context,
                  'MAIN',
                  [
                    _buildNavItem(context, Icons.home, 'Dashboard', true, () {}),
                    _buildNavItem(context, Icons.search, 'Search Receipts', false, () {}),
                    _buildNavItem(context, Icons.email, 'Email Receipts', false, () {}),
                  ],
                ),
                const SizedBox(height: 8),
                _buildNavSection(
                  context,
                  'REPORTS',
                  [
                    _buildNavItem(context, Icons.description, 'Expense Reports', false, onNavigateToReports),
                    _buildNavItem(context, Icons.receipt_long, 'Tax Reports', false, () {}),
                    _buildNavItem(context, Icons.bar_chart, 'Analytics', false, () {}),
                  ],
                ),
                const SizedBox(height: 8),
                _buildNavSection(
                  context,
                  'WORKSPACE',
                  [
                    _buildNavItem(context, Icons.business, 'Workspaces', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkspacesListScreen(
                            userId: userId,
                            token: token,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                // ADMIN section - only shown if user has admin access
                if (Provider.of<UserProvider>(context).hasAdminAccess) ...[
                  _buildNavSection(
                    context,
                    'ADMIN',
                    [
                      _buildNavItem(context, Icons.admin_panel_settings, 'Admin Panel', false, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WebAdminDashboard(
                              adminId: userId,
                              token: token,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                _buildNavSection(
                  context,
                  'FEATURES',
                  [
                    _buildNavItem(context, Icons.notifications, 'Bill Reminders', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BillRemindersScreen(),
                        ),
                      );
                    }),
                    _buildNavItem(context, Icons.people, 'Split Receipts', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SplitReceiptsScreen(
                            userId: userId,
                            token: token,
                          ),
                        ),
                      );
                    }),
                    // Tax Calculator - Hidden for Indian users
                    if (!CountryUtils.isIndia(Provider.of<UserProvider>(context, listen: false).country))
                      _buildNavItem(context, Icons.calculate, 'Tax Calculator', false, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TaxCalculatorScreen(),
                          ),
                        );
                      }),
                    _buildNavItem(context, Icons.folder, 'Document Wallet', false, () async {
                      await _navigateToDocWallet(context);
                    }),
                    _buildNavItem(context, Icons.monetization_on, 'MR Bucks', false, () {
                      Navigator.pushNamed(context, '/mr_bucks');
                    }),
                    _buildNavItem(context, Icons.person_add, 'Refer & Earn', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReferEarnScreen(
                            userId: userId,
                            token: token,
                          ),
                        ),
                      );
                    }),
                    _buildNavItem(context, Icons.category, 'Manage Categories', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditCategoryScreen(
                            initialValue: null,
                            userId: userId,
                          ),
                        ),
                      );
                    }),
                    _buildNavItem(context, Icons.contacts, 'Manage Contacts', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SplitContactsScreen(
                            userId: userId,
                            token: token,
                          ),
                        ),
                      );
                    }),
                    _buildNavItem(context, Icons.settings, 'Settings', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WebSettingsScreen(
                            userId: userId,
                            token: token,
                          ),
                        ),
                      );
                    }),
                    _buildNavItem(context, Icons.logout, 'Logout', false, () {
                      onLogout();
                    }),
                  ],
                ),
              ],
            ),
          ),
          // User Profile Section
          _buildUserProfile(context),
        ],
      ),
    );
  }

  Widget _buildNavSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, bool isSelected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF905CFF).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFF905CFF) : Colors.grey.shade700,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF905CFF) : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToDocWallet(BuildContext context) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final walletInfo = await userProvider.getWalletNavigationInfo(token);
      
      if (walletInfo['needsOnboarding']) {
        // User needs to set up wallet
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyWalletOnboardingScreen(
              userId: userId,
              token: token,
            ),
          ),
        );
      } else if (walletInfo['needsPinEntry']) {
        // User has wallet but needs PIN entry
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocWalletPinEntryScreen(
              userId: userId,
              token: token,
              userEmail: userProvider.email,
            ),
          ),
        );
      } else if (walletInfo['canAccessWallet']) {
        // User can access wallet directly
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyWalletScreen(
              userId: userId,
              token: token,
            ),
          ),
        );
      } else {
        // Default to onboarding
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyWalletOnboardingScreen(
              userId: userId,
              token: token,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing Doc Wallet: $e')),
      );
    }
  }

  Widget _buildUserProfile(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final displayName = userProvider.username ?? userName;
        final initials = displayName.isNotEmpty
            ? displayName.substring(0, 1).toUpperCase()
            : 'U';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF905CFF),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Premium Account',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Dashboard',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Consumer<FeatureFlagsProvider>(
                  builder: (context, featureFlagsProvider, child) {
                    if (!featureFlagsProvider.isMrBucksEnabled) {
                      return const SizedBox.shrink();
                    }
                    return Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.monetization_on, size: 18, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '1,250 MR Bucks',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final displayName = userProvider.username ?? userName;
        return Text(
          'Hi $displayName 👋',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    // Calculate summary statistics
    final totalReceipts = savedReceipts.length;
    double totalExpenses = 0;
    int exportedCount = 0;
    
    for (var receipt in savedReceipts) {
      final amount = receipt['amount'];
      if (amount != null) {
        totalExpenses += (amount is num ? amount.toDouble() : double.tryParse(amount.toString()) ?? 0.0);
      }
      final status = receipt['status']?.toString().toLowerCase() ?? '';
      if (status == 'exported') {
        exportedCount++;
      }
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
    final currencySymbol = userProvider.currencySymbol ?? settingsProvider.currencySymbol ?? '₹';

    final children = <Widget>[
      _buildSummaryCard(
        context,
        'TOTAL RECEIPTS',
        totalReceipts.toString(),
        '+12% this month',
        true,
        Icons.receipt_long,
        const Color(0xFF905CFF),
      ),
      _buildSummaryCard(
        context,
        'TOTAL EXPENSES',
        '$currencySymbol${NumberFormat('#,##0.00').format(totalExpenses)}',
        '-5% this month',
        false,
        Icons.account_balance_wallet,
        Colors.green,
      ),
      _buildSummaryCard(
        context,
        'EXPORTED VS NOT EXPORTED',
        '$exportedCount / $totalReceipts',
        '${totalReceipts > 0 ? ((exportedCount / totalReceipts) * 100).toStringAsFixed(0) : 0}% exported',
        true,
        Icons.file_upload,
        Colors.blue,
      ),
      _buildSummaryCard(
        context,
        'UPCOMING BILL REMINDERS',
        '7',
        '2 due this week',
        false,
        Icons.notifications,
        Colors.amber,
      ),
    ];

    if (featureFlagsProvider.isMrBucksEnabled) {
      children.add(
        _buildSummaryCard(
          context,
          'MR BUCKS BALANCE',
          '1,250',
          '+150 this month',
          true,
          Icons.monetization_on,
          Colors.amber,
        ),
      );
    }

    return Row(
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < children.length - 1 ? 16 : 0),
            child: child,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    bool isPositive,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row (title + icon). Wrapped in FittedBox to avoid overflow
          // on very narrow layouts (e.g. small grid cells on web).
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isPositive ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showUploadReceiptsDialog(BuildContext context, {int initialTab = 0}) {
    showDialog(
      context: context,
      builder: (dialogContext) => _UploadReceiptsDialog(
        initialTab: initialTab,
        onPickFiles: () async {
          // For web, directly open file picker (no intermediate Photos/Documents dialog)
          Navigator.of(dialogContext).pop();
          await onPickFilesDirectly(context);
        },
        onPickFilesDirectly: () async {
          // Dialog is already closed by the button, just start upload
          // Use parent context since dialog context may be invalid after closing
          await onPickFilesDirectly(context);
        },
        onEmailInfo: () {
          Navigator.of(dialogContext).pop();
          onEmailReceiptInfo();
        },
        onManualEntry: (data) async {
          await _handleManualEntry(context, dialogContext, data);
        },
      ),
    );
  }

  void _showReviewExtractedDataDialog(BuildContext context, Map<String, dynamic> receipt) {
    final imageUrl = receipt['imageUrl']?.toString() ?? '';
    
    showDialog(
      context: context,
      builder: (dialogContext) => ReviewExtractedDataDialog(
        receipt: receipt,
        imageUrl: imageUrl,
        userId: userId,
        token: token,
        onRefresh: onRefresh,
      ),
    );
  }

  Future<void> _handleManualEntry(BuildContext parentContext, BuildContext dialogContext, Map<String, dynamic> data) async {
    try {
      // Prepare receipt data using same format as mobile app
      final receiptData = {
        'userId': userId,
        'merchant': data['merchant'] ?? '',
        'receiptDate': data['receiptDate'] ?? DateFormat('MM-dd-yyyy').format(DateTime.now()),
        'amount': data['amount']?.toString().replaceAll(RegExp(r'[^\d.]'), '') ?? '',
        'category': data['category'] ?? '',
        'tags': data['tags'] ?? '',
        'comments': data['comments'] ?? '',
        'isManual': true,
      };

      // Use the same API endpoint as mobile app: POST /receipts/{userId}
      final response = await ApiService.post(
        '/receipts/$userId',
        body: receiptData,
        token: token,
      );

      // Close the dialog after save completes
      try {
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
      } catch (_) {
        // Ignore navigation errors during close
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Wait for navigation to complete before refreshing
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Safely trigger refresh - wrap in try-catch to prevent crashes
        try {
          onRefresh();
        } catch (refreshError) {
          // If refresh fails, that's okay - user can manually refresh
          print('Refresh failed but receipt was saved: $refreshError');
        }
      }
    } catch (e) {
      // Close dialog on error too
      try {
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
      } catch (_) {
        // Ignore navigation errors
      }
      print('Error saving receipt: $e');
    }
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Use horizontal scroll on smaller screens
            if (constraints.maxWidth < 800) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: _buildQuickActionCard(
                        context,
                        Icons.cloud_upload,
                        'Upload Receipt',
                        'Upload images or PDFs',
                        const Color(0xFF905CFF),
                        () => _showUploadReceiptsDialog(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 250,
                      child: _buildQuickActionCard(
                        context,
                        Icons.edit,
                        'Add Manual Receipt',
                        'Enter receipt details manually',
                        const Color(0xFF905CFF),
                        () => _showUploadReceiptsDialog(context, initialTab: 2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 250,
                      child: _buildQuickActionCard(
                        context,
                        Icons.location_on,
                        'Track Distance',
                        'Create an expense from distance traveled',
                        const Color(0xFF905CFF),
                        onCreateTrackDistanceReceipt,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 250,
                      child: _buildQuickActionCard(
                        context,
                        Icons.email,
                        'Email Receipt Info',
                        'Forward receipts via email',
                        const Color(0xFF905CFF),
                        () => _showUploadReceiptsDialog(context, initialTab: 1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 250,
                      child: _buildQuickActionCard(
                        context,
                        Icons.picture_as_pdf,
                        'Create Expense Report',
                        'Generate PDF reports',
                        const Color(0xFF905CFF),
                        onCreateExpenseReport,
                      ),
                    ),
                  ],
                ),
              );
            }
            // Use expanded row on larger screens
            return Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    Icons.cloud_upload,
                    'Upload Receipt',
                    'Upload images or PDFs',
                    const Color(0xFF905CFF),
                    () => _showUploadReceiptsDialog(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    Icons.edit,
                    'Add Manual Receipt',
                    'Enter receipt details manually',
                    const Color(0xFF905CFF),
                    () => _showUploadReceiptsDialog(context, initialTab: 2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    Icons.location_on,
                    'Track Distance',
                    'Create an expense from distance traveled',
                    const Color(0xFF905CFF),
                    onCreateTrackDistanceReceipt,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    Icons.email,
                    'Email Receipt Info',
                    'Forward receipts via email',
                    const Color(0xFF905CFF),
                    () => _showUploadReceiptsDialog(context, initialTab: 1),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    Icons.picture_as_pdf,
                    'Create Expense Report',
                    'Generate PDF reports',
                    const Color(0xFF905CFF),
                    onCreateExpenseReport,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color color,
    VoidCallback onTap,
  ) {
    return _QuickActionCard(
      icon: icon,
      title: title,
      description: description,
      color: color,
      onTap: onTap,
    );
  }

  Widget _buildRecentReceiptsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Receipts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            TextButton(
              onPressed: onNavigateToReports,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF905CFF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Color(0xFF905CFF),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildReceiptsTable(context),
      ],
    );
  }

  Widget _buildReceiptsTable(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF905CFF)),
          ),
        ),
      );
    }

    if (savedReceipts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No receipts uploaded yet',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final currencySymbol = userProvider.currencySymbol ?? settingsProvider.currencySymbol ?? '₹';

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1),
                },
        children: [
          // Header Row
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            children: [
              _buildTableHeader('Receipt'),
              _buildTableHeader('Category'),
              _buildTableHeader('Amount'),
              _buildTableHeader('Date'),
              _buildTableHeader(''),
            ],
          ),
          // Data Rows
          ...savedReceipts.take(10).map((receipt) {
            // Make receipt tappable
            final receiptData = receipt;
            final rowKey = GlobalKey();
            final merchant = receipt['merchant']?.toString() ?? 'Unknown';
            final amount = receipt['amount'];
            final amountValue = amount is num
                ? amount.toDouble()
                : (double.tryParse(amount?.toString() ?? '0') ?? 0.0);
            final category = receipt['category']?.toString() ?? 'Uncategorized';

            String formattedDate = 'No date';
            if (receipt['receiptDate'] != null) {
              try {
                final dateStr = receipt['receiptDate'].toString();
                DateTime? date = DateTime.tryParse(dateStr);
                if (date == null) {
                  // Try alternative format
                  try {
                    final formatter = DateFormat('MM-dd-yyyy');
                    date = formatter.parse(dateStr);
                  } catch (e) {
                    // Keep null
                  }
                }
                if (date != null) {
                  formattedDate = DateFormat('MMM d, yyyy').format(date);
                }
              } catch (e) {
                // Keep default
              }
            }

            final categoryIcon = getCategoryIcon(category);
            final categoryColor = getCategoryColor(category);

            return TableRow(
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              children: [
                _buildTableCell(
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onReceiptTap(context, receiptData),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(categoryIcon, size: 20, color: categoryColor),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  merchant,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (receipt['description'] != null)
                                  Text(
                                    receipt['description'].toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 24, top: 16, bottom: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onReceiptTap(context, receiptData),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: categoryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
                _buildTableCell(
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onReceiptTap(context, receiptData),
                      child: Text(
                        '$currencySymbol${NumberFormat('#,##0.00').format(amountValue)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                _buildTableCell(
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onReceiptTap(context, receiptData),
                      child: Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                _buildTableCell(
                  OutlinedButton.icon(
                    onPressed: () => _showReviewExtractedDataDialog(context, receiptData),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      foregroundColor: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: Colors.transparent,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHovered ? widget.color : Colors.grey.shade200,
                width: _isHovered ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered 
                      ? widget.color.withOpacity(0.2)
                      : Colors.grey.shade100,
                  blurRadius: _isHovered ? 12 : 8,
                  offset: Offset(0, _isHovered ? 4 : 2),
                ),
              ],
            ),
            transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, size: 24, color: widget.color),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Upload Receipts Dialog with Tabs
class _UploadReceiptsDialog extends StatefulWidget {
  final Function() onPickFiles;
  final Future<void> Function() onPickFilesDirectly;
  final Function() onEmailInfo;
  final Function(Map<String, dynamic>) onManualEntry;
  final int initialTab;

  const _UploadReceiptsDialog({
    required this.onPickFiles,
    required this.onPickFilesDirectly,
    required this.onEmailInfo,
    required this.onManualEntry,
    this.initialTab = 0,
  });

  @override
  State<_UploadReceiptsDialog> createState() => _UploadReceiptsDialogState();
}

class _UploadReceiptsDialogState extends State<_UploadReceiptsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  bool _showCopiedMessage = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _selectedTabIndex = widget.initialTab;
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Adjust dialog size based on selected tab
    // Email Upload tab has less content, so use smaller size
    final isEmailTab = _selectedTabIndex == 1;
    final isManualTab = _selectedTabIndex == 2;
    final maxWidth = isEmailTab ? 450.0 : (isManualTab ? 500.0 : 500.0);
    final maxHeight = isEmailTab ? 500.0 : (isManualTab ? 580.0 : 550.0);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),
            // Tabs
            _buildTabs(),
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUploadFilesTab(),
                  _buildEmailUploadTab(),
                  _buildManualEntryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Upload Receipts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 22),
            onPressed: () => Navigator.of(context).pop(),
            color: Colors.grey.shade600,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF7E5EFD),
        indicatorWeight: 3,
        labelColor: const Color(0xFF7E5EFD),
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        tabs: const [
          Tab(text: 'Upload Files'),
          Tab(text: 'Email Upload'),
          Tab(text: 'Manual Entry'),
        ],
      ),
    );
  }

  Widget _buildUploadFilesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragDropArea(),
          const SizedBox(height: 16),
          _buildFileInfo(),
          const SizedBox(height: 16),
          _buildActionButtons(
            onCancel: () => Navigator.of(context).pop(),
            onUpload: () async {
              // Close dialog and directly open file picker (no intermediate dialog for web)
              if (mounted) {
                Navigator.of(context).pop();
              }
              // Small delay to ensure dialog is closed before starting file picker
              await Future.delayed(const Duration(milliseconds: 100));
              if (mounted) {
                await widget.onPickFilesDirectly();
              }
            },
            primaryButtonText: 'Upload Receipt',
          ),
        ],
      ),
    );
  }

  Widget _buildDragDropArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF7E5EFD).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_upload,
              size: 40,
              color: Color(0xFF7E5EFD),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Drag & Drop Receipts Here',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Upload images (JPG, PNG) or PDF files',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Supports multiple files',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () async {
              // Close dialog immediately, upload happens in background
              if (mounted) {
                Navigator.of(context).pop();
              }
              // Small delay to ensure dialog is closed before starting file picker
              await Future.delayed(const Duration(milliseconds: 100));
              if (mounted) {
                await widget.onPickFilesDirectly();
              }
            },
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Browse Files', style: TextStyle(fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E5EFD),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfo() {
    return Column(
      children: [
        _buildInfoRow(
          Icons.info_outline,
          'Maximum file size: 10MB per file',
        ),
        const SizedBox(height: 6),
        _buildInfoRow(
          Icons.info_outline,
          'For bulk uploads, consider using Email Upload',
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E5EFD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.email,
                  color: Color(0xFF7E5EFD),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'Forward Receipts via Email',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Forward receipts from your registered email ID to automatically add them to your Manage Receipt account.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 20),
          _buildEmailInputField(),
          if (_showCopiedMessage) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7E5EFD).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF7E5EFD).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF7E5EFD),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Email address copied to clipboard',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7E5EFD),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildRecentUploadsSection(),
          const SizedBox(height: 20),
          _buildActionButtons(
            onCancel: () => Navigator.of(context).pop(),
            onUpload: () {
              widget.onEmailInfo();
              Navigator.of(context).pop();
            },
            primaryButtonText: 'Copy Email Address',
          ),
        ],
      ),
    );
  }

  Widget _buildEmailInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'upload@managereceipt.com',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: 'upload@managereceipt.com'),
              );
              if (mounted) {
                setState(() {
                  _showCopiedMessage = true;
                });
                // Hide message after 3 seconds
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) {
                    setState(() {
                      _showCopiedMessage = false;
                    });
                  }
                });
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E5EFD),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentUploadsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Uploads via Email',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          _buildUploadStatusRow(
            Icons.check_circle,
            '3 receipts processed today',
            Colors.green,
          ),
          const SizedBox(height: 6),
          _buildUploadStatusRow(
            Icons.access_time,
            '1 receipt processing',
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadStatusRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualEntryTab() {
    return _ManualEntryForm(
      onSave: (data) {
        widget.onManualEntry(data);
        Navigator.of(context).pop();
      },
      onCancel: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildActionButtons({
    required VoidCallback onCancel,
    required VoidCallback onUpload,
    required String primaryButtonText,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: onUpload,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7E5EFD),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            primaryButtonText,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// Manual Entry Form
class _ManualEntryForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;

  const _ManualEntryForm({
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<_ManualEntryForm> {
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _tagsController = TextEditingController();
  final _commentsController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _categoryFocusNode = FocusNode();
  
  DateTime? _selectedDate;
  String? _selectedCategory;
  List<String> _categories = [];
  List<String> _tags = [];
  bool _loadingCategories = false;
  bool _isDropdownOpen = false;
  final _categoryFieldKey = GlobalKey();
  static const int _maxTags = 5;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadCategories();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _tagsController.dispose();
    _commentsController.dispose();
    _categoryController.dispose();
    _tagInputController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim();
    if (trimmedTag.isNotEmpty && !_tags.contains(trimmedTag) && _tags.length < _maxTags) {
      setState(() {
        _tags.add(trimmedTag);
        _tagsController.text = _tags.join(', ');
      });
    } else if (_tags.length >= _maxTags) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $_maxTags tags allowed'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    _tagInputController.clear();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _tagsController.text = _tags.join(', ');
    });
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId ?? '';
      
      final response = await ApiService.get('/receipts/categories?userId=$userId');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['categories'] != null && data['categories'] is List) {
          setState(() {
            _categories = List<String>.from(data['categories'])..sort();
          });
        } else {
          _setDefaultCategories();
        }
      } else {
        _setDefaultCategories();
      }
    } catch (e) {
      _setDefaultCategories();
    } finally {
      setState(() => _loadingCategories = false);
    }
  }

  void _setDefaultCategories() {
    setState(() {
      _categories = [
        'Books',
        'Clothing',
        'Electronics',
        'Groceries',
        'Shopping',
        'Toys',
        'Business',
        'Travel',
        'Dining',
        'Entertainment',
      ]..sort();
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showCategoryMenu(BuildContext context, RenderBox button) {
    // Prevent opening if already open
    if (_isDropdownOpen) return;
    
    final searchText = _categoryController.text.toLowerCase();
    final filteredCategories = _categories
        .where((cat) => cat.toLowerCase().contains(searchText))
        .toList();

    // Get the overlay to calculate position relative to it
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    // Get the button's position relative to the overlay
    final Offset buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size buttonSize = button.size;
    
    // Calculate position: dropdown should appear directly below the textbox
    // Use a small offset (4px) to create a gap between textbox and dropdown
    final Offset topLeft = Offset(buttonPosition.dx, buttonPosition.dy + buttonSize.height + 4);
    final Offset bottomRight = Offset(buttonPosition.dx + buttonSize.width, buttonPosition.dy + buttonSize.height + 4);

    // Get screen size to ensure dropdown doesn't go off-screen
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;
    
    // Calculate available space below the button
    final double availableSpaceBelow = screenSize.height - topLeft.dy;
    final double maxHeight = availableSpaceBelow > 200 ? 200 : (availableSpaceBelow - 16 > 0 ? availableSpaceBelow - 16 : 200);

    // Create the menu position relative to the overlay using fromRect
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    );

    // Mark dropdown as open
    setState(() => _isDropdownOpen = true);

    showMenu<String>(
      context: context,
      position: position,
      constraints: BoxConstraints(
        minWidth: buttonSize.width,
        maxWidth: buttonSize.width,
        maxHeight: maxHeight > 0 ? maxHeight : 200,
      ),
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      items: filteredCategories.isEmpty
          ? [
              PopupMenuItem<String>(
                enabled: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    searchText.isEmpty
                        ? 'No categories available'
                        : 'No categories match "$searchText"',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ]
          : filteredCategories.map((category) {
              return PopupMenuItem<String>(
                value: category,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop(category);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
    ).then((String? selectedValue) {
      // Mark dropdown as closed
      setState(() => _isDropdownOpen = false);
      
      if (selectedValue != null) {
        setState(() {
          _selectedCategory = selectedValue;
          _categoryController.text = selectedValue;
        });
      }
    });
  }


  void _saveManualEntry() {
    if (_merchantController.text.isEmpty ||
        _amountController.text.isEmpty ||
        _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final data = {
      'merchant': _merchantController.text,
      'receiptDate': DateFormat('MM-dd-yyyy').format(_selectedDate!),
      'amount': _amountController.text,
      'category': _selectedCategory ?? _categoryController.text,
      'tags': _tagsController.text,
      'comments': _commentsController.text,
    };

    widget.onSave(data);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextField(
            controller: _merchantController,
            label: 'Merchant Name',
            hint: 'Enter merchant name',
            isRequired: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateField(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _amountController,
                  label: 'Total Amount',
                  hint: '0.00',
                  isRequired: true,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCategoryField(),
          const SizedBox(height: 12),
          _buildTagsField(),
          const SizedBox(height: 12),
          _buildCommentsField(),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isRequired = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    final dateText = _selectedDate != null
        ? DateFormat('dd-MM-yyyy').format(_selectedDate!)
        : 'dd-mm-yyyy';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dateText,
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedDate != null
                          ? Colors.black
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Builder(
          builder: (BuildContext context) {
            return Container(
              key: _categoryFieldKey,
              child: TextField(
                controller: _categoryController,
                focusNode: _categoryFocusNode,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter or select category',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  suffixIcon: _loadingCategories
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF7E5EFD),
                              ),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          onPressed: () {
                            if (!_isDropdownOpen && !_loadingCategories && _categories.isNotEmpty) {
                              final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
                              if (renderBox != null) {
                                _showCategoryMenu(context, renderBox);
                              }
                            }
                          },
                        ),
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value.isEmpty ? null : value;
                  });
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tags',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_tags.length}/$_maxTags)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _tagInputController,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: _tags.length >= _maxTags
                ? 'Maximum $_maxTags tags reached'
                : 'Type a tag and press Enter',
            hintStyle: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
          ),
          enabled: _tags.length < _maxTags,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty && _tags.length < _maxTags) {
              _addTag(value.trim());
            }
          },
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _tags.map((tag) {
              return Chip(
                label: Text(
                  tag,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: const Color(0xFF7E5EFD),
                deleteIcon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
                onDeleted: () => _removeTag(tag),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCommentsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _commentsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add any notes about this receipt',
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
            contentPadding: const EdgeInsets.all(12),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }


  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: widget.onCancel,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _saveManualEntry,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7E5EFD),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Save Manual Entry'),
        ),
      ],
    );
  }
}

// Review Extracted Data Dialog
class ReviewExtractedDataDialog extends StatefulWidget {
  final Map<String, dynamic> receipt;
  final String imageUrl;
  final String userId;
  final String token;
  final Function()? onRefresh;

  const ReviewExtractedDataDialog({
    required this.receipt,
    required this.imageUrl,
    required this.userId,
    required this.token,
    this.onRefresh,
  });

  @override
  State<ReviewExtractedDataDialog> createState() => _ReviewExtractedDataDialogState();
}

class _ReviewExtractedDataDialogState extends State<ReviewExtractedDataDialog> {
  final _merchantController = TextEditingController();
  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _commentsController = TextEditingController();
  final _categoryFocusNode = FocusNode();
  final _categoryFieldKey = GlobalKey();
  
  DateTime? _selectedDate;
  String? _selectedCategory;
  List<String> _categories = [];
  List<String> _tags = [];
  bool _loadingCategories = false;
  bool _isSaving = false;
  bool _isDropdownOpen = false;
  static const int _maxTags = 5;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _loadCategories();
  }

  void _initializeFields() {
    final receipt = widget.receipt;
    _merchantController.text = receipt['merchant']?.toString() ?? '';
    
    // Parse and format date
    final dateStr = receipt['receiptDate']?.toString() ?? '';
    if (dateStr.isNotEmpty) {
      try {
        DateTime? date;
        if (dateStr.contains('-')) {
          try {
            date = DateFormat('MM-dd-yyyy').parse(dateStr);
          } catch (e) {
            date = DateTime.tryParse(dateStr);
          }
        } else {
          date = DateTime.tryParse(dateStr);
        }
        if (date != null) {
          _selectedDate = date;
          _dateController.text = DateFormat('dd-MM-yyyy').format(date);
        }
      } catch (e) {
        _dateController.text = dateStr;
      }
    }
    
    final amount = receipt['amount'];
    _amountController.text = amount != null 
        ? (amount is num ? amount.toStringAsFixed(2) : amount.toString())
        : '0.00';
    
    _categoryController.text = receipt['category']?.toString() ?? '';
    _selectedCategory = _categoryController.text.isEmpty ? null : _categoryController.text;
    
    final tags = receipt['tags'];
    if (tags != null) {
      if (tags is List) {
        _tags = tags.map((e) => e.toString().trim()).where((tag) => tag.isNotEmpty).toList();
        if (_tags.length > _maxTags) {
          _tags = _tags.take(_maxTags).toList();
        }
        _tagsController.text = _tags.join(', ');
      } else {
        final tagsString = tags.toString();
        _tags = tagsString.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
        if (_tags.length > _maxTags) {
          _tags = _tags.take(_maxTags).toList();
        }
        _tagsController.text = _tags.join(', ');
      }
    }
    
    _commentsController.text = receipt['comments']?.toString() ?? '';
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _dateController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _tagInputController.dispose();
    _commentsController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim();
    if (trimmedTag.isNotEmpty && !_tags.contains(trimmedTag) && _tags.length < _maxTags) {
      setState(() {
        _tags.add(trimmedTag);
        _tagsController.text = _tags.join(', ');
      });
    } else if (_tags.length >= _maxTags) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $_maxTags tags allowed'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    _tagInputController.clear();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _tagsController.text = _tags.join(', ');
    });
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final response = await ApiService.get('/receipts/categories?userId=${widget.userId}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['categories'] != null && data['categories'] is List) {
          setState(() {
            _categories = List<String>.from(data['categories'])..sort();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    } finally {
      setState(() => _loadingCategories = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  void _showCategoryMenu(BuildContext context, RenderBox button) {
    // Prevent opening if already open
    if (_isDropdownOpen) return;
    
    final searchText = _categoryController.text.toLowerCase();
    final filteredCategories = _categories
        .where((cat) => cat.toLowerCase().contains(searchText))
        .toList();

    // Get the overlay to calculate position relative to it
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    // Get the button's position relative to the overlay
    final Offset buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size buttonSize = button.size;
    
    // Calculate position: dropdown should appear directly below the textbox
    // Use a small offset (4px) to create a gap between textbox and dropdown
    final Offset topLeft = Offset(buttonPosition.dx, buttonPosition.dy + buttonSize.height + 4);
    final Offset bottomRight = Offset(buttonPosition.dx + buttonSize.width, buttonPosition.dy + buttonSize.height + 4);

    // Get screen size to ensure dropdown doesn't go off-screen
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;
    
    // Calculate available space below the button
    final double availableSpaceBelow = screenSize.height - topLeft.dy;
    final double maxHeight = availableSpaceBelow > 200 ? 200 : (availableSpaceBelow - 16 > 0 ? availableSpaceBelow - 16 : 200);

    // Create the menu position relative to the overlay using fromRect
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    );

    // Mark dropdown as open
    setState(() => _isDropdownOpen = true);

    showMenu<String>(
      context: context,
      position: position,
      constraints: BoxConstraints(
        minWidth: buttonSize.width,
        maxWidth: buttonSize.width,
        maxHeight: maxHeight > 0 ? maxHeight : 200,
      ),
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      items: filteredCategories.isEmpty
          ? [
              PopupMenuItem<String>(
                enabled: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    searchText.isEmpty
                        ? 'No categories available'
                        : 'No categories match "$searchText"',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ]
          : filteredCategories.map((category) {
              return PopupMenuItem<String>(
                value: category,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop(category);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
    ).then((String? selectedValue) {
      // Mark dropdown as closed
      setState(() => _isDropdownOpen = false);
      
      if (selectedValue != null) {
        setState(() {
          _selectedCategory = selectedValue;
          _categoryController.text = selectedValue;
        });
      }
    });
  }

  Future<void> _saveReceipt() async {
    if (_merchantController.text.isEmpty || _amountController.text.isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final receiptId = widget.receipt['id']?.toString() ?? '';
      final receiptData = {
        'id': receiptId,
        'merchant': _merchantController.text,
        'receiptDate': DateFormat('MM-dd-yyyy').format(_selectedDate!),
        'amount': _amountController.text,
        'category': _selectedCategory ?? _categoryController.text,
        'tags': _tagsController.text,
        'comments': _commentsController.text,
      };

      final response = await ApiService.put(
        '/receipts/update',
        body: receiptData,
        token: widget.token,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop(true);
          widget.onRefresh?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to update receipt');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final currencySymbol = userProvider.currencySymbol ?? settingsProvider.currencySymbol ?? '₹';
    final isPdf = widget.imageUrl.toLowerCase().endsWith('.pdf');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Review Extracted Data',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.grey.shade600,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side - Form fields
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormField(
                            label: 'Merchant Name',
                            controller: _merchantController,
                            isRequired: true,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateField(),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  label: 'Total Amount',
                                  controller: _amountController,
                                  isRequired: true,
                                  prefix: currencySymbol,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildCategoryField(),
                          const SizedBox(height: 16),
                          _buildTagsField(),
                          const SizedBox(height: 16),
                          _buildCommentsField(),
                        ],
                      ),
                    ),
                  ),
                  // Right side - Receipt preview
                  Container(
                    width: 1,
                    color: Colors.grey.shade200,
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Receipt Preview',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: widget.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: isPdf
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.picture_as_pdf,
                                                    size: 64,
                                                    color: Colors.red,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    'PDF Document',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  TextButton(
                                                    onPressed: () {
                                                      if (widget.imageUrl.isNotEmpty) {
                                                        html.window.open(widget.imageUrl, '_blank');
                                                      }
                                                    },
                                                    child: const Text('View PDF'),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Image.network(
                                              widget.imageUrl,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Center(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.broken_image,
                                                        size: 64,
                                                        color: Colors.grey,
                                                      ),
                                                      SizedBox(height: 16),
                                                      Text(
                                                        'Failed to load image',
                                                        style: TextStyle(color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded /
                                                            loadingProgress.expectedTotalBytes!
                                                        : null,
                                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                                      Color(0xFF7E5EFD),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    )
                                  : const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.receipt_long,
                                            size: 64,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'Receipt Preview',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Action buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveReceipt,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E5EFD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    bool isRequired = false,
    String? prefix,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Date',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dateController.text.isEmpty ? 'Select date' : _dateController.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: _dateController.text.isEmpty
                          ? Colors.grey.shade500
                          : Colors.black,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        Builder(
          builder: (BuildContext context) {
            return Container(
              key: _categoryFieldKey,
              child: TextField(
                controller: _categoryController,
                focusNode: _categoryFocusNode,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter or select category',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  suffixIcon: _loadingCategories
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF7E5EFD),
                              ),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          onPressed: () {
                            if (!_isDropdownOpen && !_loadingCategories && _categories.isNotEmpty) {
                              final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
                              if (renderBox != null) {
                                _showCategoryMenu(context, renderBox);
                              }
                            }
                          },
                        ),
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value.isEmpty ? null : value;
                  });
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tags',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_tags.length}/$_maxTags)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _tagInputController,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: _tags.length >= _maxTags
                ? 'Maximum $_maxTags tags reached'
                : 'Type a tag and press Enter',
            hintStyle: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
          ),
          enabled: _tags.length < _maxTags,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty && _tags.length < _maxTags) {
              _addTag(value.trim());
            }
          },
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _tags.map((tag) {
              return Chip(
                label: Text(
                  tag,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: const Color(0xFF7E5EFD),
                deleteIcon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
                onDeleted: () => _removeTag(tag),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCommentsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _commentsController,
          maxLines: 3,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Add any notes about this receipt',
            hintStyle: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
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
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}