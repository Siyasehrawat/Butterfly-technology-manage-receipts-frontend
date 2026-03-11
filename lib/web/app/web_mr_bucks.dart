import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../providers/user_provider.dart';
import '../../screens/welcome_screen.dart';
import '../../screens/expense_reports_screen.dart';
import '../../screens/tax_reports_screen.dart';
import '../../screens/analytics_screen.dart';
import '../../screens/bill_reminders_screen.dart';
import '../../screens/split_receipts_screen.dart';
import '../../screens/mr_bucks_screen.dart';
import '../../screens/refer_earn_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/wallet_screen.dart' show MyWalletScreen;
import '../../services/api_service_bypass.dart';

class WebMrBucksScreen extends StatefulWidget {
  final String userId;
  final String token;

  const WebMrBucksScreen({
    Key? key,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<WebMrBucksScreen> createState() => _WebMrBucksScreenState();
}

class _WebMrBucksScreenState extends State<WebMrBucksScreen> {
  int _balance = 1250;
  bool _isLoading = false;
  List<Map<String, dynamic>> _activityLog = [];
  
  @override
  void initState() {
    super.initState();
    _loadMrBucksData();
  }

  Future<void> _loadMrBucksData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load actual data from API (same endpoint as mobile app)
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final response = await ApiService.get(
        '/rewards/users/${userProvider.userId}/points/summary',
        token: userProvider.token ?? '',
        queryParameters: {
          'limit': '50',  // Show more transactions on web
          'offset': '0',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _balance = data['balance'] ?? 1250;
          _activityLog = List<Map<String, dynamic>>.from(data['transactions'] ?? []);
        });
      } else {
        debugPrint('MR Bucks API failed: ${response.statusCode} - ${response.body}');
        // Use mock data if API fails
        _loadMockData();
      }
    } catch (e) {
      debugPrint('Error loading MR Bucks data: $e');
      _loadMockData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadMockData() {
    setState(() {
      _activityLog = [
        {
          'type': 'upload',
          'title': 'Uploaded Receipt',
          'description': 'Elite Fitness Club',
          'date': '2025-04-03',
          'points': 10,
          'balance': 1250,
        },
        {
          'type': 'email',
          'title': 'Email Receipt Upload',
          'description': 'Amazon order',
          'date': '2025-04-02',
          'points': 15,
          'balance': 1240,
        },
        {
          'type': 'export',
          'title': 'Tax Export',
          'description': 'Q1 2025 report',
          'date': '2025-04-01',
          'points': 25,
          'balance': 1225,
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Row(
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
                      padding: const EdgeInsets.all(48.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMrBucksContent(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        children: [
          // Logo/Brand
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7E5EFD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'MR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Manage Receipt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
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
                    _buildNavItem(context, Icons.home, 'Dashboard', false, () {
                      Navigator.pop(context);
                    }),
                    _buildNavItem(context, Icons.search, 'Search Receipts', false, () {}),
                    _buildNavItem(context, Icons.email, 'Email Receipts', false, () {}),
                  ],
                ),
                const SizedBox(height: 8),
                _buildNavSection(
                  context,
                  'REPORTS',
                  [
                    _buildNavItem(context, Icons.description, 'Expense Reports', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ExpenseReportsScreen(userId: widget.userId, token: widget.token)),
                      );
                    }),
                    _buildNavItem(context, Icons.receipt_long, 'Tax Reports', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TaxReportsScreen(userId: widget.userId)),
                      );
                    }),
                    _buildNavItem(context, Icons.bar_chart, 'Analytics', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                _buildNavSection(
                  context,
                  'FEATURES',
                  [
                    _buildNavItem(context, Icons.notifications, 'Bill Reminders', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BillRemindersScreen()),
                      );
                    }),
                    _buildNavItem(context, Icons.people, 'Split Receipts', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SplitReceiptsScreen(userId: widget.userId, token: widget.token)),
                      );
                    }),
                    _buildNavItem(context, Icons.folder, 'Document Wallet', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MyWalletScreen(userId: widget.userId, token: widget.token)),
                      );
                    }),
                    _buildNavItem(context, Icons.monetization_on, 'MR Bucks', true, () {}),
                  ],
                ),
                const SizedBox(height: 8),
                _buildNavSection(
                  context,
                  'ACCOUNT',
                  [
                    _buildNavItem(context, Icons.person_add, 'Refer & Earn', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ReferEarnScreen(userId: widget.userId, token: widget.token)),
                      );
                    }),
                    _buildNavItem(context, Icons.settings, 'Settings', false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    }),
                    _buildNavItem(context, Icons.logout, 'Logout', false, () async {
                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                      await userProvider.logout();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                        (route) => false,
                      );
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
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
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFF0E6FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? const Color(0xFF7E5EFD) : Colors.grey.shade600,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF7E5EFD) : Colors.grey.shade800,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true,
      ),
    );
  }

  Widget _buildUserProfile(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF7E5EFD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                userProvider.username?.isNotEmpty == true
                    ? userProvider.username![0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userProvider.username ?? 'Bhavneesh',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Premium Account',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'MR Bucks',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9500), Color(0xFFFF7300)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$_balance MR Bucks',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.grey),
                    onPressed: () {},
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMrBucksContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // MR Bucks Rewards Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MR Bucks Rewards',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9500), Color(0xFFFF7300)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Balance: $_balance MR Bucks',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // Activity Log Section
        const Text(
          'Activity Log',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        
        const SizedBox(height: 16),
        
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildActivityLogTable(),
        
        const SizedBox(height: 48),
        
        // Redeem Your Points Section
        const Text(
          'Redeem Your Points',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        
        const SizedBox(height: 16),
        
        _buildRedemptionCards(),
      ],
    );
  }

  Widget _buildActivityLogTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Activity',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Points',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Balance',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Table Rows
          ..._activityLog.asMap().entries.map((entry) {
            final index = entry.key;
            final activity = entry.value;
            final isLast = index == _activityLog.length - 1;
            
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: isLast
                      ? BorderSide.none
                      : BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        _getActivityIcon(activity['type']),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity['title'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activity['description'],
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
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      DateFormat('MMM d, yyyy').format(DateTime.parse(activity['date'])),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '+${activity['points']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${activity['balance']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _getActivityIcon(String type) {
    Color bgColor;
    Color iconColor;
    IconData icon;

    switch (type) {
      case 'upload':
        bgColor = const Color(0xFFF0E6FF);
        iconColor = const Color(0xFF7E5EFD);
        icon = Icons.upload_file;
        break;
      case 'email':
        bgColor = const Color(0xFFE3F2FD);
        iconColor = const Color(0xFF2196F3);
        icon = Icons.email;
        break;
      case 'export':
        bgColor = const Color(0xFFFFF3E0);
        iconColor = const Color(0xFFFF9500);
        icon = Icons.file_download;
        break;
      default:
        bgColor = Colors.grey.shade100;
        iconColor = Colors.grey;
        icon = Icons.circle;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  Widget _buildRedemptionCards() {
    return Row(
      children: [
        Expanded(
          child: _buildRedemptionCard(
            icon: Icons.card_giftcard,
            iconColor: const Color(0xFFFF9500),
            iconBgColor: const Color(0xFFFFF3E0),
            title: 'Amazon Gift Card',
            description: '1,000 points = ₹500 voucher',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildRedemptionCard(
            icon: Icons.redeem,
            iconColor: const Color(0xFF7E5EFD),
            iconBgColor: const Color(0xFFF0E6FF),
            title: 'Flipkart Voucher',
            description: '800 points = ₹400 voucher',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildRedemptionCard(
            icon: Icons.restaurant,
            iconColor: const Color(0xFFE91E63),
            iconBgColor: const Color(0xFFFCE4EC),
            title: 'Swiggy Food Credit',
            description: '500 points = ₹250 credit',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildRedemptionCard(
            icon: Icons.favorite,
            iconColor: const Color(0xFF2196F3),
            iconBgColor: const Color(0xFFE3F2FD),
            title: 'Donate to Charity',
            description: 'Support a cause',
          ),
        ),
      ],
    );
  }

  Widget _buildRedemptionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

