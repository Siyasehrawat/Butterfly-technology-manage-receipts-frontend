import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EditDateScreen extends StatefulWidget {
  final String initialValue;

  const EditDateScreen({
    super.key,
    required this.initialValue,
  });

  @override
  State<EditDateScreen> createState() => _EditDateScreenState();
}

class _EditDateScreenState extends State<EditDateScreen> {
  late DateTime _fromDate;
  late DateTime _toDate;
  final DateFormat _dateFormat = DateFormat('MMMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    try {
      // Attempt to parse initialValue as a date range if it contains " - "
      if (widget.initialValue.contains(' - ')) {
        final parts = widget.initialValue.split(' - ');
        _fromDate = _dateFormat.parse(parts[0]);
        _toDate = _dateFormat.parse(parts[1]);
      } else if (widget.initialValue.isNotEmpty) {
        // If it's a single date, use it for both from and to
        _fromDate = _dateFormat.parse(widget.initialValue);
        _toDate = _fromDate;
      } else {
        // Default to today if no initial value
        _fromDate = DateTime.now();
        _toDate = DateTime.now();
      }
    } catch (e) {
      // Fallback to today if parsing fails
      _fromDate = DateTime.now();
      _toDate = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: true, // Ensure bottom padding for system navigation bar
        child: Column(
          children: [
            // Purple header with back button and logo
            Container(
              color: const Color(0xFF7E5EFD),
              padding: const EdgeInsets.only(top: 8, bottom: 16),
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
                        'Date Range', // Changed title to Date Range
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

            // White content area
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      // From date section
                      const Text(
                        'From Date', // Changed label
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dateFormat.format(_fromDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Icon(Icons.calendar_today), // Changed icon to calendar
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32), // Increased spacing

                      // To date section
                      const Text(
                        'To Date', // Changed label
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dateFormat.format(_toDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Icon(Icons.calendar_today), // Changed icon to calendar
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32), // Increased spacing

                      // Display selected range (optional, for visual feedback)
                      Center(
                        child: Text(
                          'Selected Range: ${_dateFormat.format(_fromDate)} - ${_dateFormat.format(_toDate)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF7E5EFD),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            // Return both from and to dates as a map
                            Navigator.pop(
                              context,
                              {
                                'fromDate': _fromDate.toIso8601String(),
                                'toDate': _toDate.toIso8601String(),
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E5EFD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      // Add bottom padding to ensure content isn't covered by system navigation
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7E5EFD),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7E5EFD),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          // Ensure toDate is not before fromDate
          if (_toDate.isBefore(_fromDate)) {
            _toDate = _fromDate;
          }
        } else {
          _toDate = picked;
          // Ensure fromDate is not after toDate
          if (_fromDate.isAfter(_toDate)) {
            _fromDate = _toDate;
          }
        }
      });
    }
  }
}