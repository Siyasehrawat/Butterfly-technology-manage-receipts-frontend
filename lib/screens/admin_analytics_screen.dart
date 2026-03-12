import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service_bypass.dart';
import '../services/version_service.dart';

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

  // Receipt activity summary (today, yesterday, week, etc.)
  bool _isReceiptCountsLoading = false;
  String? _receiptCountsError;
  // Each item: { 'label': 'Today', 'count': 24 }
  List<Map<String, dynamic>> _receiptUploadCounts = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
    _fetchReceiptUploadCounts();
  }

  Future<void> _fetchAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${dotenv.env['API_BASE_URL']}/api/admin/analytics');
      final headers = await ApiService.getHeaders(token: widget.token);
      final response = await http.get(url, headers: headers);

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

  Future<void> _fetchReceiptUploadCounts() async {
    setState(() {
      _isReceiptCountsLoading = true;
      _receiptCountsError = null;
    });

    try {
      if (!VersionService.isInitialized) {
        await VersionService.initialize();
      }

      final envBase = dotenv.env['API_BASE_URL'];
      final baseUrl = (envBase != null && envBase.isNotEmpty)
          ? envBase
          : VersionService.baseUrl.replaceFirst('/api', '');

      // Filters we want to show together
      final filterLabels = <String, String>{
        'today': 'Today',
        'yesterday': 'Yesterday',
        'week': 'Week',
        'month': 'Month',
        '6months': '6 Months',
      };

      final headers = await ApiService.getHeaders(token: widget.token);
      final List<Map<String, dynamic>> results = [];

      for (final entry in filterLabels.entries) {
        final queryParams = {
          'platform': VersionService.platform ?? 'unknown',
          'currentVersion': VersionService.currentVersion ?? '1.0.0',
          'userId': widget.adminId,
          'filter': entry.key,
        };

        final url = Uri.parse('$baseUrl/api/admin/receipt-upload-counts')
            .replace(queryParameters: queryParams);

        final response = await http.get(url, headers: headers);

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          int count = 0;

          if (decoded is Map<String, dynamic>) {
            final map = decoded;
            final fromRoot = map['count'] ?? map['total'] ?? map['receipts'];
            if (fromRoot != null) {
              count = int.tryParse(fromRoot.toString()) ?? 0;
            } else if (map['data'] is Map) {
              final data = map['data'] as Map;
              final fromData =
                  data['count'] ?? data['total'] ?? data['receipts'] ?? data['value'];
              if (fromData != null) {
                count = int.tryParse(fromData.toString()) ?? 0;
              }
            }
          } else if (decoded is List) {
            // If backend returns list of points, sum their counts
            int sum = 0;
            for (final item in decoded) {
              if (item is Map) {
                final v =
                    item['count'] ?? item['receipts'] ?? item['value'] ?? item['total'];
                if (v != null) {
                  sum += int.tryParse(v.toString()) ?? 0;
                }
              }
            }
            count = sum;
          }

          results.add({
            'label': entry.value,
            'count': count,
          });
        } else {
          setState(() {
            _receiptCountsError =
                'Failed to load receipt activity: ${response.statusCode}';
            _isReceiptCountsLoading = false;
          });
          return;
        }
      }

      setState(() {
        _receiptUploadCounts = results;
        _isReceiptCountsLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching receipt upload counts: $e');
      setState(() {
        _receiptCountsError = 'Network error: Unable to load receipt activity';
        _isReceiptCountsLoading = false;
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
        onRefresh: () async {
          await Future.wait([
            _fetchAnalyticsData(),
            _fetchReceiptUploadCounts(),
          ]);
        },
        color: const Color(0xFF7E5EFD),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewSection(),
              const SizedBox(height: 24),
              _buildTimeSeriesSection(),
              const SizedBox(height: 24),
              _buildCategoryDistributionSection(),
              const SizedBox(height: 24),
              _buildUserActivitySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    final summary = _analyticsData['summary'] ?? {};
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
                'Total Users',
                '${summary['totalUsers'] ?? 0}',
                Icons.people,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Active Users',
                '${summary['activeUsers'] ?? 0}',
                Icons.person,
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
                'Total Receipts',
                '${summary['totalReceipts'] ?? 0}',
                Icons.receipt,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Avg Receipts/User',
                '${summary['averageReceiptsPerUser'] ?? 0}',
                Icons.bar_chart,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeSeriesSection() {
    return _buildAnalyticsCard(
      'Receipt Activity Over Time',
      Column(
        children: [
          if (_isReceiptCountsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  color: Color(0xFF7E5EFD),
                ),
              ),
            )
          else if (_receiptCountsError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                _receiptCountsError!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (_receiptUploadCounts.isEmpty)
            const Center(
              child: Text('No time series data available'),
            )
          else
            ..._receiptUploadCounts.map<Widget>((dataPoint) {
              final label = dataPoint['label']?.toString() ?? '';
              final count = dataPoint['count'] is int
                  ? dataPoint['count'] as int
                  : int.tryParse('${dataPoint['count'] ?? 0}') ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EAFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count receipts',
                          style: const TextStyle(
                            color: Color(0xFF7E5EFD),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
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

  Widget _buildCategoryDistributionSection() {
    final categories = _analyticsData['categoryData'] as List<dynamic>? ?? [];

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
              final name = category['name']?.toString() ?? 'Uncategorized';
              final count = category['count']?.toString() ?? '0';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EAFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count receipts',
                          style: const TextStyle(
                            color: Color(0xFF7E5EFD),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
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

  Widget _buildUserActivitySection() {
    final userActivity = _analyticsData['userActivityData'] as List<dynamic>? ?? [];

    return _buildAnalyticsCard(
      'User Activity Status',
      Column(
        children: [
          if (userActivity.isEmpty)
            const Center(
              child: Text('No user activity data available'),
            )
          else
            ...userActivity.map<Widget>((activity) {
              final status = activity['status']?.toString() ?? 'Unknown';
              final count = activity['count']?.toString() ?? '0';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        status,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: status.toLowerCase().contains('active')
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count users',
                          style: TextStyle(
                            color: status.toLowerCase().contains('active')
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
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
}
