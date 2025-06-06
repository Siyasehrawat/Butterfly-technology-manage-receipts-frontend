import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../providers/receipt_provider.dart';
import '../providers/setting_provider.dart';
import 'receipt_details_screen.dart';
import 'filters_screen.dart';

class ReportsScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? filterParams;

  const ReportsScreen({
    Key? key,
    required this.userId,
    this.filterParams,
  }) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedTimeFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredReceipts = [];
  List<Map<String, dynamic>> savedReceipts = [];
  bool _isLoading = true;
  double _totalAmount = 0;
  bool _hasCustomDateRange = false;
  String _customDateRangeText = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF7E5EFD),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.filterParams != null) {
        final receiptProvider =
        Provider.of<ReceiptProvider>(context, listen: false);
        widget.filterParams!.forEach((key, value) {
          receiptProvider.updateFilter(key, value);
        });

        if (widget.filterParams!['fromDate'] != null &&
            widget.filterParams!['toDate'] != null) {
          _checkForCustomDateRange(
              widget.filterParams!['fromDate'], widget.filterParams!['toDate']);
        }
      }
      _fetchReceipts();
    });
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    super.dispose();
  }

  void _checkForCustomDateRange(String fromDate, String toDate) {
    try {
      final DateTime from = DateTime.parse(fromDate);
      final DateTime to = DateTime.parse(toDate);
      final DateFormat dateFormat = DateFormat('MMMM dd, yyyy');

      setState(() {
        _hasCustomDateRange = true;
        _customDateRangeText =
        '${dateFormat.format(from)} - ${dateFormat.format(to)}';
        _selectedTimeFilter = 'Custom';
      });
    } catch (e) {
      debugPrint('Error parsing custom date range: $e');
    }
  }

  Future<void> _fetchReceipts() async {
    setState(() {
      _isLoading = true;
    });

    await _fetchSavedReceipts();
    _filterReceipts();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchSavedReceipts() async {
    final url =
        'https://manage-receipt-backend-bnl1.onrender.com/api/receipts/${widget.userId}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> receipts = List<Map<String, dynamic>>.from(
            data is List ? data : data['receipts'] ?? []);

        receipts.sort((a, b) {
          DateTime? dateA = _parseDate(a['updatedAt']) ??
              _parseDate(a['createdAt']) ??
              _parseDate(a['receiptDate']);

          DateTime? dateB = _parseDate(b['updatedAt']) ??
              _parseDate(b['createdAt']) ??
              _parseDate(b['receiptDate']);

          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;

          return dateB.compareTo(dateA);
        });

        receipts =
            receipts.where((receipt) => receipt['isSaved'] != false).toList();

        setState(() {
          savedReceipts = receipts;
        });
      } else {
        debugPrint(
            'Failed to load receipts: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint("Error fetching receipts: $e");
    }
  }

  DateTime? _parseDate(dynamic dateString) {
    if (dateString == null) return null;
    try {
      return DateTime.parse(dateString.toString());
    } catch (e) {
      try {
        final DateFormat formatter = DateFormat('MM-dd-yyyy');
        return formatter.parse(dateString.toString());
      } catch (e) {
        debugPrint('Error parsing date: $e');
        return null;
      }
    }
  }

  void _filterReceipts() {
    final receiptProvider =
    Provider.of<ReceiptProvider>(context, listen: false);
    List<Map<String, dynamic>> providerFilteredReceipts = savedReceipts;

    final filters = receiptProvider.filters;

    if (filters.isNotEmpty) {
      providerFilteredReceipts = savedReceipts.where((receipt) {
        if (filters['merchant'] != null && filters['merchant'].isNotEmpty) {
          final merchant = (receipt['merchant'] ?? '').toLowerCase();
          if (!merchant.contains(filters['merchant'].toLowerCase())) {
            return false;
          }
        }

        if (filters['fromDate'] != null && filters['fromDate'].isNotEmpty) {
          try {
            final receiptDate = _parseDate(receipt['receiptDate']);
            final fromDate = DateTime.parse(filters['fromDate']);

            if (receiptDate == null || receiptDate.isBefore(fromDate)) {
              return false;
            }

            if (filters['toDate'] != null && filters['toDate'].isNotEmpty) {
              final toDate = DateTime.parse(filters['toDate']);
              final adjustedToDate = toDate.add(const Duration(days: 1));
              if (receiptDate.isAfter(adjustedToDate)) {
                return false;
              }
            }
          } catch (e) {
            debugPrint('Error parsing date: $e');
          }
        }

        if (filters['minAmount'] != null && filters['minAmount'].isNotEmpty) {
          try {
            final receiptAmount =
                double.tryParse(receipt['amount']?.toString() ?? '0') ?? 0;
            final minAmount = double.tryParse(filters['minAmount']) ?? 0;

            if (receiptAmount < minAmount) {
              return false;
            }
          } catch (e) {
            debugPrint('Error parsing min amount: $e');
          }
        }

        if (filters['maxAmount'] != null && filters['maxAmount'].isNotEmpty) {
          try {
            final receiptAmount =
                double.tryParse(receipt['amount']?.toString() ?? '0') ?? 0;
            final maxAmount =
                double.tryParse(filters['maxAmount']) ?? double.infinity;

            if (receiptAmount > maxAmount) {
              return false;
            }
          } catch (e) {
            debugPrint('Error parsing max amount: $e');
          }
        }

        return true;
      }).toList();
    }

    List<Map<String, dynamic>> timeFilteredReceipts = [];
    final now = DateTime.now();

    if (_hasCustomDateRange) {
      final fromDateStr = receiptProvider.filters['fromDate'];
      final toDateStr = receiptProvider.filters['toDate'];

      if (fromDateStr != null && toDateStr != null) {
        try {
          final fromDate = DateTime.parse(fromDateStr);
          final toDate = DateTime.parse(toDateStr);

          timeFilteredReceipts = providerFilteredReceipts.where((receipt) {
            try {
              final receiptDate = _parseDate(receipt['receiptDate']);
              return receiptDate != null &&
                  receiptDate
                      .isAfter(fromDate.subtract(const Duration(days: 1))) &&
                  receiptDate.isBefore(toDate.add(const Duration(days: 1)));
            } catch (e) {
              debugPrint('Error parsing date: $e');
              return false;
            }
          }).toList();
        } catch (e) {
          debugPrint('Error parsing custom date range: $e');
          timeFilteredReceipts = List.from(providerFilteredReceipts);
        }
      } else {
        timeFilteredReceipts = List.from(providerFilteredReceipts);
      }
    } else if (_selectedTimeFilter == 'All') {
      timeFilteredReceipts = List.from(providerFilteredReceipts);
    } else {
      DateTime startDate;
      DateTime? endDate;

      switch (_selectedTimeFilter) {
        case 'Last week':
          startDate = now.subtract(const Duration(days: 7));
          endDate = now;
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 1)
              .subtract(const Duration(days: 1));
          break;
        case 'Last Month':
          final lastMonth = now.month == 1 ? 12 : now.month - 1;
          final year = now.month == 1 ? now.year - 1 : now.year;
          startDate = DateTime(year, lastMonth, 1);
          endDate = DateTime(now.year, now.month, 1)
              .subtract(const Duration(days: 1));
          break;
        default:
          startDate = DateTime(1900);
          endDate = null;
      }

      timeFilteredReceipts = providerFilteredReceipts.where((receipt) {
        try {
          final receiptDate = _parseDate(receipt['receiptDate']);
          if (receiptDate == null) return false;

          if (endDate != null) {
            return receiptDate
                .isAfter(startDate.subtract(const Duration(days: 1))) &&
                receiptDate.isBefore(endDate.add(const Duration(days: 1)));
          } else {
            return receiptDate
                .isAfter(startDate.subtract(const Duration(days: 1)));
          }
        } catch (e) {
          debugPrint('Error parsing date: $e');
          return false;
        }
      }).toList();
    }

    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) {
      _filteredReceipts = timeFilteredReceipts;
    } else {
      _filteredReceipts = timeFilteredReceipts.where((receipt) {
        final merchant = (receipt['merchant'] ?? '').toLowerCase();
        final category = (receipt['category'] ?? '').toLowerCase();
        final amount = (receipt['amount'] ?? '').toString().toLowerCase();
        final date = (receipt['receiptDate'] ?? '').toLowerCase();

        return merchant.contains(searchQuery) ||
            category.contains(searchQuery) ||
            amount.contains(searchQuery) ||
            date.contains(searchQuery);
      }).toList();
    }

    _totalAmount = _filteredReceipts.fold(0, (sum, receipt) {
      final amount = double.tryParse(receipt['amount']?.toString() ?? '0') ?? 0;
      return sum + amount;
    });
  }

  void _clearAllFilters() {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);

    receiptProvider.clearFilters();

    setState(() {
      _selectedTimeFilter = 'All';
      _hasCustomDateRange = false;
      _customDateRangeText = '';
      _searchController.clear();
    });

    _filterReceipts();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All filters cleared'),
        backgroundColor: Color(0xFF7E5EFD),
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _hasActiveFilters() {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    final filters = receiptProvider.filters;

    return (filters['merchant'] != null && filters['merchant'].isNotEmpty) ||
        (filters['fromDate'] != null && filters['fromDate'].isNotEmpty) ||
        (filters['toDate'] != null && filters['toDate'].isNotEmpty) ||
        (filters['minAmount'] != null && filters['minAmount'].isNotEmpty) ||
        (filters['maxAmount'] != null && filters['maxAmount'].isNotEmpty) ||
        (filters['categoryIds'] != null && (filters['categoryIds'] as List?)?.isNotEmpty == true) ||
        _searchController.text.isNotEmpty ||
        _selectedTimeFilter != 'All';
  }

  Widget _buildActiveFiltersIndicator() {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    final filters = receiptProvider.filters;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;
    List<Widget> filterChips = [];

    // Search filter
    if (_searchController.text.isNotEmpty) {
      filterChips.add(_buildFilterChip(
        'Search: "${_searchController.text}"',
            () {
          setState(() {
            _searchController.clear();
            _filterReceipts();
          });
        },
      ));
    }

    // Time filter (only if not 'All' and not custom date range)
    if (_selectedTimeFilter != 'All' && !_hasCustomDateRange) {
      filterChips.add(_buildFilterChip(
        'Time: $_selectedTimeFilter',
            () {
          setState(() {
            _selectedTimeFilter = 'All';
            _filterReceipts();
          });
        },
      ));
    }

    // Merchant filter
    if (filters['merchant'] != null && filters['merchant'].isNotEmpty) {
      filterChips.add(_buildFilterChip(
        'Merchant: ${filters['merchant']}',
            () {
          receiptProvider.updateFilter('merchant', null);
          _filterReceipts();
        },
      ));
    }

    // Category filter
    if (filters['categoryIds'] != null && (filters['categoryIds'] as List?)?.isNotEmpty == true) {
      final categoryIds = filters['categoryIds'] as List;
      final categoryNames = filters['categories'] as List? ?? [];
      String displayText = categoryNames.isNotEmpty
          ? (categoryNames.length == 1 ? 'Category: ${categoryNames.first}' : 'Categories: ${categoryNames.length} selected')
          : 'Category: ${categoryIds.length} selected';

      filterChips.add(_buildFilterChip(
        displayText,
            () {
          receiptProvider.updateFilter('categoryIds', null);
          receiptProvider.updateFilter('categories', null);
          receiptProvider.updateFilter('category', null);
          receiptProvider.updateFilter('categoryId', null);
          _filterReceipts();
        },
      ));
    }

    // Date range filter (consolidated) - only show if there's a custom date range
    if (filters['fromDate'] != null && filters['fromDate'].isNotEmpty) {
      String dateText = '';
      try {
        final DateTime from = DateTime.parse(filters['fromDate']);
        final DateFormat dateFormat = DateFormat('MMM dd, yyyy');

        if (filters['toDate'] != null && filters['toDate'].isNotEmpty) {
          final DateTime to = DateTime.parse(filters['toDate']);
          dateText = 'Date: ${dateFormat.format(from)} - ${dateFormat.format(to)}';
        } else {
          dateText = 'Date: From ${dateFormat.format(from)}';
        }
      } catch (e) {
        dateText = 'Date: Custom range';
      }

      filterChips.add(_buildFilterChip(
        dateText,
            () {
          receiptProvider.updateFilter('fromDate', null);
          receiptProvider.updateFilter('toDate', null);
          setState(() {
            _hasCustomDateRange = false;
            _customDateRangeText = '';
            _selectedTimeFilter = 'All';
            _filterReceipts();
          });
        },
      ));
    }

    // Amount filter (consolidated)
    if ((filters['minAmount'] != null && filters['minAmount'].isNotEmpty) ||
        (filters['maxAmount'] != null && filters['maxAmount'].isNotEmpty)) {
      String amountText = '';
      final minAmount = filters['minAmount'];
      final maxAmount = filters['maxAmount'];

      if (minAmount != null && minAmount.isNotEmpty && maxAmount != null && maxAmount.isNotEmpty) {
        amountText = 'Amount: $currencySymbol$minAmount - $currencySymbol$maxAmount';
      } else if (minAmount != null && minAmount.isNotEmpty) {
        amountText = 'Amount: Min $currencySymbol$minAmount';
      } else if (maxAmount != null && maxAmount.isNotEmpty) {
        amountText = 'Amount: Max $currencySymbol$maxAmount';
      }

      filterChips.add(_buildFilterChip(
        amountText,
            () {
          receiptProvider.updateFilter('minAmount', null);
          receiptProvider.updateFilter('maxAmount', null);
          _filterReceipts();
        },
      ));
    }

    if (filterChips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Active Filters:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7E5EFD),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearAllFilters,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: filterChips,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7E5EFD).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF7E5EFD),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 12,
                color: Color(0xFF7E5EFD),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterTab(String title) {
    final isSelected = _selectedTimeFilter == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeFilter = title;
          if (title != 'Custom') {
            _hasCustomDateRange = false;
            _customDateRangeText = '';
          }
          _filterReceipts();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8E6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
          isSelected ? Border.all(color: const Color(0xFF7E5EFD)) : null,
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

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF7E5EFD),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: true,
          child: Column(
            children: [
              // Purple header with logo
              Container(
                color: const Color(0xFF7E5EFD),
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Reports',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/logo.png',
                          width: 30,
                          height: 30,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text(
                              'MR',
                              style: TextStyle(
                                color: Color(0xFF7E5EFD),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // White content area
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8E6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(Icons.search, color: Colors.grey),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    hintText:
                                    'Search by merchant, category, or date',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _filterReceipts();
                                    });
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.filter_list,
                                    color: Colors.grey),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (ctx) => const FiltersScreen(),
                                    ),
                                  ).then((_) {
                                    final receiptProvider =
                                    Provider.of<ReceiptProvider>(context,
                                        listen: false);
                                    if (receiptProvider.filters['fromDate'] !=
                                        null &&
                                        receiptProvider.filters['toDate'] !=
                                            null) {
                                      _checkForCustomDateRange(
                                          receiptProvider.filters['fromDate'],
                                          receiptProvider.filters['toDate']);
                                    }
                                    _fetchReceipts();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Consolidated Active Filters Section
                      if (_hasActiveFilters()) _buildActiveFiltersIndicator(),

                      // Time filter tabs
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTimeFilterTab('All'),
                              const SizedBox(width: 8),
                              _buildTimeFilterTab('Last week'),
                              const SizedBox(width: 8),
                              _buildTimeFilterTab('This Month'),
                              const SizedBox(width: 8),
                              _buildTimeFilterTab('Last Month'),
                              if (_hasCustomDateRange) ...[
                                const SizedBox(width: 8),
                                _buildTimeFilterTab('Custom'),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Total amount
                      if (!_isLoading && _filteredReceipts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8E6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Amount:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '$currencySymbol${_totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF7E5EFD),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Receipts list
                      Expanded(
                        child: _isLoading
                            ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF7E5EFD)),
                          ),
                        )
                            : _filteredReceipts.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No receipts found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your filters',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                            : RefreshIndicator(
                          onRefresh: _fetchReceipts,
                          color: const Color(0xFF7E5EFD),
                          child: ListView.builder(
                            itemCount: _filteredReceipts.length,
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 16,
                            ),
                            itemBuilder: (context, index) {
                              final receipt = _filteredReceipts[index];
                              final imageUrl = receipt['imageLink'] ?? '';
                              final merchant = receipt['merchant'] ?? 'Unknown';
                              final amount = receipt['amount']?.toString() ?? '0';
                              final category = receipt['category']?.toString() ?? 'Uncategorized';

                              String formattedDate = 'No date';
                              if (receipt['receiptDate'] != null) {
                                try {
                                  final DateTime? date = _parseDate(receipt['receiptDate']);
                                  if (date != null) {
                                    formattedDate = DateFormat('MMMM d, yyyy').format(date);
                                  }
                                } catch (e) {
                                  debugPrint('Error parsing date: $e');
                                }
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ReceiptDetailsScreen(
                                          receipt: receipt,
                                          imageUrl: imageUrl,
                                          userId: widget.userId,
                                          imageId: receipt['imageId']?.toString() ?? '',
                                          isNewReceipt: false,
                                        ),
                                      ),
                                    ).then((_) => _fetchReceipts());
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8E6FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey.shade300),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: imageUrl.isNotEmpty
                                                  ? Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child, loadingProgress) =>
                                                loadingProgress == null
                                                    ? child
                                                    : const Center(
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                                                    ),
                                                  ),
                                                ),
                                                errorBuilder: (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.receipt,
                                                  size: 30,
                                                  color: Color(0xFF7E5EFD),
                                                ),
                                              )
                                                  : const Icon(
                                                Icons.receipt,
                                                size: 30,
                                                color: Color(0xFF7E5EFD),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  merchant,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "$currencySymbol$amount",
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                category,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF7E5EFD),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                formattedDate,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
