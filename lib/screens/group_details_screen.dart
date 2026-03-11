import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/receipt_save_result.dart';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';
import '../services/expense_group_service.dart';
import '../utils/payment_helper.dart';
import '../widgets/styled_dropdown.dart';
import 'group_receipt_selection_screen.dart';
import 'group_split_options_screen.dart';
import 'receipt_details_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String userId;
  final String token;
  final Map<String, dynamic>? initialData; // Optional initial data for mock/testing

  const GroupDetailsScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.userId,
    required this.token,
    this.initialData,
  }) : super(key: key);

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  Map<String, dynamic>? groupData;
  List<Map<String, dynamic>> expenses = [];
  List<Map<String, dynamic>> settlements = [];
  bool isLoading = true;
  bool _loadingCategories = false;
  List<String> _categories = [];
  List<String> _filteredCategories = [];

  @override
  void initState() {
    super.initState();
    // If initial data is provided (for mock/testing), use it directly
    // Otherwise, load from API
    if (widget.initialData != null) {
      _processGroupData(widget.initialData!);
    } else {
      _loadGroupData();
    }
  }

  void _processGroupData(dynamic data) {
    // Convert data to Map<String, dynamic> if it's not already
    final Map<String, dynamic> groupMap = data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map);
    
    // Calculate yourBalance based on current user
    double yourBalance = 0.0;
    final participantsList = groupMap['participants'] ?? [];
    final participants = participantsList is List ? participantsList : [];
    
    // Find current user's balance from participants
    for (var participant in participants) {
      // Convert participant to Map<String, dynamic>
      final Map<String, dynamic> participantMap = participant is Map<String, dynamic>
          ? participant
          : Map<String, dynamic>.from(participant as Map);
      
      final userId = participantMap['userId']?.toString() ?? 
                    participantMap['id']?.toString() ?? 
                    participantMap['_id']?.toString();
      if (userId == widget.userId) {
        // Balance can be in different fields: balance, amount, share, etc.
        final balance = participantMap['balance'] ?? 
                       participantMap['amount'] ?? 
                       participantMap['share'] ?? 
                       participantMap['owed'] ?? 0.0;
        yourBalance = (balance is num) ? balance.toDouble() : 
                     double.tryParse(balance.toString()) ?? 0.0;
        break;
      }
    }
    
    // Ensure participants have balance field
    final processedParticipants = participants.map((p) {
      // Convert participant to Map<String, dynamic>
      final Map<String, dynamic> participantMap = p is Map<String, dynamic>
          ? p
          : Map<String, dynamic>.from(p as Map);
      
      final balance = participantMap['balance'] ?? 
                     participantMap['amount'] ?? 
                     participantMap['share'] ?? 
                     participantMap['owed'] ?? 0.0;
      return {
        ...participantMap,
        'balance': (balance is num) ? balance.toDouble() : 
                  double.tryParse(balance.toString()) ?? 0.0,
      };
    }).toList();
    
    // Extract expenses if present (only if not already set from API)
    final expensesList = groupMap['expenses'] as List<dynamic>? ?? [];
    
    setState(() {
      groupData = {
        ...groupMap,
        'totalAmount': (groupMap['totalAmount'] ?? groupMap['total'] ?? 0.0) is num 
            ? (groupMap['totalAmount'] ?? groupMap['total'] ?? 0.0).toDouble()
            : double.tryParse((groupMap['totalAmount'] ?? groupMap['total'] ?? 0.0).toString()) ?? 0.0,
        'yourBalance': yourBalance,
        'participants': processedParticipants,
      };
      // Only set expenses if they're not already set (from _loadGroupData)
      // This prevents overwriting properly mapped expenses
      if (expenses.isEmpty && expensesList.isNotEmpty) {
        expenses = expensesList.map((expense) {
          final expenseMap = expense as Map<String, dynamic>;
          // Map expenses with proper structure
          final receipt = expenseMap['receipt'] as Map<String, dynamic>? ?? {};
          final participantsRaw = expenseMap['participants'] as List<dynamic>? ?? [];
          final participants = participantsRaw.map((p) {
            if (p is Map<String, dynamic>) {
              return Map<String, dynamic>.from(p);
            }
            return <String, dynamic>{};
          }).toList();
          
          return {
            'id': expenseMap['id'],
            'receiptId': expenseMap['receiptId'],
            'totalAmount': expenseMap['totalAmount']?.toString() ?? '0',
            'paidBy': expenseMap['paidBy'],
            'paidByUser': expenseMap['paidByUser'],
            'receipt': {
              'id': receipt['id'],
              'merchant': receipt['merchant']?.toString() ?? 'Unknown',
              'category': receipt['category']?.toString() ?? '',
              'receiptDate': receipt['receiptDate']?.toString() ?? '',
            },
            'participants': participants,
            'status': expenseMap['status']?.toString() ?? 'active',
            'createdAt': expenseMap['createdAt']?.toString(),
          };
        }).toList();
      }
      isLoading = false;
    });
  }

  Future<void> _loadGroupData() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final result = await ExpenseGroupService.getGroupDetails(
        groupId: widget.groupId,
        userId: widget.userId,
        token: userProvider.token,
      );

      // Fetch settlements
      final settlementsResult = await ExpenseGroupService.getSettlements(
        groupId: widget.groupId,
        userId: widget.userId,
        token: userProvider.token,
      );

      // Store settlements data
      List<Map<String, dynamic>> settlementsList = [];
      if (settlementsResult['success'] == true) {
        final settlementsData = settlementsResult['data'] as List<dynamic>? ?? [];
        settlementsList = settlementsData.map((s) {
          if (s is Map<String, dynamic>) {
            return Map<String, dynamic>.from(s);
          }
          return <String, dynamic>{};
        }).toList();
        debugPrint('📊 Loaded ${settlementsList.length} settlements');
      }

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final group = data['group'] as Map<String, dynamic>;
        final expensesList = data['expenses'] as List<dynamic>? ?? [];
        final balances = data['balances'] as List<dynamic>? ?? [];

        // Store expenses for display - map API response to expected format
        debugPrint('📊 Loading expenses: ${expensesList.length} items');
        setState(() {
          settlements = settlementsList;
          expenses = expensesList.map((expense) {
            final expenseMap = expense as Map<String, dynamic>;
            
            // Extract receipt data
            final receipt = expenseMap['receipt'] as Map<String, dynamic>? ?? {};
            
            // Extract paidByUser data
            final paidByUserRaw = expenseMap['paidByUser'];
            final paidByUser = paidByUserRaw != null && paidByUserRaw is Map<String, dynamic>
                ? Map<String, dynamic>.from(paidByUserRaw)
                : <String, dynamic>{};
            
            // Extract participants
            final participantsRaw = expenseMap['participants'] as List<dynamic>? ?? [];
            final participants = participantsRaw.map((p) {
              if (p is Map<String, dynamic>) {
                return Map<String, dynamic>.from(p);
              }
              return <String, dynamic>{};
            }).toList();
            
            // Parse totalAmount - preserve formatted string from API (e.g., "₹234.00")
            // API returns totalAmount as formatted string, so preserve it as-is
            final totalAmountRaw = expenseMap['totalAmount'];
            final totalAmount = totalAmountRaw?.toString() ?? '0';
            
            // Debug print for each expense
            debugPrint('  - Expense: merchant=${receipt['merchant']}, amount=$totalAmount, participants=${participants.length}');
            
            // Return mapped expense with all required fields
            return {
              'id': expenseMap['id'],
              'receiptId': expenseMap['receiptId'],
              'totalAmount': totalAmount,
              'paidBy': expenseMap['paidBy'],
              'paidByUser': paidByUser,
              'receipt': {
                'id': receipt['id'],
                'merchant': receipt['merchant']?.toString() ?? 'Unknown',
                'category': receipt['category']?.toString() ?? '',
                'receiptDate': receipt['receiptDate']?.toString() ?? '',
              },
              'participants': participants,
              'status': expenseMap['status']?.toString() ?? 'active',
              'createdAt': expenseMap['createdAt']?.toString(),
            };
          }).toList();
          debugPrint('✅ Expenses mapped: ${expenses.length} items');
        });

        // Transform the API response to match the expected format
        final transformedData = {
          ...group,
          'participants': balances.isNotEmpty 
              ? balances.map((balance) {
                  final balanceMap = balance as Map<String, dynamic>;
                  return {
                    'userId': balanceMap['userId'],
                    'email': balanceMap['email'],
                    'name': balanceMap['name'],
                    'balance': _parseBalance(balanceMap['balance']),
                    'balanceRaw': balanceMap['balanceRaw'],
                    'balanceFormatted': balanceMap['balance'],
                    'memberId': balanceMap['memberId'],
                    'owes': balanceMap['owes'] ?? 0,
                    'owed': balanceMap['owed'] ?? 0,
                    'owesBreakdown': balanceMap['owesBreakdown'] ?? [],
                    'owedBreakdown': balanceMap['owedBreakdown'] ?? [],
                  };
                }).toList()
              : (group['members'] as List<dynamic>? ?? []).map((member) {
                  final memberMap = member as Map<String, dynamic>;
                  return {
                    'userId': memberMap['userId'],
                    'email': memberMap['email'],
                    'name': memberMap['name'],
                    'balance': 0.0,
                    'balanceRaw': 0,
                    'balanceFormatted': '0.00',
                    'owes': 0,
                    'owed': 0,
                    'owesBreakdown': [],
                    'owedBreakdown': [],
                  };
                }).toList(),
          'totalAmount': expensesList.fold<double>(
            0.0,
            (sum, expense) {
              final expenseMap = expense as Map<String, dynamic>;
              final totalAmount = expenseMap['totalAmount']?.toString() ?? '0';
              final amount = _parseAmount(totalAmount);
              return sum + amount;
            },
          ),
        };

        // Store settlements
        if (settlementsResult['success'] == true) {
          final settlementsList = settlementsResult['data'] as List<dynamic>? ?? [];
          setState(() {
            settlements = settlementsList.map((s) {
              if (s is Map<String, dynamic>) {
                return Map<String, dynamic>.from(s);
              }
              return <String, dynamic>{};
            }).toList();
          });
        }
        
        _processGroupData(transformedData);
      } else {
        setState(() {
          isLoading = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error']?.toString() ?? 'Failed to load group details'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading group data: $e');
      setState(() {
        isLoading = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading group details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGroupSettingsMenu() {
    final createdBy = groupData?['createdBy']?.toString() ?? '';
    final isCreator = createdBy == widget.userId;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_add, color: Color(0xFF7E5EFD)),
                title: const Text(
                  'Add Member',
                  style: TextStyle(color: Color(0xFF7E5EFD), fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAddMemberDialog();
                },
              ),
              if (isCreator)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete Group',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteGroup();
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.exit_to_app,
                  color: isCreator ? Colors.red : Colors.orange.shade700,
                ),
                title: Text(
                  isCreator ? 'Remove Member' : 'Leave Group',
                  style: TextStyle(
                    color: isCreator ? Colors.red : Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (isCreator) {
                    _showRemoveMemberDialog();
                  } else {
                    _confirmLeaveGroup();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddMemberDialog() async {
    // Show loading dialog while fetching contacts
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
        ),
      ),
    );

    // Fetch contacts excluding existing group members
    List<Map<String, dynamic>> contacts = [];

    try {
      final result = await ExpenseGroupService.getContacts(
        userId: widget.userId,
        token: widget.token,
        groupId: widget.groupId,
        page: 1,
        limit: 50,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        final allContacts = List<Map<String, dynamic>>.from(result['data'] ?? []);
        
        // Filter contacts with valid email addresses
        contacts = allContacts.where((contact) {
          final hasValidEmail = contact['email'] != null && 
                               contact['email'].toString().trim().isNotEmpty &&
                               contact['email'].toString().trim() != 'null';
          return hasValidEmail;
        }).toList();
        
        // Sort contacts: saved contacts first, then unsaved
        contacts.sort((a, b) {
          final aIsSaved = a['isSavedContact'] == true;
          final bIsSaved = b['isSavedContact'] == true;
          
          if (aIsSaved && !bIsSaved) return -1;
          if (!aIsSaved && bIsSaved) return 1;
          
          final aName = aIsSaved ? (a['name']?.toString() ?? '') : a['email']?.toString() ?? '';
          final bName = bIsSaved ? (b['name']?.toString() ?? '') : b['email']?.toString() ?? '';
          return aName.toLowerCase().compareTo(bName.toLowerCase());
        });
      }
    } catch (e) {
      debugPrint("Error fetching contacts: $e");
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final Set<String> selectedContactIds = <String>{};

    final selectedContacts = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String getContactInitials(Map<String, dynamic> contact) {
              final name = contact['name']?.toString() ?? '';
              if (name.isEmpty) {
                final email = contact['email']?.toString() ?? '';
                if (email.isNotEmpty) return email[0].toUpperCase();
                return '?';
              }
              final parts = name.trim().split(' ');
              if (parts.length >= 2) {
                return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
              }
              return name[0].toUpperCase();
            }

            void toggleContact(String contactId) {
              setDialogState(() {
                if (selectedContactIds.contains(contactId)) {
                  selectedContactIds.remove(contactId);
                } else {
                  selectedContactIds.add(contactId);
                }
              });
            }

            List<Map<String, dynamic>> getSelectedContacts() {
              return contacts.where((contact) {
                final contactId = contact['id']?.toString() ?? 
                                  contact['_id']?.toString() ?? 
                                  contact['contactId']?.toString() ??
                                  contact['email']?.toString() ?? 
                                  '';
                return contactId.isNotEmpty && selectedContactIds.contains(contactId);
              }).toList();
            }

            // Calculate approximate height needed
            // Header: ~64px, Footer: ~80px, Each ListTile: ~72px
            final headerHeight = 64.0;
            final footerHeight = 80.0;
            final itemHeight = 72.0;
            final maxScreenHeight = MediaQuery.of(context).size.height * 0.7;
            final availableHeight = maxScreenHeight - headerHeight - footerHeight;
            final totalItemsHeight = contacts.length * itemHeight;
            final shouldScroll = totalItemsHeight > availableHeight;
            
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: maxScreenHeight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF7E5EFD),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add Members',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 24),
                            onPressed: () => Navigator.of(dialogContext).pop(null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Contact List
                    contacts.isEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.contacts_outlined, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  'No contacts available',
                                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'All your contacts are already members',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : shouldScroll
                            ? SizedBox(
                                height: availableHeight,
                                child: ListView.builder(
                                  itemCount: contacts.length,
                                  itemBuilder: (context, index) {
                                    final contact = contacts[index];
                                    final contactId = contact['id']?.toString() ?? 
                                                      contact['_id']?.toString() ?? 
                                                      contact['email']?.toString() ?? '';
                                    final isSelected = selectedContactIds.contains(contactId);
                                    final name = contact['name']?.toString() ?? 'Unknown';
                                    final email = contact['email']?.toString() ?? '';
                                    final initials = getContactInitials(contact);

                                    return ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF7E5EFD),
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
                                      title: Text(
                                        name,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Text(
                                        email,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                      trailing: Checkbox(
                                        value: isSelected,
                                        onChanged: (value) => toggleContact(contactId),
                                        activeColor: const Color(0xFF7E5EFD),
                                      ),
                                      onTap: () => toggleContact(contactId),
                                    );
                                  },
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: contacts.length,
                                itemBuilder: (context, index) {
                                  final contact = contacts[index];
                                  final contactId = contact['id']?.toString() ?? 
                                                    contact['_id']?.toString() ?? 
                                                    contact['email']?.toString() ?? '';
                                  final isSelected = selectedContactIds.contains(contactId);
                                  final name = contact['name']?.toString() ?? 'Unknown';
                                  final email = contact['email']?.toString() ?? '';
                                  final initials = getContactInitials(contact);

                                  return ListTile(
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF7E5EFD),
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
                                    title: Text(
                                      name,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      email,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    trailing: Checkbox(
                                      value: isSelected,
                                      onChanged: (value) => toggleContact(contactId),
                                      activeColor: const Color(0xFF7E5EFD),
                                    ),
                                    onTap: () => toggleContact(contactId),
                                  );
                                },
                              ),
                    // Footer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(dialogContext).pop(null),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Color(0xFF7E5EFD)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Color(0xFF7E5EFD), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: selectedContactIds.isEmpty
                                  ? null
                                  : () {
                                      final selected = getSelectedContacts();
                                      Navigator.of(dialogContext).pop(selected);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7E5EFD),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                disabledBackgroundColor: Colors.grey.shade300,
                              ),
                              child: Text(
                                'Add ${selectedContactIds.length > 0 ? "(${selectedContactIds.length})" : ""}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedContacts != null && selectedContacts.isNotEmpty && mounted) {
      await _addMembersToGroup(selectedContacts);
    }
  }

  Future<void> _addMembersToGroup(List<Map<String, dynamic>> members) async {
    if (members.isEmpty) return;

    // Show loading indicator
    if (!mounted) return;
    
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
      final result = await ExpenseGroupService.addMembers(
        groupId: widget.groupId,
        addedBy: widget.userId,
        members: members.map((m) => {
          'email': m['email']?.toString() ?? '',
          if (m['name'] != null) 'name': m['name'],
        }).toList(),
        token: widget.token,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        // Reload group data to show new members
        await _loadGroupData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${members.length} member(s) added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error']?.toString() ?? 'Failed to add members'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding members: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDeleteGroup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Group'),
          content: const Text(
            'Are you sure you want to delete this group? This action cannot be undone and all expenses will be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteGroup();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveMemberDialog() {
    final membersList = groupData?['participants'] as List<dynamic>? ?? [];
    final members = membersList is List ? membersList : [];
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF7E5EFD),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Remove Member',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final Map<String, dynamic> memberMap = members[index] is Map<String, dynamic>
                          ? members[index]
                          : Map<String, dynamic>.from(members[index] as Map);
                      
                      final userId = memberMap['userId']?.toString() ?? '';
                      final memberId = memberMap['memberId']?.toString() ?? '';
                      final name = memberMap['name']?.toString() ?? 'Unknown';
                      final email = memberMap['email']?.toString() ?? '';
                      final initials = _getMemberInitials(memberMap);
                      final isCurrentUser = userId == widget.userId;
                      
                      // Don't allow removing themselves through this dialog
                      if (isCurrentUser) {
                        return const SizedBox.shrink();
                      }
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _getAvatarColorForMember(memberMap),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 24,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmRemoveMember(memberId, name);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmRemoveMember(String memberId, String memberName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Member'),
          content: Text(
            'Are you sure you want to remove $memberName from this group?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removeMember(memberId);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Leave Group'),
          content: const Text(
            'Are you sure you want to leave this group? You will no longer have access to this group.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _leaveGroup();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
              ),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
  }

  void _showReminderConfirmationDialog() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final membersList = groupData?['participants'] ?? [];
    final List<Map<String, dynamic>> members = (membersList is List 
        ? membersList.map((m) {
            if (m is Map<String, dynamic>) {
              return m;
            } else if (m is Map) {
              return Map<String, dynamic>.from(m);
            } else {
              return <String, dynamic>{};
            }
          }).toList()
        : <Map<String, dynamic>>[]);

    // Count members who owe money
    int membersWhoOwe = 0;
    for (var member in members) {
      final memberMap = member is Map<String, dynamic> ? member : Map<String, dynamic>.from(member as Map);
      final balance = double.tryParse(memberMap['balance']?.toString() ?? '0') ?? 0.0;
      final memberUserId = memberMap['userId']?.toString() ?? '';
      final memberEmail = memberMap['email']?.toString().toLowerCase() ?? '';
      final currentUserEmail = userProvider.email?.toLowerCase() ?? '';
      final isCurrentUser = (memberUserId == widget.userId) || 
                           (memberEmail.isNotEmpty && memberEmail == currentUserEmail);
      
      if (balance < 0 && !isCurrentUser) {
        membersWhoOwe++;
      }
    }

    if (membersWhoOwe == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No members owe you money.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Send Reminder'),
          content: Text(
            'Do you want to send the reminder email to all the members who owe you?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _sendReminderEmails();
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7E5EFD),
              ),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendReminderEmails() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final membersList = groupData?['participants'] ?? [];
    final List<Map<String, dynamic>> members = (membersList is List 
        ? membersList.map((m) {
            if (m is Map<String, dynamic>) {
              return m;
            } else if (m is Map) {
              return Map<String, dynamic>.from(m);
            } else {
              return <String, dynamic>{};
            }
          }).toList()
        : <Map<String, dynamic>>[]);

    // Get members who owe money (balance < 0) and are not the current user
    List<Map<String, dynamic>> membersWhoOwe = [];
    for (var member in members) {
      final memberMap = member is Map<String, dynamic> ? member : Map<String, dynamic>.from(member as Map);
      final balance = double.tryParse(memberMap['balance']?.toString() ?? '0') ?? 0.0;
      final memberUserId = memberMap['userId']?.toString() ?? '';
      final memberEmail = memberMap['email']?.toString().toLowerCase() ?? '';
      final currentUserEmail = userProvider.email?.toLowerCase() ?? '';
      final isCurrentUser = (memberUserId == widget.userId) || 
                           (memberEmail.isNotEmpty && memberEmail == currentUserEmail);
      
      if (balance < 0 && !isCurrentUser) {
        membersWhoOwe.add(memberMap);
      }
    }

    if (membersWhoOwe.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No members owe you money.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Prepare the request body with member details who owe money
      final requestBody = {
        'groupId': widget.groupId,
        'userId': widget.userId,
        'members': membersWhoOwe.map((member) {
          final balance = double.tryParse(member['balance']?.toString() ?? '0') ?? 0.0;
          return {
            'userId': member['userId']?.toString() ?? '',
            'email': member['email']?.toString() ?? '',
            'name': member['name']?.toString() ?? 'Unknown',
            'outstandingAmount': balance.abs(), // Convert negative balance to positive amount owed
          };
        }).toList(),
      };

      final response = await ApiService.post(
        '/expense-groups/${widget.groupId}/send-reminders',
        body: requestBody,
        token: userProvider.token,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder emails sent to ${membersWhoOwe.length} member(s).'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error'] ?? errorData['message'] ?? 'Failed to send reminder emails';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending reminder emails: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteGroup() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    if (!context.mounted) return;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await ExpenseGroupService.deleteGroup(
        groupId: widget.groupId,
        token: userProvider.token,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back to previous screen
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Failed to delete group'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting group: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeMember(String memberId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    if (memberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid member ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!context.mounted) return;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await ExpenseGroupService.removeMember(
        groupId: widget.groupId,
        memberId: memberId,
        token: userProvider.token,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload group data to reflect changes
        _loadGroupData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Failed to remove member'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing member: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _leaveGroup() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Find current user's member ID from participants
    final participantsList = groupData?['participants'] as List<dynamic>? ?? [];
    String? memberId;
    
    // Find from participants (which have memberId from balances mapping)
    for (var participant in participantsList) {
      final participantMap = participant as Map<String, dynamic>;
      final userId = participantMap['userId']?.toString();
      if (userId == widget.userId) {
        memberId = participantMap['memberId']?.toString();
        break;
      }
    }

    // If not found, reload group data to get fresh member information
    if (memberId == null || memberId.isEmpty) {
      if (!context.mounted) return;
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Reload group data
      await _loadGroupData();
      
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      // Try again after reload
      final refreshedParticipants = groupData?['participants'] as List<dynamic>? ?? [];
      for (var participant in refreshedParticipants) {
        final participantMap = participant as Map<String, dynamic>;
        final userId = participantMap['userId']?.toString();
        if (userId == widget.userId) {
          memberId = participantMap['memberId']?.toString();
          break;
        }
      }
      
      if (memberId == null || memberId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to find your membership in this group'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await ExpenseGroupService.removeMember(
        groupId: widget.groupId,
        memberId: memberId,
        token: userProvider.token,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the group'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back to previous screen since user left
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Failed to leave group'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error leaving group: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Check if a member is settled based on settlements data
  /// A member is considered settled if:
  /// 1. Their balance is 0
  /// 2. They are the fromEmail in at least one settlement (they paid someone)
  /// 
  /// Only members who have made a payment (fromEmail) should show "Settled" tag
  bool _isMemberSettled(Map<String, dynamic> memberMap) {
    final balance = double.tryParse(memberMap['balance']?.toString() ?? '0') ?? 0.0;
    
    // If balance is not 0, member is not settled
    if (balance != 0) return false;
    
    // If no settlements exist, don't show settled tag
    if (settlements.isEmpty) return false;
    
    // Check if member is the fromEmail in any settlement
    final memberEmail = memberMap['email']?.toString().toLowerCase() ?? '';
    if (memberEmail.isEmpty) return false;
    
    // Member is settled if they are the fromEmail (payer) in any settlement
    return settlements.any((settlement) {
      final fromEmail = settlement['fromEmail']?.toString().toLowerCase() ?? '';
      return fromEmail == memberEmail;
    });
  }

  double _parseBalance(dynamic balance) {
    if (balance == null) return 0.0;
    if (balance is num) return balance.toDouble();
    if (balance is String) {
      // Remove currency symbols and parse
      final cleaned = balance.replaceAll(RegExp(r'[^\d.-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is num) return amount.toDouble();
    if (amount is String) {
      // Remove currency symbols and parse
      final cleaned = amount.replaceAll(RegExp(r'[^\d.-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  IconData _getPaymentIcon(String paymentType) {
    final type = paymentType.toLowerCase().trim();
    // Check for Zelle first with multiple variations
    if (type.contains('zelle') || type == 'zelle' || type.startsWith('zelle')) {
      return Icons.account_balance_wallet; // Bank wallet icon for Zelle
    } else if (type.contains('google') || type.contains('gpay')) {
      return Icons.contactless_outlined;
    } else if (type.contains('paytm')) {
      return Icons.phone_iphone;
    } else if (type.contains('upi')) {
      return Icons.account_balance;
    } else if (type.contains('paypal')) {
      return Icons.account_balance_wallet_outlined;
    } else if (type.contains('venmo')) {
      return Icons.account_balance_wallet_outlined;
    } else if (type.contains('stripe')) {
      return Icons.credit_card;
    }
    return Icons.payment;
  }

  Future<void> _settleUpPayment(String fromEmail, String toEmail, String? notes) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    if (!context.mounted) return;
    
    // Show loading
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
      // Get current user's userId for settledBy
      final settledBy = widget.userId;

      debugPrint('📤 Settle Up Payment Request (NEW API - No Amount):');
      debugPrint('   fromEmail: $fromEmail (who paid)');
      debugPrint('   toEmail: $toEmail (who received)');
      debugPrint('   settledBy: $settledBy');
      debugPrint('   notes: $notes');
      debugPrint('   ⚠️ Amount NOT sent - system will calculate automatically');

      final result = await ExpenseGroupService.createSettlement(
        groupId: widget.groupId,
        fromEmail: fromEmail,
        toEmail: toEmail,
        settledBy: settledBy,
        notes: notes ?? 'Settled via app',
        token: userProvider.token,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      debugPrint('📥 Settle Up Payment Response:');
      debugPrint('   Success: ${result['success']}');
      debugPrint('   Message: ${result['message'] ?? result['error']}');

      if (result['success'] == true) {
        final settlement = result['data'] as Map<String, dynamic>? ?? {};
        final amount = settlement['amount']?.toString() ?? settlement['amountRaw']?.toString() ?? '';
        final message = result['message']?.toString() ?? '';
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message.contains('auto-corrected') 
                ? 'Settlement created successfully (direction was auto-corrected)'
                : amount.isNotEmpty 
                  ? 'Successfully settled $amount from ${settlement['fromEmail']} to ${settlement['toEmail']}!'
                  : 'Settlement created successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          // Reload group data to reflect changes and show "Settled" status
          _loadGroupData();
        }
      } else {
        final errorMessage = result['error']?.toString() ?? 'Failed to settle payment';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Settle up payment error: $e');
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error settling payment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addManualReceipt() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final membersList = groupData?['participants'] ?? [];
    final List<Map<String, dynamic>> members = (membersList is List 
        ? membersList.map((m) {
            if (m is Map<String, dynamic>) {
              return m;
            } else if (m is Map) {
              return Map<String, dynamic>.from(m);
            } else {
              return <String, dynamic>{};
            }
          }).toList()
        : <Map<String, dynamic>>[]);
    
    showDialog(
      context: context,
      builder: (context) {
        return _ManualReceiptDialog(
          userId: widget.userId,
          token: widget.token,
          groupId: widget.groupId,
          groupName: widget.groupName,
          groupMembers: members,
          onSave: (receiptData) async {
            // Prepare receipt data for split options screen
            final receiptForSplit = {
              ...receiptData,
              'id': 'manual_${DateTime.now().millisecondsSinceEpoch}', // Temporary ID for manual receipt
              'isManual': true,
            };
            
            // Wait a frame to ensure dialog is closed
            await Future.delayed(const Duration(milliseconds: 100));
            
            // Navigate to split options screen
            if (!mounted) return;
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupSplitOptionsScreen(
                  groupId: widget.groupId,
                  groupName: widget.groupName,
                  selectedReceipts: [receiptForSplit],
                  groupMembers: members,
                  userId: widget.userId,
                  token: widget.token,
                ),
              ),
            );
            
            // If split was successful, reload group data
            if (result == true && mounted) {
              if (widget.initialData == null) {
                _loadGroupData();
              }
            }
          },
        );
      },
    );
  }

  Future<void> _showSettleUpDialog(Map<String, dynamic>? member, double balance) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currencySymbol = userProvider.effectiveCurrencySymbol;
    
    // Show loading dialog while fetching debts
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
        ),
      ),
    );
    
    // Fetch debts before showing the settle up dialog
    List<Map<String, dynamic>> debtsList = [];
    try {
      final result = await ExpenseGroupService.getDebts(
        groupId: widget.groupId,
        userId: widget.userId,
        token: userProvider.token,
      );

      if (result['success'] == true) {
        final debtsData = result['data'] as List<dynamic>? ?? [];
        debtsList = debtsData.map((d) {
          if (d is Map<String, dynamic>) {
            return Map<String, dynamic>.from(d);
          }
          return <String, dynamic>{};
        }).toList();
        debugPrint('📊 Loaded ${debtsList.length} debts');
      } else {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Failed to load debts'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('Error fetching debts: $e');
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading debts: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Close loading dialog and show settle up dialog with debts
    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog
    
    showDialog(
      context: context,
      builder: (context) {
        return _SettleUpDialog(
          debts: debtsList,
          currencySymbol: currencySymbol,
          userId: widget.userId,
          token: widget.token,
          groupId: widget.groupId,
          onSettle: (fromEmail, toEmail, notes) {
            Navigator.pop(context);
            _settleUpPayment(fromEmail, toEmail, notes);
          },
        );
      },
    );
  }

  String _getMemberInitials(Map<String, dynamic> member) {
    final name = member['name']?.toString() ?? '';
    if (name.isEmpty) {
      final email = member['email']?.toString() ?? '';
      if (email.isNotEmpty) return email[0].toUpperCase();
      return '?';
    }
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getAvatarColorForMember(Map<String, dynamic> member) {
    final memberId = member['userId']?.toString() ?? 
                    member['id']?.toString() ?? 
                    member['_id']?.toString() ?? 
                    member['email']?.toString() ?? '';
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

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currencySymbol = userProvider.effectiveCurrencySymbol;
    
    final totalSpend = groupData?['totalAmount'] ?? 0.0;
    final yourBalance = groupData?['yourBalance'] ?? 0.0;
    final description = groupData?['description']?.toString() ?? '';
    final membersList = groupData?['participants'] ?? [];
    // Ensure members is a List
    final members = membersList is List ? membersList : [];
    
    // Format group description
    final groupDescription = description.isNotEmpty ? description : '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Light background
      body: Column(
        children: [
          // Header
          Container(
            color: const Color(0xFF7E5EFD),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 16,
              left: 8,
              right: 8,
            ),
            child: SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  Center(
                    child: Text(
                      widget.groupName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'MR',
                          style: TextStyle(
                            color: Color(0xFF7E5EFD),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group description (only show if not empty)
                        if (groupDescription.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              groupDescription,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                        // Summary Cards (White cards with purple text)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.shade200,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$currencySymbol${totalSpend.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Color(0xFF7E5EFD),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total Spend',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.shade200,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${yourBalance < 0 ? '-' : ''}$currencySymbol${yourBalance.abs().toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Color(0xFF7E5EFD),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Your Balance',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Add Receipt Actions
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GroupReceiptSelectionScreen(
                                        groupId: widget.groupId,
                                        groupName: widget.groupName,
                                        userId: widget.userId,
                                        token: widget.token,
                                      ),
                                    ),
                                  ).then((result) {
                                    // Refresh group data if receipts were added
                                    if (result == true) {
                                      if (widget.initialData == null) {
                                        _loadGroupData();
                                      } else {
                                        // For mock data, just show a message
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Receipts added successfully'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    }
                                  });
                                },
                                icon: const Icon(Icons.add, color: Colors.white),
                                label: const Text(
                                  'Add Receipt',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7E5EFD),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _addManualReceipt,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF7E5EFD),
                                  side: const BorderSide(color: Color(0xFF7E5EFD)),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  '+ Add Manually',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Member Balances with Settings and Settle Up Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Member Balances',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                // Reminder icon - only show if there are members who owe money
                                if (members.any((m) {
                                  final memberMap = m is Map<String, dynamic> ? m : Map<String, dynamic>.from(m as Map);
                                  final balance = double.tryParse(memberMap['balance']?.toString() ?? '0') ?? 0.0;
                                  final memberUserId = memberMap['userId']?.toString() ?? '';
                                  final memberEmail = memberMap['email']?.toString().toLowerCase() ?? '';
                                  final currentUserEmail = userProvider.email?.toLowerCase() ?? '';
                                  final isCurrentUser = (memberUserId == widget.userId) || 
                                                       (memberEmail.isNotEmpty && memberEmail == currentUserEmail);
                                  // Member owes money if balance < 0 and is not the current user
                                  return balance < 0 && !isCurrentUser;
                                })) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.notifications_outlined,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    onPressed: _showReminderConfirmationDialog,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Send reminder to members who owe you',
                                  ),
                                ],
                              ],
                            ),
                            Row(
                              children: [
                                // Check if there are any members with non-zero balances
                                if (members.any((m) {
                                  final memberMap = m is Map<String, dynamic> ? m : Map<String, dynamic>.from(m as Map);
                                  final balance = double.tryParse(memberMap['balance']?.toString() ?? '0') ?? 0.0;
                                  final memberUserId = memberMap['userId']?.toString() ?? '';
                                  final memberEmail = memberMap['email']?.toString().toLowerCase() ?? '';
                                  final currentUserEmail = userProvider.email?.toLowerCase() ?? '';
                                  final isCurrentUser = (memberUserId == widget.userId) || 
                                                       (memberEmail.isNotEmpty && memberEmail == currentUserEmail);
                                  return balance != 0 && !isCurrentUser;
                                }))
                                  ElevatedButton(
                                    onPressed: () => _showSettleUpDialog(null, 0.0),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Settle Up',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.settings,
                                    color: Colors.black87,
                                    size: 20,
                                  ),
                                  onPressed: _showGroupSettingsMenu,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...members.map((member) {
                          // Ensure member is Map<String, dynamic>
                          final Map<String, dynamic> memberMap = member is Map<String, dynamic>
                              ? member
                              : Map<String, dynamic>.from(member as Map);
                          
                          final name = memberMap['name']?.toString() ?? 'Unknown';
                          final balance = double.tryParse(memberMap['balance']?.toString() ?? '0') ?? 0.0;
                          final initials = _getMemberInitials(memberMap);
                          final isOwed = balance > 0;
                          final isOwes = balance < 0;
                          final isSettled = _isMemberSettled(memberMap);
                          
                          // Check if this member is the current user
                          final memberUserId = memberMap['userId']?.toString() ?? '';
                          final memberEmail = memberMap['email']?.toString().toLowerCase() ?? '';
                          final currentUserEmail = userProvider.email?.toLowerCase() ?? '';
                          final isCurrentUser = (memberUserId == widget.userId) || 
                                               (memberEmail.isNotEmpty && memberEmail == currentUserEmail);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF7E5EFD),
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
                                // Name and Status Badge
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // Status badge
                                      if (isSettled)
                                        Row(
                                          children: [
                                            Text(
                                              'Settled',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.green.shade300),
                                              ),
                                              child: Text(
                                                'Settled',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      else if (isOwed || isOwes)
                                        Text(
                                          isOwed
                                              ? 'Owed $currencySymbol ${balance.abs().toStringAsFixed(2)}'
                                              : 'Owes $currencySymbol ${balance.abs().toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isOwed
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Balance Amount
                                Text(
                                  isSettled || balance == 0
                                      ? '$currencySymbol 0.00'
                                      : '$currencySymbol ${balance.abs().toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isSettled || balance == 0
                                        ? Colors.grey.shade600
                                        : (isOwed ? Colors.green.shade700 : Colors.orange.shade700),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        // Group Receipts Section
                        const Text(
                          'Group Receipts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            debugPrint('🔍 Rendering expenses: ${expenses.length} items');
                            if (expenses.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No expenses yet',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: expenses.map<Widget>((expense) {
                                final expenseMap = expense as Map<String, dynamic>;
                                
                                // Extract data from mapped expense structure
                                // expenseMap['receipt'] contains: merchant, category, receiptDate
                                final receipt = expenseMap['receipt'] as Map<String, dynamic>? ?? {};
                                final merchant = receipt['merchant']?.toString() ?? 'Unknown';
                                final receiptDate = receipt['receiptDate']?.toString() ?? '';
                                
                                // totalAmount comes directly from expense object (not from receipt)
                                final totalAmount = expenseMap['totalAmount']?.toString() ?? '0';
                                
                                // participants array from expense object - count gives us split count
                                final participants = expenseMap['participants'] as List<dynamic>? ?? [];
                                final participantCount = participants.length;
                                
                                // Parse date for display
                                String formattedDate = receiptDate;
                                try {
                                  if (receiptDate.isNotEmpty) {
                                    // Handle different date formats
                                    DateTime? date;
                                    // Try parsing as ISO format (YYYY-MM-DD)
                                    try {
                                      date = DateTime.parse(receiptDate);
                                    } catch (e) {
                                      // Try parsing as MM-DD-YYYY format
                                      try {
                                        final parts = receiptDate.split('-');
                                        if (parts.length == 3) {
                                          final month = int.tryParse(parts[0]);
                                          final day = int.tryParse(parts[1]);
                                          final year = int.tryParse(parts[2]);
                                          if (month != null && day != null && year != null) {
                                            date = DateTime(year, month, day);
                                          }
                                        }
                                      } catch (e2) {
                                        // Keep original if all parsing fails
                                      }
                                    }
                                    if (date != null) {
                                      formattedDate = DateFormat('MMM d, yyyy').format(date);
                                    }
                                  }
                                } catch (e) {
                                  // Keep original format if parsing fails
                                  debugPrint('Error parsing date: $e');
                                }
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.shade200,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Merchant name and amount row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              merchant,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            totalAmount,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Split info and date
                                      Text(
                                        'Split with $participantCount ${participantCount == 1 ? 'person' : 'people'} • $formattedDate',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
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

// Separate StatefulWidget for Settle Up Dialog
class _SettleUpDialog extends StatefulWidget {
  final List<Map<String, dynamic>> debts;
  final String currencySymbol;
  final String userId;
  final String token;
  final String groupId;
  final Function(String, String, String?) onSettle;

  const _SettleUpDialog({
    required this.debts,
    required this.currencySymbol,
    required this.userId,
    required this.token,
    required this.groupId,
    required this.onSettle,
  });

  @override
  State<_SettleUpDialog> createState() => _SettleUpDialogState();
}

class _SettleUpDialogState extends State<_SettleUpDialog> {
  Map<String, dynamic>? selectedPaidByDebt;
  Map<String, dynamic>? selectedDebt;
  bool loadingPaymentCatalog = false;
  List<Map<String, dynamic>> paymentCatalog = [];

  @override
  void initState() {
    super.initState();
    _fetchPaymentCatalog();
  }

  Future<void> _fetchPaymentCatalog() async {
    setState(() {
      loadingPaymentCatalog = true;
    });
    
    try {
      final endpoint = '/payments/catalog/${widget.userId}';
      final response = await ApiService.get(endpoint, token: widget.token);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<Map<String, dynamic>> catalog = [];
        
        if (responseData is Map && responseData.containsKey('data')) {
          final data = responseData['data'];
          if (data is Map && data.containsKey('recommendedPartners')) {
            final recommended = data['recommendedPartners'];
            if (recommended is List) {
              catalog = List<Map<String, dynamic>>.from(
                recommended.map((item) => Map<String, dynamic>.from(item as Map)),
              );
            }
          }
        }
        
        setState(() {
          paymentCatalog = catalog;
          loadingPaymentCatalog = false;
        });
      } else {
        setState(() {
          loadingPaymentCatalog = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching payment catalog: $e');
      setState(() {
        loadingPaymentCatalog = false;
      });
    }
  }

  // Get unique "Paid By" members from debts
  List<Map<String, dynamic>> getPaidByOptions() {
    final uniqueEmails = <String>{};
    final paidByList = <Map<String, dynamic>>[];
    
    for (var debt in widget.debts) {
      final fromEmail = debt['fromEmail']?.toString().toLowerCase() ?? '';
      if (fromEmail.isNotEmpty && !uniqueEmails.contains(fromEmail)) {
        uniqueEmails.add(fromEmail);
        paidByList.add({
          'email': debt['fromEmail'],
          'name': debt['fromName'],
        });
      }
    }
    
    return paidByList;
  }

  // Get "Paid To" options filtered by selected "Paid By"
  List<Map<String, dynamic>> getPaidToOptions() {
    if (selectedPaidByDebt == null) return [];
    
    final selectedEmail = selectedPaidByDebt!['email']?.toString().toLowerCase() ?? '';
    return widget.debts
        .where((debt) => debt['fromEmail']?.toString().toLowerCase() == selectedEmail)
        .map((debt) => <String, dynamic>{
          'email': debt['toEmail'],
          'name': debt['toName'],
          'amount': debt['amount'],
          'amountRaw': debt['amountRaw'],
        })
        .toList();
  }

  IconData _getPaymentIcon(String paymentType) {
    final type = paymentType.toLowerCase().trim();
    if (type.contains('zelle') || type == 'zelle' || type.startsWith('zelle')) {
      return Icons.account_balance_wallet;
    } else if (type.contains('google') || type.contains('gpay')) {
      return Icons.contactless_outlined;
    } else if (type.contains('paytm')) {
      return Icons.phone_iphone;
    } else if (type.contains('upi')) {
      return Icons.account_balance;
    } else if (type.contains('paypal')) {
      return Icons.account_balance_wallet_outlined;
    } else if (type.contains('venmo')) {
      return Icons.account_balance_wallet_outlined;
    } else if (type.contains('stripe')) {
      return Icons.credit_card;
    }
    return Icons.payment;
  }

  String _getMemberInitials(Map<String, dynamic> member) {
    final name = member['name']?.toString() ?? '';
    if (name.isEmpty) {
      final email = member['email']?.toString() ?? '';
      if (email.isNotEmpty) return email[0].toUpperCase();
      return '?';
    }
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final paidByOptions = getPaidByOptions();
    final paidToOptions = getPaidToOptions();
    
    // Get settlement amount from selected debt
    String settlementAmount = '';
    String settlementMessage = '';
    if (selectedDebt != null) {
      settlementAmount = selectedDebt!['amount']?.toString() ?? '';
      final fromName = selectedDebt!['fromName']?.toString() ?? '';
      final toName = selectedDebt!['toName']?.toString() ?? '';
      settlementMessage = '$fromName owes $toName';
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Purple Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF7E5EFD),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Text(
                'Settle Up',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Empty state
                      if (widget.debts.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  'No outstanding debts',
                                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'All members are settled up!',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // Paid By Section
                        const Text(
                          'Paid By',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: LayoutBuilder(
                            builder: (context, box) {
                              const double fieldHeight = 36;
                              return SizedBox(
                                height: fieldHeight,
                                child: PopupMenuButton<Map<String, dynamic>>(
                                  constraints: BoxConstraints(
                                    minWidth: box.maxWidth,
                                    maxWidth: box.maxWidth,
                                  ),
                                  offset: const Offset(0, fieldHeight),
                                  child: Row(
                                    children: [
                                      if (selectedPaidByDebt != null) ...[
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF7E5EFD),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              _getMemberInitials(selectedPaidByDebt!),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            selectedPaidByDebt!['name']?.toString() ?? 'Unknown',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        Expanded(
                                          child: Text(
                                            'Select who is paying',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Icon(Icons.keyboard_arrow_down, size: 18),
                                    ],
                                  ),
                                  itemBuilder: (BuildContext context) => paidByOptions.map((Map<String, dynamic> option) {
                                    final name = option['name']?.toString() ?? 'Unknown';
                                    final initials = _getMemberInitials(option);
                                    return PopupMenuItem<Map<String, dynamic>>(
                                      value: option,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF7E5EFD),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                initials,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onSelected: (Map<String, dynamic> value) {
                                    setState(() {
                                      selectedPaidByDebt = value;
                                      selectedDebt = null; // Reset selected debt
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Paid To Section
                        if (selectedPaidByDebt != null) ...[
                          const Text(
                            'Paid To',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: selectedDebt != null ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                                width: selectedDebt != null ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: LayoutBuilder(
                              builder: (context, box) {
                                const double fieldHeight = 36;
                                return SizedBox(
                                  height: fieldHeight,
                                  child: paidToOptions.isEmpty
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'No outstanding debts for this member',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : PopupMenuButton<Map<String, dynamic>>(
                                          constraints: BoxConstraints(
                                            minWidth: box.maxWidth,
                                            maxWidth: box.maxWidth,
                                          ),
                                          offset: const Offset(0, fieldHeight),
                                          child: Row(
                                            children: [
                                              if (selectedDebt != null) ...[
                                                Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF7E5EFD),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      _getMemberInitials({
                                                        'name': selectedDebt!['toName'],
                                                        'email': selectedDebt!['toEmail'],
                                                      }),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        selectedDebt!['toName']?.toString() ?? 'Unknown',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Owes ${selectedDebt!['amount']?.toString() ?? ''}',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.orange.shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ] else ...[
                                                Expanded(
                                                  child: Text(
                                                    'Select who is receiving',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              const Icon(Icons.keyboard_arrow_down, size: 18),
                                            ],
                                          ),
                                          itemBuilder: (BuildContext context) => paidToOptions.map((Map<String, dynamic> option) {
                                            final name = option['name']?.toString() ?? 'Unknown';
                                            final amount = option['amount']?.toString() ?? '';
                                            final initials = _getMemberInitials(option);
                                            
                                            // Find the matching debt
                                            final matchingDebt = widget.debts.firstWhere(
                                              (debt) => 
                                                debt['fromEmail']?.toString().toLowerCase() == selectedPaidByDebt!['email']?.toString().toLowerCase() &&
                                                debt['toEmail']?.toString().toLowerCase() == option['email']?.toString().toLowerCase(),
                                              orElse: () => <String, dynamic>{},
                                            );
                                            
                                            return PopupMenuItem<Map<String, dynamic>>(
                                              value: matchingDebt,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF7E5EFD),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        initials,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          name,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black87,
                                                          ),
                                                        ),
                                                        Text(
                                                          'Owes $amount',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.orange.shade700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onSelected: (Map<String, dynamic> value) {
                                            setState(() {
                                              selectedDebt = value;
                                            });
                                          },
                                        ),
                                );
                              },
                            ),
                          ),
                          ],
                          // Settlement Amount Display
                          if (selectedDebt != null) ...[
                            const SizedBox(height: 24),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8E6FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Settlement Amount',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      settlementAmount,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7E5EFD),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      settlementMessage,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      const SizedBox(height: 20),
                      // Payment Options Section
                      if (loadingPaymentCatalog)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                          ),
                        ),
                      if (paymentCatalog.isNotEmpty) ...[
                        const Center(
                          child: Text(
                            'Quick Payment Options',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: paymentCatalog.length,
                              itemBuilder: (context, index) {
                              final option = paymentCatalog[index];
                              final name = option['name']?.toString() ?? '';
                              final id = option['id']?.toString() ?? '';
                              final logoUrl = option['logo']?.toString() ?? '';
                              final redirectUrl = option['redirectUrl']?.toString() ?? '';
                              
                              final paymentIcon = _getPaymentIcon(id.isNotEmpty ? id : name);
                              
                              return Container(
                                width: 90,
                                margin: EdgeInsets.only(
                                  right: index < paymentCatalog.length - 1 ? 12 : 0,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      if (redirectUrl.isNotEmpty) {
                                        debugPrint('Opening $name: $redirectUrl');
                                        final result = await PaymentHelper.openPaymentAppFromRedirectUrl(
                                          redirectUrl,
                                          widget.token,
                                          deepLink: option['deepLink']?.toString(),
                                          webUrl: option['webUrl']?.toString(),
                                        );
                                        
                                        if (result == PaymentHelper.resultSuccess && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Complete the payment in the app, then click "Settle Amount"'),
                                              duration: const Duration(seconds: 3),
                                              backgroundColor: const Color(0xFF7E5EFD),
                                              behavior: SnackBarBehavior.floating,
                                              margin: EdgeInsets.only(
                                                bottom: MediaQuery.of(context).size.height * 0.3,
                                                left: 16,
                                                right: 16,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                          );
                                        } else if (result == PaymentHelper.resultAppNotInstalled && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('$name is not installed. Please install it first.'),
                                              backgroundColor: Colors.orange,
                                              behavior: SnackBarBehavior.floating,
                                              margin: EdgeInsets.only(
                                                bottom: MediaQuery.of(context).size.height * 0.3,
                                                left: 16,
                                                right: 16,
                                              ),
                                              duration: const Duration(seconds: 4),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (logoUrl.isNotEmpty)
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                logoUrl,
                                                width: 45,
                                                height: 45,
                                                fit: BoxFit.contain,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Icon(
                                                    paymentIcon,
                                                    size: 45,
                                                    color: Colors.grey.shade400,
                                                  );
                                                },
                                              ),
                                            )
                                          else
                                            Icon(
                                              paymentIcon,
                                              size: 45,
                                              color: Colors.grey.shade400,
                                            ),
                                          const SizedBox(height: 8),
                                          Text(
                                            name,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selectedDebt != null
                          ? () {
                              final fromEmail = selectedDebt!['fromEmail']?.toString() ?? '';
                              final toEmail = selectedDebt!['toEmail']?.toString() ?? '';
                              widget.onSettle(fromEmail, toEmail, null);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFF7E5EFD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: const Text(
                        'Settle Amount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Manual Receipt Dialog - moved to top level
class _ManualReceiptDialog extends StatefulWidget {
  final String userId;
  final String token;
  final String groupId;
  final String groupName;
  final List<dynamic> groupMembers;
  final Function(Map<String, dynamic>)? onSave;

  const _ManualReceiptDialog({
    required this.userId,
    required this.token,
    required this.groupId,
    required this.groupName,
    required this.groupMembers,
    this.onSave,
  });

  @override
  State<_ManualReceiptDialog> createState() => _ManualReceiptDialogState();
}

class _ManualReceiptDialogState extends State<_ManualReceiptDialog> {
  final _formKey = GlobalKey<FormState>();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _dateController = TextEditingController();
  final _paidByController = TextEditingController();
  final _categoryFocusNode = FocusNode();
  final _categoryFieldKey = GlobalKey();
  String? _selectedCategory;
  Map<String, dynamic>? _selectedPaidBy;
  List<String> _categories = [];
  List<String> _filteredCategories = [];
  bool _loadingCategories = false;
  bool _isCategoryMenuOpen = false;
  Timer? _categoryFilterTimer;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('MM-dd-yyyy').format(_selectedDate);
    _loadCategories();
    
    
    // Initialize paidBy with first member if available
    if (widget.groupMembers.isNotEmpty) {
      for (var member in widget.groupMembers) {
        if (member is Map<String, dynamic>) {
          final memberMap = Map<String, dynamic>.from(member);
          _selectedPaidBy = memberMap;
          _paidByController.text = memberMap['name']?.toString() ?? '';
          break;
        }
      }
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
    });

    try {
      final response = await ApiService.get('/receipts/categories?userId=${widget.userId}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['categories'] != null && data['categories'] is List) {
          List<String> fetchedCategories = List<String>.from(data['categories']);

          // Also include user categories if available
          if (data['usercategories'] != null && data['usercategories'] is List) {
            final userCategories = List<String>.from(data['usercategories']);
            // Merge user categories with global categories, avoiding duplicates
            for (String userCategory in userCategories) {
              if (!fetchedCategories.contains(userCategory)) {
                fetchedCategories.add(userCategory);
              }
            }
          }

          if (mounted) {
            setState(() {
              _categories = fetchedCategories;
              _filteredCategories = fetchedCategories;
              _loadingCategories = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _categories = [];
              _loadingCategories = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _categories = [];
            _filteredCategories = [];
            _loadingCategories = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _categories = [];
          _filteredCategories = [];
          _loadingCategories = false;
        });
      }
    }
  }

  void _updateFilteredCategories(String query) {
    final trimmedQuery = query.trim().toLowerCase();
    List<String> source = List<String>.from(_categories);
    if (trimmedQuery.isEmpty) {
      source.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        _filteredCategories = source;
      });
      return;
    }

    final List<String> matches = source
        .where((c) => c.toLowerCase().contains(trimmedQuery))
        .toList();

    matches.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();
      final aStarts = aLower.startsWith(trimmedQuery);
      final bStarts = bLower.startsWith(trimmedQuery);
      if (aStarts != bStarts) return aStarts ? -1 : 1; // prefix first
      return aLower.compareTo(bLower); // then alphabetical
    });

    setState(() {
      _filteredCategories = matches;
    });
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _categoryController.text = category;
    });
  }

  void _showCategoryMenu() {
    if (_isCategoryMenuOpen || _filteredCategories.isEmpty) return;
    
    final RenderBox? renderBox = _categoryFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    setState(() {
      _isCategoryMenuOpen = true;
    });

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        MediaQuery.of(context).size.width - offset.dx - size.width,
        MediaQuery.of(context).size.height - offset.dy - size.height - 4,
      ),
      constraints: const BoxConstraints(
        maxHeight: 200,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      elevation: 8,
      items: _filteredCategories.map((category) {
        final isSelected = _categoryController.text.trim().toLowerCase() == category.toLowerCase();
        return PopupMenuItem<String>(
          value: category,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF7E5EFD) : Colors.black,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check,
                  color: Color(0xFF7E5EFD),
                  size: 18,
                ),
            ],
          ),
        );
      }).toList(),
    ).then((selectedCategory) {
      setState(() {
        _isCategoryMenuOpen = false;
      });
      if (selectedCategory != null) {
        _selectCategory(selectedCategory);
      }
    });
  }

  void _updateCategoryFilterAndShowMenu(String query) {
    // Cancel any existing timer
    _categoryFilterTimer?.cancel();
    
    // Update filtered categories immediately for responsive UI
    _updateFilteredCategories(query);
    
    // Close menu if no filtered results
    if (_filteredCategories.isEmpty && _isCategoryMenuOpen) {
      Navigator.of(context).pop();
      setState(() {
        _isCategoryMenuOpen = false;
      });
      return;
    }
    
    // Only update menu if it's already open - don't open automatically while typing
    // This prevents interference with text input
    if (_isCategoryMenuOpen && _filteredCategories.isNotEmpty) {
      // Debounce: Update menu after user stops typing for 300ms
      _categoryFilterTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted || !_isCategoryMenuOpen) return;
        
        // Close and reopen menu with updated filtered results
        Navigator.of(context).pop();
        setState(() {
          _isCategoryMenuOpen = false;
        });
        
        // Small delay to ensure the previous menu is closed before opening new one
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _categoryFocusNode.hasFocus && _filteredCategories.isNotEmpty) {
            _showCategoryMenu();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _categoryFilterTimer?.cancel();
    _merchantController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _dateController.dispose();
    _paidByController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }


  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('MM-dd-yyyy').format(picked);
      });
    }
  }


  void _saveReceipt() {
    if (!_formKey.currentState!.validate()) return;
    final categoryText = _categoryController.text.trim();
    if (categoryText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedPaidBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select who paid'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final receiptData = {
      'merchant': _merchantController.text.trim(),
      'amount': _amountController.text.trim().replaceAll(RegExp(r'[^\d.]'), ''),
      'category': categoryText,
      'receiptDate': _dateController.text.trim(),
      'paidBy': _selectedPaidBy!['email']?.toString() ?? '',
    };

    if (widget.onSave != null) {
      widget.onSave!(receiptData);
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF7E5EFD),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Add Manual Receipt',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLabeledField(
                        label: 'Merchant',
                        child: TextFormField(
                          controller: _merchantController,
                          decoration: const InputDecoration(
                            hintText: 'Enter merchant name',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Merchant name is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        label: 'Amount',
                        child: Builder(
                          builder: (context) {
                            final userProvider = Provider.of<UserProvider>(context, listen: false);
                            final currencySymbol = userProvider.effectiveCurrencySymbol;
                            return TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: 'Enter amount',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                prefixText: currencySymbol,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Amount is required';
                                }
                                final amount = double.tryParse(
                                  value.trim().replaceAll(RegExp(r'[^\d.]'), ''),
                                );
                                if (amount == null || amount <= 0) {
                                  return 'Please enter a valid amount';
                                }
                                return null;
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCategoryFieldWithDropdown(),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        label: 'Date',
                        child: GestureDetector(
                          onTap: _selectDate,
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: _dateController,
                              decoration: const InputDecoration(
                                hintText: 'Select date',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        label: 'Paid By',
                        child: Builder(
                          builder: (context) {
                            final membersList = widget.groupMembers
                                .where((member) => member is Map<String, dynamic>)
                                .map((member) => Map<String, dynamic>.from(member as Map<String, dynamic>))
                                .toList();

                            if (membersList.isEmpty) {
                              return InputDecorator(
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                child: const Text(
                                  'No members available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            }

                            return StyledDropdown<Map<String, dynamic>>(
                              value: _selectedPaidBy,
                              items: membersList,
                              placeholder: 'Select member',
                              onChanged: (Map<String, dynamic> value) {
                                setState(() {
                                  _selectedPaidBy = value;
                                  _paidByController.text = value['name']?.toString() ?? '';
                                });
                              },
                              itemToString: (member) => member['name']?.toString() ?? 'Unknown',
                              childBuilder: (context, value) {
                                return Row(
                                  children: [
                                    if (value != null) ...[
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF7E5EFD),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            _getMemberInitials(value),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Text(
                                        value != null
                                            ? (value['name']?.toString() ?? 'Unknown')
                                            : 'Select member',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: value != null
                                              ? Colors.black87
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                              menuItemBuilder: (context, member) {
                                final name = member['name']?.toString() ?? 'Unknown';
                                final email = member['email']?.toString() ?? '';
                                final isSelected = _selectedPaidBy?['email'] == email;

                                return Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF7E5EFD),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          _getMemberInitials(member),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
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
                                            name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? const Color(0xFF7E5EFD)
                                                  : Colors.black,
                                            ),
                                          ),
                                          if (email.isNotEmpty)
                                            Text(
                                              email,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check,
                                        color: Color(0xFF7E5EFD),
                                        size: 18,
                                      ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveReceipt,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMemberInitials(Map<String, dynamic> member) {
    final name = member['name']?.toString() ?? '';
    if (name.isEmpty) {
      final email = member['email']?.toString() ?? '';
      if (email.isNotEmpty) return email[0].toUpperCase();
      return '?';
    }
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Widget _buildCategoryFieldWithDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        _loadingCategories
            ? InputDecorator(
                key: _categoryFieldKey,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  suffixIcon: SizedBox(
                    width: 16,
                    height: 16,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                      ),
                    ),
                  ),
                ),
                child: const Text(
                  'Loading categories...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : TextField(
                key: _categoryFieldKey,
                controller: _categoryController,
                focusNode: _categoryFocusNode,
                decoration: InputDecoration(
                  hintText: 'Enter or select category',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      if (_categories.isNotEmpty) {
                        _updateFilteredCategories(_categoryController.text);
                        _showCategoryMenu();
                      }
                    },
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                onTap: () {
                  if (_categories.isNotEmpty) {
                    _updateFilteredCategories(_categoryController.text);
                    if (_filteredCategories.isNotEmpty) {
                      _showCategoryMenu();
                    }
                  }
                },
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                  // Update filter immediately for responsive filtering
                  _updateFilteredCategories(value);
                  // Show menu after user stops typing (debounced)
                  _updateCategoryFilterAndShowMenu(value);
                },
                onSubmitted: (value) {
                  // Close menu on submit
                  if (_isCategoryMenuOpen) {
                    Navigator.of(context).pop();
                    setState(() {
                      _isCategoryMenuOpen = false;
                    });
                  }
                  // Allow custom category entry
                },
              ),
      ],
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Color _getAvatarColorForMember(Map<String, dynamic> member) {
    final memberId = member['userId']?.toString() ?? 
                    member['id']?.toString() ?? 
                    member['_id']?.toString() ?? 
                    member['email']?.toString() ?? '';
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

  String _getUserInitials() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final username = userProvider.username ?? userProvider.effectiveUsername;
    if (username.isEmpty) {
      final email = userProvider.email ?? '';
      if (email.isNotEmpty) {
        return email[0].toUpperCase();
      }
      return 'U';
    }
    final parts = username.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username[0].toUpperCase();
  }
}

