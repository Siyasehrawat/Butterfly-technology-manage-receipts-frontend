import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'dart:async';

/// Helper widget to add a Done button toolbar above numeric keyboards on iOS
class _KeyboardDoneButton extends StatelessWidget {
  final Widget child;
  
  const _KeyboardDoneButton({required this.child});
  
  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
            FocusScope.of(context).unfocus();
          }
        },
        child: child,
      );
    }
    return child;
  }
}

/// Custom popup route that always opens downward
class _DownwardPopupRoute<T> extends PopupRoute<T> {
  final Widget child;
  final Offset position;
  final double menuMaxHeight;
  final double width;

  _DownwardPopupRoute({
    required this.child,
    required this.position,
    required this.width,
    this.menuMaxHeight = 300,
  });

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Close dropdown';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      removeLeft: true,
      removeRight: true,
      child: Builder(
        builder: (BuildContext context) {
          return CustomSingleChildLayout(
            delegate: _DownwardMenuLayout(
              position.dx,
              position.dy,
              width,
              menuMaxHeight,
            ),
            child: FadeTransition(
              opacity: animation,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: menuMaxHeight,
                    minWidth: width,
                  ),
                  child: IntrinsicWidth(
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DownwardMenuLayout extends SingleChildLayoutDelegate {
  final double x;
  final double y;
  final double width;
  final double menuMaxHeight;

  _DownwardMenuLayout(this.x, this.y, this.width, this.menuMaxHeight);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxHeight: menuMaxHeight,
      minWidth: width,
      maxWidth: width,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Always position below the button
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_DownwardMenuLayout oldDelegate) {
    return x != oldDelegate.x ||
        y != oldDelegate.y ||
        width != oldDelegate.width ||
        menuMaxHeight != oldDelegate.menuMaxHeight;
  }
}

/// Reusable dropdown widget for Tax Calculator screen
/// Matches app's design system and handles all edge cases
/// Always opens downward from the text box
class TaxCalculatorDropdown<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? Function(T?)? validator;
  final bool isEnabled;

  const TaxCalculatorDropdown({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.hintText,
    this.validator,
    this.isEnabled = true,
  });

  @override
  State<TaxCalculatorDropdown<T>> createState() =>
      _TaxCalculatorDropdownState<T>();
}

class _TaxCalculatorDropdownState<T> extends State<TaxCalculatorDropdown<T>> {
  final GlobalKey _dropdownKey = GlobalKey();

  void _showDropdown() {
    if (!widget.isEnabled || widget.onChanged == null) return;

    final RenderBox? renderBox =
        _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset position = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    final List<Widget> menuItems = widget.items.map((item) {
      final isSelected = item.value == widget.value;
      return InkWell(
        onTap: () {
          Navigator.pop(context);
          widget.onChanged?.call(item.value);
        },
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEEE8FF) : Colors.transparent,
          ),
          child: item.child,
        ),
      );
    }).toList();

    Navigator.of(context).push(
      _DownwardPopupRoute<T>(
        position: Offset(position.dx, position.dy + size.height + 4),
        width: size.width,
        menuMaxHeight: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: menuItems,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      key: _dropdownKey,
      initialValue: widget.value,
      validator: widget.validator,
      builder: (FormFieldState<T> field) {
        return InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7C63F6), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF5252), width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF5252), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            isDense: false,
            errorText: field.hasError ? field.errorText : null,
          ),
          isEmpty: widget.value == null,
          child: GestureDetector(
            onTap: widget.isEnabled ? _showDropdown : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.value?.toString() ?? widget.hintText ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: widget.value == null
                          ? Colors.grey.shade400
                          : const Color(0xFF1f1f1f),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: widget.isEnabled
                      ? const Color(0xFF7C63F6)
                      : Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TaxCalculatorScreen extends StatefulWidget {
  const TaxCalculatorScreen({super.key});

  @override
  State<TaxCalculatorScreen> createState() => _TaxCalculatorScreenState();
}

class _TaxCalculatorScreenState extends State<TaxCalculatorScreen>
    with SingleTickerProviderStateMixin {
  final _revenueController = TextEditingController(text: '185000');
  final _ownerPayController = TextEditingController(text: '60000');
  final _taxesPaidController = TextEditingController(text: '12000');
  
  // Individual expense controllers
  final _cogsController = TextEditingController(text: '45000');
  final _payrollController = TextEditingController(text: '35000');
  final _rentController = TextEditingController(text: '18000');
  final _marketingController = TextEditingController(text: '8500');
  final _softwareController = TextEditingController(text: '4200');
  final _equipmentController = TextEditingController(text: '7500');
  final _othersController = TextEditingController(text: '0');

  late TabController _tabController;

  final _currencyFormatter =
      NumberFormat.currency(locale: 'en_US', symbol: r'$', decimalDigits: 0);

  String _businessType = 'LLC (Multi-Member)';
  String _selectedYear = '2026';
  bool _expensesExpanded = false;

  // Calculated values
  double _netProfit = 0;
  double _estimatedTax = 0;
  double _selfEmploymentTax = 0;
  double _remainingDue = 0;
  double _effectiveTaxRate = 0;

  // What-if simulator values
  double _simRevenue = 185000;
  double _simExpenses = 86200;

  // Individual Tax Calculator state
  final _individualIncomeController = TextEditingController(text: '85000');
  final _additionalIncomeController = TextEditingController(text: '18700');
  final _taxWithheldController = TextEditingController(text: '8000');
  final _mortgageController = TextEditingController(text: '0');
  final _stateTaxController = TextEditingController(text: '0');
  final _charitableController = TextEditingController(text: '0');
  final _medicalController = TextEditingController(text: '0');
  final _individualOthersController = TextEditingController(text: '0');

  String _filingStatus = 'Married Filing Jointly';
  String _workType = 'Freelancer / Self-Employed';
  String _deductionMethod = 'standard'; // 'standard' or 'itemized'
  bool _itemizedExpanded = false;

  // Individual calculated values
  double _individualTax = 0;
  double _individualTaxRate = 0;
  double _taxableIncome = 0;
  double _agi = 0;
  double _netAfterTax = 0;
  double _individualRemainingDue = 0;

  // Debounce timer for calculations (mobile optimization)
  Timer? _calculationTimer;

  @override
  void initState() {
    super.initState();
    try {
      debugPrint('📱 TaxCalculatorScreen: initState called');
      print('📱 TaxCalculatorScreen: initState called'); // More reliable on mobile
      
      _tabController = TabController(length: 2, vsync: this);
      
      // Add listeners to all controllers to recalculate when values change
      // Use debounced handler for better mobile performance
      _revenueController.addListener(_onBusinessFieldChanged);
      _ownerPayController.addListener(_onBusinessFieldChanged);
      _taxesPaidController.addListener(_onBusinessFieldChanged);
      _cogsController.addListener(_onBusinessFieldChanged);
      _payrollController.addListener(_onBusinessFieldChanged);
      _rentController.addListener(_onBusinessFieldChanged);
      _marketingController.addListener(_onBusinessFieldChanged);
      _softwareController.addListener(_onBusinessFieldChanged);
      _equipmentController.addListener(_onBusinessFieldChanged);
      _othersController.addListener(_onBusinessFieldChanged);
      
      debugPrint('📱 TaxCalculatorScreen: Controllers initialized');
      debugPrint('📱 TaxCalculatorScreen: Revenue controller text: "${_revenueController.text}"');
      print('📱 TaxCalculatorScreen: Revenue controller text: "${_revenueController.text}"');
      
      // Force initial calculation after a short delay to ensure controllers are ready
      // Use a small delay to ensure the widget tree is fully built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('📱 TaxCalculatorScreen: PostFrameCallback executed, mounted: $mounted');
        print('📱 TaxCalculatorScreen: PostFrameCallback executed, mounted: $mounted');
        if (mounted) {
          // Add a small delay to ensure all controllers are fully initialized
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              debugPrint('📱 TaxCalculatorScreen: Calling initial calculations after delay...');
              print('📱 TaxCalculatorScreen: Calling initial calculations after delay...');
              debugPrint('📱 TaxCalculatorScreen: Revenue before calc: "${_revenueController.text}"');
              print('📱 TaxCalculatorScreen: Revenue before calc: "${_revenueController.text}"');
              _calculateBusinessTax(); // Initial calculation
              _calculateIndividualTax(); // Initial individual calculation
              debugPrint('📱 TaxCalculatorScreen: Initial calculations completed');
              print('📱 TaxCalculatorScreen: Initial calculations completed');
            } else {
              debugPrint('⚠️ TaxCalculatorScreen: Widget disposed during delay, skipping calculation');
              print('⚠️ TaxCalculatorScreen: Widget disposed during delay, skipping calculation');
            }
          });
        } else {
          debugPrint('⚠️ TaxCalculatorScreen: Widget not mounted, skipping initial calculation');
          print('⚠️ TaxCalculatorScreen: Widget not mounted, skipping initial calculation');
        }
      });
    } catch (e) {
      debugPrint('❌ Error initializing TaxCalculatorScreen: $e');
      print('❌ Error initializing TaxCalculatorScreen: $e');
    }
  }

  @override
  void dispose() {
    _calculationTimer?.cancel();
    _tabController.dispose();
    
    // Remove listeners before disposing
    _revenueController.removeListener(_onBusinessFieldChanged);
    _ownerPayController.removeListener(_onBusinessFieldChanged);
    _taxesPaidController.removeListener(_onBusinessFieldChanged);
    _cogsController.removeListener(_onBusinessFieldChanged);
    _payrollController.removeListener(_onBusinessFieldChanged);
    _rentController.removeListener(_onBusinessFieldChanged);
    _marketingController.removeListener(_onBusinessFieldChanged);
    _softwareController.removeListener(_onBusinessFieldChanged);
    _equipmentController.removeListener(_onBusinessFieldChanged);
    _othersController.removeListener(_onBusinessFieldChanged);
    
    _revenueController.dispose();
    _ownerPayController.dispose();
    _taxesPaidController.dispose();
    _cogsController.dispose();
    _payrollController.dispose();
    _rentController.dispose();
    _marketingController.dispose();
    _softwareController.dispose();
    _equipmentController.dispose();
    _othersController.dispose();
    _individualIncomeController.dispose();
    _additionalIncomeController.dispose();
    _taxWithheldController.dispose();
    _mortgageController.dispose();
    _stateTaxController.dispose();
    _charitableController.dispose();
    _medicalController.dispose();
    _individualOthersController.dispose();
    super.dispose();
  }

  // Debounced handler for business tax calculation (mobile optimization)
  void _onBusinessFieldChanged() {
    // Cancel previous timer
    _calculationTimer?.cancel();
    
    // Set new timer to debounce calculations
    // This prevents excessive calculations while user is typing on mobile
    _calculationTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _calculateBusinessTax();
      }
    });
  }

  // Debounced handler for individual tax calculation (mobile optimization)
  void _onIndividualFieldChanged() {
    // Cancel previous timer
    _calculationTimer?.cancel();
    
    // Set new timer to debounce calculations
    // This prevents excessive calculations while user is typing on mobile
    _calculationTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _calculateIndividualTax();
      }
    });
  }

  double _parseAmount(TextEditingController controller) {
    try {
      final originalText = controller.text;
      
      if (originalText.isEmpty || originalText.trim().isEmpty) {
        debugPrint('📝 _parseAmount: Empty text, returning 0');
        return 0;
      }
      
      // Get the raw text
      String rawText = originalText.trim();
      
      // Remove all non-numeric characters except decimal point
      // Handle various formatting characters that might appear on mobile
      String cleanedText = rawText
          .replaceAll(',', '')  // Remove commas
          .replaceAll(' ', '')  // Remove spaces
          .replaceAll('\$', '') // Remove dollar signs
          .replaceAll('₹', '')  // Remove rupee signs
          .replaceAll('€', '')  // Remove euro signs
          .replaceAll('£', '')  // Remove pound signs
          .replaceAll(RegExp(r'[^\d.]'), '') // Remove any other non-numeric except decimal
          .trim();
      
      if (cleanedText.isEmpty || cleanedText == '.') {
        debugPrint('📝 _parseAmount: Cleaned text empty or just ".", returning 0. Original: "$originalText"');
        print('📝 _parseAmount: Cleaned text empty or just ".", returning 0. Original: "$originalText"');
        return 0;
      }
      
      // Handle multiple decimal points - take only the first one
      final parts = cleanedText.split('.');
      String normalizedText;
      if (parts.length > 1) {
        // Keep first part, then join remaining parts and remove non-digits
        final firstPart = parts[0].isEmpty ? '0' : parts[0];
        final decimalPart = parts.sublist(1).join('').replaceAll(RegExp(r'[^\d]'), '');
        normalizedText = '$firstPart.$decimalPart';
      } else {
        normalizedText = cleanedText;
      }
      
      // Handle edge case: if text ends with a decimal point, remove it
      final finalText = normalizedText.endsWith('.') 
          ? normalizedText.substring(0, normalizedText.length - 1)
          : normalizedText;
      
      if (finalText.isEmpty || finalText == '.') {
        debugPrint('📝 _parseAmount: Final text empty or just ".", returning 0. Original: "$originalText"');
        print('📝 _parseAmount: Final text empty or just ".", returning 0. Original: "$originalText"');
        return 0;
      }
      
      // Try parsing as double with explicit locale (en_US uses . as decimal separator)
      // This ensures consistent parsing across platforms
      final parsed = double.tryParse(finalText);
      if (parsed == null) {
        // Fallback: try replacing locale-specific decimal separators
        final fallbackText = finalText.replaceAll(',', '.');
        final fallbackParsed = double.tryParse(fallbackText);
        if (fallbackParsed != null) {
          debugPrint('✅ _parseAmount: Parsed with fallback. "$originalText" -> $fallbackParsed');
          print('✅ _parseAmount: Parsed with fallback. "$originalText" -> $fallbackParsed');
          return fallbackParsed;
        }
        
        debugPrint('❌ Failed to parse amount: "$originalText" -> cleaned: "$cleanedText" -> normalized: "$normalizedText" -> final: "$finalText"');
        print('❌ Failed to parse amount: "$originalText" -> cleaned: "$cleanedText" -> normalized: "$normalizedText" -> final: "$finalText"');
        return 0;
      }
      
      // Ensure we don't return NaN or Infinity
      if (parsed.isNaN || parsed.isInfinite) {
        debugPrint('⚠️ Invalid number parsed: $parsed from "$originalText"');
        print('⚠️ Invalid number parsed: $parsed from "$originalText"');
        return 0;
      }
      
      debugPrint('✅ _parseAmount: Successfully parsed "$originalText" -> $parsed');
      print('✅ _parseAmount: Successfully parsed "$originalText" -> $parsed');
      return parsed;
    } catch (e) {
      debugPrint('❌ Exception parsing amount: "${controller.text}" - $e');
      print('❌ Exception parsing amount: "${controller.text}" - $e');
      return 0;
    }
  }

  double _getTotalExpenses() {
    return _parseAmount(_cogsController) +
        _parseAmount(_payrollController) +
        _parseAmount(_rentController) +
        _parseAmount(_marketingController) +
        _parseAmount(_softwareController) +
        _parseAmount(_equipmentController) +
        _parseAmount(_othersController);
  }

  /// Get business tax brackets based on selected year
  /// Business tax uses Single filing status brackets
  List<Map<String, double>> _getBusinessTaxBrackets(String year) {
    if (year == '2025') {
      // 2025 Tax brackets for Single (used for business income)
      return [
        {'min': 0.0, 'max': 11600.0, 'rate': 0.10},
        {'min': 11601.0, 'max': 47150.0, 'rate': 0.12},
        {'min': 47151.0, 'max': 100525.0, 'rate': 0.22},
        {'min': 100526.0, 'max': 191950.0, 'rate': 0.24},
        {'min': 191951.0, 'max': 243725.0, 'rate': 0.32},
        {'min': 243726.0, 'max': 609350.0, 'rate': 0.35},
        {'min': 609351.0, 'max': double.infinity, 'rate': 0.37},
      ];
    } else {
      // 2026 Tax brackets for Single (used for business income)
      return [
        {'min': 0.0, 'max': 11600.0, 'rate': 0.10},
        {'min': 11601.0, 'max': 47150.0, 'rate': 0.12},
        {'min': 47151.0, 'max': 100525.0, 'rate': 0.22},
        {'min': 100526.0, 'max': 191950.0, 'rate': 0.24},
        {'min': 191951.0, 'max': 243725.0, 'rate': 0.32},
        {'min': 243726.0, 'max': 609350.0, 'rate': 0.35},
        {'min': 609351.0, 'max': double.infinity, 'rate': 0.37},
      ];
    }
  }

  /// Get individual tax brackets based on filing status and year
  List<Map<String, double>> _getIndividualTaxBrackets(String filingStatus, String year) {
    if (year == '2025') {
      // 2025 Tax brackets
      switch (filingStatus) {
        case 'Single':
          return [
            {'min': 0.0, 'max': 11600.0, 'rate': 0.10},
            {'min': 11601.0, 'max': 47150.0, 'rate': 0.12},
            {'min': 47151.0, 'max': 100525.0, 'rate': 0.22},
            {'min': 100526.0, 'max': 191950.0, 'rate': 0.24},
            {'min': 191951.0, 'max': 243725.0, 'rate': 0.32},
            {'min': 243726.0, 'max': 609350.0, 'rate': 0.35},
            {'min': 609351.0, 'max': double.infinity, 'rate': 0.37},
          ];
        case 'Married Filing Jointly':
          return [
            {'min': 0.0, 'max': 23200.0, 'rate': 0.10},
            {'min': 23201.0, 'max': 94300.0, 'rate': 0.12},
            {'min': 94301.0, 'max': 201050.0, 'rate': 0.22},
            {'min': 201051.0, 'max': 383900.0, 'rate': 0.24},
            {'min': 383901.0, 'max': 487450.0, 'rate': 0.32},
            {'min': 487451.0, 'max': 731200.0, 'rate': 0.35},
            {'min': 731201.0, 'max': double.infinity, 'rate': 0.37},
          ];
        case 'Married Filing Separately':
          return [
            {'min': 0.0, 'max': 11600.0, 'rate': 0.10},
            {'min': 11601.0, 'max': 47150.0, 'rate': 0.12},
            {'min': 47151.0, 'max': 100525.0, 'rate': 0.22},
            {'min': 100526.0, 'max': 191950.0, 'rate': 0.24},
            {'min': 191951.0, 'max': 243725.0, 'rate': 0.32},
            {'min': 243726.0, 'max': 365600.0, 'rate': 0.35},
            {'min': 365601.0, 'max': double.infinity, 'rate': 0.37},
          ];
        case 'Head of Household':
          return [
            {'min': 0.0, 'max': 16550.0, 'rate': 0.10},
            {'min': 16551.0, 'max': 63100.0, 'rate': 0.12},
            {'min': 63101.0, 'max': 100500.0, 'rate': 0.22},
            {'min': 100501.0, 'max': 191950.0, 'rate': 0.24},
            {'min': 191951.0, 'max': 243700.0, 'rate': 0.32},
            {'min': 243701.0, 'max': 609350.0, 'rate': 0.35},
            {'min': 609351.0, 'max': double.infinity, 'rate': 0.37},
          ];
        default:
          return [
            {'min': 0.0, 'max': 23200.0, 'rate': 0.10},
            {'min': 23201.0, 'max': 94300.0, 'rate': 0.12},
            {'min': 94301.0, 'max': 201050.0, 'rate': 0.22},
            {'min': 201051.0, 'max': 383900.0, 'rate': 0.24},
            {'min': 383901.0, 'max': 487450.0, 'rate': 0.32},
            {'min': 487451.0, 'max': 731200.0, 'rate': 0.35},
            {'min': 731201.0, 'max': double.infinity, 'rate': 0.37},
          ];
      }
    } else {
      // 2026 Tax brackets
      switch (filingStatus) {
        case 'Single':
          return [
            {'min': 0.0, 'max': 11600.0, 'rate': 0.10},
            {'min': 11601.0, 'max': 47150.0, 'rate': 0.12},
            {'min': 47151.0, 'max': 100525.0, 'rate': 0.22},
            {'min': 100526.0, 'max': 191950.0, 'rate': 0.24},
            {'min': 191951.0, 'max': 243725.0, 'rate': 0.32},
            {'min': 243726.0, 'max': 609350.0, 'rate': 0.35},
            {'min': 609351.0, 'max': double.infinity, 'rate': 0.37},
          ];
        case 'Married Filing Jointly':
          return [
            {'min': 0.0, 'max': 23200.0, 'rate': 0.10},
            {'min': 23201.0, 'max': 94300.0, 'rate': 0.12},
            {'min': 94301.0, 'max': 201050.0, 'rate': 0.22},
            {'min': 201051.0, 'max': 383900.0, 'rate': 0.24},
            {'min': 383901.0, 'max': 487450.0, 'rate': 0.32},
            {'min': 487451.0, 'max': 731200.0, 'rate': 0.35},
            {'min': 731201.0, 'max': double.infinity, 'rate': 0.37},
          ];
        case 'Married Filing Separately':
          return [
            {'min': 0.0, 'max': 11600.0, 'rate': 0.10},
            {'min': 11601.0, 'max': 47150.0, 'rate': 0.12},
            {'min': 47151.0, 'max': 100525.0, 'rate': 0.22},
            {'min': 100526.0, 'max': 191950.0, 'rate': 0.24},
            {'min': 191951.0, 'max': 243725.0, 'rate': 0.32},
            {'min': 243726.0, 'max': 365600.0, 'rate': 0.35},
            {'min': 365601.0, 'max': double.infinity, 'rate': 0.37},
          ];
        case 'Head of Household':
          return [
            {'min': 0.0, 'max': 16550.0, 'rate': 0.10},
            {'min': 16551.0, 'max': 63100.0, 'rate': 0.12},
            {'min': 63101.0, 'max': 100500.0, 'rate': 0.22},
            {'min': 100501.0, 'max': 191950.0, 'rate': 0.24},
            {'min': 191951.0, 'max': 243700.0, 'rate': 0.32},
            {'min': 243701.0, 'max': 609350.0, 'rate': 0.35},
            {'min': 609351.0, 'max': double.infinity, 'rate': 0.37},
          ];
        default:
          return [
            {'min': 0.0, 'max': 23200.0, 'rate': 0.10},
            {'min': 23201.0, 'max': 94300.0, 'rate': 0.12},
            {'min': 94301.0, 'max': 201050.0, 'rate': 0.22},
            {'min': 201051.0, 'max': 383900.0, 'rate': 0.24},
            {'min': 383901.0, 'max': 487450.0, 'rate': 0.32},
            {'min': 487451.0, 'max': 731200.0, 'rate': 0.35},
            {'min': 731201.0, 'max': double.infinity, 'rate': 0.37},
          ];
      }
    }
  }

  /// Get standard deduction amount based on filing status and year
  double _getStandardDeductionAmount(String filingStatus, String year) {
    if (year == '2025') {
      switch (filingStatus) {
        case 'Single':
          return 15850.0;
        case 'Married Filing Jointly':
          return 27700.0;
        case 'Married Filing Separately':
          return 13850.0;
        case 'Head of Household':
          return 20800.0;
        default:
          return 27700.0;
      }
    } else {
      // 2026 standard deductions
      switch (filingStatus) {
        case 'Single':
          return 15850.0;
        case 'Married Filing Jointly':
          return 27700.0;
        case 'Married Filing Separately':
          return 13850.0;
        case 'Head of Household':
          return 20800.0;
        default:
          return 27700.0;
      }
    }
  }

  void _calculateBusinessTax() {
    debugPrint('🔢 _calculateBusinessTax: Called');
    print('🔢 _calculateBusinessTax: Called'); // More reliable on mobile
    
    if (!mounted) {
      debugPrint('⚠️ _calculateBusinessTax: Widget not mounted, returning');
      print('⚠️ _calculateBusinessTax: Widget not mounted, returning');
      return;
    }
    
    try {
      debugPrint('🔢 _calculateBusinessTax: Starting calculation...');
      print('🔢 _calculateBusinessTax: Starting calculation...');
      
      final revenue = _parseAmount(_revenueController);
      final totalExpenses = _getTotalExpenses();
      final ownerPay = _parseAmount(_ownerPayController);
      final taxesPaid = _parseAmount(_taxesPaidController);

      debugPrint('=== Tax Calculation ===');
      debugPrint('Revenue text: "${_revenueController.text}" -> parsed: $revenue');
      debugPrint('Total Expenses: $totalExpenses');
      debugPrint('  - COGS: ${_parseAmount(_cogsController)} (text: "${_cogsController.text}")');
      debugPrint('  - Payroll: ${_parseAmount(_payrollController)} (text: "${_payrollController.text}")');
      debugPrint('  - Rent: ${_parseAmount(_rentController)} (text: "${_rentController.text}")');
      debugPrint('  - Marketing: ${_parseAmount(_marketingController)} (text: "${_marketingController.text}")');
      debugPrint('  - Software: ${_parseAmount(_softwareController)} (text: "${_softwareController.text}")');
      debugPrint('  - Equipment: ${_parseAmount(_equipmentController)} (text: "${_equipmentController.text}")');
      debugPrint('  - Others: ${_parseAmount(_othersController)} (text: "${_othersController.text}")');
      debugPrint('OwnerPay: $ownerPay, TaxesPaid: $taxesPaid');
      
      // Also print to console for mobile visibility
      print('=== Tax Calculation ===');
      print('Revenue text: "${_revenueController.text}" -> parsed: $revenue');
      print('Total Expenses: $totalExpenses');
      print('  - COGS: ${_parseAmount(_cogsController)} (text: "${_cogsController.text}")');
      print('  - Payroll: ${_parseAmount(_payrollController)} (text: "${_payrollController.text}")');
      print('  - Rent: ${_parseAmount(_rentController)} (text: "${_rentController.text}")');
      print('  - Marketing: ${_parseAmount(_marketingController)} (text: "${_marketingController.text}")');
      print('  - Software: ${_parseAmount(_softwareController)} (text: "${_softwareController.text}")');
      print('  - Equipment: ${_parseAmount(_equipmentController)} (text: "${_equipmentController.text}")');
      print('  - Others: ${_parseAmount(_othersController)} (text: "${_othersController.text}")');
      print('OwnerPay: $ownerPay, TaxesPaid: $taxesPaid');
      debugPrint('Business Type: $_businessType');
      print('Business Type: $_businessType');

    // Calculate profit based on business type
    // For S-Corporation: Owner salary is deductible, so subtract it from expenses
    // For others: Owner pay/draws are NOT deductible
    double adjustedExpenses = totalExpenses;
    double taxableProfit;
    double netProfit;
    
    if (_businessType == 'S-Corporation') {
      // S-Corp: Owner salary is deductible business expense
      adjustedExpenses = totalExpenses + ownerPay;
      netProfit = revenue - adjustedExpenses;
      taxableProfit = netProfit < 0 ? 0.0 : netProfit;
      
      debugPrint('S-Corporation: Owner salary ($ownerPay) is deductible');
      debugPrint('Adjusted Expenses: $adjustedExpenses (Total Expenses: $totalExpenses + Owner Salary: $ownerPay)');
      debugPrint('Net Profit: $netProfit (Revenue: $revenue - Adjusted Expenses: $adjustedExpenses)');
      print('S-Corporation: Owner salary ($ownerPay) is deductible');
      print('Adjusted Expenses: $adjustedExpenses (Total Expenses: $totalExpenses + Owner Salary: $ownerPay)');
      print('Net Profit: $netProfit (Revenue: $revenue - Adjusted Expenses: $adjustedExpenses)');
    } else {
      // Sole Proprietorship, LLC (Single-Member), LLC (Multi-Member): Owner pay/draws are NOT deductible
      netProfit = revenue - totalExpenses;
      taxableProfit = netProfit < 0 ? 0.0 : netProfit;
      
      debugPrint('${_businessType}: Owner pay/draws ($ownerPay) are NOT deductible');
      debugPrint('Net Profit: $netProfit (Revenue: $revenue - Expenses: $totalExpenses)');
      print('${_businessType}: Owner pay/draws ($ownerPay) are NOT deductible');
      print('Net Profit: $netProfit (Revenue: $revenue - Expenses: $totalExpenses)');
    }
    
    final profitForTax = taxableProfit;
    
    debugPrint('Profit For Tax: $profitForTax');
    print('Profit For Tax: $profitForTax');

    // Self-employment tax rate
    const seTaxRate = 0.153;

    // Calculate self-employment tax based on business type
    double selfEmploymentTax;
    if (_businessType == 'S-Corporation') {
      // S-Corp: Only owner salary is subject to self-employment tax, not the distributed profit
      final salaryForSETax = ownerPay < 0 ? 0.0 : ownerPay;
      selfEmploymentTax = salaryForSETax * seTaxRate;
      debugPrint('S-Corporation: Only owner salary ($salaryForSETax) is subject to self-employment tax');
      debugPrint('Self-Employment Tax Calculation: $salaryForSETax * $seTaxRate = $selfEmploymentTax');
      print('S-Corporation: Only owner salary ($salaryForSETax) is subject to self-employment tax');
      print('Self-Employment Tax Calculation: $salaryForSETax * $seTaxRate = $selfEmploymentTax');
    } else {
      // Other business types: All profit is subject to self-employment tax
      selfEmploymentTax = profitForTax * seTaxRate;
      debugPrint('${_businessType}: All profit ($profitForTax) is subject to self-employment tax');
      debugPrint('Self-Employment Tax Calculation: $profitForTax * $seTaxRate = $selfEmploymentTax');
      print('${_businessType}: All profit ($profitForTax) is subject to self-employment tax');
      print('Self-Employment Tax Calculation: $profitForTax * $seTaxRate = $selfEmploymentTax');
    }

    // Calculate income tax using progressive brackets (Single filing for business)
    // For income tax purposes:
    // - S-Corp: Income tax applies to owner salary + distributed profit = revenue - expenses
    // - Others: Income tax applies to all profit
    double incomeTaxBase;
    if (_businessType == 'S-Corporation') {
      // S-Corp: Income tax applies to the full profit (revenue - expenses)
      // This includes both the salary portion (already taxed as salary) and distributions
      incomeTaxBase = revenue - totalExpenses;
      incomeTaxBase = incomeTaxBase < 0 ? 0.0 : incomeTaxBase;
      debugPrint('S-Corporation: Income tax base = revenue ($revenue) - expenses ($totalExpenses) = $incomeTaxBase');
      print('S-Corporation: Income tax base = revenue ($revenue) - expenses ($totalExpenses) = $incomeTaxBase');
    } else {
      // Other business types: Income tax applies to profit
      incomeTaxBase = profitForTax;
      debugPrint('${_businessType}: Income tax base = profitForTax ($profitForTax)');
      print('${_businessType}: Income tax base = profitForTax ($profitForTax)');
    }
    
    double incomeTax = 0;
    double remainingIncome = incomeTaxBase;

    // Get tax brackets based on selected year
    final List<Map<String, double>> brackets = _getBusinessTaxBrackets(_selectedYear);
    
    debugPrint('📅 Using tax brackets for year: $_selectedYear, business type: $_businessType');
    print('📅 Using tax brackets for year: $_selectedYear, business type: $_businessType');

    // Calculate tax using progressive brackets
    // Track cumulative income taxed so far
    // Use the same logic as individual tax calculation (which works correctly)
    double incomeTaxedSoFar = 0;
    
    debugPrint('🔢 Starting bracket calculation for incomeTaxBase: $incomeTaxBase (business type: $_businessType)');
    print('🔢 Starting bracket calculation for incomeTaxBase: $incomeTaxBase (business type: $_businessType)');
    
    for (var bracket in brackets) {
      // If we've already taxed all income, stop
      if (incomeTaxedSoFar >= incomeTaxBase) {
        debugPrint('⏹️ All income taxed. incomeTaxedSoFar ($incomeTaxedSoFar) >= incomeTaxBase ($incomeTaxBase), breaking');
        print('⏹️ All income taxed. incomeTaxedSoFar ($incomeTaxedSoFar) >= incomeTaxBase ($incomeTaxBase), breaking');
        break;
      }
      
      final min = (bracket['min'] as num).toDouble();
      final max = (bracket['max'] as num).toDouble();
      final rate = (bracket['rate'] as num).toDouble();

      debugPrint('📊 Processing bracket: min=$min, max=$max, rate=${rate * 100}%');
      print('📊 Processing bracket: min=$min, max=$max, rate=${rate * 100}%');

      // Calculate how much income falls in this bracket
      // Use the same logic as individual tax calculation
      double incomeInBracket = 0;
      final bracketTop = max == double.infinity ? incomeTaxBase : max;
      
      if (incomeTaxBase <= min) {
        // Total income is below this bracket - skip it
        debugPrint('⏹️ Income tax base ($incomeTaxBase) <= bracket min ($min), breaking');
        print('⏹️ Income tax base ($incomeTaxBase) <= bracket min ($min), breaking');
        break;
      } else if (incomeTaxBase <= bracketTop) {
        // Income ends in this bracket
        incomeInBracket = incomeTaxBase - (min > incomeTaxedSoFar ? min : incomeTaxedSoFar);
        debugPrint('  Income ends in bracket. incomeInBracket = $incomeTaxBase - ${min > incomeTaxedSoFar ? min : incomeTaxedSoFar} = $incomeInBracket');
        print('  Income ends in bracket. incomeInBracket = $incomeTaxBase - ${min > incomeTaxedSoFar ? min : incomeTaxedSoFar} = $incomeInBracket');
      } else {
        // Income exceeds this bracket - tax the full bracket range
        incomeInBracket = bracketTop - (min > incomeTaxedSoFar ? min : incomeTaxedSoFar);
        debugPrint('  Income exceeds bracket. incomeInBracket = $bracketTop - ${min > incomeTaxedSoFar ? min : incomeTaxedSoFar} = $incomeInBracket');
        print('  Income exceeds bracket. incomeInBracket = $bracketTop - ${min > incomeTaxedSoFar ? min : incomeTaxedSoFar} = $incomeInBracket');
      }
      
      // Only tax positive amounts
      if (incomeInBracket > 0) {
        final taxInBracket = incomeInBracket * rate;
        incomeTax += taxInBracket;
        incomeTaxedSoFar += incomeInBracket;
        debugPrint('✅ Bracket [${min.toStringAsFixed(0)}-${max == double.infinity ? '∞' : max.toStringAsFixed(0)}]: Taxed ${incomeInBracket.toStringAsFixed(2)} at ${(rate * 100).toStringAsFixed(1)}% = ${taxInBracket.toStringAsFixed(2)}. Total incomeTax so far: $incomeTax');
        print('✅ Bracket [${min.toStringAsFixed(0)}-${max == double.infinity ? '∞' : max.toStringAsFixed(0)}]: Taxed ${incomeInBracket.toStringAsFixed(2)} at ${(rate * 100).toStringAsFixed(1)}% = ${taxInBracket.toStringAsFixed(2)}. Total incomeTax so far: $incomeTax');
      } else {
        debugPrint('⏭️ Skipping bracket: incomeInBracket ($incomeInBracket) <= 0');
        print('⏭️ Skipping bracket: incomeInBracket ($incomeInBracket) <= 0');
      }
    }
    
    debugPrint('🔢 Finished bracket calculation. Final incomeTax: $incomeTax');
    print('🔢 Finished bracket calculation. Final incomeTax: $incomeTax');

    final totalTax = incomeTax + selfEmploymentTax;
    debugPrint('💰 Total Tax Calculation: incomeTax ($incomeTax) + selfEmploymentTax ($selfEmploymentTax) = $totalTax');
    print('💰 Total Tax Calculation: incomeTax ($incomeTax) + selfEmploymentTax ($selfEmploymentTax) = $totalTax');
    
    // Remaining due can be negative if overpaid, but we'll show 0 for display purposes
    final remainingDue = totalTax > taxesPaid ? (totalTax - taxesPaid) : 0.0;
    debugPrint('💰 Remaining Due Calculation: totalTax ($totalTax) - taxesPaid ($taxesPaid) = $remainingDue');
    print('💰 Remaining Due Calculation: totalTax ($totalTax) - taxesPaid ($taxesPaid) = $remainingDue');

      debugPrint('=== Final Tax Calculation Results ===');
      debugPrint('Business Type: $_businessType');
      debugPrint('Revenue: ${_currencyFormatter.format(revenue)}');
      debugPrint('Total Expenses: ${_currencyFormatter.format(totalExpenses)}');
      if (_businessType == 'S-Corporation') {
        debugPrint('Owner Salary (deductible): ${_currencyFormatter.format(ownerPay)}');
        debugPrint('Adjusted Expenses: ${_currencyFormatter.format(adjustedExpenses)}');
      } else {
        debugPrint('Owner Pay/Draws (NOT deductible): ${_currencyFormatter.format(ownerPay)}');
      }
      debugPrint('Net Profit: ${_currencyFormatter.format(netProfit)}');
      debugPrint('Income Tax Base: ${_currencyFormatter.format(incomeTaxBase)}');
      debugPrint('Income Tax: ${_currencyFormatter.format(incomeTax)}');
      debugPrint('Self-Employment Tax: ${_currencyFormatter.format(selfEmploymentTax)}');
      debugPrint('Total Tax: ${_currencyFormatter.format(totalTax)}');
      debugPrint('Taxes Already Paid: ${_currencyFormatter.format(taxesPaid)}');
      debugPrint('Remaining Due: ${_currencyFormatter.format(remainingDue)}');
      debugPrint('Effective Tax Rate: ${incomeTaxBase > 0 ? ((totalTax / incomeTaxBase) * 100).toStringAsFixed(2) : "0.00"}%');
      debugPrint('=====================================');
      
      // Also print to console for mobile visibility
      print('=== Final Tax Calculation Results ===');
      print('Business Type: $_businessType');
      print('Revenue: ${_currencyFormatter.format(revenue)}');
      print('Total Expenses: ${_currencyFormatter.format(totalExpenses)}');
      if (_businessType == 'S-Corporation') {
        print('Owner Salary (deductible): ${_currencyFormatter.format(ownerPay)}');
        print('Adjusted Expenses: ${_currencyFormatter.format(adjustedExpenses)}');
      } else {
        print('Owner Pay/Draws (NOT deductible): ${_currencyFormatter.format(ownerPay)}');
      }
      print('Net Profit: ${_currencyFormatter.format(netProfit)}');
      print('Income Tax Base: ${_currencyFormatter.format(incomeTaxBase)}');
      print('Income Tax: ${_currencyFormatter.format(incomeTax)}');
      print('Self-Employment Tax: ${_currencyFormatter.format(selfEmploymentTax)}');
      print('Total Tax: ${_currencyFormatter.format(totalTax)}');
      print('Taxes Already Paid: ${_currencyFormatter.format(taxesPaid)}');
      print('Remaining Due: ${_currencyFormatter.format(remainingDue)}');
      print('Effective Tax Rate: ${incomeTaxBase > 0 ? ((totalTax / incomeTaxBase) * 100).toStringAsFixed(2) : "0.00"}%');
      print('=====================================');

      // Ensure state update happens on the correct thread (important for mobile)
      if (mounted) {
        debugPrint('✅ _calculateBusinessTax: Updating state with estimatedTax: $totalTax');
        print('✅ _calculateBusinessTax: Updating state with estimatedTax: $totalTax');
        setState(() {
          _netProfit = netProfit; // Use the calculated netProfit (which accounts for business type)
          _estimatedTax = totalTax;
          _selfEmploymentTax = selfEmploymentTax;
          _remainingDue = remainingDue;
          _effectiveTaxRate = incomeTaxBase > 0 ? (totalTax / incomeTaxBase) * 100 : 0.0;
        });
        debugPrint('✅ _calculateBusinessTax: State updated successfully');
        print('✅ _calculateBusinessTax: State updated successfully');
      } else {
        debugPrint('⚠️ _calculateBusinessTax: Widget not mounted, cannot update state');
        print('⚠️ _calculateBusinessTax: Widget not mounted, cannot update state');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _calculateBusinessTax: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      print('❌ Error in _calculateBusinessTax: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _netProfit = 0;
          _estimatedTax = 0;
          _selfEmploymentTax = 0;
          _remainingDue = 0;
          _effectiveTaxRate = 0.0;
        });
      }
    }
  }

  String _profitHealthMessage() {
    if (_netProfit <= 0) {
      return 'Low or negative profit: Consider reviewing pricing or reducing expenses.';
    }
    final revenue = _parseAmount(_revenueController);
    if (revenue <= 0) return 'Add your revenue and expenses to see insights.';
    final margin = _netProfit / revenue;
    if (margin >= 0.25) {
      return 'Healthy Profit Margin: Your business shows strong profitability with good expense management.';
    } else if (margin >= 0.10) {
      return 'Moderate Profit Margin: You\'re on track, but there may be room to optimize expenses.';
    } else {
      return 'Thin Profit Margin: Consider reviewing recurring costs and improving pricing.';
    }
  }

  Color _getProfitHealthColor() {
    if (_netProfit <= 0) return const Color(0xFFFF5252);
    final revenue = _parseAmount(_revenueController);
    if (revenue <= 0) return const Color(0xFFFFC107);
    final margin = _netProfit / revenue;
    if (margin >= 0.25) {
      return const Color(0xFF4CAF50);
    } else if (margin >= 0.10) {
      return const Color(0xFFFFC107);
    } else {
      return const Color(0xFFFF5252);
    }
  }

  IconData _getProfitHealthIcon() {
    final color = _getProfitHealthColor();
    if (color == const Color(0xFF4CAF50)) {
      return Icons.check_circle;
    } else if (color == const Color(0xFFFFC107)) {
      return Icons.warning;
    } else {
      return Icons.error;
    }
  }

  List<double> _quarterlyPayments() {
    if (_remainingDue <= 0) {
      return const [0, 0, 0, 0];
    }
    final q = _remainingDue / 4;
    return [q, q, q, q];
  }

  List<double> _individualQuarterlyPayments() {
    if (_individualRemainingDue <= 0) {
      return const [0, 0, 0, 0];
    }
    final q = _individualRemainingDue / 4;
    return [q, q, q, q];
  }

  void _calculateIndividualTax() {
    debugPrint('🔢 _calculateIndividualTax: Called');
    print('🔢 _calculateIndividualTax: Called');
    
    if (!mounted) {
      debugPrint('⚠️ _calculateIndividualTax: Widget not mounted, returning');
      print('⚠️ _calculateIndividualTax: Widget not mounted, returning');
      return;
    }
    
    try {
      debugPrint('🔢 _calculateIndividualTax: Starting calculation...');
      print('🔢 _calculateIndividualTax: Starting calculation...');
      
      final annualIncome = _parseAmount(_individualIncomeController);
      final additionalIncome = _parseAmount(_additionalIncomeController);
      final taxWithheld = _parseAmount(_taxWithheldController);

      debugPrint('=== Individual Tax Calculation ===');
      debugPrint('Filing Status: $_filingStatus');
      debugPrint('Year: $_selectedYear');
      debugPrint('Work Type: $_workType');
      debugPrint('Deduction Method: $_deductionMethod');
      debugPrint('Annual Income: ${_currencyFormatter.format(annualIncome)}');
      debugPrint('Additional Income: ${_currencyFormatter.format(additionalIncome)}');
      debugPrint('Tax Withheld: ${_currencyFormatter.format(taxWithheld)}');
      
      print('=== Individual Tax Calculation ===');
      print('Filing Status: $_filingStatus');
      print('Year: $_selectedYear');
      print('Work Type: $_workType');
      print('Deduction Method: $_deductionMethod');
      print('Annual Income: ${_currencyFormatter.format(annualIncome)}');
      print('Additional Income: ${_currencyFormatter.format(additionalIncome)}');
      print('Tax Withheld: ${_currencyFormatter.format(taxWithheld)}');

      // Calculate AGI
      final agi = annualIncome + additionalIncome;
      debugPrint('AGI (Adjusted Gross Income): $annualIncome + $additionalIncome = $agi');
      print('AGI (Adjusted Gross Income): $annualIncome + $additionalIncome = $agi');

      // Determine deduction amount based on filing status and year
      double standardDeduction = _getStandardDeductionAmount(_filingStatus, _selectedYear);
      debugPrint('Standard Deduction for $_filingStatus ($_selectedYear): ${_currencyFormatter.format(standardDeduction)}');
      print('Standard Deduction for $_filingStatus ($_selectedYear): ${_currencyFormatter.format(standardDeduction)}');
      
      double deductionAmount = standardDeduction;

      // If itemized, use itemized deductions
      if (_deductionMethod == 'itemized') {
        final mortgageInterest = _parseAmount(_mortgageController);
        final stateTaxes = _parseAmount(_stateTaxController);
        final charitable = _parseAmount(_charitableController);
        final medical = _parseAmount(_medicalController);
        final others = _parseAmount(_individualOthersController);
        final itemizedTotal = mortgageInterest + stateTaxes + charitable + medical + others;
        
        debugPrint('Itemized Deductions:');
        debugPrint('  - Mortgage Interest: ${_currencyFormatter.format(mortgageInterest)}');
        debugPrint('  - State Taxes: ${_currencyFormatter.format(stateTaxes)}');
        debugPrint('  - Charitable: ${_currencyFormatter.format(charitable)}');
        debugPrint('  - Medical: ${_currencyFormatter.format(medical)}');
        debugPrint('  - Others: ${_currencyFormatter.format(others)}');
        debugPrint('  - Total Itemized: ${_currencyFormatter.format(itemizedTotal)}');
        
        print('Itemized Deductions:');
        print('  - Mortgage Interest: ${_currencyFormatter.format(mortgageInterest)}');
        print('  - State Taxes: ${_currencyFormatter.format(stateTaxes)}');
        print('  - Charitable: ${_currencyFormatter.format(charitable)}');
        print('  - Medical: ${_currencyFormatter.format(medical)}');
        print('  - Others: ${_currencyFormatter.format(others)}');
        print('  - Total Itemized: ${_currencyFormatter.format(itemizedTotal)}');
        
        if (itemizedTotal > standardDeduction) {
          deductionAmount = itemizedTotal;
          debugPrint('✅ Using Itemized Deduction (${_currencyFormatter.format(itemizedTotal)}) > Standard (${_currencyFormatter.format(standardDeduction)})');
          print('✅ Using Itemized Deduction (${_currencyFormatter.format(itemizedTotal)}) > Standard (${_currencyFormatter.format(standardDeduction)})');
        } else {
          debugPrint('✅ Using Standard Deduction (${_currencyFormatter.format(standardDeduction)}) > Itemized (${_currencyFormatter.format(itemizedTotal)})');
          print('✅ Using Standard Deduction (${_currencyFormatter.format(standardDeduction)}) > Itemized (${_currencyFormatter.format(itemizedTotal)})');
        }
      } else {
        debugPrint('Using Standard Deduction: ${_currencyFormatter.format(standardDeduction)}');
        print('Using Standard Deduction: ${_currencyFormatter.format(standardDeduction)}');
      }

      // Calculate taxable income
      final taxableIncome = ((agi - deductionAmount).clamp(0, double.infinity)).toDouble();
      debugPrint('Taxable Income: AGI ($agi) - Deduction (${_currencyFormatter.format(deductionAmount)}) = ${_currencyFormatter.format(taxableIncome)}');
      print('Taxable Income: AGI ($agi) - Deduction (${_currencyFormatter.format(deductionAmount)}) = ${_currencyFormatter.format(taxableIncome)}');

      // Tax calculation using progressive brackets based on filing status
      double tax = 0;
      double remainingIncome = taxableIncome;

      // Get tax brackets based on filing status and selected year
      final List<Map<String, double>> brackets = _getIndividualTaxBrackets(_filingStatus, _selectedYear);
      
      debugPrint('📅 Using tax brackets for year: $_selectedYear, filing status: $_filingStatus');
      debugPrint('📊 Number of tax brackets: ${brackets.length}');
      print('📅 Using tax brackets for year: $_selectedYear, filing status: $_filingStatus');
      print('📊 Number of tax brackets: ${brackets.length}');

      // Calculate tax using progressive brackets
      // Track cumulative income taxed so far
      double incomeTaxedSoFar = 0;
      
      debugPrint('🔢 Starting bracket calculation for taxableIncome: $taxableIncome');
      print('🔢 Starting bracket calculation for taxableIncome: $taxableIncome');
      
      for (var bracket in brackets) {
        if (incomeTaxedSoFar >= taxableIncome) {
          debugPrint('⏹️ All income taxed. incomeTaxedSoFar ($incomeTaxedSoFar) >= taxableIncome ($taxableIncome), breaking');
          print('⏹️ All income taxed. incomeTaxedSoFar ($incomeTaxedSoFar) >= taxableIncome ($taxableIncome), breaking');
          break;
        }
        
        final min = (bracket['min'] as num).toDouble();
        final max = (bracket['max'] as num).toDouble();
        final rate = (bracket['rate'] as num).toDouble();

        debugPrint('📊 Processing bracket: min=$min, max=$max, rate=${rate * 100}%');
        print('📊 Processing bracket: min=$min, max=$max, rate=${rate * 100}%');

        // Calculate how much income falls in this bracket
        double incomeInBracket = 0;
        final bracketTop = max == double.infinity ? taxableIncome : max;
        
        if (taxableIncome <= min) {
          // Total income is below this bracket - skip it
          debugPrint('⏹️ Taxable income ($taxableIncome) <= bracket min ($min), breaking');
          print('⏹️ Taxable income ($taxableIncome) <= bracket min ($min), breaking');
          break;
        } else if (taxableIncome <= bracketTop) {
          // Income ends in this bracket
          incomeInBracket = taxableIncome - (min > incomeTaxedSoFar ? min : incomeTaxedSoFar);
          debugPrint('  Income ends in bracket. incomeInBracket = $taxableIncome - ${min > incomeTaxedSoFar ? min : incomeTaxedSoFar} = $incomeInBracket');
          print('  Income ends in bracket. incomeInBracket = $taxableIncome - ${min > incomeTaxedSoFar ? min : incomeTaxedSoFar} = $incomeInBracket');
        } else {
          // Income exceeds this bracket - tax the full bracket range
          incomeInBracket = bracketTop - (min > incomeTaxedSoFar ? min : incomeTaxedSoFar);
          debugPrint('  Income exceeds bracket. incomeInBracket = $bracketTop - ${min > incomeTaxedSoFar ? min : incomeTaxedSoFar} = $incomeInBracket');
          print('  Income exceeds bracket. incomeInBracket = $bracketTop - ${min > incomeTaxedSoFar ? min : incomeTaxedSoFar} = $incomeInBracket');
        }
        
        // Only tax positive amounts
        if (incomeInBracket > 0) {
          final taxInBracket = incomeInBracket * rate;
          tax += taxInBracket;
          incomeTaxedSoFar += incomeInBracket;
          debugPrint('✅ Bracket [${min.toStringAsFixed(0)}-${max == double.infinity ? '∞' : max.toStringAsFixed(0)}]: Taxed ${incomeInBracket.toStringAsFixed(2)} at ${(rate * 100).toStringAsFixed(1)}% = ${taxInBracket.toStringAsFixed(2)}. Total tax so far: $tax');
          print('✅ Bracket [${min.toStringAsFixed(0)}-${max == double.infinity ? '∞' : max.toStringAsFixed(0)}]: Taxed ${incomeInBracket.toStringAsFixed(2)} at ${(rate * 100).toStringAsFixed(1)}% = ${taxInBracket.toStringAsFixed(2)}. Total tax so far: $tax');
        } else {
          debugPrint('⏭️ Skipping bracket: incomeInBracket ($incomeInBracket) <= 0');
          print('⏭️ Skipping bracket: incomeInBracket ($incomeInBracket) <= 0');
        }
      }
      
      debugPrint('🔢 Finished bracket calculation. Income tax: $tax');
      print('🔢 Finished bracket calculation. Income tax: $tax');

      // Add self-employment tax if applicable
      double selfEmploymentTax = 0.0;
      if (_workType == 'Freelancer / Self-Employed') {
        const seTaxRate = 0.153;
        selfEmploymentTax = annualIncome * seTaxRate;
        tax += selfEmploymentTax;
        debugPrint('💰 Self-Employment Tax: Annual Income ($annualIncome) * $seTaxRate = $selfEmploymentTax');
        print('💰 Self-Employment Tax: Annual Income ($annualIncome) * $seTaxRate = $selfEmploymentTax');
      } else {
        debugPrint('💰 No self-employment tax (Work Type: $_workType)');
        print('💰 No self-employment tax (Work Type: $_workType)');
      }

      final incomeTaxOnly = tax - selfEmploymentTax;
      debugPrint('💰 Income Tax (before SE tax): $incomeTaxOnly');
      print('💰 Income Tax (before SE tax): $incomeTaxOnly');

      // Calculate remaining tax due
      final remainingDue = ((tax - taxWithheld).clamp(0, double.infinity)).toDouble();

      // Calculate effective tax rate
      final effectiveRate = (agi > 0 ? (tax / agi) * 100 : 0.0).toDouble();

      // Calculate net income after tax
      final netIncome = agi - tax;

      debugPrint('=== Final Individual Tax Calculation Results ===');
      debugPrint('Filing Status: $_filingStatus');
      debugPrint('Year: $_selectedYear');
      debugPrint('AGI: ${_currencyFormatter.format(agi)}');
      debugPrint('Deduction Used: ${_currencyFormatter.format(deductionAmount)} (${_deductionMethod == 'itemized' ? 'Itemized' : 'Standard'})');
      debugPrint('Taxable Income: ${_currencyFormatter.format(taxableIncome)}');
      debugPrint('Income Tax: ${_currencyFormatter.format(incomeTaxOnly)}');
      if (selfEmploymentTax > 0) {
        debugPrint('Self-Employment Tax: ${_currencyFormatter.format(selfEmploymentTax)}');
      }
      debugPrint('Total Tax: ${_currencyFormatter.format(tax)}');
      debugPrint('Tax Already Withheld: ${_currencyFormatter.format(taxWithheld)}');
      debugPrint('Remaining Due: ${_currencyFormatter.format(remainingDue)}');
      debugPrint('Effective Tax Rate: ${effectiveRate.toStringAsFixed(2)}%');
      debugPrint('Net Income After Tax: ${_currencyFormatter.format(netIncome)}');
      debugPrint('===============================================');
      
      print('=== Final Individual Tax Calculation Results ===');
      print('Filing Status: $_filingStatus');
      print('Year: $_selectedYear');
      print('AGI: ${_currencyFormatter.format(agi)}');
      print('Deduction Used: ${_currencyFormatter.format(deductionAmount)} (${_deductionMethod == 'itemized' ? 'Itemized' : 'Standard'})');
      print('Taxable Income: ${_currencyFormatter.format(taxableIncome)}');
      print('Income Tax: ${_currencyFormatter.format(incomeTaxOnly)}');
      if (selfEmploymentTax > 0) {
        print('Self-Employment Tax: ${_currencyFormatter.format(selfEmploymentTax)}');
      }
      print('Total Tax: ${_currencyFormatter.format(tax)}');
      print('Tax Already Withheld: ${_currencyFormatter.format(taxWithheld)}');
      print('Remaining Due: ${_currencyFormatter.format(remainingDue)}');
      print('Effective Tax Rate: ${effectiveRate.toStringAsFixed(2)}%');
      print('Net Income After Tax: ${_currencyFormatter.format(netIncome)}');
      print('===============================================');

      if (mounted) {
        debugPrint('✅ _calculateIndividualTax: Updating state');
        print('✅ _calculateIndividualTax: Updating state');
        setState(() {
          _individualTax = tax;
          _individualTaxRate = effectiveRate;
          _taxableIncome = taxableIncome;
          _agi = agi;
          _netAfterTax = netIncome;
          _individualRemainingDue = remainingDue;
        });
        debugPrint('✅ _calculateIndividualTax: State updated successfully');
        print('✅ _calculateIndividualTax: State updated successfully');
      } else {
        debugPrint('⚠️ _calculateIndividualTax: Widget not mounted, cannot update state');
        print('⚠️ _calculateIndividualTax: Widget not mounted, cannot update state');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _calculateIndividualTax: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      print('❌ Error in _calculateIndividualTax: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _individualTax = 0;
          _individualTaxRate = 0;
          _taxableIncome = 0;
          _agi = 0;
          _netAfterTax = 0;
          _individualRemainingDue = 0;
        });
      }
    }
  }

  String _getStandardDeduction() {
    final amount = _getStandardDeductionAmount(_filingStatus, _selectedYear);
    return NumberFormat('#,###').format(amount.toInt());
  }

  void _resetSimulator() {
    setState(() {
      _simRevenue = 185000;
      _simExpenses = 86200;
      _revenueController.text = '185000';
      _cogsController.text = '45000';
      _payrollController.text = '35000';
      _rentController.text = '18000';
      _marketingController.text = '8500';
      _softwareController.text = '4200';
      _equipmentController.text = '7500';
      _othersController.text = '0';
    });
    _calculateBusinessTax();
  }

  void _resetCalculator() {
    setState(() {
      _businessType = 'LLC (Multi-Member)';
      _selectedYear = '2026';
      _revenueController.text = '185000';
      _ownerPayController.text = '60000';
      _taxesPaidController.text = '12000';
      _cogsController.text = '45000';
      _payrollController.text = '35000';
      _rentController.text = '18000';
      _marketingController.text = '8500';
      _softwareController.text = '4200';
      _equipmentController.text = '7500';
      _othersController.text = '0';
    });
    _resetSimulator();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF7C63F6),
                Color(0xFF9C7BFF),
              ],
            ),
          ),
        ),
        title: const Text(
          'Estimated Tax Calculator',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside input fields
          // TextFields will handle their own focus when tapped, so this only dismisses
          // when tapping on non-interactive areas
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.translucent,
        child: Column(
        children: [
          // Tabs Container
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEE8FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: const Color(0xFF7C63F6),
              unselectedLabelColor: const Color(0xFF7a7a7a),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              labelPadding: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              indicatorPadding: EdgeInsets.zero,
              dividerColor: Colors.transparent,
              tabAlignment: TabAlignment.fill,
              tabs: [
                Tab(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('🏢', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 6),
                      Text('Business'),
                    ],
                  ),
                ),
                Tab(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('👤', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 6),
                      Text('Individual'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBusinessTab(),
                _buildIndividualPlaceholder(),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildBusinessTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calculator Card
          _buildCalculatorCard(),
          const SizedBox(height: 20),
          
          // Results Card
          _buildResultsCard(),
          const SizedBox(height: 20),
          
          // Metrics Grid
          _buildMetricsGrid(),
          const SizedBox(height: 20),
          
          // Alert Card
          _buildAlertCard(),
          const SizedBox(height: 20),
          
          // Quarterly Section
          _buildQuarterlySection(),
          const SizedBox(height: 20),
          
          // Simulator Card
          _buildSimulatorCard(),
          const SizedBox(height: 20),
          
          // Action Buttons
          _buildActionButtons(),
          const SizedBox(height: 20),
          
          // Disclaimer
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildCalculatorCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF7C63F6).withOpacity(0.1),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEE8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    '🏢',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Business Tax Calculator',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1f1f1f),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 1),
          
          // Business Type
          _buildInputGroup(
            label: 'Business Type',
            child: TaxCalculatorDropdown<String>(
              value: _businessType,
              items: const [
                DropdownMenuItem(
                  value: 'Sole Proprietorship',
                  child: Text(
                    'Sole Proprietorship',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'LLC (Single-Member)',
                  child: Text(
                    'LLC (Single-Member)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'LLC (Multi-Member)',
                  child: Text(
                    'LLC (Multi-Member)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'S-Corporation',
                  child: Text(
                    'S-Corporation',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _businessType = value;
                  });
                  _calculateBusinessTax();
                }
              },
            ),
          ),
          
          // Year
          _buildInputGroup(
            label: 'Year',
            child: TaxCalculatorDropdown<String>(
              value: _selectedYear,
              items: const [
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
                if (value != null) {
                  setState(() {
                    _selectedYear = value;
                  });
                  _calculateBusinessTax();
                }
              },
            ),
          ),
          
          // Annual Revenue
          _buildInputGroup(
            label: 'Annual Revenue (\$)',
            child: TextField(
              controller: _revenueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              onChanged: (_) {
                // Trigger debounced calculation
                _onBusinessFieldChanged();
              },
              onSubmitted: (_) {
                // Dismiss keyboard when done is pressed
                FocusScope.of(context).unfocus();
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7C63F6), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            helpText: 'Total business income before expenses',
          ),
          
          // Operating Expenses Toggle
          GestureDetector(
            onTap: () {
              setState(() {
                _expensesExpanded = !_expensesExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Operating Expenses',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1f1f1f),
                    ),
                  ),
                  Icon(
                    _expensesExpanded ? Icons.remove : Icons.add,
                    color: const Color(0xFF7C63F6),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded Expenses Grid
          if (_expensesExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              margin: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildExpenseItem(
                          'Cost of Goods',
                          _cogsController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildExpenseItem(
                          'Payroll',
                          _payrollController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildExpenseItem(
                          'Rent & Utilities',
                          _rentController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildExpenseItem(
                          'Marketing',
                          _marketingController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildExpenseItem(
                          'Software',
                          _softwareController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildExpenseItem(
                          'Equipment',
                          _equipmentController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildExpenseItem(
                          'Others',
                          _othersController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox()), // Empty space for alignment
                    ],
                  ),
                ],
              ),
            ),
          
          // Owner Salary
          _buildInputGroup(
            label: 'Owner Salary / Draws (\$)',
            child: TextField(
              controller: _ownerPayController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              onChanged: (_) {
                // Trigger debounced calculation
                _onBusinessFieldChanged();
              },
              onSubmitted: (_) {
                // Dismiss keyboard when done is pressed
                FocusScope.of(context).unfocus();
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7C63F6), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          
          // Taxes Already Paid
          _buildInputGroup(
            label: 'Taxes Already Paid (\$)',
            child: TextField(
              controller: _taxesPaidController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              onChanged: (_) {
                // Trigger debounced calculation
                _onBusinessFieldChanged();
              },
              onSubmitted: (_) {
                // Dismiss keyboard when done is pressed
                FocusScope.of(context).unfocus();
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7C63F6), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            helpText: 'Estimated tax payments made this year',
          ),
          
        ],
      ),
    );
  }

  Widget _buildInputGroup({
    required String label,
    required Widget child,
    String? helpText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1f1f1f),
            ),
          ),
        ),
        child,
        if (helpText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              helpText,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF7a7a7a),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildExpenseItem(String label, TextEditingController controller, {bool isIndividual = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7a7a7a),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
            ],
            onChanged: (_) {
              // Trigger debounced calculation based on context
              if (isIndividual) {
                _onIndividualFieldChanged();
              } else {
                _onBusinessFieldChanged();
              }
            },
            onSubmitted: (_) {
              // Dismiss keyboard when done is pressed
              FocusScope.of(context).unfocus();
            },
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1f1f1f),
            ),
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7C63F6),
            Color(0xFF9C7BFF),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C63F6).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Builder(
              builder: (context) {
                // Log the displayed value for debugging
                debugPrint('📺 _buildResultsCard: Displaying _estimatedTax = $_estimatedTax');
                print('📺 _buildResultsCard: Displaying _estimatedTax = $_estimatedTax');
                return Text(
                  _currencyFormatter.format(_estimatedTax),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Estimated Annual Business Tax',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricItem('Net Profit', _currencyFormatter.format(_netProfit)),
        _buildMetricItem('Tax Rate', '${_effectiveTaxRate.toStringAsFixed(1)}%'),
        _buildMetricItem(
            'Self-Employment Tax', _currencyFormatter.format(_selfEmploymentTax)),
        _buildMetricItem('Remaining Due', _currencyFormatter.format(_remainingDue)),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7C63F6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7a7a7a),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard() {
    final color = _getProfitHealthColor();
    final icon = _getProfitHealthIcon();
    final message = _profitHealthMessage();
    
    Color bgColor;
    Color borderColor;
    if (color == const Color(0xFF4CAF50)) {
      bgColor = const Color(0xFF4CAF50).withOpacity(0.1);
      borderColor = const Color(0xFF4CAF50);
    } else if (color == const Color(0xFFFFC107)) {
      bgColor = const Color(0xFFFFC107).withOpacity(0.1);
      borderColor = const Color(0xFFFFC107);
    } else {
      bgColor = const Color(0xFFFF5252).withOpacity(0.1);
      borderColor = const Color(0xFFFF5252);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: borderColor,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF1f1f1f),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuarterlySection() {
    final quarterly = _quarterlyPayments();
    final labels = ['Q1', 'Q2', 'Q3', 'Q4'];
    final dates = ['Apr 15', 'Jun 15', 'Sep 15', 'Jan 15'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          const Text(
            'Quarterly Estimated Payments',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1f1f1f),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(4, (index) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[index],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1f1f1f),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _currencyFormatter.format(quarterly[index]),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C63F6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dates[index],
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF7a7a7a),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatorCard() {
    final simulatedProfit = _simRevenue - _simExpenses;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What-If Simulator',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1f1f1f),
            ),
          ),
          const SizedBox(height: 20),
          
          // Revenue Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Revenue',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1f1f1f),
                ),
              ),
              Text(
                _currencyFormatter.format(_simRevenue),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C63F6),
                ),
              ),
            ],
          ),
          Slider(
            value: _simRevenue,
            min: 50000,
            max: 500000,
            divisions: 450,
            activeColor: const Color(0xFF7C63F6),
            onChanged: (v) {
              setState(() {
                _simRevenue = v;
                _revenueController.text = v.toInt().toString();
              });
              _calculateBusinessTax();
            },
          ),
          
          const SizedBox(height: 20),
          
          // Expenses Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Expenses',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1f1f1f),
                ),
              ),
              Text(
                _currencyFormatter.format(_simExpenses),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C63F6),
                ),
              ),
            ],
          ),
          Slider(
            value: _simExpenses,
            min: 10000,
            max: 300000,
            divisions: 290,
            activeColor: const Color(0xFF7C63F6),
            onChanged: (v) {
              setState(() {
                _simExpenses = v;
                // Distribute expenses proportionally
                _cogsController.text = (v * 0.45).toInt().toString();
                _payrollController.text = (v * 0.35).toInt().toString();
                _rentController.text = (v * 0.10).toInt().toString();
                _marketingController.text = (v * 0.03).toInt().toString();
                _softwareController.text = (v * 0.02).toInt().toString();
                _equipmentController.text = (v * 0.02).toInt().toString();
              });
              _calculateBusinessTax();
            },
          ),
          
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _resetSimulator,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7a7a7a),
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Reset Simulator',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _resetCalculator,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7a7a7a),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              backgroundColor: const Color(0xFFF5F6FA),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Reset',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndividualPlaceholder() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calculator Card
          _buildIndividualCalculatorCard(),
          const SizedBox(height: 20),

          // Results Card
          _buildIndividualResultsCard(),
          const SizedBox(height: 20),

          // Metrics Grid
          _buildIndividualMetricsGrid(),
          const SizedBox(height: 20),

          // Alert Card
          _buildIndividualAlertCard(),
          const SizedBox(height: 20),

          // Quarterly Section
          _buildIndividualQuarterlySection(),
          const SizedBox(height: 20),

          // Action Buttons
          _buildIndividualActionButtons(),
          const SizedBox(height: 20),
          
          // Disclaimer
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildIndividualCalculatorCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF7C63F6).withOpacity(0.1),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEE8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    '👤',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Individual Tax Calculator',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1f1f1f),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 1),

          // Year
          _buildInputGroup(
            label: 'Year',
            child: TaxCalculatorDropdown<String>(
              value: _selectedYear,
              items: const [
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
                if (value != null) {
                  setState(() {
                    _selectedYear = value;
                  });
                  // Trigger debounced calculation
                  _onIndividualFieldChanged();
                }
              },
            ),
          ),

          // Filing Status Dropdown
          _buildInputGroup(
            label: 'Filing Status',
            child: TaxCalculatorDropdown<String>(
              value: _filingStatus,
              items: const [
                DropdownMenuItem(
                  value: 'Single',
                  child: Text(
                    'Single',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'Married Filing Jointly',
                  child: Text(
                    'Married Filing Jointly',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'Married Filing Separately',
                  child: Text(
                    'Married Filing Separately',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'Head of Household',
                  child: Text(
                    'Head of Household',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _filingStatus = value;
                  });
                  // Trigger debounced calculation
                  _onIndividualFieldChanged();
                }
              },
            ),
          ),

          // Work Type Dropdown
          _buildInputGroup(
            label: 'Work Type',
            child: TaxCalculatorDropdown<String>(
              value: _workType,
              items: const [
                DropdownMenuItem(
                  value: 'Salaried Employee',
                  child: Text(
                    'Salaried Employee',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'Freelancer / Self-Employed',
                  child: Text(
                    'Freelancer / Self-Employed',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _workType = value;
                  });
                  // Trigger debounced calculation
                  _onIndividualFieldChanged();
                }
              },
            ),
          ),

          // Annual Income
          _buildInputGroup(
            label: 'Annual Income (\$)',
            child: TextField(
              controller: _individualIncomeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7C63F6), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (_) {
                // Trigger debounced calculation
                _onIndividualFieldChanged();
              },
              onSubmitted: (_) {
                // Dismiss keyboard when done is pressed
                FocusScope.of(context).unfocus();
              },
            ),
          ),

          // Additional Income
          _buildInputGroup(
            label: 'Additional Income (\$)',
            child: TextField(
              controller: _additionalIncomeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7C63F6), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (_) {
                // Trigger debounced calculation
                _onIndividualFieldChanged();
              },
              onSubmitted: (_) {
                // Dismiss keyboard when done is pressed
                FocusScope.of(context).unfocus();
              },
            ),
            helpText: 'Dividends, interest, freelance income',
          ),

          // Deduction Options
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _deductionMethod = 'standard';
                      _itemizedExpanded = false;
                    });
                    // Trigger debounced calculation
                    _onIndividualFieldChanged();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _deductionMethod == 'standard'
                          ? const Color(0xFFEEE8FF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _deductionMethod == 'standard'
                            ? const Color(0xFF7C63F6)
                            : const Color(0xFFE0E0E0),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Standard',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _deductionMethod == 'standard'
                                ? const Color(0xFF7C63F6)
                                : const Color(0xFF1f1f1f),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_getStandardDeduction()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7a7a7a),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _deductionMethod = 'itemized';
                      _itemizedExpanded = true;
                    });
                    // Trigger debounced calculation
                    _onIndividualFieldChanged();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _deductionMethod == 'itemized'
                          ? const Color(0xFFEEE8FF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _deductionMethod == 'itemized'
                            ? const Color(0xFF7C63F6)
                            : const Color(0xFFE0E0E0),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Itemized',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _deductionMethod == 'itemized'
                                ? const Color(0xFF7C63F6)
                                : const Color(0xFF1f1f1f),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Custom',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7a7a7a),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Itemized Deductions (if selected)
          if (_itemizedExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              margin: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildExpenseItem(
                          'Mortgage Interest',
                          _mortgageController,
                          isIndividual: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildExpenseItem(
                          'State Taxes',
                          _stateTaxController,
                          isIndividual: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildExpenseItem(
                          'Charitable',
                          _charitableController,
                          isIndividual: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildExpenseItem(
                          'Medical',
                          _medicalController,
                          isIndividual: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildExpenseItem(
                          'Others',
                          _individualOthersController,
                          isIndividual: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Tax Already Withheld
          _buildInputGroup(
            label: 'Tax Already Withheld (\$)',
            child: TextField(
              controller: _taxWithheldController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7C63F6), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (_) {
                // Trigger debounced calculation
                _onIndividualFieldChanged();
              },
              onSubmitted: (_) {
                // Dismiss keyboard when done is pressed
                FocusScope.of(context).unfocus();
              },
            ),
            helpText: 'Tax paid through paycheck withholding',
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualResultsCard() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7C63F6),
            Color(0xFF9C7BFF),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C63F6).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _currencyFormatter.format(_individualTax),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Estimated Annual Federal Tax',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricItem(
            'Tax Rate', '${_individualTaxRate.toStringAsFixed(1)}%'),
        _buildMetricItem(
            'Taxable Income', _currencyFormatter.format(_taxableIncome)),
        _buildMetricItem('AGI', _currencyFormatter.format(_agi)),
        _buildMetricItem(
            'Net After Tax', _currencyFormatter.format(_netAfterTax)),
      ],
    );
  }

  Widget _buildIndividualAlertCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFFFFC107), width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning,
            color: Color(0xFFFFC107),
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1f1f1f),
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(
                    text: 'Underpayment Warning: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                        'Your estimated tax due exceeds \$1,000. Quarterly payments are recommended.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualQuarterlySection() {
    final quarterly = _individualQuarterlyPayments();
    final labels = ['Q1', 'Q2', 'Q3', 'Q4'];
    final dates = ['Apr 15', 'Jun 15', 'Sep 15', 'Jan 15'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          const Text(
            'Quarterly Estimated Payments',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1f1f1f),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(4, (index) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[index],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1f1f1f),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _currencyFormatter.format(quarterly[index]),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C63F6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dates[index],
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF7a7a7a),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _filingStatus = 'Married Filing Jointly';
                _workType = 'Freelancer / Self-Employed';
                _deductionMethod = 'standard';
                _itemizedExpanded = false;
                _individualIncomeController.text = '85000';
                _additionalIncomeController.text = '18700';
                _taxWithheldController.text = '8000';
                _mortgageController.text = '0';
                _stateTaxController.text = '0';
                _charitableController.text = '0';
                _medicalController.text = '0';
                _individualOthersController.text = '0';
              });
              _calculateIndividualTax();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7a7a7a),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              backgroundColor: const Color(0xFFF5F6FA),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Reset',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFFFFC107), width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning,
            color: Color(0xFFFFC107),
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1f1f1f),
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  const TextSpan(
                    text: 'Disclaimer: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text:
                        'This calculator provides estimates only. Results are based on current tax rates and are not professional tax advice. Consult a tax professional for accurate guidance. Learn more in our ',
                  ),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        const url = 'https://managereceipt.com/privacy-policy';
                        final uri = Uri.parse(url);
                        try {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        } catch (e) {
                          debugPrint('Error launching URL: $e');
                        }
                      },
                  ),
                  const TextSpan(
                    text: ' and ',
                  ),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        const url = 'https://managereceipt.com/terms-and-conditions';
                        final uri = Uri.parse(url);
                        try {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        } catch (e) {
                          debugPrint('Error launching URL: $e');
                        }
                      },
                  ),
                  const TextSpan(
                    text: '.',
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
