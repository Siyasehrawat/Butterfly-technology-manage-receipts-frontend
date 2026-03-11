import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../providers/setting_provider.dart';
import '../../providers/feature_flags_provider.dart';
import '../../utils/category_icons.dart';
import '../../screens/receipt_details_screen.dart';
import 'web_dashboard.dart';

/// Web-optimized search receipts layout with sidebar navigation
class WebSearchReceiptsLayout extends StatefulWidget {
  final String userId;
  final String token;
  final List<dynamic> savedReceipts;
  final bool isLoading;
  final bool isLoadingMore;
  final Function(String) onSearchChanged;
  final Function() onRefresh;
  final Function(BuildContext, dynamic) onReceiptTap;
  final Function() onLogout;
  final Function() onNavigateToReports;
  final Function() onExportCSV;
  final Function() onExportPDF;
  final Function() onPrintReceipts;
  final int currentPage;
  final int totalCount;
  final bool hasNextPage;
  final Function(int) onPageChanged;
  final Function() onToggleFilters;
  final bool showFilters;
  final Map<String, dynamic> filterParams;
  final Function(Map<String, dynamic>) onFilterChanged;

  const WebSearchReceiptsLayout({
    Key? key,
    required this.userId,
    required this.token,
    required this.savedReceipts,
    required this.isLoading,
    required this.isLoadingMore,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onReceiptTap,
    required this.onLogout,
    required this.onNavigateToReports,
    required this.onExportCSV,
    required this.onExportPDF,
    required this.onPrintReceipts,
    required this.currentPage,
    required this.totalCount,
    required this.hasNextPage,
    required this.onPageChanged,
    required this.onToggleFilters,
    required this.showFilters,
    required this.filterParams,
    required this.onFilterChanged,
  }) : super(key: key);

  @override
  State<WebSearchReceiptsLayout> createState() => _WebSearchReceiptsLayoutState();
}

class _WebSearchReceiptsLayoutState extends State<WebSearchReceiptsLayout> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedReceiptIds = <String>{};
  bool _selectAll = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    widget.onSearchChanged(value);
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      if (_selectAll) {
        _selectedReceiptIds.addAll(
          widget.savedReceipts.map((r) => r['id']?.toString() ?? '').where((id) => id.isNotEmpty),
        );
      } else {
        _selectedReceiptIds.clear();
      }
    });
  }

  void _toggleReceiptSelection(String receiptId, bool? value) {
    setState(() {
      if (value ?? false) {
        _selectedReceiptIds.add(receiptId);
      } else {
        _selectedReceiptIds.remove(receiptId);
      }
      _selectAll = _selectedReceiptIds.length == widget.savedReceipts.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            // Left Sidebar (reuse from WebDashboardLayout)
            _buildSidebar(context),
            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Top Header
                  _buildTopHeader(context),
                  // Main Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16.0 : 32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Search and Filters Section
                            _buildSearchSection(context),
                            const SizedBox(height: 16),
                            // Filters Panel
                            if (widget.showFilters) _buildFiltersPanel(context),
                            // Bulk Actions
                            _buildBulkActions(context),
                            const SizedBox(height: 16),
                            // Receipts Table
                            _buildReceiptsTable(context),
                            const SizedBox(height: 16),
                            // Pagination
                            _buildPagination(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth < 1200 ? 240.0 : 280.0;
    
    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo Section
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF905CFF), Color(0xFF7A4BD9)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'MR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Manage Receipt',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Navigation Sections
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildNavSection(
                  context,
                  'MAIN',
                  [
                    _buildNavItem(context, Icons.home, 'Dashboard', false, () {
                      Navigator.pop(context);
                    }),
                    _buildNavItem(context, Icons.search, 'Search Receipts', true, () {}),
                    _buildNavItem(context, Icons.email, 'Email Receipts', false, () {}),
                  ],
                ),
                const SizedBox(height: 8),
                _buildNavSection(
                  context,
                  'REPORTS',
                  [
                    _buildNavItem(context, Icons.description, 'Expense Reports', false, widget.onNavigateToReports),
                    _buildNavItem(context, Icons.receipt_long, 'Tax Reports', false, () {}),
                    _buildNavItem(context, Icons.bar_chart, 'Analytics', false, () {}),
                  ],
                ),
                const SizedBox(height: 8),
                _buildNavSection(
                  context,
                  'FEATURES',
                  [
                    _buildNavItem(context, Icons.notifications, 'Bill Reminders', false, () {}),
                    _buildNavItem(context, Icons.people, 'Split Receipts', false, () {}),
                    _buildNavItem(context, Icons.folder, 'Document Wallet', false, () {}),
                  ],
                ),
              ],
            ),
          ),
          // User Profile Section
          _buildUserProfile(context),
        ],
      ),
    );
  }

  Widget _buildNavSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, bool isSelected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF905CFF).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFF905CFF) : Colors.grey.shade700,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF905CFF) : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfile(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final displayName = userProvider.username ?? 'User';
        final initials = displayName.isNotEmpty
            ? displayName.substring(0, 1).toUpperCase()
            : 'U';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF905CFF),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Premium Account',
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
        );
      },
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Search Receipts',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Consumer<FeatureFlagsProvider>(
                  builder: (context, featureFlagsProvider, child) {
                    if (!featureFlagsProvider.isMrBucksEnabled) {
                      return const SizedBox.shrink();
                    }
                    return Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.monetization_on, size: 18, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '1,250 MR Bucks',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }

  Widget _buildSearchSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search receipts by merchant, category, tags...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF905CFF), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: _handleSearchChanged,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: widget.onToggleFilters,
                icon: Icon(
                  widget.showFilters ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                ),
                label: const Text('Filters'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _handleSearchChanged(_searchController.text),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF905CFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextButton(
                onPressed: () {
                  widget.onFilterChanged({
                    'dateRange': 'Last 30 days',
                    'category': 'All Categories',
                    'exportStatus': 'All',
                  });
                },
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                    color: Color(0xFF905CFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date Range',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: widget.filterParams['dateRange'] ?? 'Last 30 days',
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Last 30 days', child: Text('Last 30 days')),
                        DropdownMenuItem(value: 'This month', child: Text('This month')),
                        DropdownMenuItem(value: 'Last month', child: Text('Last month')),
                        DropdownMenuItem(value: 'Custom range', child: Text('Custom range')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          widget.onFilterChanged({'dateRange': value});
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: widget.filterParams['category'] ?? 'All Categories',
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All Categories', child: Text('All Categories')),
                        DropdownMenuItem(value: 'Food & Dining', child: Text('Food & Dining')),
                        DropdownMenuItem(value: 'Transportation', child: Text('Transportation')),
                        DropdownMenuItem(value: 'Services', child: Text('Services')),
                        DropdownMenuItem(value: 'Advertising', child: Text('Advertising')),
                        DropdownMenuItem(value: 'Office Supplies', child: Text('Office Supplies')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          widget.onFilterChanged({'category': value});
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Export Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: widget.filterParams['exportStatus'] ?? 'All',
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Exported', child: Text('Exported')),
                        DropdownMenuItem(value: 'Not Exported', child: Text('Not Exported')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          widget.onFilterChanged({'exportStatus': value});
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Row(
            children: [
              Checkbox(
                value: _selectAll,
                onChanged: _toggleSelectAll,
              ),
              const SizedBox(width: 8),
              Text(
                'Select All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedReceiptIds.length} selected',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _selectedReceiptIds.isEmpty ? null : widget.onExportCSV,
                icon: const Icon(Icons.file_download, size: 18),
                label: const Text('Export CSV'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _selectedReceiptIds.isEmpty ? null : widget.onExportPDF,
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Export PDF'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _selectedReceiptIds.isEmpty ? null : widget.onPrintReceipts,
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print Receipts'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptsTable(BuildContext context) {
    if (widget.isLoading) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF905CFF)),
          ),
        ),
      );
    }

    if (widget.savedReceipts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No receipts found',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final currencySymbol = userProvider.currencySymbol ?? settingsProvider.currencySymbol ?? '₹';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                SizedBox(width: 40), // Checkbox space
                Expanded(flex: 3, child: _buildTableHeader('Receipt')),
                Expanded(flex: 2, child: _buildTableHeader('Category')),
                Expanded(flex: 2, child: _buildTableHeader('Amount')),
                Expanded(flex: 2, child: _buildTableHeader('Date')),
                Expanded(flex: 2, child: _buildTableHeader('')),
              ],
            ),
          ),
          // Table Rows
          ...widget.savedReceipts.map((receipt) {
            final receiptId = receipt['id']?.toString() ?? '';
            final merchant = receipt['merchant']?.toString() ?? 'Unknown';
            final amount = receipt['amount'];
            final amountValue = amount is num
                ? amount.toDouble()
                : (double.tryParse(amount?.toString() ?? '0') ?? 0.0);
            final category = receipt['category']?.toString() ?? 'Uncategorized';
            final status = receipt['status']?.toString().toLowerCase() ?? 'pending';

            String formattedDate = 'No date';
            if (receipt['receiptDate'] != null) {
              try {
                final dateStr = receipt['receiptDate'].toString();
                DateTime? date = DateTime.tryParse(dateStr);
                if (date == null) {
                  try {
                    final formatter = DateFormat('MM-dd-yyyy');
                    date = formatter.parse(dateStr);
                  } catch (e) {
                    // Keep null
                  }
                }
                if (date != null) {
                  formattedDate = DateFormat('MMM d, yyyy').format(date);
                }
              } catch (e) {
                // Keep default
              }
            }

            final categoryIcon = getCategoryIcon(category);
            final categoryColor = getCategoryColor(category);

            return Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Checkbox(
                        value: _selectedReceiptIds.contains(receiptId),
                        onChanged: (value) => _toggleReceiptSelection(receiptId, value),
                      ),
                    ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(categoryIcon, size: 20, color: categoryColor),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                merchant,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: categoryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '$currencySymbol${NumberFormat('#,##0.00').format(amountValue)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: () => widget.onReceiptTap(context, receipt),
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('View'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            foregroundColor: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildPagination(BuildContext context) {
    final totalPages = (widget.totalCount / 20).ceil();
    final startItem = ((widget.currentPage - 1) * 20) + 1;
    final endItem = (widget.currentPage * 20).clamp(0, widget.totalCount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem-$endItem of ${widget.totalCount} receipts',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: widget.currentPage > 1
                    ? () => widget.onPageChanged(widget.currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                disabledColor: Colors.grey.shade400,
              ),
              ...List.generate(
                totalPages.clamp(0, 5),
                (index) {
                  final page = index + 1;
                  final isActive = page == widget.currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: isActive ? const Color(0xFF905CFF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => widget.onPageChanged(page),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            '$page',
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey.shade700,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                onPressed: widget.hasNextPage
                    ? () => widget.onPageChanged(widget.currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                disabledColor: Colors.grey.shade400,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

