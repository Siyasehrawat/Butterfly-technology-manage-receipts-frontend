import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/dashboard_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/expense_reports_screen.dart';
import '../screens/split_receipts_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/welcome_screen.dart';
import '../services/auth_service.dart';
import '../services/auth_manager.dart';
import '../providers/user_provider.dart';
import '../providers/subscription_provider_bypass.dart';
import '../providers/feature_flags_provider.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/wallet_onboarding_screen.dart';
import '../screens/wallet_pin_entry_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/tax_reports_screen.dart';
import '../services/api_service_bypass.dart'; // Import ApiService
import 'dart:convert'; // For json.decode
import '../screens/analytics_screen.dart';
import '../screens/bill_reminders_screen.dart';

class AppDrawer extends StatefulWidget {
  final String userId;
  final String token;
  final Function? onLogout;
  final Future<void> Function() onNavigateToReports;
  final String? displayName;

  const AppDrawer({
    super.key,
    required this.userId,
    this.token = '',
    this.onLogout,
    required this.onNavigateToReports,
    this.displayName,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Add state for expandable Reports section
  bool _isReportsExpanded = false;

  @override
  void initState() {
    super.initState();
    // Add a small delay to ensure UserProvider is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Extra small delay to ensure everything is ready
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        _initializeSubscriptionData();
        _initializeFeatureFlags();
      }
    });
  }

  Future<void> _initializeSubscriptionData() async {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    await subscriptionProvider.initFromCache();

    // Prefer props, but fall back to UserProvider if missing
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String effectiveToken = (widget.token.isNotEmpty)
        ? widget.token
        : (userProvider.token ?? '');
    final String effectiveUserId = (widget.userId.isNotEmpty)
        ? widget.userId
        : (userProvider.userId ?? '');

    await subscriptionProvider.fetchSubscriptionStatus(
      token: effectiveToken,
      userId: effectiveUserId,
    );
  }

  Future<void> _initializeFeatureFlags() async {
    try {
      final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
      await featureFlagsProvider.initFromCache();

      // Prefer props, but fall back to UserProvider if missing
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final String effectiveToken = (widget.token.isNotEmpty)
          ? widget.token
          : (userProvider.token ?? '');
      final String effectiveUserId = (widget.userId.isNotEmpty)
          ? widget.userId
          : (userProvider.userId ?? '');

      debugPrint('AppDrawer - Initializing feature flags with token: ${effectiveToken.isNotEmpty ? 'present' : 'missing'}, userId: ${effectiveUserId.isNotEmpty ? 'present' : 'missing'}');

      // Use safe fetch method with validation
      final fetchAttempted = await featureFlagsProvider.safeFetchFeatureFlags(
        token: effectiveToken,
        userId: effectiveUserId,
      );
      
      if (!fetchAttempted) {
        debugPrint('AppDrawer - Warning: Could not fetch feature flags due to missing credentials');
        debugPrint('AppDrawer - Props: token=${widget.token.isNotEmpty ? 'present' : 'missing'}, userId=${widget.userId.isNotEmpty ? 'present' : 'missing'}');
        debugPrint('AppDrawer - UserProvider: token=${userProvider.token?.isNotEmpty == true ? 'present' : 'missing'}, userId=${userProvider.userId?.isNotEmpty == true ? 'present' : 'missing'}');
      }
    } catch (e) {
      debugPrint('AppDrawer - Error initializing feature flags: $e');
    }
  }

  Future<void> _checkWalletStatusAndNavigate() async {

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);

      // Call the API to check wallet status
      await userProvider.checkAndCacheDocWalletStatus(widget.token);

      // Get the updated status after API call
      final hasWalletSetup = userProvider.hasDocWalletSetup;
      final isPinRequired = featureFlagsProvider.featureFlags.docWalletPinRequired;

      if (mounted) {
        Navigator.pop(context); // Close drawer first

        if (hasWalletSetup) {
          // User has already set up wallet
          if (isPinRequired) {
            // PIN is required, go to PIN entry screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DocWalletPinEntryScreen(
                  userId: widget.userId,
                  token: widget.token,
                ),
              ),
            );
          } else {
            // PIN is not required, go directly to wallet screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MyWalletScreen(
                  userId: widget.userId,
                  token: widget.token,
                ),
              ),
            );
          }
        } else {
          // User hasn't set up wallet, go to onboarding
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyWalletOnboardingScreen(
                userId: widget.userId,
                token: widget.token,
              ),
            ),
          ).then((_) {
            // Refresh status after returning from onboarding
            userProvider.checkAndCacheDocWalletStatus(widget.token);
          });
        }
      }
    } catch (e) {
      print('Error checking wallet status: $e');
      if (mounted) {
        Navigator.pop(context); // Close drawer
        // On error, default to onboarding screen
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
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<UserProvider, SubscriptionProvider, FeatureFlagsProvider>(
      builder: (context, userProvider, subscriptionProvider, featureFlagsProvider, child) {
        final bool hasAdminAccess = userProvider.hasAdminAccess;
        final featureFlags = featureFlagsProvider.featureFlags;

        debugPrint('AppDrawer - Building with admin access: $hasAdminAccess');
        debugPrint('AppDrawer - Feature flags: walletEnabled=${featureFlags.walletEnabled}, docWalletPinRequired=${featureFlags.docWalletPinRequired}');

        return Drawer(
          child: Container(
            color: const Color(0xFF7E5EFD),
            child: Column(
              children: [
                // Fixed Header with user info
                Container(
                  padding: const EdgeInsets.only(top: 50, bottom: 20, left: 24, right: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo on the left with edit button overlay
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: Image.asset(
                                '',
                                width: 20,
                                height: 20,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Text(
                                    'MR',
                                    style: TextStyle(
                                      color: Color(0xFF7E5EFD),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfileScreen(
                                        userId: widget.userId,
                                        token: widget.token,
                                      ),
                                    ),
                                  ).then((nameChanged) async {
                                    // Attempt to refresh username from cache if it may have changed
                                    if (mounted) {
                                      try {
                                        final userProvider = Provider.of<UserProvider>(context, listen: false);
                                        await userProvider.refreshUsernameFromCache();
                                      } catch (_) {}
                                      setState(() {});
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7E5EFD),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Name to the right of logo with edit button
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                (widget.displayName != null && widget.displayName!.trim().isNotEmpty)
                                    ? widget.displayName!.trim()
                                    : userProvider.effectiveUsername,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider after header
                _buildDivider(),

                // Scrollable menu items
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Home
                        _buildDrawerItem(
                          context,
                          icon: Icons.home_outlined,
                          title: 'Home',
                          onTap: () {
                            Navigator.pop(context); // Close drawer first
                            final currentRoute = ModalRoute.of(context)?.settings.name;
                            if (currentRoute != '/dashboard') {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DashboardScreen(
                                    userId: widget.userId,
                                    token: widget.token,
                                  ),
                                ),
                              );
                            }
                          },
                        ),

                        // Divider after Home
                        _buildDivider(),

                        // Reports (expandable section)
                        _buildExpandableReportsSection(context),

                        // Divider after Reports
                        _buildDivider(),

                        // Email Receipts
                        _buildDrawerItem(
                          context,
                          icon: Icons.email_outlined,
                          title: 'Email Receipts',
                          onTap: () {
                            Navigator.pop(context);
                            _showEmailReceiptsDialog();
                          },
                        ),

                        // Divider after Email Receipts
                        _buildDivider(),

                        // Expense Reports
                        _buildDrawerItem(
                          context,
                          icon: Icons.assessment_outlined,
                          title: 'Expense Reports',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ExpenseReportsScreen(
                                  userId: widget.userId,
                                  token: widget.token,
                                ),
                              ),
                            );
                          },
                        ),

                        // Divider after Expense Reports
                        _buildDivider(),

                        // Analytics
                        _buildDrawerItem(
                          context,
                          icon: Icons.analytics_outlined,
                          title: 'Analytics',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AnalyticsScreen(),
                              ),
                            );
                          },
                        ),

                        // Divider after Analytics
                        _buildDivider(),

                        // Bill Reminders
                        _buildDrawerItem(
                          context,
                          icon: Icons.notifications_outlined,
                          title: 'Bill Reminders',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BillRemindersScreen(),
                              ),
                            );
                          },
                        ),

                        _buildDivider(),

                        // Split Receipts (conditionally shown based on feature flag)
                        if (featureFlags.splitBillEnabled) ...[
                          _buildDrawerItem(
                            context,
                            icon: Icons.call_split_outlined,
                            title: 'Split Receipts',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SplitReceiptsScreen(
                                    userId: widget.userId,
                                    token: widget.token,
                                  ),
                                ),
                              );
                            },
                          ),

                          // Divider after Split Receipts
                          _buildDivider(),
                        ],

                        // Doc Wallet (conditionally shown based on feature flag)
                        if (featureFlags.walletEnabled) ...[
                          _buildDrawerItem(
                            context,
                            icon: Icons.wallet_outlined,
                            title: 'Doc Wallet',
                            onTap: _checkWalletStatusAndNavigate,
                          ),
                          _buildDivider(),
                        ],

                        // Admin Panel (only shown if user has admin access)
                        if (hasAdminAccess) ...[
                          _buildDrawerItem(
                            context,
                            icon: Icons.admin_panel_settings_outlined,
                            title: 'Admin Panel',
                            onTap: () {
                              debugPrint('AppDrawer - Admin Panel tapped');
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AdminDashboardScreen(
                                    adminId: widget.userId,
                                    token: widget.token,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildDivider(),
                        ],

                        // Settings
                        _buildDrawerItem(
                          context,
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),

                        // Divider after Settings
                        _buildDivider(),

                        // Logout
                        _buildDrawerItem(
                          context,
                          icon: Icons.logout_outlined,
                          title: 'Logout',
                          onTap: () {
                            Navigator.pop(context);
                            _showLogoutDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandableReportsSection(BuildContext context) {
    return Column(
      children: [
        // Main Reports item (expandable)
        ListTile(
          leading: Icon(
            Icons.receipt_long,
            color: Colors.white,
            size: 28,
          ),
          title: Text(
            'Reports',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: AnimatedRotation(
            turns: _isReportsExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 28,
            ),
          ),
          onTap: () {
            setState(() {
              _isReportsExpanded = !_isReportsExpanded;
            });
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
          dense: false,
          visualDensity: VisualDensity.comfortable,
        ),
        
        // Animated sub-items
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isReportsExpanded ? null : 0,
          child: _isReportsExpanded
              ? Column(
                  children: [
                    // Search Reports sub-item
                    _buildSubDrawerItem(
                      context,
                      icon: Icons.description,
                      title: 'Search Receipts',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReportsScreen(
                              userId: widget.userId,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // Tax Reports sub-item (conditionally shown based on feature flag)
                    if (Provider.of<FeatureFlagsProvider>(context, listen: false).featureFlags.taxReportsEnabled)
                      _buildSubDrawerItem(
                        context,
                        icon: Icons.request_quote,
                        title: 'Tax Reports',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TaxReportsScreen(
                                userId: widget.userId,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSubDrawerItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
      }) {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.white.withOpacity(0.8),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildDrawerItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback? onTap, // Made nullable for loading state
      }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.white,
        size: 28,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      dense: false,
      visualDensity: VisualDensity.comfortable,
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              // Clear subscription cache on logout
              final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
              await subscriptionProvider.clearCache();

              // Use the provided logout function if available
              if (widget.onLogout != null) {
                widget.onLogout!();
                return;
              }

              // Otherwise handle logout here
              final authService = AuthService();
              await authService.signOut();

              // Clear stored auth data
              final authManager = AuthManager();
              await authManager.clearAuthData();

              // Update user provider
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              await userProvider.logout();

              // Navigate to welcome screen and clear navigation stack
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showEmailReceiptsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool copied = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('📧 Email Receipts'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'You can email or forward your receipts from your registered email ID to the following address, and it will automatically process your receipt in the app:',
                ),
                SizedBox(height: 12),
                SelectableText(
                  'upload@managereceipt.com',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: copied ? Colors.green : null,
                  foregroundColor: copied ? Colors.white : null,
                ),
                onPressed: () async {
                  await Clipboard.setData(const ClipboardData(text: 'upload@managereceipt.com'));
                  if (mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.removeCurrentSnackBar();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Email copied')),
                    );
                  }
                  setState(() {
                    copied = true;
                  });
                },
                child: Text(copied ? 'Copied' : 'Copy Email'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}