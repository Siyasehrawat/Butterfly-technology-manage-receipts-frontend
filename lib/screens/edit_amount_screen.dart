import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class EditAmountScreen extends StatefulWidget {
  final String initialMinValue;
  final String initialMaxValue;

  const EditAmountScreen({
    super.key,
    this.initialMinValue = '0',
    this.initialMaxValue = '',
  });

  @override
  State<EditAmountScreen> createState() => _EditAmountScreenState();
}

class _EditAmountScreenState extends State<EditAmountScreen> {
  late TextEditingController _minController;
  late TextEditingController _maxController;
  RangeValues _currentRangeValues = const RangeValues(0, 1000);
  final double _minPossibleValue = 0;
  final double _maxPossibleValue = 10000;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(text: widget.initialMinValue);
    _maxController = TextEditingController(text: widget.initialMaxValue);

    // Initialize range slider values
    double minValue = double.tryParse(widget.initialMinValue) ?? _minPossibleValue;
    double maxValue = double.tryParse(widget.initialMaxValue) ?? _maxPossibleValue;

    // Ensure max is not less than min
    if (maxValue < minValue) {
      maxValue = minValue;
    }

    _currentRangeValues = RangeValues(minValue, maxValue);
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _updateRangeFromControllers() {
    double minValue = double.tryParse(_minController.text) ?? _minPossibleValue;
    double maxValue = double.tryParse(_maxController.text) ?? _maxPossibleValue;

    // Ensure max is not less than min
    if (maxValue < minValue) {
      maxValue = minValue;
    }

    setState(() {
      _currentRangeValues = RangeValues(minValue, maxValue);
    });
  }

  void _updateControllersFromRange(RangeValues values) {
    setState(() {
      _minController.text = values.start.toStringAsFixed(2);
      if (values.end >= _maxPossibleValue) {
        _maxController.text = ''; // Leave max empty if it's at the maximum
      } else {
        _maxController.text = values.end.toStringAsFixed(2);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get currency symbol from UserProvider
    final userProvider = Provider.of<UserProvider>(context);
    final currencySymbol = userProvider.effectiveCurrencySymbol;

    return Scaffold(
      body: Column(
        children: [
          // Purple header with back button and logo
          Container(
            color: const Color(0xFF7E5EFD),
            padding: const EdgeInsets.only(top: 40, bottom: 16),
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
                      'Amount Range',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Description text
                  const Text(
                    'Set a range to filter receipts by amount',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Range slider
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amount Range',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      RangeSlider(
                        values: _currentRangeValues,
                        min: _minPossibleValue,
                        max: _maxPossibleValue,
                        divisions: 100,
                        labels: RangeLabels(
                          '$currencySymbol${_currentRangeValues.start.toStringAsFixed(2)}',
                          _currentRangeValues.end >= _maxPossibleValue
                              ? 'Any'
                              : '$currencySymbol${_currentRangeValues.end.toStringAsFixed(2)}',
                        ),
                        onChanged: (RangeValues values) {
                          setState(() {
                            _currentRangeValues = values;
                            _updateControllersFromRange(values);
                          });
                        },
                        activeColor: const Color(0xFF7E5EFD),
                        inactiveColor: const Color(0xFFE8E6FF),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$currencySymbol${_minPossibleValue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '$currencySymbol${_maxPossibleValue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Min and Max amount input fields
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Minimum Amount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _minController,
                              decoration: InputDecoration(
                                hintText: '0.00',
                                prefixText: '$currencySymbol ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: const Color(0xFF7E5EFD).withOpacity(0.5),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: const Color(0xFF7E5EFD).withOpacity(0.5),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF7E5EFD),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              style: const TextStyle(fontSize: 16),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              onChanged: (value) {
                                _updateRangeFromControllers();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Maximum Amount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _maxController,
                              decoration: InputDecoration(
                                hintText: 'Any',
                                prefixText: '$currencySymbol ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: const Color(0xFF7E5EFD).withOpacity(0.5),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: const Color(0xFF7E5EFD).withOpacity(0.5),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF7E5EFD),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              style: const TextStyle(fontSize: 16),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              onChanged: (value) {
                                _updateRangeFromControllers();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // Return both min and max values
                        Navigator.pop(
                          context,
                          {
                            'minAmount': _minController.text,
                            'maxAmount': _maxController.text.isEmpty ? null : _maxController.text,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
