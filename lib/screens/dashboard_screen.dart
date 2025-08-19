import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
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
import '../services/auth_manager.dart';
import 'package:flutter/services.dart';
import '../utils/encryption_helper.dart';
import '../utils/category_icons.dart';
import 'package:flutter/scheduler.dart';

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

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
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
        final result = await ShareIntentService.handleSharedFilePreview(
          File(sharedPath),
          onProgress: (status, message) {
            debugPrint('ShareIntent: Progress $status - ${message ?? ''}');
            ShareIntentHandler.showProcessingDialogWithProgress(context, status, message);
          },
        ).timeout(const Duration(seconds: 60));

        debugPrint('ShareIntent: Result status=${result.status} hasReceiptDetails=${result.receiptDetails != null}');
        
        if (result.status == ShareIntentStatus.completed && result.receiptDetails != null) {
          // Dismiss processing dialog
          if (mounted) ShareIntentHandler.dismissProcessingDialog(context);
          
          // Convert ReceiptDetails to receipt map for ReceiptDetailsScreen
          final receiptDetails = result.receiptDetails!;
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
          
          final saved = await Navigator.of(context).push<bool>(
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
          
          // Refresh receipts if user saved the receipt
          if (saved == true) {
            await _fetchSavedReceipts();
          }
          
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
              content: Text(result.error ?? 'Failed to process shared file. Please try again.'),
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
      case 3: // MR Bucks
        Navigator.pushNamed(context, '/mr_bucks');
        break;
      case 4: // More
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MoreOptionsScreen(
              userId: widget.userId,
              token: widget.token,
            ),
          ),
        );
        break;
    }
  }

  void _showUploadBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Upload Receipt',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7E5EFD),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E5EFD).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: Text('📷', style: TextStyle(fontSize: 20))),
                  ),
                  title: const Text('Take Receipt Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Capture a photo of your receipt'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImageFromCamera();
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E5EFD).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: Text('📤', style: TextStyle(fontSize: 20))),
                  ),
                  title: const Text('Upload Receipt', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Select from your gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    // Show Photos/Documents choice before proceeding
                    _showUploadDialog();
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E5EFD).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: Text('📝', style: TextStyle(fontSize: 20))),
                  ),
                  title: const Text('Add Manual Receipt', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Enter receipt details manually'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _createManualReceipt();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
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

      // Fetch receipts and subscription data in parallel
      if (mounted) {
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
        ]);
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

    // Only refresh if receipt was actually saved
    if (result == true) {
      await _fetchSavedReceipts();
      // Increment receipt count locally for immediate UI update
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      subscriptionProvider.incrementReceiptCount();
    }
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

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
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
          if (result == true) {
            await _fetchSavedReceipts();
            // Increment receipt count locally for immediate UI update
            final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
            subscriptionProvider.incrementReceiptCount();
          }
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
          if (result == true) {
            await _fetchSavedReceipts();
            // Increment receipt count locally for immediate UI update
            final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
            subscriptionProvider.incrementReceiptCount();
          }
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
                if (result == true) {
                  await _fetchSavedReceipts();
                  // Refresh receipt limit after modification
                  final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
                  await subscriptionProvider.refreshReceiptLimit(
                    token: widget.token,
                    userId: widget.userId,
                  );
                }
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF7E5EFD),
          elevation: 0,
          title: const Center(
            child: AppLogo(isHeaderLogo: true),
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 28),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
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
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
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

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Welcome, $displayName!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF7E5EFD),
                            ),
                            textAlign: TextAlign.center,
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
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your receipts, organized and accessible\nin one place.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Receipt limit bar (using cached data from SubscriptionProvider)
                  _buildReceiptLimitBar(),

                  const SizedBox(height: 16),

                  // Take Receipt Photo Button
                  ElevatedButton(
                    onPressed: _isUploading
                        ? null
                        : _pickAndUploadImageFromCamera,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E5EFD),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('📷', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text(
                          'Take Receipt Photo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Upload Receipt Button
                  OutlinedButton(
                    onPressed: _isUploading ? null : _showUploadDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7E5EFD),
                      side: const BorderSide(color: Color(0xFF7E5EFD)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('📤', style: TextStyle(fontSize: 16, color: Color(0xFF7E5EFD))),
                        SizedBox(width: 8),
                        Text(
                          'Upload Receipt',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7E5EFD),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Manual Receipt Button
                  OutlinedButton(
                    onPressed: _isUploading ? null : _createManualReceipt,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7E5EFD),
                      side: const BorderSide(color: Color(0xFF7E5EFD)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('📝', style: TextStyle(fontSize: 16, color: Color(0xFF7E5EFD))),
                        SizedBox(width: 8),
                        Text(
                          'Add Manual Receipt',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7E5EFD),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Text(
                          'Recent Uploads',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your Latest Receipts at a Glance!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildReceiptsList(),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Consumer<FeatureFlagsProvider>(
          builder: (context, featureFlagsProvider, child) {
            return BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF7E5EFD),
              unselectedItemColor: Colors.grey.shade600,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              currentIndex: 0, // Home is selected by default
              onTap: (index) {
                _onBottomNavTap(index);
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined, size: 26),
                  activeIcon: Icon(Icons.home, size: 28),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.analytics_outlined, size: 26),
                  activeIcon: Icon(Icons.analytics, size: 28),
                  label: 'Reports',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline, size: 26),
                  activeIcon: Icon(Icons.add_circle, size: 28),
                  label: 'Upload',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.savings_outlined, size: 26),
                  activeIcon: Icon(Icons.savings, size: 28),
                  label: 'MR Bucks',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.more_horiz, size: 26),
                  activeIcon: Icon(Icons.more_horiz, size: 28),
                  label: 'More',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Price Breakup functionality removed from dashboard - only available on receipt detail screen
}
