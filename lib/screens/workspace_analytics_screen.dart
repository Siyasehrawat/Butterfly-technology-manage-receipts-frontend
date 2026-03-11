import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/workspace_service.dart';
import '../web/app/workspace_analytics_web_screen.dart';

class WorkspaceAnalyticsScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String? workspaceId;

  const WorkspaceAnalyticsScreen({
    Key? key,
    required this.userId,
    required this.token,
    this.workspaceId,
  }) : super(key: key);

  @override
  State<WorkspaceAnalyticsScreen> createState() => _WorkspaceAnalyticsScreenState();
}

class _WorkspaceAnalyticsScreenState extends State<WorkspaceAnalyticsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  double _totalSpendMonthly = 0;
  double _avgPerEmployee = 0;
  int _approvedCount = 0;
  int _pendingCount = 0;
  List<Map<String, dynamic>> _categoryBreakdown = [];
  List<Map<String, dynamic>> _spendTrend = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    if (widget.workspaceId == null || widget.workspaceId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Workspace is required to load analytics';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summaryFuture = WorkspaceService.getAnalyticsSummary(
        workspaceId: widget.workspaceId!,
        userId: widget.userId,
        token: widget.token,
      );

      final spendFuture = WorkspaceService.getSpendOverTime(
        workspaceId: widget.workspaceId!,
        userId: widget.userId,
        token: widget.token,
      );

      final breakdownFuture = WorkspaceService.getExpensesBreakdown(
        workspaceId: widget.workspaceId!,
        userId: widget.userId,
        query: {'groupBy': 'category'},
        token: widget.token,
      );

      final results = await Future.wait([summaryFuture, spendFuture, breakdownFuture]);

      final summaryRes = results[0];
      final spendRes = results[1];
      final breakdownRes = results[2];

      if (summaryRes['success'] != true) {
        throw summaryRes['error'] ?? 'Failed to fetch summary';
      }

      if (spendRes['success'] != true) {
        throw spendRes['error'] ?? 'Failed to fetch spend';
      }

      if (breakdownRes['success'] != true) {
        throw breakdownRes['error'] ?? 'Failed to fetch breakdown';
      }

      final summaryData = summaryRes['data'] as Map<String, dynamic>? ?? {};
      final summary = (summaryData['summary'] ?? summaryData) as Map<String, dynamic>;

      final breakdownData = breakdownRes['data'] as Map<String, dynamic>? ?? {};
      final breakdownList = (breakdownData['breakdown'] ?? breakdownData['data'] ?? []) as List;

      final spendData = spendRes['data'] as Map<String, dynamic>? ?? {};
      final spendList = (spendData['data'] ?? spendData['points'] ?? spendData['series'] ?? []) as List;

      setState(() {
        _totalSpendMonthly = _toDouble(summary['totalSpendMonthly'] ?? summary['monthlySpend'] ?? summary['totalSpend'] ?? 0);
        _avgPerEmployee = _toDouble(summary['avgPerEmployee'] ?? summary['averagePerEmployee'] ?? 0);
        _approvedCount = _toInt(summary['approvedExpenses'] ?? summary['approvedCount'] ?? 0);
        _pendingCount = _toInt(summary['pendingApproval'] ?? summary['pendingApprovals'] ?? summary['pendingCount'] ?? 0);
        _categoryBreakdown = breakdownList.map(_normalizeBreakdown).toList();
        _spendTrend = spendList.map(_normalizeSpendPoint).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  Map<String, dynamic> _normalizeBreakdown(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final amount = map['amount'] ?? map['total'] ?? 0;
    return {
      'label': map['category'] ?? map['label'] ?? 'Category',
      'amount': _toDouble(amount),
      'percentage': _toDouble(map['percentage'] ?? 0),
    };
  }

  Map<String, dynamic> _normalizeSpendPoint(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final amount = map['amount'] ?? map['total'] ?? 0;
    return {
      'label': map['label'] ?? map['date'] ?? map['period'] ?? '',
      'amount': _toDouble(amount),
    };
  }

  String _formatCurrency(num value) => '₹${value.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    // Redirect to web analytics if on web platform
    if (kIsWeb && widget.workspaceId != null && widget.workspaceId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkspaceAnalyticsWebScreen(
              userId: widget.userId,
              token: widget.token,
              workspaceId: widget.workspaceId!,
            ),
          ),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Workspace Analytics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
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
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAnalytics,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildSpendingByCategoryCard(),
          const SizedBox(height: 24),
          _buildSpendTrendCard(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  value: _formatCurrency(_totalSpendMonthly),
                  label: 'Total Spend (Monthly)',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  value: _formatCurrency(_avgPerEmployee),
                  label: 'Avg. per Employee',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  value: '$_approvedCount',
                  label: 'Approved Expenses',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  value: '$_pendingCount',
                  label: 'Pending Approval',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export report functionality coming soon')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'EXPORT REPORT',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_categoryBreakdown.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF1ECFF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.pie_chart_outline,
                      size: 48,
                      color: Color(0xFF7E5EFD),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No spending data yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Category breakdown will appear here',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categoryBreakdown.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _categoryBreakdown[index];
                return _buildCategoryCard(
                  category: item['label'] ?? 'Category',
                  amount: _formatCurrency(item['amount'] ?? 0),
                  percentage: '${(item['percentage'] ?? 0).toStringAsFixed(1)}%',
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSpendingByCategoryCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart,
            size: 80,
            color: const Color(0xFF7E5EFD).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Spending by Category',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendTrendCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spend Over Time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              if (_spendTrend.isNotEmpty)
                Text(
                  '${_spendTrend.length} pts',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_spendTrend.isEmpty)
            const Text(
              'No spend data available',
              style: TextStyle(color: Colors.grey),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _spendTrend.length,
              separatorBuilder: (context, index) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final item = _spendTrend[index];
                final label = item['label']?.toString().isNotEmpty == true
                    ? item['label']
                    : 'Period ${index + 1}';
                final amount = _formatCurrency(item['amount'] ?? 0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7E5EFD),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7E5EFD),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required String category,
    required String amount,
    required String percentage,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF7E5EFD).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.pie_chart_outline,
              color: Color(0xFF7E5EFD),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$amount ($percentage)',
                  style: const TextStyle(
                    fontSize: 14,
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
}




