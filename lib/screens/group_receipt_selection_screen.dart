import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';
import '../services/expense_group_service.dart';
import '../utils/category_icons.dart';
import 'group_split_options_screen.dart';

class GroupReceiptSelectionScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String userId;
  final String token;

  const GroupReceiptSelectionScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<GroupReceiptSelectionScreen> createState() => _GroupReceiptSelectionScreenState();
}

class _GroupReceiptSelectionScreenState extends State<GroupReceiptSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _receipts = [];
  Set<String> _selectedReceiptIds = <String>{};
  bool _isLoading = true;
  bool _isAdding = false;
  List<Map<String, dynamic>> _groupMembers = [];
  bool _isLoadingMembers = false;

  // Pagination variables
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalCount = 0;
  bool _hasNextPage = false;
  bool _isLoadingMore = false;

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
    _fetchReceipts(reset: true);
    _fetchGroupMembers();
  }

  List<Map<String, dynamic>> _getDemoGroupMembers() {
    return [
      {
        'userId': 'demo-user-1',
        'id': 'demo-user-1',
        '_id': 'demo-user-1',
        'name': 'John Doe',
      },
      {
        'userId': 'demo-user-2',
        'id': 'demo-user-2',
        '_id': 'demo-user-2',
        'name': 'Sarah Miller',
      },
      {
        'userId': 'demo-user-3',
        'id': 'demo-user-3',
        '_id': 'demo-user-3',
        'name': 'Bhavneesh Sharma',
      },
    ];
  }

  Future<void> _fetchGroupMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final result = await ExpenseGroupService.getGroupDetails(
        groupId: widget.groupId,
        userId: widget.userId,
        token: widget.token,
      );

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final group = data['group'] as Map<String, dynamic>;
        final balances = data['balances'] as List<dynamic>? ?? [];
        
        // Use balances if available, otherwise use members
        if (balances.isNotEmpty) {
          setState(() {
            _groupMembers = balances.map((balance) {
              final balanceMap = balance as Map<String, dynamic>;
              return {
                'userId': balanceMap['userId'],
                'email': balanceMap['email'],
                'name': balanceMap['name'],
                'memberId': balanceMap['memberId'],
              };
            }).toList();
          });
        } else {
          final members = group['members'] as List<dynamic>? ?? [];
          setState(() {
            _groupMembers = members.map((member) {
              final memberMap = member as Map<String, dynamic>;
              return {
                'userId': memberMap['userId'],
                'email': memberMap['email'],
                'name': memberMap['name'],
                'memberId': memberMap['id'],
              };
            }).toList();
          });
        }
      } else {
        debugPrint('Error fetching group members: ${result['error']}');
        // Fallback to demo data on error
        setState(() {
          _groupMembers = _getDemoGroupMembers();
        });
      }
    } catch (e) {
      debugPrint('Error fetching group members: $e');
      // Fallback to demo data on error
      setState(() {
        _groupMembers = _getDemoGroupMembers();
      });
    } finally {
      setState(() => _isLoadingMembers = false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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

  List<Map<String, dynamic>> _getDemoReceipts() {
    final now = DateTime.now();
    return [
      {
        'id': 'demo-receipt-1',
        'merchant': 'dinner',
        'category': 'Bills',
        'amount': '323.00',
        'receiptDate': now.subtract(const Duration(days: 1)).toIso8601String(),
        'isSaved': true,
        'isManual': false,
        'imageUrl': '',
      },
      {
        'id': 'demo-receipt-2',
        'merchant': 'test',
        'category': 'Benefits',
        'amount': '1234.56',
        'receiptDate': now.subtract(const Duration(days: 1)).toIso8601String(),
        'isSaved': true,
        'isManual': false,
        'imageUrl': '',
      },
      {
        'id': 'demo-receipt-3',
        'merchant': 'wuhfcw',
        'category': 'Benefits',
        'amount': '133.00',
        'receiptDate': now.subtract(const Duration(days: 8)).toIso8601String(),
        'isSaved': true,
        'isManual': false,
        'imageUrl': '',
      },
      {
        'id': 'demo-receipt-4',
        'merchant': 'suhxa',
        'category': 'Bills',
        'amount': '345.00',
        'receiptDate': now.subtract(const Duration(days: 9)).toIso8601String(),
        'isSaved': true,
        'isManual': false,
        'imageUrl': '',
      },
      {
        'id': 'demo-receipt-5',
        'merchant': 'Coffee Shop',
        'category': 'Food & Dining',
        'amount': '125.50',
        'receiptDate': now.subtract(const Duration(days: 2)).toIso8601String(),
        'isSaved': true,
        'isManual': false,
        'imageUrl': '',
      },
      {
        'id': 'demo-receipt-6',
        'merchant': 'Gas Station',
        'category': 'Transportation',
        'amount': '2500.00',
        'receiptDate': now.subtract(const Duration(days: 3)).toIso8601String(),
        'isSaved': true,
        'isManual': false,
        'imageUrl': '',
      },
      {
        'id': 'demo-receipt-7',
        'merchant': 'Grocery Store',
        'category': 'Shopping',
        'amount': '567.89',
        'receiptDate': now.subtract(const Duration(days: 5)).toIso8601String(),
        'isSaved': true,
        'isManual': false,
        'imageUrl': '',
      },
      {
        'id': 'demo-receipt-8',
        'merchant': 'Restaurant',
        'category': 'Food & Dining',
        'amount': '890.00',
        'receiptDate': now.subtract(const Duration(days: 4)).toIso8601String(),
        'isSaved': true,
        'isManual': false,
        'imageUrl': '',
      },
    ];
  }

  Future<void> _fetchReceipts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _receipts.clear();
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      // Build query parameters including search
      String endpoint = '/receipts/${widget.userId}?page=$_currentPage&pageSize=$_pageSize';
      
      // Add search query as merchant parameter for backend search
      if (_searchController.text.trim().isNotEmpty) {
        endpoint += '&merchant=${Uri.encodeComponent(_searchController.text.trim())}';
      }
      
      final response = await ApiService.get(
        endpoint,
        token: widget.token,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> fetchedReceipts = [];
        Map<String, dynamic> pagination = {};

        if (data is Map && data.containsKey('receipts')) {
          fetchedReceipts = List<Map<String, dynamic>>.from(data['receipts'] ?? []);
          pagination = data['pagination'] ?? {};
          setState(() {
            _totalCount = pagination['totalCount'] ?? 0;
            _hasNextPage = pagination['hasNextPage'] ?? false;
          });
        } else {
          fetchedReceipts = List<Map<String, dynamic>>.from(data is List ? data : []);
          setState(() {
            _totalCount = fetchedReceipts.length;
            _hasNextPage = false;
          });
        }

        // Filter out unsaved receipts and group receipts
        fetchedReceipts = fetchedReceipts.where((receipt) {
          final isSaved = receipt['isSaved'] != false;
          final isGroupReceipt = receipt['isGroupReceipt'] == true || receipt['groupId'] != null;
          return isSaved && !isGroupReceipt; // Only show personal saved receipts
        }).toList();

        // Sort by date (newest first)
        fetchedReceipts.sort((a, b) {
          DateTime? dateA = _parseDate(a['receiptDate']);
          DateTime? dateB = _parseDate(b['receiptDate']);

          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;

          return dateB.compareTo(dateA);
        });

        setState(() {
          if (reset) {
            _receipts = fetchedReceipts;
          } else {
            _receipts.addAll(fetchedReceipts);
          }
        });
      } else {
        debugPrint('Failed to load receipts: ${response.statusCode}');
        // Fallback to empty list on error
        setState(() {
          _totalCount = 0;
          _hasNextPage = false;
          if (reset) {
            _receipts = [];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching receipts: $e");
      // Fallback to demo data on error
      final demoReceipts = _getDemoReceipts();
      setState(() {
        _totalCount = demoReceipts.length;
        _hasNextPage = false;
        if (reset) {
          _receipts = demoReceipts;
        } else {
          _receipts.addAll(demoReceipts);
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
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

  List<Map<String, dynamic>> get _filteredReceipts => _receipts;

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchReceipts(reset: true);
    });
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

  void _selectAllReceipts() {
    setState(() {
      if (_selectedReceiptIds.length == _filteredReceipts.length) {
        _selectedReceiptIds.clear();
      } else {
        _selectedReceiptIds = _filteredReceipts
            .map((receipt) => receipt['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
      }
    });
  }

  Future<void> _addReceiptsToGroup() async {
    if (_selectedReceiptIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one receipt'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get selected receipts
    final selectedReceipts = _receipts.where((receipt) {
      final receiptId = receipt['id']?.toString() ?? '';
      return _selectedReceiptIds.contains(receiptId);
    }).toList();

    // Navigate to split options screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupSplitOptionsScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
          selectedReceipts: selectedReceipts,
          groupMembers: _groupMembers,
          userId: widget.userId,
          token: widget.token,
        ),
      ),
    );

    // If split was successful, navigate back to group details
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  bool _isManualReceipt(Map<String, dynamic> receipt) {
    final imageUrl = receipt['decryptedImageLink'] ?? receipt['decryptedImageUrl'] ?? receipt['imageLink'] ?? receipt['imageUrl'] ?? '';
    return receipt['isManual'] == true ||
        imageUrl.contains('placeholder') ||
        imageUrl.contains('Manual+Receipt') ||
        imageUrl.isEmpty ||
        imageUrl == 'null';
  }

  bool _isPdfReceipt(Map<String, dynamic> receipt) {
    final link = (receipt['decryptedImageLink'] ?? receipt['decryptedImageUrl'] ?? receipt['imageLink'] ?? receipt['imageUrl'] ?? '').toString().toLowerCase();
    return link.endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final filteredReceipts = _filteredReceipts;
    final userProvider = Provider.of<UserProvider>(context);
    final currencySymbol = userProvider.effectiveCurrencySymbol;

    return Scaffold(
      body: Column(
        children: [
          // Purple header
          Container(
            color: const Color(0xFF7E5EFD),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 16,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          widget.groupName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select receipts to add to group',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Selection header
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
                const Spacer(),
                TextButton(
                  onPressed: _selectAllReceipts,
                  child: Text(
                    _selectedReceiptIds.length == filteredReceipts.length ? 'Deselect All' : 'Select All',
                    style: const TextStyle(
                      color: Color(0xFF7E5EFD),
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
                                hintText: 'Search by merchant name...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                              ),
                              onChanged: _onSearchChanged,
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
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                            ),
                          )
                        : filteredReceipts.isEmpty
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
                                      'Try adjusting your search',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filteredReceipts.length + (_hasNextPage ? 1 : 0),
                                itemBuilder: (context, index) {
                                  // Load more button
                                  if (index == filteredReceipts.length) {
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
                                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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

                                  final receipt = filteredReceipts[index];
                                  final receiptId = receipt['id']?.toString() ?? '';
                                  final isSelected = _selectedReceiptIds.contains(receiptId);
                                  final merchant = receipt['merchant'] ?? 'Unknown';
                                  final amount = receipt['amount']?.toString() ?? '0';
                                  final category = receipt['category']?.toString() ?? 'Uncategorized';
                                  final isPdf = _isPdfReceipt(receipt);
                                  final isManual = _isManualReceipt(receipt);

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
                                      onTap: () => _toggleReceiptSelection(receiptId),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFFD1C4E9) : const Color(0xFFE8E6FF),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            children: [
                                              // Selection icon
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
                                                        Icons.check,
                                                        size: 16,
                                                        color: Colors.white,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 12),

                                              // Receipt icon (aligned with reports screen)
                                              Builder(
                                                builder: (context) {
                                                  if (isPdf) {
                                                    return Container(
                                                      width: 50,
                                                      height: 50,
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons.picture_as_pdf,
                                                          size: 28,
                                                          color: Color(0xFF7E5EFD),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  
                                                  final brandIcon = getMerchantIcon(merchant);
                                                  final brandColor = getMerchantColor(merchant);
                                                  final emoji = getMerchantEmoji(merchant) ?? getCategoryEmoji(category);
                                                  final icon = brandIcon ?? getCategoryIcon(category);
                                                  final color = brandColor ?? getCategoryColor(category);
                                                  
                                                  if (emoji != null) {
                                                    return Container(
                                                      width: 50,
                                                      height: 50,
                                                      child: Center(
                                                        child: Text(
                                                          emoji,
                                                          style: const TextStyle(fontSize: 24),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  
                                                  return Container(
                                                    width: 50,
                                                    height: 50,
                                                    child: Center(
                                                      child: Icon(
                                                        icon,
                                                        size: 28,
                                                        color: color,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 16),

                                              // Receipt details
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

                                              // Amount and date
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

                  // Bottom action button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isAdding || _selectedReceiptIds.isEmpty) ? null : _addReceiptsToGroup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E5EFD),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isAdding
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add ${_selectedReceiptIds.isEmpty ? '' : '${_selectedReceiptIds.length} '}Receipt${_selectedReceiptIds.length == 1 ? '' : 's'} to Group',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
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

