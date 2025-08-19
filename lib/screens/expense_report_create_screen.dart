import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'expense_report_receipt_selection_screen.dart';

class ExpenseReportCreateScreen extends StatefulWidget {
  final String userId;
  final String token;
  // Note: This screen is currently designed for creating new reports only,
  // as per the provided attachment. If editing functionality is needed here,
  // initialReportTitle, initialReportDescription, initialReportId,
  // initialReceiptIds, and isEditing flags would need to be re-added.

  const ExpenseReportCreateScreen({
    Key? key,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<ExpenseReportCreateScreen> createState() => _ExpenseReportCreateScreenState();
}

class _ExpenseReportCreateScreenState extends State<ExpenseReportCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _sortBy = 'date';
  String _exportFormat = 'pdf';
  // Removed _isCreating as its loading state is handled on the next screen.

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
    super.dispose();
  }

  void _navigateToReceiptSelection() {
    if (!_formKey.currentState!.validate()) return;

    final reportTitle = _titleController.text.trim();
    final reportDescription = _descriptionController.text.trim();

    // Changed from Navigator.pushReplacement to Navigator.push
    // This allows ExpenseReportCreateScreen to remain on the stack
    // and listen for a result from ExpenseReportReceiptSelectionScreen.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseReportReceiptSelectionScreen(
          reportId: '', // No reportId yet, it will be created on the next screen
          userId: widget.userId,
          token: widget.token,
          reportTitle: reportTitle,
          reportDescription: reportDescription,
          sortBy: _sortBy,
          exportFormat: _exportFormat,
          isEditing: false, // This is a new report, not an edit
          existingReceiptIds: const [],
        ),
      ),
    ).then((result) {
      // If the receipt selection screen indicates a change (e.g., by popping with true),
      // then this screen should also pop with true to signal the ExpenseReportsScreen to refresh.
      if (result == true) {
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Create Expense Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Balance the back button
              ],
            ),
          ),

          // Form content
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title field
                      const Text(
                        'Report Title',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        maxLength: 50,
                        decoration: InputDecoration(
                          hintText: 'Enter report title',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF7E5EFD)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a report title';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Description field
                      const Text(
                        'Description (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLength: 200,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter report description',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF7E5EFD)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sort by section
                      const Text(
                        'Sort By',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              title: const Text('Date'),
                              value: 'date',
                              groupValue: _sortBy,
                              activeColor: const Color(0xFF7E5EFD),
                              onChanged: (value) {
                                setState(() {
                                  _sortBy = value!;
                                });
                              },
                            ),
                            const Divider(height: 1),
                            RadioListTile<String>(
                              title: const Text('Category'),
                              value: 'category',
                              groupValue: _sortBy,
                              activeColor: const Color(0xFF7E5EFD),
                              onChanged: (value) {
                                setState(() {
                                  _sortBy = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Export format section
                      const Text(
                        'Export Format',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              title: const Text('PDF'),
                              value: 'pdf',
                              groupValue: _exportFormat,
                              activeColor: const Color(0xFF7E5EFD),
                              onChanged: (value) {
                                setState(() {
                                  _exportFormat = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Continue button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _navigateToReceiptSelection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E5EFD),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Select Receipts',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}