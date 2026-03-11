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
import '../providers/feature_flags_provider.dart';
import '../services/api_service_bypass.dart';
import '../utils/encryption_helper.dart';
import '../utils/category_icons.dart';
import '../models/receipt_save_result.dart';
import 'receipt_details_screen.dart';

class TaxReportsScreen extends StatefulWidget {
  final String userId;

  const TaxReportsScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<TaxReportsScreen> createState() => _TaxReportsScreenState();
}

class _TaxReportsScreenState extends State<TaxReportsScreen> {
  // Combined filter - only one can be selected at a time
  String _selectedFilter = 'All'; // Default to 'All'
  bool _hasDateRangeFilter = false; // Track if custom date range is applied

  List<Map<String, dynamic>> _filteredReceipts = [];
  List<Map<String, dynamic>> savedReceipts = [];
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isLoadingMore = false;
  double _totalAmount = 0;

  // Pagination variables
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalCount = 0;
  bool _hasNextPage = false;
  int _totalUserReceipts = 0;

  // Tax export logs specific to tax reports API
  List<Map<String, dynamic>> _taxExportLogs = [];
  bool _isLoadingTaxExportLogs = true;

  // Export summary
  Map<String, dynamic> _exportSummary = {};

  // Track if any changes were made to receipts
  bool _hasChanges = false;

  // Date range state for new UI - set wide default range
  DateTime _startDate = DateTime(2020, 1, 1); // Wide default range
  DateTime _endDate = DateTime(2030, 12, 31);
  bool _showCalendar = false;
  DateTime _currentCalendarMonth = DateTime(2025, 7);

  // Add new state variables for enhanced calendar functionality
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;
  bool _isSelectingStartDate = true;
  bool _showManualInput = false;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  // Add new state variable to track selected quick filter
  String? _selectedQuickFilter;

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
      _fetchTaxReportsData(reset: true);
    });

    // Initialize text controllers with current dates
    _startDateController.text = DateFormat('yyyy-MM-dd').format(_startDate);
    _endDateController.text = DateFormat('yyyy-MM-dd').format(_endDate);
    _tempStartDate = _startDate;
    _tempEndDate = _endDate;
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
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

  bool _isManualReceipt(Map<String, dynamic> receipt) {
    final imageUrl = receipt['decryptedImageLink'] ?? receipt['decryptedImageUrl'] ?? receipt['imageLink'] ?? receipt['imageUrl'] ?? '';
    return receipt['isManual'] == true ||
        imageUrl.contains('placeholder') ||
        imageUrl.contains('Manual+Receipt') ||
        imageUrl.isEmpty ||
        imageUrl == 'null';
  }

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

  /// Fetch tax reports data using the new tax-reports API endpoint
  Future<void> _fetchTaxReportsData({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        savedReceipts.clear();
        _filteredReceipts.clear();
        _taxExportLogs.clear();
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    await Future.wait([
      _fetchTaxReportsReceipts(),
      if (reset) _fetchTaxExportLogs(),
    ]);

    _filterReceipts();

    setState(() {
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  /// Fetch receipts using the new /tax-reports/receipts endpoint
  Future<void> _fetchTaxReportsReceipts() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Build query parameters for tax reports endpoint
      final Map<String, String> queryParams = {
        'userId': widget.userId, // Keep as string for query parameters
        'page': _currentPage.toString(),
        'limit': _pageSize.toString(), // Changed from pageSize to limit
      };

      // Add filter based on selected option
      if (_selectedFilter == 'Exported') {
        queryParams['exported'] = 'true';
      } else if (_selectedFilter == 'Not Exported') {
        queryParams['exported'] = 'false';
      }

      // Apply date range filter only if user has specifically set a custom range
      if (_hasDateRangeFilter) {
        queryParams['fromDate'] = _startDate.toIso8601String().split('T')[0];
        queryParams['toDate'] = _endDate.toIso8601String().split('T')[0];
      }

      debugPrint('Fetching tax reports from: /tax-reports/receipts with params: $queryParams');
      debugPrint('Current page: $_currentPage, Page size: $_pageSize');

      final response = await ApiService.get(
        '/tax-reports/receipts',
        token: userProvider.token,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        List<Map<String, dynamic>> receipts = [];
        Map<String, dynamic> pagination = {};
        Map<String, dynamic> summary = {};

        if (data is Map && data.containsKey('receipts')) {
          receipts = List<Map<String, dynamic>>.from(data['receipts'] ?? []);
          pagination = data['pagination'] ?? {};
          summary = data['summary'] ?? {};

          setState(() {
            // Use new pagination format
            _totalCount = pagination['total'] ?? pagination['totalCount'] ?? 0;
            _hasNextPage = pagination['hasMore'] ?? pagination['hasNextPage'] ?? false;
            _exportSummary = summary;

            if (_currentPage == 1) {
              _totalUserReceipts = pagination['total'] ?? pagination['totalCount'] ?? 0;
            }
          });

          debugPrint('Received ${receipts.length} receipts for page $_currentPage');
          debugPrint('Total count: $_totalCount, Has next page: $_hasNextPage');
        } else {
          receipts = List<Map<String, dynamic>>.from(data is List ? data : []);

          if (_currentPage == 1) {
            setState(() {
              _totalUserReceipts = receipts.length;
            });
          }
        }

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
            debugPrint('First page: Set ${receipts.length} receipts');
          } else {
            savedReceipts.addAll(receipts);
            debugPrint('Page $_currentPage: Added ${receipts.length} receipts, total now: ${savedReceipts.length}');
          }
        });
      } else {
        debugPrint('Failed to load tax reports receipts: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint("Error fetching tax reports receipts: $e");
    }
  }

  /// Fetch tax export logs (using same endpoint but for display purposes)
  Future<void> _fetchTaxExportLogs() async {
    setState(() {
      _isLoadingTaxExportLogs = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Build query parameters for tax export logs
      final Map<String, String> queryParams = {
        'userId': widget.userId, // Keep as string for query parameters
        'exported': 'true', // Only get exported receipts for logs
      };

      // Apply date range filter only if user has specifically set a custom range
      if (_hasDateRangeFilter) {
        queryParams['fromDate'] = _startDate.toIso8601String().split('T')[0];
        queryParams['toDate'] = _endDate.toIso8601String().split('T')[0];
      }

      final response = await ApiService.get(
        '/tax-reports/receipts',
        token: userProvider.token,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('receipts')) {
          setState(() {
            _taxExportLogs = List<Map<String, dynamic>>.from(data['receipts'] ?? []);
          });
        } else if (data is List) {
          setState(() {
            _taxExportLogs = List<Map<String, dynamic>>.from(data);
          });
        }
      } else {
        debugPrint('Failed to load tax export logs: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching tax export logs: $e');
    } finally {
      setState(() {
        _isLoadingTaxExportLogs = false;
      });
    }
  }

  // Helper method for calendar quick filters (This Year, Last Year)
  Map<String, String>? _getDateRangeFromFilter(String filter) {
    final now = DateTime.now();

    switch (filter) {
      case 'This Year':
        return {
          'fromDate': DateTime(now.year, 1, 1).toIso8601String(),
          'toDate': DateTime(now.year, 12, 31).toIso8601String(),
        };
      case 'Last Year':
        return {
          'fromDate': DateTime(now.year - 1, 1, 1).toIso8601String(),
          'toDate': DateTime(now.year - 1, 12, 31).toIso8601String(),
        };
      default:
        return null;
    }
  }

  Future<void> _loadMoreReceipts() async {
    if (_hasNextPage && !_isLoadingMore) {
      setState(() {
        _currentPage++;
        _isLoadingMore = true;
      });

      await _fetchTaxReportsReceipts();
      _filterReceipts();

      setState(() {
        _isLoadingMore = false;
      });
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
    _filteredReceipts = List.from(savedReceipts);

    _totalAmount = _filteredReceipts.fold(0, (sum, receipt) {
      final amount = double.tryParse(receipt['amount']?.toString() ?? '0') ?? 0;
      return sum + amount;
    });

    debugPrint('Filtered receipts: ${_filteredReceipts.length} out of ${savedReceipts.length} total');
    debugPrint('Has next page: $_hasNextPage');
  }

  Future<void> _exportTaxReports() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Prepare export request body for tax reports - export only currently displayed receipts
      final List<String> receiptIds = _filteredReceipts.map((receipt) => 
        (receipt['id']?.toString() ?? receipt['receiptId']?.toString() ?? '')
      ).where((id) => id.isNotEmpty).toList();

      final Map<String, dynamic> exportRequestBody = {
        'userId': widget.userId,
        'receiptIds': receiptIds, // Send specific receipt IDs instead of filter parameters
      };

      // Note: Removed filter parameters as we're now sending specific receipt IDs
      // This ensures only the currently displayed receipts are exported

      debugPrint('Tax export request body: ${json.encode(exportRequestBody)}');
      debugPrint('Exporting all filtered receipts: ${_filteredReceipts.length} receipts');
      debugPrint('Selected filter: $_selectedFilter');
      debugPrint('Receipt IDs being exported: $receiptIds');

      final response = await ApiService.post(
        '/tax-reports/export',
        body: exportRequestBody,
        token: userProvider.token,
        additionalHeaders: {
          'Accept': 'application/octet-stream',
        },
      );
      debugPrint('Tax export response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Uint8List fileBytes = response.bodyBytes;
        debugPrint('Tax report file size: ${fileBytes.length} bytes');

        if (fileBytes.isEmpty) {
          throw Exception('Received empty file from server');
        }

        await _saveAndShareTaxFile(fileBytes);

        // Refresh the entire tax reports data after successful export to show updated badges
        _fetchTaxReportsData(reset: true);
      } else {
        // Enhanced error handling
        String errorMessage = 'Tax export failed with status: ${response.statusCode}';

        try {
          final errorBody = json.decode(response.body);
          if (errorBody['message'] != null) {
            errorMessage = errorBody['message'];
          } else if (errorBody['error'] != null) {
            errorMessage = errorBody['error'];
          }
        } catch (e) {
          if (response.body.isNotEmpty) {
            errorMessage += '\nResponse: ${response.body}';
          }
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Tax export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tax export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _exportTaxReports(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _saveAndShareTaxFile(Uint8List bytes) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'tax_reports_export_$timestamp.xlsx';

      Directory directory;

      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        final downloadsDir = Directory('${directory.path}/Downloads');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        directory = downloadsDir;
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes);

      debugPrint('Tax report file saved to: ${file.path}');

      final savedFileSize = await file.length();
      if (savedFileSize != bytes.length) {
        throw Exception('File save verification failed: expected ${bytes.length} bytes, got $savedFileSize bytes');
      }

      await _shareFile(file.path, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tax report exported successfully!'),
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
      debugPrint('Save and share tax file error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export tax file: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _shareFile(String filePath, String filename) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Tax Report Export - $filename',
        subject: 'Exported Tax Reports',
      );
    } catch (e) {
      debugPrint('Share file error: $e');
    }
  }

  void _toggleCalendar() {
    setState(() {
      _showCalendar = !_showCalendar;
      if (_showCalendar) {
        // Reset temp dates to current selection when opening
        _tempStartDate = _hasDateRangeFilter ? _startDate : DateTime.now().subtract(const Duration(days: 30));
        _tempEndDate = _hasDateRangeFilter ? _endDate : DateTime.now();
        _isSelectingStartDate = true;
        _showManualInput = false;
        _selectedQuickFilter = null; // Reset selected filter
        _startDateController.text = DateFormat('yyyy-MM-dd').format(_tempStartDate!);
        _endDateController.text = DateFormat('yyyy-MM-dd').format(_tempEndDate!);
      }
    });
  }

  void _selectDateRange(DateTime start, DateTime end) {
    setState(() {
      _startDate = start;
      _endDate = end;
      _showCalendar = false;
      _hasDateRangeFilter = true; // Mark that user has applied custom date range
    });
    _fetchTaxReportsData(reset: true);
  }

  void _clearDateRangeFilter() {
    setState(() {
      _startDate = DateTime(2020, 1, 1); // Reset to wide default range
      _endDate = DateTime(2030, 12, 31);
      _hasDateRangeFilter = false;
    });
    _fetchTaxReportsData(reset: true);
  }

  void _applyManualDates() {
    try {
      final startDate = DateTime.parse(_startDateController.text);
      final endDate = DateTime.parse(_endDateController.text);

      if (startDate.isAfter(endDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Start date must be before end date'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _selectDateRange(startDate, endDate);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid dates in YYYY-MM-DD format'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleDayTap(DateTime date) {
    setState(() {
      _selectedQuickFilter = null; // Clear quick filter selection when manually selecting dates

      if (_isSelectingStartDate) {
        _tempStartDate = date;
        _isSelectingStartDate = false;
        // If the selected start date is after the current end date, also update end date
        if (_tempEndDate != null && date.isAfter(_tempEndDate!)) {
          _tempEndDate = date;
        }
      } else {
        if (date.isBefore(_tempStartDate!)) {
          // If selected end date is before start date, swap them
          _tempEndDate = _tempStartDate;
          _tempStartDate = date;
        } else {
          _tempEndDate = date;
        }
        _isSelectingStartDate = true;
      }

      // Update text controllers
      if (_tempStartDate != null) {
        _startDateController.text = DateFormat('yyyy-MM-dd').format(_tempStartDate!);
      }
      if (_tempEndDate != null) {
        _endDateController.text = DateFormat('yyyy-MM-dd').format(_tempEndDate!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context);
    final currencySymbol = userProvider.effectiveCurrencySymbol;

    // Check if tax reports feature is enabled
    if (!featureFlagsProvider.isTaxReportsEnabled) {
      return Scaffold(
        body: Column(
          children: [
            // Purple header with logo
            Container(
              color: const Color(0xFF7E5EFD),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 16,
              ),
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
                        'Tax Reports',
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
            // Feature disabled message
            Expanded(
              child: Container(
                color: Colors.white,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Tax Reports Feature Disabled',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'This feature is currently not available.\nPlease contact support for more information.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Purple header with logo
              Container(
                color: const Color(0xFF7E5EFD),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 16,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context, _hasChanges);
                      },
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Tax Reports',
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

              // White content area
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Date range selector
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GestureDetector(
                          onTap: _toggleCalendar,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _hasDateRangeFilter ? const Color(0xFFE8E6FF) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _hasDateRangeFilter ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today, 
                                  color: _hasDateRangeFilter ? const Color(0xFF7E5EFD) : Colors.grey.shade600, 
                                  size: 20
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _hasDateRangeFilter 
                                        ? '${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}'
                                        : 'All dates',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: _hasDateRangeFilter ? const Color(0xFF7E5EFD) : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (_hasDateRangeFilter) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      _clearDateRangeFilter();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7E5EFD),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Filter tabs
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            _buildFilterTab('All'),
                            const SizedBox(width: 12),
                            _buildFilterTab('Exported'),
                            const SizedBox(width: 12),
                            _buildFilterTab('Not Exported'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Summary Section
                      if (!_isLoading && _filteredReceipts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
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
                                        Text(
                                          'Total Receipts: ${_filteredReceipts.length}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Export Button on the right
                                    GestureDetector(
                                      onTap: _isExporting ? null : _exportTaxReports,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50),
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
                                            const Text(
                                              'Export Excel',
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

                      // Receipts List
                      Expanded(
                        child: _isLoading
                            ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                          ),
                        )
                            : _filteredReceipts.isEmpty
                            ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.description,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No tax receipts found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Try adjusting your filters',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                            : RefreshIndicator(
                          onRefresh: () => _fetchTaxReportsData(reset: true),
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
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
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
                              final receiptId = receipt['id']?.toString() ?? receipt['receiptId']?.toString() ?? '';
                              final imageUrl = _getReceiptImageUrl(receipt);
                              final merchant = receipt['merchant'] ?? 'Unknown';
                              final amount = receipt['amount']?.toString() ?? '0';
                              final category = receipt['category']?.toString() ?? 'Uncategorized';
                              final isPdf = _isPdfReceipt(receipt);
                              final isManual = _isManualReceipt(receipt);
                              final hasReminder = receipt['hasReminder'] ?? false; // Use API flag
                              final hasSplit = receipt['hasSplitBill'] ?? false; // Use API flag
                              final isExported = receipt['exportedForTax'] == true || receipt['exported'] == true;

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
                                      final receiptId = receipt['id']?.toString() ?? receipt['receiptId']?.toString() ?? '';
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
                                            debugPrint('🔓 Tax Reports - Decrypted image URL: $decryptedImageUrl');
                                          }
                                        }

                                        final isPdfFresh = decryptedImageUrl.toLowerCase().endsWith('.pdf');
                                        final isManualFresh = _isManualReceipt(freshReceipt);

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
                                          final saveResult = ReceiptSaveResult.maybeFrom(result);
                                          if (saveResult?.saved == true) {
                                            setState(() {
                                              _hasChanges = true;
                                            });
                                            _fetchTaxReportsData(reset: true);
                                          }
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
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8E6FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              // Icon on the left - merchant/category avatar
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

                                              // Middle section - Merchant name and category with exported badge
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // Merchant name only
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
                                                    // Category with exported badge and reminder/split icons
                                                    Row(
                                                      children: [
                                                        Flexible(
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
                                                        if (isExported) ...[
                                                          const SizedBox(width: 8),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: Colors.green.shade100,
                                                              borderRadius: BorderRadius.circular(10),
                                                              border: Border.all(color: Colors.green.shade300),
                                                            ),
                                                            child: Text(
                                                              'Exported',
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.green.shade700,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                        if (hasReminder || hasSplit) ...[
                                                          const SizedBox(width: 8),
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
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Right section - Amount and date
                                              Expanded(
                                                flex: 2,
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

          // Calendar overlay
          if (_showCalendar)
            _buildCalendarOverlay(),
        ],
      ),
    );
  }


  Widget _buildFilterTab(String title) {
    final String filterValue = title == 'Not Exported' ? 'Not Exported' : title;
    final bool isSelected = _selectedFilter == filterValue;

    return Flexible(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = filterValue;
          });
          _fetchTaxReportsData(reset: true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(25), // Changed to make it oval
            border: Border.all(
              color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12, // Smaller font to fit better
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.1,
              vertical: MediaQuery.of(context).size.height * 0.1,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: 350,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Last year and This year buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Last year button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final now = DateTime.now();
                            final lastYearStart = DateTime(now.year - 1, 1, 1);
                            final lastYearEnd = DateTime(now.year - 1, 12, 31);
                            setState(() {
                              _selectedQuickFilter = 'Last Year';
                              _tempStartDate = lastYearStart;
                              _tempEndDate = lastYearEnd;
                              _startDateController.text = DateFormat('yyyy-MM-dd').format(lastYearStart);
                              _endDateController.text = DateFormat('yyyy-MM-dd').format(lastYearEnd);
                              _currentCalendarMonth = DateTime(now.year - 1, 1);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedQuickFilter == 'Last Year'
                                  ? const Color(0xFF7E5EFD)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedQuickFilter == 'Last Year'
                                    ? const Color(0xFF7E5EFD)
                                    : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Last Year',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _selectedQuickFilter == 'Last Year'
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 14,
                                fontWeight: _selectedQuickFilter == 'Last Year'
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // This year button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final now = DateTime.now();
                            final thisYearStart = DateTime(now.year, 1, 1);
                            final thisYearEnd = DateTime(now.year, 12, 31);
                            setState(() {
                              _selectedQuickFilter = 'This Year';
                              _tempStartDate = thisYearStart;
                              _tempEndDate = thisYearEnd;
                              _startDateController.text = DateFormat('yyyy-MM-dd').format(thisYearStart);
                              _endDateController.text = DateFormat('yyyy-MM-dd').format(thisYearEnd);
                              _currentCalendarMonth = DateTime(now.year, 1);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedQuickFilter == 'This Year'
                                  ? const Color(0xFF7E5EFD)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedQuickFilter == 'This Year'
                                    ? const Color(0xFF7E5EFD)
                                    : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'This Year',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _selectedQuickFilter == 'This Year'
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 14,
                                fontWeight: _selectedQuickFilter == 'This Year'
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Selected date display
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _tempStartDate != null && _tempEndDate != null
                              ? '${DateFormat('MMM d, yyyy').format(_tempStartDate!)} - ${DateFormat('MMM d, yyyy').format(_tempEndDate!)}'
                              : _tempStartDate != null
                              ? '${DateFormat('MMM d, yyyy').format(_tempStartDate!)} - Select end date'
                              : 'Select date range',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Month navigation
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Color(0xFF7E5EFD)),
                        iconSize: 24,
                        onPressed: () {
                          setState(() {
                            _currentCalendarMonth = DateTime(
                              _currentCalendarMonth.year,
                              _currentCalendarMonth.month - 1,
                            );
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          DateFormat('MMMM yyyy').format(_currentCalendarMonth),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF7E5EFD),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Color(0xFF7E5EFD)),
                        iconSize: 24,
                        onPressed: () {
                          setState(() {
                            _currentCalendarMonth = DateTime(
                              _currentCalendarMonth.year,
                              _currentCalendarMonth.month + 1,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Calendar grid with day headers
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Weekday headers
                      Row(
                        children: ['S', 'M', 'T', 'W', 'TH', 'F', 'S']
                            .map((day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),

                      // Calendar grid
                      _buildResponsiveCalendarGrid(),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _showCalendar = false;
                            });
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_tempStartDate != null && _tempEndDate != null) {
                              _selectDateRange(_tempStartDate!, _tempEndDate!);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E5EFD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
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
  }

  Widget _buildResponsiveCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month + 1, 0);

    // Correct weekday calculation for Sunday = 0 grid
    // DateTime.weekday returns 1-7 (Monday=1, Sunday=7)
    // We need 0-6 (Sunday=0, Saturday=6)
    final firstWeekday = firstDayOfMonth.weekday % 7; // This converts Sunday(7) to 0, Monday(1) to 1, etc.

    List<Widget> dayWidgets = [];

    // Add empty cells for days before the first day of the month
    for (int i = 0; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    // Add day cells
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month, day);
      dayWidgets.add(_buildResponsiveDayCell(day, date));
    }

    // Organize into rows of 7 days each
    List<Widget> rows = [];
    for (int i = 0; i < dayWidgets.length; i += 7) {
      final rowWidgets = <Widget>[];
      for (int j = 0; j < 7; j++) {
        if (i + j < dayWidgets.length) {
          rowWidgets.add(Expanded(child: dayWidgets[i + j]));
        } else {
          rowWidgets.add(const Expanded(child: SizedBox()));
        }
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(children: rowWidgets),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildResponsiveDayCell(int day, DateTime date) {
    final isToday = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isStartDate = _tempStartDate != null && DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(_tempStartDate!);
    final isEndDate = _tempEndDate != null && DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(_tempEndDate!);
    final isInRange = _tempStartDate != null && _tempEndDate != null &&
        date.isAfter(_tempStartDate!) && date.isBefore(_tempEndDate!);

    Color backgroundColor = Colors.transparent;
    Color textColor = Colors.black87;

    if (isStartDate || isEndDate) {
      backgroundColor = const Color(0xFF7E5EFD);
      textColor = Colors.white;
    } else if (isInRange) {
      backgroundColor = const Color(0xFFE8E6FF);
      textColor = const Color(0xFF7E5EFD);
    } else if (isToday) {
      backgroundColor = Colors.grey.shade300;
      textColor = Colors.black87;
    }

    return GestureDetector(
      onTap: () => _handleDayTap(date),
      child: Container(
        height: 36,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: isToday && !isStartDate && !isEndDate
              ? Border.all(color: const Color(0xFF7E5EFD), width: 1)
              : null,
        ),
        child: Center(
          child: Text(
            day.toString(),
            style: TextStyle(
              fontSize: 14,
              color: textColor,
              fontWeight: isStartDate || isEndDate ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}