import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/feature_flags_provider.dart';
import 'analytics_screen.dart';
import 'tax_reports_screen.dart';
import 'expense_reports_screen.dart';
import 'reports_screen.dart';
import '../widgets/upload_bottom_sheet.dart';
import 'receipt_details_screen.dart';
import 'track_distance_screen.dart';
import '../providers/receipt_provider.dart';
import '../utils/country_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'wallet_screen.dart';
import 'wallet_pin_entry_screen.dart';
import 'wallet_onboarding_screen.dart';
import '../widgets/app_bottom_nav_bar.dart';

class ReportsHomeScreen extends StatefulWidget {
  const ReportsHomeScreen({super.key});

  @override
  State<ReportsHomeScreen> createState() => _ReportsHomeScreenState();
}

class _ReportsHomeScreenState extends State<ReportsHomeScreen> {
  @override
  void initState() {
    super.initState();
    _initializeFeatureFlags();
  }

  Future<void> _initializeFeatureFlags() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
      
      await featureFlagsProvider.initFromCache();
      await featureFlagsProvider.safeFetchFeatureFlags(
        token: userProvider.token ?? '',
        userId: userProvider.userId ?? '',
      );
    } catch (e) {
      debugPrint('ReportsHomeScreen - Error initializing feature flags: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final featureFlags = Provider.of<FeatureFlagsProvider>(context);
    final userId = userProvider.userId ?? '';
    final token = userProvider.token ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Purple header with logo
          Container(
            color: const Color(0xFF7E5EFD),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 16,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Reports',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Container(
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
                const SizedBox(width: 16), // Add some spacing from the edge
              ],
            ),
          ),

          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [

                  // Report options grid
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      // Slightly taller cards to prevent text overflow on smaller screens
                      childAspectRatio: 0.9,
                      children: _buildReportOptions(context, featureFlags, userId, token),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentRoute: 'reports',
        userId: userId,
        token: token,
        onUploadTap: () {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final currentUserId = userProvider.userId ?? '';
          final country = userProvider.country;
          UploadSheet.show(
            context,
            country: country,
            onAction: (action) async {
              switch (action) {
                case UploadAction.camera:
                  await _handleUploadFromHere(context, currentUserId, source: ImageSource.camera);
                  break;
                case UploadAction.gallery:
                  await _handleUploadFromHere(context, currentUserId, source: ImageSource.gallery);
                  break;
                case UploadAction.manual:
                  await _openManualReceipt(context, currentUserId);
                  break;
                case UploadAction.trackDistance:
                  await _openTrackDistance(context, currentUserId);
                  break;
              }
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildReportOptions(BuildContext context, FeatureFlagsProvider featureFlags, String userId, String token) {
    List<Widget> options = [];

    // Analytics
    if (featureFlags.isAnalyticsEnabled) {
      options.add(
        _buildReportCard(
          context,
          icon: Icons.show_chart,
          title: 'Analytics',
          subtitle: '',
          onTap: () => _navigateToAnalytics(context),
        ),
      );
    }

    // Tax Reports
    if (featureFlags.isTaxReportsEnabled) {
      options.add(
        _buildReportCard(
          context,
          icon: Icons.description,
          title: 'Tax Reports',
          subtitle: '',
          onTap: () => _navigateToTaxReports(context, userId),
        ),
      );
    }

    // Expense Reports
    if (featureFlags.isExpenseReportsEnabled) {
      options.add(
        _buildReportCard(
          context,
          icon: Icons.folder,
          title: 'Expense Reports',
          subtitle: '',
          onTap: () => _navigateToExpenseReports(context, userId, token),
        ),
      );
    }

    // Search Reports
    if (featureFlags.isCustomReportsEnabled) {
      options.add(
        _buildReportCard(
          context,
          icon: Icons.pie_chart,
          title: 'Search Receipts',
          subtitle: '',
          onTap: () => _navigateToCustomReports(context, userId),
        ),
      );
    }

    // If no options are enabled, show a message
    if (options.isEmpty) {
      options.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No report options available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Report features are currently disabled',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return options;
  }

  Widget _buildReportCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7E5EFD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  // Subtitle
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToDocWallet(BuildContext context) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final walletInfo = await userProvider.getWalletNavigationInfo(userProvider.token ?? '');
      
      if (mounted) {
        if (walletInfo['needsOnboarding']) {
          // User needs to set up wallet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyWalletOnboardingScreen(
                userId: userProvider.userId ?? '',
                token: userProvider.token ?? '',
              ),
            ),
          );
        } else if (walletInfo['needsPinEntry']) {
          // User has wallet but needs PIN entry
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocWalletPinEntryScreen(
                userId: userProvider.userId ?? '',
                token: userProvider.token ?? '',
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
                userId: userProvider.userId ?? '',
                token: userProvider.token ?? '',
              ),
            ),
          );
        } else {
          // Default to onboarding
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyWalletOnboardingScreen(
                userId: userProvider.userId ?? '',
                token: userProvider.token ?? '',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing Doc Wallet: $e')),
        );
      }
    }
  }

  void _onBottomNavTap(BuildContext context, int index) {
    final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
    final isMrBucksEnabled = featureFlagsProvider.isMrBucksEnabled;
    
    // If mr bucks is disabled, adjust index mapping
    // When disabled: Home(0), Reports(1), Upload(2), More(3)
    // When enabled: Home(0), Reports(1), Upload(2), MR Bucks(3), More(4)
    if (!isMrBucksEnabled && index == 3) {
      // This is the "More" tab when mr bucks is disabled
      Navigator.pushNamed(context, '/more');
      return;
    }
    
    switch (index) {
      case 0: // Home
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
        );
        break;
      case 1: // Reports
        // Already on reports screen, do nothing
        break;
      case 2: // Upload
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final currentUserId = userProvider.userId ?? '';
        final country = userProvider.country;
        UploadSheet.show(
          context,
          country: country,
          onAction: (action) async {
            switch (action) {
              case UploadAction.camera:
                await _handleUploadFromHere(context, currentUserId, source: ImageSource.camera);
                break;
              case UploadAction.gallery:
                await _handleUploadFromHere(context, currentUserId, source: ImageSource.gallery);
                break;
              case UploadAction.manual:
                await _openManualReceipt(context, currentUserId);
                break;
              case UploadAction.trackDistance:
                await _openTrackDistance(context, currentUserId);
                break;
            }
          },
        );
        break;
      case 3: // MR Bucks (only if enabled)
        if (isMrBucksEnabled) {
          Navigator.pushNamed(context, '/mr_bucks');
        }
        break;
      case 4: // More (only if mr bucks is enabled)
        if (isMrBucksEnabled) {
          Navigator.pushNamed(context, '/more');
        }
        break;
    }
  }


  Future<void> _handleUploadFromHere(BuildContext context, String userId, {required ImageSource source}) async {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    receiptProvider.setUserId(userId);

    final receiptData = await receiptProvider.uploadAndProcessReceipt(source);
    if (receiptData == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptDetailsScreen(
          receipt: receiptData,
          imageUrl: receiptData['decryptedImageUrl'] ?? receiptData['imageUrl'] ?? '',
          userId: userId,
          imageId: (receiptData['imageId']?.toString()) ?? '',
          isNewReceipt: true,
          isPdf: false,
        ),
      ),
    );
  }

  Future<void> _openManualReceipt(BuildContext context, String userId) async {
    final emptyReceipt = {
      'merchant': '',
      'receiptDate': DateTime.now().toIso8601String(),
      'amount': '',
      'category': '',
    };

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptDetailsScreen(
          receipt: emptyReceipt,
          imageUrl: '',
          userId: userId,
          imageId: '',
          isNewReceipt: true,
          isPdf: false,
          isManualReceipt: true,
        ),
      ),
    );
  }

  Future<void> _openTrackDistance(BuildContext context, String userId) async {
    final token = Provider.of<UserProvider>(context, listen: false).token ?? '';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackDistanceScreen(
          userId: userId,
          token: token,
        ),
      ),
    );
  }

  void _navigateToAnalytics(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AnalyticsScreen(),
      ),
    );
  }

  void _navigateToTaxReports(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaxReportsScreen(userId: userId),
      ),
    );
  }

  void _navigateToExpenseReports(BuildContext context, String userId, String token) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseReportsScreen(
          userId: userId,
          token: token,
        ),
      ),
    );
  }

  void _navigateToCustomReports(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportsScreen(userId: userId),
      ),
    );
  }
}
