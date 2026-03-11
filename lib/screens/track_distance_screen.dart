import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service_bypass.dart';
import '../providers/user_provider.dart';
// Reuse styled dropdown from Tax Calculator so year selector matches design.
import 'tax_calculator_screen.dart' show TaxCalculatorDropdown;

import 'receipt_details_screen.dart';

/// Helper widget to add a Done button toolbar above numeric keyboards on iOS
class _KeyboardDoneButton extends StatelessWidget {
  final Widget child;
  
  const _KeyboardDoneButton({required this.child});
  
  @override
  Widget build(BuildContext context) {
    // Web does not support dart:io Platform, and on mobile we want the same
    // behavior everywhere: tap outside to dismiss the keyboard.
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

class TrackDistanceScreen extends StatefulWidget {
  final String userId;
  final String token;

  const TrackDistanceScreen({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<TrackDistanceScreen> createState() => _TrackDistanceScreenState();
}

class _TrackDistanceScreenState extends State<TrackDistanceScreen> {
  static const _primary = Color(0xFF7E5EFD);

  // Manual entry (miles)
  final TextEditingController _milesController = TextEditingController(text: '0');

  // Rate (per mile)
  final TextEditingController _rateController = TextEditingController(text: '0');

  // Year for mileage rate (UI only for now)
  String _mileageYear = '2026';
  bool _isLoadingRate = false;
  String? _currency;

  @override
  void initState() {
    super.initState();
    _fetchDefaultRate();
  }

  @override
  void dispose() {
    _milesController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _fetchDefaultRate({String? year}) async {
    final effectiveYear = year ?? _mileageYear;
    setState(() {
      _isLoadingRate = true;
    });

    try {
      final response = await ApiService.get(
        '/receipts/mileage-rate?userId=${widget.userId}&year=$effectiveYear',
        token: widget.token,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ratePerMile = data['ratePerMile']?.toString() ?? '0';
        final currency = data['currency'] ?? 'USD';
        final responseYear = data['year']?.toString();
        
        if (mounted) {
          setState(() {
            _rateController.text = ratePerMile;
            _currency = currency;
            if (responseYear != null && responseYear.isNotEmpty) {
              _mileageYear = responseYear;
            }
            _isLoadingRate = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingRate = false;
          });
        }
        debugPrint('Failed to fetch mileage rate: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching mileage rate: $e');
      if (mounted) {
        setState(() {
          _isLoadingRate = false;
        });
      }
    }
  }

  double get _distanceMiles {
    final parsed = double.tryParse(_milesController.text.trim()) ?? 0;
    return parsed;
  }

  double get _ratePerMile => double.tryParse(_rateController.text.trim()) ?? 0;

  double get _amount => (_distanceMiles * _ratePerMile);

  Future<void> _showInfoDialog({required String title, required String message}) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: _primary)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: _primary)),
          ),
        ],
      ),
    );
  }

  void _manualKeyPress(String key) {
    setState(() {
      final currentText = _milesController.text;
      if (key == '<') {
        if (currentText.length <= 1) {
          _milesController.text = '0';
        } else {
          _milesController.text = currentText.substring(0, currentText.length - 1);
          if (_milesController.text.isEmpty) _milesController.text = '0';
        }
        _milesController.selection = TextSelection.fromPosition(
          TextPosition(offset: _milesController.text.length),
        );
        return;
      }

      if (key == '.') {
        if (currentText.contains('.')) return;
        _milesController.text = '$currentText.';
        _milesController.selection = TextSelection.fromPosition(
          TextPosition(offset: _milesController.text.length),
        );
        return;
      }

      // digit
      if (currentText == '0') {
        _milesController.text = key;
      } else {
        // Keep it reasonable
        if (currentText.length < 8) {
          _milesController.text = '$currentText$key';
        }
      }
      _milesController.selection = TextSelection.fromPosition(
        TextPosition(offset: _milesController.text.length),
      );
    });
  }

  Future<void> _goNext() async {
    final miles = _distanceMiles;
    if (miles <= 0) {
      await _showInfoDialog(title: 'Distance required', message: 'Please enter or track a distance first.');
      return;
    }

    final amount = _amount;
    if (amount <= 0) {
      await _showInfoDialog(title: 'Rate required', message: 'Please enter a valid rate per mile.');
      return;
    }

    // For mileage receipts, don't send amount - backend calculates it
    final receipt = <String, dynamic>{
      'merchant': 'Distance',
      'receiptDate': DateFormat('MM-dd-yyyy').format(DateTime.now()),
      // Note: amount is NOT sent - backend calculates it as distanceMiles × ratePerMile
      'category': 'Mileage', // Optional - backend sets it anyway
      'isDistance': true, // REQUIRED: Flag to indicate mileage receipt
      'distanceMiles': miles, // REQUIRED: Distance in miles
      'ratePerMile': _ratePerMile, // REQUIRED: Rate per mile
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptDetailsScreen(
          receipt: receipt,
          imageUrl: '',
          userId: widget.userId,
          imageId: '',
          isNewReceipt: true,
          isPdf: false,
          isManualReceipt: true,
        ),
      ),
    );

    if (!mounted) return;
    // Always pop back to dashboard, passing the result (which may be null if user dismissed)
    Navigator.pop(context, result);
  }


  Widget _distanceHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
            Future.delayed(const Duration(milliseconds: 100), () {
              _milesController.selection = TextSelection.fromPosition(
                TextPosition(offset: _milesController.text.length),
              );
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _milesController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    // Dismiss keyboard when done is pressed
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'miles',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _key(String label, {IconData? icon}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: () => _manualKeyPress(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF3EFFF),
              foregroundColor: _primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: icon != null
                ? Icon(icon, color: Colors.black54)
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final amountText = _amount > 0 ? _amount.toStringAsFixed(2) : '0.00';
    final isNextEnabled = _distanceMiles > 0 && _ratePerMile > 0;
    // Use user's effective currency symbol (based on stored currency/country),
    // defaulting to US Dollar ('$') when not available.
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currencySymbol = userProvider.effectiveCurrencySymbol;

    return _KeyboardDoneButton(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3FF),
        appBar: AppBar(
          title: const Text('Track Distance'),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Main content in a single card that fills the space
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scrollable content section
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Rate + Year (two columns in the same row)
                              Row(
                                children: [
                                  // Rate column
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Rate (per mile)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                currencySymbol,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: _primary,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextField(
                                                  controller: _rateController,
                                                  keyboardType: const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                                  textInputAction: TextInputAction.done,
                                                  enabled: !_isLoadingRate,
                                                  decoration: InputDecoration(
                                                    hintText: _isLoadingRate ? 'Loading...' : '0',
                                                    border: InputBorder.none,
                                                    enabledBorder: InputBorder.none,
                                                    disabledBorder: InputBorder.none,
                                                    focusedBorder: InputBorder.none,
                                                    errorBorder: InputBorder.none,
                                                    focusedErrorBorder: InputBorder.none,
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.zero,
                                                    hintStyle: TextStyle(
                                                      color: Colors.grey.shade500,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                  onChanged: (_) => setState(() {}),
                                                  onSubmitted: (_) {
                                                    // Dismiss keyboard when done is pressed
                                                    FocusScope.of(context).unfocus();
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Year column
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Year',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TaxCalculatorDropdown<String>(
                                          value: _mileageYear,
                                          items: const [
                                            DropdownMenuItem(
                                              value: '2024',
                                              child: Text(
                                                '2024',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: '2025',
                                              child: Text(
                                                '2025',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: '2026',
                                              child: Text(
                                                '2026',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            if (value == null) return;
                                            setState(() {
                                              _mileageYear = value;
                                            });
                                            // Refetch mileage rate for the newly selected year
                                            _fetchDefaultRate(year: value);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Distance header
                              _distanceHeader(),
                              const SizedBox(height: 16),
                              // Keypad
                              Column(
                                children: [
                                  Row(children: [_key('1'), _key('2'), _key('3')]),
                                  Row(children: [_key('4'), _key('5'), _key('6')]),
                                  Row(children: [_key('7'), _key('8'), _key('9')]),
                                  Row(
                                    children: [
                                      _key('.'),
                                      _key('0'),
                                      _key('<', icon: Icons.backspace_outlined),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Amount row and buttons section (fixed at bottom)
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      // Amount row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Amount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Distance × rate',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$currencySymbol$amountText',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _primary,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Next button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isNextEnabled ? _goNext : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Next',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Cancel button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: const BorderSide(color: _primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

