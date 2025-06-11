import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/curved_background.dart';

class AdminReportsScreen extends StatefulWidget {
  final String adminId;
  final String token;

  const AdminReportsScreen({
    Key? key,
    required this.adminId,
    required this.token,
  }) : super(key: key);

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _reportsData = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchReportsData();
  }

  Future<void> _fetchReportsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse(
          'https://manage-receipt-backend-bnl1.onrender.com/api/admin/reports');

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
          _reportsData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load reports data: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports data: $e');
      setState(() {
        _errorMessage = 'Network error: Unable to connect to server';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: true,
        child: CurvedBackground(
          child: Column(
            children: [
              // App Bar
              Container(
                padding: const EdgeInsets.only(
                    top: 8, left: 16, right: 16, bottom: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Admin Reports',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'MR',
                          style: TextStyle(
                            color: Color(0xFF7E5EFD),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Reports Content
              Expanded(
                child: _isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
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
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchReportsData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF7E5EFD),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: _fetchReportsData,
                  color: Colors.white,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        const Text(
                          'Last 7 Days Statistics',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Key metrics for the past week',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Primary Stats (Last 7 Days)
                        _buildStatsSection(
                          'Last 7 Days Activity',
                          [
                            _buildStatCard(
                              'New Users',
                              '${_reportsData['usersLast7Days'] ?? 0}',
                              Icons.person_add,
                              Colors.green,
                              'Users who joined in the last 7 days',
                            ),
                            _buildStatCard(
                              'Receipts Generated',
                              '${_reportsData['receiptsLast7Days'] ?? 0}',
                              Icons.receipt_long,
                              Colors.blue,
                              'New receipts created in the last 7 days',
                            ),
                            _buildStatCard(
                              'User Logins',
                              '${_reportsData['loginsLast7Days'] ?? 0}',
                              Icons.login,
                              Colors.purple,
                              'Users who logged in during the last 7 days',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // User Activity Stats
                        _buildStatsSection(
                          'User Activity',
                          [
                            _buildStatCard(
                              'New Sign-ups',
                              '${_reportsData['newSignups'] ?? 0}',
                              Icons.how_to_reg,
                              Colors.orange,
                              'Total new user registrations',
                            ),
                            _buildStatCard(
                              'Forgot Password',
                              '${_reportsData['forgotPasswordUsers'] ?? 0}',
                              Icons.lock_reset,
                              Colors.red,
                              'Users who used forgot password feature',
                            ),
                            _buildStatCard(
                              'Report Searches',
                              '${_reportsData['searchReportUsers'] ?? 0}',
                              Icons.search,
                              Colors.teal,
                              'Users who searched or looked for reports',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Overall Statistics
                        _buildStatsSection(
                          'Overall Statistics',
                          [
                            _buildStatCard(
                              'Total Users',
                              '${_reportsData['totalUsers'] ?? 0}',
                              Icons.people,
                              Colors.indigo,
                              'All registered users',
                            ),
                            _buildStatCard(
                              'Total Receipts',
                              '${_reportsData['totalReceipts'] ?? 0}',
                              Icons.receipt,
                              Colors.amber,
                              'All receipts in the system',
                            ),
                            _buildStatCard(
                              'Active Users',
                              '${_reportsData['activeUsers'] ?? 0}',
                              Icons.person_outline,
                              Colors.cyan,
                              'Currently active users',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Performance Metrics
                        _buildPerformanceSection(),
                        const SizedBox(height: 16),
                      ],
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

  Widget _buildStatsSection(String title, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...cards.map((card) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: card,
        )),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      String description) {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7E5EFD),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
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
    );
  }

  Widget _buildPerformanceSection() {
    final avgReceipts = _reportsData['averageReceiptsPerUser'] ?? 0;
    final engagementRate = _reportsData['activeUsers'] != null &&
        _reportsData['totalUsers'] != null
        ? ((_reportsData['activeUsers'] / _reportsData['totalUsers']) * 100)
        .toStringAsFixed(1)
        : '0.0';

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
          const Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Avg Receipts/User',
                  avgReceipts.toString(),
                  Icons.analytics,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricItem(
                  'User Engagement',
                  '$engagementRate%',
                  Icons.trending_up,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EAFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: const Color(0xFF7E5EFD),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'User engagement is calculated as active users / total users',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
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

  Widget _buildMetricItem(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}