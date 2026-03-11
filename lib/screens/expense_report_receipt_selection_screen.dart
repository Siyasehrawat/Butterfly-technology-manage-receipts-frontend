import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';

class ExpenseReportReceiptSelectionScreen extends StatefulWidget {
  final String reportId; // Will be empty for new reports, actual ID for edits
  final String userId;
  final String token;
  final String reportTitle;
  final String reportDescription;
  final String sortBy;
  final String exportFormat;
  final bool isEditing; // Flag to indicate if we're editing an existing report
  final List<String> existingReceiptIds; // Existing receipt IDs for editing

  const ExpenseReportReceiptSelectionScreen({
    Key? key,
    required this.reportId,
    required this.userId,
    required this.token,
    required this.reportTitle,
    this.reportDescription = '',
    this.sortBy = 'date',
    this.exportFormat = 'pdf',
    this.isEditing = false,
    this.existingReceiptIds = const [],
  }) : super(key: key);

  @override
  State<ExpenseReportReceiptSelectionScreen> createState() => _ExpenseReportReceiptSelectionScreenState();
}

class _ExpenseReportReceiptSelectionScreenState extends State<ExpenseReportReceiptSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _receipts = [];
  Set<String> _selectedReceiptIds = <String>{};
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isSavingDraft = false;

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

    // Pre-select existing receipts if editing
    if (widget.isEditing) {
      _selectedReceiptIds = widget.existingReceiptIds.toSet();
    }

    _fetchReceipts(reset: true); // Initial fetch with reset
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

  Future<void> _fetchReceipts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _receipts.clear(); // Clear existing receipts
        // Keep _selectedReceiptIds if editing, clear if creating new
        if (!widget.isEditing) {
          _selectedReceiptIds.clear();
        }
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
      // Note: Backend uses 'merchant' parameter for search
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
          // Fallback for old format, assume no pagination
          fetchedReceipts = List<Map<String, dynamic>>.from(data is List ? data : []);
          setState(() {
            _totalCount = fetchedReceipts.length; // Assume all fetched
            _hasNextPage = false; // No next page if all fetched
          });
        }

        // Filter out unsaved receipts
        fetchedReceipts = fetchedReceipts.where((receipt) => receipt['isSaved'] != false).toList();

        // Sort receipts based on selected sort option
        if (widget.sortBy == 'date') {
          fetchedReceipts.sort((a, b) {
            DateTime? dateA = _parseDate(a['receiptDate']);
            DateTime? dateB = _parseDate(b['receiptDate']);

            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;

            return dateB.compareTo(dateA);
          });
        } else if (widget.sortBy == 'category') {
          fetchedReceipts.sort((a, b) {
            final categoryA = (a['category'] ?? 'Uncategorized').toString();
            final categoryB = (b['category'] ?? 'Uncategorized').toString();
            return categoryA.compareTo(categoryB);
          });
        }

        setState(() {
          if (reset) {
            _receipts = fetchedReceipts;
          } else {
            _receipts.addAll(fetchedReceipts);
          }
        });
      } else {
        debugPrint('Failed to load receipts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching receipts: $e");
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
      await _fetchReceipts(); // Call fetch without reset
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

  // Search is now handled by backend, so filtered receipts is just the receipts list
  List<Map<String, dynamic>> get _filteredReceipts => _receipts;

  // Handle search query changes with debouncing
  void _onSearchChanged(String value) {
    // Cancel previous timer
    _searchDebounce?.cancel();
    
    // Create new timer
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      // Reset pagination and fetch from backend when search changes
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

  // Show email dialog for export functionality
  Future<void> _showEmailDialog() async {
    if (_selectedReceiptIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one receipt'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final List<String> emails = [];
    final TextEditingController emailController = TextEditingController();
    String? dialogError;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send Report via Email'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Text(
                  'Add email addresses to send the expense report:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),

                // Email input field
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          hintText: 'Enter email address',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        final entered = emailController.text.trim();
                        final email = entered.toLowerCase();
                        if (email.isNotEmpty && _isValidEmail(email)) {
                          final existingLower = emails.map((e) => e.toLowerCase()).toSet();
                          if (!existingLower.contains(email)) {
                            setDialogState(() {
                              emails.add(email);
                              emailController.clear();
                              dialogError = null;
                            });
                          } else {
                            setDialogState(() {
                              dialogError = 'This email is already added';
                            });
                          }
                        } else {
                          setDialogState(() {
                            dialogError = 'Please enter a valid email address';
                          });
                        }
                      },
                      icon: const Icon(Icons.add, color: Color(0xFF7E5EFD)),
                    ),
                  ],
                ),

                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    dialogError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 16),

                // Email list
                if (emails.isNotEmpty) ...[
                  const Text(
                    'Email addresses:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: emails.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8E6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  emails[index],
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setDialogState(() {
                                    emails.removeAt(index);
                                  });
                                },
                                icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          ),
          actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: emails.isNotEmpty
                    ? () {
                  Navigator.pop(context);
                  _exportAndSubmitReport(emails);
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Send Report'),
              ),
          ],
        ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Updated to use correct API routes and navigate back to ExpenseReportsScreen
  Future<void> _exportAndSubmitReport([List<String>? emailAddresses]) async {
    setState(() => _isExporting = true);

    try {
      String? actualReportId;
      if (widget.isEditing) {
        // Update existing draft report using the draft endpoint
        actualReportId = widget.reportId;
        final updateResponse = await ApiService.post(
          '/expense-reports/draft/$actualReportId',
          body: {
            'title': widget.reportTitle,
            'description': widget.reportDescription,
            'emailsSentTo': emailAddresses ?? [],
            'receiptIds': _selectedReceiptIds.toList(),
          },
          token: widget.token,
        );

        debugPrint('Update draft response: ${updateResponse.statusCode}');

        if (updateResponse.statusCode != 200 && updateResponse.statusCode != 201) {
          throw Exception('Failed to update expense report: ${updateResponse.statusCode}');
        }

        // Submit the report (change status to submitted)
        final submitResponse = await ApiService.post(
          '/expense-reports/submit/$actualReportId',
          body: {},
          token: widget.token,
        );

        debugPrint('Submit response: ${submitResponse.statusCode}');

        if (submitResponse.statusCode != 200 && submitResponse.statusCode != 201) {
          throw Exception('Failed to submit expense report: ${submitResponse.statusCode}');
        }
      } else {
        // Create new report
        final createRequestBody = {
          'userId': widget.userId,
          'title': widget.reportTitle,
          'description': widget.reportDescription,
          'emailsSentTo': emailAddresses ?? [],
          'receiptIds': _selectedReceiptIds.toList(),
          'status': 'submitted',
        };

        final createResponse = await ApiService.post(
          '/expense-reports/',
          body: createRequestBody,
          token: widget.token,
        );

        debugPrint('Create response: ${createResponse.statusCode}');

        if (createResponse.statusCode == 201 || createResponse.statusCode == 200) {
          final responseData = json.decode(createResponse.body);
          actualReportId = responseData['id']?.toString() ?? responseData['_id']?.toString();
          if (actualReportId == null || actualReportId.isEmpty) {
            throw Exception('Failed to get report ID from creation response.');
          }
        } else {
          throw Exception('Failed to create expense report: ${createResponse.statusCode}');
        }
      }

      // Send email if addresses are provided and reportId is available
      if (emailAddresses != null && emailAddresses.isNotEmpty && actualReportId != null && actualReportId.isNotEmpty) {
        final emailResponse = await ApiService.post(
          '/expense-reports/$actualReportId/email',
          body: {},
          token: widget.token,
        );
        debugPrint('Email response: ${emailResponse.statusCode}');
      }

      if (mounted) {
        final emailMessage = emailAddresses != null && emailAddresses.isNotEmpty
            ? ' and sent to ${emailAddresses.length} recipient(s)'
            : '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense report ${widget.isEditing ? 'updated' : 'submitted'} successfully$emailMessage!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to expense reports screen
        Navigator.pop(context, true); // Pop this screen and pass true result
      }
    } catch (e) {
      debugPrint('Error submitting expense report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${widget.isEditing ? 'update' : 'submit'} report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // Updated to use draft endpoint for saving drafts and navigate back to ExpenseReportsScreen
  Future<void> _saveAsDraft() async {
    setState(() => _isSavingDraft = true);

    try {
      if (widget.isEditing) {
        // Update existing draft report using the draft endpoint
        final updateResponse = await ApiService.post(
          '/expense-reports/draft/${widget.reportId}',
          body: {
            'title': widget.reportTitle,
            'description': widget.reportDescription,
            'emailsSentTo': [],
            'receiptIds': _selectedReceiptIds.toList(),
          },
          token: widget.token,
        );

        debugPrint('Update draft response: ${updateResponse.statusCode}');

        if (updateResponse.statusCode == 200 || updateResponse.statusCode == 201) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense report updated successfully!'),
                backgroundColor: Colors.orange,
              ),
            );
            Navigator.pop(context, true); // Pop this screen and pass true result
          }
        } else {
          throw Exception('Failed to update expense report: ${updateResponse.statusCode}');
        }
      } else {
        // Create new draft report
        final requestBody = {
          'userId': widget.userId,
          'title': widget.reportTitle,
          'description': widget.reportDescription,
          'emailsSentTo': [],
          'receiptIds': _selectedReceiptIds.toList(),
          'status': 'draft',
        };

        final response = await ApiService.post(
          '/expense-reports/',
          body: requestBody,
          token: widget.token,
        );

        debugPrint('Create draft response: ${response.statusCode}');

        if (response.statusCode == 201 || response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense report saved as draft!'),
                backgroundColor: Colors.orange,
              ),
            );
            Navigator.pop(context, true); // Pop this screen and pass true result
          }
        } else {
          throw Exception('Failed to save expense report as draft: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error saving expense report as draft: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save draft: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingDraft = false);
      }
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
                          widget.reportTitle,
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
                  widget.isEditing ? 'Edit receipts for your expense report' : 'Select receipts for your expense report',
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PDF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
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
                      itemCount: filteredReceipts.length + (_hasNextPage ? 1 : 0), // Add 1 for load more button
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

                                    // Receipt icon
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7E5EFD),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: isManual
                                            ? const Icon(
                                          Icons.edit_note,
                                          size: 28,
                                          color: Colors.white,
                                        )
                                            : isPdf
                                            ? const Icon(
                                          Icons.picture_as_pdf,
                                          size: 28,
                                          color: Colors.white,
                                        )
                                            : const Icon(
                                          Icons.receipt,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Receipt details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Merchant name - wrap if too long
                                          Text(
                                            merchant,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                            maxLines: null,
                                            overflow: TextOverflow.visible,
                                            softWrap: true,
                                          ),
                                          const SizedBox(height: 4),
                                          // Category and Amount on same line
                                          Row(
                                            children: [
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
                                              const SizedBox(width: 8),
                                              Text(
                                                '$currencySymbol$amount',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          // Date
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

                  // Bottom action buttons
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
                    child: Column(
                      children: [
                        // Export & Email button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_isExporting || _isSavingDraft) ? null : _showEmailDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7E5EFD),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isExporting
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
                                const Icon(Icons.email, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  widget.isEditing ? 'Update & Email' : 'Export & Email',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Save as Draft button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: (_isExporting || _isSavingDraft) ? null : _saveAsDraft,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isSavingDraft
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.orange,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              widget.isEditing ? 'Update Draft' : 'Save as Draft',
                              style: const TextStyle(
                                fontSize: 16,
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
          ),
        ],
      ),
    );
  }
}