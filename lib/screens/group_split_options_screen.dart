import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import '../services/expense_group_service.dart';

class GroupSplitOptionsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<Map<String, dynamic>> selectedReceipts;
  final List<Map<String, dynamic>> groupMembers;
  final String userId;
  final String token;

  const GroupSplitOptionsScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.selectedReceipts,
    required this.groupMembers,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<GroupSplitOptionsScreen> createState() => _GroupSplitOptionsScreenState();
}

class _GroupSplitOptionsScreenState extends State<GroupSplitOptionsScreen> {
  String _splitMode = 'equal'; // 'equal', 'custom_amount', 'custom_percentage'
  double _totalAmount = 0.0;
  final Map<String, TextEditingController> _amountControllers = {};
  final Map<String, TextEditingController> _percentageControllers = {};
  final Set<String> _selectedMemberIds = <String>{};
  final Map<String, double> _memberAmounts = {};
  final Map<String, double> _memberPercentages = {};

  @override
  void initState() {
    super.initState();
    _calculateTotalAmount();
    _initializeMembers();
  }

  void _calculateTotalAmount() {
    double total = 0.0;
    for (var receipt in widget.selectedReceipts) {
      // Try multiple possible fields for amount
      final amountStr = receipt['amount']?.toString() ?? 
                       receipt['totalAmount']?.toString() ?? '0';
      // Remove currency symbols and parse
      final cleaned = amountStr.replaceAll(RegExp(r'[^\d.-]'), '');
      final amount = double.tryParse(cleaned) ?? 0.0;
      total += amount;
    }
    setState(() {
      _totalAmount = total;
    });
  }

  void _initializeMembers() {
    // Select all members by default
    for (var member in widget.groupMembers) {
      // Try multiple fields to get member identifier
      // Use memberId if available (from group members), otherwise use userId, id, or _id
      final memberId = member['memberId']?.toString() ?? 
                      member['userId']?.toString() ?? 
                      member['id']?.toString() ?? 
                      member['_id']?.toString() ?? '';
      
      // If still no ID, use email as fallback identifier
      final identifier = memberId.isNotEmpty 
          ? memberId 
          : (member['email']?.toString() ?? '');
      
      if (identifier.isNotEmpty) {
        _selectedMemberIds.add(identifier);
        _amountControllers[identifier] = TextEditingController();
        _percentageControllers[identifier] = TextEditingController();
        _memberAmounts[identifier] = 0.0;
        _memberPercentages[identifier] = 0.0;
      }
    }
    _applyEqualSplit();
  }

  void _applyEqualSplit() {
    if (_splitMode == 'equal' && _selectedMemberIds.isNotEmpty) {
      final equalAmount = _totalAmount / _selectedMemberIds.length;
      final equalPercentage = 100.0 / _selectedMemberIds.length;
      
      for (var memberId in _selectedMemberIds) {
        _memberAmounts[memberId] = equalAmount;
        _memberPercentages[memberId] = equalPercentage;
        _amountControllers[memberId]?.text = equalAmount.toStringAsFixed(2);
        _percentageControllers[memberId]?.text = equalPercentage.toStringAsFixed(2);
      }
    }
  }

  void _toggleMemberSelection(String memberId) {
    setState(() {
      if (_selectedMemberIds.contains(memberId)) {
        _selectedMemberIds.remove(memberId);
        _memberAmounts.remove(memberId);
        _memberPercentages.remove(memberId);
      } else {
        _selectedMemberIds.add(memberId);
        _memberAmounts[memberId] = 0.0;
        _memberPercentages[memberId] = 0.0;
        if (!_amountControllers.containsKey(memberId)) {
          _amountControllers[memberId] = TextEditingController();
          _percentageControllers[memberId] = TextEditingController();
        }
      }
      _applyEqualSplit();
    });
  }

  void _selectAllMembers() {
    setState(() {
      // Count valid members
      int validMemberCount = 0;
      for (var member in widget.groupMembers) {
        final memberId = member['memberId']?.toString() ?? 
                        member['userId']?.toString() ?? 
                        member['id']?.toString() ?? 
                        member['_id']?.toString() ?? '';
        final identifier = memberId.isNotEmpty 
            ? memberId 
            : (member['email']?.toString() ?? '');
        if (identifier.isNotEmpty) {
          validMemberCount++;
        }
      }
      
      if (_selectedMemberIds.length == validMemberCount) {
        _selectedMemberIds.clear();
        _memberAmounts.clear();
        _memberPercentages.clear();
      } else {
        for (var member in widget.groupMembers) {
          final memberId = member['memberId']?.toString() ?? 
                          member['userId']?.toString() ?? 
                          member['id']?.toString() ?? 
                          member['_id']?.toString() ?? '';
          final identifier = memberId.isNotEmpty 
              ? memberId 
              : (member['email']?.toString() ?? '');
          if (identifier.isNotEmpty) {
            _selectedMemberIds.add(identifier);
            if (!_amountControllers.containsKey(identifier)) {
              _amountControllers[identifier] = TextEditingController();
              _percentageControllers[identifier] = TextEditingController();
            }
            _memberAmounts[identifier] = 0.0;
            _memberPercentages[identifier] = 0.0;
          }
        }
        _applyEqualSplit();
      }
    });
  }

  bool _isAllMembersSelected() {
    int validMemberCount = 0;
    for (var member in widget.groupMembers) {
      final memberId = member['memberId']?.toString() ?? 
                      member['userId']?.toString() ?? 
                      member['id']?.toString() ?? 
                      member['_id']?.toString() ?? '';
      final identifier = memberId.isNotEmpty 
          ? memberId 
          : (member['email']?.toString() ?? '');
      if (identifier.isNotEmpty) {
        validMemberCount++;
      }
    }
    return _selectedMemberIds.length == validMemberCount && validMemberCount > 0;
  }

  void _updateMemberAmount(String memberId, String value) {
    final amount = double.tryParse(value) ?? 0.0;
    setState(() {
      _memberAmounts[memberId] = amount;
      if (_totalAmount > 0) {
        _memberPercentages[memberId] = (amount / _totalAmount) * 100.0;
        _percentageControllers[memberId]?.text = _memberPercentages[memberId]!.toStringAsFixed(2);
      }
    });
  }

  void _updateMemberPercentage(String memberId, String value) {
    final percentage = double.tryParse(value) ?? 0.0;
    setState(() {
      _memberPercentages[memberId] = percentage;
      _memberAmounts[memberId] = (_totalAmount * percentage) / 100.0;
      _amountControllers[memberId]?.text = _memberAmounts[memberId]!.toStringAsFixed(2);
    });
  }

  void _changeSplitMode(String mode) {
    setState(() {
      _splitMode = mode;
      if (mode == 'equal') {
        _applyEqualSplit();
      }
    });
  }

  double _getAmountPerPerson() {
    if (_selectedMemberIds.isEmpty) return 0.0;
    if (_splitMode == 'equal') {
      return _totalAmount / _selectedMemberIds.length;
    } else {
      double total = 0.0;
      for (var memberId in _selectedMemberIds) {
        total += _memberAmounts[memberId] ?? 0.0;
      }
      return total / _selectedMemberIds.length;
    }
  }

  // Get the paidBy userId from receipts
  String? _getPaidByUserId() {
    // For manual receipts, get paidBy from the receipt
    // If there are multiple receipts, we'll use the first one's paidBy
    // In practice, manual receipts are usually added one at a time
    for (var receipt in widget.selectedReceipts) {
      final paidBy = receipt['paidBy']?.toString() ?? '';
      if (paidBy.isNotEmpty) {
        return paidBy;
      }
    }
    return null;
  }

  // Calculate what a member owes or is owed
  Map<String, dynamic> _getMemberBalance(String memberId) {
    final paidByUserId = _getPaidByUserId();
    final memberShare = _memberAmounts[memberId] ?? 0.0;
    
    if (paidByUserId == null) {
      // No paidBy info, just show share
      return {
        'type': 'share',
        'amount': memberShare,
      };
    }
    
    if (memberId == paidByUserId) {
      // This person paid, so they are owed (total amount - their share)
      final owedAmount = _totalAmount - memberShare;
      return {
        'type': 'owed',
        'amount': owedAmount,
      };
    } else {
      // This person didn't pay, so they owe their share
      return {
        'type': 'owes',
        'amount': memberShare,
      };
    }
  }

  String _getMemberInitials(Map<String, dynamic> member) {
    final name = member['name']?.toString() ?? '';
    if (name.isEmpty) {
      final email = member['email']?.toString() ?? '';
      if (email.isNotEmpty) {
        return email[0].toUpperCase();
      }
      return '?';
    }
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getAvatarColor(String memberId) {
    final colors = [
      const Color(0xFF7E5EFD),
      const Color(0xFF22C55E),
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
    ];
    final index = memberId.hashCode % colors.length;
    return colors[index.abs()];
  }

  Future<void> _onDone() async {
    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one member'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate that shares sum equals total amount for each receipt
    // Note: When multiple receipts are selected, we validate against the total of all receipts
    // Each receipt will be split individually, but shares are distributed across all selected receipts
    double totalShares = 0.0;
    for (var memberId in _selectedMemberIds) {
      totalShares += _memberAmounts[memberId] ?? 0.0;
    }

    // Allow small floating point differences (0.01)
    if ((totalShares - _totalAmount).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Total shares (${totalShares.toStringAsFixed(2)}) must equal total amount (${_totalAmount.toStringAsFixed(2)})'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
        ),
      ),
    );

    try {
      // Process each receipt
      for (var receipt in widget.selectedReceipts) {
        final isManual = receipt['isManual'] == true;
        final receiptIdStr = receipt['id']?.toString() ?? '';
        
        // Check if this is a manual receipt (temporary ID) or existing receipt
        final isTemporaryReceipt = isManual && (receiptIdStr.length > 10 && receiptIdStr.contains(DateTime.now().millisecondsSinceEpoch.toString().substring(0, 10)));
        
        if (isManual || isTemporaryReceipt) {
          // Create manual receipt in group using POST /api/expense-groups/:groupId/receipts
          // This endpoint creates both the receipt and split bill atomically
          // Used for: manual receipts added after group creation, "+ add manually", and "+ add receipt to group"
          final merchant = receipt['merchant']?.toString() ?? '';
          final amount = double.tryParse(receipt['amount']?.toString() ?? '0') ?? 0.0;
          final receiptDate = receipt['receiptDate']?.toString() ?? '';
          final category = receipt['category']?.toString();
          final paidBy = receipt['paidBy']?.toString() ?? '';
          
          // Convert receipt date from MM-dd-yyyy to yyyy-MM-dd if needed
          String formattedDate = receiptDate;
          try {
            if (receiptDate.contains('-') && receiptDate.split('-').length == 3) {
              final parts = receiptDate.split('-');
              if (parts[0].length == 2) {
                // MM-dd-yyyy format, convert to yyyy-MM-dd
                formattedDate = '${parts[2]}-${parts[0]}-${parts[1]}';
              }
            } else {
              // Try parsing as DateTime and format
              final date = DateTime.parse(receiptDate);
              formattedDate = DateFormat('yyyy-MM-dd').format(date);
            }
          } catch (e) {
            // If parsing fails, try to use as-is or use current date
            debugPrint('Error parsing receipt date: $e');
            if (formattedDate.isEmpty) {
              formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
            }
          }

          // Build participants list from selected members
          final List<Map<String, dynamic>> participants = [];
          for (var identifier in _selectedMemberIds) {
            final member = widget.groupMembers.firstWhere(
              (m) {
                final memberId = m['memberId']?.toString() ?? 
                                m['userId']?.toString() ?? 
                                m['id']?.toString() ?? 
                                m['_id']?.toString() ?? '';
                final memberIdentifier = memberId.isNotEmpty 
                    ? memberId 
                    : (m['email']?.toString() ?? '');
                return memberIdentifier == identifier;
              },
              orElse: () => <String, dynamic>{},
            );

            if (member.isNotEmpty) {
              final email = member['email']?.toString() ?? '';
              final name = member['name']?.toString();
              final share = _memberAmounts[identifier] ?? 0.0;

              if (email.isNotEmpty) {
                participants.add({
                  'email': email,
                  'share': share,
                  if (name != null && name.isNotEmpty) 'name': name,
                });
              }
            }
          }

          // NEW API: Use paidByEmail (email string) instead of paidBy (userId)
          // Convert paidBy to email if it's a userId
          String? paidByEmail;
          
          // Check if paidBy is a UUID (userId) or email
          if (paidBy.contains('-') && paidBy.length >= 30) {
            // It's a userId, find the corresponding email
            for (var member in widget.groupMembers) {
              final memberId = member['userId']?.toString() ?? 
                              member['id']?.toString() ?? 
                              member['_id']?.toString() ?? '';
              if (memberId == paidBy) {
                paidByEmail = member['email']?.toString() ?? '';
                break;
              }
            }
          } else {
            // It's already an email
            paidByEmail = paidBy;
          }

          // Determine if receipt should show in personal receipts
          // Get current user's email from UserProvider
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final currentUserEmail = userProvider.email?.toLowerCase() ?? '';
          final paidByEmailLower = paidByEmail?.toLowerCase() ?? '';
          
          // Only show in personal receipts if the payer matches the current user
          final showInPersonalReceipts = paidByEmailLower.isNotEmpty && 
                                        currentUserEmail.isNotEmpty && 
                                        paidByEmailLower == currentUserEmail;
          
          debugPrint('💳 Receipt paidByEmail: $paidByEmailLower');
          debugPrint('👤 Current user email: $currentUserEmail');
          debugPrint('📋 showInPersonalReceipts: $showInPersonalReceipts');

          final result = await ExpenseGroupService.createReceiptInGroup(
            groupId: widget.groupId,
            merchant: merchant,
            amount: amount,
            receiptDate: formattedDate,
            paidByEmail: paidByEmail,
            createdBy: widget.userId,
            participants: participants,
            category: category,
            showInPersonalReceipts: showInPersonalReceipts,
            token: widget.token,
          );

          if (result['success'] != true) {
            // Error - show message and stop
            Navigator.pop(context); // Close loading dialog
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['error']?.toString() ?? 'Failed to create receipt'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        } else {
          // Existing receipt - use Method 1: POST /api/split-bill
          // Split an existing receipt among group members
          final receiptIdStr = receipt['id']?.toString() ?? '';
          final receiptIdInt = int.tryParse(receiptIdStr);
          
          // Skip receipts with non-numeric IDs (e.g., demo/test receipts)
          // The API requires receiptId to be a number
          if (receiptIdInt == null) {
            debugPrint('Skipping receipt with non-numeric ID: $receiptIdStr (likely a demo/test receipt)');
            continue; // Skip this receipt and continue with others
          }

          // Get this receipt's amount for validation
          // Try multiple possible fields for amount
          final receiptAmountStr = receipt['amount']?.toString() ?? 
                                  receipt['totalAmount']?.toString() ?? '0';
          final receiptAmount = double.tryParse(receiptAmountStr.replaceAll(RegExp(r'[^\d.-]'), '')) ?? 0.0;
          
          if (receiptAmount == 0.0) {
            debugPrint('Warning: Receipt $receiptIdStr has zero or invalid amount');
          }

          // Build participants list from selected members
          // For multiple receipts: split each receipt equally among selected members
          // For single receipt: use the shares from _memberAmounts
          final List<Map<String, dynamic>> participants = [];
          double receiptTotalShares = 0.0;
          
          if (widget.selectedReceipts.length == 1) {
            // Single receipt: use the shares from user input
            for (var identifier in _selectedMemberIds) {
              final member = widget.groupMembers.firstWhere(
                (m) {
                  final memberId = m['memberId']?.toString() ?? 
                                  m['userId']?.toString() ?? 
                                  m['id']?.toString() ?? 
                                  m['_id']?.toString() ?? '';
                  final memberIdentifier = memberId.isNotEmpty 
                      ? memberId 
                      : (m['email']?.toString() ?? '');
                  return memberIdentifier == identifier;
                },
                orElse: () => <String, dynamic>{},
              );

              if (member.isNotEmpty) {
                final email = member['email']?.toString() ?? '';
                final name = member['name']?.toString();
                final share = _memberAmounts[identifier] ?? 0.0;
                receiptTotalShares += share;

                if (email.isNotEmpty) {
                  participants.add({
                    'email': email,
                    'share': share,
                    if (name != null && name.isNotEmpty) 'name': name,
                  });
                }
              }
            }
          } else {
            // Multiple receipts: split each receipt equally among selected members
            final equalShare = receiptAmount / _selectedMemberIds.length;
            for (var identifier in _selectedMemberIds) {
              final member = widget.groupMembers.firstWhere(
                (m) {
                  final memberId = m['memberId']?.toString() ?? 
                                  m['userId']?.toString() ?? 
                                  m['id']?.toString() ?? 
                                  m['_id']?.toString() ?? '';
                  final memberIdentifier = memberId.isNotEmpty 
                      ? memberId 
                      : (m['email']?.toString() ?? '');
                  return memberIdentifier == identifier;
                },
                orElse: () => <String, dynamic>{},
              );

              if (member.isNotEmpty) {
                final email = member['email']?.toString() ?? '';
                final name = member['name']?.toString();
                receiptTotalShares += equalShare;

                if (email.isNotEmpty) {
                  participants.add({
                    'email': email,
                    'share': equalShare,
                    if (name != null && name.isNotEmpty) 'name': name,
                  });
                }
              }
            }
          }
          
          // Validate shares for this receipt
          if ((receiptTotalShares - receiptAmount).abs() > 0.01) {
            debugPrint('Warning: Receipt $receiptIdStr shares (${receiptTotalShares.toStringAsFixed(2)}) do not match amount (${receiptAmount.toStringAsFixed(2)})');
            // Adjust shares proportionally to match receipt amount
            if (receiptTotalShares > 0) {
              final adjustmentFactor = receiptAmount / receiptTotalShares;
              for (var participant in participants) {
                participant['share'] = (participant['share'] as double) * adjustmentFactor;
              }
            }
          }
          
          debugPrint('Creating split bill for receipt $receiptIdInt: amount=$receiptAmount, participants=${participants.length}');

          // NEW API: Get paidByEmail if available from receipt
          String? paidByEmail;
          final paidBy = receipt['paidBy']?.toString() ?? '';
          if (paidBy.isNotEmpty) {
            // Check if paidBy is a UUID (userId) or email
            if (paidBy.contains('-') && paidBy.length >= 30) {
              // It's a userId, find the corresponding email
              for (var member in widget.groupMembers) {
                final memberId = member['userId']?.toString() ?? 
                                member['id']?.toString() ?? 
                                member['_id']?.toString() ?? '';
                if (memberId == paidBy) {
                  paidByEmail = member['email']?.toString() ?? '';
                  break;
                }
              }
            } else {
              // It's already an email
              paidByEmail = paidBy;
            }
          }

          // Create split bill for existing receipt
          final result = await ExpenseGroupService.createSplitBillForReceipt(
            receiptId: receiptIdInt,
            createdBy: widget.userId,
            participants: participants,
            groupId: widget.groupId,
            paidByEmail: paidByEmail,
            token: widget.token,
          );

          if (result['success'] != true) {
            // Error - show message and stop
            Navigator.pop(context); // Close loading dialog
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['error']?.toString() ?? 'Failed to create split bill'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }
      }

      Navigator.pop(context); // Close loading dialog

      // All receipts created successfully
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt(s) added to group successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      debugPrint('Error creating receipt in group: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // All receipts created successfully
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt(s) added to group successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    for (var controller in _amountControllers.values) {
      controller.dispose();
    }
    for (var controller in _percentageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currencySymbol = userProvider.effectiveCurrencySymbol;
    final amountPerPerson = _getAmountPerPerson();
    final selectedCount = _selectedMemberIds.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Split options',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _onDone,
            child: const Text(
              'Done',
              style: TextStyle(
                color: Color(0xFF22C55E),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Split method selection
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Split method icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSplitMethodIcon(
                      icon: null,
                      isSelected: _splitMode == 'equal',
                      onTap: () => _changeSplitMode('equal'),
                      customText: '=',
                    ),
                    _buildSplitMethodIcon(
                      icon: null, // Custom icon - will show "1.23" in a block
                      isSelected: _splitMode == 'custom_amount',
                      onTap: () => _changeSplitMode('custom_amount'),
                      customText: '1.23',
                    ),
                    _buildSplitMethodIcon(
                      icon: Icons.percent,
                      isSelected: _splitMode == 'custom_percentage',
                      onTap: () => _changeSplitMode('custom_percentage'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _splitMode == 'equal'
                      ? 'Split equally'
                      : _splitMode == 'custom_amount'
                          ? 'Split by amount'
                          : 'Split by percentage',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _splitMode == 'equal'
                      ? 'Select which people owe an equal share.'
                      : _splitMode == 'custom_amount'
                          ? 'Enter custom amounts for each person.'
                          : 'Enter percentages for each person.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Spacing between description and summary/input
          SizedBox(height: _splitMode == 'equal' ? 12 : 8),

          // Input bar (only show for custom modes)
          if (_splitMode != 'equal')
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.equalizer,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: _totalAmount.toStringAsFixed(2)),
                      decoration: InputDecoration(
                        labelText: 'Total Amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      enabled: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 60,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Text(
                        _splitMode == 'custom_percentage' ? '%' : currencySymbol,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_splitMode != 'equal') const SizedBox(height: 12),

          // Summary bar above members
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$currencySymbol${amountPerPerson.toStringAsFixed(2)}/person',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '($selectedCount ${selectedCount == 1 ? 'person' : 'people'})',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text(
                      'All',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _selectAllMembers,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isAllMembersSelected()
                              ? const Color(0xFF22C55E)
                              : Colors.transparent,
                          border: Border.all(
                            color: _isAllMembersSelected()
                                ? const Color(0xFF22C55E)
                                : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: _isAllMembersSelected()
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Member list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.groupMembers.length,
              itemBuilder: (context, index) {
                final member = widget.groupMembers[index];
                // Use same identifier logic as _initializeMembers
                final memberId = member['memberId']?.toString() ?? 
                                member['userId']?.toString() ?? 
                                member['id']?.toString() ?? 
                                member['_id']?.toString() ?? '';
                final identifier = memberId.isNotEmpty 
                    ? memberId 
                    : (member['email']?.toString() ?? '');
                final name = member['name']?.toString() ?? 'Unknown';
                final isSelected = _selectedMemberIds.contains(identifier);
                final avatarColor = _getAvatarColor(identifier);

                final balance = isSelected ? _getMemberBalance(identifier) : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: avatarColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _getMemberInitials(member),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                // Show owes/owed when selected
                                if (isSelected && balance != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    balance['type'] == 'owed'
                                        ? 'Owed: $currencySymbol${balance['amount'].toStringAsFixed(2)}'
                                        : balance['type'] == 'owes'
                                            ? 'Owes: $currencySymbol${balance['amount'].toStringAsFixed(2)}'
                                            : 'Share: $currencySymbol${balance['amount'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: balance['type'] == 'owed'
                                          ? Colors.green.shade700
                                          : balance['type'] == 'owes'
                                              ? Colors.orange.shade700
                                              : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Custom amount/percentage input (only for custom modes)
                          if (_splitMode != 'equal' && isSelected) ...[
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _splitMode == 'custom_amount'
                                    ? _amountControllers[identifier]
                                    : _percentageControllers[identifier],
                                decoration: InputDecoration(
                                  hintText: _splitMode == 'custom_amount' ? '0.00' : '0',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  if (_splitMode == 'custom_amount') {
                                    _updateMemberAmount(identifier, value);
                                  } else {
                                    _updateMemberPercentage(identifier, value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Selection checkbox
                          GestureDetector(
                            onTap: () => _toggleMemberSelection(identifier),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? const Color(0xFF22C55E) : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF22C55E) : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitMethodIcon({
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? customText,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF7E5EFD) : Colors.transparent,
            width: 2,
          ),
        ),
        child: customText != null
            ? Center(
                child: Text(
                  customText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              )
            : Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 24,
              ),
      ),
    );
  }
}

