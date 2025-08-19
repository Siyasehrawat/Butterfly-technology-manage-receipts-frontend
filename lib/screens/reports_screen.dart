import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/receipt_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';
import '../utils/encryption_helper.dart';
import '../utils/category_icons.dart';
import 'receipt_details_screen.dart';
import 'filters_screen.dart';

enum ExportFormat { excel, pdf }

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
  bool _isExporting = false;
  bool _isLoadingMore = false;
  double _totalAmount = 0;
  bool _hasCustomDateRange = false;
  String _customDateRangeText = '';

// Pagination variables
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalCount = 0;
  bool _hasNextPage = false;

// UPDATED: Track both total user receipts and filtered total receipts
  int _totalUserReceipts = 0; // Unfiltered total (all user receipts)
  int _filteredTotalReceipts = 0; // Filtered total from API response

// Selection functionality
  Set<String> _selectedReceiptIds = <String>{};
  bool _isSelectionMode = false;
  ExportFormat _selectedFormat = ExportFormat.excel;

// Track if any changes were made to receipts
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // Set status bar to match the purple header
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

        // Handle both parameter formats for date filtering - prioritize dateFrom/dateTo
        Map<String, dynamic> normalizedParams = Map.from(widget.filterParams!);

        // Prioritize dateFrom/dateTo format and convert to fromDate/toDate for internal use
        if (normalizedParams['dateFrom'] != null) {
          normalizedParams['fromDate'] = normalizedParams['dateFrom'];
          // Keep dateFrom for API calls that expect this format
        }
        if (normalizedParams['dateTo'] != null) {
          normalizedParams['toDate'] = normalizedParams['dateTo'];
          // Keep dateTo for API calls that expect this format
        }

        normalizedParams.forEach((key, value) {
          receiptProvider.updateFilter(key, value);
        });

        // Check for custom date range with prioritized dateFrom/dateTo format
        String? fromDate = normalizedParams['dateFrom'] ?? normalizedParams['fromDate'];
        String? toDate = normalizedParams['dateTo'] ?? normalizedParams['toDate'];

        if (fromDate != null && toDate != null) {
          _checkForCustomDateRange(fromDate, toDate);
        }
      }
      _fetchReceipts(reset: true);
    });
  }

  @override
  void dispose() {
    // Reset status bar when leaving
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    super.dispose();
  }

  bool _isPdfReceipt(Map<String, dynamic> receipt) {
    final link = (receipt['decryptedImageLink'] ?? receipt['decryptedImageUrl'] ?? receipt['imageLink'] ?? receipt['imageUrl'] ?? '').toString().toLowerCase();
    return link.endsWith('.pdf');
  }

// Enhanced manual receipt detection
  bool _isManualReceipt(Map<String, dynamic> receipt) {
    final imageUrl = receipt['decryptedImageLink'] ?? receipt['decryptedImageUrl'] ?? receipt['imageLink'] ?? receipt['imageUrl'] ?? '';
    return receipt['isManual'] == true ||
        imageUrl.contains('placeholder') ||
        imageUrl.contains('Manual+Receipt') ||
        imageUrl.isEmpty ||
        imageUrl == 'null';
  }

// Method to get the correct image URL for a receipt
  String _getReceiptImageUrl(Map<String, dynamic> receipt) {
    final possibleUrls = [
      receipt['decryptedImageUrl'],
      receipt['decryptedImageLink'],
      receipt['imageUrl'],
      receipt['imageLink'],
      receipt['image_url'],
    ];

    for (final url in possibleUrls) {
      if (url != null && url.toString().isNotEmpty && url.toString() != 'null') {
        final urlString = url.toString();
        if (urlString.startsWith('http://') || urlString.startsWith('https://')) {
          return urlString;
        }
      }
    }

    return '';
  }

// Toggle selection mode and show format selection
  void _toggleSelectionMode() {
    if (!_isSelectionMode) {
      // Entering selection mode - show format selection first
      _showFormatSelectionDialog();
    } else {
      // Exiting selection mode
      setState(() {
        _isSelectionMode = false;
        _selectedReceiptIds.clear();
      });
    }
  }

// Show format selection dialog with proper state management
  void _showFormatSelectionDialog() {
    ExportFormat tempSelectedFormat = _selectedFormat; // Temporary selection

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Select Export Format',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E5EFD),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Choose the format for your export:'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              tempSelectedFormat = ExportFormat.excel;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: tempSelectedFormat == ExportFormat.excel
                                  ? const Color(0xFFE8E6FF)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: tempSelectedFormat == ExportFormat.excel
                                    ? const Color(0xFF7E5EFD)
                                    : Colors.grey.shade300,
                                width: tempSelectedFormat == ExportFormat.excel ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.table_chart,
                                  color: tempSelectedFormat == ExportFormat.excel
                                      ? const Color(0xFF7E5EFD)
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Excel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: tempSelectedFormat == ExportFormat.excel
                                        ? const Color(0xFF7E5EFD)
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              tempSelectedFormat = ExportFormat.pdf;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: tempSelectedFormat == ExportFormat.pdf
                                  ? const Color(0xFFE8E6FF)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: tempSelectedFormat == ExportFormat.pdf
                                    ? const Color(0xFF7E5EFD)
                                    : Colors.grey.shade300,
                                width: tempSelectedFormat == ExportFormat.pdf ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.picture_as_pdf,
                                  color: tempSelectedFormat == ExportFormat.pdf
                                      ? const Color(0xFF7E5EFD)
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PDF',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: tempSelectedFormat == ExportFormat.pdf
                                        ? const Color(0xFF7E5EFD)
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedFormat = tempSelectedFormat; // Apply the selection
                      _isSelectionMode = true;
                    });
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Color(0xFF7E5EFD),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleReceiptSelection(String receiptId) {
    setState(() {
      if (_selectedReceiptIds.contains(receiptId)) {
        _selectedReceiptIds.remove(receiptId);
      } else {
        _selectedReceiptIds.add(receiptId);
      }
    });
  }

  // UPDATED: Select all receipts across all pages, not just current page
  Future<void> _selectAllReceipts() async {
    setState(() {
      _selectedReceiptIds.clear();
    });

    try {
      final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final filters = receiptProvider.filters;

      // Build query parameters to get ALL receipts (no pagination)
      // Use a very large page size to get all receipts in one call
      final Map<String, String> queryParams = {
        'page': '1',
        'pageSize': '10000', // Large enough to get all receipts
      };

      // Add all current filters to query parameters (same as _fetchSavedReceipts)
      if (filters['merchant'] != null && filters['merchant'].isNotEmpty) {
        queryParams['merchant'] = filters['merchant'];
      }

      if (filters['categoryIds'] != null && filters['categoryIds'] is List) {
        final categoryIds = filters['categoryIds'] as List;
        if (categoryIds.isNotEmpty) {
          queryParams['categoryIds'] = categoryIds.join(',');
        }
      } else if (filters['category'] != null && filters['category'].isNotEmpty) {
        queryParams['category'] = filters['category'];
      }

      // Use proper date filtering with _buildDateFilters helper (server-side only)
      final dateFilters = _buildDateFilters(filters);
      queryParams.addAll(dateFilters);

      if (filters['minAmount'] != null && filters['minAmount'].isNotEmpty) {
        queryParams['minAmount'] = filters['minAmount'];
      }

      if (filters['maxAmount'] != null && filters['maxAmount'].isNotEmpty) {
        queryParams['maxAmount'] = filters['maxAmount'];
      }

      if (filters['tags'] != null && (filters['tags'] as List).isNotEmpty) {
        queryParams['tags'] = (filters['tags'] as List).join(',');
      }

      // Build query string
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final endpoint = '/receipts/${widget.userId}?$queryString';

      debugPrint('Selecting all receipts from: $endpoint');
      debugPrint('Query parameters: $queryParams');

      final response = await ApiService.get(endpoint, token: userProvider.token);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> allReceipts = [];

        if (data is Map && data.containsKey('receipts')) {
          allReceipts = List<Map<String, dynamic>>.from(data['receipts'] ?? []);
        } else {
          allReceipts = List<Map<String, dynamic>>.from(data is List ? data : []);
        }

        // Filter out unsaved receipts (same as in _fetchSavedReceipts)
        allReceipts = allReceipts.where((receipt) => receipt['isSaved'] != false).toList();

        // Apply only client-side search filter locally; date/amount already on server
        allReceipts = _applyLocalFiltersToReceipts(allReceipts);

        setState(() {
          for (final receipt in allReceipts) {
            final receiptId = receipt['id']?.toString() ?? '';
            if (receiptId.isNotEmpty) {
              _selectedReceiptIds.add(receiptId);
            }
          }
        });

        // Show feedback to user about how many receipts were selected
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected ${_selectedReceiptIds.length} receipts across all pages'),
              backgroundColor: const Color(0xFF7E5EFD),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        debugPrint('Successfully selected ${_selectedReceiptIds.length} receipts across all pages');
      } else {
        debugPrint('Failed to fetch all receipts for selection: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch receipts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error selecting all receipts: $e');
      // Fallback to selecting only current page receipts
      setState(() {
        _selectedReceiptIds = _filteredReceipts
            .map((receipt) => receipt['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected ${_selectedReceiptIds.length} receipts from current page (fallback)'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }


  // Helper method to apply local filters (time filter and search filter)
  List<Map<String, dynamic>> _applyLocalFiltersToReceipts(List<Map<String, dynamic>> receipts) {
    List<Map<String, dynamic>> filtered = receipts;

    // Only apply client-side search. All other filters (date, amount, category, tags)
    // should be handled by the backend via query params for accuracy.
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((receipt) {
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

    return filtered;
  }

// UPDATED: Simplified export method with receiptIds instead of imageIds
  void _exportSelectedReceipts() {
    if (_selectedReceiptIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one receipt to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _exportReceipts(
      format: _selectedFormat,
      selectedIds: _selectedReceiptIds,
    );
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

  Future<void> _fetchReceipts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        savedReceipts.clear();
        _filteredReceipts.clear();
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    await _fetchSavedReceipts();
    _filterReceipts();

    setState(() {
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  // UPDATED: Now properly handles filtered total count from pagination response
  Future<void> _fetchSavedReceipts() async {
    try {
      final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final filters = receiptProvider.filters;

      // Build query parameters
      final Map<String, String> queryParams = {
        'page': _currentPage.toString(),
        'pageSize': _pageSize.toString(),
      };

      // Add filters to query parameters
      if (filters['merchant'] != null && filters['merchant'].isNotEmpty) {
        queryParams['merchant'] = filters['merchant'];
      }

      if (filters['categoryIds'] != null && filters['categoryIds'] is List) {
        final categoryIds = filters['categoryIds'] as List;
        if (categoryIds.isNotEmpty) {
          queryParams['categoryIds'] = categoryIds.join(',');
        }
      } else if (filters['category'] != null && filters['category'].isNotEmpty) {
        // Handle backward compatibility for single category
        queryParams['category'] = filters['category'];
      }

      // Enhanced date filtering with validation
      final dateFilters = _buildDateFilters(filters);
      queryParams.addAll(dateFilters);

      if (filters['minAmount'] != null && filters['minAmount'].isNotEmpty) {
        queryParams['minAmount'] = filters['minAmount'];
      }

      if (filters['maxAmount'] != null && filters['maxAmount'].isNotEmpty) {
        queryParams['maxAmount'] = filters['maxAmount'];
      }

      if (filters['tags'] != null && (filters['tags'] as List).isNotEmpty) {
        queryParams['tags'] = (filters['tags'] as List).join(',');
      }

      // Build query string
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final endpoint = '/receipts/${widget.userId}?$queryString';

      debugPrint('Fetching receipts from: $endpoint');

      // UPDATED: Using ApiService instead of direct HTTP call
      final response = await ApiService.get(endpoint, token: userProvider.token);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        List<Map<String, dynamic>> receipts = [];
        Map<String, dynamic> pagination = {};

        if (data is Map && data.containsKey('receipts')) {
          // New paginated API response format
          receipts = List<Map<String, dynamic>>.from(data['receipts'] ?? []);
          // pagination can be null in new response
          pagination = (data['pagination'] is Map) ? Map<String, dynamic>.from(data['pagination']) : {};

          setState(() {
            _totalCount = pagination['totalCount'] ?? 0;
            _hasNextPage = pagination['hasNextPage'] ?? false;

            // Prefer new totals structure if present
            final filteredTotals = data['filteredReceipts'];
            final totalTotals = data['totalReceipts'];

            if (filteredTotals is Map) {
              _filteredTotalReceipts = (filteredTotals['totalCount'] as num?)?.toInt() ?? _filteredTotalReceipts;
              _totalAmount = (filteredTotals['totalAmount'] as num?)?.toDouble() ?? _totalAmount;
              debugPrint('Using filtered totals from API: count=$_filteredTotalReceipts, amount=$_totalAmount');
            } else {
              // Fallback to pagination totalCount for filtered count
              _filteredTotalReceipts = pagination['totalCount'] ?? 0;
              // Legacy single totalAmount at root
              if (data.containsKey('totalAmount')) {
                _totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                debugPrint('Using totalAmount from API root: $_totalAmount');
              } else {
                debugPrint('No totalAmount in API response, will calculate locally if needed');
              }
            }

            // Get total user receipts only on first page load and when no filters are applied
            if (_currentPage == 1) {
              // Check if any filters are applied
              final hasFilters = _hasAnyFiltersApplied();

              if (!hasFilters) {
                // No filters applied - prefer new totalReceipts if available otherwise pagination
                if (totalTotals is Map) {
                  _totalUserReceipts = (totalTotals['totalCount'] as num?)?.toInt() ?? (pagination['totalCount'] ?? 0);
                } else {
                  _totalUserReceipts = pagination['totalCount'] ?? 0;
                }
              } else {
                // Filters are applied - fetch unfiltered total separately if we don't have it
                if (_totalUserReceipts == 0) {
                  // If new totals block exists, use it directly; else fetch
                  if (totalTotals is Map) {
                    _totalUserReceipts = (totalTotals['totalCount'] as num?)?.toInt() ?? 0;
                  } else {
                    _fetchTotalCountFromUnfilteredData();
                  }
                }
              }
            }
          });

          debugPrint('Pagination info: totalCount=${pagination['totalCount']}, hasFilters=${_hasAnyFiltersApplied()}');
          debugPrint('Display totals: filtered=$_filteredTotalReceipts, unfiltered=$_totalUserReceipts, totalAmount=$_totalAmount');
        } else {
          // Fallback to old format
          receipts = List<Map<String, dynamic>>.from(data is List ? data : []);

          // For old format, count all receipts as total
          if (_currentPage == 1) {
            setState(() {
              _totalUserReceipts = receipts.length;
              _filteredTotalReceipts = receipts.length;
              // For old format, calculate total amount locally
              _totalAmount = receipts.fold(0.0, (sum, receipt) {
                final amount = double.tryParse(receipt['amount']?.toString() ?? '0') ?? 0;
                return sum + amount;
              });
            });
          }
        }

        // Filter out unsaved receipts
        receipts = receipts.where((receipt) => receipt['isSaved'] != false).toList();

        // Sort receipts by receipt date (newest first)
        receipts.sort((a, b) {
          DateTime? dateA = _parseDate(a['receiptDate']);
          DateTime? dateB = _parseDate(b['receiptDate']);

          if (dateA == null) {
            dateA = _parseDate(a['updatedAt']) ?? _parseDate(a['createdAt']);
          }
          if (dateB == null) {
            dateB = _parseDate(b['updatedAt']) ?? _parseDate(b['createdAt']);
          }

          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;

          return dateB.compareTo(dateA);
        });

        setState(() {
          if (_currentPage == 1) {
            savedReceipts = receipts;
          } else {
            savedReceipts.addAll(receipts);
          }
        });
      } else {
        debugPrint('Failed to load receipts: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint("Error fetching receipts: $e");
    }
  }

  // UPDATED: Helper method to check if any filters are applied
  bool _hasAnyFiltersApplied() {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    final filters = receiptProvider.filters;

    return (filters['merchant'] != null && filters['merchant'].isNotEmpty) ||
        (filters['fromDate'] != null && filters['fromDate'].isNotEmpty) ||
        (filters['toDate'] != null && filters['toDate'].isNotEmpty) ||
        (filters['minAmount'] != null && filters['minAmount'].isNotEmpty) ||
        (filters['maxAmount'] != null && filters['maxAmount'].isNotEmpty) ||
        (filters['categoryIds'] != null && (filters['categoryIds'] as List?)?.isNotEmpty == true) ||
        (filters['tags'] != null && (filters['tags'] as List?)?.isNotEmpty == true) ||
        _searchController.text.isNotEmpty ||
        (_selectedTimeFilter != 'All' && _selectedTimeFilter != 'Custom');
  }

// UPDATED: Fetch total count by making one call without filters using ApiService
  Future<void> _fetchTotalCountFromUnfilteredData() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final endpoint = '/receipts/${widget.userId}?page=1&pageSize=1';

      // UPDATED: Using ApiService instead of direct HTTP call
      final response = await ApiService.get(endpoint, token: userProvider.token);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is Map && data.containsKey('pagination')) {
          final pagination = data['pagination'] ?? {};
          setState(() {
            _totalUserReceipts = pagination['totalCount'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching total count: $e");
    }
  }

  Future<void> _loadMoreReceipts() async {
    if (_hasNextPage && !_isLoadingMore) {
      setState(() {
        _currentPage++;
      });
      await _fetchReceipts();
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
    // Backend returns already-filtered results (date, amount, tags, category).
    // Here we only apply client-side search and then sort for stable ordering.
    List<Map<String, dynamic>> baseReceipts = List.from(savedReceipts);

    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      baseReceipts = baseReceipts.where((receipt) {
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

    _filteredReceipts = baseReceipts;

    // Apply additional sorting to filtered receipts to ensure consistent ordering
    _filteredReceipts.sort((a, b) {
      DateTime? dateA = _parseDate(a['receiptDate']);
      DateTime? dateB = _parseDate(b['receiptDate']);

      // Fall back to other date fields if receiptDate is not available
      if (dateA == null) {
        dateA = _parseDate(a['updatedAt']) ?? _parseDate(a['createdAt']);
      }
      if (dateB == null) {
        dateB = _parseDate(b['updatedAt']) ?? _parseDate(b['createdAt']);
      }

      // Handle null dates
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      // Sort by most recent date first
      return dateB.compareTo(dateA);
    });

    // Only calculate total locally when a client-side search is active.
    if (_currentPage == 1 && _searchController.text.isNotEmpty) {
      final localTotal = _filteredReceipts.fold(0.0, (sum, receipt) {
        final amount = double.tryParse(receipt['amount']?.toString() ?? '0') ?? 0;
        return sum + amount;
      });
      _totalAmount = localTotal;
      debugPrint('Updated total amount with client-side search: $_totalAmount');
    }
  }

  Future<void> _exportReceipts({
    required ExportFormat format,
    required Set<String> selectedIds,
  }) async {
    List<int> receiptIds = []; // Changed from imageIds to receiptIds

    // UPDATED: Convert selectedIds directly to integers for the payload
    // This ensures all selected receipt IDs are included, not just those from current page
    receiptIds = selectedIds
        .map((id) => int.tryParse(id))
        .where((id) => id != null)
        .cast<int>()
        .toList();

    if (receiptIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No receipts selected for export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // UPDATED: Changed payload structure to use receiptIds instead of imageIds
      final exportRequestBody = {
        'userId': widget.userId,
        'receiptIds': receiptIds, // Changed from 'imageIds' to 'receiptIds'
        'format': format == ExportFormat.excel ? 'excel' : 'pdf',
      };

      debugPrint('Export request body: ${json.encode(exportRequestBody)}');
      debugPrint('Total receipt IDs to export: ${receiptIds.length}');

      // UPDATED: Using the correct endpoint /receipts/exportRequest
      final response = await ApiService.post(
        '/receipts/export', // Changed from '/receipts/export'
        body: exportRequestBody,
        token: userProvider.token,
        additionalHeaders: {
          'Accept': 'application/octet-stream',
        },
      );

      debugPrint('Export response status: ${response.statusCode}');
      debugPrint('Export response headers: ${response.headers}');

      if (response.statusCode == 200) {
        final Uint8List fileBytes = response.bodyBytes;
        debugPrint('${format == ExportFormat.excel ? 'Excel' : 'PDF'} file size: ${fileBytes.length} bytes');

        // Validate file content
        if (fileBytes.isEmpty) {
          throw Exception('Received empty file from server');
        }

        await _saveAndShareFile(fileBytes, format);

        // Exit selection mode after successful export
        setState(() {
          _isSelectionMode = false;
          _selectedReceiptIds.clear();
          _isExporting = false; // Reset exporting state after successful export
        });
      } else {
        // Enhanced error handling
        String errorMessage = 'Export failed with status: ${response.statusCode}';

        try {
          final errorBody = json.decode(response.body);
          if (errorBody['message'] != null) {
            errorMessage = errorBody['message'];
          } else if (errorBody['error'] != null) {
            errorMessage = errorBody['error'];
          }
        } catch (e) {
          // If response body is not JSON, use the raw body
          if (response.body.isNotEmpty) {
            errorMessage += '\nResponse: ${response.body}';
          }
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _exportReceipts(format: format, selectedIds: selectedIds),
            ),
          ),
        );
      }
    } finally {
      if (mounted && _isExporting) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  /// UPDATED: Simplified save and share file method
  Future<void> _saveAndShareFile(
      Uint8List bytes,
      ExportFormat format,
      ) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final extension = format == ExportFormat.excel ? 'xlsx' : 'pdf';
      final filename = 'receipts_export_$timestamp.$extension';

      // Use app-specific directory (no permissions required)
      Directory directory;

      if (Platform.isAndroid) {
        // For Android, use app-specific external files directory
        directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();

        // Create a Downloads subfolder for better organization
        final downloadsDir = Directory('${directory.path}/Downloads');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        directory = downloadsDir;
      } else if (Platform.isIOS) {
        // For iOS, use documents directory
        directory = await getApplicationDocumentsDirectory();
      } else {
        // For other platforms
        directory = await getApplicationDocumentsDirectory();
      }

      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes);

      debugPrint('File saved to: ${file.path}');

      // Verify file was written correctly
      final savedFileSize = await file.length();
      if (savedFileSize != bytes.length) {
        throw Exception('File save verification failed: expected ${bytes.length} bytes, got $savedFileSize bytes');
      }

      // Always share the file immediately after saving
      await _shareFile(file.path, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${format == ExportFormat.excel ? 'Excel' : 'PDF'} file exported successfully!'),
                Text(
                  'File: $filename',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  'Size: ${(bytes.length / 1024).toStringAsFixed(1)} KB',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const Text(
                  'The file has been shared. You can save it to your preferred location.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF7E5EFD),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Share Again',
              textColor: Colors.white,
              onPressed: () => _shareFile(file.path, filename),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Save and share file error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export file: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Share file using the system share dialog
  Future<void> _shareFile(String filePath, String filename) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Receipt Export - $filename',
        subject: 'Exported Receipts',
      );
    } catch (e) {
      debugPrint('Share file error: $e');
      // Don't show error to user for sharing failures as it's not critical
    }
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

    _fetchReceipts(reset: true);

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
        (filters['tags'] != null && (filters['tags'] as List?)?.isNotEmpty == true) ||
        _searchController.text.isNotEmpty ||
        (_selectedTimeFilter != 'All' && _selectedTimeFilter != 'Custom'); // Exclude 'Custom' if it's derived from fromDate/toDate
  }

  Widget _buildActiveFiltersIndicator() {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    final filters = receiptProvider.filters;
    final userProvider = Provider.of<UserProvider>(context);
    final currencySymbol = userProvider.effectiveCurrencySymbol;
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
          _fetchReceipts(reset: true);
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
          _fetchReceipts(reset: true);
        },
      ));
    }

    // Tags filter
    if (filters['tags'] != null && (filters['tags'] as List?)?.isNotEmpty == true) {
      final tags = filters['tags'] as List;
      String displayText = tags.length == 1 ? 'Tag: ${tags.first}' : 'Tags: ${tags.length} selected';

      filterChips.add(_buildFilterChip(
        displayText,
            () {
          receiptProvider.updateFilter('tags', null);
          _fetchReceipts(reset: true);
        },
      ));
    }

    // Date range filter
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
          });
          _fetchReceipts(reset: true);
        },
      ));
    }

    // Amount filter
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
          _fetchReceipts(reset: true);
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
          final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
          final now = DateTime.now();
          DateTime? from;
          DateTime? to;

          if (title == 'All') {
            // Clear server-side date filters
            receiptProvider.updateFilter('fromDate', null);
            receiptProvider.updateFilter('toDate', null);
            setState(() {
              _selectedTimeFilter = title;
              _hasCustomDateRange = false;
              _customDateRangeText = '';
            });
            _fetchReceipts(reset: true);
            return;
          }

          switch (title) {
            case 'Last week':
              from = now.subtract(const Duration(days: 7));
              to = now;
              break;
            case 'Year to Date':
              from = DateTime(now.year, 1, 1);
              to = now;
              break;
            case 'This Month':
              from = DateTime(now.year, now.month, 1);
              to = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));
              break;
            case 'Last Month':
              final lastMonth = now.month == 1 ? 12 : now.month - 1;
              final year = now.month == 1 ? now.year - 1 : now.year;
              from = DateTime(year, lastMonth, 1);
              to = DateTime(now.year, now.month, 1).subtract(const Duration(days: 1));
              break;
            default:
              from = null;
              to = null;
          }

          if (from != null && to != null) {
            final fromStr = DateFormat('yyyy-MM-dd').format(from);
            final toStr = DateFormat('yyyy-MM-dd').format(to);
            receiptProvider.updateFilter('fromDate', fromStr);
            receiptProvider.updateFilter('toDate', toStr);
          }

          setState(() {
            _selectedTimeFilter = title;
            _hasCustomDateRange = false;
            _customDateRangeText = '';
          });

          _fetchReceipts(reset: true);
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
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currencySymbol = userProvider.effectiveCurrencySymbol;

    return Scaffold(
      body: Column(
        children: [
          // Purple header with logo - NO SafeArea here
          Container(
            color: const Color(0xFF7E5EFD),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8, // Add status bar height manually
              bottom: 16,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    // Return true to indicate potential changes were made
                    Navigator.pop(context, _hasChanges);
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
                // Single export button that toggles selection mode
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

          // Selection mode header
          if (_isSelectionMode)
            Container(
              color: const Color(0xFFE8E6FF),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${_selectedReceiptIds.length} selected',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7E5EFD),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _selectedFormat == ExportFormat.excel
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _selectedFormat == ExportFormat.excel ? 'Excel' : 'PDF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _selectedFormat == ExportFormat.excel
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _selectAllReceipts,
                    child: const Text(
                      'Select All',
                      style: TextStyle(
                        color: Color(0xFF7E5EFD),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedReceiptIds.clear();
                      });
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
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
                                _fetchReceipts(reset: true);
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
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTimeFilterTab('All'),
                          const SizedBox(width: 2),
                          _buildTimeFilterTab('Last week'),
                          const SizedBox(width: 2),
                          _buildTimeFilterTab('Year to Date'),
                          const SizedBox(width: 2),
                          _buildTimeFilterTab('This Month'),
                          const SizedBox(width: 2),
                          _buildTimeFilterTab('Last Month'),
                          if (_hasCustomDateRange) ...[
                            const SizedBox(width: 2),
                            _buildTimeFilterTab('Custom'),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Total amount and export info
                  if (!_isLoading && _filteredReceipts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
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
                                  '$currencySymbol ${_totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF7E5EFD),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // UPDATED: Show filtered total when filters are applied, otherwise show total user receipts
                                    Text(
                                      _hasAnyFiltersApplied()
                                          ? 'Filtered Receipts: $_filteredTotalReceipts'
                                          : 'Total Receipts: $_totalUserReceipts',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    // Show both totals when filters are applied and we have unfiltered count
                                    if (_hasAnyFiltersApplied() && _totalUserReceipts > 0 && _totalUserReceipts != _filteredTotalReceipts)
                                      Text(
                                        'Total Receipts: $_totalUserReceipts',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    if (_selectedReceiptIds.isNotEmpty)
                                      Text(
                                        'Selected: ${_selectedReceiptIds.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF7E5EFD),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                                // Export button behavior
                                if (_isSelectionMode)
                                  GestureDetector(
                                    onTap: _isExporting ? null : _exportSelectedReceipts,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7E5EFD),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.file_download,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Export Selected',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: _isExporting ? null : _toggleSelectionMode,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7E5EFD),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.file_download,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Export',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Receipts list with updated layout
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
                      onRefresh: () => _fetchReceipts(reset: true),
                      color: const Color(0xFF7E5EFD),
                      child: ListView.builder(
                        itemCount: _filteredReceipts.length + (_hasNextPage ? 1 : 0),
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 16,
                        ),
                        itemBuilder: (context, index) {
                          // Load more button
                          if (index == _filteredReceipts.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(
                                child: _isLoadingMore
                                    ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF7E5EFD)),
                                )
                                    : ElevatedButton(
                                  onPressed: _loadMoreReceipts,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7E5EFD),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 12),
                                  ),
                                  child: const Text(
                                    'Load More',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          final receipt = _filteredReceipts[index];
                          final imageUrl = _getReceiptImageUrl(receipt);
                          final merchant = receipt['merchant'] ?? 'Unknown';
                          final amount = receipt['amount']?.toString() ?? '0';
                          final category = receipt['category']?.toString() ?? 'Uncategorized';
                          final isPdf = _isPdfReceipt(receipt);
                          final isManual = _isManualReceipt(receipt);
                          // UPDATED: Use 'id' field for receipt selection
                          final receiptId = receipt['id']?.toString() ?? '';
                          final isSelected = _selectedReceiptIds.contains(receiptId);
                          final hasReminder = receipt['hasReminder'] ?? false; // Use API flag
                          final hasSplit = receipt['hasSplitBill'] ?? false; // Use API flag

                          String formattedDate = 'No date';
                          if (receipt['receiptDate'] != null) {
                            try {
                              final DateTime? date = _parseDate(receipt['receiptDate']);
                              if (date != null) {
                                formattedDate = DateFormat('MMM d, yyyy').format(date);
                              }
                            } catch (e) {
                              debugPrint('Error parsing date: $e');
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: GestureDetector(
                              onTap: () async {
                                if (_isSelectionMode) {
                                  _toggleReceiptSelection(receiptId);
                                } else {
                                  // Show loading indicator
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                                      ),
                                    ),
                                  );

                                  try {
                                    // Get token from UserProvider
                                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                                    
                                    // Fetch fresh receipt details from API
                                    final response = await ApiService.get(
                                      '/receipts/details/$receiptId?userId=${widget.userId}',
                                      token: userProvider.token,
                                    );

                                    // Close loading indicator
                                    if (mounted) Navigator.pop(context);

                                    if (response.statusCode == 200) {
                                      final data = json.decode(response.body);
                                      final freshReceipt = data['receipt'] ?? data;

                                      // Decrypt image URL
                                      final encryptedImageLink = freshReceipt['imageLink'] as String?;
                                      String decryptedImageUrl = imageUrl; // fallback to list data
                                      if (encryptedImageLink != null) {
                                        final decrypted = EncryptionHelper.decryptUrl(encryptedImageLink);
                                        if (decrypted != null) {
                                          decryptedImageUrl = decrypted;
                                          freshReceipt['decryptedImageLink'] = decryptedImageUrl;
                                          debugPrint('🔓 Reports - Decrypted image URL: $decryptedImageUrl');
                                        }
                                      }

                                      final isPdfFresh = decryptedImageUrl.toLowerCase().endsWith('.pdf');
                                      final isManualFresh = _isManualReceipt(freshReceipt);

                                      // Navigate to receipt details and handle result
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReceiptDetailsScreen(
                                            receipt: freshReceipt,
                                            imageUrl: decryptedImageUrl,
                                            userId: widget.userId,
                                            imageId: freshReceipt['imageId']?.toString() ?? '',
                                            isNewReceipt: false,
                                            isPdf: isPdfFresh,
                                            isManualReceipt: isManualFresh,
                                          ),
                                        ),
                                      ).then((result) {
                                        // Track if changes were made and refresh if needed
                                        if (result == true) {
                                          setState(() {
                                            _hasChanges = true;
                                          });
                                          _fetchReceipts(reset: true);
                                        }
                                        // If result is null or false, don't refresh (no changes made)
                                      });
                                    } else {
                                      // API failed, show error
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Failed to load receipt details. Please try again.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    // Close loading indicator if still showing
                                    if (mounted && Navigator.canPop(context)) {
                                      Navigator.pop(context);
                                    }
                                    
                                    debugPrint('Error fetching receipt details: $e');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to load receipt details. Please try again.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFD1C4E9) : const Color(0xFFE8E6FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: _isSelectionMode
                                      ? Border.all(
                                    color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  )
                                      : null,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      // Selection icon - now using green plus icon
                                      if (_isSelectionMode) ...[
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected ? const Color(0xFF7E5EFD) : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey,
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                            Icons.add,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                              : const Icon(
                                            Icons.add,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                      ],

                                      // Icon on the left: merchant/category-based avatar
                                      Builder(
                                        builder: (context) {
                                          final brandIcon = getMerchantIcon(merchant);
                                          final brandColor = getMerchantColor(merchant);
                                          final emoji = getMerchantEmoji(merchant) ?? getCategoryEmoji(category);
                                          final icon = brandIcon ?? getCategoryIcon(category);
                                          final color = brandColor ?? getCategoryColor(category);
                                          if (emoji != null) {
                                            return Text(
                                              emoji,
                                              style: const TextStyle(fontSize: 24),
                                            );
                                          }
                                          return CircleAvatar(
                                            radius: 24,
                                            backgroundColor: color.withOpacity(0.15),
                                            child: Icon(icon, size: 24, color: color),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 16),

                                      // Middle section - Merchant name and category
                                      Expanded(
                                        flex: 1,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Merchant name with overflow protection
                                            Text(
                                              merchant,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.black87,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            // Category with overflow protection
                                            Row(
                                              children: [
                                                // Category
                                                Expanded(
                                                  child: Text(
                                                    category,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Color(0xFF7E5EFD),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                // Reminder/Split Icons
                                                if (hasReminder || hasSplit)
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (hasReminder) ...[
                                                        const Icon(
                                                          Icons.notifications_active,
                                                          size: 16,
                                                          color: Colors.green,
                                                        ),
                                                        if (hasSplit) const SizedBox(width: 4),
                                                      ],
                                                      if (hasSplit)
                                                        const Icon(
                                                          Icons.call_split,
                                                          size: 16,
                                                          color: Colors.orange,
                                                        ),
                                                    ],
                                                  ),
                                              ],
                                            ),

                                          ],
                                        ),
                                      ),

                                      // Right section - Amount, date, and icons
                                      // Right section - only amount and date
                                      Expanded(
                                        flex: 1,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '$currencySymbol$amount',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              formattedDate,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
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
}

// Validates and formats date parameters for API calls
Map<String, String> _buildDateFilters(Map<String, dynamic> filters) {
  Map<String, String> dateParams = {};

  // Prioritize dateFrom/dateTo format for API calls
  String? fromDate = filters['dateFrom'] ?? filters['fromDate'];
  if (fromDate != null && fromDate.isNotEmpty) {
    try {
      // Validate date format and ensure it's in YYYY-MM-DD format
      final parsedDate = DateTime.parse(fromDate);
      // Use dateFrom for API parameter name
      dateParams['dateFrom'] = DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (e) {
      debugPrint('Invalid dateFrom format: $fromDate, error: $e');
    }
  }

  // Prioritize dateTo format for API calls
  String? toDate = filters['dateTo'] ?? filters['toDate'];
  if (toDate != null && toDate.isNotEmpty) {
    try {
      // Validate date format and ensure it's in YYYY-MM-DD format
      final parsedDate = DateTime.parse(toDate);
      // Use dateTo for API parameter name
      dateParams['dateTo'] = DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (e) {
      debugPrint('Invalid dateTo format: $toDate, error: $e');
    }
  }

  return dateParams;
}