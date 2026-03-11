import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart' as intl;
import '../../services/workspace_service.dart';

/// Workspace Analytics Screen - Web Optimized
/// Track spending patterns and budget utilization with visual charts
class WorkspaceAnalyticsWebScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String workspaceId;

  const WorkspaceAnalyticsWebScreen({
    Key? key,
    required this.userId,
    required this.token,
    required this.workspaceId,
  }) : super(key: key);

  @override
  State<WorkspaceAnalyticsWebScreen> createState() => _WorkspaceAnalyticsWebScreenState();
}

class _WorkspaceAnalyticsWebScreenState extends State<WorkspaceAnalyticsWebScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedTimeframe = 'Last 30 days';
  String _selectedCategorySort = 'By amount';
  String _selectedTrendCategory = 'All categories';

  List<Map<String, dynamic>> _categoryData = [];
  List<Map<String, dynamic>> _trendData = [];

  final Map<String, Color> _categoryColors = {
    'Travel': const Color(0xFF6366F1),
    'Software': const Color(0xFF8B5CF6),
    'Office': const Color(0xFF10B981),
    'Meals': const Color(0xFFF59E0B),
    'Other': const Color(0xFF6B7280),
    'Entertainment': const Color(0xFFEC4899),
    'Marketing': const Color(0xFF3B82F6),
    'Supplies': const Color(0xFFF97316),
  };

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get timeframe parameters
      final timeframeParams = _getTimeframeParams();

      // Build expenses breakdown query with groupBy=category
      final expensesQuery = Map<String, String>.from(timeframeParams);
      expensesQuery['groupBy'] = 'category';

      // Fetch expenses breakdown (category data)
      final expensesResult = await WorkspaceService.getExpensesBreakdown(
        workspaceId: widget.workspaceId,
        userId: widget.userId,
        query: expensesQuery,
        token: widget.token,
      );

      // Fetch spend over time (trend data) - only needs from/to
      final spendQuery = <String, String>{
        'from': timeframeParams['from']!,
        'to': timeframeParams['to']!,
      };

      final spendResult = await WorkspaceService.getSpendOverTime(
        workspaceId: widget.workspaceId,
        userId: widget.userId,
        query: spendQuery,
        token: widget.token,
      );

      if (!mounted) return;

      if (expensesResult['success'] == true && spendResult['success'] == true) {
        try {
          // Safely extract data with type checking
          final expensesDataRaw = expensesResult['data'];
          final spendDataRaw = spendResult['data'];
          
          debugPrint('🔍 Expenses data type: ${expensesDataRaw.runtimeType}');
          debugPrint('🔍 Spend data type: ${spendDataRaw.runtimeType}');
          
          Map<String, dynamic> expensesData;
          Map<String, dynamic> spendData;
          
          // Ensure expensesData is a Map
          if (expensesDataRaw is Map<String, dynamic>) {
            expensesData = expensesDataRaw;
          } else if (expensesDataRaw is Map) {
            // Handle non-typed Map
            expensesData = Map<String, dynamic>.from(expensesDataRaw);
          } else if (expensesDataRaw is List) {
            expensesData = {'breakdown': expensesDataRaw};
          } else {
            expensesData = {'breakdown': []};
          }
          
          // Ensure spendData is a Map
          if (spendDataRaw is Map<String, dynamic>) {
            spendData = spendDataRaw;
          } else if (spendDataRaw is Map) {
            // Handle non-typed Map
            spendData = Map<String, dynamic>.from(spendDataRaw);
          } else if (spendDataRaw is List) {
            spendData = {'data': {'byDate': spendDataRaw}};
          } else {
            spendData = {'data': {'byDate': []}};
          }

          debugPrint('✅ Parsed expenses data keys: ${expensesData.keys}');
          debugPrint('✅ Parsed spend data keys: ${spendData.keys}');

          setState(() {
            _categoryData = _parseCategoryData(expensesData);
            _trendData = _parseTrendData(spendData);
            _isLoading = false;
          });
        } catch (parseError) {
          debugPrint('❌ Parse error: $parseError');
          debugPrint('❌ Expenses result: $expensesResult');
          debugPrint('❌ Spend result: $spendResult');
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Error parsing analytics data: $parseError';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = expensesResult['error']?.toString() ?? 
                         spendResult['error']?.toString() ?? 
                         'Failed to load analytics';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Load analytics error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Map<String, String> _getTimeframeParams() {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedTimeframe) {
      case 'Last 7 days':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Last 90 days':
        startDate = now.subtract(const Duration(days: 90));
        break;
      case 'Last 6 months':
        startDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case 'Last year':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default: // 'Last 30 days'
        startDate = now.subtract(const Duration(days: 30));
    }

    // Format dates as YYYY-MM-DD
    final fromDate = intl.DateFormat('yyyy-MM-dd').format(startDate);
    final toDate = intl.DateFormat('yyyy-MM-dd').format(now);

    return {
      'from': fromDate,
      'to': toDate,
    };
  }

  List<Map<String, dynamic>> _parseCategoryData(Map<String, dynamic> data) {
    // Response format: { "breakdown": [{ "label": "Travel", "amount": 2000.00, "count": 10 }] }
    // Safely extract breakdown array
    dynamic breakdownRaw = data['breakdown'];
    List<dynamic> breakdown;
    
    if (breakdownRaw is List) {
      breakdown = breakdownRaw;
    } else if (breakdownRaw is List<dynamic>) {
      breakdown = breakdownRaw;
    } else {
      breakdown = [];
    }
    
    // Calculate total from breakdown amounts
    final total = breakdown.fold<double>(
      0.0,
      (sum, item) {
        if (item is! Map) return sum;
        try {
          final itemMap = item is Map<String, dynamic> 
              ? item 
              : Map<String, dynamic>.from(item as Map);
          final amount = itemMap['amount'];
          if (amount == null) return sum;
          final amountValue = amount is num ? amount.toDouble() : (double.tryParse(amount.toString()) ?? 0.0);
          return sum + amountValue;
        } catch (e) {
          debugPrint('⚠️ Error parsing breakdown item: $e');
          return sum;
        }
      },
    );

    return breakdown.map((item) {
      try {
        final itemMap = item is Map<String, dynamic> 
            ? item 
            : (item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{});
        final label = itemMap['label'] as String? ?? 'Other';
        final amount = (itemMap['amount'] as num?)?.toDouble() ?? 0.0;
        final percent = total > 0 ? (amount / total) * 100 : 0.0;

        return {
          'category': label,
          'amount': amount,
          'color': _categoryColors[label] ?? const Color(0xFF6B7280),
          'percent': percent,
        };
      } catch (e) {
        debugPrint('⚠️ Error mapping breakdown item: $e');
        return {
          'category': 'Other',
          'amount': 0.0,
          'color': const Color(0xFF6B7280),
          'percent': 0.0,
        };
      }
    }).toList();
  }

  List<Map<String, dynamic>> _parseTrendData(Map<String, dynamic> data) {
    // Response format: { "data": { "byDate": [{ "date": "2025-12-15", "amount": 500.00 }] } }
    // Safely extract data object
    dynamic dataObjRaw = data['data'];
    Map<String, dynamic> dataObj;
    
    if (dataObjRaw is Map<String, dynamic>) {
      dataObj = dataObjRaw;
    } else if (dataObjRaw is Map) {
      try {
        dataObj = Map<String, dynamic>.from(dataObjRaw);
      } catch (e) {
        debugPrint('⚠️ Error converting data object: $e');
        dataObj = {};
      }
    } else {
      dataObj = {};
    }
    
    // Safely extract byDate array
    dynamic byDateRaw = dataObj['byDate'];
    List<dynamic> byDate;
    
    if (byDateRaw is List) {
      byDate = byDateRaw;
    } else if (byDateRaw is List<dynamic>) {
      byDate = byDateRaw;
    } else {
      byDate = [];
    }

    return byDate.map((item) {
      try {
        final itemMap = item is Map<String, dynamic> 
            ? item 
            : (item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{});
        final dateStr = itemMap['date'] as String? ?? '';
        String formattedMonth = '';
        
        try {
          if (dateStr.isNotEmpty) {
            final date = DateTime.parse(dateStr);
            formattedMonth = intl.DateFormat('MMM').format(date);
          }
        } catch (e) {
          formattedMonth = dateStr;
        }

        return {
          'month': formattedMonth,
          'amount': (itemMap['amount'] as num?)?.toDouble() ?? 0.0,
        };
      } catch (e) {
        debugPrint('⚠️ Error mapping trend item: $e');
        return {
          'month': '',
          'amount': 0.0,
        };
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: const Color(0xFFF9FAFB),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: const Color(0xFFF9FAFB),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAnalytics,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workspace Analytics',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Track spending patterns and budget utilization',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildDropdown(_selectedTimeframe, [
                      'Last 7 days',
                      'Last 30 days',
                      'Last 90 days',
                      'Last 6 months',
                      'Last year',
                    ], (value) {
                      setState(() {
                        _selectedTimeframe = value!;
                      });
                      _loadAnalytics();
                    }),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Spend by Category
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
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
                        'Spend by Category',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      _buildDropdown(_selectedCategorySort, [
                        'By amount',
                        'By name',
                        'By count',
                      ], (value) {
                        setState(() {
                          _selectedCategorySort = value!;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Pie Chart and Legend
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Pie Chart
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: SizedBox(
                            width: 300,
                            height: 300,
                            child: CustomPaint(
                              painter: PieChartPainter(_categoryData),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Total Spend',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${_categoryData.fold<double>(0, (sum, item) => sum + item['amount']).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Legend
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _categoryData.map((data) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: data['color'],
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['category'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        Text(
                                          '\$${data['amount'].toStringAsFixed(2)} • ${data['percent']}%',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Monthly Trends
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
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
                        'Monthly Trends',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      _buildDropdown(_selectedTrendCategory, [
                        'All categories',
                        'Travel',
                        'Software',
                        'Office',
                        'Meals',
                      ], (value) {
                        setState(() {
                          _selectedTrendCategory = value!;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Bar Chart
                  SizedBox(
                    height: 300,
                    child: CustomPaint(
                      painter: BarChartPainter(_trendData),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          isDense: true,
        ),
      ),
    );
  }
}

/// Custom Pie Chart Painter
class PieChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  PieChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final innerRadius = radius * 0.6;

    double startAngle = -math.pi / 2;

    for (var item in data) {
      final sweepAngle = (item['percent'] as double) / 100 * 2 * math.pi;
      
      // Outer arc
      final paint = Paint()
        ..color = item['color']
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
      );
      path.lineTo(center.dx, center.dy);
      path.close();

      canvas.drawPath(path, paint);

      // Inner circle (donut hole)
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, innerRadius, innerPaint);

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Custom Bar Chart Painter
class BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  BarChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxAmount = data.map((e) => e['amount'] as double).reduce(math.max);
    final barWidth = (size.width - 100) / data.length - 20;
    final chartHeight = size.height - 40;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    for (int i = 0; i <= 5; i++) {
      final y = chartHeight - (chartHeight / 5 * i);
      canvas.drawLine(
        Offset(50, y),
        Offset(size.width - 20, y),
        gridPaint,
      );

      // Draw Y-axis labels
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: '\$${(maxAmount / 5 * i).toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - 8));
    }

    // Draw bars
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final amount = item['amount'] as double;
      final barHeight = (amount / maxAmount) * chartHeight;
      final x = 60 + i * (barWidth + 20);
      final y = chartHeight - barHeight;

      // Draw bar
      final barPaint = Paint()
        ..color = const Color(0xFF6366F1)
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, barPaint);

      // Draw month label
      final monthPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: item['month'],
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
      );
      monthPainter.layout();
      monthPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - monthPainter.width / 2, chartHeight + 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

