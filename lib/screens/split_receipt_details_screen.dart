import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';

class SplitReceiptDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> receipt;
  final String userId;
  final String token;

  const SplitReceiptDetailsScreen({
    Key? key,
    required this.receipt,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<SplitReceiptDetailsScreen> createState() => _SplitReceiptDetailsScreenState();
}

class _SplitReceiptDetailsScreenState extends State<SplitReceiptDetailsScreen> {
  late Map<String, dynamic> _currentSplitBillDetails;
  bool _isLoading = true;
  bool _statusChanged = false; // New flag to track if status was changed

  @override
  void initState() {
    super.initState();
    _currentSplitBillDetails = {};
    _fetchSplitBillDetails();
  }

  Future<void> _fetchSplitBillDetails() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final splitBillId = widget.receipt['id']?.toString();
      if (splitBillId == null || splitBillId.isEmpty) {
        debugPrint('Error: Split Bill ID is missing for fetching split details.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Split Bill ID is missing.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final endpoint = '/split-bill/details/$splitBillId';
      debugPrint('Fetching split bill details from: $endpoint');

      final response = await ApiService.get(endpoint, token: widget.token);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _currentSplitBillDetails = data;
        });
        debugPrint('Successfully fetched split bill details.');
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Failed to load split bill details';
        debugPrint('Failed to load split bill details: ${response.statusCode} - $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading split details: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching split bill details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
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

  Future<void> _updateParticipantStatus(
      String participantId, String action) async { // Removed paymentAmount parameter
    setState(() {
      _isLoading = true;
    });
    try {
      final Map<String, dynamic> requestBody = {
        'participantId': participantId,
        'action': action,
      };

      final response = await ApiService.post(
        '/split-bill/update-payment',
        body: requestBody,
        token: widget.token,
      );

      if (response.statusCode == 200) {
        debugPrint('Successfully updated status for participant $participantId with action $action.');
        _statusChanged = true; // Set flag to true on successful update
        await _fetchSplitBillDetails(); // Refresh data
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar( // Changed message to generic "Status changed"
            content: Text('Status changed'),
            backgroundColor: Color(0xFF7E5EFD),
          ),
        );
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Failed to update participant status';
        debugPrint('Failed to update participant status: ${response.statusCode} - $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating participant status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currencySymbol = userProvider.effectiveCurrencySymbol;

    final merchant = _currentSplitBillDetails['merchant'] ?? 'Unknown Merchant';
    final amount = _currentSplitBillDetails['totalAmount']?.toString() ?? '0.00';
    final category = _currentSplitBillDetails['category'] ?? 'Uncategorized';

    String formattedDate = 'No date';
    if (_currentSplitBillDetails['receiptDate'] != null) {
      try {
        final DateTime? date = _parseDate(_currentSplitBillDetails['receiptDate']);
        if (date != null) {
          formattedDate = DateFormat('MMM d, yyyy').format(date);
        }
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    List<Map<String, dynamic>> participants = [];
    if (_currentSplitBillDetails.containsKey('participants') && _currentSplitBillDetails['participants'] is List) {
      participants = List<Map<String, dynamic>>.from(_currentSplitBillDetails['participants']);
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _statusChanged); // Pass the flag back when popping
        return false; // Prevent default back button behavior
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF7E5EFD),
          foregroundColor: Colors.white,
          title: const Text('Split Receipt Details'),
          leading: IconButton( // Ensure the back button also passes the result
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context, _statusChanged);
            },
          ),
          actions: [
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
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
          ),
        )
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: const Color(0xFFE8E6FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7E5EFD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.receipt,
                            size: 28,
                            color: Colors.white,
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
                                fontSize: 20,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              category,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF7E5EFD),
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
                            '$currencySymbol$amount',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 14,
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Participants',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            Expanded(
              child: participants.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_off,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No participants found for this receipt',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final participant = participants[index];
                  final participantEmail = participant['email'] ?? 'N/A';
                  final participantName = participant['name']?.toString();
                  final displayText = participantName != null && participantName.isNotEmpty
                      ? participantName
                      : participantEmail;

                  String currentParticipantStatus = (participant['paymentStatus'] ?? 'unpaid').toString();
                  // Ensure status is either 'paid' or 'unpaid'
                  if (currentParticipantStatus != 'paid') {
                    currentParticipantStatus = 'unpaid';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    color: const Color(0xFFE8E6FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Share: $currencySymbol${participant['share']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF7E5EFD),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8E6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<String>(
                                  value: currentParticipantStatus,
                                  icon: const Icon(Icons.arrow_drop_down,
                                      color: Color(0xFF7E5EFD)),
                                  iconSize: 24,
                                  elevation: 0,
                                  style: const TextStyle(
                                      color: Color(0xFF7E5EFD),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                  underline: const SizedBox(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      if (newValue == 'paid') {
                                        _updateParticipantStatus(participant['id'].toString(), 'mark_paid');
                                      } else if (newValue == 'unpaid') {
                                        _updateParticipantStatus(participant['id'].toString(), 'mark_unpaid');
                                      }
                                    }
                                  },
                                  items: <String>['paid', 'unpaid'] // Only 'paid' and 'unpaid' options
                                      .map<DropdownMenuItem<String>>((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value == 'unpaid' ? 'Not Paid' : value.toCapitalized()),
                                    );
                                  }).toList(),
                                ),
                              ),
                              // Removed the partially paid amount display
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  String toTitleCase() => replaceAll(RegExp(' +'), ' ').split(' ').map((str) => StringExtension(str).toCapitalized()).join(' ');
}
