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
      _fromDate = widget.initialValue.isNotEmpty
          ? _dateFormat.parse(widget.initialValue)
          : DateTime.now();
    } catch (e) {
      _fromDate = DateTime.now();
    }
    _toDate = _fromDate;
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
                        'Date',
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
                      // From date section
                      const Text(
                        'From',
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
                              const Icon(Icons.keyboard_arrow_down),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // From date calendar
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: _buildCustomCalendar(true),
                      ),

                      // To date section
                      const Text(
                        'To',
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
                              const Icon(Icons.keyboard_arrow_down),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // To date calendar
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: _buildCustomCalendar(false),
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

  // Custom calendar widget that highlights the selected date
  Widget _buildCustomCalendar(bool isFromDate) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF7E5EFD),
          onPrimary: Colors.white,
          onSurface: Colors.black,
        ),
      ),
      child: CalendarDatePicker(
        initialDate: isFromDate ? _fromDate : _toDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
        onDateChanged: (date) {
          setState(() {
            if (isFromDate) {
              _fromDate = date;
              if (_toDate.isBefore(_fromDate)) {
                _toDate = _fromDate;
              }
            } else {
              _toDate = date;
              if (_fromDate.isAfter(_toDate)) {
                _fromDate = _toDate;
              }
            }
          });
        },
        selectableDayPredicate: (DateTime day) {
          // Make all days selectable
          return true;
        },
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
            // Add this to make the selected date visible with a purple background
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
          if (_toDate.isBefore(_fromDate)) {
            _toDate = _fromDate;
          }
        } else {
          _toDate = picked;
          if (_fromDate.isAfter(_toDate)) {
            _fromDate = _toDate;
          }
        }
      });
    }
  }
}