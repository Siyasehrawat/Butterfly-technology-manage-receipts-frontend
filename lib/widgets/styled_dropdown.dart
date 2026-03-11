import 'package:flutter/material.dart';

/// A styled dropdown widget that matches the design used in the reminder dialog.
/// 
/// Usage:
/// ```dart
/// StyledDropdown<String>(
///   value: selectedValue,
///   items: ['Option 1', 'Option 2', 'Option 3'],
///   onChanged: (value) => setState(() => selectedValue = value),
///   placeholder: 'Select an option',
/// )
/// ```
class StyledDropdown<T> extends StatelessWidget {
  /// The currently selected value
  final T? value;
  
  /// List of items to display in the dropdown
  final List<T> items;
  
  /// Callback when an item is selected
  final ValueChanged<T> onChanged;
  
  /// Placeholder text when no value is selected
  final String? placeholder;
  
  /// Function to convert item to display string
  final String Function(T)? itemToString;
  
  /// Optional custom height (default: 36)
  final double? height;
  
  /// Optional custom text style
  final TextStyle? textStyle;
  
  /// Optional custom icon
  final IconData? icon;
  
  /// Optional custom icon size
  final double? iconSize;
  
  /// Maximum height for the dropdown menu (default: 200)
  /// When items exceed this height, the menu becomes scrollable
  final double? maxMenuHeight;
  
  /// Custom builder for the dropdown button child
  /// If provided, this will be used instead of the default text display
  final Widget Function(BuildContext context, T? value)? childBuilder;
  
  /// Custom builder for menu items
  /// If provided, this will be used instead of the default text display
  final Widget Function(BuildContext context, T item)? menuItemBuilder;

  const StyledDropdown({
    Key? key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.placeholder,
    this.itemToString,
    this.height,
    this.textStyle,
    this.icon,
    this.iconSize,
    this.maxMenuHeight,
    this.childBuilder,
    this.menuItemBuilder,
  }) : super(key: key);

  String _getDisplayText(T? item) {
    if (item == null) return placeholder ?? '';
    if (itemToString != null) return itemToString!(item);
    return item.toString();
  }

  void _showMenu(BuildContext context, RenderBox button) {
    final menuMaxHeight = maxMenuHeight ?? 200.0;
    
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<T>(
      context: context,
      position: position,
      constraints: BoxConstraints(
        minWidth: button.size.width,
        maxWidth: button.size.width,
        maxHeight: menuMaxHeight,
      ),
      items: items.map((T item) {
        return PopupMenuItem<T>(
          value: item,
          child: menuItemBuilder != null
              ? menuItemBuilder!(context, item)
              : Text(
                  _getDisplayText(item),
                  style: textStyle ?? const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
        );
      }).toList(),
    ).then((T? selectedValue) {
      if (selectedValue != null) {
        onChanged(selectedValue);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayTextStyle = textStyle ?? const TextStyle(
      fontSize: 16,
      color: Colors.black87,
    );
    final dropdownIcon = icon ?? Icons.keyboard_arrow_down;
    final dropdownIconSize = iconSize ?? 24;

    return InputDecorator(
      decoration: InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        suffixIcon: Icon(dropdownIcon, size: dropdownIconSize),
      ),
      child: Builder(
        builder: (BuildContext context) {
          return InkWell(
            onTap: () {
              final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                _showMenu(context, renderBox);
              }
            },
            child: childBuilder != null
                ? childBuilder!(context, value)
                : Text(
                    _getDisplayText(value),
                    style: displayTextStyle.copyWith(
                      color: value != null ? Colors.black87 : Colors.grey.shade500,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

