import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../utils/split_participant.dart';
import '../services/contact_service.dart';

class SplitDialog extends StatefulWidget {
  final double totalAmount;
  final List<SplitParticipant>? existingParticipants;
  final Function(List<SplitParticipant>) onSave;
  final Function()? onClearSplit;
  final String currencySymbol;
  final String? defaultEmail;
  final String? userId;
  final String? token;

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

  @override
  void initState() {
    super.initState();
    _remainingAmount = widget.totalAmount;
    _loadContacts();
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

  bool _canSave() {
    if (_participants.isEmpty) return false;

    if (_splitMode == 'equal') return true;

    if (_customSplitType == 'amount') {
      return _remainingAmount.abs() < 0.01;
    } else {
      return _remainingPercentage.abs() < 0.01;
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

                    // Split mode selection
                    const Text(
                      'Split Mode:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('=', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            selected: _splitMode == 'equal',
                            onSelected: (_) => _changeSplitMode('equal'),
                            selectedColor: const Color(0xFF7E5EFD),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            labelStyle: TextStyle(
                              color: _splitMode == 'equal' ? Colors.white : Colors.black,
                            ),
                            showCheckmark: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Custom'),
                              ],
                            ),
                            selected: _splitMode == 'custom',
                            onSelected: (_) => _changeSplitMode('custom'),
                            selectedColor: const Color(0xFF7E5EFD),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            labelStyle: TextStyle(
                              color: _splitMode == 'custom' ? Colors.white : Colors.black,
                            ),
                            showCheckmark: false,
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
                            child: ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(widget.currencySymbol, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 2),
                                  const Text(''),
                                ],
                              ),
                              selected: _customSplitType == 'amount',
                              onSelected: (_) => _changeCustomSplitType('amount'),
                              selectedColor: const Color(0xFF7E5EFD),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              labelStyle: TextStyle(
                                color: _customSplitType == 'amount' ? Colors.white : Colors.black,
                              ),
                              showCheckmark: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('%', style: TextStyle(fontSize: 16)),
                                  SizedBox(width: 2),
                                  Text(''),
                                ],
                              ),
                              selected: _customSplitType == 'percentage',
                              onSelected: (_) => _changeCustomSplitType('percentage'),
                              selectedColor: const Color(0xFF7E5EFD),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              labelStyle: TextStyle(
                                color: _customSplitType == 'percentage' ? Colors.white : Colors.black,
                              ),
                              showCheckmark: false,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Add participant section with autocomplete
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

                    const SizedBox(height: 16),

                    // Participants list
                    if (_participants.isNotEmpty) ...[
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
                      onPressed: _canSave() ? () {
                        widget.onSave(_participants);
                        Navigator.pop(context);
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        foregroundColor: Colors.white,
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
}