import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/setting_provider.dart';
import '../providers/user_provider.dart';
import '../services/analytics_service.dart';
import 'category_wise_spend_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _summaryData;
  Map<String, dynamic>? _categoryData;
  Map<String, dynamic>? _monthlyTrendData;
  String _selectedPeriod = 'monthly';
  String _selectedTrendPeriod = '6months';

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    final token = userProvider.token;

    if (userId == null || token == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Fetch all analytics data in parallel
      final results = await Future.wait([
        AnalyticsService.getAnalyticsSummary(userId, token: token),
        AnalyticsService.getCategoryWiseSpending(userId, token: token, period: _selectedPeriod),
        AnalyticsService.getMonthlyTrend(userId, token: token, period: _selectedTrendPeriod),
      ]);

      setState(() {
        _summaryData = results[0]['success'] ? results[0]['data'] : null;
        _categoryData = results[1]['success'] ? results[1]['data'] : null;
        _monthlyTrendData = results[2]['success'] ? results[2]['data'] : null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadAnalyticsData();
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    _loadAnalyticsData();
  }

  void _onTrendPeriodChanged(String period) {
    setState(() {
      _selectedTrendPeriod = period;
    });
    _loadAnalyticsData();
  }

  @override
  Widget build(BuildContext context) {
    final String currencySymbol = _getCurrencySymbol(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        centerTitle: true,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: _AppLogo(),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary grid removed
                      _CardContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Category wise Spending',
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _CategoryWiseSection(
                              categoryData: _categoryData,
                              currencySymbol: currencySymbol,
                              selectedPeriod: _selectedPeriod,
                              onPeriodChanged: _onPeriodChanged,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _CardContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Monthly Trend',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _TrendPeriodTab(
                                    title: '3M',
                                    value: '3months',
                                    groupValue: _selectedTrendPeriod,
                                    onTap: _onTrendPeriodChanged,
                                  ),
                                  const SizedBox(width: 8),
                                  _TrendPeriodTab(
                                    title: '6M',
                                    value: '6months',
                                    groupValue: _selectedTrendPeriod,
                                    onTap: _onTrendPeriodChanged,
                                  ),
                                  const SizedBox(width: 8),
                                  _TrendPeriodTab(
                                    title: '12M',
                                    value: '12months',
                                    groupValue: _selectedTrendPeriod,
                                    onTap: _onTrendPeriodChanged,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _MonthlyTrendSection(
                              monthlyTrendData: _monthlyTrendData,
                              currencySymbol: currencySymbol,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _getCurrencySymbol(BuildContext context) {
    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final symbol = settings.currencySymbol;
      if (symbol != null && symbol.isNotEmpty) return symbol;
    } catch (_) {}
    
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      return userProvider.effectiveCurrencySymbol;
    } catch (_) {}
    
    return '₹';
  }
}

// Summary grid removed

class _CardContainer extends StatelessWidget {
  const _CardContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CategoryWiseSection extends StatelessWidget {
  const _CategoryWiseSection({
    required this.categoryData,
    required this.currencySymbol,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  final Map<String, dynamic>? categoryData;
  final String currencySymbol;
  final String selectedPeriod;
  final void Function(String value) onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    // Extract categories from API response structure (with safe defaults)
    final List<dynamic> categoryWiseSpending =
        (categoryData != null ? categoryData!['categoryWiseSpending'] as List<dynamic>? : null) ??
            <dynamic>[];
    final double totalSpent = _getDoubleValue(categoryData != null ? categoryData!['totalSpent'] : null) ?? 0.0;

    // Convert API data to the format expected by the chart
    final Map<String, Map<String, dynamic>> formattedCategories = {};
    final List<Color> colors = [
      Colors.green,
      Colors.deepOrange,
      Colors.amber,
      Colors.brown,
      Colors.blue,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    for (int i = 0; i < categoryWiseSpending.length && i < 8; i++) {
      final category = categoryWiseSpending[i];
      final name = category['category']?.toString() ?? 'Unknown';
      final amount = _getDoubleValue(category['amount']) ?? 0.0;
      
      // Calculate percentage if not provided
      double percentage = 0.0;
      if (totalSpent > 0) {
        percentage = (amount / totalSpent) * 100;
      }

      formattedCategories[name] = {
        'amount': amount,
        'percentage': percentage,
        'color': colors[i % colors.length],
      };
    }

    return Column(
      children: [
        // Show total spent info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total (${_formatPeriodText(selectedPeriod)}): $currencySymbol${totalSpent.toStringAsFixed(0)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              DropdownButton<String>(
                isDense: true,
                value: selectedPeriod,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    onPeriodChanged(newValue);
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'yeartodate', child: Text('YTD')),
                  DropdownMenuItem(value: 'lastYear', child: Text('Last Year')),
                  DropdownMenuItem(value: 'last3Months', child: Text('Last 3M')),
                  DropdownMenuItem(value: 'last6Months', child: Text('Last 6M')),
                ],
                underline: SizedBox.shrink(),
                style: TextStyle(
                  color: Colors.purple.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (categoryWiseSpending.isEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Icon(
                  Icons.pie_chart_outline,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No spending data for ${categoryData != null ? (categoryData!['period'] ?? _formatPeriodText(selectedPeriod)) : _formatPeriodText(selectedPeriod)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total spent: $currencySymbol${totalSpent.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
        // Centered pie chart
        Center(
          child: SizedBox(
            width: 180,
            height: 180,
            child: _DonutChart(
              values: formattedCategories.values.map((data) => data['amount'] as double).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Category grid
        _CategoryGrid(
          categoryData: formattedCategories,
          currencySymbol: currencySymbol,
        ),
        const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoryWiseSpendScreen(),
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View More',
                  style: TextStyle(
                    color: Colors.purple.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.purple.shade600,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double? _getDoubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _formatPeriodText(String period) {
    final String key = period.toString();
    switch (key) {
      case 'monthly':
        return 'Monthly';
      case 'yeartodate':
        return 'Year to Date';
      case 'lastYear':
        return 'Last Year';
      case 'last3Months':
        return 'Last 3 Months';
      case 'last6Months':
        return 'Last 6 Months';
      case 'total':
        return 'Total';
      default:
        // Fallback: insert spaces between digits and letters, then title case
        final spaced = key
            .replaceAllMapped(RegExp(r'([a-zA-Z])(\d)'), (m) => '${m.group(1)} ${m.group(2)}')
            .replaceAllMapped(RegExp(r'(\d)([a-zA-Z])'), (m) => '${m.group(1)} ${m.group(2)}')
            .replaceAll('_', ' ');
        return spaced
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
    }
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: CustomPaint(
        painter: _DonutChartPainter(values: values),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.values});

  final List<double> values;
  final List<Color> colors = const [
    Colors.green,
    Colors.deepOrange,
    Colors.amber,
    Colors.brown,
    Colors.blue,
    Colors.purple,
    Colors.red,
    Colors.teal,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold(0, (a, b) => a + b);
    if (total <= 0) return;

    final Rect rect = Offset.zero & size;
    final double thickness = size.width * 0.55;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    double startRadian = -90 * 3.1415926535 / 180.0;

    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * 3.1415926535;
      paint.color = colors[i % colors.length];

      canvas.drawArc(
        Rect.fromLTWH(
          rect.left + thickness / 2,
          rect.top + thickness / 2,
          rect.width - thickness,
          rect.height - thickness,
        ),
        startRadian,
        sweep,
        false,
        paint,
      );
      startRadian += sweep;
    }

    final innerHolePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final double innerRadius = (size.width - thickness) / 2;
    canvas.drawCircle(size.center(Offset.zero), innerRadius, innerHolePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categoryData,
    required this.currencySymbol,
  });

  final Map<String, Map<String, dynamic>> categoryData;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final categories = categoryData.entries.toList();
    
    return Column(
      children: [
        // First row - show at least the first category, or first two if available
        if (categories.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: _CategoryCard(
                  category: categories[0].key,
                  amount: categories[0].value['amount'] as double,
                  percentage: categories[0].value['percentage'] as double,
                  color: categories[0].value['color'] as Color,
                  currencySymbol: currencySymbol,
                ),
              ),
              if (categories.length >= 2) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _CategoryCard(
                    category: categories[1].key,
                    amount: categories[1].value['amount'] as double,
                    percentage: categories[1].value['percentage'] as double,
                    color: categories[1].value['color'] as Color,
                    currencySymbol: currencySymbol,
                  ),
                ),
              ],
            ],
          ),
        if (categories.isNotEmpty) const SizedBox(height: 12),
        // Second row - show third and fourth categories if available
        if (categories.length >= 3)
          Row(
            children: [
              Expanded(
                child: _CategoryCard(
                  category: categories[2].key,
                  amount: categories[2].value['amount'] as double,
                  percentage: categories[2].value['percentage'] as double,
                  color: categories[2].value['color'] as Color,
                  currencySymbol: currencySymbol,
                ),
              ),
              if (categories.length >= 4) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _CategoryCard(
                    category: categories[3].key,
                    amount: categories[3].value['amount'] as double,
                    percentage: categories[3].value['percentage'] as double,
                    color: categories[3].value['color'] as Color,
                    currencySymbol: currencySymbol,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.currencySymbol,
  });

  final String category;
  final double amount;
  final double percentage;
  final Color color;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: double.infinity,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$currencySymbol${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black87,
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

class _MonthlyTrendSection extends StatelessWidget {
  const _MonthlyTrendSection({
    required this.monthlyTrendData,
    required this.currencySymbol,
  });

  final Map<String, dynamic>? monthlyTrendData;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    if (monthlyTrendData == null) {
      return const Center(
        child: Text(
          'No trend data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Extract monthly trend from API response structure
    final List<dynamic>? monthlyTrend = monthlyTrendData!['monthlyTrend'];
    if (monthlyTrend == null || monthlyTrend.isEmpty) {
      return const Center(
        child: Text(
          'No monthly trend data found',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final List<double> values = monthlyTrend.map((item) {
      return _getDoubleValue(item['amount']) ?? 0.0;
    }).toList();

    final List<String> labels = monthlyTrend.map((item) {
      return item['month']?.toString() ?? 'Unknown';
    }).toList();

    final double maxY = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) * 1.1 : 10000;

    return SizedBox(
      height: 200,
      child: _LineChart(
        values: values,
        currencySymbol: currencySymbol,
        maxY: maxY,
        xLabels: labels,
      ),
    );
  }

  double? _getDoubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.values,
    required this.currencySymbol,
    this.maxY = 10000,
    this.xLabels,
  });

  final List<double> values;
  final String currencySymbol;
  final double maxY;
  final List<String>? xLabels;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        return CustomPaint(
          size: size,
          painter: _LineChartPainter(
            values: values,
            currencySymbol: currencySymbol,
            maxY: maxY,
            xLabels: xLabels,
          ),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.currencySymbol,
    required this.maxY,
    this.xLabels,
  });

  final List<double> values;
  final String currencySymbol;
  final double maxY;
  final List<String>? xLabels;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double leftPadding = 36;
    final double bottomPadding = 26;
    final double rightPadding = 8;
    final double topPadding = 8;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    final origin = Offset(leftPadding, size.height - bottomPadding);
    canvas.drawLine(origin, Offset(size.width - rightPadding, size.height - bottomPadding), axisPaint);
    canvas.drawLine(origin, Offset(leftPadding, topPadding), axisPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    const int steps = 2;
    for (int i = 0; i <= steps; i++) {
      final y = origin.dy - (i / steps) * chartHeight;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width - rightPadding, y), axisPaint..color = Colors.grey.shade200);
      final label = _formatCurrency((i / steps) * maxY);
      textPainter.text = TextSpan(text: label, style: const TextStyle(fontSize: 10, color: Colors.black54));
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding - textPainter.width - 6, y - textPainter.height / 2));
    }

    final path = Path();
    final pointPaint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0x007C3AED)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight))
      ..style = PaintingStyle.fill;

    final points = <Offset>[];
    final int n = values.length.clamp(1, 12);
    for (int i = 0; i < n; i++) {
      final x = n == 1 ? leftPadding : leftPadding + (chartWidth / (n - 1)) * i;
      final clamped = values[i].clamp(0, maxY);
      final y = origin.dy - (clamped / maxY) * chartHeight;
      points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, origin.dy)
        ..lineTo(points.first.dx, origin.dy)
        ..close();
      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, pointPaint);

      final dotPaint = Paint()..color = const Color(0xFF7C3AED);
      for (final p in points) {
        canvas.drawCircle(p, 3, dotPaint);
      }
    }

    if (xLabels != null && xLabels!.isNotEmpty) {
      final labels = xLabels!;
      final int labelCount = labels.length.clamp(1, points.length);
      for (int i = 0; i < labelCount; i++) {
        final x = leftPadding + (chartWidth / (labelCount - 1)) * i;
        textPainter.text = TextSpan(text: labels[i], style: const TextStyle(fontSize: 10, color: Colors.black54));
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, origin.dy + 6));
      }
    }
  }

  String _formatCurrency(double v) {
    if (v >= 1000) {
      return '$currencySymbol${(v / 1000).round()}k';
    }
    return '$currencySymbol${v.round()}';
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InsightsSection extends StatelessWidget {
  const _InsightsSection({
    required this.summaryData,
    required this.categoryData,
    required this.monthlyTrendData,
    required this.currencySymbol,
  });

  final Map<String, dynamic>? summaryData;
  final Map<String, dynamic>? categoryData;
  final Map<String, dynamic>? monthlyTrendData;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final List<String> insights = [];

    // Generate insights from the data
    if (summaryData != null) {
      final totalSpend = _getDoubleValue(summaryData!['totalSpend']) ?? 0.0;
      final monthlySpend = _getDoubleValue(summaryData!['monthlySpend']) ?? 0.0;
      final ytdSpend = _getDoubleValue(summaryData!['yeartodateSpend']) ?? 0.0;
      final lastMonthSpend = _getDoubleValue(summaryData!['lastMonthSpend']) ?? 0.0;

      if (totalSpend > 0) {
        insights.add('Total spending: $currencySymbol${totalSpend.toStringAsFixed(0)}');
      }
      
      if (monthlySpend > 0) {
        insights.add('This month: $currencySymbol${monthlySpend.toStringAsFixed(0)}');
      }
      
      if (ytdSpend > 0) {
        insights.add('Year to date: $currencySymbol${ytdSpend.toStringAsFixed(0)}');
      }
      
      if (lastMonthSpend > 0) {
        insights.add('Last month: $currencySymbol${lastMonthSpend.toStringAsFixed(0)}');
      }
    }

    // Add insights from monthly trend
    if (monthlyTrendData != null && monthlyTrendData!['monthlyTrend'] != null) {
      final monthlyTrend = monthlyTrendData!['monthlyTrend'] as List<dynamic>;
      if (monthlyTrend.isNotEmpty) {
        // Find the month with highest spending
        monthlyTrend.sort((a, b) {
          final amountA = _getDoubleValue(a['amount']) ?? 0.0;
          final amountB = _getDoubleValue(b['amount']) ?? 0.0;
          return amountB.compareTo(amountA);
        });

        final highestMonth = monthlyTrend.first;
        final highestAmount = _getDoubleValue(highestMonth['amount']) ?? 0.0;
        if (highestAmount > 0) {
          insights.add('Highest spending month: ${highestMonth['month']} ($currencySymbol${highestAmount.toStringAsFixed(0)})');
        }
      }
    }

    // Add insights from category data
    if (categoryData != null && categoryData!['categoryWiseSpending'] != null) {
      final categories = categoryData!['categoryWiseSpending'] as List<dynamic>;
      if (categories.isNotEmpty) {
        categories.sort((a, b) {
          final amountA = _getDoubleValue(a['amount']) ?? 0.0;
          final amountB = _getDoubleValue(b['amount']) ?? 0.0;
          return amountB.compareTo(amountA);
        });

        final topCategory = categories.first;
        final topAmount = _getDoubleValue(topCategory['amount']) ?? 0.0;
        if (topAmount > 0) {
          insights.add('Top category: ${topCategory['category']} ($currencySymbol${topAmount.toStringAsFixed(0)})');
        }
      }
    }

    if (insights.isEmpty) {
      insights.add('No insights available at the moment');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: insights.map((insight) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _InsightItem(insight),
      )).toList(),
    );
  }

  double? _getDoubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class _InsightItem extends StatelessWidget {
  const _InsightItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(top: 8, right: 12),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'MR',
          style: TextStyle(
            color: Color(0xFF7C3AED),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _TrendPeriodTab extends StatelessWidget {
  const _TrendPeriodTab({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onTap,
  });

  final String title;
  final String value;
  final String groupValue;
  final void Function(String value) onTap;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8E6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: const Color(0xFF7E5EFD)) : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}


