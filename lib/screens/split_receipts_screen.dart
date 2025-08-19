import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/receipt_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';
import 'split_receipt_details_screen.dart'; // New screen for split details
import 'split_contacts_screen.dart'; // Import the new contacts screen
import '../utils/category_icons.dart';

// Updated enum for split type filter - removed 'all'
enum SplitType { splitByYou, splitWithYou }

class SplitReceiptsScreen extends StatefulWidget {
  final String userId;
  final String token;

  const SplitReceiptsScreen({
    Key? key,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<SplitReceiptsScreen> createState() => _SplitReceiptsScreenState();
}

class _SplitReceiptsScreenState extends State<SplitReceiptsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredReceipts = [];
  List<Map<String, dynamic>> savedReceipts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  SplitType _selectedSplitTypeFilter = SplitType.splitByYou; // Updated default filter

// Pagination variables
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalCount = 0;
  bool _hasNextPage = false;

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

    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReceipts(reset: true);
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
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterReceipts();
    });
  }

  bool _isPdfReceipt(Map<String, dynamic> receipt) {
    // The split bill response does not contain imageLink/imageUrl directly.
    // This logic will not work as expected without image URLs in the split bill object.
    // You might need to fetch full receipt details or update backend.
    final link = (receipt['decryptedImageLink'] ?? receipt['decryptedImageUrl'] ?? receipt['imageLink'] ?? receipt['imageUrl'] ?? '').toString().toLowerCase();
    return link.endsWith('.pdf');
  }

  bool _isManualReceipt(Map<String, dynamic> receipt) {
    // The split bill response does not contain imageLink/imageUrl directly.
    // This logic will not work as expected without image URLs in the split bill object.
    final imageUrl = receipt['decryptedImageLink'] ?? receipt['decryptedImageUrl'] ?? receipt['imageLink'] ?? receipt['imageUrl'] ?? '';
    return receipt['isManual'] == true ||
        imageUrl.contains('placeholder') ||
        imageUrl.contains('Manual+Receipt') ||
        imageUrl.isEmpty ||
        imageUrl == 'null';
  }

  String _getReceiptImageUrl(Map<String, dynamic> receipt) {
    // The split bill response does not contain imageLink/imageUrl directly.
    // This function will return an empty string unless the backend is updated.
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

  // Helper function to determine the split status more robustly
  String _getSplitStatus(Map<String, dynamic> splitBill) {
    // Prioritize an overall status field if available
    final status = splitBill['status']?.toString().toLowerCase();
    if (status == 'completed' || status == 'paid') {
      return 'paid';
    }

    // Fallback to paymentSummary for aggregated status
    final paymentSummary = splitBill['paymentSummary'];
    if (paymentSummary != null) {
      final totalParticipants = paymentSummary['totalParticipants'] ?? 0;
      final paidParticipants = paymentSummary['paidParticipants'] ?? 0;

      if (totalParticipants > 0) {
        if (paidParticipants == totalParticipants) {
          return 'paid';
        } else if (paidParticipants > 0) {
          return 'partially_paid';
        }
      }
    }

    // Check participants' individual statuses for 'split with you' or general cases
    final participants = splitBill['participants'];
    if (participants is List && participants.isNotEmpty) {
      int paidCount = 0;
      int totalExpectedParticipants = participants.length;

      for (var p in participants) {
        if (p is Map<String, dynamic> && p['status']?.toString().toLowerCase() == 'paid') {
          paidCount++;
        }
      }

      if (totalExpectedParticipants > 0) {
        if (paidCount == totalExpectedParticipants) {
          return 'paid';
        } else if (paidCount > 0) {
          return 'partially_paid';
        }
      }
    }

    // Default to unpaid if no clear status found
    return 'unpaid';
  }

  // New helper function to get the effective payment status for display
  String _getEffectivePaymentStatus(Map<String, dynamic> receipt) {
    if (_selectedSplitTypeFilter == SplitType.splitWithYou) {
      final myPaymentStatus = receipt['myPaymentStatus']?.toString().toLowerCase();
      if (myPaymentStatus == 'paid') {
        return 'paid';
      } else if (myPaymentStatus == 'unpaid') {
        return 'unpaid';
      } else if (myPaymentStatus == 'partially paid') {
        return 'partially_paid';
      }
    }
    // For Split By You, or if myPaymentStatus is not clear/relevant, use the general split status
    return _getSplitStatus(receipt);
  }

  Color _getBorderColor(Map<String, dynamic> receipt) {
    final status = _getEffectivePaymentStatus(receipt); // Use the new effective status
    if (status == 'paid') {
      return Colors.green; // All paid
    } else if (status == 'partially_paid') {
      return Colors.orange; // Partially paid
    }
    return Colors.orange; // Unpaid or unknown status
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

  Future<void> _fetchSavedReceipts() async {
    try {
      final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final filters = receiptProvider.filters; // Get current filters from provider

      final Map<String, String> queryParams = {
        'page': _currentPage.toString(),
        'pageSize': _pageSize.toString(),
      };

      // Apply tags filter from ReceiptProvider
      if (filters['tags'] != null && filters['tags'] is List && (filters['tags'] as List).isNotEmpty) {
        queryParams['tags'] = (filters['tags'] as List<String>).join(',');
      }

      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      String endpoint;
      if (_selectedSplitTypeFilter == SplitType.splitByYou) {
        endpoint = '/split-bill/by-you/${widget.userId}?$queryString';
      } else { // SplitType.splitWithYou
        endpoint = '/split-bill/with-you/${widget.userId}?$queryString';
      }

      debugPrint('Fetching split receipts from: $endpoint');

      final response = await ApiService.get(endpoint, token: userProvider.token);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        List<Map<String, dynamic>> receipts = [];
        Map<String, dynamic> pagination = {};

        // The new endpoints return a list of split bills, not receipts directly.
        // Each split bill object contains the receipt details directly.
        if (data is Map && data.containsKey('splitBills')) {
          final List<dynamic> splitBillsJson = data['splitBills'] ?? [];
          // Directly use the splitBill object as it contains receipt details
          receipts = List<Map<String, dynamic>>.from(splitBillsJson);
          pagination = data['pagination'] ?? {};

          setState(() {
            _totalCount = pagination['totalCount'] ?? 0;
            _hasNextPage = pagination['hasNextPage'] ?? false;
          });
        } else {
          // Fallback for unexpected response structure, though it should be handled by the above.
          receipts = List<Map<String, dynamic>>.from(data is List ? data : []);
        }

        // Removed the `isSaved` filter as split bill objects from these endpoints
        // do not contain an `isSaved` field and are inherently "saved" for this view.
        // receipts = receipts.where((receipt) => receipt['isSaved'] != false).toList();

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
        debugPrint('Failed to load split receipts: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint("Error fetching split receipts: $e");
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
    List<Map<String, dynamic>> currentReceipts = List.from(savedReceipts);

    // Apply search query filter
    if (_searchQuery.isNotEmpty) {
      currentReceipts = currentReceipts.where((receipt) {
        final merchant = (receipt['merchant'] ?? '').toString().toLowerCase();
        final category = (receipt['category'] ?? '').toString().toLowerCase();
        final amount = (receipt['totalAmount']?.toString() ?? '0').toLowerCase(); // Use totalAmount for split bills
        final query = _searchQuery.toLowerCase();
        return merchant.contains(query) ||
            category.contains(query) ||
            amount.contains(query);
      }).toList();
    }

    // The split type filter is now handled by the backend endpoint,
    // so no need to filter here based on `receiptSplitType`.
    // The `_filteredReceipts` will already contain only the relevant split type.

    _filteredReceipts = currentReceipts;

    _filteredReceipts.sort((a, b) {
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
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currencySymbol = userProvider.effectiveCurrencySymbol;

    return Scaffold(
      body: Column(
        children: [
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
                      'Split Receipts',
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

          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search receipts...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF7E5EFD)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                      ),
                    ),
                  ),

                  // Split Type Filter - Only two options now
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('Split By You'),
                                  selected: _selectedSplitTypeFilter == SplitType.splitByYou,
                                  showCheckmark: false,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedSplitTypeFilter = SplitType.splitByYou;
                                        _fetchReceipts(reset: true);
                                      });
                                    }
                                  },
                                  selectedColor: const Color(0xFFE8E6FF),
                                  labelStyle: TextStyle(
                                    color: _selectedSplitTypeFilter == SplitType.splitByYou ? const Color(0xFF7E5EFD) : Colors.grey,
                                    fontWeight: _selectedSplitTypeFilter == SplitType.splitByYou ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: _selectedSplitTypeFilter == SplitType.splitByYou ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Split With You'),
                                  selected: _selectedSplitTypeFilter == SplitType.splitWithYou,
                                  showCheckmark: false,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedSplitTypeFilter = SplitType.splitWithYou;
                                        _fetchReceipts(reset: true);
                                      });
                                    }
                                  },
                                  selectedColor: const Color(0xFFE8E6FF),
                                  labelStyle: TextStyle(
                                    color: _selectedSplitTypeFilter == SplitType.splitWithYou ? const Color(0xFF7E5EFD) : Colors.grey,
                                    fontWeight: _selectedSplitTypeFilter == SplitType.splitWithYou ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: _selectedSplitTypeFilter == SplitType.splitWithYou ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Contacts Icon Button
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF7E5EFD),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7E5EFD).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SplitContactsScreen(
                                        userId: widget.userId,
                                        token: widget.token,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.contacts,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                tooltip: 'Manage Contacts',
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              '🟢 : Paid',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '🟠 : Not Paid',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

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
                            'No split receipts found',
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
                          // imageUrl, isPdf, isManual will not work correctly without image URLs in the split bill response
                          final imageUrl = _getReceiptImageUrl(receipt);
                          final merchant = receipt['merchant'] ?? 'Unknown';
                          final rawAmount = receipt['totalAmount']?.toString() ?? '0'; // Use totalAmount from splitBill
                          final category = receipt['category']?.toString() ?? 'Uncategorized';
                          final isPdf = _isPdfReceipt(receipt);
                          final isManual = _isManualReceipt(receipt);
                          final receiptId = receipt['id']?.toString() ?? '';

                          // Clean the amount string to ensure it's just a number before formatting
                          final cleanAmount = rawAmount.replaceAll(RegExp(r'[^\d.]'), '');
                          final formattedAmount = double.tryParse(cleanAmount)?.toStringAsFixed(2) ?? '0.00';


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
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SplitReceiptDetailsScreen(
                                      receipt: receipt,
                                      userId: widget.userId,
                                      token: widget.token,
                                    ),
                                  ),
                                ).then((result) {
                                  if (result == true) { // Check if result is true (status changed)
                                    _fetchReceipts(reset: true); // Reload receipts
                                  }
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8E6FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getBorderColor(receipt),
                                    width: 2,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
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

                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
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
                                            Text(
                                              category,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF7E5EFD),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),

                                      Expanded(
                                        flex: 1,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '$currencySymbol$formattedAmount',
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

// Extension to capitalize first letter of each word
extension StringExtension on String {
  String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  String toTitleCase() => replaceAll(RegExp(' +'), ' ').split(' ').map((str) => StringExtension(str).toCapitalized()).join(' ');
}
