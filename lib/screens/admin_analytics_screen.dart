import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  final String adminId;
  final String token;

  const AdminAnalyticsScreen({
    Key? key,
    required this.adminId,
    required this.token,
  }) : super(key: key);

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _analyticsData = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('https://manage-receipt-backend-bnl1.onrender.com/api/admin/analytics');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _analyticsData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load analytics data: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching analytics data: $e');
      setState(() {
        _errorMessage = 'Network error: Unable to connect to server';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        title: const Text('Admin - Analytics'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF7E5EFD),
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAnalyticsData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchAnalyticsData,
        color: const Color(0xFF7E5EFD),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overview Cards
              _buildOverviewSection(),
              const SizedBox(height: 24),

              // User Growth Section
              _buildUserGrowthSection(),
              const SizedBox(height: 24),

              // Receipt Analytics Section
              _buildReceiptAnalyticsSection(),
              const SizedBox(height: 24),

              // Category Distribution Section
              _buildCategoryDistributionSection(),
              const SizedBox(height: 24),

              // Monthly Trends Section
              _buildMonthlyTrendsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Revenue',
                '\$${_analyticsData['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                Icons.attach_money,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Avg per Receipt',
                '\$${_analyticsData['averageReceiptAmount']?.toStringAsFixed(2) ?? '0.00'}',
                Icons.receipt,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Active Users',
                '${_analyticsData['activeUsersCount'] ?? 0}',
                Icons.people,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Growth Rate',
                '${_analyticsData['userGrowthRate']?.toStringAsFixed(1) ?? '0.0'}%',
                Icons.trending_up,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserGrowthSection() {
    final userGrowth = _analyticsData['userGrowthData'] as List<dynamic>? ?? [];

    return _buildAnalyticsCard(
      'User Growth',
      Column(
        children: [
          if (userGrowth.isEmpty)
            const Center(
              child: Text('No user growth data available'),
            )
          else
            ...userGrowth.map<Widget>((data) {
              final month = data['month'] as String;
              final count = data['count'] as int;
              final maxCount = userGrowth.fold<int>(0, (max, item) =>
              (item['count'] as int) > max ? (item['count'] as int) : max);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(month),
                        Text('$count users'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: maxCount > 0 ? count / maxCount : 0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildReceiptAnalyticsSection() {
    return _buildAnalyticsCard(
      'Receipt Analytics',
      Column(
        children: [
          _buildAnalyticsRow('Total Receipts', '${_analyticsData['totalReceipts'] ?? 0}'),
          _buildAnalyticsRow('Receipts This Month', '${_analyticsData['receiptsThisMonth'] ?? 0}'),
          _buildAnalyticsRow('Receipts Last Month', '${_analyticsData['receiptsLastMonth'] ?? 0}'),
          _buildAnalyticsRow('Average per User', '${_analyticsData['averageReceiptsPerUser']?.toStringAsFixed(1) ?? '0.0'}'),
        ],
      ),
    );
  }

  Widget _buildCategoryDistributionSection() {
    final categories = _analyticsData['categoryDistribution'] as List<dynamic>? ?? [];

    return _buildAnalyticsCard(
      'Category Distribution',
      Column(
        children: [
          if (categories.isEmpty)
            const Center(
              child: Text('No category data available'),
            )
          else
            ...categories.map<Widget>((category) {
              final name = category['name'] as String;
              final count = category['count'] as int;
              final percentage = category['percentage']?.toStringAsFixed(1) ?? '0.0';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(name),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('$count receipts'),
                    ),
                    Expanded(
                      child: Text('$percentage%'),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendsSection() {
    final trends = _analyticsData['monthlyTrends'] as List<dynamic>? ?? [];

    return _buildAnalyticsCard(
      'Monthly Trends',
      Column(
        children: [
          if (trends.isEmpty)
            const Center(
              child: Text('No trend data available'),
            )
          else
            ...trends.map<Widget>((trend) {
              final month = trend['month'] as String;
              final receipts = trend['receipts'] as int;
              final revenue = trend['revenue']?.toStringAsFixed(2) ?? '0.00';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(month),
                    ),
                    Expanded(
                      child: Text('$receipts'),
                    ),
                    Expanded(
                      child: Text('\$$revenue'),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7E5EFD),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7E5EFD),
            ),
          ),
        ],
      ),
    );
  }
}
