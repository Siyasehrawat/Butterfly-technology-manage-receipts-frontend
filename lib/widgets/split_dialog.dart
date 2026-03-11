import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../utils/split_participant.dart';
import '../services/contact_service.dart';
import '../services/api_service_bypass.dart';
import '../services/expense_group_service.dart';
import 'dart:convert';

class SplitDialog extends StatefulWidget {
  final double totalAmount;
  final List<SplitParticipant>? existingParticipants;
  final Function(List<SplitParticipant>) onSave;
  final Function()? onClearSplit;
  final String currencySymbol;
  final String? defaultEmail;
  final String? userId;
  final String? token;
  final int? receiptId;

  const SplitDialog({
    Key? key,
    required this.totalAmount,
    this.existingParticipants,
    required this.onSave,
    this.onClearSplit,
    required this.currencySymbol,
    this.defaultEmail,
    this.userId,
    this.token,
    this.receiptId,
  }) : super(key: key);

  @override
  State<SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends State<SplitDialog> {
  final List<SplitParticipant> _participants = [];
  final TextEditingController _emailController = TextEditingController();
  final Map<int, TextEditingController> _amountControllers = {};
  final Map<int, TextEditingController> _percentageControllers = {};
  String _splitMode = 'equal'; // 'equal', 'custom'
  String _customSplitType = 'amount'; // 'amount', 'percentage'
  double _remainingAmount = 0.0;
  double _remainingPercentage = 100.0;
  String? _emailError; // Inline error for email field
  VoidCallback? _userProviderListener;

  // Variables for contact dropdown
  List<Map<String, dynamic>> _allContacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  bool _showContactDropdown = false;

  // Variables for split type selection
  String _splitType = 'participants'; // 'participants' or 'group'
  
  // Variables for group selection
  List<Map<String, dynamic>> _groups = [];
  Map<String, dynamic>? _selectedGroup;
  bool _loadingGroups = false;
  List<Map<String, dynamic>> _selectedGroupMembers = [];
  
  // Error state for displaying errors in dialog
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _remainingAmount = widget.totalAmount;
    _loadContacts();
    _loadGroups();
    _setupEmailController();
    _attachUserProviderListener();

    // 1. Populate participants from existing ones
    if (widget.existingParticipants != null && widget.existingParticipants!.isNotEmpty) {
      _participants.addAll(widget.existingParticipants!);
      // Determine initial split mode and type from existing participants
      _splitMode = _participants.every((p) => p.splitType == 'equal') ? 'equal' : 'custom';
      if (_splitMode == 'custom' && _participants.isNotEmpty) {
        _customSplitType = _participants.first.splitType == 'percentage' ? 'percentage' : 'amount';
      }
    } else {
      // No existing participants, default to equal split
      _splitMode = 'equal';
      _customSplitType = 'amount'; // Default custom type
    }

    // 2. Add default email if provided or available from UserProvider and not already in the list
    String resolvedDefaultEmail = (widget.defaultEmail ?? '').trim();
    if (resolvedDefaultEmail.isEmpty) {
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        resolvedDefaultEmail = (userProvider.effectiveEmail).trim();
      } catch (_) {}
    }

    if (resolvedDefaultEmail.isNotEmpty) {
      bool defaultEmailExists = _participants.any((p) => p.email.toLowerCase() == resolvedDefaultEmail.toLowerCase());
      if (!defaultEmailExists) {
        // Add the default user as a participant
        _participants.insert(0, SplitParticipant(
          email: resolvedDefaultEmail,
          name: '',
          amount: 0.0, // Initial amount, will be recalculated if equal split
          percentage: 0.0, // Initial percentage, will be recalculated if equal split
          isCustomAmount: false,
          splitType: 'equal', // Default type, will be adjusted by _applySplitModeLogic
        ));
        // If we just added the first participant, ensure split mode is 'equal'
        if (_participants.length == 1) {
          _splitMode = 'equal';
        }
      }
      // Ensure the input field is clear after the default email is handled
      _emailController.clear();
    }

    // 3. Initialize controllers for all participants
    _initializeControllers();

    // 4. Apply the current split mode logic to all participants
    // This will correctly set amounts/percentages based on _splitMode and _customSplitType
    _applySplitModeLogic();
    _updateControllerValues();
    _calculateRemaining();
  }

  void _setupEmailController() {
    _emailController.addListener(() {
      final query = _emailController.text.toLowerCase();

      setState(() {
        // Clear inline error while typing
        if (_emailError != null && query.isNotEmpty) {
          _emailError = null;
        }
        if (query.isEmpty) {
          // Hide dropdown when field is empty
          _filteredContacts = [];
          _showContactDropdown = false;
        } else {
          // Filter contacts based on email query - prioritize email matches
          _filteredContacts = _allContacts.where((contact) {
            final email = (contact['email'] ?? '').toString().toLowerCase();
            final name = (contact['name'] ?? '').toString().toLowerCase();
            return email.contains(query) || name.contains(query);
          }).toList();

          // Sort filtered contacts - exact email matches first, then partial matches
          _filteredContacts.sort((a, b) {
            final emailA = (a['email'] ?? '').toString().toLowerCase();
            final emailB = (b['email'] ?? '').toString().toLowerCase();

            // Exact email matches first
            if (emailA.startsWith(query) && !emailB.startsWith(query)) return -1;
            if (emailB.startsWith(query) && !emailA.startsWith(query)) return 1;

            // Then alphabetical by email
            return emailA.compareTo(emailB);
          });

          // Show dropdown if there are matching contacts
          _showContactDropdown = _filteredContacts.isNotEmpty;
        }
      });
    });
  }

  Future<void> _loadContacts() async {
    if (widget.userId != null && widget.token != null) {
      try {
        final contacts = await ContactService.fetchContacts(widget.userId!, widget.token!);
        setState(() {
          _allContacts = contacts;
        });
        // Try to auto-add current user's email for SSO users if not already present
        _maybeAddSelfEmailFromContacts();
        debugPrint('Loaded ${contacts.length} contacts for split dialog');
      } catch (e) {
        debugPrint('Error loading contacts: $e');
      }
    }
  }

  Future<void> _loadGroups() async {
    if (widget.userId != null && widget.token != null) {
      setState(() {
        _loadingGroups = true;
      });
      try {
        debugPrint('🔄 Loading groups for split dialog...');
        // Use ExpenseGroupService to fetch full groups (with members)
        // Note: Using default pagination (page 1, limit 20) for dialog
        final result = await ExpenseGroupService.getUserGroups(
          userId: widget.userId!,
          page: 1,
          limit: 20,
          token: widget.token,
        );
        
        if (result['success'] == true) {
          final groups = List<Map<String, dynamic>>.from(result['data'] ?? []);
          
          setState(() {
            _groups = groups;
            _loadingGroups = false;
          });
          
          debugPrint('✅ Loaded ${_groups.length} groups for split dialog');
          if (_groups.isNotEmpty) {
            debugPrint('📋 Groups:');
            for (var group in _groups) {
              final participantsCount = group['participants']?.length ?? 
                                       group['members']?.length ?? 
                                       group['memberCount'] ?? 0;
              debugPrint('   - ${group['name']} (ID: ${group['id']}, Members: $participantsCount)');
              debugPrint('     Fields: ${group.keys.toList()}');
              if (group['participants'] != null) {
                debugPrint('     Has participants field ✓');
              } else if (group['members'] != null) {
                debugPrint('     Has members field ✓');
              } else {
                debugPrint('     ⚠️ No participants/members field!');
              }
            }
          } else {
            debugPrint('⚠️ No groups found for user');
          }
        } else {
          debugPrint('❌ Failed to load groups: ${result['error']}');
          setState(() {
            _groups = [];
            _loadingGroups = false;
          });
        }
      } catch (e) {
        debugPrint('❌ Error loading groups: $e');
        setState(() {
          _groups = [];
          _loadingGroups = false;
        });
      }
    } else {
      debugPrint('⚠️ Cannot load groups: userId or token is null');
    }
  }

  // Heuristic: find the current user's email from contacts and add as participant
  void _maybeAddSelfEmailFromContacts() {
    try {
      // If defaultEmail is provided, existing logic already handled it
      if ((widget.defaultEmail ?? '').isNotEmpty) return;

      // If email already present among participants, skip
      final Set<String> existingEmails = _participants.map((p) => p.email.toLowerCase()).toSet();

      // Try preferred matches by flags or matching userId
      Map<String, dynamic>? selfContact;
      for (final c in _allContacts) {
        final email = (c['email'] ?? '').toString();
        if (email.isEmpty) continue;
        final isSelf = (c['isSelf'] == true) || (c['self'] == true) || (c['isOwner'] == true) || (c['isCurrentUser'] == true) || (c['me'] == true);
        final matchesUserId = widget.userId != null && (
            c['userId']?.toString() == widget.userId ||
            c['id']?.toString() == widget.userId ||
            c['ownerId']?.toString() == widget.userId);
        if (isSelf || matchesUserId) {
          selfContact = c;
          break;
        }
      }

      if (selfContact == null) return;
      final Map<String, dynamic> me = Map<String, dynamic>.from(selfContact!);
      final String email = (me['email'] ?? '').toString();
      if (email.isEmpty || existingEmails.contains(email.toLowerCase())) return;

      setState(() {
        _participants.insert(0, SplitParticipant(
          email: email,
          name: (me['name'] ?? '').toString(),
          amount: 0.0,
          percentage: 0.0,
          isCustomAmount: false,
          splitType: 'equal',
        ));

        // Create controllers for the new participant if controllers already initialized
        final newIndex = 0;
        _amountControllers[newIndex] = TextEditingController(text: '0.00');
        _percentageControllers[newIndex] = TextEditingController(text: '0.0');

        // Re-apply split logic and update
        _applySplitModeLogic();
        _updateControllerValues();
        _calculateRemaining();
      });
    } catch (e) {
      debugPrint('Error auto-adding self email from contacts: $e');
    }
  }

  void _selectContact(Map<String, dynamic> contact) {
    final email = contact['email']?.toString() ?? '';
    setState(() {
      _emailController.text = email;
      _showContactDropdown = false;
    });
  }

  Widget _buildContactDropdown() {
    debugPrint('Building dropdown: show=$_showContactDropdown, contacts=${_filteredContacts.length}');
    if (!_showContactDropdown || _filteredContacts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.3, // Max 30% of screen height
        minHeight: 50,
      ),
      child: Scrollbar(
        thumbVisibility: _filteredContacts.length > 3,
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _filteredContacts.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: Colors.grey.shade200,
            indent: 16,
            endIndent: 16,
          ),
          itemBuilder: (context, index) {
            final contact = _filteredContacts[index];
            final email = contact['email']?.toString() ?? '';

            return InkWell(
              onTap: () => _selectContact(contact),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Email icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E5EFD).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.email_outlined,
                        size: 16,
                        color: Color(0xFF7E5EFD),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Email text
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Arrow icon
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }



  void _initializeControllers() {
    for (int i = 0; i < _participants.length; i++) {
      _amountControllers[i] = TextEditingController(
        text: _participants[i].amount.toStringAsFixed(2),
      );
      _percentageControllers[i] = TextEditingController(
        text: _participants[i].percentage.toStringAsFixed(1),
      );
    }
  }

  void _createControllersForParticipant(int index) {
    _amountControllers[index] = TextEditingController(
      text: _participants[index].amount.toStringAsFixed(2),
    );
    _percentageControllers[index] = TextEditingController(
      text: _participants[index].percentage.toStringAsFixed(1),
    );
  }

  void _disposeControllersForParticipant(int index) {
    _amountControllers[index]?.dispose();
    _percentageControllers[index]?.dispose();
    _amountControllers.remove(index);
    _percentageControllers.remove(index);
  }

  void _updateControllerValues() {
    for (int i = 0; i < _participants.length; i++) {
      if (_amountControllers[i] != null) {
        final currentText = _amountControllers[i]!.text;
        final newText = _participants[i].amount.toStringAsFixed(2);
        if (currentText != newText && !_amountControllers[i]!.selection.isValid) {
          _amountControllers[i]!.text = newText;
        }
      }
      if (_percentageControllers[i] != null) {
        final currentText = _percentageControllers[i]!.text;
        final newText = _participants[i].percentage.toStringAsFixed(1);
        if (currentText != newText && !_percentageControllers[i]!.selection.isValid) {
          _percentageControllers[i]!.text = newText;
        }
      }
    }
  }

  @override
  void dispose() {
    if (_userProviderListener != null) {
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.removeListener(_userProviderListener!);
      } catch (_) {}
    }
    _emailController.dispose();
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    for (final controller in _percentageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _attachUserProviderListener() {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      // If email already available, ensure it's present
      _ensureSelfParticipant(userProvider.effectiveEmail);
      _userProviderListener = () {
        _ensureSelfParticipant(userProvider.effectiveEmail);
      };
      userProvider.addListener(_userProviderListener!);
    } catch (_) {}
  }

  void _ensureSelfParticipant(String? email) {
    final resolved = (email ?? '').trim();
    if (resolved.isEmpty) return;
    final exists = _participants.any((p) => p.email.toLowerCase() == resolved.toLowerCase());
    if (exists) return;
    setState(() {
      _participants.insert(0, SplitParticipant(
        email: resolved,
        name: '',
        amount: 0.0,
        percentage: 0.0,
        isCustomAmount: false,
        splitType: 'equal',
      ));
      // Create controllers for new participant
      _createControllersForParticipant(0);
      _applySplitModeLogic();
      _updateControllerValues();
      _calculateRemaining();
    });
  }

  void _calculateRemaining() {
    if (_splitMode == 'equal') {
      _remainingAmount = 0.0;
      _remainingPercentage = 0.0;
    } else if (_customSplitType == 'amount') {
      double usedAmount = 0.0;
      for (final participant in _participants) {
        usedAmount += participant.amount;
      }
      _remainingAmount = widget.totalAmount - usedAmount;
      _remainingPercentage = 0.0;
    } else {
      double usedPercentage = 0.0;
      for (final participant in _participants) {
        usedPercentage += participant.percentage;
      }
      _remainingPercentage = 100.0 - usedPercentage;
      _remainingAmount = (widget.totalAmount * _remainingPercentage) / 100.0;
    }
  }

  void _updateGroupMemberSplits() {
    if (_splitMode == 'equal') {
      _remainingAmount = 0.0;
      _remainingPercentage = 0.0;
      return;
    }
    
    if (_customSplitType == 'amount') {
      double usedAmount = 0.0;
      for (var i = 0; i < _selectedGroupMembers.length; i++) {
        final controller = _amountControllers[i];
        if (controller != null && controller.text.isNotEmpty) {
          usedAmount += double.tryParse(controller.text) ?? 0.0;
        }
      }
      _remainingAmount = widget.totalAmount - usedAmount;
      _remainingPercentage = 0.0;
    } else {
      double usedPercentage = 0.0;
      for (var i = 0; i < _selectedGroupMembers.length; i++) {
        final controller = _percentageControllers[i];
        if (controller != null && controller.text.isNotEmpty) {
          usedPercentage += double.tryParse(controller.text) ?? 0.0;
        }
      }
      _remainingPercentage = 100.0 - usedPercentage;
      _remainingAmount = (widget.totalAmount * _remainingPercentage) / 100.0;
    }
  }

// Helper to apply split mode logic to all participants
  void _applySplitModeLogic() {
    if (_splitMode == 'equal' && _participants.isNotEmpty) {
      final equalAmount = widget.totalAmount / _participants.length;
      for (int i = 0; i < _participants.length; i++) {
        _participants[i] = _participants[i].copyWith(
          amount: equalAmount,
          percentage: 100.0 / _participants.length,
          splitType: 'equal',
          isCustomAmount: false,
        );
      }
    } else if (_splitMode == 'custom' && _participants.isNotEmpty) {
      for (int i = 0; i < _participants.length; i++) {
        // If switching to percentage, convert existing amount to percentage
        double newAmount = _participants[i].amount;
        double newPercentage = _participants[i].percentage;

        if (_customSplitType == 'percentage' && _participants[i].splitType != 'percentage') {
          newPercentage = (newAmount / widget.totalAmount) * 100.0;
          newAmount = (widget.totalAmount * newPercentage) / 100.0; // Ensure consistency
        } else if (_customSplitType == 'amount' && _participants[i].splitType != 'amount') {
          newAmount = (newPercentage / 100.0) * widget.totalAmount;
          newPercentage = (newAmount / widget.totalAmount) * 100.0; // Ensure consistency
        }

        _participants[i] = _participants[i].copyWith(
          amount: newAmount,
          percentage: newPercentage,
          splitType: _customSplitType,
          isCustomAmount: true,
        );
      }
    }
  }

  void _addParticipant() {
    final entered = _emailController.text.trim();
    final email = entered.toLowerCase();

    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() {
        _emailError = 'Please enter a valid email address';
      });
      return;
    }

    if (_participants.any((p) => p.email.toLowerCase() == email)) {
      setState(() {
        _emailError = 'This email is already added';
      });
      return;
    }

    setState(() {
      _participants.add(SplitParticipant(
        email: email,
        name: '',
        amount: 0.0, // Initial values, will be set by _applySplitModeLogic
        percentage: 0.0,
        isCustomAmount: _splitMode != 'equal',
        splitType: _splitMode == 'equal' ? 'equal' : _customSplitType,
      ));

      final newIndex = _participants.length - 1;
      _createControllersForParticipant(newIndex);

      _emailController.clear(); // This line clears the input field after adding
      _emailError = null; // Clear error on success
      _showContactDropdown = false;
      _applySplitModeLogic(); // Recalculate all participants based on current mode
      _updateControllerValues();
      _calculateRemaining();
    });
  }

  void _removeParticipant(int index) {
    setState(() {
      _participants.removeAt(index);
      _disposeControllersForParticipant(index);

      // Reindex controllers
      final tempAmountControllers = <int, TextEditingController>{};
      final tempPercentageControllers = <int, TextEditingController>{};

      for (int i = 0; i < _participants.length; i++) {
        tempAmountControllers[i] = _amountControllers[i < index ? i : i + 1]!;
        tempPercentageControllers[i] = _percentageControllers[i < index ? i : i + 1]!;
      }

      _amountControllers.clear();
      _percentageControllers.clear();
      _amountControllers.addAll(tempAmountControllers);
      _percentageControllers.addAll(tempPercentageControllers);

      _applySplitModeLogic(); // Recalculate all participants based on current mode
      _updateControllerValues();
      _calculateRemaining();
    });
  }

  void _updateParticipantAmount(int index, double amount) {
    setState(() {
      _participants[index] = _participants[index].copyWith(
        amount: amount,
        isCustomAmount: true,
        splitType: 'amount',
      );
      _calculateRemaining();
    });
  }

  void _updateParticipantPercentage(int index, double percentage) {
    setState(() {
      final amount = (widget.totalAmount * percentage) / 100.0;
      _participants[index] = _participants[index].copyWith(
        percentage: percentage,
        amount: amount,
        isCustomAmount: true,
        splitType: 'percentage',
      );
      _calculateRemaining();
    });
  }

  void _changeSplitMode(String mode) {
    setState(() {
      _splitMode = mode;
      _applySplitModeLogic();
      _updateControllerValues();
      _calculateRemaining();
    });
  }

  void _changeCustomSplitType(String type) {
    setState(() {
      _customSplitType = type;
      _applySplitModeLogic();
      _updateControllerValues();
      _calculateRemaining();
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _selectGroup(Map<String, dynamic> group) async {
    // Set loading state
    setState(() {
      _selectedGroup = group;
      _selectedGroupMembers = [];
    });
    
    debugPrint('📋 Raw group data: $group');
    
    // Extract members from group - try different field names
    List<dynamic> participants = [];
    if (group['participants'] != null) {
      participants = group['participants'] as List<dynamic>;
      debugPrint('✓ Found participants field in group');
    } else if (group['members'] != null) {
      participants = group['members'] as List<dynamic>;
      debugPrint('✓ Found members field in group');
    } else {
      // If we don't have participants, fetch full group details
      debugPrint('⚠️ No participants/members in group data, fetching full details...');
      try {
        final groupId = group['id']?.toString();
        if (groupId != null && widget.userId != null && widget.token != null) {
          final result = await ExpenseGroupService.getGroupDetails(
            groupId: groupId,
            userId: widget.userId,
            token: widget.token,
          );
          
          if (result['success'] == true) {
            final responseData = result['data'] as Map<String, dynamic>;
            debugPrint('📥 Group details response keys: ${responseData.keys.toList()}');
            
            // Check if data is nested under 'group' key
            final groupData = responseData['group'] as Map<String, dynamic>? ?? responseData;
            debugPrint('📋 Group data keys: ${groupData.keys.toList()}');
            
            // Try to find members/participants in the nested structure
            if (groupData['members'] != null) {
              participants = groupData['members'] as List<dynamic>;
              debugPrint('✅ Found members field in group details');
            } else if (groupData['participants'] != null) {
              participants = groupData['participants'] as List<dynamic>;
              debugPrint('✅ Found participants field in group details');
            }
            
            debugPrint('✅ Fetched ${participants.length} members from group details');
          } else {
            debugPrint('❌ Failed to fetch group details: ${result['error']}');
          }
        }
      } catch (e) {
        debugPrint('❌ Error fetching group details: $e');
      }
    }
    
    final members = participants.map((p) {
      if (p is Map<String, dynamic>) {
        return {
          'userId': p['userId'] ?? p['id'] ?? p['_id'] ?? '',
          'email': p['email'] ?? '',
          'name': p['name'] ?? '',
        };
      } else {
        return {
          'userId': '',
          'email': '',
          'name': '',
        };
      }
    }).toList();
    
    setState(() {
      _selectedGroupMembers = members;
    });
    
    debugPrint('✅ Group selected: ${group['name']}');
    debugPrint('   Group ID: ${group['id']}');
    debugPrint('   Participants from API: ${participants.length}');
    debugPrint('   Selected members mapped: ${_selectedGroupMembers.length}');
    debugPrint('   Can save: ${_selectedGroup != null && _selectedGroupMembers.isNotEmpty}');
    
    if (_selectedGroupMembers.isNotEmpty) {
      debugPrint('   ✅ Members:');
      for (var member in _selectedGroupMembers) {
        debugPrint('      - ${member['name']} (${member['email']})');
      }
    } else {
      debugPrint('   ⚠️ No members found in group data!');
      debugPrint('   Available fields: ${group.keys.toList()}');
    }
  }

  Future<Map<String, dynamic>?> _showAddContactDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E5EFD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_add,
                  color: Color(0xFF7E5EFD),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Add New Contact',
                style: TextStyle(
                  color: Color(0xFF7E5EFD),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name *',
                      hintText: 'Enter contact name',
                      prefixIcon: const Icon(Icons.person, color: Color(0xFF7E5EFD)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      hintText: 'Enter email address',
                      prefixIcon: const Icon(Icons.email, color: Color(0xFF7E5EFD)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an email';
                      }
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone (Optional)',
                      hintText: 'Enter phone number',
                      prefixIcon: const Icon(Icons.phone, color: Color(0xFF7E5EFD)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        // Basic phone validation if provided
                        final phoneRegex = RegExp(r'^[\+]?[0-9\s\-\(\)]{7,}$');
                        if (!phoneRegex.hasMatch(value.trim())) {
                          return 'Please enter a valid phone number';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final result = await _addContact(
                    nameController.text.trim(),
                    emailController.text.trim(),
                    phoneController.text.trim(),
                  );
                  if (result != null && context.mounted) {
                    Navigator.pop(dialogContext, result);
                  } else if (context.mounted) {
                    Navigator.pop(dialogContext);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Add Contact',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _addContact(String name, String email, String phone) async {
    if (widget.userId == null || widget.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User information not available'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
              ),
              const SizedBox(height: 16),
              Text(
                'Adding contact...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final Map<String, dynamic> requestBody = {
        'name': name,
        'email': email,
        'phone': phone.isNotEmpty ? phone : null,
        'userId': widget.userId,
      };

      final response = await ApiService.post(
        '/split-bill/contacts',
        body: requestBody,
        token: userProvider.token,
      );

      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        // Handle the response structure: { success: true, message: "...", data: {...} }
        final contactData = data['data'] ?? data;
        
        // Return the created contact data in the format expected by the UI
        return {
          'id': contactData['id']?.toString() ?? '',
          'name': contactData['name']?.toString() ?? name,
          'email': contactData['email']?.toString() ?? email,
          'phone': contactData['phone']?.toString(),
          'userId': contactData['userId']?.toString() ?? widget.userId,
          'isSavedContact': contactData['isSavedContact'] ?? true,
        };
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? errorBody['error'] ?? 'Failed to add contact';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      debugPrint('Error adding contact: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error. Please check your internet connection.'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _showSelectContactsDialog() async {
    // Fetch fresh contacts
    List<Map<String, dynamic>> contacts = [];
    try {
      if (widget.userId != null && widget.token != null) {
        // If a group is selected, pass groupId to exclude existing group members
        final groupId = _selectedGroup?['id']?.toString();
        
        final result = await ExpenseGroupService.getContacts(
          userId: widget.userId!,
          token: widget.token,
          groupId: groupId,
        );

        if (result['success'] == true) {
          final allContacts = List<Map<String, dynamic>>.from(result['data'] ?? []);
          
          // Filter contacts with valid email addresses
          contacts = allContacts.where((contact) {
            final hasValidEmail = contact['email'] != null && 
                                 contact['email'].toString().trim().isNotEmpty &&
                                 contact['email'].toString().trim() != 'null';
            return hasValidEmail;
          }).toList();
        }
      }
    } catch (e) {
      debugPrint("Error fetching contacts: $e");
    }

    final Set<String> selectedContactIds = <String>{};

    return showDialog<List<Map<String, dynamic>>>(
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

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Contacts',
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
                    Expanded(
                      child: contacts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.contacts_outlined, size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No contacts found',
                                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
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
                              onPressed: () {
                                final selected = getSelectedContacts();
                                Navigator.of(dialogContext).pop(selected);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7E5EFD),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  }

  void _createNewGroup() async {
    final TextEditingController groupNameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String? groupNameError;
    final List<Map<String, dynamic>> selectedMembers = [];

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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

            void _addMember(Map<String, dynamic> contact) {
              final memberEmail = contact['email']?.toString() ?? '';
              final exists = selectedMembers.any((m) {
                final email = m['email']?.toString() ?? '';
                return memberEmail.isNotEmpty && email.toLowerCase() == memberEmail.toLowerCase();
              });
              
              if (!exists) {
                setDialogState(() {
                  selectedMembers.add(contact);
                });
              }
            }

            void _removeMember(int index) {
              if (index >= 0 && index < selectedMembers.length) {
                setDialogState(() {
                  selectedMembers.removeAt(index);
                });
              }
            }

            bool isValid() {
              groupNameError = null;
              if (groupNameController.text.trim().isEmpty) {
                groupNameError = 'Group name is required';
                return false;
              }
              return true;
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
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
                            'Create Group',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 24),
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Group Name
                            const Text(
                              'Group Name *',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: groupNameController,
                              decoration: InputDecoration(
                                hintText: 'e.g.Holiday',
                                errorText: groupNameError,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              onChanged: (value) {
                                if (groupNameError != null) {
                                  setDialogState(() => groupNameError = null);
                                }
                              },
                            ),
                            const SizedBox(height: 20),
                            // Description
                            const Text(
                              'Description (Optional)',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: descriptionController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: "What's this group for?",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Add Members
                            const Text(
                              'Add Members',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final newContact = await _showAddContactDialog();
                                      if (newContact != null) {
                                        setDialogState(() {
                                          _addMember(newContact);
                                        });
                                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                                          const SnackBar(
                                            content: Text('Contact added successfully'),
                                            backgroundColor: Color(0xFF7E5EFD),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: BorderSide(color: Colors.grey.shade300),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text(
                                      'Add Contacts',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final contacts = await _showSelectContactsDialog();
                                      if (contacts != null && contacts.isNotEmpty) {
                                        setDialogState(() {
                                          for (var contact in contacts) {
                                            _addMember(contact);
                                          }
                                        });
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: BorderSide(color: Colors.grey.shade300),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text(
                                      'From Contacts',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Selected Members
                            if (selectedMembers.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ...selectedMembers.asMap().entries.map((entry) {
                                final index = entry.key;
                                final member = entry.value;
                                final name = member['name']?.toString() ?? 'Unknown';
                                final email = member['email']?.toString() ?? '';
                                final initials = _getMemberInitials(member);
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF7E5EFD),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            initials,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                            ),
                                            if (email.isNotEmpty)
                                              Text(
                                                email,
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                                        onPressed: () => _removeMember(index),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            const SizedBox(height: 20),
                            // Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(false),
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
                                    onPressed: () async {
                                      if (isValid()) {
                                        // Create group
                                        final members = selectedMembers.map((m) => {
                                          'email': m['email']?.toString() ?? '',
                                          'name': m['name']?.toString(),
                                        }).toList();

                                        final result = await ExpenseGroupService.createGroup(
                                          name: groupNameController.text.trim(),
                                          description: descriptionController.text.trim(),
                                          createdBy: widget.userId!,
                                          members: members,
                                          token: widget.token,
                                        );

                                        if (result['success'] == true) {
                                          Navigator.of(dialogContext).pop(true);
                                        } else {
                                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                                            SnackBar(
                                              content: Text(result['error']?.toString() ?? 'Failed to create group'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      } else {
                                        setDialogState(() {});
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7E5EFD),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text(
                                      'Create Group',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
              ),
            );
          },
        );
      },
    );

    // Reload groups if group was created
    if (result == true) {
      await _loadGroups();
    }
  }

  Color _getAvatarColorForMember(String userId) {
    // Generate consistent color based on userId
    final hash = userId.hashCode;
    final colors = [
      const Color(0xFF7E5EFD),
      const Color(0xFF22C55E),
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];
    return colors[hash.abs() % colors.length];
  }

  bool _canSave() {
    if (_splitType == 'group') {
      // For group mode, require a group to be selected
      if (_selectedGroup == null || _selectedGroupMembers.isEmpty) {
        debugPrint('🔍 Can save (group mode): false - No group or members');
        return false;
      }
      
      // For equal mode, just need members
      if (_splitMode == 'equal') {
        debugPrint('🔍 Can save (group mode): true - Equal mode with ${_selectedGroupMembers.length} members');
        return true;
      }
      
      // For custom mode, check if splits are valid
      _updateGroupMemberSplits();
      final canSave = _customSplitType == 'amount' 
          ? _remainingAmount.abs() < 0.01
          : _remainingPercentage.abs() < 0.01;
      
      debugPrint('🔍 Can save (group mode - custom): $canSave');
      debugPrint('   - Remaining: ${_customSplitType == "amount" ? _remainingAmount : _remainingPercentage}');
      return canSave;
    } else {
      // For participants mode, use existing logic
      if (_participants.isEmpty) return false;

      if (_splitMode == 'equal') return true;

      if (_customSplitType == 'amount') {
        return _remainingAmount.abs() < 0.01;
      } else {
        return _remainingPercentage.abs() < 0.01;
      }
    }
  }

  Future<void> _createGroupSplitBill() async {
    if (widget.receiptId == null || widget.userId == null || widget.token == null) {
      debugPrint('❌ Missing required parameters for split bill creation');
      setState(() {
        _errorMessage = 'Unable to create split bill: missing required data';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      // Get current user email for paidByEmail
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final paidByEmail = userProvider.effectiveEmail;

      // Build participants list
      final participants = _selectedGroupMembers.asMap().entries.map((entry) {
        final index = entry.key;
        final member = entry.value;
        
        double share;
        
        if (_splitMode == 'equal') {
          share = widget.totalAmount / _selectedGroupMembers.length;
        } else if (_customSplitType == 'amount') {
          final controller = _amountControllers[index];
          share = controller != null && controller.text.isNotEmpty
              ? double.tryParse(controller.text) ?? 0.0
              : 0.0;
        } else {
          final controller = _percentageControllers[index];
          final percentage = controller != null && controller.text.isNotEmpty
              ? double.tryParse(controller.text) ?? 0.0
              : 0.0;
          share = (widget.totalAmount * percentage) / 100.0;
        }
        
        return {
          'email': member['email'] ?? '',
          'share': share,
          'name': member['name'] ?? '',
        };
      }).toList();

      // Prepare request body
      final requestBody = {
        'receiptId': widget.receiptId,
        'createdBy': widget.userId,
        'groupId': _selectedGroup!['id'],
        'paidByEmail': paidByEmail,
        'participants': participants,
      };

      debugPrint('📤 Creating split bill with group:');
      debugPrint('   Request body: ${json.encode(requestBody)}');

      // Call the API
      final response = await ApiService.post(
        '/split-bill',
        body: requestBody,
        token: widget.token,
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Split bill created successfully');
        
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        debugPrint('❌ Failed to create split bill: ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
        
        String errorMessage = 'Failed to create split bill';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {}
        
        if (mounted) {
          setState(() {
            _errorMessage = errorMessage;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error creating split bill: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF7E5EFD),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '   Split Bill',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total amount display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${widget.currencySymbol}${widget.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF7E5EFD),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Split Type Selection
                    const Text(
                      'Split Type:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _splitType = 'participants';
                                _selectedGroup = null;
                                _selectedGroupMembers = [];
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _splitType == 'participants' 
                                  ? const Color(0xFF7E5EFD) 
                                  : Colors.white,
                              foregroundColor: _splitType == 'participants' 
                                  ? Colors.white 
                                  : const Color(0xFF7E5EFD),
                              side: BorderSide(
                                color: _splitType == 'participants' 
                                    ? const Color(0xFF7E5EFD) 
                                    : Colors.grey.shade300,
                                width: _splitType == 'participants' ? 2 : 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 18,
                                  color: _splitType == 'participants' 
                                      ? Colors.white 
                                      : const Color(0xFF7E5EFD),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'With Participants',
                                    style: TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _splitType = 'group';
                                _participants.clear();
                                _emailController.clear();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _splitType == 'group' 
                                  ? const Color(0xFF7E5EFD) 
                                  : Colors.white,
                              foregroundColor: _splitType == 'group' 
                                  ? Colors.white 
                                  : const Color(0xFF7E5EFD),
                              side: BorderSide(
                                color: _splitType == 'group' 
                                    ? const Color(0xFF7E5EFD) 
                                    : Colors.grey.shade300,
                                width: _splitType == 'group' ? 2 : 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.group_outlined,
                                  size: 18,
                                  color: _splitType == 'group' 
                                      ? Colors.white 
                                      : const Color(0xFF7E5EFD),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'With Group',
                                    style: TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Group selection UI (when split type is 'group')
                    if (_splitType == 'group') ...[
                      // Split Mode selection
                      const Text(
                        'Split Mode:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _changeSplitMode('equal'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _splitMode == 'equal' ? const Color(0xFF7E5EFD) : Colors.white,
                                foregroundColor: _splitMode == 'equal' ? Colors.white : Colors.black,
                                side: BorderSide(
                                  color: _splitMode == 'equal' ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('=', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _changeSplitMode('custom'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _splitMode == 'custom' ? const Color(0xFF7E5EFD) : Colors.white,
                                foregroundColor: _splitMode == 'custom' ? Colors.white : Colors.black,
                                side: BorderSide(
                                  color: _splitMode == 'custom' ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Custom', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Select Group section
                      const Text(
                        'Select Group:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
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
                                  maxHeight: 300,
                                ),
                                offset: const Offset(0, fieldHeight),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedGroup != null 
                                            ? _selectedGroup!['name'] ?? 'Selected Group'
                                            : 'Choose a group',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _selectedGroup != null 
                                              ? Colors.black87 
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.keyboard_arrow_down, size: 18),
                                  ],
                                ),
                                itemBuilder: (BuildContext context) {
                                  if (_loadingGroups) {
                                    return [
                                      PopupMenuItem<Map<String, dynamic>>(
                                        enabled: false,
                                        child: const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ];
                                  }
                                  
                                  if (_groups.isEmpty) {
                                    return [
                                      PopupMenuItem<Map<String, dynamic>>(
                                        enabled: false,
                                        child: Text(
                                          'No groups found',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ];
                                  }
                                  
                                  return _groups.map((group) {
                                    return PopupMenuItem<Map<String, dynamic>>(
                                      value: group,
                                      child: Text(
                                        group['name'] ?? 'Unnamed Group',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }).toList();
                                },
                                onSelected: (Map<String, dynamic> value) {
                                  _selectGroup(value);
                                },
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Create New Group button - simple text button
                      TextButton.icon(
                        onPressed: _createNewGroup,
                        icon: const Icon(
                          Icons.add,
                          color: Color(0xFF7E5EFD),
                          size: 18,
                        ),
                        label: const Text(
                          'Create New Group',
                          style: TextStyle(
                            color: Color(0xFF7E5EFD),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          alignment: Alignment.centerLeft,
                        ),
                      ),

                      // Custom split type selection (when custom mode is selected)
                      if (_splitMode == 'custom') ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Custom Split Type:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _changeCustomSplitType('amount'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: _customSplitType == 'amount' ? const Color(0xFF7E5EFD) : Colors.white,
                                  foregroundColor: _customSplitType == 'amount' ? Colors.white : Colors.black,
                                  side: BorderSide(
                                    color: _customSplitType == 'amount' ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(widget.currencySymbol, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _changeCustomSplitType('percentage'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: _customSplitType == 'percentage' ? const Color(0xFF7E5EFD) : Colors.white,
                                  foregroundColor: _customSplitType == 'percentage' ? Colors.white : Colors.black,
                                  side: BorderSide(
                                    color: _customSplitType == 'percentage' ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Selected Members section - display all members with edit fields for custom mode
                      if (_selectedGroupMembers.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Selected Members:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        
                        // Show editable fields in custom mode
                        if (_splitMode == 'custom') ...[
                          ..._selectedGroupMembers.asMap().entries.map((entry) {
                            final index = entry.key;
                            final member = entry.value;
                            final name = member['name']?.toString() ?? member['email']?.toString() ?? '';
                            final email = member['email']?.toString() ?? '';
                            
                            // Ensure controllers exist for this member
                            if (!_amountControllers.containsKey(index)) {
                              _amountControllers[index] = TextEditingController();
                            }
                            if (!_percentageControllers.containsKey(index)) {
                              _percentageControllers[index] = TextEditingController();
                            }
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      name,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _customSplitType == 'amount' 
                                          ? _amountControllers[index]
                                          : _percentageControllers[index],
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        hintText: _customSplitType == 'amount' ? '0.00' : '0',
                                        prefixText: _customSplitType == 'amount' ? widget.currencySymbol : null,
                                        suffixText: _customSplitType == 'percentage' ? '%' : null,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 13),
                                      onChanged: (value) {
                                        setState(() {
                                          _updateGroupMemberSplits();
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          
                          // Show remaining amount/percentage
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _customSplitType == 'amount' ? 'Remaining:' : 'Remaining %:',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _customSplitType == 'amount'
                                      ? '${widget.currencySymbol}${_remainingAmount.toStringAsFixed(2)}'
                                      : '${_remainingPercentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: (_customSplitType == 'amount' 
                                        ? _remainingAmount.abs() < 0.01 
                                        : _remainingPercentage.abs() < 0.01)
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Show member chips for equal mode
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _selectedGroupMembers.map((member) {
                              final name = member['name']?.toString() ?? member['email']?.toString() ?? '';
                              final email = member['email']?.toString() ?? '';
                              final initials = name.isNotEmpty 
                                  ? name.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
                                  : email.isNotEmpty 
                                      ? email[0].toUpperCase()
                                      : '?';
                              final userId = member['userId']?.toString() ?? '';
                              final avatarColor = _getAvatarColorForMember(userId);
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: avatarColor,
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
                                    const SizedBox(width: 6),
                                    Text(
                                      name.isNotEmpty ? name.split(' ').first : email.split('@').first,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ],

                    // Split mode selection (for participants mode)
                    if (_splitType == 'participants') ...[
                      const Text(
                        'Split Mode:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _changeSplitMode('equal'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _splitMode == 'equal' ? const Color(0xFF7E5EFD) : Colors.white,
                                foregroundColor: _splitMode == 'equal' ? Colors.white : Colors.black,
                                side: BorderSide(
                                  color: _splitMode == 'equal' ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('=', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _changeSplitMode('custom'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _splitMode == 'custom' ? const Color(0xFF7E5EFD) : Colors.white,
                                foregroundColor: _splitMode == 'custom' ? Colors.white : Colors.black,
                                side: BorderSide(
                                  color: _splitMode == 'custom' ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Custom', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      ),

                    // Custom split type selection
                    if (_splitMode == 'custom') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Custom Split Type:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _changeCustomSplitType('amount'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _customSplitType == 'amount' ? const Color(0xFF7E5EFD) : Colors.white,
                                foregroundColor: _customSplitType == 'amount' ? Colors.white : Colors.black,
                                side: BorderSide(
                                  color: _customSplitType == 'amount' ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(widget.currencySymbol, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _changeCustomSplitType('percentage'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _customSplitType == 'percentage' ? const Color(0xFF7E5EFD) : Colors.white,
                                foregroundColor: _customSplitType == 'percentage' ? Colors.white : Colors.black,
                                side: BorderSide(
                                  color: _customSplitType == 'percentage' ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                    ],

                    const SizedBox(height: 16),

                    // Add participant section with autocomplete (only for participants mode)
                    if (_splitType == 'participants') ...[
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter participant\'s email',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF7E5EFD)),
                                    suffixIcon: _emailController.text.isNotEmpty
                                        ? IconButton(
                                      icon: Icon(Icons.clear, color: Colors.grey.shade400),
                                      onPressed: () {
                                        _emailController.clear();
                                        setState(() {
                                          _showContactDropdown = false;
                                          _emailError = null;
                                        });
                                      },
                                    )
                                        : (_allContacts.isNotEmpty
                                        ? Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400)
                                        : null),
                                    errorText: _emailError,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.done,
                                  onTap: () {
                                    // Show dropdown with filtered contacts when text field is tapped
                                    if (_allContacts.isNotEmpty && _emailController.text.isEmpty) {
                                      setState(() {
                                        _filteredContacts = _allContacts;
                                        _showContactDropdown = true;
                                      });
                                    }
                                  },
                                  onSubmitted: (value) {
                                    if (value.isNotEmpty) {
                                      _addParticipant();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7E5EFD),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7E5EFD).withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: _addParticipant,
                                  icon: const Icon(Icons.add, color: Colors.white, size: 24),
                                  tooltip: 'Add Participant',
                                ),
                              ),
                            ],
                          ),
                          _buildContactDropdown(),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Participants list (only for participants mode)
                    if (_splitType == 'participants' && _participants.isNotEmpty) ...[
                      const Text(
                        'Every participant\'s details will be shared',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Participants:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      // Removed explicit maxHeight to allow dynamic scrolling by SingleChildScrollView
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(), // Let the parent SingleChildScrollView handle scrolling
                        itemCount: _participants.length,
                        itemBuilder: (context, index) {
                          final participant = _participants[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8E6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        participant.email,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_splitMode == 'equal') ...[
                                  Text(
                                    '${widget.currencySymbol}${participant.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7E5EFD),
                                    ),
                                  ),
                                ] else if (_customSplitType == 'amount') ...[
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      decoration: InputDecoration(
                                        prefixText: widget.currencySymbol,
                                        border: const OutlineInputBorder(),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                      ],
                                      controller: _amountControllers[index],
                                      onChanged: (value) {
                                        final amount = double.tryParse(value) ?? 0.0;
                                        _updateParticipantAmount(index, amount);
                                      },
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ] else ...[
                                  SizedBox(
                                    width: 60,
                                    child: TextField(
                                      decoration: const InputDecoration(
                                        suffixText: '%',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                      ],
                                      controller: _percentageControllers[index],
                                      onChanged: (value) {
                                        final percentage = double.tryParse(value) ?? 0.0;
                                        _updateParticipantPercentage(index, percentage);
                                      },
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${widget.currencySymbol}${participant.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7E5EFD),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => _removeParticipant(index),
                                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Remaining amount/percentage display
                      if (_splitMode == 'custom') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _canSave() ? Colors.green.shade100 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_customSplitType == 'percentage' ? 'Remaining:' : 'Remaining:'),
                              Text(
                                _customSplitType == 'percentage'
                                    ? '${_remainingPercentage.toStringAsFixed(1)}%'
                                    : '${widget.currencySymbol}${_remainingAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _canSave() ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // Error Message Display
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red.shade700, size: 18),
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

            // Loading Indicator
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                ),
              ),

            // Actions
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  if (widget.existingParticipants != null && widget.existingParticipants!.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        widget.onClearSplit?.call();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_canSave() && !_isLoading) ? () async {
                        setState(() {
                          _errorMessage = null;
                        });
                        if (_splitType == 'group' && _selectedGroup != null) {
                          // Call the API to create split bill for group
                          await _createGroupSplitBill();
                        } else {
                          widget.onSave(_participants);
                          Navigator.pop(context);
                        }
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(_splitType == 'group' ? 'Add Receipt' : 'Save Split'),
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

// Custom painter for dashed border with rounded corners
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.borderRadius,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    // Draw dashed border - simplified approach
    _drawDashedRect(canvas, rect, paint);
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    final totalDashLength = dashWidth + dashSpace;
    
    // Top edge
    _drawDashedLine(
      canvas,
      Offset(rect.left + borderRadius, rect.top),
      Offset(rect.right - borderRadius, rect.top),
      paint,
    );
    
    // Right edge
    _drawDashedLine(
      canvas,
      Offset(rect.right, rect.top + borderRadius),
      Offset(rect.right, rect.bottom - borderRadius),
      paint,
    );
    
    // Bottom edge
    _drawDashedLine(
      canvas,
      Offset(rect.right - borderRadius, rect.bottom),
      Offset(rect.left + borderRadius, rect.bottom),
      paint,
    );
    
    // Left edge
    _drawDashedLine(
      canvas,
      Offset(rect.left, rect.bottom - borderRadius),
      Offset(rect.left, rect.top + borderRadius),
      paint,
    );
    
    // Draw corner arcs (simplified - solid arcs for corners)
    if (borderRadius > 0) {
      final cornerPaint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      
      // Top-right corner
      canvas.drawArc(
        Rect.fromLTWH(rect.right - borderRadius * 2, rect.top, borderRadius * 2, borderRadius * 2),
        0,
        1.5708, // 90 degrees
        false,
        cornerPaint,
      );
      
      // Bottom-right corner
      canvas.drawArc(
        Rect.fromLTWH(rect.right - borderRadius * 2, rect.bottom - borderRadius * 2, borderRadius * 2, borderRadius * 2),
        1.5708,
        1.5708,
        false,
        cornerPaint,
      );
      
      // Bottom-left corner
      canvas.drawArc(
        Rect.fromLTWH(rect.left, rect.bottom - borderRadius * 2, borderRadius * 2, borderRadius * 2),
        3.14159,
        1.5708,
        false,
        cornerPaint,
      );
      
      // Top-left corner
      canvas.drawArc(
        Rect.fromLTWH(rect.left, rect.top, borderRadius * 2, borderRadius * 2),
        4.71239,
        1.5708,
        false,
        cornerPaint,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final distance = (end - start).distance;
    if (distance == 0) return;
    
    final totalDashLength = dashWidth + dashSpace;
    final direction = (end - start) / distance;
    
    double currentDistance = 0.0;
    while (currentDistance < distance) {
      final dashStart = start + direction * currentDistance;
      final remainingDistance = distance - currentDistance;
      final dashLength = dashWidth < remainingDistance ? dashWidth : remainingDistance;
      final dashEnd = dashStart + direction * dashLength;
      
      canvas.drawLine(dashStart, dashEnd, paint);
      
      currentDistance += totalDashLength;
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}