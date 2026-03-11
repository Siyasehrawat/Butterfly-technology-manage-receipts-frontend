import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/reminder_settings.dart';
import '../services/api_service_bypass.dart';
import '../services/calendar_sync_service.dart';
import '../providers/feature_flags_provider.dart';
import 'styled_dropdown.dart';

class ReminderDialog extends StatefulWidget {
  final ReminderSettings? currentSettings;
  final String receiptDate;
  final Function(ReminderSettings) onSave;
  final Function(String userId, String receiptId)? onDelete;
  final String userId;
  final String receiptId;
  final String? reminderId; // NEW: present when editing existing reminder
  final String? merchant; // NEW: receipt merchant for display
  final dynamic amount; // NEW: receipt amount/originalAmount for display
  final String? category; // NEW: receipt category for display

  const ReminderDialog({
    Key? key,
    this.currentSettings,
    required this.receiptDate,
    required this.onSave,
    this.onDelete,
    required this.userId,
    required this.receiptId,
    this.reminderId, // NEW
    this.merchant,
    this.amount,
    this.category,
  }) : super(key: key);

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  bool _isEnabled = false;
  bool _emailReminder = false;
  bool _pushNotification = false;
  bool _useCustomDate = false;
  DateTime? _customReminderDate;
  String? _selectedRecurrence;
  String? _selectedRemindBefore;
  bool _syncToCalendar = false;
  final TextEditingController _messageController = TextEditingController();
  String? _errorMessage; // Inline error shown inside the dialog
  String? _selectedBillType;
  final ScrollController _scrollController = ScrollController();
  bool _hasCalendarConnected = false;
  bool _isCheckingCalendar = true;
  bool _isConnectingCalendar = false; // NEW: indicates OAuth connection in progress
  bool _isSyncingCalendar = false; // NEW: indicates immediate sync/unsync in progress
  bool _isNotesExpanded = false; // NEW: tracks if notes field is expanded

  // Options for dropdowns
  final List<String> _recurrenceOptions = [
    'None',
    'Daily',
    'Weekly',
    'Monthly',
    'Quarterly',
    'Yearly',
  ];

  final List<String> _remindBeforeOptions = [
    'On the day',
    '1 day before',
    '2 days before',
    '3 days before',
    '1 week before',
    '2 weeks before',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.currentSettings != null) {
      _isEnabled = widget.currentSettings!.isEnabled;
      _emailReminder = widget.currentSettings!.emailReminder;
      _pushNotification = widget.currentSettings!.pushNotification;
      _messageController.text = widget.currentSettings!.reminderMessage ?? '';
      _customReminderDate = widget.currentSettings!.customReminderDate;
      _useCustomDate = _customReminderDate != null;
      _selectedRecurrence = widget.currentSettings!.recurrence ?? 'Monthly';
      _selectedRemindBefore = widget.currentSettings!.remindBefore ?? '1 day before';
      _syncToCalendar = widget.currentSettings!.syncToCalendar;
      _selectedBillType = widget.currentSettings!.billType;
    } else {
      _isEnabled = true; // default new reminder to enabled
      _selectedRecurrence = 'Monthly';
      _selectedRemindBefore = '1 day before';
      _selectedBillType = null;
    }
    // Only check calendar connection if the feature is enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
      if (featureFlagsProvider.isCalendarSyncEnabled) {
        _checkCalendarConnection();
      } else {
        setState(() {
          _isCheckingCalendar = false;
        });
      }
    });
  }

  Future<void> _checkCalendarConnection() async {
    try {
      final isConnected = await CalendarSyncService.isCalendarConnected(widget.userId);
      if (mounted) {
        setState(() {
          _hasCalendarConnected = isConnected;
          _isCheckingCalendar = false;
          // Default sync to calendar ON if connected, creating new reminder, and feature is enabled
          final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
          if (widget.currentSettings == null && isConnected && featureFlagsProvider.isCalendarSyncEnabled) {
            _syncToCalendar = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingCalendar = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  DateTime? _parseReceiptDate(String dateString) {
    if (dateString.isEmpty) return null;

    try {
      if (dateString.contains('-')) {
        final parts = dateString.split('-');
        if (parts.length == 3) {
          final part1 = int.tryParse(parts[0]);
          final part2 = int.tryParse(parts[1]);
          final part3 = int.tryParse(parts[2]);
          
          if (part1 != null && part2 != null && part3 != null) {
            // Determine format based on part lengths
            if (part1 > 12) {
              // yyyy-MM-dd format (Bill Reminders API)
              return DateTime(part1, part2, part3);
            } else if (part3 > 12) {
              // MM-dd-yyyy format (Receipts API)
              return DateTime(part3, part1, part2);
            }
          }
        }
      }

      // Try other formats
      return DateTime.tryParse(dateString);
    } catch (e) {
      return null;
    }
  }

  String _formatDisplayDate(DateTime? date) {
    if (date == null) return 'No date set';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  bool _isDateInPast(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final checkDate = DateTime(date.year, date.month, date.day);
    return checkDate.isBefore(today);
  }

  bool _isRecurringReminder() {
    // Check if the reminder is recurring (not "None" or null)
    return _selectedRecurrence != null && _selectedRecurrence != 'None';
  }

  Future<void> _selectCustomDate() async {
    // Allow past dates for recurring reminders
    final firstDate = _isRecurringReminder() 
        ? DateTime.now().subtract(const Duration(days: 365 * 2))
        : DateTime.now();
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _customReminderDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: firstDate,
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
        _customReminderDate = picked;
      });
    }
  }

  DateTime? _getEffectiveReminderDate() {
    if (_useCustomDate && _customReminderDate != null) {
      return _customReminderDate;
    }
    return _parseReceiptDate(widget.receiptDate);
  }

  void _handleSyncToCalendar() async {
    // If not connected, start OAuth flow directly with WebView
    if (!_hasCalendarConnected) {
      setState(() {
        _isConnectingCalendar = true;
      });
      try {
        final connected = await CalendarSyncService.connectCalendar(
          widget.userId,
          context: context,
        );
        if (!mounted) return;
        setState(() {
          _isConnectingCalendar = false;
          _hasCalendarConnected = connected;
          if (connected) {
            _syncToCalendar = true; // auto-enable after connect
          }
        });
        if (connected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calendar connected. ✓ Will sync when you save'),
              backgroundColor: Color(0xFF7E5EFD),
              duration: Duration(milliseconds: 1800),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calendar connection incomplete. Please try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(milliseconds: 1800),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isConnectingCalendar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect calendar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(milliseconds: 2000),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // If this dialog has an existing reminderId, sync/unsync immediately via endpoints
    if (widget.reminderId != null && widget.reminderId!.isNotEmpty) {
      setState(() {
        _isSyncingCalendar = true;
      });
      try {
        bool success;
        if (_syncToCalendar) {
          // Currently synced -> unsync
          success = await CalendarSyncService.unsyncReminderFromCalendar(
            reminderId: widget.reminderId!,
          );
        } else {
          // Currently not synced -> sync
          success = await CalendarSyncService.syncReminderToCalendar(
            reminderId: widget.reminderId!,
            calendarId: 'default',
            calendarType: 'google',
          );
        }

        if (!mounted) return;
        setState(() {
          _isSyncingCalendar = false;
          if (success) {
            _syncToCalendar = !_syncToCalendar;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? (_syncToCalendar
                    ? '✅ Synced to Google Calendar'
                    : 'Removed from Google Calendar')
                : 'Calendar sync failed'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(milliseconds: 1800),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSyncingCalendar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calendar sync failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(milliseconds: 2000),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // No reminderId yet (creating new) -> toggle state; actual sync will happen on Save
    setState(() {
      _syncToCalendar = !_syncToCalendar;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _syncToCalendar
                ? '✓ Will sync to calendar when you save'
                : 'Calendar sync disabled',
          ),
          duration: const Duration(milliseconds: 1800),
          backgroundColor: const Color(0xFF7E5EFD),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final featureFlagsProvider = Provider.of<FeatureFlagsProvider>(context, listen: false);
    final receiptDate = _parseReceiptDate(widget.receiptDate);
    final effectiveDate = _getEffectiveReminderDate();
    final hasValidDate = effectiveDate != null;
    final isDateInPast = hasValidDate && _isDateInPast(effectiveDate);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with purple background
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF7E5EFD),
                borderRadius: BorderRadius.zero,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Set Reminder',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Merchant Name Display (for receipt reminders)
                    if (widget.merchant != null && widget.merchant!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF7E5EFD).withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Merchant Name',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF7E5EFD),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.merchant!,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Enable toggle - simple row, no border/underline
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
                            value: _isEnabled,
                            activeColor: const Color(0xFF7E5EFD),
                            onChanged: (v) {
                              setState(() {
                                _isEnabled = v;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    
                    // Show disabled state when reminder is turned off
                    if (!_isEnabled) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          'Reminder is disabled. Turn on the toggle above to configure settings.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Show all details when reminder is enabled
                    if (_isEnabled) ...[
                    // Date Selection Section - Compact inline layout
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E6FF), // Light purple background
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF7E5EFD).withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Receipt Date and Custom Date in one row
                          Row(
                            children: [
                              // Receipt Date Option
                              Expanded(
                                child: Row(
                                  children: [
                                    Radio<bool>(
                                      value: false,
                                      groupValue: _useCustomDate,
                                      onChanged: receiptDate != null ? (value) {
                                        setState(() {
                                          _useCustomDate = false;
                                        });
                                      } : null,
                                      activeColor: const Color(0xFF7E5EFD),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Receipt Date:',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            receiptDate != null
                                                ? _formatDisplayDate(receiptDate)
                                                : 'No date available',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: (receiptDate != null && _isDateInPast(receiptDate) && !_isRecurringReminder())
                                                  ? Colors.red
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(width: 8),
                              
                              // Custom Date Option
                              Expanded(
                                child: Row(
                                  children: [
                                    Radio<bool>(
                                      value: true,
                                      groupValue: _useCustomDate,
                                      onChanged: (value) {
                                        setState(() {
                                          _useCustomDate = true;
                                        });
                                        if (_customReminderDate == null) {
                                          _selectCustomDate();
                                        }
                                      },
                                      activeColor: const Color(0xFF7E5EFD),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Custom Date:',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            _useCustomDate && _customReminderDate != null
                                                ? _formatDisplayDate(_customReminderDate)
                                                : 'Select a date',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (_useCustomDate) ...[
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _selectCustomDate,
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(
                                  _customReminderDate != null ? 'Change Date' : 'Select Date',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF7E5EFD),
                                  side: const BorderSide(color: Color(0xFF7E5EFD)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Info message for past dates with recurring reminders
                    if (isDateInPast && _isRecurringReminder()) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E6), // Light orange background
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Past date selected with recurring reminder. The next occurrence will be calculated from this date.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Bill Type dropdown (inline with label)
                    Row(
                      children: [
                        RichText(
                          text: const TextSpan(
                            text: 'Bill Type:',
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
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
                                            _selectedBillType ?? 'Select bill type',
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
                                        _selectedBillType = value;
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Recurrence and Remind Before Section
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
                              StyledDropdown<String>(
                                value: _selectedRecurrence,
                                items: _recurrenceOptions,
                                placeholder: 'None',
                                onChanged: (String value) {
                                  setState(() {
                                    _selectedRecurrence = value;
                                  });
                                },
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
                              StyledDropdown<String>(
                                value: _selectedRemindBefore,
                                items: _remindBeforeOptions,
                                placeholder: '1 day before',
                                onChanged: (String value) {
                                  setState(() {
                                    _selectedRemindBefore = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Reminder Methods Section (compact)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E6FF), // Light purple background
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF7E5EFD).withOpacity(0.2)),
                      ),
                      child: Column(
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
                          const SizedBox(height: 6),

                          // Email and Push Notification in one row
                          Row(
                            children: [
                              // Email Reminder Checkbox
                              Expanded(
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _emailReminder,
                                      onChanged: (value) {
                                        setState(() {
                                          _emailReminder = value ?? false;
                                        });
                                      },
                                      activeColor: const Color(0xFF7E5EFD),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const SizedBox(width: 4),
                                    const Expanded(
                                      child: Text(
                                        'Email',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Push Notification Checkbox
                              Expanded(
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _pushNotification,
                                      onChanged: (value) {
                                        setState(() {
                                          _pushNotification = value ?? false;
                                        });
                                      },
                                      activeColor: const Color(0xFF7E5EFD),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const SizedBox(width: 4),
                                    const Expanded(
                                      child: Text(
                                        'Push Notification',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Notes Section (dynamic height)
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
                        if (_messageController.text.isNotEmpty)
                          Text(
                            '${_messageController.text.length}/200',
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
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Add notes about this bill...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          counterText: '',
                        ),
                        maxLines: _isNotesExpanded || _messageController.text.isNotEmpty ? 3 : 1,
                        maxLength: 200,
                        style: const TextStyle(fontSize: 13),
                        onChanged: (value) {
                          setState(() {
                            // Auto-expand if user starts typing
                            if (value.isNotEmpty && !_isNotesExpanded) {
                              _isNotesExpanded = true;
                            }
                          });
                        },
                        onTap: () {
                          // Expand when user taps to focus
                          if (!_isNotesExpanded) {
                            setState(() {
                              _isNotesExpanded = true;
                            });
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Sync to Calendar - only show if feature is enabled
                    if (featureFlagsProvider.isCalendarSyncEnabled && !_isCheckingCalendar)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Tooltip(
                          message: _syncToCalendar
                              ? 'Will sync to Google Calendar when you save'
                              : 'Tap to enable calendar sync',
                          child: InkWell(
                            onTap: _isConnectingCalendar || _isSyncingCalendar ? null : _handleSyncToCalendar,
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
                                  if (_isConnectingCalendar || _isSyncingCalendar)
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(_syncToCalendar ? Colors.white : Color(0xFF7E5EFD)),
                                      ),
                                    )
                                  else
                                    Icon(
                                      _syncToCalendar ? Icons.check_circle : Icons.calendar_today,
                                      size: 18,
                                      color: _syncToCalendar ? Colors.white : const Color(0xFF7E5EFD),
                                    ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isConnectingCalendar
                                        ? 'Connecting...'
                                        : (_isSyncingCalendar
                                            ? (_syncToCalendar ? 'Removing...' : 'Syncing...')
                                            : (_syncToCalendar ? 'Will Sync to Calendar' : 'Sync to Calendar')),
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
                      ),
                    ], // End of _isEnabled conditional block
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.zero,
              ),
              child: Row(
                children: [
                  // Always show Cancel on the left
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
                    onPressed: () {
                      if (!hasValidDate) {
                        setState(() {
                          _errorMessage = 'Please select a valid date first';
                        });
                        _scrollToTop();
                        return;
                      }

                      // Allow past dates for recurring reminders
                      if (isDateInPast && !_isRecurringReminder()) {
                        setState(() {
                          _errorMessage = 'Cannot set reminder for past dates. Use a recurring reminder for past dates.';
                        });
                        _scrollToTop();
                        return;
                      }

                      if (_isEnabled && (!_emailReminder && !_pushNotification)) {
                        setState(() {
                          _errorMessage = 'Please select at least one reminder method';
                        });
                        _scrollToTop();
                        return;
                      }

                      final settings = ReminderSettings(
                        isEnabled: _isEnabled && hasValidDate && (!isDateInPast || _isRecurringReminder()),
                        emailReminder: _emailReminder,
                        pushNotification: _pushNotification,
                        reminderMessage: _messageController.text.trim().isEmpty
                            ? null
                            : _messageController.text.trim(),
                        customReminderDate: _useCustomDate ? _customReminderDate : null,
                        recurrence: _selectedRecurrence,
                        remindBefore: _selectedRemindBefore,
                        syncToCalendar: _syncToCalendar,
                        billType: _selectedBillType,
                      );

                      setState(() {
                        _errorMessage = null;
                      });
                      widget.onSave(settings);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E5EFD),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    ),
                    child: const Text(
                      'Save Bill Reminder',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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