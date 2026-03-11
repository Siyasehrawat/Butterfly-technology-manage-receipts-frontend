import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide Banner;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/support_service.dart';
import '../providers/receipt_provider.dart';
import '../providers/user_provider.dart';
import '../providers/setting_provider.dart';
import '../providers/subscription_provider_bypass.dart';
import '../providers/feature_flags_provider.dart';
import '../services/auth_service.dart';
import '../services/api_service_bypass.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_logo.dart';
import '../widgets/duplicate_receipt_badge.dart';
import '../utils/country_utils.dart';
import '../widgets/upload_bottom_sheet.dart';
import 'receipt_details_screen.dart';
import 'welcome_screen.dart';
import 'reports_screen.dart';
import 'subscription_plans_screen.dart';
import 'profile_screen.dart';
import 'more_options_screen.dart';
import 'wallet_screen.dart';
import 'wallet_pin_entry_screen.dart';
import 'wallet_onboarding_screen.dart';
import '../widgets/subscription_upgrade_dialog_bypass.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'dart:io' show File;
import '../services/share_intent_service.dart';
import '../services/share_intent_handler.dart';
import '../services/receipts_service.dart';
import '../models/receipt_models.dart';
import '../models/receipt_save_result.dart';
import '../services/auth_manager.dart';
import 'package:flutter/services.dart';
import '../utils/encryption_helper.dart';
import '../utils/category_icons.dart';
import 'package:flutter/scheduler.dart';
import 'refer_earn_screen.dart';
import '../services/banner_service.dart';
import '../models/banner_model.dart';
import '../widgets/banner_carousel.dart';
import '../web/app/web_dashboard.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../services/document_scan_service.dart';
import 'track_distance_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userId;
  final String token;

  const DashboardScreen({
    Key? key,
    required this.userId,
    required this.token, // Now required instead of defaulting to ''
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<dynamic> savedReceipts = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String _userName = 'User';
  bool _isLoadingUserName = false;
  DateTime? _lastBackPressTime;
  bool _hasInitialized = false;
  bool _isHandlingShareIntent = false;

  // Upload progress indicators
  String _uploadStatus = 'Uploading receipt...';
  int _currentStep = 0;
  final List<String> _uploadSteps = [
    'Uploading receipt...',
    'Scanning for data...',
    'Filling in missing pieces...',
    'Processing complete!'
  ];
  Timer? _progressTimer;

  final GlobalKey _mrBucksIconKey = GlobalKey();
  AnimationController? _coinAnimationController;
  OverlayEntry? _coinOverlayEntry;
  bool _highlightMrBucks = false;
  Timer? _highlightTimer;
  bool _showPointsCelebration = false;
  int _recentPointsAwarded = 0;

  // Banner state
  List<BannerModel> _banners = [];
  bool _isLoadingBanners = false;

  // Category/Merchant helpers now imported from utils/category_icons.dart

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final receiptProvider = Provider.of<ReceiptProvider>(
        context,
        listen: false,
      );
      receiptProvider.setUserId(widget.userId);
      // Profile completion is handled by needsProfile flag during login flow
      _initializeScreen();

      // Delay share intent check to ensure route is fully mounted
      // This prevents "Failed to handle route information" errors
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          _handlePendingShareIntent();
        }
      });

      // If navigated here with an upload action, execute it now
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['uploadAction'] is String) {
        final String action = args['uploadAction'] as String;
        switch (action) {
          case 'camera':
            _pickAndUploadImageFromCamera();
            break;
          case 'gallery':
            _pickAndUploadImageFromGallery();
            break;
          case 'manual':
            _createManualReceipt();
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _highlightTimer?.cancel();
    _coinAnimationController?.dispose();
    _removeCoinOverlay();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When app returns to foreground (e.g., via Android share), process any pending share
      // Only handle if route is current and not already handling
      if (mounted && ModalRoute.of(context)?.isCurrent == true && !_isHandlingShareIntent) {
        _handlePendingShareIntent();
      }
    }
  }

  Future<void> _handlePendingShareIntent() async {
    try {
      if (_isHandlingShareIntent) {
        debugPrint('ShareIntent: Already handling, skipping duplicate call');
        return;
      }
      _isHandlingShareIntent = true;
      debugPrint('ShareIntent: Checking for pending shared file...');
      const MethodChannel channel = MethodChannel('share_intent');
      final String? sharedPath = await channel.invokeMethod<String>('getSharedFile');
      debugPrint('ShareIntent: getSharedFile => ${sharedPath ?? 'null'}');
      if (sharedPath == null) {
        _isHandlingShareIntent = false;
        return;
      }

      if (!mounted) {
        _isHandlingShareIntent = false;
        return;
      }

      // Ensure route is active before showing dialog
      if (ModalRoute.of(context)?.isCurrent != true) {
        debugPrint('ShareIntent: Route not active, aborting');
        _isHandlingShareIntent = false;
        return;
      }

      // Wait for the end of the current frame to avoid route information issues
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
        _isHandlingShareIntent = false;
        return;
      }

      ShareIntentHandler.showProcessingDialog(context);
      try {
        debugPrint('ShareIntent: Starting processing for $sharedPath');

        // Skip if this path was just discarded (within last 10 minutes)
        try {
          final prefs = await SharedPreferences.getInstance();
          final lastDiscarded = prefs.getString('lastDiscardedSharedPath');
          final lastDiscardedAt = prefs.getInt('lastDiscardedAtMs') ?? 0;
          final withinWindow = DateTime.now().millisecondsSinceEpoch - lastDiscardedAt < 10 * 60 * 1000;
          if (lastDiscarded != null && lastDiscarded == sharedPath && withinWindow) {
            debugPrint('ShareIntent: Skipping processing for discarded path');
            const MethodChannel channel = MethodChannel('share_intent');
            await channel.invokeMethod('cleanupSharedFile', sharedPath);
            await prefs.remove('lastDiscardedSharedPath');
            await prefs.remove('lastDiscardedAtMs');
            if (mounted) ShareIntentHandler.dismissProcessingDialog(context);
            _isHandlingShareIntent = false;
            return;
          }
        } catch (_) {}

        // Ensure the file still exists before attempting upload
        final file = File(sharedPath);
        if (!await file.exists()) {
          debugPrint('ShareIntent: Shared file missing, cleaning up and aborting');
          try {
            const MethodChannel channel = MethodChannel('share_intent');
            await channel.invokeMethod('cleanupSharedFile', sharedPath);
          } catch (_) {}
          if (mounted) ShareIntentHandler.dismissProcessingDialog(context);
          _isHandlingShareIntent = false;
          return;
        }
        // Use preview mode - don't auto-save
        final shareResult = await ShareIntentService.handleSharedFilePreview(
          File(sharedPath),
          onProgress: (status, message) {
            debugPrint('ShareIntent: Progress $status - ${message ?? ''}');
            ShareIntentHandler.showProcessingDialogWithProgress(context, status, message);
          },
        ).timeout(const Duration(seconds: 60));

        debugPrint('ShareIntent: Result status=${shareResult.status} hasReceiptDetails=${shareResult.receiptDetails != null}');
        
        if (shareResult.status == ShareIntentStatus.completed && shareResult.receiptDetails != null) {
          // Dismiss processing dialog
          if (mounted) ShareIntentHandler.dismissProcessingDialog(context);
          
          // Convert ReceiptDetails to receipt map for ReceiptDetailsScreen
          final receiptDetails = shareResult.receiptDetails!;
          final encryptedUrl = receiptDetails.imageUrl ?? receiptDetails.pdfUrl ?? '';
          // Decrypt URL if needed
          final decryptedUrl = EncryptionHelper.decryptUrl(encryptedUrl) ?? encryptedUrl;
          final isPdf = decryptedUrl.toLowerCase().endsWith('.pdf');
          
          // Create receipt map from ReceiptDetails
          final receiptMap = {
            'userId': receiptDetails.userId,
            'merchant': receiptDetails.merchant,
            'amount': receiptDetails.amount,
            'receiptDate': receiptDetails.receiptDate,
            'category': receiptDetails.category,
            'imageId': receiptDetails.imageId,
            'imageUrl': encryptedUrl,
            'imageLink': encryptedUrl,
            'decryptedImageLink': decryptedUrl,
            'tags': receiptDetails.tags,
            'comments': receiptDetails.comments,
            'ocrCurrency': receiptDetails.ocrCurrency,
            'userCurrency': receiptDetails.userCurrency,
            'needsCurrencyConversion': receiptDetails.needsCurrencyConversion,
            'lineItems': receiptDetails.lineItems?.map((item) => {
              'page': item.page,
              'merchant': item.merchant,
              'category': item.category,
              'description': item.description,
              'amount': item.amount,
            }).toList(),
            'lineItemsStatus': receiptDetails.lineItemsStatus,
            '_lineItemsPromise': receiptDetails.lineItemsPromise,
          };
          
          debugPrint('ShareIntent: Navigating to ReceiptDetailsScreen with unsaved receipt');
          
          // Wait for next frame before navigating
          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;
          
          final navResult = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ReceiptDetailsScreen(
                receipt: receiptMap,
                imageUrl: decryptedUrl,
                userId: widget.userId,
                imageId: receiptDetails.imageId,
                isNewReceipt: true,
                isPdf: isPdf,
                isManualReceipt: false,
                sharedFilePath: sharedPath, // Pass the shared file path for cleanup
              ),
            ),
          );
          
          // CRITICAL: Clean up the shared file (whether saved or discarded)
          try {
            debugPrint('ShareIntent: Cleaning up shared file: $sharedPath');
            const MethodChannel channel = MethodChannel('share_intent');
            await channel.invokeMethod('cleanupSharedFile', sharedPath);
            debugPrint('ShareIntent: Shared file cleaned up successfully');
          } catch (e) {
            debugPrint('ShareIntent: Failed to cleanup shared file: $e');
          }
          
          await _handleReceiptSaveResult(navResult);
          
          return;
        }
        
        // Error handling - cleanup and show error message
        if (mounted) {
          ShareIntentHandler.dismissProcessingDialog(context);
          
          // Clean up the shared file on error too
          try {
            debugPrint('ShareIntent: Cleaning up shared file after error: $sharedPath');
            const MethodChannel channel = MethodChannel('share_intent');
            await channel.invokeMethod('cleanupSharedFile', sharedPath);
          } catch (e) {
            debugPrint('ShareIntent: Failed to cleanup shared file: $e');
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(shareResult.error ?? 'Failed to process shared file. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } on TimeoutException {
        debugPrint('ShareIntent: Timeout while processing shared file');
        
        // Clean up the shared file on timeout
        try {
          const MethodChannel channel = MethodChannel('share_intent');
          await channel.invokeMethod('cleanupSharedFile', sharedPath);
        } catch (e) {
          debugPrint('ShareIntent: Failed to cleanup shared file: $e');
        }
        
        if (mounted) {
          ShareIntentHandler.dismissProcessingDialog(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Processing timed out. Please check your internet and try again.')),
          );
        }
      } catch (e) {
        debugPrint('ShareIntent: Error while processing shared file: $e');
        
        // Clean up the shared file on error
        try {
          const MethodChannel channel = MethodChannel('share_intent');
          await channel.invokeMethod('cleanupSharedFile', sharedPath);
        } catch (cleanupError) {
          debugPrint('ShareIntent: Failed to cleanup shared file: $cleanupError');
        }
        if (mounted) {
          ShareIntentHandler.dismissProcessingDialog(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error processing shared file: $e')),
          );
        }
      }
      if (mounted) ShareIntentHandler.dismissProcessingDialog(context);
    } catch (_) {
      // Ignore errors silently
    } finally {
      _isHandlingShareIntent = false;
    }
  }

  // Handle bottom navigation bar taps
  Future<void> _navigateToDocWallet(BuildContext context) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final walletInfo = await userProvider.getWalletNavigationInfo(widget.token);
      
      if (mounted) {
        if (walletInfo['needsOnboarding']) {
          // User needs to set up wallet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyWalletOnboardingScreen(
                userId: widget.userId,
                token: widget.token,
              ),
            ),
          );
        } else if (walletInfo['needsPinEntry']) {
          // User has wallet but needs PIN entry
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocWalletPinEntryScreen(
                userId: widget.userId,
                token: widget.token,
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
                userId: widget.userId,
                token: widget.token,
              ),
            ),
          );
        } else {
          // Default to onboarding
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyWalletOnboardingScreen(
                userId: widget.userId,
                token: widget.token,
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

  void _onBottomNavTap(int index) {
    final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
    final isMrBucksEnabled = featureFlagsProvider.isMrBucksEnabled;
    
    // If mr bucks is disabled, adjust index mapping
    // When disabled: Home(0), Reports(1), Upload(2), More(3)
    // When enabled: Home(0), Reports(1), Upload(2), MR Bucks(3), More(4)
    if (!isMrBucksEnabled && index == 3) {
      // This is the "More" tab when mr bucks is disabled
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => MoreOptionsScreen(
            userId: widget.userId,
            token: widget.token,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      return;
    }
    
    switch (index) {
      case 0: // Home
        // Already on home screen, do nothing
        break;
      case 1: // Reports
        Navigator.pushNamed(context, '/reports');
        break;
      case 2: // Upload
        _showUploadBottomSheet();
        break;
      case 3: // MR Bucks (only if enabled)
        if (isMrBucksEnabled) {
          Navigator.pushNamed(context, '/mr_bucks');
        }
        break;
      case 4: // More (only if mr bucks is enabled)
        if (isMrBucksEnabled) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => MoreOptionsScreen(
                userId: widget.userId,
                token: widget.token,
              ),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
        break;
    }
  }

  void _showUploadBottomSheet() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userCountry = userProvider.country;

    UploadSheet.show(
      context,
      country: userCountry,
      onAction: (action) {
        switch (action) {
          case UploadAction.trackDistance:
            _createTrackDistanceReceipt();
            break;
          case UploadAction.camera:
            _pickAndUploadImageFromCamera();
            break;
          case UploadAction.gallery:
            _showUploadDialog();
            break;
          case UploadAction.manual:
            _createManualReceipt();
            break;
        }
      },
    );
  }

  Widget _buildUploadOption({
    required BuildContext ctx,
    required String icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF1F5FF),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced initialization method
  Future<void> _initializeScreen() async {
    if (_hasInitialized) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _isLoadingUserName = true;
      });
    }

    try {
      // First, try to get username from UserProvider
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        if (userProvider.username != null && userProvider.username!.isNotEmpty) {
          setState(() {
            _userName = userProvider.username!;
          });
          debugPrint('Dashboard - Got username from UserProvider: ${userProvider.username}');
        }

        // Initialize subscription provider from cache
        final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
        await subscriptionProvider.initFromCache();

        // Initialize feature flags
        final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
        await featureFlagsProvider.initFromCache();
        await featureFlagsProvider.safeFetchFeatureFlags(
          token: widget.token,
          userId: widget.userId,
        );
      }

      // Load from cache first for immediate display
      await _loadUserNameFromCache();

      // Fetch receipts, subscription data, and banners in parallel
      if (mounted) {
        debugPrint('Dashboard - Starting parallel fetch of receipts, subscription, and banners...');
        final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
        await Future.wait([
          _fetchSavedReceipts(),
          subscriptionProvider.fetchSubscriptionStatus(
            token: widget.token,
            userId: widget.userId,
          ),
          subscriptionProvider.fetchReceiptLimit(
            token: widget.token,
            userId: widget.userId,
          ),
          _fetchBanners(),
        ]);
        debugPrint('Dashboard - Parallel fetch completed');
      }

      // Then fetch fresh data from API
      await _fetchAndCacheUserName();

      _hasInitialized = true;
    } catch (e) {
      debugPrint('Dashboard - Error initializing screen: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingUserName = false;
      });
    }
  }

  // Check if user can add more receipts using SubscriptionProvider
  Future<bool> _canAddReceipt() async {
    if (!mounted) return false;
    
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);

    // Refresh receipt limit before checking
    await subscriptionProvider.fetchReceiptLimit(
      token: widget.token,
      userId: widget.userId,
    );

    return subscriptionProvider.canAddReceipt();
  }

  // Show upgrade dialog when limit is reached
  Future<void> _showUpgradeDialog() async {
    if (!mounted) return;
    
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);

    await SubscriptionUpgradeDialog.show(
      context,
      userId: widget.userId,
      token: widget.token,
      title: 'Receipt Limit Reached',
      message: 'You have reached your limit of ${subscriptionProvider.receiptLimit} receipts. Upgrade to Premium to add unlimited receipts and unlock more features.',
    );
  }

  // Enhanced method to load username from cache
  Future<void> _loadUserNameFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Try multiple cache keys for username
      String? cachedName = prefs.getString('user_name_${widget.userId}');
      cachedName ??= prefs.getString('username');
      cachedName ??= prefs.getString('name');

      if (cachedName != null && cachedName.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _userName = cachedName!;
        });
        debugPrint('Dashboard - Loaded cached username: $cachedName');
      } else {
        debugPrint('Dashboard - No cached username found');
      }
    } catch (e) {
      debugPrint('Error loading cached username: $e');
    }
  }

  // Enhanced method to fetch username from API using ApiService
  Future<void> _fetchAndCacheUserName() async {
    String tokenToUse = widget.token;

    if (tokenToUse.isEmpty) {
      debugPrint('Dashboard - Widget token is empty, trying to get from AuthManager...');
      final authManager = AuthManager();
      tokenToUse = await authManager.getToken() ?? '';

      if (tokenToUse.isEmpty) {
        debugPrint('Dashboard - No token available from AuthManager either');
        return;
      }
      debugPrint('Dashboard - Retrieved token from AuthManager');
    }

    debugPrint('Dashboard - Fetching user profile from API...');

    try {
      final response = await ApiService.get('/users/profile?userId=${widget.userId}', token: tokenToUse);
      debugPrint('Dashboard - API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String? userName;

        // Get user object from response
        if (data['user'] != null) {
          userName = data['user']['name'];
        } else if (data['name'] != null) {
          userName = data['name'];
        }

        if (userName != null && userName.isNotEmpty) {
          debugPrint('Dashboard - Found user name: $userName');
          if (mounted) {
            setState(() {
              _userName = userName!;
            });
          }

          // Cache the username
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_username', userName);

          // Update UserProvider if available
          if (mounted) {
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            userProvider.updateUserName(userName);
          }
        } else {
          debugPrint('Dashboard - No valid username found in API response');
        }
      } else {
        debugPrint('Dashboard - API call failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
    }
  }

  // Method to refresh username when returning from profile screen
  Future<void> _refreshUserName() async {
    if (mounted) {
      setState(() {
        _isLoadingUserName = true;
      });
    }

    try {
      await _fetchAndCacheUserName();
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingUserName = false;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_showPointsCelebration) {
      setState(() {
        _showPointsCelebration = false;
      });
      return false;
    }
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  // Fetch receipts using ApiService
  Future<void> _fetchSavedReceipts() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await ApiService.get('/receipts/${widget.userId}?limit=5', token: widget.token);

      debugPrint('Dashboard - Fetch receipts response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> receipts = data is List ? data : data['receipts'] ?? [];

        debugPrint('Dashboard - Total receipts from API: ${receipts.length}');

        // Filter and sort receipts by the most recent date
        receipts = receipts.where((receipt) {
          final isSaved = receipt['isSaved'];
          return isSaved == null || isSaved == true || isSaved != false;
        }).toList();

        receipts.sort((a, b) {
          DateTime? dateA = _parseDate(a['updatedAt']) ??
              _parseDate(a['createdAt']) ??
              _parseDate(a['receiptDate']);
          DateTime? dateB = _parseDate(b['updatedAt']) ??
              _parseDate(b['createdAt']) ??
              _parseDate(b['receiptDate']);

          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;

          return dateB.compareTo(dateA);
        });

        // Take only the 5 most recent receipts
        final recentReceipts = receipts.take(5).toList();

        debugPrint('Dashboard - Showing ${recentReceipts.length} recent receipts');

        if (mounted) {
          setState(() {
            savedReceipts = recentReceipts;
          });
        }

        // Update receipt count in subscription provider
        if (mounted) {
          final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
          await subscriptionProvider.fetchReceiptLimit(
            token: widget.token,
            userId: widget.userId,
            forceRefresh: true,
          );
        }
      } else {
        debugPrint('Dashboard - Failed to load receipts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Dashboard - Error fetching receipts: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  DateTime? _parseDate(dynamic dateString) {
    if (dateString == null) return null;
    try {
      return DateTime.parse(dateString.toString());
    } catch (e) {
      try {
        final DateFormat formatter = DateFormat('MM-dd-yyyy');
        return formatter.parse(dateString.toString());
      } catch (e) {
        debugPrint('Error parsing date: $e');
        return null;
      }
    }
  }

  // Start upload progress animation
  void _startUploadProgress() {
    if (mounted) {
      setState(() {
        _currentStep = 0;
        _uploadStatus = _uploadSteps[0];
      });
    }

    _progressTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (timer) {
          if (!mounted || !_isUploading) {
            timer.cancel();
            return;
          }

          if (_currentStep < _uploadSteps.length - 1) {
            if (mounted) {
              setState(() {
                _currentStep++;
                _uploadStatus = _uploadSteps[_currentStep];
              });
            }
          } else {
            timer.cancel();
          }
        });
  }

  // Navigate to manual receipt entry
  void _createManualReceipt() async {
    // Check receipt limit first
    if (!await _canAddReceipt()) {
      await _showUpgradeDialog();
      return;
    }

    debugPrint('Dashboard - Creating manual receipt');

    final emptyReceipt = {
      'merchant': '',
      'receiptDate': DateFormat('MM-dd-yyyy').format(DateTime.now()),
      'amount': '',
      'category': '',
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptDetailsScreen(
          receipt: emptyReceipt,
          imageUrl: '',
          userId: widget.userId,
          imageId: '',
          isNewReceipt: true,
          isPdf: false,
          isManualReceipt: true,
        ),
      ),
    );

    await _handleReceiptSaveResult(
      result,
      incrementReceiptCount: true,
    );
  }

  // Navigate to track distance flow (creates a manual-style receipt)
  void _createTrackDistanceReceipt() async {
    // Check receipt limit first
    if (!await _canAddReceipt()) {
      await _showUpgradeDialog();
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackDistanceScreen(
          userId: widget.userId,
          token: widget.token,
        ),
      ),
    );

    await _handleReceiptSaveResult(
      result,
      incrementReceiptCount: true,
    );
  }

  // Show upload dialog
  void _showUploadDialog() async {
    // Check receipt limit first
    if (!await _canAddReceipt()) {
      await _showUpgradeDialog();
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Upload Receipt',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF7E5EFD),
            ),
          ),
          content: const Text(
            'Choose how you want to upload your receipt:',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickAndUploadImageFromGallery();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, color: Color(0xFF7E5EFD)),
                  SizedBox(width: 8),
                  Text(
                    'Photos',
                    style: TextStyle(
                      color: Color(0xFF7E5EFD),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickAndUploadFile();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder, color: Color(0xFF7E5EFD)),
                  SizedBox(width: 8),
                  Text(
                    'Documents',
                    style: TextStyle(
                      color: Color(0xFF7E5EFD),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  // Gallery upload
  Future<void> _pickAndUploadImageFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _uploadImageToCloudinary(image);
    }
  }

  // Camera upload
  Future<void> _pickAndUploadImageFromCamera() async {
    // Check receipt limit first
    if (!await _canAddReceipt()) {
      await _showUpgradeDialog();
      return;
    }

    final image = await DocumentScanService.captureCroppedDocumentImage();
    if (image != null) {
      await _uploadImageToCloudinary(image);
    }
  }

  Future<void> _uploadImageToCloudinary(dynamic image) async {
    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }

    _startUploadProgress();

    const cloudinaryUrl =
        'https://api.cloudinary.com/v1_1/ds1lqhvc3/image/upload';
    const uploadPreset = 'receipt_uploads';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
        ..fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: image.name),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('file', image.path),
        );
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);

      if (response.statusCode == 200) {
        await _sendImageUrlToBackend(jsonResponse["secure_url"] ?? '');
      } else {
        throw Exception(
            "Cloudinary error: ${jsonResponse['error']?['message'] ?? 'Unknown error'}");
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      _progressTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to upload image. Please try again.')),
      );
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _handleReceiptSaveResult(
    dynamic navResult, {
    bool incrementReceiptCount = false,
    bool refreshLimit = false,
  }) async {
    final isReceiptSaveResult = navResult is ReceiptSaveResult;
    final bool shouldRefresh = isReceiptSaveResult
        ? navResult.saved
        : navResult == true;

    if (!shouldRefresh) return;

    await _fetchSavedReceipts();
    if (!mounted) return;

    if (incrementReceiptCount || refreshLimit) {
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);

      if (incrementReceiptCount) {
        subscriptionProvider.incrementReceiptCount();
      }

      if (refreshLimit) {
        await subscriptionProvider.refreshReceiptLimit(
          token: widget.token,
          userId: widget.userId,
        );
      }
    }

    if (isReceiptSaveResult) {
      final saveResult = navResult as ReceiptSaveResult;
      final points = saveResult.pointsAwarded;
      if (points != null && points > 0) {
        _showPointsCelebrationOverlay(points);
      }
      
      // Show duplicate dialog if duplicates found
      if (saveResult.hasDuplicates && saveResult.duplicateReceipts != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => DuplicateReceiptDialog(
                duplicateReceipts: saveResult.duplicateReceipts!,
                onViewReceipt: (receiptId) {
                  // Navigate to receipt details if needed
                  // Navigator.push(...);
                },
              ),
            );
          }
        });
      }
    }
  }

  void _showMrBucksCoinAnimation(int pointsAwarded) {
    if (!mounted) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final iconContext = _mrBucksIconKey.currentContext;
    if (overlay == null || iconContext == null) return;

    final renderBox = iconContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final iconPosition = renderBox.localToGlobal(Offset.zero);
    final iconSize = renderBox.size;
    final mediaQuery = MediaQuery.of(context);

    final availableHeight = mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom;
    final start = Offset(
      mediaQuery.size.width / 2 - 30,
      mediaQuery.padding.top + (availableHeight / 2) - 30,
    );
    final end = Offset(
      iconPosition.dx + (iconSize.width / 2) - 30,
      iconPosition.dy - 16,
    );

    _coinAnimationController?.dispose();
    _coinAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    final animation = CurvedAnimation(
      parent: _coinAnimationController!,
      curve: Curves.easeOutCubic,
    );

    _removeCoinOverlay();
    _coinOverlayEntry = OverlayEntry(
      builder: (context) => _CoinJumpOverlay(
        animation: animation,
        start: start,
        end: end,
        pointsAwarded: pointsAwarded,
      ),
    );
    overlay.insert(_coinOverlayEntry!);

    _coinAnimationController!.forward().whenComplete(() {
      _coinAnimationController?.dispose();
      _coinAnimationController = null;
      _removeCoinOverlay();

      if (!mounted) return;
      setState(() {
        _highlightMrBucks = true;
      });

      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            _highlightMrBucks = false;
          });
        }
      });
    });
  }

  void _showPointsCelebrationOverlay(int pointsAwarded) {
    if (!mounted) return;
    setState(() {
      _recentPointsAwarded = pointsAwarded;
      _showPointsCelebration = true;
    });
  }

  void _dismissPointsCelebrationAndAnimate() {
    if (!mounted) return;
    setState(() {
      _showPointsCelebration = false;
    });
    if (_recentPointsAwarded > 0) {
      // Wait for the next frame to ensure overlay is fully removed before starting animation
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _recentPointsAwarded > 0) {
          _showMrBucksCoinAnimation(_recentPointsAwarded);
        }
      });
    }
  }

  void _removeCoinOverlay() {
    _coinOverlayEntry?.remove();
    _coinOverlayEntry = null;
  }

  Widget _buildMrBucksNavIcon({required bool isActive}) {
    final icon = Icon(
      isActive ? Icons.savings : Icons.savings_outlined,
      size: isActive ? 28 : 26,
    );

    final animatedIcon = AnimatedScale(
      scale: _highlightMrBucks ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: icon,
    );

    return SizedBox(
      key: isActive ? null : _mrBucksIconKey,
      width: 36,
      height: 36,
      child: Center(child: animatedIcon),
    );
  }

  // Send PDF URL to backend using ApiService
  Future<void> _sendPdfUrlToBackend(String pdfUrl) async {
    try {
      // Get user's country from UserProvider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userCountry = userProvider.country ?? '';

      final response = await ApiService.post(
        '/receipts/process-receipt',
        body: {
          'pdfUrl': pdfUrl,
          'userId': widget.userId,
          'country': userCountry,  // Add country to payload
        },
        token: widget.token,
        timeout: const Duration(seconds: 60), // Increased timeout for receipt processing
      );

      _progressTimer?.cancel();
      setState(() {
        _isUploading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = json.decode(response.body);
        debugPrint('📥 PDF process-receipt response: $responseBody');

        // Handle both possible response structures: "receiptDetails" or "receipt"
        final receiptDetails = responseBody["receiptDetails"] ?? responseBody["receipt"];
        
        // Debug line items information
        if (receiptDetails != null) {
          debugPrint('🔍 Dashboard PDF - Line items status: ${receiptDetails['lineItemsStatus']}');
          debugPrint('🔍 Dashboard PDF - Has line items: ${receiptDetails['lineItems']?.length ?? 0}');
          debugPrint('🔍 Dashboard PDF - Has line items promise: ${receiptDetails['_lineItemsPromise'] != null}');
          if (receiptDetails['_lineItemsPromise'] != null) {
            debugPrint('🔍 Dashboard PDF - Line items promise type: ${receiptDetails['_lineItemsPromise'].runtimeType}');
          }
        }
        
        if (responseBody != null && receiptDetails != null) {
          // Decrypt URLs from the response
          final encryptedImageUrl = receiptDetails['imageUrl'] as String?;
          final encryptedPdfUrl = receiptDetails['pdfUrl'] as String?;
          
          debugPrint('🔐 Decrypting PDF OCR response URLs...');
          if (encryptedImageUrl != null) {
            final decryptedImageUrl = EncryptionHelper.decryptUrl(encryptedImageUrl);
            receiptDetails['decryptedImageUrl'] = decryptedImageUrl;
            debugPrint('🔓 Decrypted image URL: $decryptedImageUrl');
          }
          
          if (encryptedPdfUrl != null) {
            final decryptedPdfUrl = EncryptionHelper.decryptUrl(encryptedPdfUrl);
            receiptDetails['decryptedPdfUrl'] = decryptedPdfUrl;
            debugPrint('🔓 Decrypted PDF URL: $decryptedPdfUrl');
          }

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReceiptDetailsScreen(
                receipt: receiptDetails,
                imageUrl: receiptDetails['decryptedImageUrl'] ?? receiptDetails['imageUrl'] ?? '',
                userId: widget.userId,
                imageId: receiptDetails['imageId']?.toString() ?? '',
                isNewReceipt: true,
                isPdf: receiptDetails['pdfUrl'] != null,
              ),
            ),
          );

          // Only refresh if receipt was actually saved
          await _handleReceiptSaveResult(
            result,
            incrementReceiptCount: true,
          );
        } else {
          throw Exception(
              'Unexpected response structure: Missing receiptDetails');
        }
      } else {
        final error = json.decode(response.body)['error'] ?? 'Unknown error';
        throw Exception('Backend error: $error');
      }
    } catch (e) {
      debugPrint("Backend Error: $e");
      _progressTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to process receipt. Please try again.'),
        ),
      );
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // Send Image URL to backend using ApiService
  Future<void> _sendImageUrlToBackend(String imageUrl) async {
    try {
      // Get user's country from UserProvider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userCountry = userProvider.country ?? '';

      final response = await ApiService.post(
        '/receipts/process-receipt',
        body: {
          'imageUrl': imageUrl,
          'userId': widget.userId,
          'country': userCountry,  // Add country to payload
        },
        token: widget.token,
        timeout: const Duration(seconds: 60), // Increased timeout for receipt processing
      );

      _progressTimer?.cancel();
      setState(() {
        _isUploading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = json.decode(response.body);
        debugPrint('📥 Image process-receipt response: $responseBody');

        // Handle both possible response structures: "receiptDetails" or "receipt"
        final receiptDetails = responseBody["receiptDetails"] ?? responseBody["receipt"];
        
        // Debug line items information
        if (receiptDetails != null) {
          debugPrint('🔍 Dashboard Image - Line items status: ${receiptDetails['lineItemsStatus']}');
          debugPrint('🔍 Dashboard Image - Has line items: ${receiptDetails['lineItems']?.length ?? 0}');
          debugPrint('🔍 Dashboard Image - Has line items promise: ${receiptDetails['_lineItemsPromise'] != null}');
          if (receiptDetails['_lineItemsPromise'] != null) {
            debugPrint('🔍 Dashboard Image - Line items promise type: ${receiptDetails['_lineItemsPromise'].runtimeType}');
          }
        }
        
        if (responseBody != null && receiptDetails != null) {
          // Decrypt URLs from the response
          final encryptedImageUrl = receiptDetails['imageUrl'] as String?;
          final encryptedPdfUrl = receiptDetails['pdfUrl'] as String?;
          
          debugPrint('🔐 Decrypting Image OCR response URLs...');
          if (encryptedImageUrl != null) {
            final decryptedImageUrl = EncryptionHelper.decryptUrl(encryptedImageUrl);
            receiptDetails['decryptedImageUrl'] = decryptedImageUrl;
            debugPrint('🔓 Decrypted image URL: $decryptedImageUrl');
          }
          
          if (encryptedPdfUrl != null) {
            final decryptedPdfUrl = EncryptionHelper.decryptUrl(encryptedPdfUrl);
            receiptDetails['decryptedPdfUrl'] = decryptedPdfUrl;
            debugPrint('🔓 Decrypted PDF URL: $decryptedPdfUrl');
          }

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReceiptDetailsScreen(
                receipt: receiptDetails,
                imageUrl: receiptDetails['decryptedImageUrl'] ?? receiptDetails['imageUrl'] ?? '',
                userId: widget.userId,
                imageId: receiptDetails['imageId']?.toString() ?? '',
                isNewReceipt: true,
                isPdf: false,
              ),
            ),
          );

          // Only refresh if receipt was actually saved
          await _handleReceiptSaveResult(
            result,
            incrementReceiptCount: true,
          );
        } else {
          throw Exception(
              'Unexpected response structure: Missing receiptDetails');
        }
      } else {
        final error = json.decode(response.body)['error'] ?? 'Unknown error';
        throw Exception('Backend error: $error');
      }
    } catch (e) {
      debugPrint("Backend Error: $e");
      _progressTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to process receipt. Please try again.'),
        ),
      );
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_name_${widget.userId}');
      await prefs.remove('username');
      await prefs.remove('name');
    } catch (e) {
      debugPrint('Error clearing cached username: $e');
    }

    final authService = AuthService();
    await authService.signOut();

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.logout();

    // Clear subscription cache
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    await subscriptionProvider.clearCache();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
    );
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final isPdf = file.extension?.toLowerCase() == 'pdf';
      await _uploadFileToCloudinary(file, isPdf);
    }
  }

  Future<void> _uploadFileToCloudinary(PlatformFile file, bool isPdf) async {
    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }

    _startUploadProgress();

    final cloudinaryUrl = isPdf
        ? 'https://api.cloudinary.com/v1_1/ds1lqhvc3/raw/upload'
        : 'https://api.cloudinary.com/v1_1/ds1lqhvc3/image/upload';
    const uploadPreset = 'receipt_uploads';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
        ..fields['upload_preset'] = uploadPreset;

      if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('file', file.bytes!,
              filename: file.name),
        );
      } else if (file.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path!,
              filename: file.name),
        );
      } else {
        throw Exception('File data not available');
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);

      if (response.statusCode == 200) {
        final url = jsonResponse["secure_url"] ?? '';
        if (isPdf) {
          await _sendPdfUrlToBackend(url);
        } else {
          await _sendImageUrlToBackend(url);
        }
      } else {
        throw Exception(
            "Cloudinary error: ${jsonResponse['error']?['message'] ?? 'Unknown error'}");
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      _progressTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to upload file. Please try again.')),
      );
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // Build drawer with navigation handling
  AppDrawer _buildDrawer() {
    return AppDrawer(
      userId: widget.userId,
      token: widget.token,
      onLogout: () => _logout(context),
      onNavigateToReports: () async {
        final result = await Navigator.pushNamed(
          context,
          '/reports',
        );

        if (result == true) {
          debugPrint('Dashboard - Refreshing due to changes in reports');
          await _fetchSavedReceipts();
          // Refresh receipt limit after reports changes
          final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
          await subscriptionProvider.refreshReceiptLimit(
            token: widget.token,
            userId: widget.userId,
          );
        } else {
          debugPrint('Dashboard - No refresh needed, no changes made in reports');
        }
      },
    );
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

  bool _isManualReceipt(Map<String, dynamic> receipt) {
    final imageUrl = receipt['decryptedImageLink'] ?? receipt['imageLink'] ?? '';
    return receipt['isManual'] == true ||
        imageUrl.contains('placeholder') ||
        imageUrl.contains('Manual+Receipt') ||
        imageUrl.isEmpty ||
        imageUrl == 'null';
  }

  // Show What's New Dialog with API data
  void _showWhatsNewDialog() async {
    // Show loading dialog while fetching
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Fetch What's New items from API
    final supportService = SupportService();
    final result = await supportService.getWhatsNew();

    // Close loading dialog
    if (mounted) {
      Navigator.pop(context);
    }

    // Get items list
    List<dynamic> whatsNewItems = [];
    if (result['success'] == true && result['items'] != null) {
      whatsNewItems = result['items'] as List<dynamic>;
    }

    // Show the What's New dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'What\'s New',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7E5EFD),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Display items from API
                    if (whatsNewItems.isNotEmpty)
                      ...whatsNewItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon (emoji)
                              if (item['icon'] != null)
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  child: Text(
                                    item['icon'],
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              if (item['icon'] != null) const SizedBox(width: 10),
                              
                              // Title and Description
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'] ?? 'New Feature',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7E5EFD),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildDescriptionWithBoldEmail(item['description'] ?? ''),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList()
                    else
                      // Fallback content when API fails or returns empty
                      ...[
                        _buildFallbackFeatureItem(
                          icon: '📧',
                          title: 'Email Receipt',
                          description: 'Forward your receipts to upload@managereceipt.com and we\'ll automatically process them for you.',
                        ),
                        
                        _buildFallbackFeatureItem(
                          icon: '👥',
                          title: 'Workspace Collaboration',
                          description: 'Create and manage shared workspaces with team members for better expense tracking.',
                        ),
                        
                        _buildFallbackFeatureItem(
                          icon: '📊',
                          title: 'Advanced Analytics',
                          description: 'New spending insights and category-wise analytics to help you understand your expenses better.',
                        ),
                        
                        _buildFallbackFeatureItem(
                          icon: '🔍',
                          title: 'Receipt OCR Enhancement',
                          description: 'Improved text recognition for better accuracy in extracting receipt information.',
                        ),
                        
                        _buildFallbackFeatureItem(
                          icon: '💱',
                          title: 'Multi-Currency Support',
                          description: 'Now supporting multiple currencies for international expense tracking.',
                        ),
                        
                        _buildFallbackFeatureItem(
                          icon: '🌙',
                          title: 'Dark Mode',
                          description: 'Enjoy a new dark theme option for reduced eye strain in low-light conditions.',
                        ),
                      ],
                    
                    const SizedBox(height: 16),
                    
                    // Got it button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E5EFD),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Got it!',
                          style: TextStyle(
                            fontSize: 15,
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
        },
      );
    }
  }

  // Helper method to build description text with bold email addresses
  Widget _buildDescriptionWithBoldEmail(String description) {
    final emailPattern = RegExp(r'upload@managereceipt\.com');
    final match = emailPattern.firstMatch(description);
    
    if (match == null) {
      // No email found, return plain text
      return Text(
        description,
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      );
    }
    
    // Split text and make email bold
    final beforeEmail = description.substring(0, match.start);
    final email = match.group(0)!;
    final afterEmail = description.substring(match.end);
    
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Colors.grey),
        children: [
          TextSpan(text: beforeEmail),
          TextSpan(
            text: email,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          TextSpan(text: afterEmail),
        ],
      ),
    );
  }

  // Helper method to build fallback feature items with icons
  Widget _buildFallbackFeatureItem({
    required String icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon (emoji)
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Text(
              icon,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 10),
          
          // Title and Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7E5EFD),
                  ),
                ),
                const SizedBox(height: 4),
                _buildDescriptionWithBoldEmail(description),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Show Report an Issue Dialog
  void _showReportIssueDialog() {
    String? selectedIssueType;
    final TextEditingController issueDescriptionController = TextEditingController();
    PlatformFile? attachedFile;
    String? issueTypeError;
    String? descriptionError;
    bool hasAttemptedSubmit = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Full country list and controller for searchable input
            const List<String> allCountries = [
              'Afghanistan','Albania','Algeria','Andorra','Angola','Antigua and Barbuda','Argentina','Armenia','Australia','Austria','Azerbaijan',
              'Bahamas','Bahrain','Bangladesh','Barbados','Belarus','Belgium','Belize','Benin','Bhutan','Bolivia','Bosnia and Herzegovina','Botswana','Brazil','Brunei','Bulgaria','Burkina Faso','Burundi',
              'Cabo Verde','Cambodia','Cameroon','Canada','Central African Republic','Chad','Chile','China','Colombia','Comoros','Congo (Congo-Brazzaville)','Costa Rica','Cote d\'Ivoire','Croatia','Cuba','Cyprus','Czechia',
              'Democratic Republic of the Congo','Denmark','Djibouti','Dominica','Dominican Republic',
              'Ecuador','Egypt','El Salvador','Equatorial Guinea','Eritrea','Estonia','Eswatini','Ethiopia',
              'Fiji','Finland','France',
              'Gabon','Gambia','Georgia','Germany','Ghana','Greece','Grenada','Guatemala','Guinea','Guinea-Bissau','Guyana',
              'Haiti','Honduras','Hungary',
              'Iceland','India','Indonesia','Iran','Iraq','Ireland','Israel','Italy',
              'Jamaica','Japan','Jordan',
              'Kazakhstan','Kenya','Kiribati','Kuwait','Kyrgyzstan',
              'Laos','Latvia','Lebanon','Lesotho','Liberia','Libya','Liechtenstein','Lithuania','Luxembourg',
              'Madagascar','Malawi','Malaysia','Maldives','Mali','Malta','Marshall Islands','Mauritania','Mauritius','Mexico','Micronesia','Moldova','Monaco','Mongolia','Montenegro','Morocco','Mozambique','Myanmar',
              'Namibia','Nauru','Nepal','Netherlands','New Zealand','Nicaragua','Niger','Nigeria','North Korea','North Macedonia','Norway',
              'Oman',
              'Pakistan','Palau','Panama','Papua New Guinea','Paraguay','Peru','Philippines','Poland','Portugal',
              'Qatar',
              'Romania','Russia','Rwanda',
              'Saint Kitts and Nevis','Saint Lucia','Saint Vincent and the Grenadines','Samoa','San Marino','Sao Tome and Principe','Saudi Arabia','Senegal','Serbia','Seychelles','Sierra Leone','Singapore','Slovakia','Slovenia','Solomon Islands','Somalia','South Africa','South Korea','South Sudan','Spain','Sri Lanka','Sudan','Suriname','Sweden','Switzerland','Syria',
              'Taiwan','Tajikistan','Tanzania','Thailand','Timor-Leste','Togo','Tonga','Trinidad and Tobago','Tunisia','Turkey','Turkmenistan','Tuvalu',
              'Uganda','Ukraine','United Arab Emirates','United Kingdom','United States','Uruguay','Uzbekistan',
              'Vanuatu','Vatican City','Venezuela','Vietnam',
              'Yemen',
              'Zambia','Zimbabwe'
            ];
            // Validation function
            bool isValid() {
              issueTypeError = null;
              descriptionError = null;
              
              if (selectedIssueType == null) {
                issueTypeError = 'Please select an issue type';
              }
              
              if (issueDescriptionController.text.trim().isEmpty) {
                descriptionError = 'Please provide a description';
              } else if (RegExp(r'(<[^>]*>|`{3,}|</?script|javascript:)', caseSensitive: false)
                  .hasMatch(issueDescriptionController.text)) {
                descriptionError = 'Please avoid adding code or scripts in the description';
              } else if (issueDescriptionController.text.trim().length > 2000) {
                descriptionError = 'Description cannot exceed 2000 characters';
              }
              
              return issueTypeError == null && descriptionError == null;
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Share Feedback',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7E5EFD),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogContext),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Issue Type Dropdown
                      const Text(
                        'Issue Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedIssueType,
                        decoration: InputDecoration(
                          hintText: 'Select Feedback type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          errorText: hasAttemptedSubmit ? issueTypeError : null,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Bug/Error',
                            child: Text('Bug/Error'),
                          ),
                          DropdownMenuItem(
                            value: 'Feature Request',
                            child: Text('Feature Request'),
                          ),
                          DropdownMenuItem(
                            value: 'Performance ',
                            child: Text('Performance Issue'),
                          ),
                          DropdownMenuItem(
                            value: 'User Interface',
                            child: Text('UI/UX Issue'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedIssueType = value;
                            if (hasAttemptedSubmit) {
                              issueTypeError = null; // Clear error when user selects
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // Issue Description
                      const Text(
                        'Describe the issue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(You can include issue screenshot)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: issueDescriptionController,
                        maxLines: 5,
                        maxLength: 2000,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'[<>`]')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            if (hasAttemptedSubmit) {
                              descriptionError = null; // Clear error when user types
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Please describe the issue you\'re experiencing in detail...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          errorText: hasAttemptedSubmit ? descriptionError : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Attach Screenshot
                      const Text(
                        'Attach Screenshot (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            allowMultiple: false,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            setState(() {
                              attachedFile = result.files.first;
                            });
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey.shade400, style: BorderStyle.solid, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('📤', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                attachedFile == null ? 'Choose File' : attachedFile!.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey,
                                side: const BorderSide(color: Colors.grey),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isValid() ? () async {
                                await _submitIssue(
                                  issueType: selectedIssueType!,
                                  description: issueDescriptionController.text.trim(),
                                  attachedFile: attachedFile,
                                );
                                
                                Navigator.pop(dialogContext);
                              } : () {
                                // Trigger validation and show errors
                                setState(() {
                                  hasAttemptedSubmit = true;
                                  isValid(); // This will set the error messages
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7E5EFD),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Submit Issue via API (Authenticated)
  Future<void> _submitIssue({
    required String issueType,
    required String description,
    PlatformFile? attachedFile,
  }) async {
    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      String? screenshotUrl;
      if (attachedFile != null) {
        try {
          final uri = Uri.parse('https://api.cloudinary.com/v1_1/ds1lqhvc3/image/upload');
          final request = http.MultipartRequest('POST', uri)
            ..fields['upload_preset'] = 'feedback_ss';
          if (attachedFile.bytes != null) {
            request.files.add(http.MultipartFile.fromBytes('file', attachedFile.bytes!, filename: attachedFile.name));
          } else if (attachedFile.path != null) {
            request.files.add(await http.MultipartFile.fromPath('file', attachedFile.path!, filename: attachedFile.name));
          }
          final uploadResponse = await request.send();
          final body = await uploadResponse.stream.bytesToString();
          if (uploadResponse.statusCode == 200) {
            final data = json.decode(body);
            screenshotUrl = data['secure_url'] ?? data['url'];
          }
        } catch (e) {
          // ignore upload failure and continue without screenshotUrl
        }
      }

      final response = await ApiService.post(
        '/support/report-issue/authenticated',
        body: {
          'userId': widget.userId,
          'issueType': issueType,
          'description': description,
          if (screenshotUrl != null) 'screenshotUrl': screenshotUrl,
        },
        token: widget.token,
      );

      // Close loading indicator
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Thank you for reporting the issue! We will look into it soon.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // Error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit issue. Please try again.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error submitting issue: $e');
      
      // Close loading indicator if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit issue. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Build receipt limit bar widget using SubscriptionProvider
  Widget _buildReceiptLimitBar() {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        if (subscriptionProvider.isUnlimited) return const SizedBox.shrink();

        final progress = subscriptionProvider.receiptLimit > 0
            ? subscriptionProvider.currentReceiptCount / subscriptionProvider.receiptLimit
            : 0.0;
        final isNearLimit = progress >= 0.8;
        final isAtLimit = subscriptionProvider.currentReceiptCount >= subscriptionProvider.receiptLimit;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${subscriptionProvider.currentReceiptCount} of ${subscriptionProvider.receiptLimit} Free Receipts Used',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isAtLimit ? Colors.red.shade700 : const Color(0xFF7E5EFD),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubscriptionPlansScreen(
                            userId: widget.userId,
                            token: widget.token,
                          ),
                        ),
                      ).then((_) {
                        // Refresh subscription data when returning from upgrade screen
                        subscriptionProvider.refreshSubscriptionData(
                          token: widget.token,
                          userId: widget.userId, userI: '',
                        );
                      });
                    },
                    child: Text(
                      'Unlock More',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isAtLimit ? Colors.red.shade700 : const Color(0xFF7E5EFD),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isAtLimit
                        ? Colors.red.shade600
                        : isNearLimit
                        ? Colors.orange.shade600
                        : const Color(0xFF7E5EFD),
                  ),
                  minHeight: 8,
                ),
              ),
              if (isAtLimit) ...[
                const SizedBox(height: 8),
                Text(
                  'You\'ve reached your receipt limit. Upgrade to add more!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildReceiptsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
        ),
      );
    }

    if (savedReceipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No receipts uploaded yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first receipt above',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: savedReceipts.length,
      itemBuilder: (context, index) {
        final receipt = savedReceipts[index];
        final imageUrl = receipt['decryptedImageLink'] ?? receipt['imageLink'] ?? '';
        final merchant = receipt['merchant']?.toString() ?? 'Unknown';
        final amount = receipt['amount']?.toString() ?? '0';
        final category = receipt['category']?.toString() ?? 'Uncategorized';
        final hasReminder = receipt['hasReminder'] ?? false; // Use API flag
        final hasSplit = receipt['hasSplitBill'] ?? false; // Use API flag

        String formattedDate = 'No date';
        if (receipt['receiptDate'] != null) {
          try {
            final DateTime? date = _parseDate(receipt['receiptDate']);
            if (date != null) {
              formattedDate = DateFormat('MMM d, yyyy').format(date);
            }
          } catch (e) {
            debugPrint('Error parsing date: $e');
          }
        }

        final isPdf = imageUrl.toLowerCase().endsWith('.pdf');
        final isManual = _isManualReceipt(receipt);

        final userProvider = Provider.of<UserProvider>(context);
        final settingsProvider = Provider.of<SettingsProvider>(context);
        final currencySymbol =
            userProvider.currencySymbol ?? settingsProvider.currencySymbol;

        return GestureDetector(
          onTap: () async {
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
              // Fetch fresh receipt details from API
              final receiptId = receipt['id']?.toString() ?? '';
              final response = await ApiService.get(
                '/receipts/details/$receiptId?userId=${widget.userId}',
                token: widget.token,
              );

              // Close loading indicator
              if (mounted) Navigator.pop(context);

              if (response.statusCode == 200) {
                final data = json.decode(response.body);
                final freshReceipt = data['receipt'] ?? data;

                // Decrypt image URL
                final encryptedImageLink = freshReceipt['imageLink'] as String?;
                String decryptedImageUrl = imageUrl; // fallback to list data
                if (encryptedImageLink != null) {
                  final decrypted = EncryptionHelper.decryptUrl(encryptedImageLink);
                  if (decrypted != null) {
                    decryptedImageUrl = decrypted;
                    freshReceipt['decryptedImageLink'] = decryptedImageUrl;
                    debugPrint('🔓 Dashboard - Decrypted image URL: $decryptedImageUrl');
                  }
                }

                final isPdfFresh = decryptedImageUrl.toLowerCase().endsWith('.pdf');
                final isManualFresh = _isManualReceipt(freshReceipt);

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReceiptDetailsScreen(
                      receipt: freshReceipt,
                      imageUrl: decryptedImageUrl,
                      userId: widget.userId,
                      imageId: freshReceipt['imageId']?.toString() ?? '',
                      isNewReceipt: false,
                      isPdf: isPdfFresh,
                      isManualReceipt: isManualFresh,
                    ),
                  ),
                );

                // Only refresh if receipt was actually modified
                await _handleReceiptSaveResult(
                  result,
                  refreshLimit: true,
                );
              } else {
                // API failed, show error
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to load receipt details. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } catch (e) {
              // Close loading indicator if still showing
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              
              debugPrint('Error fetching receipt details: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to load receipt details. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8E6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Center(
                    child: Builder(
                      builder: (context) {
                        final brandIcon = getMerchantIcon(merchant);
                        final brandColor = getMerchantColor(merchant);
                        final emoji = getMerchantEmoji(merchant) ?? getCategoryEmoji(category);
                        final icon = brandIcon ?? getCategoryIcon(category);
                        final color = brandColor ?? getCategoryColor(category);
                        if (emoji != null) {
                          return Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          );
                        }
                        return CircleAvatar(
                          radius: 22,
                          backgroundColor: color.withOpacity(0.15),
                          child: Icon(icon, size: 24, color: color),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchant,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Category on the left
                            Expanded(
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7E5EFD),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Centered icons
                            if (hasReminder || hasSplit)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasReminder)
                                    const Icon(
                                      Icons.notifications_active,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                  if (hasReminder && hasSplit)
                                    const SizedBox(width: 4),
                                  if (hasSplit)
                                    const Icon(
                                      Icons.call_split,
                                      size: 16,
                                      color: Colors.orange,
                                    ),
                                ],
                              ),
                          ],
                        ),
                        // Duplicate badge if duplicates exist
                        if (_hasDuplicateInfo(receipt))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: DuplicateReceiptBadge(
                              duplicateReceipts: _extractDuplicateReceipts(receipt),
                              onResolve: () {
                                _showDuplicateDialog(context, receipt);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),


                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$currencySymbol$amount',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Price Breakup removed from dashboard - only shown on receipt detail screen
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use web-optimized layout for web platform
    if (kIsWeb) {
      return WebDashboardLayout(
        userId: widget.userId,
        token: widget.token,
        savedReceipts: savedReceipts,
        isLoading: _isLoading,
        isLoadingUserName: _isLoadingUserName,
        userName: _userName,
        onRefresh: () async {
          await _fetchSavedReceipts();
          await _refreshUserName();
          await _fetchBanners(forceRefresh: true);
          final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
          await subscriptionProvider.refreshSubscriptionData(
            token: widget.token,
            userId: widget.userId,
            userI: '',
          );
          await subscriptionProvider.refreshReceiptLimit(
            token: widget.token,
            userId: widget.userId,
          );
        },
        onPickAndUploadImageFromCamera: _pickAndUploadImageFromCamera,
        onShowUploadDialog: _showUploadDialog,
        onPickFilesDirectly: (BuildContext dialogContext) async {
          await _pickAndUploadFile();
        },
        onCreateManualReceipt: _createManualReceipt,
        onCreateTrackDistanceReceipt: _createTrackDistanceReceipt,
        onEmailReceiptInfo: () {
          // Navigate to email receipts screen or show dialog
          Navigator.pushNamed(context, '/email_receipts');
        },
        onCreateExpenseReport: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportsScreen(userId: widget.userId),
            ),
          );
        },
        onReceiptTap: (context, receipt) async {
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
            final receiptId = receipt['id']?.toString() ?? '';
            final response = await ApiService.get(
              '/receipts/details/$receiptId?userId=${widget.userId}',
              token: widget.token,
            );

            if (context.mounted) Navigator.pop(context);

            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final freshReceipt = data['receipt'] ?? data;

              final encryptedImageLink = freshReceipt['imageLink'] as String?;
              String decryptedImageUrl = receipt['decryptedImageLink'] ?? receipt['imageLink'] ?? '';
              if (encryptedImageLink != null) {
                final decrypted = EncryptionHelper.decryptUrl(encryptedImageLink);
                if (decrypted != null) {
                  decryptedImageUrl = decrypted;
                  freshReceipt['decryptedImageLink'] = decryptedImageUrl;
                }
              }

              if (context.mounted) {
                final result = await showDialog(
                  context: context,
                  builder: (context) => ReviewExtractedDataDialog(
                    receipt: freshReceipt,
                    imageUrl: decryptedImageUrl,
                    userId: widget.userId,
                    token: widget.token,
                    onRefresh: () async {
                      await _fetchSavedReceipts();
                      await _refreshUserName();
                    },
                  ),
                );

                if (result == true) {
                  await _handleReceiptSaveResult(result, refreshLimit: true);
                }
              }
            }
          } catch (e) {
            if (context.mounted && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to load receipt details. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        onLogout: () => _logout(context),
        onNavigateToReports: () async {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportsScreen(userId: widget.userId),
            ),
          );
        },
        banners: _banners,
        isLoadingBanners: _isLoadingBanners,
        isUploading: _isUploading,
        uploadStatus: _uploadStatus,
        currentStep: _currentStep,
        uploadSteps: _uploadSteps,
      );
    }

    // Mobile layout (existing implementation)
    final scaffold = Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // MR Logo square
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF905CFF), Color(0xFF7A4BD9)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF905CFF).withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'MR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Manage Receipt text
            const Text(
              'Manage Receipt',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black, size: 28),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          // Menu button
          PopupMenuButton<String>(
            icon: const Text(
              '⋯',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            color: Colors.white,
            offset: const Offset(0, 50),
            elevation: 8,
            onSelected: (value) {
              if (value == 'whats_new') {
                _showWhatsNewDialog();
              } else if (value == 'report_issue') {
                _showReportIssueDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'whats_new',
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.orange, size: 24),
                    SizedBox(width: 12),
                    Text('What\'s New'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'report_issue',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.red, size: 24),
                    SizedBox(width: 12),
                    Text('Share Feedback'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isUploading
          ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
              ),
              const SizedBox(height: 24),
              Text(
                _uploadStatus,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we process your receipt',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _uploadSteps.length,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF7E5EFD),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Step ${_currentStep + 1} of ${_uploadSteps.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        )
          : RefreshIndicator(
          onRefresh: () async {
            await _fetchSavedReceipts();
            await _refreshUserName();
            await _fetchBanners(forceRefresh: true);
            // Refresh subscription data
            final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
            await subscriptionProvider.refreshSubscriptionData(
              token: widget.token,
              userId: widget.userId, userI: '',
            );
            await subscriptionProvider.refreshReceiptLimit(
              token: widget.token,
              userId: widget.userId,
            );
          },
          color: const Color(0xFF7E5EFD),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 4),
                  // Banner Carousel (Refer & Earn and other banners)
                  _buildBannerCarousel(),
                  const SizedBox(height: 24),
                  // Enhanced welcome message with better fallback handling
                  Consumer<UserProvider>(
                    builder: (context, userProvider, child) {
                      // Priority order: UserProvider -> local state -> fallback
                      String displayName = 'User';

                      if (userProvider.username != null && userProvider.username!.isNotEmpty) {
                        displayName = userProvider.username!;
                      } else if (_userName.isNotEmpty && _userName != 'User') {
                        displayName = _userName;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Hi $displayName!',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              if (_isLoadingUserName) ...[
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(width: 8),
                                const Text(
                                  '👋',
                                  style: TextStyle(fontSize: 24),
                                ),
                              ],
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Three receipt action cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isUploading ? null : _pickAndUploadImageFromCamera,
                                child: Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFF1F5FF),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7E5EFD).withOpacity(0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 4,
                                            color: const Color(0xFF7E5EFD),
                                          ),
                                        ),
                                        Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF7E5EFD).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                  child: const Center(
                                                    child: Text(
                                                      '📷',
                                                      style: TextStyle(fontSize: 24),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  'Scan',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black,
                                                    decoration: TextDecoration.none,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  overflow: TextOverflow.visible,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isUploading ? null : _showUploadDialog,
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFF1F5FF),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 4,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  '📤',
                                                  style: TextStyle(fontSize: 24),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Upload',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black,
                                                decoration: TextDecoration.none,
                                              ),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.visible,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isUploading ? null : _createManualReceipt,
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFF1F5FF),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 4,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  '📝',
                                                  style: TextStyle(fontSize: 24),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Manual',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black,
                                                decoration: TextDecoration.none,
                                              ),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.visible,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                  },
                  ),
                  const SizedBox(height: 32),

                  // Recent Activity section
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
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReportsScreen(
                                userId: widget.userId,
                              ),
                            ),
                          );
                        },
                        child: const Row(
                          children: [
                            Text(
                              'View all',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF7E5EFD),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: Color(0xFF7E5EFD),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildReceiptsList(),
                ],
              ),
            ),
          ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentRoute: 'dashboard',
        userId: widget.userId,
        token: widget.token,
        onUploadTap: _showUploadBottomSheet,
      ),
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Stack(
        children: [
          scaffold,
          if (_showPointsCelebration)
            _PointsCelebrationOverlay(
              points: _recentPointsAwarded,
              onContinue: _dismissPointsCelebrationAndAnimate,
            ),
        ],
      ),
    );
  }


  Widget _buildReceiptActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border(
            top: BorderSide(color: borderColor, width: 4),
            left: const BorderSide(color: Color(0xFFF1F5FF), width: 1),
            right: const BorderSide(color: Color(0xFFF1F5FF), width: 1),
            bottom: const BorderSide(color: Color(0xFFF1F5FF), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.08),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    iconColor.withOpacity(0.1),
                    iconColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  /// Fetch banners from API
  Future<void> _fetchBanners({bool forceRefresh = false}) async {
    debugPrint('Dashboard - _fetchBanners called (forceRefresh: $forceRefresh)');
    
    if (mounted) {
      setState(() {
        _isLoadingBanners = true;
      });
    }

    try {
      debugPrint('Dashboard - Creating BannerService instance...');
      final bannerService = BannerService();
      debugPrint('Dashboard - Calling bannerService.fetchBanners...');
      final banners = await bannerService.fetchBanners(forceRefresh: forceRefresh);
      debugPrint('Dashboard - Received ${banners.length} banners from API');

      if (mounted) {
        setState(() {
          _banners = banners;
          _isLoadingBanners = false;
        });
        debugPrint('Dashboard - Banners state updated. Total banners: ${_banners.length}');
      }
    } catch (e, stackTrace) {
      debugPrint('Dashboard - Error fetching banners: $e');
      debugPrint('Dashboard - Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingBanners = false;
        });
      }
    }
  }

  /// Build banner carousel widget
  Widget _buildBannerCarousel() {
    if (_isLoadingBanners) {
      // Show loading placeholder or return empty
      return const SizedBox.shrink();
    }

    if (_banners.isEmpty) {
      // Return empty if no banners from API - no fallback banner
      return const SizedBox.shrink();
    }

    // Filter banners that are currently visible
    final visibleBanners = _banners.where((BannerModel banner) => banner.isVisible).toList();

    if (visibleBanners.isEmpty) {
      // Return empty if no visible banners - no fallback banner
      return const SizedBox.shrink();
    }

    return BannerCarousel(banners: visibleBanners);
  }

  // Price Breakup functionality removed from dashboard - only available on receipt detail screen
}

class _CoinJumpOverlay extends StatelessWidget {
  final Animation<double> animation;
  final Offset start;
  final Offset end;
  final int pointsAwarded;

  const _CoinJumpOverlay({
    required this.animation,
    required this.start,
    required this.end,
    required this.pointsAwarded,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value.clamp(0.0, 1.0);
          const holdFraction = 0.35;
          final bool inHoldPhase = t < holdFraction;
          final double travelT = inHoldPhase ? 0.0 : ((t - holdFraction) / (1 - holdFraction)).clamp(0.0, 1.0);
          final dx = inHoldPhase ? start.dx : _lerp(start.dx, end.dx, travelT);
          final dyBase = inHoldPhase ? start.dy : _lerp(start.dy, end.dy, travelT);
          final jump = inHoldPhase ? 0.0 : -4 * (travelT - 0.5) * (travelT - 0.5) + 1;
          final dy = dyBase - (inHoldPhase ? 0.0 : jump * 90);
          final opacity = t < 0.9 ? 1.0 : (1 - (t - 0.9) / 0.1).clamp(0.0, 1.0);

          return SizedBox.expand(
            child: Stack(
              children: [
                Positioned(
                  left: dx,
                  top: dy,
                  child: Opacity(
                    opacity: opacity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '+$pointsAwarded',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const _RewardCoinIcon(size: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

double _lerp(double start, double end, double t) {
  return start + (end - start) * t;
}

class _PointsCelebrationOverlay extends StatefulWidget {
  final int points;
  final VoidCallback onContinue;

  const _PointsCelebrationOverlay({
    required this.points,
    required this.onContinue,
  });

  @override
  State<_PointsCelebrationOverlay> createState() => _PointsCelebrationOverlayState();
}

class _PointsCelebrationOverlayState extends State<_PointsCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _autoCloseTimer;
  final List<_ConfettiPiece> _confettiPieces = [];
  final Random _random = Random();
  static const int _confettiCount = 35;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _generateConfetti();
    _autoCloseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onContinue();
      }
    });
  }

  void _generateConfetti() {
    _confettiPieces.clear();
    const colors = [
      Color(0xFFFFD700),
      Color(0xFF7C57FF),
      Color(0xFFFF4081),
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
    ];

    for (int i = 0; i < _confettiCount; i++) {
      _confettiPieces.add(
        _ConfettiPiece(
          startX: _random.nextDouble(),
          phase: _random.nextDouble(),
          speed: 0.8 + _random.nextDouble() * 0.6,
          size: 6 + _random.nextDouble() * 4,
          color: colors[_random.nextInt(colors.length)],
          swing: -18 + _random.nextDouble() * 36,
          rotation: (_random.nextDouble() * 2 + 1) * pi,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            color: Colors.black.withOpacity(0.6),
            alignment: Alignment.center,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth = min(constraints.maxWidth * 0.72, 300);
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Stack(
                            children: [
                              Container(
                                width: cardWidth,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 25,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _RewardCoinIcon(size: 56),
                                    const SizedBox(height: 16),
                                    Text(
                                      '+${widget.points} Points Earned!',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF7C57FF),
                                        decoration: TextDecoration.none,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Keep earning more MR Bucks!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF7C57FF),
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.none,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 120,
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _ConfettiPainter(
                                      pieces: _confettiPieces,
                                      progress: _controller.value,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiPiece {
  final double startX;
  final double phase;
  final double speed;
  final double size;
  final Color color;
  final double swing;
  final double rotation;

  _ConfettiPiece({
    required this.startX,
    required this.phase,
    required this.speed,
    required this.size,
    required this.color,
    required this.swing,
    required this.rotation,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;

  _ConfettiPainter({
    required this.pieces,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final t = (progress * piece.speed + piece.phase) % 1.0;
      final dx = piece.startX * size.width + sin(t * pi * 2) * piece.swing;
      final dy = t * size.height;

      if (dy < 0 || dy > size.height) continue;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(t * piece.rotation);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: piece.size,
        height: piece.size * 1.4,
      );
      final paint = Paint()..color = piece.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pieces != pieces;
  }
}

class _RewardCoinIcon extends StatelessWidget {
  final double size;

  const _RewardCoinIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    final double innerSize = size * 0.76;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.55),
            blurRadius: size * 0.18,
            spreadRadius: size * 0.04,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: innerSize,
          height: innerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Icon(
            Icons.workspace_premium,
            color: Colors.orange.shade700,
            size: innerSize * 0.6,
          ),
        ),
      ),
    );
  }
}
