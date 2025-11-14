import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/setting_provider.dart';
import '../providers/user_provider.dart';
import '../services/analytics_service.dart';

class CategoryWiseSpendScreen extends StatefulWidget {
  const CategoryWiseSpendScreen({super.key});

  @override
  State<CategoryWiseSpendScreen> createState() => _CategoryWiseSpendScreenState();
}

class _CategoryWiseSpendScreenState extends State<CategoryWiseSpendScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _categoryData;
  String _selectedPeriod = 'monthly';

  @override
  void initState() {
    super.initState();
    _loadCategoryData();
  }

  Future<void> _loadCategoryData() async {
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

      final result = await AnalyticsService.getCategoryWiseSpending(
        userId, 
        token: token, 
        period: _selectedPeriod,
      );

      setState(() {
        _categoryData = result['success'] ? result['data'] : null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading category data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadCategoryData();
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    _loadCategoryData();
  }

  @override
  Widget build(BuildContext context) {
    final String currencySymbol = _getCurrencySymbol(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category wise Spend'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF7E5EFD),
        foregroundColor: Colors.white,
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
                      // Period Selector
                      _CardContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Removed 'Select Period' label
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _PeriodTab(
                                    title: 'Monthly',
                                    value: 'monthly',
                                    groupValue: _selectedPeriod,
                                    onTap: _onPeriodChanged,
                                  ),
                                  const SizedBox(width: 6),
                                  _PeriodTab(
                                    title: 'Year to Date',
                                    value: 'yeartodate',
                                    groupValue: _selectedPeriod,
                                    onTap: _onPeriodChanged,
                                  ),
                                  const SizedBox(width: 6),
                                  _PeriodTab(
                                    title: 'Last Month',
                                    value: 'lastMonth',
                                    groupValue: _selectedPeriod,
                                    onTap: _onPeriodChanged,
                                  ),
                                  const SizedBox(width: 6),
                                  _PeriodTab(
                                    title: 'Last 3 Months',
                                    value: 'last3Months',
                                    groupValue: _selectedPeriod,
                                    onTap: _onPeriodChanged,
                                  ),
                                const SizedBox(width: 6),
                                _PeriodTab(
                                  title: 'Last 6 Months',
                                  value: 'last6Months',
                                  groupValue: _selectedPeriod,
                                  onTap: _onPeriodChanged,
                                ),
                                const SizedBox(width: 6),
                                _PeriodTab(
                                  title: 'Last Year',
                                  value: 'lastYear',
                                  groupValue: _selectedPeriod,
                                  onTap: _onPeriodChanged,
                                ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Spending Distribution Chart (moved above)
                      _CardContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Spending Distribution',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _ChartSection(
                              categoryData: _categoryData,
                              currencySymbol: currencySymbol,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Spending Summary Card
                      _CardContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Spending Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _SpendingSummarySection(
                              categoryData: _categoryData,
                              currencySymbol: currencySymbol,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Spending by Category Section
                      const Text(
                        'Spending by Category',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      _CategoryListSection(
                        categoryData: _categoryData,
                        currencySymbol: currencySymbol,
                      ),
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

  String _formatWithCommas(double value) {
    final intVal = value.round();
    final str = intVal.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (i != 0 && count % 3 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join();
  }
}

// Formats API period keys to nicely spaced display text
String _formatPeriodText(String period) {
  final String key = period.toString();
  switch (key) {
    case 'monthly':
      return 'Monthly';
    case 'yeartodate':
      return 'Year to Date';
    case 'lastMonth':
      return 'Last Month';
    case 'last3Months':
      return 'Last 3 Months';
    case 'last6Months':
      return 'Last 6 Months';
    case 'lastYear':
      return 'Last Year';
    case 'total':
      return 'Total';
    default:
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

class _SpendingSummarySection extends StatelessWidget {
  const _SpendingSummarySection({
    required this.categoryData,
    required this.currencySymbol,
  });

  final Map<String, dynamic>? categoryData;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    if (categoryData == null) {
      return const Center(
        child: Text(
          'No spending data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final double totalSpent = _getDoubleValue(categoryData!['totalSpent']) ?? 0.0;
    final String period = _formatPeriodText(categoryData!['period']?.toString() ?? 'period');

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Spent ($period)',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$currencySymbol${_formatWithCommas(totalSpent)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
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

  String _formatWithCommas(double value) {
    final intVal = value.round();
    final str = intVal.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (i != 0 && count % 3 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join();
  }
}

class _CategoryListSection extends StatelessWidget {
  const _CategoryListSection({
    required this.categoryData,
    required this.currencySymbol,
  });

  final Map<String, dynamic>? categoryData;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    if (categoryData == null) {
      return const Center(
        child: Text(
          'No category data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final List<dynamic>? categoryWiseSpending = categoryData!['categoryWiseSpending'];
    final double totalSpent = _getDoubleValue(categoryData!['totalSpent']) ?? 0.0;

    if (categoryWiseSpending == null || categoryWiseSpending.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.category_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No spending data for ${_formatPeriodText((categoryData!['period'] ?? 'this period').toString())}',
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
      );
    }

    // Convert API data to the format expected by the cards
    final List<Map<String, dynamic>> formattedCategories = [];
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

    for (int i = 0; i < categoryWiseSpending.length; i++) {
      final category = categoryWiseSpending[i];
      final name = category['category']?.toString() ?? 'Unknown';
      final amount = _getDoubleValue(category['amount']) ?? 0.0;
      
      // Calculate percentage if not provided
      double percentage = 0.0;
      if (totalSpent > 0) {
        percentage = (amount / totalSpent) * 100;
      }

      formattedCategories.add({
        'name': name,
        'amount': amount,
        'percentage': percentage,
        'color': colors[i % colors.length],
      });
    }

    // Sort by amount (highest first)
    formattedCategories.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    return Column(
      children: formattedCategories.map((category) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _CategoryCard(
          category: category['name'] as String,
          percentage: category['percentage'] as double,
          amount: category['amount'] as double,
          color: category['color'] as Color,
          currencySymbol: currencySymbol,
        ),
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

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.categoryData,
    required this.currencySymbol,
  });

  final Map<String, dynamic>? categoryData;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    if (categoryData == null) {
      return const Center(
        child: Text(
          'No chart data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final List<dynamic>? categoryWiseSpending = categoryData!['categoryWiseSpending'];
    final double totalSpent = _getDoubleValue(categoryData!['totalSpent']) ?? 0.0;

    if (categoryWiseSpending == null || categoryWiseSpending.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No data to display',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Convert API data to the format expected by the chart
    final List<Map<String, dynamic>> formattedCategories = [];
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

    for (int i = 0; i < categoryWiseSpending.length; i++) {
      final category = categoryWiseSpending[i];
      final name = category['category']?.toString() ?? 'Unknown';
      final amount = _getDoubleValue(category['amount']) ?? 0.0;
      
      // Calculate percentage if not provided
      double percentage = 0.0;
      if (totalSpent > 0) {
        percentage = (amount / totalSpent) * 100;
      }

      formattedCategories.add({
        'name': name,
        'amount': amount,
        'percentage': percentage,
        'color': colors[i % colors.length],
      });
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: AspectRatio(
            aspectRatio: 1,
            child: _DonutChart(
              values: formattedCategories.map((data) => data['amount'] as double).toList(),
              totalSpent: totalSpent,
              currencySymbol: currencySymbol,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 1,
          child: _Legend(categories: formattedCategories),
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
}

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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.percentage,
    required this.amount,
    required this.color,
    required this.currencySymbol,
  });

  final String category;
  final double percentage;
  final double amount;
  final Color color;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$currencySymbol${_formatWithCommas(amount)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(1)}% of total',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWithCommas(double value) {
    final intVal = value.round();
    final str = intVal.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (i != 0 && count % 3 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join();
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.values,
    required this.totalSpent,
    required this.currencySymbol,
  });

  final List<double> values;
  final double totalSpent;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: CustomPaint(
        painter: _DonutChartPainter(
          values: values,
          totalSpent: totalSpent,
          currencySymbol: currencySymbol,
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.values,
    required this.totalSpent,
    required this.currencySymbol,
  });

  final List<double> values;
  final double totalSpent;
  final String currencySymbol;

  // Colors matching the category data
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

    // Start from top (12 o'clock position)
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

    // Create inner hole with white background
    final innerHolePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final double innerRadius = (size.width - thickness) / 2;
    canvas.drawCircle(size.center(Offset.zero), innerRadius, innerHolePaint);

    // Center text removed as requested
  }

  String _formatWithCommas(double value) {
    final intVal = value.round();
    final str = intVal.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (i != 0 && count % 3 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.categories});

  final List<Map<String, dynamic>> categories;

  @override
  Widget build(BuildContext context) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(categories.length, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colors[index % colors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  categories[index]['name'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
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
