import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';
import 'expense_report_receipt_selection_screen.dart';

class ExpenseReportDetailScreen extends StatefulWidget {
  final String reportId;
  final String userId;
  final String token;

  const ExpenseReportDetailScreen({
    Key? key,
    required this.reportId,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<ExpenseReportDetailScreen> createState() => _ExpenseReportDetailScreenState();
}

class _ExpenseReportDetailScreenState extends State<ExpenseReportDetailScreen> {
  Map<String, dynamic>? _reportData;
  List<Map<String, dynamic>> _receipts = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isSubmitting = false;
  bool _isExporting = false;
  bool _isUpdatingStatus = false;
  bool _isUpdatingTitle = false;
  bool _isUpdatingDescription = false;

// Controllers for editing title and description
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  bool _isEditingTitle = false;
  bool _isEditingDescription = false;

// Store original values for comparison
  String _originalTitle = '';
  String _originalDescription = '';

// Prevent duplicate API calls
  bool _isSavingTitle = false;
  bool _isSavingDescription = false;

  double _safeParseAmount(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    final str = raw.toString();
    final cleaned = str.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

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

    // Add focus listeners for auto-save
    _titleFocusNode.addListener(_onTitleFocusChange);
    _descriptionFocusNode.addListener(_onDescriptionFocusChange);

    _fetchReportDetails();
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
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

// Focus change listeners for auto-save
  void _onTitleFocusChange() {
    if (!_titleFocusNode.hasFocus && _isEditingTitle && !_isSavingTitle) {
      _saveTitle();
    }
  }

  void _onDescriptionFocusChange() {
    if (!_descriptionFocusNode.hasFocus && _isEditingDescription && !_isSavingDescription) {
      _saveDescription();
    }
  }

  Future<void> _fetchReportDetails() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('Making GET request to: ${dotenv.env['API_BASE_URL']}/api/expense-reports/${widget.reportId}');

      final response = await ApiService.get(
        '/expense-reports/${widget.reportId}',
        token: widget.token,
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Expense Report Detail API Response: ${response.statusCode}');
      debugPrint('Expense Report Detail API Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _reportData = data['report'] ?? data;
          _receipts = List<Map<String, dynamic>>.from(_reportData?['receipts'] ?? []);

          // Initialize controllers and original values
          _originalTitle = _reportData?['title'] ?? '';
          _originalDescription = _reportData?['description'] ?? '';
          _titleController.text = _originalTitle;
          _descriptionController.text = _originalDescription;

          double currentTotalAmount = 0.0;
          for (final receipt in _receipts) {
            currentTotalAmount += (double.tryParse(receipt['amount']?.toString() ?? '0') ?? 0.0);
          }
          debugPrint('Detail Screen - Fetched Report: ${_reportData?['title']}, Receipts Count: ${_receipts.length}, Total Amount: $currentTotalAmount');
        });
      } else {
        debugPrint('Failed to load expense report details: ${response.statusCode}');
        setState(() {
          _reportData = null;
          _receipts = [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching expense report details: $e");
      setState(() {
        _reportData = null;
        _receipts = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

// Auto-save title when focus is lost or enter is pressed - Using POST draft API
  Future<void> _saveTitle() async {
    if (_isSavingTitle || _titleController.text.trim() == _originalTitle || _titleController.text.trim().isEmpty) {
      setState(() {
        _isEditingTitle = false;
        _titleController.text = _originalTitle;
      });
      return;
    }

    _isSavingTitle = true;
    setState(() => _isUpdatingTitle = true);

    try {
      debugPrint('Making POST request to update draft title: ${dotenv.env['API_BASE_URL']}/api/expense-reports/draft/${widget.reportId}');

      // Using POST draft API to update only title and description - no receiptIds to avoid constraint error
      final response = await ApiService.post(
        '/expense-reports/draft/${widget.reportId}',
        body: {
          'title': _titleController.text.trim(),
          'description': _reportData?['description'] ?? '',
          // Removed receiptIds to prevent duplicate constraint error
        },
        token: widget.token,
      );

      debugPrint('Update draft title POST response: ${response.statusCode}');
      debugPrint('Update draft title response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _reportData?['title'] = _titleController.text.trim();
          _originalTitle = _titleController.text.trim();
          _isEditingTitle = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Title updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to update title');
      }
    } catch (e) {
      // Revert to original title on error
      setState(() {
        _titleController.text = _originalTitle;
        _isEditingTitle = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update title: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUpdatingTitle = false);
      _isSavingTitle = false;
    }
  }

// Auto-save description when focus is lost or enter is pressed - Using POST draft API
  Future<void> _saveDescription() async {
    if (_isSavingDescription || _descriptionController.text.trim() == _originalDescription) {
      setState(() {
        _isEditingDescription = false;
      });
      return;
    }

    _isSavingDescription = true;
    setState(() => _isUpdatingDescription = true);

    try {
      debugPrint('Making POST request to update draft description: ${dotenv.env['API_BASE_URL']}/api/expense-reports/draft/${widget.reportId}');

      // Using POST draft API to update only title and description - no receiptIds to avoid constraint error
      final response = await ApiService.post(
        '/expense-reports/draft/${widget.reportId}',
        body: {
          'title': _reportData?['title'] ?? '',
          'description': _descriptionController.text.trim(),
          // Removed receiptIds to prevent duplicate constraint error
        },
        token: widget.token,
      );

      debugPrint('Update draft description POST response: ${response.statusCode}');
      debugPrint('Update draft description response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _reportData?['description'] = _descriptionController.text.trim();
          _originalDescription = _descriptionController.text.trim();
          _isEditingDescription = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Description updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to update description');
      }
    } catch (e) {
      // Revert to original description on error
      setState(() {
        _descriptionController.text = _originalDescription;
        _isEditingDescription = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update description: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUpdatingDescription = false);
      _isSavingDescription = false;
    }
  }

// Update status from submitted to paid - Using PATCH status API
  Future<void> _updateStatusToPaid() async {
    setState(() => _isUpdatingStatus = true);

    try {
      debugPrint('Making PATCH request to update status: ${dotenv.env['API_BASE_URL']}/api/expense-reports/${widget.reportId}/status');

      // Using PATCH status API to update only status
      final response = await ApiService.patch(
        '/expense-reports/${widget.reportId}/status',
        body: {
          'newStatus': 'paid',
        },
        token: widget.token,
      );

      debugPrint('Update status PATCH response: ${response.statusCode}');
      debugPrint('Update status response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _reportData?['status'] = 'paid';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated to Paid'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update status');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUpdatingStatus = false);
    }
  }

// Delete report functionality
  Future<void> _deleteReport() async {
    final title = _reportData?['title'] ?? 'this report';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense Report'),
        content: Text('Are you sure you want to delete "$title"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      final response = await ApiService.delete(
        '/expense-reports/${widget.reportId}',
        token: widget.token,
      );

      debugPrint('Delete response status: ${response.statusCode}');
      debugPrint('Delete response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense report deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        String errorMessage = 'Failed to delete expense report';
        if (response.statusCode == 404) {
          errorMessage = 'Report not found or already deleted';
        } else if (response.statusCode == 403) {
          errorMessage = 'You do not have permission to delete this report';
        }
        throw Exception('$errorMessage (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error deleting expense report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

// Fixed email dialog - matching the working implementation from selection screen
  Future<void> _showEmailDialogAndSubmit() async {
    final List<String> emails = [];
    final TextEditingController emailController = TextEditingController();
    String? dialogError;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Submit Report via Email'),
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
                        textInputAction: TextInputAction.done,
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
                onPressed: () {
                  Navigator.pop(context);
                  _submitReportWithEmail(emails);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit Report'),
              ),
          ],
        ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

// Submit report with email
  Future<void> _submitReportWithEmail(List<String> emails) async {
    if (emails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one email to submit the report'),
          backgroundColor: Colors.red,
        ),
      );
      return; // Stop submission
    }
    setState(() => _isSubmitting = true);

    try {
      final updateResponse = await ApiService.post(
        '/expense-reports/draft/${widget.reportId}',
        body: {
          'title': _reportData?['title'] ?? '',
          'description': _reportData?['description'] ?? '',
          'emailsSentTo': emails,
          'receiptIds': (_reportData?['receipts'] as List?)?.map((r) => r['id'].toString()).toList() ?? [],
        },
        token: widget.token,
      );

      debugPrint('Update draft response: ${updateResponse.statusCode}');

      if (updateResponse.statusCode == 200 || updateResponse.statusCode == 201) {
        final submitResponse = await ApiService.post(
          '/expense-reports/submit/${widget.reportId}',
          body: {},
          token: widget.token,
        );

        debugPrint('Submit response: ${submitResponse.statusCode}');

        if (submitResponse.statusCode == 200 || submitResponse.statusCode == 201) {
          if (emails.isNotEmpty) {
            final emailResponse = await ApiService.post(
              '/expense-reports/${widget.reportId}/email',
              body: {},
              token: widget.token,
            );
            debugPrint('Email response: ${emailResponse.statusCode}');
          }

          if (mounted) {
            final emailMessage = emails.isNotEmpty
                ? ' and sent to ${emails.length} recipient(s)'
                : '';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Expense report submitted successfully$emailMessage!'),
                backgroundColor: Colors.green,
              ),
            );

            _fetchReportDetails();
          }
        } else {
          throw Exception('Failed to submit expense report: ${submitResponse.statusCode}');
        }
      } else {
        throw Exception('Failed to update expense report: ${updateResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('Error submitting expense report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

// Export report functionality
  Future<void> _exportReport() async {
    setState(() => _isExporting = true);

    try {
      final response = await ApiService.get(
        '/expense-reports/${widget.reportId}/export',
        token: widget.token,
      );

      debugPrint('Export response: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report exported successfully in PDF format!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to export expense report: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error exporting expense report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export report: ${e.toString()}'),
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

// Navigate to receipt selection for editing
  void _editReceiptSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseReportReceiptSelectionScreen(
          reportId: widget.reportId,
          userId: widget.userId,
          token: widget.token,
          reportTitle: _reportData?['title'] ?? '',
          reportDescription: _reportData?['description'] ?? '',
          sortBy: 'date',
          exportFormat: 'pdf',
          isEditing: true,
          existingReceiptIds: _receipts.map((r) => r['id'].toString()).toList(),
        ),
      ),
    ).then((result) {
      _fetchReportDetails();
    });
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

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currencySymbol = userProvider.effectiveCurrencySymbol;

    if (_isLoading) {
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
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Expense Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // MR Logo
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
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_reportData == null) {
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
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Expense Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // MR Logo
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
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Report not found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
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

    final status = _reportData!['status'] ?? 'draft';
    final isSubmitted = status == 'submitted';
    final isPaid = status == 'paid';
    final isDraft = status == 'draft';
    final title = _reportData!['title'] ?? 'Untitled Report';
    final description = _reportData!['description'] ?? '';
    final emailsSentTo = (_reportData!['emailsSentTo'] as List?)?.cast<String>() ?? [];

    // Calculate total amount from actual receipts
    double totalAmount = 0.0;
    for (final receipt in _receipts) {
      final amount = double.tryParse(receipt['amount']?.toString() ?? '0') ?? 0.0;
      totalAmount += amount;
    }

    String formattedDate = 'No date';
    try {
      final createdAt = DateTime.parse(_reportData!['createdAt'] ?? _reportData!['created_at'] ?? '');
      formattedDate = DateFormat('MMM d, yyyy').format(createdAt);
    } catch (e) {
      debugPrint('Error parsing date: $e');
    }

    return Scaffold(
      body: Column(
        children: [
          // Purple header with MR logo
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
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Expense Reports', // Changed from title to static string
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
                // Removed PopupMenuButton (three dots) from header as per request
                // MR Logo
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
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Report status and info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPaid ? Colors.blue : (isSubmitted ? Colors.green : Colors.orange),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row with seamless edit functionality
                          Row(
                            children: [
                              Expanded(
                                child: _isEditingTitle && isDraft
                                    ? TextField(
                                  controller: _titleController,
                                  focusNode: _titleFocusNode,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                    filled: false, // Remove white background
                                    fillColor: Colors.transparent,
                                  ),
                                  onSubmitted: (_) => _saveTitle(),
                                  textInputAction: TextInputAction.done,
                                )
                                    : GestureDetector(
                                  onTap: isDraft ? () {
                                    setState(() {
                                      _isEditingTitle = true;
                                    });
                                    // Focus the text field after a short delay
                                    Future.delayed(const Duration(milliseconds: 100), () {
                                      _titleFocusNode.requestFocus();
                                    });
                                  } : null,
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      if (isDraft) ...[
                                        const SizedBox(width: 4),
                                        _isUpdatingTitle
                                            ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF7E5EFD),
                                          ),
                                        )
                                            : const Icon(
                                          Icons.edit,
                                          color: Color(0xFF7E5EFD),
                                          size: 14,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              // Status dropdown for submitted reports
                              if (isSubmitted)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: 'submitted',
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'submitted',
                                          child: Text(
                                            'Submitted',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'paid',
                                          child: Text(
                                            'Mark as Paid',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: _isUpdatingStatus ? null : (value) {
                                        if (value == 'paid') {
                                          _updateStatusToPaid();
                                        }
                                      },
                                      icon: _isUpdatingStatus
                                          ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                          : const Icon(Icons.arrow_drop_down),
                                    ),
                                  ),
                                )
                              else if (isPaid)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Paid',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Draft',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Description row with seamless edit functionality
                          _isEditingDescription && isDraft
                              ? TextField(
                            controller: _descriptionController,
                            focusNode: _descriptionFocusNode,
                            maxLines: null,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              hintText: 'Enter description...',
                              filled: false, // Remove white background
                              fillColor: Colors.transparent,
                            ),
                            onSubmitted: (_) => _saveDescription(),
                            textInputAction: TextInputAction.done,
                          )
                              : GestureDetector(
                            onTap: isDraft ? () {
                              setState(() {
                                _isEditingDescription = true;
                              });
                              // Focus the text field after a short delay
                              Future.delayed(const Duration(milliseconds: 100), () {
                                _descriptionFocusNode.requestFocus();
                              });
                            } : null,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    description.isEmpty ? 'No description' : description,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: description.isEmpty ? Colors.grey.shade500 : Colors.grey.shade700,
                                      fontStyle: description.isEmpty ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                ),
                                if (isDraft) ...[
                                  const SizedBox(width: 4),
                                  _isUpdatingDescription
                                      ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF7E5EFD),
                                    ),
                                  )
                                      : const Icon(
                                    Icons.edit,
                                    color: Color(0xFF7E5EFD),
                                    size: 14,
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Show emails sent to if any
                          if (emailsSentTo.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8E6FF), // Changed to purple theme
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF7E5EFD).withOpacity(0.3)), // Changed to purple theme
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.email,
                                        size: 16,
                                        color: Color(0xFF7E5EFD), // Changed to purple theme
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Sent to: ', // Changed to be on the same line
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF7E5EFD), // Changed to purple theme
                                        ),
                                      ),
                                      Expanded( // Added Expanded to keep emails on one line
                                        child: Text(
                                          emailsSentTo.join(', '), // Joined emails with comma
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF7E5EFD), // Changed to purple theme
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Created: $formattedDate',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Status: ${isPaid ? 'Paid' : (isSubmitted ? 'Submitted' : 'Draft')}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$currencySymbol${totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7E5EFD),
                                    ),
                                  ),
                                  Text(
                                    '${_receipts.length} receipts',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Receipts section with edit button for drafts
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Included Receipts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        // Edit button for draft reports
                        if (isDraft)
                          TextButton.icon(
                            onPressed: _editReceiptSelection,
                            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF7E5EFD)),
                            label: const Text(
                              'Edit',
                              style: TextStyle(
                                color: Color(0xFF7E5EFD),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_receipts.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No receipts included',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _receipts.length,
                        itemBuilder: (context, index) {
                          final receipt = _receipts[index];
                          final merchant = receipt['merchant'] ?? 'Unknown';
                          final amount = receipt['amount']?.toString() ?? '0';
                          final category = receipt['category']?.toString() ?? 'Uncategorized';
                          final isPdf = _isPdfReceipt(receipt);
                          final isManual = _isManualReceipt(receipt);

                          String formattedReceiptDate = 'No date';
                          if (receipt['receiptDate'] != null) {
                            try {
                              final DateTime? date = _parseDate(receipt['receiptDate']);
                              if (date != null) {
                                formattedReceiptDate = DateFormat('MMM d, yyyy').format(date);
                              }
                            } catch (e) {
                              debugPrint('Error parsing receipt date: $e');
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8E6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
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
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
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
                                            // Price Breakup removed from expense report - only shown on receipt detail screen
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formattedReceiptDate,
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
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom action buttons for draft reports
          if (isDraft)
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
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton( // Changed to ElevatedButton for delete
                      onPressed: _isDeleting ? null : _deleteReport, // Call delete function
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, // Red color for delete
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isDeleting
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete, size: 20), // Delete icon
                          SizedBox(width: 4), // Reduced width for better fit
                          Flexible( // Added Flexible to prevent text overflow
                            child: Text(
                              'Delete', // Text changed to Delete Report
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis, // Ensure text truncates
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8), // Reduced width for better fit
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _showEmailDialogAndSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, size: 20),
                          SizedBox(width: 4), // Reduced width for better fit
                          Flexible( // Added Flexible to prevent text overflow
                            child: Text(
                              'Submit Report',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis, // Ensure text truncates
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Bottom action button for submitted/paid reports (Delete button)
          if (isSubmitted || isPaid)
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
                  onPressed: _isDeleting ? null : _deleteReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isDeleting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: TextStyle(
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
    );
  }

  void _showPriceBreakupDialog(BuildContext context, Map<String, dynamic> receipt, String currencySymbol) {
    final lineItems = receipt['lineItems'] as List<dynamic>? ?? [];
    
    if (lineItems.isEmpty) return;

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
                  'Receipt Details',
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
                        ...List.generate(lineItems.length, (index) {
                          final item = lineItems[index];
                          final description = item['description']?.toString() ?? 'Item';
                          final merchant = item['merchant']?.toString() ?? '';
                          final amount = _safeParseAmount(item['amount']); // Defaults to 0.0 if null
                          final quantity = item['quantity']?.toString() ?? '1';
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      description, 
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                                    ),
                                  ),
                                  Text(
                                    '$currencySymbol${amount.toStringAsFixed(2)}', 
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)
                                  ),
                                ],
                              ),
                              if (merchant.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    merchant, 
                                    style: TextStyle(color: Colors.grey.shade600)
                                  ),
                                ),
                              if (index != lineItems.length - 1) const Divider(),
                            ],
                          );
                        }),
                        const SizedBox(height: 8),
                        const Divider(thickness: 1.5),
                        const SizedBox(height: 4),
                        Builder(builder: (context) {
                          final total = lineItems.fold<double>(0.0, (sum, e) => sum + _safeParseAmount(e['amount']));
                          
                          return _buildSummaryRow('Total', '$currencySymbol${total.toStringAsFixed(2)}', isBold: true);
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
                    child: const Text(
                      'Close', 
                      style: TextStyle(color: Color(0xFF7E5EFD), fontWeight: FontWeight.w600)
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? const Color(0xFF7E5EFD) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
