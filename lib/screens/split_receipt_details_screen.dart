import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';
import '../utils/payment_helper.dart';

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
  bool _loadingPaymentCatalog = false;
  List<Map<String, dynamic>> _paymentCatalog = [];
  String? _modalError; // Error message to display in modal

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

  double _parseAmount(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    final sanitized = value.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(sanitized) ?? 0;
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
    final userEmail = userProvider.effectiveEmail.toLowerCase();
    final userId = userProvider.userId;

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

    Map<String, dynamic>? currentUserParticipant;
    for (final participant in participants) {
      final participantUserId = participant['userId']?.toString();
      final participantEmail = (participant['email'] ?? '').toString().toLowerCase();
      if ((participantUserId != null && participantUserId == userId) ||
          (participantEmail.isNotEmpty && participantEmail == userEmail)) {
        currentUserParticipant = participant;
        break;
      }
    }

    final double userShareAmount = _parseAmount(currentUserParticipant?['share']);
    final String userPaymentStatus = (currentUserParticipant?['paymentStatus'] ?? '').toString().toLowerCase();
    final bool canShowPayShareButton = currentUserParticipant != null &&
        userShareAmount > 0 &&
        userPaymentStatus != 'paid';

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Participants',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (canShowPayShareButton)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.receipt, size: 18, color: Colors.white),
                      label: const Text(
                        'Pay Your Share',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () => _showPayYourShareModal(userShareAmount, currencySymbol),
                    ),
                ],
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

  IconData _getPaymentIcon(String paymentType) {
    final type = paymentType.toLowerCase();
    if (type.contains('google') || type.contains('gpay')) {
      return Icons.contactless_outlined;
    } else if (type.contains('paytm')) {
      return Icons.phone_iphone;
    } else if (type.contains('upi')) {
      return Icons.account_balance;
    } else if (type.contains('paypal')) {
      return Icons.account_balance_wallet_outlined;
    } else if (type.contains('zelle')) {
      return Icons.payments;
    } else if (type.contains('stripe')) {
      return Icons.credit_card;
    }
    return Icons.payment;
  }

  Future<void> _fetchPaymentCatalogForModal(Function setModalState, [Function? updateError]) async {
    setModalState(() {
      _loadingPaymentCatalog = true;
    });
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId;
      
      if (userId == null || userId.isEmpty) {
        debugPrint('Error: User ID is missing for fetching payment catalog.');
        setModalState(() {
          _loadingPaymentCatalog = false;
        });
        return;
      }

      final endpoint = '/payments/catalog/$userId';
      debugPrint('Fetching payment catalog from: $endpoint (platform header sent automatically via VersionService)');

      final response = await ApiService.get(endpoint, token: widget.token);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<Map<String, dynamic>> catalog = [];
        
        // Handle new API response structure: { success: true, data: { recommendedPartners: [...] } }
        if (responseData is Map && responseData.containsKey('data')) {
          final data = Map<String, dynamic>.from(responseData['data'] as Map);
          // First try recommendedPartners
          if (data.containsKey('recommendedPartners') && data['recommendedPartners'] is List) {
            final partners = data['recommendedPartners'] as List;
            catalog = List<Map<String, dynamic>>.from(
              partners.map((item) => Map<String, dynamic>.from(item as Map)),
            );
          }
          // If no recommendedPartners, try catalog based on userCountry
          else if (data.containsKey('userCountry') && data.containsKey('catalog')) {
            final catalogData = data['catalog'] as Map<String, dynamic>;
            final userCountry = (data['userCountry'] ?? '').toString().toLowerCase();
            
            // Map country names to catalog keys
            String catalogKey = 'india'; // default
            if (userCountry.contains('united states') || userCountry.contains('usa') || userCountry.contains('us')) {
              catalogKey = 'unitedStates';
            } else if (userCountry.contains('india') || userCountry.contains('in')) {
              catalogKey = 'india';
            }
            
            if (catalogData.containsKey(catalogKey) && catalogData[catalogKey] is List) {
              final countryCatalog = catalogData[catalogKey] as List;
              catalog = List<Map<String, dynamic>>.from(
                countryCatalog.map((item) => Map<String, dynamic>.from(item as Map)),
              );
            }
          }
        } else if (responseData is List) {
          catalog = List<Map<String, dynamic>>.from(
            responseData.map((item) => Map<String, dynamic>.from(item as Map)),
          );
        } else if (responseData is Map && responseData.containsKey('catalog')) {
          final catalogData = responseData['catalog'];
          if (catalogData is List) {
            catalog = List<Map<String, dynamic>>.from(
              catalogData.map((item) => Map<String, dynamic>.from(item as Map)),
            );
          }
        } else if (responseData is Map) {
          // If the response is a single object, convert to list
          catalog = [Map<String, dynamic>.from(responseData)];
        }
        
        setModalState(() {
          _paymentCatalog = catalog;
          _loadingPaymentCatalog = false;
        });
        debugPrint('Successfully fetched payment catalog: ${catalog.length} options');
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Failed to load payment catalog';
        debugPrint('Failed to load payment catalog: ${response.statusCode} - $errorMessage');
        setModalState(() {
          _loadingPaymentCatalog = false;
          if (updateError != null) {
            updateError('Failed to load payment options. Please try again.');
          } else {
            _modalError = 'Failed to load payment options. Please try again.';
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching payment catalog: $e');
      setModalState(() {
        _loadingPaymentCatalog = false;
        if (updateError != null) {
          updateError('Error loading payment options. Please try again.');
        } else {
          _modalError = 'Error loading payment options. Please try again.';
        }
      });
    }
  }

  Widget _buildLogoWidget(String logoUrl, IconData fallbackIcon) {
    final isSvg = logoUrl.toLowerCase().endsWith('.svg');
    
    if (isSvg) {
      return SvgPicture.network(
        logoUrl,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
            ),
          ),
        ),
        semanticsLabel: 'Payment logo',
        height: 40,
        width: 40,
      );
    } else {
      return Image.network(
        logoUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading logo: $error');
          return Icon(
            fallbackIcon,
            color: const Color(0xFF7E5EFD),
            size: 28,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
              ),
            ),
          );
        },
      );
    }
  }

  void _showPayYourShareModal(double amount, String currencySymbol) {
    // Reset payment catalog state when opening modal
    setState(() {
      _paymentCatalog = [];
      _loadingPaymentCatalog = false;
      _modalError = null;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Local error state for the modal - sync with class variable
            String? modalError = _modalError;
            
            // Function to update error state
            void updateError(String? error) {
              setModalState(() {
                _modalError = error;
                modalError = error;
              });
            }
            
            // Fetch payment catalog when modal opens (only once)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_loadingPaymentCatalog && _paymentCatalog.isEmpty) {
                setModalState(() {
                  _loadingPaymentCatalog = true;
                });
                _fetchPaymentCatalogForModal(setModalState, updateError);
              }
            });
            
            // Build payment options from catalog or use fallback
            final paymentOptions = _paymentCatalog.isEmpty
                ? [
                    // Fallback options if API returns empty
                    {
                      'icon': Icons.contactless_outlined,
                      'title': 'Google Pay',
                      'subtitle': 'G Pay',
                      'type': 'google_pay',
                      'logoUrl': '',
                    },
                    {
                      'icon': Icons.phone_iphone,
                      'title': 'Paytm',
                      'subtitle': 'Paytm',
                      'type': 'paytm',
                      'logoUrl': '',
                    },
                    {
                      'icon': Icons.account_balance,
                      'title': 'UPI',
                      'subtitle': 'UPI',
                      'type': 'upi',
                      'logoUrl': '',
                    },
                    {
                      'icon': Icons.account_balance_wallet_outlined,
                      'title': 'PayPal',
                      'subtitle': 'PayPal',
                      'type': 'paypal',
                      'logoUrl': '',
                    },
                    {
                      'icon': Icons.payments,
                      'title': 'Zelle',
                      'subtitle': 'Zelle',
                      'type': 'zelle',
                      'logoUrl': '',
                    },
                    {
                      'icon': Icons.credit_card,
                      'title': 'Stripe',
                      'subtitle': 'Stripe',
                      'type': 'stripe',
                      'logoUrl': '',
                    },
                  ]
                : _paymentCatalog.map((item) {
                    final id = (item['id'] ?? '').toString();
                    final type = (item['type'] ?? 'WALLET').toString();
                    final name = (item['name'] ?? '').toString();
                    final logoUrl = (item['logo'] ?? '').toString();
                    
                    debugPrint('Payment option: $name (ID: $id), Logo URL: $logoUrl');
                    
                    return {
                      'icon': _getPaymentIcon(id.isNotEmpty ? id : name),
                      'title': name,
                      'subtitle': item['description']?.toString() ?? '',
                      'type': type,
                      'logoUrl': logoUrl,
                      'data': item,
                    };
                  }).toList();
            
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pay Your Share',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7E5EFD),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$currencySymbol${amount.toStringAsFixed(2)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Amount to Pay',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _loadingPaymentCatalog
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                                ),
                              ),
                            )
                          : paymentOptions.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text(
                                    'No payment options available',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: paymentOptions.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.0,
                                  ),
                                  itemBuilder: (context, index) {
                                    final option = paymentOptions[index];
                                    final logoUrl = option['logoUrl'] as String?;
                                    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;
                                    final data = option['data'] as Map<String, dynamic>?;
                                    final paymentName = (option['title'] ?? '').toString();
                                    final redirectUrl = (data?['redirectUrl'] ?? '').toString();
                                    final deepLink = (data?['deepLink'] ?? '').toString(); // Get deepLink from catalog (iOS/Android)
                                    final webUrl = (data?['webUrl'] ?? '').toString(); // Get webUrl from catalog (fallback)
                                    
                                    // Debug: Verify data is extracted from catalog response
                                    debugPrint('💳 Payment option: $paymentName');
                                    debugPrint('🔗 redirectUrl from catalog: $redirectUrl');
                                    debugPrint('🔗 deepLink from catalog: $deepLink');
                                    debugPrint('🌐 webUrl from catalog: $webUrl');
                                    if (data != null) {
                                      debugPrint('📦 Full payment data: $data');
                                    }
                                    
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () async {
                                          // Clear previous errors
                                          updateError(null);

                                          if (redirectUrl.isEmpty) {
                                            debugPrint('❌ redirectUrl is empty for $paymentName');
                                            updateError('$paymentName is not available on this platform');
                                            return;
                                          }

                                          debugPrint('👆 User clicked $paymentName');
                                          debugPrint('🔗 Using redirectUrl: $redirectUrl');

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

                                          // Use redirectUrl, deepLink (if available), and webUrl (as fallback) to open app
                                          final result = await PaymentHelper.openPaymentAppFromRedirectUrl(
                                            redirectUrl,
                                            widget.token,
                                            deepLink: deepLink.isNotEmpty ? deepLink : null,
                                            webUrl: webUrl.isNotEmpty ? webUrl : null,
                                          );

                                          // Hide loading indicator
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }

                                          // Show appropriate error based on result
                                          if (result != PaymentHelper.resultSuccess && context.mounted) {
                                            if (result == PaymentHelper.resultBackendError) {
                                              PaymentHelper.showBackendErrorDialog(
                                                context: context,
                                                appName: paymentName,
                                                errorMessage: 'Payment service is temporarily unavailable. Please try again later.',
                                              );
                                            } else if (result == PaymentHelper.resultAppNotInstalled) {
                                              PaymentHelper.showAppNotInstalledDialog(
                                                context: context,
                                                appName: paymentName,
                                              );
                                            } else {
                                              // No deep link or other error
                                              updateError('Unable to open $paymentName. Please try again.');
                                            }
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF6F5FF),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFE0DBFF)),
                                          ),
                                          padding: const EdgeInsets.all(8),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              height: 40,
                                              width: 40,
                                              child: hasLogo
                                                  ? _buildLogoWidget(logoUrl!, option['icon'] as IconData)
                                                  : Icon(
                                                      option['icon'] as IconData,
                                                      color: const Color(0xFF7E5EFD),
                                                      size: 28,
                                                    ),
                                            ),
                                            const SizedBox(height: 6),
                                            Flexible(
                                              child: Text(
                                                option['title'] as String,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      // Error message display
                      if (modalError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  modalError!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

extension StringExtension on String {
  String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  String toTitleCase() => replaceAll(RegExp(' +'), ' ').split(' ').map((str) => StringExtension(str).toCapitalized()).join(' ');
}
