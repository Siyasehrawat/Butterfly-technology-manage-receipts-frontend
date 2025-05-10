import 'dart:convert';
import 'package:flutter/material.dart';
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
  Map<int, String> _categoryMap =
      {}; // Map to store category ID to name mapping
  bool _hasCustomDateRange = false;
  String _customDateRangeText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Apply any filter params passed to the screen
      if (widget.filterParams != null) {
        final receiptProvider =
            Provider.of<ReceiptProvider>(context, listen: false);
        widget.filterParams!.forEach((key, value) {
          receiptProvider.updateFilter(key, value);
        });

        // Check if custom date range is set
        if (widget.filterParams!['fromDate'] != null &&
            widget.filterParams!['toDate'] != null) {
          _checkForCustomDateRange(
              widget.filterParams!['fromDate'], widget.filterParams!['toDate']);
        }
      }

      _fetchCategories().then((_) => _fetchReceipts());
    });
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

  Future<void> _fetchCategories() async {
    try {
      final url =
          Uri.parse('https://manage-receipt-backend-bnl1.onrender.com/api/categories/get-all-categories');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Create a map of category ID to category name
        for (var category in data) {
          _categoryMap[category['categoryId']] = category['name'];
        }

        // Add a fallback for "Other" category
        _categoryMap[0] = 'Other';
      } else {
        // Fallback categories if API fails
        _categoryMap = {
          1: 'Meal',
          2: 'Education',
          3: 'Medical',
          4: 'Shopping',
          5: 'Travel',
          6: 'Rent',
          0: 'Other',
        };
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      // Fallback categories if API fails
      _categoryMap = {
        1: 'Meal',
        2: 'Education',
        3: 'Medical',
        4: 'Shopping',
        5: 'Travel',
        6: 'Rent',
        0: 'Other',
      };
    }
  }

  Future<void> _fetchSavedReceipts() async {
    final url = 'https://manage-receipt-backend-bnl1.onrender.com/api/receipts/${widget.userId}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> receipts = List<Map<String, dynamic>>.from(
            data is List ? data : data['receipts'] ?? []);

        // Sort receipts by updatedAt or createdAt date in descending order (newest first)
        receipts.sort((a, b) {
          // Try to use updatedAt first, then createdAt, then receiptDate as fallbacks
          DateTime? dateA = _parseDate(a['updatedAt']) ??
              _parseDate(a['createdAt']) ??
              _parseDate(a['receiptDate']);

          DateTime? dateB = _parseDate(b['updatedAt']) ??
              _parseDate(b['createdAt']) ??
              _parseDate(b['receiptDate']);

          // If both dates are null, maintain original order
          if (dateA == null && dateB == null) return 0;

          // If only one date is null, put the non-null date first
          if (dateA == null) return 1;
          if (dateB == null) return -1;

          // Sort in descending order (newest first)
          return dateB.compareTo(dateA);
        });

        // Only include receipts that have been saved (not temporary)
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

  // Helper method to parse dates safely
  DateTime? _parseDate(dynamic dateString) {
    if (dateString == null) return null;
    try {
      // Try parsing with the default format (YYYY-MM-DD)
      return DateTime.parse(dateString.toString());
    } catch (e) {
      try {
        // If parsing fails, handle MM-DD-YYYY format explicitly
        final DateFormat formatter = DateFormat('MM-dd-yyyy');
        return formatter.parse(dateString.toString());
      } catch (e) {
        debugPrint('Error parsing date: $e');
        return null;
      }
    }
  }

  Future<void> _fetchReceipts() async {
    setState(() {
      _isLoading = true;
    });

    // Only fetch saved receipts from the API
    await _fetchSavedReceipts();

    // Apply filters to the fetched receipts
    _filterReceipts();

    setState(() {
      _isLoading = false;
    });
  }

  void _filterReceipts() {
    final receiptProvider =
        Provider.of<ReceiptProvider>(context, listen: false);
    List<Map<String, dynamic>> providerFilteredReceipts = savedReceipts;

    final filters = receiptProvider.filters;

    // Apply filters from the provider
    if (filters.isNotEmpty) {
      providerFilteredReceipts = savedReceipts.where((receipt) {
        // Merchant filter
        if (filters['merchant'] != null && filters['merchant'].isNotEmpty) {
          final merchant = (receipt['merchant'] ?? '').toLowerCase();
          if (!merchant.contains(filters['merchant'].toLowerCase())) {
            return false;
          }
        }

        // Category filter
        if (filters['categoryIds'] != null &&
            filters['categoryIds'] is List &&
            (filters['categoryIds'] as List).isNotEmpty) {
          final receiptCategoryId = receipt['categoryId']?.toString();
          if (receiptCategoryId == null ||
              !(filters['categoryIds'] as List)
                  .contains(int.tryParse(receiptCategoryId))) {
            return false;
          }
        }

        // Date filter
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

        return true;
      }).toList();
    }

    // Apply time filter
    List<Map<String, dynamic>> timeFilteredReceipts = [];
    final now = DateTime.now();

    if (_selectedTimeFilter == 'Custom' && _hasCustomDateRange) {
      // Use the custom date range from filters
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

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) {
      _filteredReceipts = timeFilteredReceipts;
    } else {
      _filteredReceipts = timeFilteredReceipts.where((receipt) {
        final merchant = (receipt['merchant'] ?? '').toLowerCase();
        final category = (receipt['category'] ?? '').toLowerCase();
        final amount = (receipt['amount'] ?? '').toString().toLowerCase();
        final date = (receipt['receiptDate'] ?? '').toLowerCase();

        // Get category name from ID for searching
        String categoryName = 'Uncategorized';
        if (receipt['categoryId'] != null) {
          final categoryId =
              int.tryParse(receipt['categoryId'].toString()) ?? 0;
          categoryName =
              _categoryMap[categoryId]?.toLowerCase() ?? 'uncategorized';
        }

        return merchant.contains(searchQuery) ||
            category.contains(searchQuery) ||
            categoryName.contains(searchQuery) ||
            amount.contains(searchQuery) ||
            date.contains(searchQuery);
      }).toList();
    }

    // Calculate total amount
    _totalAmount = _filteredReceipts.fold(0, (sum, receipt) {
      final amount = double.tryParse(receipt['amount']?.toString() ?? '0') ?? 0;
      return sum + amount;
    });
  }

  void _clearCustomDateFilter() {
    // Clear date filters
    final receiptProvider =
        Provider.of<ReceiptProvider>(context, listen: false);
    receiptProvider.updateFilter('fromDate', null);
    receiptProvider.updateFilter('toDate', null);

    // Reset UI state
    setState(() {
      _hasCustomDateRange = false;
      _customDateRangeText = '';
      _selectedTimeFilter = 'All';
      _filterReceipts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    return Scaffold(
      body: Column(
        children: [
          // Purple header with logo
          Container(
            color: const Color(0xFF7E5EFD),
            padding: const EdgeInsets.only(top: 40, bottom: 16),
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
                                // Check if custom date range is set after returning from filters
                                final receiptProvider =
                                    Provider.of<ReceiptProvider>(context,
                                        listen: false);
                                if (receiptProvider.filters['fromDate'] !=
                                        null &&
                                    receiptProvider.filters['toDate'] != null) {
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

                  // Show custom date range if selected
                  if (_selectedTimeFilter == 'Custom' && _hasCustomDateRange)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.date_range,
                                size: 16, color: Color(0xFF7E5EFD)),
                            const SizedBox(width: 8),
                            Text(
                              _customDateRangeText,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF7E5EFD),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Add cross button to clear custom date filter
                            InkWell(
                              onTap: _clearCustomDateFilter,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Color(0xFF7E5EFD),
                                ),
                              ),
                            ),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemBuilder: (context, index) {
                                    final receipt = _filteredReceipts[index];
                                    final imageUrl = receipt['imageLink'] ??
                                        ''; // Map imageLink
                                    final merchant =
                                        receipt['merchant'] ?? 'Unknown';
                                    final amount =
                                        receipt['amount']?.toString() ?? '0';

                                    // Get category name from categoryId
                                    String category = 'Uncategorized';
                                    if (receipt['categoryId'] != null) {
                                      final categoryId = int.tryParse(
                                              receipt['categoryId']
                                                  .toString()) ??
                                          0;
                                      category = _categoryMap[categoryId] ??
                                          'Uncategorized';
                                    }

                                    // Format the receiptDate
                                    String formattedDate = 'No date';
                                    if (receipt['receiptDate'] != null) {
                                      try {
                                        final DateTime? date =
                                            _parseDate(receipt['receiptDate']);
                                        if (date != null) {
                                          formattedDate =
                                              DateFormat('MMMM d, yyyy')
                                                  .format(date);
                                        }
                                      } catch (e) {
                                        debugPrint('Error parsing date: $e');
                                      }
                                    }

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12.0),
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ReceiptDetailsScreen(
                                                receipt: receipt,
                                                imageUrl:
                                                    imageUrl, // Pass imageLink to details screen
                                                userId: widget.userId,
                                                imageId: receipt['imageId']
                                                        ?.toString() ??
                                                    '',
                                                isNewReceipt: false,
                                              ),
                                            ),
                                          ).then((_) => _fetchReceipts());
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8E6FF),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Row(
                                              children: [
                                                // Receipt thumbnail
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: Colors
                                                            .grey.shade300),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: imageUrl.isNotEmpty
                                                        ? Image.network(
                                                            imageUrl,
                                                            fit: BoxFit.cover,
                                                            loadingBuilder: (context,
                                                                    child,
                                                                    loadingProgress) =>
                                                                loadingProgress ==
                                                                        null
                                                                    ? child
                                                                    : const Center(
                                                                        child:
                                                                            SizedBox(
                                                                          width:
                                                                              20,
                                                                          height:
                                                                              20,
                                                                          child:
                                                                              CircularProgressIndicator(
                                                                            strokeWidth:
                                                                                2,
                                                                            valueColor:
                                                                                AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                                                                          ),
                                                                        ),
                                                                      ),
                                                            errorBuilder: (context,
                                                                    error,
                                                                    stackTrace) =>
                                                                const Icon(
                                                              Icons.receipt,
                                                              size: 30,
                                                              color: Color(
                                                                  0xFF7E5EFD),
                                                            ),
                                                          )
                                                        : const Icon(
                                                            Icons.receipt,
                                                            size: 30,
                                                            color: Color(
                                                                0xFF7E5EFD),
                                                          ),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                // Receipt details
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        merchant,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        "\$$amount",
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Category and date
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      category,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color:
                                                            Color(0xFF7E5EFD),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      formattedDate,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .grey.shade600,
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
    );
  }

  Widget _buildTimeFilterTab(String title) {
    final isSelected = _selectedTimeFilter == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeFilter = title;
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
}
