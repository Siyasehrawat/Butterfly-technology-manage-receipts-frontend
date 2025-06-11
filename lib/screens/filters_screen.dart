import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/receipt_provider.dart';
import 'edit_merchant_screen.dart';
import 'edit_category_screen.dart';
import 'edit_date_screen.dart';
import 'edit_amount_screen.dart';
import 'reports_screen.dart';

class FiltersScreen extends StatelessWidget {
  const FiltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReceiptProvider>(context);

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
                      'Filters',
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
                  _buildFilterOption(
                      context, 'Merchant', provider.filters['merchant'] ?? '',
                          () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditMerchantScreen(
                              initialValue: provider.filters['merchant'] ?? '',
                            ),
                          ),
                        );
                        if (result != null) {
                          provider.updateFilter('merchant', result);
                        }
                      }),
                  const Divider(),
                  _buildFilterOption(
                      context, 'Category', _getCategoryDisplayText(provider),
                          () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditCategoryScreen(
                              initialValue: provider.filters['category'] ?? '',
                            ),
                          ),
                        );
                        if (result != null && result is Map<String, dynamic>) {
                          // Update both category names and IDs for multiple selection
                          if (result['names'] != null && result['names'] is List) {
                            provider.updateFilter('categories', result['names']);
                          }
                          if (result['categoryIds'] != null &&
                              result['categoryIds'] is List) {
                            provider.updateFilter(
                                'categoryIds', result['categoryIds']);
                          }

                          // For backward compatibility
                          if (result['categoryIds'] != null &&
                              result['categoryIds'] is List &&
                              (result['categoryIds'] as List).isNotEmpty) {
                            provider.updateFilter('categoryId',
                                (result['categoryIds'] as List).first);
                          }
                          if (result['names'] != null &&
                              result['names'] is List &&
                              (result['names'] as List).isNotEmpty) {
                            provider.updateFilter(
                                'category', (result['names'] as List).first);
                          }
                        }
                      }),
                  const Divider(),
                  _buildFilterOption(
                      context,
                      'Date',
                      provider.filters['fromDate'] != null &&
                          provider.filters['toDate'] != null
                          ? formattedDateRange(provider.filters['fromDate'],
                          provider.filters['toDate'])
                          : '', () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditDateScreen(
                          initialValue: provider.filters['fromDate'] ?? '',
                        ),
                      ),
                    );
                    if (result != null) {
                      provider.updateFilter('fromDate', result['fromDate']);
                      provider.updateFilter('toDate', result['toDate']);
                    }
                  }),
                  const Divider(),
                  _buildFilterOption(
                      context,
                      'Amount',
                      _getAmountDisplayText(provider),
                          () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditAmountScreen(
                              initialMinValue: provider.filters['minAmount'] ?? '0',
                              initialMaxValue: provider.filters['maxAmount'] ?? '',
                            ),
                          ),
                        );
                        if (result != null && result is Map<String, dynamic>) {
                          provider.updateFilter('minAmount', result['minAmount']);
                          provider.updateFilter('maxAmount', result['maxAmount']);
                        }
                      }),
                  const Spacer(),

                  // Action buttons
                  Column(
                    children: [
                      // View Results button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            provider.fetchReceipts();

                            // Navigate to the reports screen with the current filters
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReportsScreen(
                                  userId: provider.userId,
                                  filterParams: provider.filters,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E5EFD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'View Results',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      // Clear Filters button
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            // Clear all filters
                            provider.clearFilters();

                            // Show confirmation
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('All filters cleared'),
                                backgroundColor: Color(0xFF7E5EFD),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF7E5EFD),
                            side: const BorderSide(color: Color(0xFF7E5EFD)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Clear Filters',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryDisplayText(ReceiptProvider provider) {
    // Check if we have multiple categories selected
    if (provider.filters['categories'] != null &&
        provider.filters['categories'] is List) {
      final categories = provider.filters['categories'] as List;
      if (categories.isEmpty) {
        return '';
      } else if (categories.length == 1) {
        return categories.first.toString();
      } else {
        return '${categories.length} categories selected';
      }
    }

    // Fallback to single category
    return provider.filters['category'] ?? '';
  }

  String _getAmountDisplayText(ReceiptProvider provider) {
    final minAmount = provider.filters['minAmount'];
    final maxAmount = provider.filters['maxAmount'];

    if (minAmount != null && minAmount.isNotEmpty && maxAmount != null && maxAmount.isNotEmpty) {
      return '\$$minAmount - \$$maxAmount';
    } else if (minAmount != null && minAmount.isNotEmpty) {
      return 'Min: \$$minAmount';
    } else if (maxAmount != null && maxAmount.isNotEmpty) {
      return 'Max: \$$maxAmount';
    }

    return '';
  }

  Widget _buildFilterOption(
      BuildContext context, String title, String value, VoidCallback onTap) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: value.isNotEmpty
          ? Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      )
          : null,
      trailing: const Icon(Icons.chevron_right),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }

  // Format the date range for display
  String formattedDateRange(String fromDate, String toDate) {
    final DateFormat dateFormat = DateFormat('MMMM dd, yyyy');
    final DateTime from = DateTime.parse(fromDate);
    final DateTime to = DateTime.parse(toDate);

    return '${dateFormat.format(from)} - ${dateFormat.format(to)}';
  }
}