import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/user_provider.dart';
import '../services/bill_reminder_service.dart';
import '../services/api_service_bypass.dart';
import '../services/calendar_sync_service.dart';
import '../widgets/reminder_dialog.dart';
import '../utils/reminder_settings.dart';
import '../utils/payment_helper.dart';
import 'dart:convert';

class BillRemindersScreen extends StatefulWidget {
  const BillRemindersScreen({super.key});

  @override
  State<BillRemindersScreen> createState() => _BillRemindersScreenState();
}

class _BillRemindersScreenState extends State<BillRemindersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _reminders = [];
  double _thisMonthAmount = 0.0;
  bool _showDisabled = true;
  bool _calendarConnected = false;
  bool _loadingPaymentCatalog = false;
  List<Map<String, dynamic>> _paymentCatalog = [];
  String? _modalError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    setState(() {
      _loading = true;
    });
    
    // Check calendar connection status
    final calendarConnected = await CalendarSyncService.isCalendarConnected(
      user.userId ?? '',
      token: user.token,
    );
    
    // Fetch reminders using the new API endpoint with pagination
    List<Map<String, dynamic>> items = [];
    try {
      final response = await ApiService.get(
        '/reminders/${user.userId}',
        token: user.token,
        queryParameters: {
          'page': '1',
          'limit': '50', // Default limit, can be increased up to 100
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle new API response structure with activeReminders and inactiveReminders
        final List<dynamic> activeReminders = data['activeReminders'] ?? [];
        final List<dynamic> inactiveReminders = data['inactiveReminders'] ?? [];
        
        // Combine both lists
        final List<dynamic> allReminders = [...activeReminders, ...inactiveReminders];
        
        items = allReminders.map((e) => Map<String, dynamic>.from(e)).toList();
        
        debugPrint('📋 Loaded ${activeReminders.length} active and ${inactiveReminders.length} inactive reminders');
        
        // Note: Pagination metadata is available in data['pagination'] if needed for future pagination UI
        if (data['pagination'] != null) {
          debugPrint('📋 Pagination: ${data['pagination']}');
        }
      }
    } catch (e) {
      debugPrint('Error fetching reminders: $e');
    }
    
    if (!mounted) return;
    setState(() {
      _reminders = items;
      _calendarConnected = calendarConnected;
      _loading = false;
      _recomputeStats();
    });
  }

  void _recomputeStats() {
    final now = DateTime.now();
    _thisMonthAmount = 0.0;
    for (final r in _reminders) {
      final enabled = (r['isEnabled'] as bool?) ?? true;
      final dateStr = (r['reminderDate'] ?? r['receipt']?['receiptDate'] ?? '').toString();
      final dt = _parseDate(dateStr);
      final receipt = r['receipt'] as Map<String, dynamic>?;
      final amountStr = receipt?['amount']?.toString() ?? '0';
      final amt = double.tryParse(amountStr.replaceAll('₹', '').replaceAll(',', '').trim()) ?? 0.0;
      if (dt != null && dt.year == now.year && dt.month == now.month && enabled) {
        _thisMonthAmount += amt;
      }
    }
  }


  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to delete this reminder?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final user = Provider.of<UserProvider>(context, listen: false);
    final success = await BillReminderService.deleteReminderV2(
      userId: user.userId ?? '',
      reminderId: id,
      token: user.token,
    );
    if (success) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Bill Reminders',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
          actions: const [
            Padding(
            padding: EdgeInsets.only(right: 16),
              child: _HeaderLogo(),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                  // Title with Active Count
                        Row(
                          children: [
                            const Text(
                              'Active Bill Reminders',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7E5EFD),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_reminders.where((e) => (e['isEnabled'] as bool?) ?? true).length} Active',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 20),

                  // Show Disabled Reminders Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Text(
                          'Show Disabled Reminders',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _showDisabled,
                          onChanged: (value) {
                            setState(() {
                              _showDisabled = value;
                            });
                          },
                          activeColor: const Color(0xFF7E5EFD),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Add Manual pill button and Pay Your Bill button
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openReminderForm(),
                          icon: const Icon(Icons.add, size: 18, color: Colors.white),
                          label: const Text(
                            'New Bill Reminder',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E5EFD),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showPayYourBillModal(),
                          icon: const Icon(Icons.receipt, size: 18, color: Colors.white),
                          label: const Text(
                            'Pay Your Bill',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E5EFD),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Reminders List
                  ..._reminders
                      .where((r) => _showDisabled || ((r['isEnabled'] as bool?) ?? true))
                      .map((r) {
                        final userProvider = Provider.of<UserProvider>(context, listen: false);
                        final currencySymbol = userProvider.effectiveCurrencySymbol;
                        return _ReminderCard(
                            title: _getReminderTitle(r),
                              subtitle: _composeSubtitle(r, currencySymbol),
                            amountDisplay: _getReminderAmount(r),
                            enabled: (r['isEnabled'] as bool?) ?? true,
                            status: ((r['isEnabled'] as bool?) ?? true) ? 'Active' : 'Disabled',
                            tags: [],
                              onEdit: () => _openEditForm(r),
                            onDelete: () => _delete((r['id'] ?? '').toString()),
                            );
                      }).toList(),

                  // Empty State
                  if (_reminders.where((r) => _showDisabled || ((r['isEnabled'] as bool?) ?? true)).isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 64,
                            color: Color(0xFFFFC107),
                          ),
                                SizedBox(height: 16),
                                Text(
                                  'No active reminders yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    'Add reminders from your receipts or create them manually',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
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

  void _showCreateReminderOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Create Bill Reminder',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Color(0xFF7E5EFD)),
              title: const Text('New bill reminder'),
              subtitle: const Text('Create bill reminder manually'),
              onTap: () {
                Navigator.pop(context);
                _openReminderForm();
              },
            ),
            if (!_calendarConnected)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Connect Google Calendar to sync reminders',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _connectCalendar();
                      },
                      child: const Text('Connect'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectCalendar() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final success = await CalendarSyncService.connectCalendar(
      user.userId ?? '',
      token: user.token,
      context: context,
    );
    
    if (success) {
      setState(() {
        _calendarConnected = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Calendar connected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect Google Calendar. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openSelectReceiptModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Select Receipt',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchReceipts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No receipts found'),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final receipt = snapshot.data![index];
                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                      final currencySymbol = userProvider.effectiveCurrencySymbol;
                      return Card(
                        child: ListTile(
                          title: Text(receipt['merchant'] ?? 'Unknown'),
                          subtitle: Text('$currencySymbol${receipt['amount'] ?? '0'}'),
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _openReminderForm(prefill: receipt);
                            },
                            child: const Text('Add'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchReceipts() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    try {
      final response = await ApiService.get(
        '/receipts/${user.userId}?page=1&pageSize=50',
        token: user.token,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> receiptsList = data['receipts'] ?? [];
        return receiptsList.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching receipts: $e');
    }
    return [];
  }

  void _openReminderForm({Map<String, dynamic>? prefill}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.62,
        padding: const EdgeInsets.all(16),
        child: _ReminderForm(
          prefill: prefill,
          calendarConnected: _calendarConnected,
          onSave: (reminderData) async {
            Navigator.pop(context);
            await _createReminder(reminderData);
          },
        ),
      ),
    );
  }

  Future<void> _createReminder(Map<String, dynamic> reminderData) async {
    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      final bool isManual = (reminderData['receiptId'] == null || reminderData['receiptId'].toString().isEmpty);
      final response = await ApiService.post(
        isManual ? '/reminder/manual' : '/reminder',
        body: reminderData,
        token: user.token,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final calendarSynced = responseData['calendarSynced'] ?? false;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                calendarSynced 
                  ? 'Reminder created and synced to Google Calendar!'
                  : 'Reminder created successfully'
              ),
              backgroundColor: const Color(0xFF7E5EFD),
            ),
          );
        }
        _load();
      } else {
        throw Exception('Failed to create reminder');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create reminder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      final token = userProvider.token;
      
      if (userId == null || userId.isEmpty) {
        debugPrint('Error: User ID is missing for fetching payment catalog.');
        setModalState(() {
          _loadingPaymentCatalog = false;
        });
        return;
      }

      final endpoint = '/payments/catalog/$userId';
      debugPrint('Fetching payment catalog from: $endpoint');

      final response = await ApiService.get(endpoint, token: token);

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

  // Legacy URL-scheme launcher removed in favor of backend-provided deep links.

  void _showPayYourBillModal() {
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
                            'Pay Your Bill',
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

                                          // Get token from UserProvider
                                          final userProvider = Provider.of<UserProvider>(context, listen: false);
                                          
                                          // Use redirectUrl, deepLink (if available), and webUrl (as fallback) to open app
                                          final result = await PaymentHelper.openPaymentAppFromRedirectUrl(
                                            redirectUrl,
                                            userProvider.token,
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

  void _openEditForm(Map<String, dynamic> reminder) async {
    final receipt = reminder['receipt'] as Map<String, dynamic>?;
    if (receipt == null) {
      // Manual reminder edit -> open the same create form prefilled
      final manualPrefill = <String, dynamic>{
        'id': reminder['id'],
        'merchant': reminder['merchantName'] ?? 'Untitled',
        'amount': reminder['amount'],
        'category': reminder['billType'] ?? 'Other',
        // Map reminderDate to expected receiptDate key used by the form
        'receiptDate': reminder['reminderDate'],
        'manual': true,
      };

      _openReminderForm(prefill: manualPrefill);
      return;
    }

    // Create ReminderSettings from the current reminder data
    final currentSettings = ReminderSettings(
      isEnabled: reminder['isEnabled'] ?? false,
      emailReminder: reminder['emailReminder'] ?? false,
      pushNotification: reminder['pushReminder'] ?? false,
      reminderMessage: reminder['message'],
      customReminderDate: reminder['reminderDate'] != null 
          ? DateTime.tryParse(reminder['reminderDate'])
          : null,
      recurrence: reminder['recurrence'] ?? 'Monthly',
      remindBefore: reminder['remindBefore'] ?? '3 days before',
      syncToCalendar: reminder['syncToCalendar'] ?? false,
      billType: reminder['billType'], // ✅ Map billType from API
    );

    debugPrint('📅 Bill Reminders - Opening edit form with billType: ${reminder['billType']}');

    // Show the reminder dialog with prefilled data
    final updatedSettings = await showDialog<ReminderSettings>(
      context: context,
      builder: (context) => ReminderDialog(
        currentSettings: currentSettings,
        receiptDate: receipt['receiptDate'] ?? '',
        onSave: (settings) {
          _updateReminder(reminder['id'].toString(), settings, receipt);
        },
        onDelete: (userId, receiptId) {
          _delete(reminder['id'].toString());
        },
        userId: Provider.of<UserProvider>(context, listen: false).userId ?? '',
        receiptId: reminder['receiptId'].toString(),
        reminderId: reminder['id']?.toString(), // Pass the reminder ID for editing
        merchant: receipt['merchant']?.toString(),
        amount: receipt['originalAmount'] ?? receipt['amount'],
        category: receipt['category']?.toString(),
      ),
    );
  }

  Future<void> _updateReminder(String reminderId, ReminderSettings settings, Map<String, dynamic> receipt) async {
    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      final effectiveDate = settings.customReminderDate ?? DateTime.parse(receipt['receiptDate']);
      final reminderDateString = DateFormat('yyyy-MM-dd').format(effectiveDate);

      final body = {
        'userId': user.userId,
        'receiptId': receipt['id'],
        'reminderDate': reminderDateString,
        'billType': settings.billType ?? receipt['category'] ?? 'Other',
        'recurrence': settings.recurrence ?? 'Monthly',
        'remindBefore': settings.remindBefore ?? '3 days before',
        'syncToCalendar': settings.syncToCalendar,
        'isEnabled': settings.isEnabled,
        'emailReminder': settings.emailReminder,
        'pushReminder': settings.pushNotification,
        'message': settings.reminderMessage,
      };

      final response = await ApiService.post(
        '/reminder',
        body: body,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final calendarSynced = responseData['calendarSynced'] ?? false;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                calendarSynced 
                  ? 'Reminder updated and synced to Google Calendar'
                  : 'Reminder updated successfully'
              ),
              backgroundColor: const Color(0xFF7E5EFD),
            ),
          );
        }
        // Reload the reminders list
        _load();
      } else {
        throw Exception('Failed to update reminder');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update reminder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper methods to extract data from API response
  String _getReminderTitle(Map<String, dynamic> reminder) {
    final receipt = reminder['receipt'] as Map<String, dynamic>?;
    if (receipt != null) {
      return receipt['merchant']?.toString() ?? 'Untitled';
    }
    // Manual reminder: show merchantName
    return (reminder['merchantName'] ?? 'Untitled').toString();
  }

  String _getReminderAmount(Map<String, dynamic> reminder) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currencySymbol = userProvider.effectiveCurrencySymbol;
    
    final receipt = reminder['receipt'] as Map<String, dynamic>?;
    if (receipt != null) {
      return receipt['amount']?.toString() ?? '$currencySymbol 0.00';
    }
    final amount = reminder['amount'];
    if (amount == null) return '$currencySymbol 0.00';
    final cleaned = amount.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    final num? n = (amount is num) ? amount : num.tryParse(cleaned);
    if (n == null) return amount.toString();
    return '$currencySymbol${n.toStringAsFixed(2)}';
  }

  List<String> _getReminderTags(Map<String, dynamic> reminder) {
    final receipt = reminder['receipt'] as Map<String, dynamic>?;
    final tagsStr = receipt?['tags']?.toString() ?? '';
    if (tagsStr.isEmpty) return [];
    return tagsStr.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
  }


  DateTime? _parseDate(String s) {
    try {
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    } catch (_) {
      return null;
    }
  }
}

class _ReminderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amountDisplay;
  final bool enabled;
  final String? status;
  final List<String>? tags;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReminderCard({
    required this.title,
    required this.subtitle,
    required this.amountDisplay,
    required this.enabled,
    this.status,
    this.tags,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                      flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                          const SizedBox(width: 8),
                          if (status != null)
                            Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                    color: enabled ? Colors.green : Colors.grey.shade400,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            ),
                        ],
                      ),
                  ),
                    const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF7E5EFD)),
                  onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                ),
              ],
            ),
            if (tags != null && tags!.isNotEmpty) ...[
            const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: tags!
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7E5EFD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        ))
                    .toList(),
              ),
            ],
          ],
      ),
    );
  }
}


class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  const _MetricCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAmount(dynamic amount, String currencySymbol) {
  if (amount == null) return '';
  final cleaned = amount.toString().replaceAll(RegExp(r'[^0-9.]'), '');
  final num? n = (amount is num) ? amount : num.tryParse(cleaned);
  if (n == null) return amount.toString();
  return '$currencySymbol${n.toStringAsFixed(2)}';
}

String _composeSubtitle(Map<String, dynamic> r, String currencySymbol) {
  final date = _formatDateForDisplay(r['reminderDate']?.toString() ?? '');
  final receipt = r['receipt'] as Map<String, dynamic>?;
  // For receipt-based reminders, read from receipt; for manual, use reminder fields
  final dynamic amountSource = receipt != null
      ? (receipt['originalAmount'] ?? receipt['amount'])
      : (r['amount']);
  final amt = _formatAmount(amountSource, currencySymbol);
  final category = ((receipt != null
          ? receipt['category']?.toString()
          : r['billType']?.toString())
      ?? '')
      .toLowerCase();
  final parts = [date, if (amt.isNotEmpty) amt, if (category.isNotEmpty) category];
  return parts.where((e) => e.toString().isNotEmpty).join(' • ');
}

String _formatDateForDisplay(String dateStr) {
  if (dateStr.isEmpty) return '';
  try {
    final date = DateTime.parse(dateStr);
    return '${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month)}, ${date.year}';
  } catch (e) {
    return dateStr;
  }
}

String _getMonthName(int month) {
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return months[month];
}

List<String> _tagsFromString(dynamic tags) {
  if (tags == null) return [];
  return tags.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}



class _ReminderForm extends StatefulWidget {
  final Map<String, dynamic>? prefill;
  final bool calendarConnected;
  final Function(Map<String, dynamic>) onSave;

  const _ReminderForm({
    this.prefill,
    required this.calendarConnected,
    required this.onSave,
  });

  @override
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  
  String _category = 'Utilities';
  String _schedule = 'Custom Date';
  DateTime? _selectedDate;
  String _occurrence = 'Monthly';
  String _remindBefore = '1 day before';
  bool _enabled = true;
  bool _sendEmail = true;
  bool _sendPush = true;
  bool _syncToCalendar = false;

  bool _isDateInPast(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final checkDate = DateTime(date.year, date.month, date.day);
    return checkDate.isBefore(today);
  }

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.prefill != null) {
      _titleController.text = widget.prefill!['merchant'] ?? '';
      final String prefillAmountRaw = widget.prefill!['amount']?.toString() ?? '';
      final String prefillAmountClean = prefillAmountRaw.replaceAll(RegExp(r'[^0-9.]'), '');
      if (prefillAmountClean.isNotEmpty) {
        final num? amtNum = num.tryParse(prefillAmountClean);
        _amountController.text = amtNum != null
            ? amtNum.toStringAsFixed(2)
            : prefillAmountClean;
      } else {
        _amountController.text = '';
      }
      _category = widget.prefill!['category'] ?? 'Utilities';
      // Tags field removed
      
      final receiptDate = widget.prefill!['receiptDate'];
      if (receiptDate != null) {
        _selectedDate = DateTime.tryParse(receiptDate);
        _schedule = 'Bill Date';
      } else {
        _selectedDate = DateTime.now().add(const Duration(days: 1));
        _schedule = 'Custom Date';
      }
    } else {
      // For manual reminders, default to tomorrow
      _selectedDate = DateTime.now().add(const Duration(days: 1));
      _schedule = 'Custom Date';
    }
    
    // Default sync to calendar if connected
    _syncToCalendar = widget.calendarConnected;
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Set Reminder',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Receipt Info (only for receipt-based reminders)
          if (widget.prefill != null && widget.prefill!['manual'] != true) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Receipt Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Merchant: ${widget.prefill!['merchant'] ?? 'Unknown'}'),
                  Builder(
                    builder: (context) {
                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                      final currencySymbol = userProvider.effectiveCurrencySymbol;
                      return Text('Amount: $currencySymbol${widget.prefill!['amount'] ?? '0'}');
                    },
                  ),
                  Text('Date: ${widget.prefill!['receiptDate'] ?? 'Unknown'}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enable Reminder toggle - compact like reminder dialog
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined, color: Color(0xFF7E5EFD), size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Enable Reminder',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Switch(
                          value: _enabled,
                          activeColor: const Color(0xFF7E5EFD),
                          onChanged: (v) {
                            setState(() {
                              _enabled = v;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  if (_enabled) ...[
                    // Top fields arranged like Recurrence/Remind Before (two columns)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            text: 'Merchant Name',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            children: [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              filled: true,
                              fillColor: Colors.transparent,
                            ),
                            style: const TextStyle(fontSize: 12),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a Merchant Name';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: const TextSpan(
                                  text: 'Bill Type',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: ' *',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, box) {
                                    const double fieldHeight = 36;
                                    return SizedBox(
                                      height: fieldHeight,
                                      child: PopupMenuButton<String>(
                                        constraints: BoxConstraints(
                                          minWidth: box.maxWidth,
                                          maxWidth: box.maxWidth,
                                        ),
                                        offset: const Offset(0, fieldHeight),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _category == '' ? 'Select bill type' : _category,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            const Icon(Icons.keyboard_arrow_down, size: 18),
                                          ],
                                        ),
                                        itemBuilder: (BuildContext context) => const [
                                          'Membership & Subscription',
                                          'Utilities',
                                          'Rent',
                                          'Insurance',
                                          'Loans & EMI',
                                          'Groceries',
                                          'Other',
                                        ].map((String choice) {
                                          return PopupMenuItem<String>(
                                            value: choice,
                                            child: Text(choice),
                                          );
                                        }).toList(),
                                        onSelected: (String value) {
                                          setState(() {
                                            _category = value;
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: const TextSpan(
                                  text: 'Amount',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: ' *',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: SizedBox(
                                  height: 36,
                                  child: Builder(
                                    builder: (context) {
                                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                                      final currencySymbol = userProvider.effectiveCurrencySymbol;
                                      return TextFormField(
                                        controller: _amountController,
                                        focusNode: _amountFocusNode,
                                        textAlignVertical: TextAlignVertical.center,
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                          prefixText: '$currencySymbol ',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                          filled: true,
                                          fillColor: Colors.transparent,
                                        ),
                                        style: const TextStyle(fontSize: 12),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onTap: () {
                                          // Only request focus when user explicitly taps
                                          if (!_amountFocusNode.hasFocus) {
                                            _amountFocusNode.requestFocus();
                                          }
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter an amount';
                                          }
                                          return null;
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Due Date - styled like other fields
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            text: 'Due Date',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            children: [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: _selectDate,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedDate != null
                                        ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                                        : 'Select Date',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _selectedDate != null ? Colors.black87 : Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: const Color(0xFF7E5EFD),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Info message when past date selected with recurring reminder
                    if (_selectedDate != null && _isDateInPast(_selectedDate!) && _occurrence != 'None') ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Past date selected with recurring reminder. The next occurrence will be calculated from this date.',
                                style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Recurrence and Remind Before in one row
                    Row(
                      children: [
                        // Recurrence Dropdown
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: const TextSpan(
                                  text: 'Recurrence',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: ' *',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, box) {
                                    const double fieldHeight = 36;
                                    return SizedBox(
                                      height: fieldHeight,
                                      child: PopupMenuButton<String>(
                                        constraints: BoxConstraints(
                                          minWidth: box.maxWidth,
                                          maxWidth: box.maxWidth,
                                        ),
                                        offset: const Offset(0, fieldHeight),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _occurrence,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            const Icon(Icons.keyboard_arrow_down, size: 18),
                                          ],
                                        ),
                                        itemBuilder: (BuildContext context) => const ['None','Daily','Weekly','Monthly','Quarterly','Yearly'].map((String choice) {
                                          return PopupMenuItem<String>(
                                            value: choice,
                                            child: Text(choice),
                                          );
                                        }).toList(),
                                        onSelected: (String value) {
                                          setState(() {
                                            _occurrence = value;
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Remind Before Dropdown
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: const TextSpan(
                                  text: 'Remind Before',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: ' *',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, box) {
                                    const double fieldHeight = 36;
                                    return SizedBox(
                                      height: fieldHeight,
                                      child: PopupMenuButton<String>(
                                        constraints: BoxConstraints(
                                          minWidth: box.maxWidth,
                                          maxWidth: box.maxWidth,
                                        ),
                                        offset: const Offset(0, fieldHeight),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _remindBefore,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            const Icon(Icons.keyboard_arrow_down, size: 18),
                                          ],
                                        ),
                                        itemBuilder: (BuildContext context) => const [
                                          'On the day',
                                          '1 day before',
                                          '2 days before',
                                          '3 days before',
                                          '1 week before',
                                          '2 weeks before',
                                        ].map((String choice) {
                                          return PopupMenuItem<String>(
                                            value: choice,
                                            child: Text(choice),
                                          );
                                        }).toList(),
                                        onSelected: (String value) {
                                          setState(() {
                                            _remindBefore = value;
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Reminder Methods - single line (no background/box) with wrapping
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            text: 'Reminder Methods:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            children: [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: _sendEmail,
                                  onChanged: (value) {
                                    setState(() {
                                      _sendEmail = value ?? false;
                                    });
                                  },
                                  activeColor: const Color(0xFF7E5EFD),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                const Text('Email', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: _sendPush,
                                  onChanged: (value) {
                                    setState(() {
                                      _sendPush = value ?? false;
                                    });
                                  },
                                  activeColor: const Color(0xFF7E5EFD),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                const Text('Push Notification', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Notes Section (compact)
                    Row(
                      children: [
                        const Text(
                          'Notes:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        if (_notesController.text.isNotEmpty)
                          Text(
                            '${_notesController.text.length}/200',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          hintText: 'Add notes about this bill...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          counterText: '',
                        ),
                        maxLines: 3,
                        maxLength: 200,
                        style: const TextStyle(fontSize: 13),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ),

                    // Calendar Sync (compact button style)
                    if (widget.calendarConnected)
                      const SizedBox(height: 8),
                    if (widget.calendarConnected)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _syncToCalendar = !_syncToCalendar;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: _syncToCalendar
                                  ? const Color(0xFF7E5EFD)
                                  : const Color(0xFFF2ECFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _syncToCalendar
                                    ? const Color(0xFF7E5EFD)
                                    : const Color(0xFF7E5EFD).withOpacity(0.25),
                                width: 1.5,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _syncToCalendar ? Icons.check_circle : Icons.calendar_today,
                                  size: 18,
                                  color: _syncToCalendar ? Colors.white : const Color(0xFF7E5EFD),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _syncToCalendar ? 'Will Sync to Calendar' : 'Sync to Calendar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _syncToCalendar ? Colors.white : const Color(0xFF7E5EFD),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),

          // Action Buttons row like dialog (Cancel + Save Bill Reminder)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _saveReminder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E5EFD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  child: const Text(
                    'Save Bill Reminder',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7E5EFD),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveReminder() {
    if (!_formKey.currentState!.validate()) return;
    
    DateTime? effectiveDate;
    if (_schedule == 'Custom Date') {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a due date'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      effectiveDate = _selectedDate;
    } else {
      // Bill Date - use receipt date or default
      if (widget.prefill != null && widget.prefill!['receiptDate'] != null) {
        effectiveDate = DateTime.tryParse(widget.prefill!['receiptDate']);
      }
      if (effectiveDate == null) {
        effectiveDate = DateTime.now().add(const Duration(days: 1));
      }
    }

    final user = Provider.of<UserProvider>(context, listen: false);
    // Manual if: creating new (no prefill), or prefill explicitly marked manual, or no receiptId on the prefill
    final bool isManual = widget.prefill == null || widget.prefill?['manual'] == true || widget.prefill?['receiptId'] == null;
    final reminderData = <String, dynamic>{
      'userId': user.userId,
      'reminderDate': DateFormat('yyyy-MM-dd').format(effectiveDate!),
      'billType': _category,
      'recurrence': _occurrence == 'None' ? null : _occurrence,
      'remindBefore': _remindBefore,
      'syncToCalendar': _syncToCalendar,
      'isEnabled': _enabled,
      'emailReminder': _sendEmail,
      'pushReminder': _sendPush,
      'message': _notesController.text.isNotEmpty ? _notesController.text : null,
    };

    if (isManual) {
      // Manual reminder payload per POST /reminder/manual
      // Required: merchantName, amount
      reminderData['merchantName'] = _titleController.text;
      final cleaned = _amountController.text.replaceAll(RegExp(r'[^0-9.]'), '');
      reminderData['amount'] = double.tryParse(cleaned) ?? 0.0;
      // If editing an existing manual reminder, include reminderId to update
      final existingId = widget.prefill != null ? widget.prefill!['id'] : null;
      if (existingId != null) {
        reminderData['reminderId'] = existingId.toString();
      }
    } else {
      // Receipt-based reminder (existing API)
      if (widget.prefill != null && widget.prefill!['id'] != null) {
        reminderData['receiptId'] = widget.prefill!['id'];
      }
      reminderData['message'] = _titleController.text;
    }

    widget.onSave(reminderData);
  }
}

class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
    );
  }
}


