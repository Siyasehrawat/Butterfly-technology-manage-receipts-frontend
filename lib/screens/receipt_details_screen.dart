import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';
import '../services/currency_conversion_service.dart';
import '../services/currency_helper_service.dart';
import '../services/share_intent_api_service.dart';
import '../models/receipt_models.dart';
import 'package:intl/intl.dart';
import 'full_image_view_screen.dart';
import 'pdf_viewer_screen.dart';
import '../utils/reminder_settings.dart';
import '../utils/split_participant.dart';
import '../widgets/reminder_dialog.dart';
import '../widgets/split_dialog.dart';

class ReceiptDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> receipt;
  final String imageUrl;
  final String userId;
  final String imageId;
  final bool isNewReceipt;
  final bool isPdf;
  final bool isManualReceipt;
  final String? sharedFilePath; // Path to the shared file (for cleanup on discard)

  const ReceiptDetailsScreen({
    super.key,
    required this.receipt,
    required this.imageUrl,
    required this.userId,
    required this.imageId,
    this.isNewReceipt = false,
    this.isPdf = false,
    this.isManualReceipt = false,
    this.sharedFilePath,
  });

  @override
  State<ReceiptDetailsScreen> createState() => _ReceiptDetailsScreenState();
}

class _ReceiptDetailsScreenState extends State<ReceiptDetailsScreen> {
  bool _isDeleting = false;
  bool _isSaving = false;

// Text editing controllers for inline editing
  late TextEditingController _merchantController;
  late TextEditingController _dateController;
  late TextEditingController _amountController;
  late TextEditingController _categoryController;
  late TextEditingController _tagsController;
  late TextEditingController _commentsController;

// Editing state flags
  bool _editingMerchant = false;
  bool _editingDate = false;
  bool _editingAmount = false;
  bool _editingCategory = false;
  bool _editingTags = false;
  bool _editingComments = false;

  bool _isNewReceipt = false;
  bool _isManualReceipt = false;
  bool _isPdf = false;

// Track if any changes were made
  bool _hasChanges = false;
  bool _hasReminderOrSplitChanges = false;
  List<Map<String, dynamic>> _lineItems = [];

  double _parseAmount(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    final str = raw.toString();
    final cleaned = str.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

// Currency conversion variables
  var _needsCurrencyConversion = false;
  String? _originalCurrency;
  CurrencyConversionResult? _conversionResult;
  bool _hasAcceptedConversion = false;
  bool _isLoadingConversion = false;

// Store original values to compare against
  late String _originalMerchant;
  late String _originalDate;
  late String _originalAmount;
  late String _originalCategory;
  late String _originalTags;
  late String _originalComments;

// Category dropdown functionality
  List<String> _categories = [];
  List<String> _filteredCategories = [];
  bool _showCategoryDropdown = false;
  bool _loadingCategories = false;
  final FocusNode _categoryFocusNode = FocusNode();

// Tags functionality
  List<String> _tags = [];
  final TextEditingController _tagInputController = TextEditingController();
  final FocusNode _tagInputFocusNode = FocusNode();
  static const int _maxTags = 5;

// Reminder and Split functionality
  ReminderSettings? _reminderSettings;
  String? _reminderId; // Store the reminder ID for editing
  List<SplitParticipant> _splitParticipants = [];
  bool _isLoadingReminder = false;
  bool _isLoadingSplit = false;
  bool _hasExistingSplit = false;

// Additional fields for displaying reminder/split info
  String? _reminderDateString;
  Map<String, dynamic>? _splitBillData;

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

    _isNewReceipt = widget.isNewReceipt;
    _isPdf = widget.isPdf;
    _isManualReceipt = !_isPdf && !_hasPdfUrl() && _detectManualReceipt();

    // Check for currency conversion requirement
    _needsCurrencyConversion = widget.receipt['needsCurrencyConversion'] == true;
    _originalCurrency = widget.receipt['ocrCurrency']; // Currency detected from receipt (e.g., USD)

// Initialize controllers with cleaned or default values
    String cleanMerchant(String? merchant) {
      if (merchant == null || merchant.isEmpty) {
        return _isManualReceipt ? '' : 'Unknown Merchant';
      }
      return merchant.trim();
    }

    final merchantText = cleanMerchant(widget.receipt['merchant']);
    final dateText = widget.receipt['receiptDate'] ?? '';
    final amountText = widget.receipt['amount']?.toString() ?? (_isManualReceipt ? '' : '0.00');
    final categoryText = widget.receipt['category'] ?? (_isManualReceipt ? '' : 'Uncategorized');
    final commentsText = widget.receipt['comments']?.toString() ?? '';

    _merchantController = TextEditingController(text: merchantText);
    _dateController = TextEditingController(text: dateText);
    _amountController = TextEditingController(text: amountText);
    _categoryController = TextEditingController(text: categoryText);
    _commentsController = TextEditingController(text: commentsText);

// Store original values for comparison
    _originalMerchant = merchantText;
    _originalDate = dateText;
    _originalAmount = amountText;
    _originalCategory = categoryText;
    _originalComments = commentsText;

// Initialize tags from receipt data
    final tagsString = widget.receipt['tags']?.toString() ?? '';
    if (tagsString.isNotEmpty) {
      _tags = tagsString.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
      if (_tags.length > _maxTags) {
        _tags = _tags.take(_maxTags).toList();
      }
    }

    _tagsController = TextEditingController(text: _tags.join(', '));
    _originalTags = _tags.join(', ');

// Add listeners to track changes
    _merchantController.addListener(_onFieldChanged);
    _dateController.addListener(_onFieldChanged);
    _amountController.addListener(_onFieldChanged);
    _categoryController.addListener(_onFieldChanged);
    _commentsController.addListener(_onFieldChanged);

// For manual receipts, start in editing mode for all fields
    if (_isManualReceipt && _isNewReceipt) {
      _editingMerchant = true;
      _editingDate = true;
      _editingAmount = true;
      _editingCategory = true;
      _editingTags = true;
      _editingComments = true;
    }

// Load categories from API
    _loadCategories();

// Load existing reminder and split data
    if (!_isNewReceipt) {
      _loadReminderSettings();
      _loadSplitData();
    }

    // Show currency conversion dialog if needed
    if (_needsCurrencyConversion && _isNewReceipt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performCurrencyConversion();
      });
    }

    // Load line items if present on receipt
    final items = widget.receipt['lineItems'];
    if (items is List) {
      _lineItems = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  }

  // Method to perform currency conversion using ExchangeRate-API
  Future<void> _performCurrencyConversion() async {
    if (_isLoadingConversion || _conversionResult != null) return;

    setState(() {
      _isLoadingConversion = true;
    });

    try {
      // Use userCurrency from API response to ensure consistency
      final userCurrency = widget.receipt['userCurrency'] ?? 'INR';
      final originalAmount = double.tryParse(widget.receipt['amount']?.toString() ?? '0') ?? 0.0;
      final originalCurrency = _originalCurrency ?? 'USD';

      debugPrint('Currency conversion: $originalAmount $originalCurrency -> $userCurrency');

      if (originalAmount > 0) {
        final result = await CurrencyConversionService.convertCurrency(
          amount: originalAmount,
          fromCurrency: originalCurrency,
          toCurrency: userCurrency,
        );

        setState(() {
          _conversionResult = result;
          _isLoadingConversion = false;
        });

        // Show the conversion dialog with real data
        _showCurrencyConversionDialog();
      } else {
        setState(() {
          _isLoadingConversion = false;
        });
      }
    } catch (e) {
      debugPrint('Currency conversion error: $e');
      setState(() {
        _isLoadingConversion = false;
      });

      // Show error message and allow user to continue without conversion
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Currency conversion failed. You can continue with original amount.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Method to show currency conversion dialog with real conversion data
  void _showCurrencyConversionDialog() {
    if (_conversionResult == null) return;

    // Use currency symbols from the conversion result to ensure consistency
    final userCurrencySymbol = CurrencyHelperService.getCurrencySymbol(_conversionResult!.toCurrency);
    final originalCurrencySymbol = CurrencyHelperService.getCurrencySymbol(_conversionResult!.fromCurrency);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(20),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Warning icon
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFF7E5EFD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.currency_exchange,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Currency Conversion Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Receipt is in ${CurrencyHelperService.getCurrencyName(_conversionResult!.fromCurrency)}, but your account uses ${CurrencyHelperService.getCurrencyName(_conversionResult!.toCurrency)}. Convert to your local currency?',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),

              // Amount details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Original:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '$originalCurrencySymbol${_conversionResult!.formattedOriginalAmount}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Converted:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '$userCurrencySymbol${_conversionResult!.formattedConvertedAmount}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7E5EFD),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (_conversionResult!.isApproximate)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          '* Approximate rate (offline)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        
                        // Clean up shared file if it exists (for new receipts from share)
                        if (_isNewReceipt && widget.sharedFilePath != null) {
                          try {
                            const MethodChannel channel = MethodChannel('share_intent');
                            await channel.invokeMethod('cleanupSharedFile', widget.sharedFilePath);
                            debugPrint('ShareIntent: Cleaned up shared file on currency conversion cancel');

                            // Remember this path as discarded to avoid re-processing
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('lastDiscardedSharedPath', widget.sharedFilePath!);
                            await prefs.setInt('lastDiscardedAtMs', DateTime.now().millisecondsSinceEpoch);
                          } catch (e) {
                            debugPrint('ShareIntent: Failed to cleanup shared file: $e');
                          }
                        }
                        
                        Navigator.of(context).pop(false); // Return to previous screen
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF7E5EFD)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF7E5EFD),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _acceptCurrencyConversion();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Proceed',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method to handle currency conversion acceptance
  void _acceptCurrencyConversion() {
    if (_conversionResult == null) return;

    setState(() {
      _hasAcceptedConversion = true;
      _amountController.text = _conversionResult!.formattedConvertedAmount;
      _originalAmount = _conversionResult!.formattedConvertedAmount; // Update original amount to prevent change detection
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Amount converted to ${CurrencyHelperService.getCurrencyName(_conversionResult!.toCurrency)}',
        ),
        backgroundColor: const Color(0xFF7E5EFD),
      ),
    );
  }

  // Helper methods to get currency names (using the helper service)
  String _getOriginalCurrencyName() {
    return CurrencyHelperService.getCurrencyName(_originalCurrency ?? 'USD');
  }

  String _getUserCurrencyName() {
    // Use userCurrency from API response to ensure consistency
    final userCurrency = widget.receipt['userCurrency'] ?? 'INR';
    return CurrencyHelperService.getCurrencyName(userCurrency);
  }

// Load reminder settings
  Future<void> _loadReminderSettings() async {
    setState(() => _isLoadingReminder = true);

    try {
      final response = await ApiService.get(
        '/reminder?userId=${widget.userId}&receiptId=${widget.receipt['id']}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final reminderData = data['reminder'];

        setState(() {
          _reminderId = reminderData['id']?.toString(); // Store the reminder ID
          _reminderSettings = ReminderSettings(
            isEnabled: reminderData['isEnabled'] ?? false,
            emailReminder: reminderData['emailReminder'] ?? false,
            pushNotification: reminderData['pushReminder'] ?? false,
            reminderMessage: reminderData['message'],
            customReminderDate: reminderData['reminderDate'] != null
                ? DateTime.tryParse(reminderData['reminderDate'])
                : null,
            recurrence: reminderData['recurrence'],
            remindBefore: reminderData['remindBefore'],
            syncToCalendar: reminderData['syncToCalendar'] ?? false,
            billType: reminderData['billType'], // Map billType from API
          );
          _reminderDateString = reminderData['reminderDate'];
        });
        
        debugPrint('📅 Loaded reminder settings: billType=${reminderData['billType']}, recurrence=${reminderData['recurrence']}, remindBefore=${reminderData['remindBefore']}');
      } else if (response.statusCode == 404) {
        setState(() {
          _reminderSettings = null;
          _reminderDateString = null;
          _reminderId = null;
        });
        debugPrint('📅 No reminder found for this receipt');
      } else {
        throw Exception('Failed to load reminder settings: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading reminder settings: $e');
      setState(() {
        _reminderSettings = null;
        _reminderDateString = null;
        _reminderId = null;
      });
    } finally {
      setState(() => _isLoadingReminder = false);
    }
  }

// Load split data
  Future<void> _loadSplitData() async {
    setState(() => _isLoadingSplit = true);
    debugPrint('Attempting to load split data for receipt ID: ${widget.receipt['id']}');

    String? foundSplitBillId;
    try {
      // First, fetch all split bills created by the user
      final responseByYou = await ApiService.get(
        '/split-bill/by-you/${widget.userId}',
      );

      if (responseByYou.statusCode == 200) {
        final List<dynamic> splitBills = json.decode(responseByYou.body)['splitBills'] ?? []; // Access 'splitBills' key
        debugPrint('Fetched user split bills: $splitBills');
        // Find the split bill associated with the current receiptId
        for (var bill in splitBills) {
          if (bill['receiptId'] == widget.receipt['id']) {
            foundSplitBillId = bill['id']?.toString();
            debugPrint('Found splitBillId: $foundSplitBillId for receiptId: ${widget.receipt['id']}');
            break;
          }
        }
      } else if (responseByYou.statusCode == 404) {
        debugPrint('No split bills found for this user (status 404).');
      } else {
        debugPrint('Failed to load user split bills with status: ${responseByYou.statusCode}, body: ${responseByYou.body}');
        throw Exception('Failed to load user split bills: ${responseByYou.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching user split bills: $e');
    }

    if (foundSplitBillId == null || foundSplitBillId.isEmpty) {
      debugPrint('No splitBillId found for receipt ${widget.receipt['id']}. Skipping split data load.');
      setState(() {
        _splitBillData = null;
        _splitParticipants = [];
        _hasExistingSplit = false;
      });
      setState(() => _isLoadingSplit = false);
      return;
    }

    try {
      // Now, use the found splitBillId to get detailed info
      final responseDetails = await ApiService.get(
        '/split-bill/details/$foundSplitBillId',
      );

      if (responseDetails.statusCode == 200) {
        final data = json.decode(responseDetails.body);
        debugPrint('Split Bill Details Data for $foundSplitBillId: $data');
        final List<dynamic> participantsJson = data['participants'] ?? [];
        debugPrint('Participants JSON from details: $participantsJson');

        setState(() {
          _splitBillData = data;
          _splitParticipants = participantsJson
              .map((json) => SplitParticipant.fromJson(json))
              .toList();
          _hasExistingSplit = _splitParticipants.isNotEmpty;
          debugPrint('Parsed Split Participants: $_splitParticipants');
          debugPrint('Has Existing Split: $_hasExistingSplit');
        });
      } else if (responseDetails.statusCode == 404) {
        debugPrint('Split bill details not found for ID: $foundSplitBillId (status 404).');
        setState(() {
          _splitBillData = null;
          _splitParticipants = [];
          _hasExistingSplit = false;
        });
      } else {
        debugPrint('Failed to load split data details with status: ${responseDetails.statusCode}, body: ${responseDetails.body}');
        throw Exception('Failed to load split data: ${responseDetails.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading split data details: $e');
      setState(() {
        _splitBillData = null;
        _splitParticipants = [];
        _hasExistingSplit = false;
      });
    } finally {
      setState(() => _isLoadingSplit = false);
    }
  }

// Save reminder settings
  Future<void> _saveReminderSettings(ReminderSettings settings) async {
    try {
      final effectiveDate = settings.customReminderDate ?? _parseReceiptDate(_dateController.text);
      if (effectiveDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot set reminder without a valid date.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final reminderDateString = DateFormat('yyyy-MM-dd').format(effectiveDate);

      final body = {
        'userId': widget.userId,
        'receiptId': widget.receipt['id'],
        'reminderDate': reminderDateString,
        'billType': settings.billType ?? widget.receipt['category'] ?? 'Other',
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _reminderSettings = settings;
          _reminderDateString = reminderDateString;
          _hasReminderOrSplitChanges = true; // Mark for changes
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(settings.isEnabled
                ? 'Reminder set for $reminderDateString!'
                : 'Reminder disabled'),
            backgroundColor: const Color(0xFF7E5EFD),
          ),
        );
      } else {
        throw Exception('Failed to save reminder: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving reminder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Delete reminder function
  Future<void> _deleteReminder(String userId, String receiptId) async {
    try {
      final response = await ApiService.delete(
        '/reminder',
        body: {
          'userId': userId,
          'receiptId': int.parse(receiptId),
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _reminderSettings = null;
          _reminderDateString = null;
          _reminderId = null; // Clear the reminder ID
          _hasReminderOrSplitChanges = true; // Mark for changes
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder removed successfully!'),
            backgroundColor: Color(0xFF7E5EFD),
          ),
        );
      } else {
        throw Exception('Failed to delete reminder: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting reminder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Save split data
  Future<void> _saveSplitData(List<SplitParticipant> participants) async {
    try {
      final body = {
        'receiptId': widget.receipt['id'],
        'totalAmount': double.tryParse(_amountController.text) ?? 0.0,
        'participants': participants.map((p) => p.toJson()).toList(),
        'createdBy': widget.userId, // Always include createdBy
      };

      http.Response response;
      if (_hasExistingSplit && _splitBillData != null && _splitBillData!['id'] != null) {
        // Update existing split bill
        final splitBillId = _splitBillData!['id'].toString();
        debugPrint('Updating existing split bill with ID: $splitBillId');
        response = await ApiService.put(
          '/split-bill/$splitBillId',
          body: body,
        );
      } else {
        // Create new split bill
        debugPrint('Creating new split bill');
        response = await ApiService.post(
          '/split-bill',
          body: body,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _splitParticipants = participants;
          _hasExistingSplit = participants.isNotEmpty; // If participants become empty, it means split is removed
          _hasReminderOrSplitChanges = true; // Mark for changes
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(participants.isEmpty
                ? 'Split removed'
                : 'Bill split with ${participants.length} participants'),
            backgroundColor: const Color(0xFF7E5EFD),
          ),
        );

        // Reload split data to get the complete information, including the new ID if created
        _loadSplitData();
      } else {
        throw Exception('Failed to save split data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving split: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Delete split bill function
  Future<void> _deleteSplitBill() async {
    try {
      final response = await ApiService.delete(
        '/split-bill/${widget.receipt['id']}',
      );

      if (response.statusCode == 200) {
        setState(() {
          _splitParticipants = [];
          _hasExistingSplit = false;
          _splitBillData = null;
          _hasReminderOrSplitChanges = true; // Mark for changes
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill split removed successfully!'),
            backgroundColor: Color(0xFF7E5EFD),
          ),
        );
      } else {
        throw Exception('Failed to delete split bill: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting split bill: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Show reminder dialog with current information
  void _showReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => ReminderDialog(
        currentSettings: _reminderSettings,
        receiptDate: _dateController.text,
        onSave: _saveReminderSettings,
        onDelete: _deleteReminder,
        userId: widget.userId,
        receiptId: widget.receipt['id'].toString(),
        reminderId: _reminderId, // Pass the reminder ID for editing
      ),
    );
  }

// Show split dialog with current information
  void _showSplitDialog() {
    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount before splitting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => SplitDialog(
        totalAmount: totalAmount,
        existingParticipants: _splitParticipants,
        onSave: _saveSplitData,
        onClearSplit: _deleteSplitBill,
        currencySymbol: userProvider.effectiveCurrencySymbol, // Corrected line
        defaultEmail: userProvider.effectiveEmail, // Ensure email is passed for SSO too
        userId: userProvider.userId, // Add userId for contact fetching
        token: userProvider.token, // Add token for API calls
      ),
    );
  }

// Show receipt details dialog
  void _showReceiptDetails() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currencySymbol = userProvider.effectiveCurrencySymbol;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Receipt Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Merchant', _merchantController.text.isNotEmpty ? _merchantController.text : 'Not specified'),
              _buildDetailRow('Date', _dateController.text.isNotEmpty ? _dateController.text : 'Not specified'),
              _buildDetailRow('Amount', _amountController.text.isNotEmpty ? '$currencySymbol ${_amountController.text}' : 'Not specified'),
              _buildDetailRow('Category', _categoryController.text.isNotEmpty ? _categoryController.text : 'Not specified'),
              _buildDetailRow('Tags', _tags.isNotEmpty ? _tags.join(', ') : 'None'),
              _buildDetailRow('Comments', _commentsController.text.isNotEmpty ? _commentsController.text : 'None'),
              
              // Show reminder info if exists
              if (_reminderSettings?.isEnabled == true) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF7E5EFD).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reminder Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7E5EFD),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow('Reminder Date', _reminderDateString != null ? _formatReminderDate(_reminderDateString) : 'Not set'),
                      _buildDetailRow('Email Reminder', _reminderSettings?.emailReminder == true ? 'Enabled' : 'Disabled'),
                      _buildDetailRow('Push Notification', _reminderSettings?.pushNotification == true ? 'Enabled' : 'Disabled'),
                      if (_reminderSettings?.recurrence != null)
                        _buildDetailRow('Recurrence', _reminderSettings!.recurrence!),
                      if (_reminderSettings?.remindBefore != null)
                        _buildDetailRow('Remind Before', _reminderSettings!.remindBefore!),
                    ],
                  ),
                ),
              ],
              
              // Show split info if exists
              if (_splitParticipants.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Split Bill',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow('Total Participants', '${_splitParticipants.length}'),
                      _buildDetailRow('Total Amount', '$currencySymbol ${_amountController.text}'),
                      ..._splitParticipants.map((participant) => 
                        _buildDetailRow(
                          participant.name ?? participant.email ?? 'Unknown',
                          '$currencySymbol ${participant.amount.toStringAsFixed(2)}'
                        )
                      ).toList(),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Color(0xFF7E5EFD),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

// Helper method to build detail rows
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

// Helper method to format reminder date for display
  String _formatReminderDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

// Helper method to get reminder button text
  String _getReminderButtonText() {
    if (_reminderSettings?.isEnabled == true && _reminderDateString != null) {
      return 'Reminder: ${_formatReminderDate(_reminderDateString)}';
    }
    return 'Set Reminder';
  }

// Helper method to get split button text
  String _getSplitButtonText() {
    debugPrint('Checking _splitParticipants. Length: ${_splitParticipants.length}');
    if (_splitParticipants.isNotEmpty) {
      return 'Split (${_splitParticipants.length} people)';
    }
    return 'Split Bill';
  }

// Helper method to show date picker
  Future<void> _showDatePicker() async {
    DateTime? initialDate;
    try {
      if (_dateController.text.isNotEmpty) {
        initialDate = _parseReceiptDate(_dateController.text);
      }
    } catch (e) {
      debugPrint('Error parsing date: $e');
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7E5EFD),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('MM-dd-yyyy').format(picked);
      });
    }
  }

  bool _hasPdfUrl() {
    final pdfUrl = widget.receipt['decryptedPdfUrl'] ?? widget.receipt['pdfUrl']?.toString().trim() ?? '';
    final imageLink = widget.receipt['decryptedImageLink'] ?? widget.receipt['imageLink']?.toString().trim() ?? '';

    return (pdfUrl.isNotEmpty && (pdfUrl.startsWith('http://') || pdfUrl.startsWith('https://'))) ||
        (imageLink.isNotEmpty && (imageLink.startsWith('http://') || imageLink.startsWith('https://')) && imageLink.contains('.pdf'));
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      final currentTags = _tags.join(', ');

      final hasFieldChanges = _merchantController.text != _originalMerchant ||
          _dateController.text != _originalDate ||
          _amountController.text != _originalAmount ||
          _categoryController.text != _originalCategory ||
          _commentsController.text != _originalComments ||
          currentTags != _originalTags;

      if (hasFieldChanges) {
        setState(() {
          _hasChanges = true;
        });
      }
    }
  }

  void _checkForChanges() {
    final currentTags = _tags.join(', ');

    final hasFieldChanges = _merchantController.text != _originalMerchant ||
        _dateController.text != _originalDate ||
        _amountController.text != _originalAmount ||
        _categoryController.text != _originalCategory ||
        _commentsController.text != _originalComments ||
        currentTags != _originalTags;

    if (hasFieldChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasFieldChanges;
      });
    }
  }

  bool _detectManualReceipt() {
    if (_isPdf || _hasPdfUrl()) {
      return false;
    }

    final imageUrl = widget.imageUrl;
    final receiptData = widget.receipt;

    if (receiptData['isManual'] == true) {
      return true;
    }

    if (imageUrl.isEmpty ||
        imageUrl == 'null' ||
        imageUrl.contains('placeholder') ||
        imageUrl.contains('Manual+Receipt') ||
        imageUrl.contains('manual_receipt')) {
      return true;
    }

    final imageLink = receiptData['imageLink'] ?? receiptData['imageUrl'] ?? '';
    if (imageLink.toString().isEmpty ||
        imageLink.toString() == 'null' ||
        imageLink.toString().contains('placeholder') ||
        imageLink.toString().contains('Manual+Receipt') ||
        imageLink.toString().contains('manual_receipt')) {
      return true;
    }

    if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
      return true;
    }

    return false;
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
    _merchantController.dispose();
    _dateController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _commentsController.dispose();
    _tagInputController.dispose();
    _tagInputFocusNode.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
    });

    try {
      final response = await ApiService.get('/receipts/categories?userId=${widget.userId}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['categories'] != null && data['categories'] is List) {
          setState(() {
            _categories = List<String>.from(data['categories']);
            _filteredCategories = List<String>.from(_categories)..sort();
          });
        } else {
          setState(() {
            _categories = [
              'Books',
              'Clothing',
              'Electronics',
              'Groceries',
              'Shopping',
              'Toys'
            ];
            _filteredCategories = List<String>.from(_categories)..sort();
          });
        }
      } else {
        setState(() {
          _categories = [
            'Books',
            'Clothing',
            'Electronics',
            'Groceries',
            'Shopping',
            'Toys'
          ];
          _filteredCategories = List<String>.from(_categories)..sort();
        });
      }
    } catch (e) {
      setState(() {
        _categories = [
          'Books',
          'Clothing',
          'Electronics',
          'Groceries',
          'Shopping',
          'Toys'
        ];
        _filteredCategories = List<String>.from(_categories)..sort();
      });
    } finally {
      setState(() {
        _loadingCategories = false;
      });
    }
  }

  void _updateFilteredCategories(String query) {
    final trimmedQuery = query.trim().toLowerCase();
    List<String> source = List<String>.from(_categories);
    if (trimmedQuery.isEmpty) {
      source.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        _filteredCategories = source;
      });
      return;
    }

    final List<String> matches = source
        .where((c) => c.toLowerCase().contains(trimmedQuery))
        .toList();

    matches.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();
      final aStarts = aLower.startsWith(trimmedQuery);
      final bStarts = bLower.startsWith(trimmedQuery);
      if (aStarts != bStarts) return aStarts ? -1 : 1; // prefix first
      return aLower.compareTo(bLower); // then alphabetical
    });

    setState(() {
      _filteredCategories = matches;
    });
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim();
    if (trimmedTag.isNotEmpty && !_tags.contains(trimmedTag) && _tags.length < _maxTags) {
      setState(() {
        _tags.add(trimmedTag);
        _tagsController.text = _tags.join(', ');
      });
      _checkForChanges();
    } else if (_tags.length >= _maxTags) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $_maxTags tags allowed'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    _tagInputController.clear();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _tagsController.text = _tags.join(', ');
    });
    _checkForChanges();
  }

  void _selectCategory(String category) {
    setState(() {
      _categoryController.text = category;
      _showCategoryDropdown = false;
      _editingCategory = false;
    });
    _checkForChanges();
  }

  String? _formatDate(String date) {
    if (date.isEmpty || date.toLowerCase() == 'no date') return null;

    final formats = [
      DateFormat('MM-dd-yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('dd-MM-yyyy'),
    ];

    for (final format in formats) {
      try {
        final parsedDate = format.parse(date);
        return DateFormat('MM-dd-yyyy').format(parsedDate);
      } catch (_) {
        // Continue to the next format if parsing fails
      }
    }

    return null;
  }

  Future<void> _saveReceiptToBackend() async {
// Validate required fields for manual receipts
    if (_isManualReceipt) {
      if (_merchantController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a merchant name'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_amountController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter an amount'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Category is required for manual receipts
      if (_categoryController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a category'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_dateController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a date'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (_commentsController.text.length > 250) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comments must be less than 250 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final rawDate = _dateController.text.trim();
    final formattedDate = _formatDate(rawDate);

    if (formattedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid date format. Please use MM-dd-yyyy format'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

    // Prepare base receipt data
    final Map<String, dynamic> baseReceiptData;
    
    if (_isManualReceipt) {
      baseReceiptData = {
        'userId': widget.userId,
        'merchant': _merchantController.text.trim(),
        'receiptDate': formattedDate,
        'amount': _amountController.text.trim().replaceAll(RegExp(r'[^\d.]'), ''),
        'category': _categoryController.text.trim(),
        'tags': _tags.join(', '),
        'comments': _commentsController.text.trim(),
        'isManual': true,
      };
    } else {
      baseReceiptData = {
        'userId': widget.userId,
        'merchant': _merchantController.text.trim(),
        'receiptDate': formattedDate,
        'amount': _amountController.text.trim().replaceAll(RegExp(r'[^\d.]'), ''),
        'category': _categoryController.text.trim(),
        'tags': _tags.join(', '),
        'comments': _commentsController.text.trim(),
        'isManual': false,
      };

      if (_isPdf || _hasPdfUrl()) {
        baseReceiptData['pdfUrl'] = _currentPdfUrl;
        baseReceiptData['imageId'] = widget.imageId;
      } else {
        baseReceiptData['imageUrl'] = widget.imageUrl;
        baseReceiptData['imageId'] = widget.imageId;
      }
    }
    
    // Use helper service to build final payload with currency conversion metadata
    final receiptData = CurrencyHelperService.buildSaveReceiptPayload(
      baseReceiptData: baseReceiptData,
      conversionResult: _conversionResult,
      hasAcceptedConversion: _hasAcceptedConversion,
    );

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Debug logging for receipt data
      debugPrint('Saving receipt with data: ${json.encode(receiptData)}');

      if (_isNewReceipt) {
        // Check if this is from OCR processing with line items
        final hasLineItems = _lineItems.isNotEmpty || 
                            (widget.receipt['lineItems'] != null && 
                             (widget.receipt['lineItems'] as List).isNotEmpty) ||
                            widget.receipt['_lineItemsPromise'] != null;
        
        if (hasLineItems && !_isManualReceipt) {
          // Use ShareIntentApiService for OCR receipts with line items
          debugPrint('🔍 Using ShareIntentApiService for OCR receipt with line items');
          
          // Create ReceiptDetails object from current data
          final receiptDetails = ReceiptDetails(
            userId: widget.userId,
            merchant: _merchantController.text.trim(),
            amount: _amountController.text.trim().replaceAll(RegExp(r'[^\d.]'), ''),
            receiptDate: formattedDate,
            category: _categoryController.text.trim(),
            imageId: widget.imageId,
            imageUrl: _isPdf || _hasPdfUrl() ? null : widget.imageUrl,
            pdfUrl: _isPdf || _hasPdfUrl() ? _currentPdfUrl : null,
            tags: _tags.join(', '),
            comments: _commentsController.text.trim(),
            ocrCurrency: widget.receipt['ocrCurrency'],
            userCurrency: widget.receipt['userCurrency'],
            needsCurrencyConversion: widget.receipt['needsCurrencyConversion'] ?? false,
            lineItems: _lineItems.isNotEmpty ? _lineItems.map((item) => LineItem(
              page: item['page'] ?? 1,
              merchant: item['merchant'],
              category: item['category'],
              description: item['description'],
              amount: item['amount']?.toString() ?? '0',
            )).toList() : null,
            lineItemsStatus: widget.receipt['lineItemsStatus'],
            lineItemsPromise: widget.receipt['_lineItemsPromise'], // ⚠️ CRITICAL: Preserve this!
          );
          
          final response = await ShareIntentApiService.saveReceipt(
            receiptDetails: receiptDetails,
            tags: _tags.join(', '),
            comments: _commentsController.text.trim(),
            token: userProvider.token,
          );
          
          if (response.success) {
            final successMsg = _isPdf ? 'PDF receipt saved!' : 'Receipt saved!';
            
            setState(() {
              _isNewReceipt = false;
              _isSaving = false;
              _hasChanges = false;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(successMsg),
                  backgroundColor: const Color(0xFF7E5EFD),
                ),
              );

              Navigator.pop(context, true); // Return true on successful save
            }
          } else {
            throw Exception(response.message);
          }
        } else {
          // Use regular ApiService for manual receipts or receipts without line items
          debugPrint('🔍 Using regular ApiService for manual receipt or receipt without line items');
          
          final response = await ApiService.post(
            '/receipts/${widget.userId}',
            body: receiptData,
            token: userProvider.token,
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            final successMsg = _isManualReceipt ? 'Manual receipt saved!' :
            _isPdf ? 'PDF receipt saved!' : 'Receipt saved!';

            setState(() {
              _isNewReceipt = false;
              _isSaving = false;
              _hasChanges = false;
              if (_isManualReceipt) {
                _editingMerchant = false;
                _editingDate = false;
                _editingAmount = false;
                _editingCategory = false;
                _editingTags = false;
                _editingComments = false;
              }
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(successMsg),
                  backgroundColor: const Color(0xFF7E5EFD),
                ),
              );

              Navigator.pop(context, true); // Return true on successful save
            }
          } else {
            throw Exception('Failed to save receipt: ${response.statusCode}');
          }
        }
      } else {
        final response = await ApiService.put(
          '/receipts/update',
          body: {
            'id': widget.receipt['id'],
            ...receiptData,
          },
          token: userProvider.token,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          setState(() {
            _isSaving = false;
            _hasChanges = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Receipt updated!'),
                backgroundColor: Color(0xFF7E5EFD),
              ),
            );

            Navigator.pop(context, true); // Return true on successful update
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error while updating receipt'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isSaving = false;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while saving the receipt'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _deleteReceipt(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Receipt'),
          content: const Text(
            'Are you sure you want to delete this receipt? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                if (!mounted) return;

                setState(() {
                  _isDeleting = true;
                });

                try {
                  final receiptId = widget.receipt['id']?.toString() ?? '';

                  final response = await ApiService.delete('/receipts/$receiptId');

                  if (response.statusCode == 200) {
                    if (mounted) {
                      Navigator.of(context, rootNavigator: true).pop(true);
                    }
                  } else {
                    if (mounted) {
                      setState(() {
                        _isDeleting = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Error deleting receipt: ${response.statusCode}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      _isDeleting = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _openZoom(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullImageViewScreen(imageUrl: widget.imageUrl),
      ),
    );
  }

  void _openPdfViewer(BuildContext context) {
    final url = _currentPdfUrl;
    if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid PDF URL')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(pdfUrl: url),
      ),
    );
  }

  String get _currentPdfUrl {
    final pdfUrl = widget.receipt['pdfUrl']?.toString().trim() ?? '';
    if (pdfUrl.isNotEmpty && (pdfUrl.startsWith('http://') || pdfUrl.startsWith('https://'))) {
      return pdfUrl;
    }

    final imageLink = widget.receipt['decryptedImageLink'] ?? widget.receipt['imageLink']?.toString().trim() ?? '';
    if (imageLink.isNotEmpty && (imageLink.startsWith('http://') || imageLink.startsWith('https://')) && imageLink.contains('.pdf')) {
      return imageLink;
    }

    final imageUrl = widget.imageUrl.trim();
    if (imageUrl.isNotEmpty && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) && imageUrl.contains('.pdf')) {
      return imageUrl;
    }

    return '';
  }

  Future<bool> _checkPdfUrl(String url) async {
    try {
      if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
        return false;
      }

      return url.contains('.pdf') || url.contains('cloudinary.com');
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isNewReceipt) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(_isManualReceipt
                  ? 'Discard Manual Receipt?'
                  : _isPdf ? 'Discard PDF Receipt?' : 'Discard Receipt?'),
              content: Text(
                _isManualReceipt
                    ? 'This manual receipt has not been saved. Are you sure you want to discard it?'
                    : _isPdf ? 'This PDF receipt has not been saved. Are you sure you want to discard it?'
                    : 'This receipt has not been saved. Are you sure you want to discard it?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );

          if (shouldDiscard == true) {
            // Clean up shared file if it exists
            if (widget.sharedFilePath != null) {
              try {
                const MethodChannel channel = MethodChannel('share_intent');
                await channel.invokeMethod('cleanupSharedFile', widget.sharedFilePath);
                debugPrint('ShareIntent: Cleaned up shared file on discard');

                // Remember this path as discarded to prevent re-processing
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('lastDiscardedSharedPath', widget.sharedFilePath!);
                await prefs.setInt('lastDiscardedAtMs', DateTime.now().millisecondsSinceEpoch);
              } catch (e) {
                debugPrint('ShareIntent: Failed to cleanup shared file: $e');
              }
            }
            
            // Navigate to Dashboard explicitly on discard
            Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
            return false;
          }
          return false;
        }

        // Return true if any changes (receipt fields or reminder/split) were made
        Navigator.pop(context, _hasChanges || _hasReminderOrSplitChanges);
        return false;
      },
      child: Scaffold(
        body: _isDeleting
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF7E5EFD)),
              SizedBox(height: 16),
              Text(
                'Deleting receipt...',
                style: TextStyle(
                  color: Color(0xFF7E5EFD),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        )
            : _buildMainView(),
      ),
    );
  }

  Widget _buildMainView() {
    final userProvider = Provider.of<UserProvider>(context);
    final currencySymbol = userProvider.effectiveCurrencySymbol;

    return Column(
      children: [
        // Purple header
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
                  if (_isNewReceipt) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(_isManualReceipt
                            ? 'Discard Manual Receipt?'
                            : _isPdf ? 'Discard PDF Receipt?' : 'Discard Receipt?'),
                        content: Text(
                          _isManualReceipt
                              ? 'This manual receipt has not been saved. Are you sure you want to discard it?'
                              : _isPdf ? 'This PDF receipt has not been saved. Are you sure you want to discard it?'
                              : 'This receipt has not been saved. Are you sure you want to discard it?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              
                              // Clean up shared file if it exists
                              if (widget.sharedFilePath != null) {
                                try {
                                  const MethodChannel channel = MethodChannel('share_intent');
                                  await channel.invokeMethod('cleanupSharedFile', widget.sharedFilePath);
                                  debugPrint('ShareIntent: Cleaned up shared file on discard');

                                  // Remember this path as discarded
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('lastDiscardedSharedPath', widget.sharedFilePath!);
                                  await prefs.setInt('lastDiscardedAtMs', DateTime.now().millisecondsSinceEpoch);
                                } catch (e) {
                                  debugPrint('ShareIntent: Failed to cleanup shared file: $e');
                                }
                              }
                              
                              // Navigate to Dashboard explicitly on discard
                              Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
                            },
                            child: const Text('Discard',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Return true if any changes (receipt fields or reminder/split) were made
                    Navigator.pop(context, _hasChanges || _hasReminderOrSplitChanges);
                  }
                },
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Receipt Details',
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

        // Content area
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Image/PDF/Manual display section
                if (_isManualReceipt) ...[
                  Container(
                    width: double.infinity,
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                    ),
                    child: Image.asset(
                      'assets/manual.png',
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 300,
                          color: const Color(0xFFE8E6FF),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_note,
                                  size: 80,
                                  color: Color(0xFF7E5EFD),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Manual Receipt',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7E5EFD),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ] else if (_isPdf || _hasPdfUrl()) ...[
                  // PDF preview section
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _openPdfViewer(context),
                        child: Container(
                          width: double.infinity,
                          height: 300,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf,
                                  size: 80,
                                  color: Colors.red[400],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'PDF Document',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap to view full PDF',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.open_in_new,
                              color: Colors.white,
                            ),
                            onPressed: () => _openPdfViewer(context),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PDF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Regular image receipt
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _openZoom(context),
                        child: Image.network(
                          widget.imageUrl,
                          width: double.infinity,
                          height: 300,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 300,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(Icons.broken_image,
                                      size: 50, color: Colors.grey),
                                ),
                              ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.zoom_out_map,
                                color: Colors.white),
                            onPressed: () => _openZoom(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Receipt details section
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        _isManualReceipt
                            ? 'Enter your receipt details manually.'
                            : _isPdf || _hasPdfUrl()
                            ? 'PDF receipt information extracted and organized.'
                            : 'All receipt information in one organized view.',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Reminder and Split buttons - only show for saved receipts
                      if (!_isNewReceipt) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _showReminderDialog,
                                icon: Icon(
                                  _reminderSettings?.isEnabled == true
                                      ? Icons.notifications_active
                                      : Icons.notifications_none,
                                  size: 20,
                                ),
                                label: Text(
                                  _getReminderButtonText(),
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _reminderSettings?.isEnabled == true
                                      ? Colors.green
                                      : const Color(0xFF7E5EFD),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _showSplitDialog,
                                icon: Icon(
                                  _splitParticipants.isNotEmpty
                                      ? Icons.group
                                      : Icons.call_split,
                                  size: 20,
                                ),
                                label: Text(
                                  _getSplitButtonText(),
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _splitParticipants.isNotEmpty
                                      ? Colors.orange
                                      : const Color(0xFF7E5EFD),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Editable fields container
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E6FF),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // All the existing editable fields...
                            _buildEditableField(
                              'Merchant',
                              _merchantController,
                              _editingMerchant,
                                  () => setState(
                                      () => _editingMerchant = !_editingMerchant),
                              isRequired: _isManualReceipt,
                            ),

                            _buildEditableField(
                              'Date (MM-DD-YYYY)',
                              _dateController,
                              _editingDate,
                                  () => setState(
                                      () => _editingDate = !_editingDate),
                              isRequired: _isManualReceipt,
                              valueTrailing: GestureDetector(
                                onTap: _showDatePicker,
                                child: const Icon(
                                  Icons.calendar_today,
                                  color: Color(0xFF7E5EFD),
                                  size: 20,
                                ),
                              ),
                            ),

                            _buildEditableField(
                              'Amount',
                              _amountController,
                              _editingAmount,
                                  () => setState(
                                      () => _editingAmount = !_editingAmount),
                              prefix:
                              _editingAmount ? '$currencySymbol ' : null,
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                              formatText: (text) => '$currencySymbol $text',
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                              ],
                              isRequired: _isManualReceipt,
                              valueTrailing: _lineItems.isNotEmpty && !_editingAmount
                                  ? GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        FocusScope.of(context).unfocus();
                                        if (_editingAmount) {
                                          setState(() => _editingAmount = false);
                                        }
                                        _showLineItemsDialog();
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Receipt Details',
                                            style: TextStyle(
                                              color: Color(0xFF7E5EFD),
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            height: 1,
                                            width: 35,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF7E5EFD),
                                              borderRadius: BorderRadius.circular(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : null,
                            ),

                            _buildCategoryFieldWithDropdown(),
                            _buildTagsField(),

                            _buildEditableField(
                              'Comments',
                              _commentsController,
                              _editingComments,
                                  () => setState(
                                      () => _editingComments = !_editingComments),
                              hintText: 'Enter your comments here (max 250 characters)',
                              maxLines: 3,
                              maxLength: 250,
                              isRequired: false,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // View Details button removed per requirements

                      // Update Receipt button (only for existing receipts)
                      if (!_isNewReceipt) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveReceiptToBackend,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7E5EFD),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSaving
                                ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Updating...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                                : const Text(
                              'Update Receipt',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Save and Discard buttons (only for new receipts)
                      if (_isNewReceipt) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveReceiptToBackend,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7E5EFD),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSaving
                                ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Saving...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                                : const Text(
                              'Save Receipt',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Delete button (only for existing receipts)
                      if (!_isNewReceipt) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => _deleteReceipt(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Delete Receipt',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

// Keep all existing helper methods for building editable fields, category dropdown, tags field, etc.
  Widget _buildEditableField(
      String label,
      TextEditingController controller,
      bool isEditing,
      VoidCallback onToggleEdit, {
        String? prefix,
        TextInputType? keyboardType,
        String Function(String)? formatText,
        List<TextInputFormatter>? inputFormatters,
        bool isRequired = false,
        String? hintText,
        int? maxLines = 1,
        int? maxLength,
        Widget? trailing,
        Widget? valueTrailing,
        Widget? prefixIcon,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            const Spacer(),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: () {
            if (!isEditing) {
              onToggleEdit();
            }
          },
          child: Container(
            width: double.infinity,
            child: isEditing
                ? Row(
                    children: [
                      if (prefixIcon != null) ...[
                        prefixIcon,
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: keyboardType,
                          inputFormatters: inputFormatters,
                          maxLines: maxLines,
                          maxLength: maxLength,
                          decoration: InputDecoration(
                            hintText: hintText,
                            prefixText: prefix,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            counterText: maxLength != null ? '${controller.text.length}/$maxLength' : null,
                            filled: false,
                          ),
                          style: const TextStyle(fontSize: 16),
                          onChanged: maxLength != null ? (value) {
                            setState(() {});
                          } : null,
                          onSubmitted: (value) {
                            onToggleEdit();
                          },
                          autofocus: true,
                        ),
                      ),
                      if (valueTrailing != null) ...[
                        const SizedBox(width: 8),
                        valueTrailing!,
                      ],
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.transparent),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        if (prefixIcon != null) ...[
                          prefixIcon,
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            controller.text.isEmpty
                                ? (hintText ?? 'Tap to edit')
                                : (formatText != null ? formatText(controller.text) : controller.text),
                            style: TextStyle(
                              fontSize: 16,
                              color: controller.text.isEmpty ? Colors.grey.shade500 : Colors.black,
                              fontStyle: controller.text.isEmpty ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                        ),
                        if (valueTrailing != null) ...[
                          const SizedBox(width: 8),
                          valueTrailing!,
                        ],
                      ],
                    ),
                  ),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showLineItemsDialog() {
    if (_lineItems.isEmpty) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    // Prefer currency symbol from line items amount string (e.g., "$6.00")
    String currencySymbol = (() {
      try {
        final firstAmount = _lineItems.first['amount']?.toString() ?? '';
        // Extract first non-digit, non-dot, non-comma character(s) as symbol
        final match = RegExp(r"^[^0-9\-.,]+").firstMatch(firstAmount.trim());
        final symbol = match?.group(0)?.trim();
        if (symbol != null && symbol.isNotEmpty) {
          return symbol;
        }
      } catch (_) {}
      return userProvider.effectiveCurrencySymbol;
    })();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 520, 
            minHeight: 200, 
            maxHeight: 600
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF7E5EFD),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                width: double.infinity,
                child: const Text(
                  'Receipt Line Items',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 450),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Only show actual line items from response
                        ...List.generate(_lineItems.length, (index) {
                          final item = _lineItems[index];
                          final title = item['description']?.toString() ?? item['title']?.toString() ?? 'Item';
                          final merchant = item['merchant']?.toString() ?? '';
                          final amt = _parseAmount(item['amount']); // Defaults to 0.0 if null
                          final quantity = item['quantity']?.toString() ?? '1';
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ),
                                  Text('$currencySymbol${amt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              if (merchant.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(merchant, style: TextStyle(color: Colors.grey.shade600)),
                                ),
                              if (index != _lineItems.length - 1) const Divider(),
                            ],
                          );
                        }),
                        const SizedBox(height: 8),
                        const Divider(thickness: 1.5),
                        const SizedBox(height: 4),
                        Builder(builder: (context) {
                          final total = _lineItems.fold<double>(0.0, (sum, e) => sum + _parseAmount(e['amount']));
                          
                          return _summaryRow('Total', '$currencySymbol${total.toStringAsFixed(2)}', isBold: true);
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(color: Color(0xFF7E5EFD), fontWeight: FontWeight.w600)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFieldWithDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (_isManualReceipt)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),

        Stack(
          children: [
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _editingCategory = true;
                          });
                          _categoryFocusNode.requestFocus();
                        },
                        child: _editingCategory
                            ? TextField(
                          controller: _categoryController,
                          focusNode: _categoryFocusNode,
                          decoration: const InputDecoration(
                            hintText: 'Enter or select category',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            filled: false,
                          ),
                          style: const TextStyle(fontSize: 16),
                          onSubmitted: (value) {
                            setState(() {
                              _editingCategory = false;
                              _showCategoryDropdown = false;
                            });
                          },
                          onChanged: (value) {
                            if (!_showCategoryDropdown) {
                              setState(() {
                                _showCategoryDropdown = true;
                              });
                            }
                            _updateFilteredCategories(value);
                          },
                        )
                            : Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.transparent),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _categoryController.text.isEmpty
                                ? 'Tap to enter or select category'
                                : _categoryController.text,
                            style: TextStyle(
                              fontSize: 16,
                              color: _categoryController.text.isEmpty
                                  ? Colors.grey.shade500
                                  : Colors.black,
                              fontStyle: _categoryController.text.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showCategoryDropdown = !_showCategoryDropdown;
                          if (_showCategoryDropdown) {
                            _editingCategory = true;
                            _updateFilteredCategories(_categoryController.text);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          _showCategoryDropdown ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),

                if (_showCategoryDropdown) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _loadingCategories
                        ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                        ),
                      ),
                    )
                        : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _filteredCategories.length,
                      itemBuilder: (context, index) {
                        final category = _filteredCategories[index];
                        final isSelected = _categoryController.text == category;

                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          minVerticalPadding: 0,
                          title: Text(
                            category,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF7E5EFD) : Colors.black,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Color(0xFF7E5EFD), size: 16)
                              : null,
                          onTap: () => _selectCategory(category),
                          selected: isSelected,
                          selectedTileColor: const Color(0xFFE8E6FF),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),

        const Divider(height: 1),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tags',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_tags.length}/$_maxTags)',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: () {
            if (!_editingTags) {
              setState(() => _editingTags = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _tagInputFocusNode.requestFocus();
              });
            }
          },
          child: Container(
            width: double.infinity,
            child: _editingTags
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _tagInputController,
                  focusNode: _tagInputFocusNode,
                  decoration: InputDecoration(
                    hintText: _tags.length >= _maxTags
                        ? 'Maximum $_maxTags tags reached'
                        : 'Type a tag and press Enter',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    filled: false,
                  ),
                  enabled: _tags.length < _maxTags,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty && _tags.length < _maxTags) {
                      _addTag(value.trim());
                      _tagInputFocusNode.requestFocus();
                    }
                  },
                ),
                const SizedBox(height: 8),
                if (_tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _tags.map((tag) {
                      return Chip(
                        label: Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: const Color(0xFF7E5EFD),
                        deleteIcon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                        onDeleted: () => _removeTag(tag),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      final pendingTag = _tagInputController.text.trim();
                      if (pendingTag.isNotEmpty && _tags.length < _maxTags && !_tags.contains(pendingTag)) {
                        _addTag(pendingTag);
                      }
                      _tagInputController.clear();
                      setState(() => _editingTags = false);
                    },
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Color(0xFF7E5EFD),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            )
                : Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.transparent),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _tags.isEmpty
                  ? Text(
                'Tap to add tags',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              )
                  : Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(
                      tag,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: const Color(0xFF7E5EFD),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
      ],
    );
  }
}

DateTime? _parseReceiptDate(String date) {
  if (date.isEmpty || date.toLowerCase() == 'no date') return null;
  final formats = [
    DateFormat('MM-dd-yyyy'),
    DateFormat('yyyy-MM-dd'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('dd-MM-yyyy'),
  ];
  for (final format in formats) {
    try {
      return format.parse(date);
    } catch (_) {
      // Continue trying next format
    }
  }
  return null;
}