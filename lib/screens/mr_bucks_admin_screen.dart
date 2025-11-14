import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service_bypass.dart';
import '../providers/user_provider.dart';

class MrBucksAdminScreen extends StatefulWidget {
  const MrBucksAdminScreen({super.key});

  @override
  State<MrBucksAdminScreen> createState() => _MrBucksAdminScreenState();
}

class _MrBucksAdminScreenState extends State<MrBucksAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  int _totalUsers = 0;
  int _pendingRedemptions = 0;
  bool _loadingStats = true;
  
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _redemptions = [];
  bool _loadingUsers = false;
  bool _loadingRedemptions = false;
  
  final int _limit = 20;
  int _usersOffset = 0;
  int _redemptionsOffset = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _fetchStats();
    await _fetchPendingRedemptions();
  }

  Future<void> _fetchStats() async {
    setState(() => _loadingStats = true);
    
    try {
      // Fetch dashboard data (includes users list, total users, and pending redemptions)
      final dashboardResp = await ApiService.get(
        '/redemptions/admin/dashboard',
        queryParameters: {
          'limit': '20',
          'offset': '0',
        },
      );
      
      debugPrint('Dashboard API Response: ${dashboardResp.statusCode}');
      debugPrint('Dashboard API Body: ${dashboardResp.body}');
      
      if (mounted && dashboardResp.statusCode == 200) {
        final Map<String, dynamic> dashboardJson = json.decode(dashboardResp.body) is Map
            ? Map<String, dynamic>.from(json.decode(dashboardResp.body) as Map)
            : <String, dynamic>{};
        
        final dashboardData = Map<String, dynamic>.from(dashboardJson['data'] ?? {});
        
        // Extract totalUsers and pendingRedemptions from top level
        final totalUsers = dashboardData['totalUsers'] ?? 0;
        final pendingRedemptions = dashboardData['pendingRedemptions'] ?? 0;
        
        // Extract users list from data.users.records
        final usersData = Map<String, dynamic>.from(dashboardData['users'] ?? {});
        final List<dynamic> userRecords = (usersData['records'] ?? []) as List<dynamic>;
        final users = userRecords.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
        
        debugPrint('Total users count: $totalUsers');
        debugPrint('Pending redemptions count: $pendingRedemptions');
        debugPrint('Users loaded: ${users.length}');
        
        setState(() {
          _totalUsers = totalUsers;
          _pendingRedemptions = pendingRedemptions;
          _users = users;
          _loadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Stats API Exception: $e');
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  Future<void> _fetchPendingRedemptions() async {
    if (_loadingRedemptions) return;
    
    setState(() => _loadingRedemptions = true);
    
    try {
      final resp = await ApiService.get(
        '/redemptions/admin/redemptions/pending',
        queryParameters: {
          'limit': _limit.toString(),
          'offset': _redemptionsOffset.toString(),
        },
      );
      
      debugPrint('Redemptions API Response: ${resp.statusCode}');
      debugPrint('Redemptions API Body: ${resp.body}');
      
      if (resp.statusCode == 200 && mounted) {
        final Map<String, dynamic> parsedJson = json.decode(resp.body) is Map
            ? Map<String, dynamic>.from(json.decode(resp.body) as Map)
            : <String, dynamic>{};
        
        final data = Map<String, dynamic>.from(parsedJson['data'] ?? {});
        final List<dynamic> records = (data['records'] ?? []) as List<dynamic>;
        final recordsList = records.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
        
        debugPrint('Fetched ${recordsList.length} redemptions');
        
        setState(() {
          _redemptions = recordsList;
          _loadingRedemptions = false;
        });
      } else {
        debugPrint('Redemptions API Error: ${resp.statusCode}');
        if (mounted) {
          setState(() => _loadingRedemptions = false);
        }
      }
    } catch (e) {
      debugPrint('Redemptions API Exception: $e');
      if (mounted) {
        setState(() => _loadingRedemptions = false);
      }
    }
  }

  Future<void> _updateRedemptionStatus(
    String redemptionId,
    String status, {
    String? message,
    String? brand,
  }) async {
    try {
      // Validate status
      if (status != 'FULFILLED' && status != 'DENIED') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid status. Must be FULFILLED or DENIED'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Build request body
      final body = <String, dynamic>{
        'status': status,
      };

      // Add optional message (for DENIED, it's the rejection reason)
      if (message != null && message.isNotEmpty) {
        body['message'] = message;
      }

      // Add optional brand override
      if (brand != null && brand.isNotEmpty) {
        body['brand'] = brand;
      }

      final resp = await ApiService.post(
        '/redemptions/$redemptionId/status',
        body: body,
      );

      if (mounted) {
        // Parse response
        final Map<String, dynamic> parsedJson = json.decode(resp.body) is Map
            ? Map<String, dynamic>.from(json.decode(resp.body) as Map)
            : <String, dynamic>{};

        if (resp.statusCode == 200 && parsedJson['success'] == true) {
          // Success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == 'FULFILLED'
                    ? 'Redemption approved successfully. User will receive an email notification.'
                    : 'Redemption rejected successfully. User will receive an email notification.',
              ),
              backgroundColor: status == 'FULFILLED' ? Colors.green : Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );

          // Refresh data
          await _fetchStats();
          await _fetchPendingRedemptions();
        } else {
          // Handle API errors
          String errorMessage = 'Failed to update redemption status';
          
          switch (resp.statusCode) {
            case 400:
              errorMessage = parsedJson['message'] ?? 'Invalid request. Please check your input.';
              if (errorMessage.toLowerCase().contains('brand')) {
                errorMessage = 'Brand cannot be empty. Please provide a valid brand name.';
              } else if (errorMessage.toLowerCase().contains('status')) {
                errorMessage = 'Invalid status. Must be FULFILLED or DENIED';
              }
              break;
            case 404:
              errorMessage = 'Redemption not found. It may have been deleted.';
              break;
            case 500:
              errorMessage = 'Server error. Please try again later.';
              break;
            default:
              errorMessage = parsedJson['message'] ?? 'An error occurred while updating the redemption status.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Network error or other exception
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Network error. Please check your connection and try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      debugPrint('Error updating redemption status: $e');
    }
  }

  void _showRejectDialog(String redemptionId) {
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Redemption'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please provide a reason for rejection:'),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason (optional)',
                  hintText: 'Explain why this redemption was denied...',
                  border: OutlineInputBorder(),
                  helperText: 'This message will be sent to the user via email',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateRedemptionStatus(
                redemptionId,
                'DENIED',
                message: messageController.text.trim(),
              );
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(String redemptionId, {String? currentBrand}) {
    final brandController = TextEditingController(text: currentBrand ?? '');
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Approve Redemption'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Are you sure you want to approve this redemption?'),
                const SizedBox(height: 16),
                TextField(
                  controller: brandController,
                  decoration: const InputDecoration(
                    labelText: 'Brand Override (optional)',
                    hintText: 'Leave empty to keep original brand',
                    border: OutlineInputBorder(),
                    helperText: 'Override the brand name if needed',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Optional Message',
                    hintText: 'Optional notes...',
                    border: OutlineInputBorder(),
                    helperText: 'Optional message or notes',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                final brand = brandController.text.trim();
                final message = messageController.text.trim();
                
                // Validate brand if provided (cannot be empty)
                if (brand.isEmpty && brandController.text.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Brand cannot be empty. Please provide a valid brand name or leave it empty.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                Navigator.of(ctx).pop();
                _updateRedemptionStatus(
                  redemptionId,
                  'FULFILLED',
                  brand: brand.isEmpty ? null : brand,
                  message: message.isEmpty ? null : message,
                );
              },
              child: const Text('Approve'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('MR Bucks Admin'),
        backgroundColor: const Color(0xFF7E5EFD),
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              children: [
                const Text(
                  'MR Bucks Admin Panel',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7E5EFD),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage users, points, and redemptions',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                // Stats Cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Users',
                        value: _totalUsers.toString(),
                        isLoading: _loadingStats,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Pending Redemptions',
                        value: _pendingRedemptions.toString(),
                        isLoading: _loadingStats,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black54,
                indicator: BoxDecoration(
                  color: const Color(0xFF7E5EFD),
                  borderRadius: BorderRadius.circular(25),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                overlayColor: MaterialStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(text: 'Users'),
                  Tab(text: 'Redemption Requests'),
                ],
              ),
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUsersTab(),
                _buildRedemptionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_loadingStats && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Users Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              'No users have signed up yet',
              style: TextStyle(color: Colors.black38),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                debugPrint('Manually refreshing users...');
                _fetchStats();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return _UserCard(
          user: user,
        );
      },
    );
  }

  Widget _buildRedemptionsTab() {
    if (_loadingRedemptions && _redemptions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_redemptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Pending Redemptions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              'All redemption requests have been processed',
              style: TextStyle(color: Colors.black38),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                debugPrint('Manually refreshing redemptions...');
                _fetchPendingRedemptions();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _redemptions.length,
      itemBuilder: (context, index) {
        final redemption = _redemptions[index];
        return _RedemptionCard(
          redemption: redemption,
          onApprove: () => _showApproveDialog(
            redemption['id'],
            currentBrand: redemption['brand'],
          ),
          onReject: () => _showRejectDialog(redemption['id']),
          onViewDetails: () {
            // Navigate to details screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RedemptionDetailsScreen(redemptionId: redemption['id']),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final bool isLoading;

  const _StatCard({
    required this.title,
    required this.value,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7E5EFD),
                  ),
                ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _RedemptionCard extends StatelessWidget {
  final Map<String, dynamic> redemption;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewDetails;

  const _RedemptionCard({
    required this.redemption,
    required this.onApprove,
    required this.onReject,
    required this.onViewDetails,
  });

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(redemption['user'] ?? {});
    final userName = user['name'] ?? 'Unknown User';
    final redemptionId = redemption['id'] ?? '';
    final shortId = redemptionId.length > 8 ? 'RED-${redemptionId.substring(0, 3)}' : redemptionId;
    
    final providerType = redemption['providerType'] ?? 'GIFT_CARD';
    final isDonation = providerType == 'DONATION';
    final brand = redemption['brand'] ?? '';
    final points = redemption['pointsSpent'] ?? 0;
    final createdAt = _formatDate(redemption['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shortId,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                isDonation ? '❤️' : '🎁',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                isDonation ? 'Donation' : 'Gift Card',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Text(' - ', style: TextStyle(fontSize: 14, color: Colors.black54)),
              Text(
                brand,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Points: ${_formatPoints(points)} MR Bucks',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            'Date: $createdAt',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: onViewDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E5EFD),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('View Details', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Approve', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Reject', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatPoints(int pts) {
    final s = pts.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final fromEnd = s.length - i - 1;
      if (fromEnd % 3 == 0 && i != s.length - 1) buf.write(',');
    }
    return '$buf';
  }
}

// Redemption Details Screen
class RedemptionDetailsScreen extends StatefulWidget {
  final String redemptionId;

  const RedemptionDetailsScreen({super.key, required this.redemptionId});

  @override
  State<RedemptionDetailsScreen> createState() => _RedemptionDetailsScreenState();
}

class _RedemptionDetailsScreenState extends State<RedemptionDetailsScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _redemption;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    try {
      final resp = await ApiService.get(
        '/redemptions/admin/redemptions/${widget.redemptionId}',
        queryParameters: {'txLimit': '50', 'txOffset': '0'},
      );

      if (resp.statusCode == 200 && mounted) {
        final Map<String, dynamic> parsedJson = json.decode(resp.body) is Map
            ? Map<String, dynamic>.from(json.decode(resp.body) as Map)
            : <String, dynamic>{};

        final data = Map<String, dynamic>.from(parsedJson['data'] ?? {});
        
        setState(() {
          _redemption = Map<String, dynamic>.from(data['redemption'] ?? {});
          final List<dynamic> txs = (data['transactions'] ?? []) as List<dynamic>;
          _transactions = txs.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  int _countByRefType(String refType) {
    return _transactions.where((tx) => tx['refType'] == refType).length;
  }

  int _countRedemptions() {
    return _transactions.where((tx) => tx['refType'] == 'REDEMPTION').length;
  }

  String _formatUserId(String userId) {
    return 'USR-${userId.substring(0, 3).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('User Details'),
          backgroundColor: const Color(0xFF7E5EFD),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_redemption == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('User Details'),
          backgroundColor: const Color(0xFF7E5EFD),
        ),
        body: const Center(child: Text('User not found')),
      );
    }

    final user = Map<String, dynamic>.from(_redemption!['user'] ?? {});
    final userName = user['name'] ?? 'Unknown User';
    final userEmail = user['email'] ?? '';
    final userId = user['id'] ?? '';
    final pointsBalance = user['pointsBalance'] ?? 0;

    // Count only actual receipt uploads for the Receipts stat
    final receiptsCount = _countByRefType('RECEIPT');
    final redemptionsCount = _countRedemptions();
    // Combine tax reports and expense reports for the Reports stat
    final reportsCount = _countByRefType('TAX_REPORT') + _countByRefType('EXPENSE_REPORT');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Header Section
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back to Users'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  // User Info
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userEmail,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${_formatUserId(userId)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7E5EFD),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_formatPoints(pointsBalance)} MR Bucks',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Stats Cards
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _UserStatCard(
                            value: receiptsCount.toString(),
                            label: 'Receipts',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _UserStatCard(
                            value: redemptionsCount.toString(),
                            label: 'Redemptions',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _UserStatCard(
                            value: reportsCount.toString(),
                            label: 'Reports',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.black54,
                        indicator: BoxDecoration(
                          color: const Color(0xFF7E5EFD),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        dividerColor: Colors.transparent,
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: MaterialStateProperty.all(Colors.transparent),
                        tabs: const [
                          Tab(text: 'Points History'),
                          Tab(text: 'Redemption History'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPointsHistoryTab(),
                _buildRedemptionHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsHistoryTab() {
    // Exclude redemptions from points history
    final pointsTransactions = _transactions.where((tx) => tx['refType'] != 'REDEMPTION').toList();
    
    if (pointsTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    final user = Map<String, dynamic>.from(_redemption!['user'] ?? {});
    final userId = user['id'] ?? '';

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pointsTransactions.length,
      itemBuilder: (context, index) {
        final tx = pointsTransactions[index];
        return _TransactionTile(transaction: tx, userId: userId);
      },
    );
  }

  Widget _buildRedemptionHistoryTab() {
    // Filter by refType: REDEMPTION
    final redemptions = _transactions.where((tx) => tx['refType'] == 'REDEMPTION').toList();

    if (redemptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.card_giftcard, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No redemptions yet',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    final user = Map<String, dynamic>.from(_redemption!['user'] ?? {});
    final userId = user['id'] ?? '';

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: redemptions.length,
      itemBuilder: (context, index) {
        final tx = redemptions[index];
        return _TransactionTile(transaction: tx, userId: userId);
      },
    );
  }

  String _formatPoints(int pts) {
    final s = pts.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final fromEnd = s.length - i - 1;
      if (fromEnd % 3 == 0 && i != s.length - 1) buf.write(',');
    }
    return '$buf';
  }
}

class _UserStatCard extends StatelessWidget {
  final String value;
  final String label;

  const _UserStatCard({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7E5EFD),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String userId;

  const _TransactionTile({
    required this.transaction,
    required this.userId,
  });

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  String _getTransactionTitle() {
    final refType = transaction['refType'] ?? '';
    final entryType = transaction['entryType'] ?? '';
    final points = transaction['points'] ?? 0;
    
    if (refType == 'RECEIPT') {
      return 'Receipt Upload';
    } else if (refType == 'REFERRAL') {
      return 'Referral Bonus';
    } else if (refType == 'TAX_REPORT') {
      return 'Tax Report Export';
    } else if (refType == 'EXPENSE_REPORT') {
      return 'Expense Report Export';
    } else if (refType == 'REDEMPTION') {
      return 'Points Redemption';
    } else if (entryType == 'AWARD') {
      return 'Points Award';
    }
    
    return 'Transaction';
  }

  String _getTransactionDescription() {
    final refType = transaction['refType'] ?? '';
    final points = transaction['points'] ?? 0;
    final metadataSummary = transaction['metadataSummary'];
    
    // Use metadata summary if available
    if (metadataSummary != null && metadataSummary.toString().isNotEmpty) {
      return metadataSummary.toString();
    }
    
    // Generate description based on refType
    if (refType == 'RECEIPT') {
      return 'Earned ${points.abs()} MR Bucks for uploading receipt';
    } else if (refType == 'REFERRAL') {
      return 'Earned ${points.abs()} MR Bucks for referring a friend';
    } else if (refType == 'TAX_REPORT') {
      return 'Earned ${points.abs()} MR Bucks for exporting tax report';
    } else if (refType == 'EXPENSE_REPORT') {
      return 'Earned ${points.abs()} MR Bucks for exporting expense report';
    } else if (refType == 'REDEMPTION') {
      return 'Redeemed ${points.abs()} MR Bucks';
    }
    
    return '';
  }

  Future<void> _viewReceiptDetails(BuildContext context) async {
    final ledgerId = transaction['id'];
    final receiptId = transaction['receiptId'];
    
    if (ledgerId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt information not available')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Use the correct endpoint: /redemptions/admin/users/:userId/ledger/:ledgerId/receipt
      final resp = await ApiService.get(
        '/redemptions/admin/users/$userId/ledger/$ledgerId/receipt',
      );

      debugPrint('Receipt Details API Response: ${resp.statusCode}');
      debugPrint('Receipt Details API Body: ${resp.body}');

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (resp.statusCode == 200) {
        final Map<String, dynamic> parsedJson = json.decode(resp.body) is Map
            ? Map<String, dynamic>.from(json.decode(resp.body) as Map)
            : <String, dynamic>{};
        
        final data = Map<String, dynamic>.from(parsedJson['data'] ?? {});
        final receipt = Map<String, dynamic>.from(data['receipt'] ?? {});
        
        _showReceiptDialog(context, data, receipt);
      } else {
        debugPrint('Failed to load receipt - Status: ${resp.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load receipt details (Status: ${resp.statusCode})'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Receipt Details API Exception: $e');
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading receipt: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showReceiptDialog(BuildContext context, Map<String, dynamic> data, Map<String, dynamic> receipt) {
    final points = data['points'] ?? 0;
    final createdAt = data['createdAt'] ?? '';
    final merchant = receipt['merchant'] ?? 'N/A';
    final amount = receipt['amount'] ?? 0.0;
    final receiptDate = receipt['receiptDate'] ?? 'N/A';
    final category = receipt['category'] ?? 'N/A';
    final receiptCreatedAt = receipt['createdAt'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receipt Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Merchant', merchant),
              _buildDetailRow('Amount', '\$${amount.toStringAsFixed(2)}'),
              _buildDetailRow('Receipt Date', receiptDate),
              _buildDetailRow('Category', category),
              _buildDetailRow('Points Earned', '$points MR Bucks'),
              _buildDetailRow('Transaction Date', _formatDate(createdAt)),
              _buildDetailRow('Receipt Uploaded', _formatDate(receiptCreatedAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTransactionIcon() {
    final refType = transaction['refType'] ?? '';
    
    if (refType == 'RECEIPT') {
      return Icons.receipt_long;
    } else if (refType == 'REFERRAL') {
      return Icons.people;
    } else if (refType == 'TAX_REPORT') {
      return Icons.description;
    } else if (refType == 'EXPENSE_REPORT') {
      return Icons.assessment;
    } else if (refType == 'REDEMPTION') {
      return Icons.card_giftcard;
    }
    
    return Icons.circle;
  }

  @override
  Widget build(BuildContext context) {
    final points = transaction['points'] ?? 0;
    final createdAt = _formatDate(transaction['createdAt']);
    final title = _getTransactionTitle();
    final description = _getTransactionDescription();
    final refType = transaction['refType'] ?? '';
    final icon = _getTransactionIcon();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: const Color(0xFF7E5EFD),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7E5EFD),
                    ),
                  ),
                ],
              ),
              Text(
                createdAt,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
          if (refType == 'RECEIPT') ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _viewReceiptDetails(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.lightBlue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.receipt, size: 24, color: Colors.black54),
                    SizedBox(width: 8),
                    Text(
                      'Click to view receipt',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              points >= 0 ? '+$points MR Bucks' : '$points MR Bucks',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: points >= 0 ? const Color(0xFF7E5EFD) : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// User Card Widget
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _UserCard({required this.user});

  String _formatUserId(String userId) {
    if (userId.length > 8) {
      return '${userId.substring(0, 4)}...${userId.substring(userId.length - 4)}';
    }
    return userId;
  }

  @override
  Widget build(BuildContext context) {
    final name = user['name'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final userId = user['userId'] ?? user['id'] ?? '';
    final pointsBalance = user['pointsBalance'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // User Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF7E5EFD).withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7E5EFD),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${_formatUserId(userId)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          // Points Balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF7E5EFD).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  '$pointsBalance',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7E5EFD),
                  ),
                ),
                const Text(
                  'MR Bucks',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7E5EFD),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

