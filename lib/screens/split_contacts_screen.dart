import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';

class SplitContactsScreen extends StatefulWidget {
  final String userId;
  final String token;

  const SplitContactsScreen({
    Key? key,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<SplitContactsScreen> createState() => _SplitContactsScreenState();
}

class _SplitContactsScreenState extends State<SplitContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredContacts = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF7E5EFD),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    _searchController.addListener(_onSearchChanged);
    _fetchContacts();
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterContacts();
    });
  }

  void _filterContacts() {
    if (_searchQuery.isEmpty) {
      _filteredContacts = List.from(_contacts);
    } else {
      _filteredContacts = _contacts.where((contact) {
        final name = (contact['name'] ?? '').toString().toLowerCase();
        final email = (contact['email'] ?? '').toString().toLowerCase();
        final phone = (contact['phone'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || 
               email.contains(query) || 
               phone.contains(query);
      }).toList();
    }
  }

  Future<void> _fetchContacts() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final response = await ApiService.get(
        '/split-bill/contacts/${widget.userId}',
        token: userProvider.token,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Contacts API Response: $data');
        
        // Handle the nested response structure: data.data.contacts
        final contactsData = data['data'];
        if (contactsData != null && contactsData['contacts'] != null) {
          final allContacts = List<Map<String, dynamic>>.from(contactsData['contacts']);
          
          // Show all contacts that have valid email addresses
          final validContacts = allContacts.where((contact) {
            final hasValidEmail = contact['email'] != null && 
                                 contact['email'].toString().trim().isNotEmpty &&
                                 contact['email'].toString().trim() != 'null';
            return hasValidEmail;
          }).toList();
          
          // Sort contacts: saved contacts first, then unsaved
          validContacts.sort((a, b) {
            final aIsSaved = a['isSavedContact'] == true;
            final bIsSaved = b['isSavedContact'] == true;
            
            if (aIsSaved && !bIsSaved) return -1;
            if (!aIsSaved && bIsSaved) return 1;
            
            // If both have same save status, sort by name (saved contacts) or email (unsaved)
            final aName = aIsSaved ? (a['name']?.toString() ?? '') : a['email']?.toString() ?? '';
            final bName = bIsSaved ? (b['name']?.toString() ?? '') : b['email']?.toString() ?? '';
            return aName.toLowerCase().compareTo(bName.toLowerCase());
          });
          
          setState(() {
            _contacts = validContacts;
            _filterContacts();
          });
          
          final savedCount = validContacts.where((c) => c['isSavedContact'] == true).length;
          final unsavedCount = validContacts.length - savedCount;
          debugPrint('Loaded ${validContacts.length} contacts: $savedCount saved, $unsavedCount from split receipts');
        } else {
          setState(() {
            _contacts = [];
            _filterContacts();
          });
        }
      } else {
        debugPrint('Failed to load contacts: ${response.statusCode} - ${response.body}');
        _showErrorSnackBar('Failed to load contacts. Please try again.');
      }
    } catch (e) {
      debugPrint("Error fetching contacts: $e");
      _showErrorSnackBar('Network error. Please check your internet connection.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                    // Check if email already exists
                    final existingContact = _contacts.firstWhere(
                      (contact) => contact['email']?.toLowerCase() == value.trim().toLowerCase(),
                      orElse: () => {},
                    );
                    if (existingContact.isNotEmpty) {
                      return 'This email already exists in your contacts';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number (Optional)',
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
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
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
                  Navigator.pop(context);
                  await _addContact(
                    nameController.text.trim(),
                    emailController.text.trim(),
                    phoneController.text.trim(),
                  );
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

  Future<void> _addContact(String name, String email, String phone) async {
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
        _showSuccessSnackBar('Contact added successfully');
        await _fetchContacts(); // Refresh the contacts list
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Failed to add contact';
        _showErrorSnackBar('Error: $errorMessage');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      debugPrint('Error adding contact: $e');
      _showErrorSnackBar('Network error. Please check your internet connection.');
    }
  }

  Future<void> _deleteContact(String contactId, String contactName) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final response = await ApiService.delete(
        '/split-bill/contacts/$contactId',
        token: userProvider.token,
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Contact deleted successfully');
        await _fetchContacts(); // Refresh the contacts list
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Failed to delete contact';
        _showErrorSnackBar('Error: $errorMessage');
      }
    } catch (e) {
      debugPrint('Error deleting contact: $e');
      _showErrorSnackBar('Network error. Please check your internet connection.');
    }
  }

  void _showDeleteConfirmation(String contactId, String contactName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delete Contact',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                  children: [
                    const TextSpan(text: 'Are you sure you want to delete '),
                    TextSpan(
                      text: '"$contactName"',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const TextSpan(text: ' from your contacts?'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, color: Colors.orange.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
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
              onPressed: () {
                Navigator.pop(context);
                _deleteContact(contactId, contactName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCompleteContactDialog(Map<String, dynamic> contact) {
    final nameController = TextEditingController(text: contact['name']?.toString().trim() ?? '');
    final emailController = TextEditingController(text: contact['email']?.toString().trim() ?? '');
    final phoneController = TextEditingController(text: contact['phone']?.toString().trim() ?? '');
    final formKey = GlobalKey<FormState>();
    final contactEmail = contact['email']?.toString().trim() ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_add,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Complete Contact Information',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name *',
                    hintText: 'Enter contact name',
                    prefixIcon: const Icon(Icons.person, color: Colors.orange),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange, width: 2),
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
                  enabled: false, // Email cannot be changed for existing split bill contacts
                  decoration: InputDecoration(
                    labelText: 'Email (From Split Bill)',
                    prefixIcon: const Icon(Icons.email, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    hintText: 'Enter phone number',
                    prefixIcon: const Icon(Icons.phone, color: Colors.orange),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange, width: 2),
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
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
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
                  Navigator.pop(context);
                  await _completeContactInfo(
                    contactEmail,
                    nameController.text.trim(),
                    phoneController.text.trim(),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Save Contact',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditContactDialog(Map<String, dynamic> contact) {
    final nameController = TextEditingController(text: contact['name'] ?? '');
    final emailController = TextEditingController(text: contact['email'] ?? '');
    final phoneController = TextEditingController(text: contact['phone'] ?? '');
    final formKey = GlobalKey<FormState>();
    final contactId = contact['id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E5EFD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit,
                  color: Color(0xFF7E5EFD),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Edit Contact',
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
                    // Check if email already exists (excluding current contact)
                    final existingContact = _contacts.firstWhere(
                      (c) => c['email']?.toLowerCase() == value.trim().toLowerCase() && 
                             c['id']?.toString() != contactId,
                      orElse: () => {},
                    );
                    if (existingContact.isNotEmpty) {
                      return 'This email already exists in your contacts';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
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
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
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
                  Navigator.pop(context);
                  await _updateContact(
                    contactId,
                    nameController.text.trim(),
                    emailController.text.trim(),
                    phoneController.text.trim(),
                  );
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
                'Update Contact',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeContactInfo(String email, String name, String phone) async {
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
              const SizedBox(height: 16),
              Text(
                'Saving contact information...',
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
        _showSuccessSnackBar('Contact information completed successfully');
        await _fetchContacts(); // Refresh the contacts list
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Failed to complete contact information';
        _showErrorSnackBar('Error: $errorMessage');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      debugPrint('Error completing contact info: $e');
      _showErrorSnackBar('Network error. Please check your internet connection.');
    }
  }

  Future<void> _updateContact(String contactId, String name, String email, String phone) async {
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
                'Updating contact...',
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
      };

      final response = await ApiService.put(
        '/split-bill/contacts/$contactId',
        body: requestBody,
        token: userProvider.token,
      );

      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Contact updated successfully');
        await _fetchContacts(); // Refresh the contacts list
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Failed to update contact';
        _showErrorSnackBar('Error: $errorMessage');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      debugPrint('Error updating contact: $e');
      _showErrorSnackBar('Network error. Please check your internet connection.');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF7E5EFD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildEmptyContactInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '0 total contacts',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'Get started by adding your first contact',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildContactCountInfo() {
    final savedContacts = _contacts.where((c) => c['isSavedContact'] == true).length;
    final unsavedContacts = _contacts.length - savedContacts;
    
    final filteredSaved = _filteredContacts.where((c) => c['isSavedContact'] == true).length;
    final filteredUnsaved = _filteredContacts.length - filteredSaved;
    
    if (_searchQuery.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_contacts.length} total contacts',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${savedContacts} saved • ${unsavedContacts} from split bills',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_filteredContacts.length} of ${_contacts.length} contacts',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${filteredSaved} saved • ${filteredUnsaved} from split bills',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        foregroundColor: Colors.white,
        title: const Text(
          'Manage Contacts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
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
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts by name, email or phone...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF7E5EFD)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
              ),
            ),
          ),

          // Contact Count Header with Add Button
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _isLoading ? 
                    const SizedBox() : 
                    _filteredContacts.isNotEmpty ? 
                      _buildContactCountInfo() :
                      _buildEmptyContactInfo(),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7E5EFD),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Add Contact Plus Icon
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF7E5EFD),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7E5EFD).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _showAddContactDialog,
                    icon: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 24,
                    ),
                    tooltip: 'Add Contact',
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),

          // Contacts List
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading contacts...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _filteredContacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _searchQuery.isEmpty ? Icons.contacts : Icons.search_off,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _searchQuery.isEmpty 
                                    ? 'No contacts found'
                                    : 'No contacts match your search',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'Add your first contact to get started with splitting bills'
                                    : 'Try adjusting your search terms or clear the search',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              if (_searchQuery.isEmpty)
                                ElevatedButton.icon(
                                  onPressed: _showAddContactDialog,
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  label: const Text(
                                    'Add Your First Contact',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7E5EFD),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24, 
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchContacts,
                          color: const Color(0xFF7E5EFD),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _filteredContacts.length,
                            itemBuilder: (context, index) {
                              final contact = _filteredContacts[index];
                              final name = contact['name']?.toString().trim() ?? '';
                              final email = contact['email']?.toString().trim() ?? '';
                              final phone = contact['phone']?.toString().trim() ?? '';
                              final contactId = contact['id']?.toString() ?? '';
                              final isSavedContact = contact['isSavedContact'] == true;
                              
                              // For unsaved contacts, show email as name if name is empty
                              final displayName = name.isNotEmpty ? name : 
                                                 (isSavedContact ? 'Unknown' : email.split('@')[0]);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSavedContact ? Colors.grey.shade200 : Colors.orange.shade300,
                                    width: isSavedContact ? 1 : 2,
                                  ),
                                ),
                                elevation: 2,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => isSavedContact 
                                      ? _showEditContactDialog(contact)
                                      : _showCompleteContactDialog(contact),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Stack(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: isSavedContact 
                                                  ? const Color(0xFF7E5EFD) 
                                                  : Colors.orange.shade400,
                                              radius: 28,
                                              child: Text(
                                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                ),
                                              ),
                                            ),
                                            if (!isSavedContact)
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  width: 20,
                                                  height: 20,
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.shade600,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.white, width: 2),
                                                  ),
                                                  child: const Icon(
                                                    Icons.edit,
                                                    size: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      displayName,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  if (!isSavedContact)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange.shade100,
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: Colors.orange.shade300),
                                                      ),
                                                      child: Text(
                                                        'Complete Info',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.orange.shade700,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.email_outlined,
                                                    size: 16,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      email,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (phone.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.phone_outlined,
                                                      size: 16,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      phone,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ] else if (!isSavedContact) ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.phone_outlined,
                                                      size: 16,
                                                      color: Colors.grey.shade400,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Phone No.',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade400,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              if (name.isEmpty && !isSavedContact) ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.person_outline,
                                                      size: 16,
                                                      color: Colors.grey.shade400,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Name',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade400,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          icon: Icon(
                                            Icons.more_vert,
                                            color: Colors.grey.shade600,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _showEditContactDialog(contact);
                                            } else if (value == 'complete') {
                                              _showCompleteContactDialog(contact);
                                            } else if (value == 'delete') {
                                              _showDeleteConfirmation(contactId, displayName);
                                            }
                                          },
                                          itemBuilder: (BuildContext context) => [
                                            if (isSavedContact)
                                              PopupMenuItem<String>(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.edit_outlined,
                                                      size: 20,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    const Text('Edit Contact'),
                                                  ],
                                                ),
                                              )
                                            else
                                              PopupMenuItem<String>(
                                                value: 'complete',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.edit_outlined,
                                                      size: 20,
                                                      color: Colors.orange.shade700,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      'Complete Info',
                                                      style: TextStyle(
                                                        color: Colors.orange.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (isSavedContact)
                                              PopupMenuItem<String>(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.delete_outline,
                                                      size: 20,
                                                      color: Colors.red,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      'Delete Contact',
                                                      style: TextStyle(
                                                        color: Colors.red.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
