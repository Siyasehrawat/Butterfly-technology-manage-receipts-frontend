import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/receipt_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';
import '../services/expense_group_service.dart';
import 'split_receipt_details_screen.dart'; // New screen for split details
import 'split_contacts_screen.dart'; // Import the new contacts screen
import 'group_details_screen.dart'; // Import the group details screen
import '../utils/category_icons.dart';
import '../models/pagination_model.dart';

// Updated enum for split type filter - added 'groups'
enum SplitType { splitByYou, splitWithYou, groups }

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
  SplitType _selectedSplitTypeFilter = SplitType.groups; // Default to Groups view

// Pagination variables
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalCount = 0;
  bool _hasNextPage = false;

// Debounce timer for search
  Timer? _searchDebounce;

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
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    super.dispose();
  }

  void _onSearchChanged() {
    // Cancel previous timer
    _searchDebounce?.cancel();
    
    setState(() {
      _searchQuery = _searchController.text;
    });
    
    // Create new timer for debounced search
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      // Reset pagination and fetch from backend when search changes
      _fetchReceipts(reset: true);
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

  // Helper function to get group title (merchant or group name)
  String _getGroupTitle(Map<String, dynamic> receipt) {
    return receipt['groupName'] ?? receipt['merchant'] ?? 'Group';
  }

  // Helper function to get participant initials
  String _getParticipantInitials(Map<String, dynamic> participant) {
    final name = participant['name']?.toString() ?? '';
    if (name.isEmpty) {
      final email = participant['email']?.toString() ?? '';
      if (email.isNotEmpty) {
        return email[0].toUpperCase();
      }
      return '?';
    }
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // Helper function to parse amount from formatted string (e.g., "₹500.00" -> 500.0)
  double _parseAmountFromString(String amountStr) {
    if (amountStr.isEmpty) return 0.0;
    // Remove currency symbols and other non-numeric characters except decimal point and minus sign
    final cleaned = amountStr.replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  // Helper function to get user's share amount
  Map<String, dynamic> _getUserShare(Map<String, dynamic> receipt) {
    // Handle expense groups with balance information
    if (receipt['isGroup'] == true) {
      final userBalance = receipt['userBalance'] as double?;
      if (userBalance != null) {
        if (userBalance > 0) {
          // Positive balance means others owe you
          return {'amount': userBalance.abs(), 'type': 'owed'};
        } else if (userBalance < 0) {
          // Negative balance means you owe others
          return {'amount': userBalance.abs(), 'type': 'owe'};
        } else {
          return {'amount': 0.0, 'type': 'none'};
        }
      }
      
      // Fallback: try to get balance from balances array
      final balances = receipt['balances'] as List?;
      if (balances != null) {
        for (var balance in balances) {
          if (balance is Map<String, dynamic>) {
            final userId = balance['userId']?.toString();
            if (userId == widget.userId) {
              final balanceStr = balance['balance']?.toString() ?? '0';
              final cleaned = balanceStr.replaceAll(RegExp(r'[^\d.-]'), '');
              final balanceAmount = double.tryParse(cleaned) ?? 0.0;
              
              if (balanceAmount > 0) {
                return {'amount': balanceAmount.abs(), 'type': 'owed'};
              } else if (balanceAmount < 0) {
                return {'amount': balanceAmount.abs(), 'type': 'owe'};
              } else {
                return {'amount': 0.0, 'type': 'none'};
              }
            }
          }
        }
      }
      
      return {'amount': 0.0, 'type': 'none'};
    }
    
    // Handle regular split bills
    final participants = receipt['participants'] as List?;
    if (participants == null) {
      return {'amount': 0.0, 'type': 'none'};
    }

    final totalAmount = double.tryParse(receipt['totalAmount']?.toString() ?? '0') ?? 0.0;
    
    // Find user's participant entry
    for (var p in participants) {
      if (p is Map<String, dynamic>) {
        final userId = p['userId']?.toString() ?? p['id']?.toString() ?? '';
        if (userId == widget.userId) {
          final amount = double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0;
          final createdBy = receipt['createdBy']?.toString() ?? '';
          
          // If user created the split, they are owed; otherwise they owe
          if (createdBy == widget.userId) {
            return {'amount': amount, 'type': 'owed'};
          } else {
            return {'amount': amount, 'type': 'owe'};
          }
        }
      }
    }
    
    // Fallback: calculate equal share
    final share = participants.isNotEmpty ? totalAmount / participants.length : 0.0;
    final createdBy = receipt['createdBy']?.toString() ?? '';
    if (createdBy == widget.userId) {
      return {'amount': share, 'type': 'owed'};
    } else {
      return {'amount': share, 'type': 'owe'};
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

  Future<void> _fetchSavedReceipts() async {
    try {
      final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final filters = receiptProvider.filters; // Get current filters from provider

      final Map<String, String> queryParams = {
        'page': _currentPage.toString(),
        'pageSize': _pageSize.toString(),
      };

      // Add search query as merchant parameter for backend search
      // Note: Backend uses 'merchant' parameter for search
      if (_searchController.text.trim().isNotEmpty) {
        queryParams['merchant'] = _searchController.text.trim();
      }

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
      } else if (_selectedSplitTypeFilter == SplitType.splitWithYou) {
        endpoint = '/split-bill/with-you/${widget.userId}?$queryString';
      } else { // SplitType.groups
        // For groups, we'll fetch both and filter client-side for now
        // If there's a specific groups endpoint, update this
        endpoint = '/split-bill/by-you/${widget.userId}?$queryString';
      }

      debugPrint('Fetching split receipts from: $endpoint');

      List<Map<String, dynamic>> receipts = [];
      Map<String, dynamic> pagination = {};

      if (_selectedSplitTypeFilter == SplitType.groups) {
        // For groups, use the expense groups user-groups endpoint with pagination
        // GET /api/expense-groups/user-groups?userId={userId}&page={page}&limit={limit}&search={search}
        try {
          final result = await ExpenseGroupService.getUserGroups(
            userId: widget.userId,
            search: _searchQuery.isNotEmpty ? _searchQuery : null,
            page: _currentPage,
            limit: _pageSize,
            token: userProvider.token,
          );

          if (result['success'] == true) {
            final groups = List<Map<String, dynamic>>.from(result['data'] ?? []);
            
            // Handle pagination if available
            if (result['pagination'] != null) {
              final paginationData = result['pagination'] as PaginationMeta;
              setState(() {
                _totalCount = paginationData.total;
                _hasNextPage = paginationData.hasMore;
              });
            }
            
            // Transform groups to match the expected receipt format for display
            receipts = groups.map((group) {
              final members = group['members'] as List<dynamic>? ?? [];
              final memberCount = group['memberCount'] ?? members.length;
              
              // Parse total spending - use totalSpendingRaw if available, otherwise parse totalSpending
              final totalSpendingRaw = group['totalSpendingRaw'];
              final totalAmount = totalSpendingRaw is num 
                  ? totalSpendingRaw.toDouble()
                  : (totalSpendingRaw != null 
                      ? double.tryParse(totalSpendingRaw.toString()) ?? 0.0
                      : _parseAmountFromString(group['totalSpending']?.toString() ?? '0'));
              
              // Parse user balance - use userBalanceRaw if available, otherwise parse userBalance
              final userBalanceRaw = group['userBalanceRaw'];
              final userBalance = userBalanceRaw is num
                  ? userBalanceRaw.toDouble()
                  : (userBalanceRaw != null
                      ? double.tryParse(userBalanceRaw.toString()) ?? 0.0
                      : _parseAmountFromString(group['userBalance']?.toString() ?? '0'));
              
              return {
                'id': group['id'],
                'groupName': group['name'],
                'description': group['description'],
                'participants': members.map((member) {
                  final memberMap = member as Map<String, dynamic>;
                  return {
                    'userId': memberMap['userId'],
                    'email': memberMap['email'],
                    'name': memberMap['name'],
                    'memberId': memberMap['id'],
                  };
                }).toList(),
                'createdBy': group['createdBy'],
                'totalAmount': totalAmount,
                'userBalance': userBalance,
                'memberCount': memberCount,
                'isGroup': true, // Flag to identify this as a group
                'createdAt': group['createdAt'], // Include creation date
                'updatedAt': group['updatedAt'], // Include update date
              };
            }).toList();
            
            // Set pagination (API doesn't return pagination yet, so we'll set defaults)
            pagination = {
              'totalCount': receipts.length,
              'hasNextPage': false,
            };
          } else {
            debugPrint("Error fetching groups: ${result['error']}");
          }
        } catch (e) {
          debugPrint("Error fetching groups: $e");
        }
      } else {
        final response = await ApiService.get(endpoint, token: userProvider.token);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          // The new endpoints return a list of split bills, not receipts directly.
          // Each split bill object contains the receipt details directly.
          if (data is Map && data.containsKey('splitBills')) {
            final List<dynamic> splitBillsJson = data['splitBills'] ?? [];
            // Directly use the splitBill object as it contains receipt details
            receipts = List<Map<String, dynamic>>.from(splitBillsJson);
            pagination = data['pagination'] ?? {};
          } else {
            // Fallback for unexpected response structure, though it should be handled by the above.
            receipts = List<Map<String, dynamic>>.from(data is List ? data : []);
          }
        } else {
          debugPrint('Failed to load split receipts: ${response.statusCode} - ${response.body}');
        }
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
        _totalCount = pagination['totalCount'] ?? receipts.length;
        _hasNextPage = pagination['hasNextPage'] ?? false;
        if (_currentPage == 1) {
          savedReceipts = receipts;
        } else {
          savedReceipts.addAll(receipts);
        }
      });
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
    // Backend returns already-filtered results (search is handled by backend).
    // The split type filter is also handled by the backend endpoint.
    List<Map<String, dynamic>> currentReceipts = List.from(savedReceipts);

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

          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Search Bar with Contacts Icon
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by merchant name...',
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
                        const SizedBox(width: 8),
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
                  ),

                  // Split Type Filter - Three options now
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Groups'),
                              selected: _selectedSplitTypeFilter == SplitType.groups,
                              showCheckmark: false,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedSplitTypeFilter = SplitType.groups;
                                    _fetchReceipts(reset: true);
                                  });
                                }
                              },
                              selectedColor: _selectedSplitTypeFilter == SplitType.groups
                                  ? const Color(0xFF7E5EFD)
                                  : const Color(0xFFE8E6FF),
                              labelStyle: TextStyle(
                                color: _selectedSplitTypeFilter == SplitType.groups
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: _selectedSplitTypeFilter == SplitType.groups
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: _selectedSplitTypeFilter == SplitType.groups
                                      ? const Color(0xFF7E5EFD)
                                      : Colors.grey.shade300,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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
                              selectedColor: _selectedSplitTypeFilter == SplitType.splitByYou
                                  ? const Color(0xFF7E5EFD)
                                  : const Color(0xFFE8E6FF),
                              labelStyle: TextStyle(
                                color: _selectedSplitTypeFilter == SplitType.splitByYou
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: _selectedSplitTypeFilter == SplitType.splitByYou
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: _selectedSplitTypeFilter == SplitType.splitByYou
                                      ? const Color(0xFF7E5EFD)
                                      : Colors.grey.shade300,
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
                              selectedColor: _selectedSplitTypeFilter == SplitType.splitWithYou
                                  ? const Color(0xFF7E5EFD)
                                  : const Color(0xFFE8E6FF),
                              labelStyle: TextStyle(
                                color: _selectedSplitTypeFilter == SplitType.splitWithYou
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: _selectedSplitTypeFilter == SplitType.splitWithYou
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: _selectedSplitTypeFilter == SplitType.splitWithYou
                                      ? const Color(0xFF7E5EFD)
                                      : Colors.grey.shade300,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_selectedSplitTypeFilter == SplitType.groups)
                              TextButton.icon(
                                onPressed: () {
                                  _showCreateGroupDialog();
                                },
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: Color(0xFF7E5EFD),
                                  size: 18,
                                ),
                                label: const Text(
                                  'Create Group',
                                  style: TextStyle(
                                    color: Color(0xFF7E5EFD),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                              ),
                            Row(
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
                      ],
                    ),
                  ),

                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
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
                                    
                                    // Show group card if Groups filter is selected
                                    if (_selectedSplitTypeFilter == SplitType.groups) {
                                      return _buildGroupCard(receipt, currencySymbol);
                                    }
                                    
                                    // Otherwise show regular receipt card
                                    final imageUrl = _getReceiptImageUrl(receipt);
                                    final merchant = receipt['merchant'] ?? 'Unknown';
                                    final rawAmount = receipt['totalAmount']?.toString() ?? '0';
                                    final category = receipt['category']?.toString() ?? 'Uncategorized';
                                    final isPdf = _isPdfReceipt(receipt);
                                    final isManual = _isManualReceipt(receipt);
                                    final receiptId = receipt['id']?.toString() ?? '';

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
                                            if (result == true) {
                                              _fetchReceipts(reset: true);
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

  Future<Map<String, dynamic>?> _showAddContactDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E5EFD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_add,
                  color: Color(0xFF7E5EFD),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Add New Contact',
                style: TextStyle(
                  color: Color(0xFF7E5EFD),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name *',
                      hintText: 'Enter contact name',
                      prefixIcon: const Icon(Icons.person, color: Color(0xFF7E5EFD)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      hintText: 'Enter email address',
                      prefixIcon: const Icon(Icons.email, color: Color(0xFF7E5EFD)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an email';
                      }
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone (Optional)',
                      hintText: 'Enter phone number',
                      prefixIcon: const Icon(Icons.phone, color: Color(0xFF7E5EFD)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        // Basic phone validation if provided
                        final phoneRegex = RegExp(r'^[\+]?[0-9\s\-\(\)]{7,}$');
                        if (!phoneRegex.hasMatch(value.trim())) {
                          return 'Please enter a valid phone number';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final result = await _addContact(
                    nameController.text.trim(),
                    emailController.text.trim(),
                    phoneController.text.trim(),
                  );
                  if (result != null && context.mounted) {
                    Navigator.pop(dialogContext, result);
                  } else if (context.mounted) {
                    Navigator.pop(dialogContext);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Add Contact',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _addContact(String name, String email, String phone) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
              ),
              const SizedBox(height: 16),
              Text(
                'Adding contact...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final Map<String, dynamic> requestBody = {
        'name': name,
        'email': email,
        'phone': phone.isNotEmpty ? phone : null,
        'userId': widget.userId,
      };

      final response = await ApiService.post(
        '/split-bill/contacts',
        body: requestBody,
        token: userProvider.token,
      );

      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        // Handle the response structure: { success: true, message: "...", data: {...} }
        final contactData = data['data'] ?? data;
        
        // Return the created contact data in the format expected by the UI
        return {
          'id': contactData['id']?.toString() ?? '',
          'name': contactData['name']?.toString() ?? name,
          'email': contactData['email']?.toString() ?? email,
          'phone': contactData['phone']?.toString(),
          'userId': contactData['userId']?.toString() ?? widget.userId,
          'isSavedContact': contactData['isSavedContact'] ?? true,
        };
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? errorBody['error'] ?? 'Failed to add contact';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      debugPrint('Error adding contact: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error. Please check your internet connection.'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _createGroup(
    String groupName,
    String description,
    List<Map<String, dynamic>> members,
  ) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Show loading indicator
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Creating group...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      // Prepare members list for API (email normalization handled by service)
      final membersList = members.map((member) {
        return {
          'email': member['email']?.toString() ?? '',
          if (member['name'] != null) 'name': member['name'],
        };
      }).toList();

      // Create group using the new API
      final result = await ExpenseGroupService.createGroup(
        name: groupName,
        createdBy: widget.userId,
        description: description.isNotEmpty ? description : null,
        members: membersList,
        token: userProvider.token,
      );

      if (!context.mounted) return;

      if (result['success'] == true) {
        final groupData = result['data'] as Map<String, dynamic>;
        final groupId = groupData['id']?.toString() ?? '';

        // Navigate to group details screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupDetailsScreen(
              groupId: groupId,
              groupName: groupName,
              userId: widget.userId,
              token: widget.token,
            ),
          ),
        ).then((_) {
          // Refresh the groups list when returning
          if (context.mounted) {
            _fetchReceipts(reset: true);
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Failed to create group'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating group: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>?> _showSelectContactsDialog() async {
    // Fetch contacts first
    List<Map<String, dynamic>> contacts = [];
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final result = await ExpenseGroupService.getContacts(
        userId: widget.userId,
        token: userProvider.token,
      );

      if (result['success'] == true) {
        final allContacts = List<Map<String, dynamic>>.from(result['data'] ?? []);
        
        // Filter contacts with valid email addresses
        final filteredContacts = allContacts.where((contact) {
          final hasValidEmail = contact['email'] != null && 
                               contact['email'].toString().trim().isNotEmpty &&
                               contact['email'].toString().trim() != 'null';
          return hasValidEmail;
        }).toList();
        
        // Sort contacts: saved contacts first, then unsaved
        filteredContacts.sort((a, b) {
          final aIsSaved = a['isSavedContact'] == true;
          final bIsSaved = b['isSavedContact'] == true;
          
          if (aIsSaved && !bIsSaved) return -1;
          if (!aIsSaved && bIsSaved) return 1;
          
          final aName = aIsSaved ? (a['name']?.toString() ?? '') : a['email']?.toString() ?? '';
          final bName = bIsSaved ? (b['name']?.toString() ?? '') : b['email']?.toString() ?? '';
          return aName.toLowerCase().compareTo(bName.toLowerCase());
        });

        contacts = filteredContacts;
      }
    } catch (e) {
      debugPrint("Error fetching contacts: $e");
    }

    return showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (BuildContext dialogContext) {
        // Use a StatefulWidget approach to persist state
        return _SelectContactsDialogContent(
          contacts: contacts,
          onSelected: (selectedContacts) {
            Navigator.of(dialogContext).pop(selectedContacts);
          },
          onCancel: () {
            Navigator.of(dialogContext).pop(null);
          },
        );
      },
    );
  }

  void _showCreateGroupDialog() {
    final TextEditingController groupNameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String? groupNameError;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // Store selectedMembers outside builder to persist across rebuilds
        final List<Map<String, dynamic>> selectedMembers = [];
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Keep selectedMembers reference accessible

            String _getMemberInitials(Map<String, dynamic> member) {
              final name = member['name']?.toString() ?? '';
              if (name.isEmpty) {
                final email = member['email']?.toString() ?? '';
                if (email.isNotEmpty) {
                  return email[0].toUpperCase();
                }
                return '?';
              }
              final parts = name.trim().split(' ');
              if (parts.length >= 2) {
                return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
              }
              return name[0].toUpperCase();
            }

            void _addMember(Map<String, dynamic> member) {
              // Check if member already exists
              final memberId = member['id']?.toString() ?? member['_id']?.toString() ?? '';
              final memberEmail = member['email']?.toString() ?? '';
              
              final exists = selectedMembers.any((m) {
                final id = m['id']?.toString() ?? m['_id']?.toString() ?? '';
                final email = m['email']?.toString() ?? '';
                return (memberId.isNotEmpty && id == memberId) || 
                       (memberEmail.isNotEmpty && email.toLowerCase() == memberEmail.toLowerCase());
              });
              
              if (!exists) {
                setDialogState(() {
                  selectedMembers.add(member);
                  debugPrint('Added member: ${member['name']} (${member['email']}), total: ${selectedMembers.length}');
                });
              } else {
                debugPrint('Member already exists: ${member['email']}');
              }
            }

            void _removeMember(int index) {
              if (index >= 0 && index < selectedMembers.length) {
                setDialogState(() {
                  selectedMembers.removeAt(index);
                  debugPrint('Removed member at index $index, total: ${selectedMembers.length}');
                });
              }
            }

            bool isValid() {
              groupNameError = null;
              if (groupNameController.text.trim().isEmpty) {
                groupNameError = 'Group name is required';
                return false;
              }
              return true;
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Purple Header
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF7E5EFD),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Create Group',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            // Group Name Field
                            const Text(
                              'Group Name *',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: groupNameController,
                              decoration: InputDecoration(
                                hintText: 'e.g.Holiday',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: groupNameError != null
                                        ? Colors.red
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: groupNameError != null
                                        ? Colors.red
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF7E5EFD),
                                    width: 2,
                                  ),
                                ),
                                errorText: groupNameError,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (value) {
                                if (groupNameError != null) {
                                  setDialogState(() {
                                    groupNameError = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 20),
                            // Description Field
                            const Text(
                              'Description (Optional)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: descriptionController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: "What's this group for?",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF7E5EFD),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Add Members Section
                            const Text(
                              'Add Members',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      // Use dialogContext to ensure we're in the right context
                                      final newContact = await _showAddContactDialog();
                                      if (newContact != null && context.mounted) {
                                        _addMember(newContact);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                                            const SnackBar(
                                              content: Text('Contact added successfully'),
                                              backgroundColor: Color(0xFF7E5EFD),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                    'Add Contacts',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      // Use dialogContext to ensure we're in the right context
                                      final selectedContacts = await _showSelectContactsDialog();
                                      if (selectedContacts != null && selectedContacts.isNotEmpty && context.mounted) {
                                        for (var contact in selectedContacts) {
                                          _addMember(contact);
                                        }
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                                            SnackBar(
                                              content: Text('${selectedContacts.length} contact(s) added'),
                                              backgroundColor: const Color(0xFF7E5EFD),
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'From Contacts',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Selected Members List
                            if (selectedMembers.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ...selectedMembers.asMap().entries.map((entry) {
                                final index = entry.key;
                                final member = entry.value;
                                final name = member['name']?.toString() ?? 'Unknown';
                                final email = member['email']?.toString() ?? '';
                                final initials = _getMemberInitials(member);
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Avatar
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF7E5EFD),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            initials,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Name and Email
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            if (email.isNotEmpty)
                                              Text(
                                                email,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // Remove button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.grey,
                                          size: 20,
                                        ),
                                        onPressed: () => _removeMember(index),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            const SizedBox(height: 24),
                            // Footer Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: const BorderSide(
                                        color: Color(0xFF7E5EFD),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Color(0xFF7E5EFD),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      if (isValid()) {
                                        Navigator.of(dialogContext).pop();
                                        await _createGroup(
                                          groupNameController.text.trim(),
                                          descriptionController.text.trim(),
                                          selectedMembers,
                                        );
                                      } else {
                                        setDialogState(() {});
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7E5EFD),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Create Group',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> receipt, String currencySymbol) {
    final groupTitle = _getGroupTitle(receipt);
    final participants = receipt['participants'] as List? ?? [];
    final memberCount = receipt['memberCount'] as int? ?? participants.length;
    final totalAmount = receipt['totalAmount'] as double? ?? 
                       double.tryParse(receipt['totalAmount']?.toString() ?? '0') ?? 0.0;
    final formattedTotal = totalAmount.toStringAsFixed(2);
    final userShare = _getUserShare(receipt);
    final userShareAmount = (userShare['amount'] as double?) ?? 0.0;
    final formattedUserShare = userShareAmount.toStringAsFixed(2);
    // If share is 0, all expenses are settled, so use green (paid) border color
    final borderColor = userShareAmount == 0.0 ? Colors.green : _getBorderColor(receipt);
    final isGroup = receipt['isGroup'] == true;
    final groupId = receipt['id']?.toString() ?? '';
    final description = receipt['description']?.toString();
    
    // Format creation date
    String formattedCreatedDate = '';
    if (receipt['createdAt'] != null) {
      try {
        final DateTime? date = _parseDate(receipt['createdAt']);
        if (date != null) {
          formattedCreatedDate = DateFormat('MMM d, yyyy').format(date);
        }
      } catch (e) {
        debugPrint('Error parsing creation date: $e');
      }
    }
    
    // Get first 3 participants for avatars, then show "+X" for remaining
    final visibleParticipants = participants.take(3).toList();
    final remainingCount = memberCount > 3 ? memberCount - 3 : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () {
          if (isGroup && groupId.isNotEmpty) {
            // Navigate to GroupDetailsScreen for expense groups
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailsScreen(
                  groupId: groupId,
                  groupName: groupTitle,
                  userId: widget.userId,
                  token: widget.token,
                ),
              ),
            ).then((result) {
              if (result == true) {
                _fetchReceipts(reset: true);
              }
            });
          } else {
            // Navigate to SplitReceiptDetailsScreen for split bills
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
              if (result == true) {
                _fetchReceipts(reset: true);
              }
            });
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Creation Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        groupTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (formattedCreatedDate.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        formattedCreatedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                // Description if available
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),
                // Total and user share row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: $currencySymbol$formattedTotal',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      userShare['type'] == 'owe'
                          ? 'You owe: $currencySymbol$formattedUserShare'
                          : userShare['type'] == 'owed'
                              ? 'You are owed: $currencySymbol$formattedUserShare'
                              : 'Share: $currencySymbol$formattedUserShare',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: userShare['type'] == 'owe'
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
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
  }
}

// Separate StatefulWidget for dialog content to properly manage state
class _SelectContactsDialogContent extends StatefulWidget {
  final List<Map<String, dynamic>> contacts;
  final Function(List<Map<String, dynamic>>) onSelected;
  final VoidCallback onCancel;

  const _SelectContactsDialogContent({
    Key? key,
    required this.contacts,
    required this.onSelected,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<_SelectContactsDialogContent> createState() => _SelectContactsDialogContentState();
}

class _SelectContactsDialogContentState extends State<_SelectContactsDialogContent> {
  final Set<String> selectedContactIds = <String>{};

  String _getContactInitials(Map<String, dynamic> contact) {
    final name = contact['name']?.toString() ?? '';
    if (name.isEmpty) {
      final email = contact['email']?.toString() ?? '';
      if (email.isNotEmpty) {
        return email[0].toUpperCase();
      }
      return '?';
    }
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  void _toggleContact(String contactId) {
    setState(() {
      if (selectedContactIds.contains(contactId)) {
        selectedContactIds.remove(contactId);
      } else {
        selectedContactIds.add(contactId);
      }
    });
  }

  List<Map<String, dynamic>> _getSelectedContacts() {
    return widget.contacts.where((contact) {
      final contactId = contact['id']?.toString() ?? 
                        contact['_id']?.toString() ?? 
                        contact['contactId']?.toString() ??
                        contact['email']?.toString() ?? 
                        '';
      return contactId.isNotEmpty && selectedContactIds.contains(contactId);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Purple Header
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF7E5EFD),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Contacts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: widget.onCancel,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Contact List
            Expanded(
              child: widget.contacts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.contacts_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No contacts found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: widget.contacts.length,
                      itemBuilder: (context, index) {
                        final contact = widget.contacts[index];
                        // Try multiple possible ID fields
                        final contactId = contact['id']?.toString() ?? 
                                          contact['_id']?.toString() ?? 
                                          contact['contactId']?.toString() ??
                                          contact['email']?.toString() ?? 
                                          '';
                        final name = contact['name']?.toString() ?? 'Unknown';
                        final email = contact['email']?.toString() ?? '';
                        final initials = _getContactInitials(contact);
                        final isSelected = contactId.isNotEmpty && selectedContactIds.contains(contactId);

                        return InkWell(
                          onTap: () {
                            if (contactId.isNotEmpty) {
                              _toggleContact(contactId);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF7E5EFD),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Name and Email
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        email,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Checkbox
                                Checkbox(
                                  value: isSelected,
                                  onChanged: contactId.isNotEmpty
                                      ? (value) {
                                          _toggleContact(contactId);
                                        }
                                      : null,
                                  activeColor: const Color(0xFF7E5EFD),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Footer Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: Color(0xFF7E5EFD),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF7E5EFD),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selectedContactIds.isEmpty
                          ? null
                          : () {
                              widget.onSelected(_getSelectedContacts());
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: Text(
                        'Add Selected${selectedContactIds.isEmpty ? '' : ' (${selectedContactIds.length})'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
}

// Extension to capitalize first letter of each word
extension StringExtension on String {
  String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  String toTitleCase() => replaceAll(RegExp(' +'), ' ').split(' ').map((str) => StringExtension(str).toCapitalized()).join(' ');
}
