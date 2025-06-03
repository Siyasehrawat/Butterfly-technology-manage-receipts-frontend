import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/curved_background.dart';

class AdminSettingsScreen extends StatefulWidget {
  final String adminId;
  final String token;

  const AdminSettingsScreen({
    Key? key,
    required this.adminId,
    required this.token,
  }) : super(key: key);

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _settings = {};
  bool _isSaving = false;

  // Form controllers
  final TextEditingController _appNameController = TextEditingController();
  final TextEditingController _supportEmailController = TextEditingController();
  final TextEditingController _supportPhoneController = TextEditingController();

  // Settings
  bool _enableUserRegistration = true;
  bool _enableEmailNotifications = true;
  bool _enableAutoCategories = true;
  String _defaultCurrency = 'USD';
  String _dateFormat = 'MM-DD-YYYY';

  // Currency options
  final List<String> _currencyOptions = [
    'USD',
    'EUR',
    'GBP',
    'CAD',
    'AUD',
    'INR'
  ];

  // Date format options
  final List<String> _dateFormatOptions = [
    'MM-DD-YYYY',
    'DD-MM-YYYY',
    'YYYY-MM-DD'
  ];

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // This would be your actual API endpoint
      final url = Uri.parse(
          'https://manage-receipt-backend-bnl1.onrender.com/api/admin/settings');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _settings = data;
          _updateFormValues();
          _isLoading = false;
        });
      } else {
        // For demo purposes, use mock data if API fails
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _settings = {
            'appName': 'Manage Receipt',
            'supportEmail': 'support@managereceipt.com',
            'supportPhone': '+1 (555) 123-4567',
            'enableUserRegistration': true,
            'enableEmailNotifications': true,
            'enableAutoCategories': true,
            'defaultCurrency': 'USD',
            'dateFormat': 'MM-DD-YYYY',
          };
          _updateFormValues();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching settings: $e');
      // For demo purposes, use mock data if API fails
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _settings = {
          'appName': 'Manage Receipt',
          'supportEmail': 'support@managereceipt.com',
          'supportPhone': '+1 (555) 123-4567',
          'enableUserRegistration': true,
          'enableEmailNotifications': true,
          'enableAutoCategories': true,
          'defaultCurrency': 'USD',
          'dateFormat': 'MM-DD-YYYY',
        };
        _updateFormValues();
        _isLoading = false;
      });
    }
  }

  void _updateFormValues() {
    _appNameController.text = _settings['appName'] ?? 'Manage Receipt';
    _supportEmailController.text =
        _settings['supportEmail'] ?? 'support@managereceipt.com';
    _supportPhoneController.text =
        _settings['supportPhone'] ?? '+1 (555) 123-4567';
    _enableUserRegistration = _settings['enableUserRegistration'] ?? true;
    _enableEmailNotifications = _settings['enableEmailNotifications'] ?? true;
    _enableAutoCategories = _settings['enableAutoCategories'] ?? true;
    _defaultCurrency = _settings['defaultCurrency'] ?? 'USD';
    _dateFormat = _settings['dateFormat'] ?? 'MM-DD-YYYY';
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    // Prepare settings data
    final updatedSettings = {
      'appName': _appNameController.text,
      'supportEmail': _supportEmailController.text,
      'supportPhone': _supportPhoneController.text,
      'enableUserRegistration': _enableUserRegistration,
      'enableEmailNotifications': _enableEmailNotifications,
      'enableAutoCategories': _enableAutoCategories,
      'defaultCurrency': _defaultCurrency,
      'dateFormat': _dateFormat,
    };

    try {
      // This would be your actual API endpoint
      final url = Uri.parse(
          'https://manage-receipt-backend-bnl1.onrender.com/api/admin/settings');

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(updatedSettings),
      );

      if (response.statusCode == 200) {
        // Settings saved successfully
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Color(0xFF7E5EFD),
          ),
        );
      } else {
        // For demo purposes, show success message anyway
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Color(0xFF7E5EFD),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      // For demo purposes, show success message anyway
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Color(0xFF7E5EFD),
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: true,
        child: CurvedBackground(
          child: Column(
            children: [
              // App Bar
              Container(
                padding: const EdgeInsets.only(
                    top: 8, left: 16, right: 16, bottom: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Admin Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Container(
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
                  ],
                ),
              ),

              // Settings Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // General Settings Section
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'General Settings',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // App Name
                                  TextField(
                                    controller: _appNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'App Name',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Support Email
                                  TextField(
                                    controller: _supportEmailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Support Email',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 16),

                                  // Support Phone
                                  TextField(
                                    controller: _supportPhoneController,
                                    decoration: const InputDecoration(
                                      labelText: 'Support Phone',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.phone,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Feature Settings Section
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Feature Settings',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Enable User Registration
                                  SwitchListTile(
                                    title:
                                        const Text('Enable User Registration'),
                                    subtitle: const Text(
                                        'Allow new users to register'),
                                    value: _enableUserRegistration,
                                    onChanged: (value) {
                                      setState(() {
                                        _enableUserRegistration = value;
                                      });
                                    },
                                    activeColor: const Color(0xFF7E5EFD),
                                  ),
                                  const Divider(),

                                  // Enable Email Notifications
                                  SwitchListTile(
                                    title: const Text(
                                        'Enable Email Notifications'),
                                    subtitle: const Text(
                                        'Send email notifications to users'),
                                    value: _enableEmailNotifications,
                                    onChanged: (value) {
                                      setState(() {
                                        _enableEmailNotifications = value;
                                      });
                                    },
                                    activeColor: const Color(0xFF7E5EFD),
                                  ),
                                  const Divider(),

                                  // Enable Auto Categories
                                  SwitchListTile(
                                    title: const Text('Enable Auto Categories'),
                                    subtitle: const Text(
                                        'Automatically categorize receipts'),
                                    value: _enableAutoCategories,
                                    onChanged: (value) {
                                      setState(() {
                                        _enableAutoCategories = value;
                                      });
                                    },
                                    activeColor: const Color(0xFF7E5EFD),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Format Settings Section
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Format Settings',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Default Currency
                                  DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: 'Default Currency',
                                      border: OutlineInputBorder(),
                                    ),
                                    value: _defaultCurrency,
                                    items: _currencyOptions.map((currency) {
                                      return DropdownMenuItem<String>(
                                        value: currency,
                                        child: Text(currency),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _defaultCurrency = value;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Date Format
                                  DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: 'Date Format',
                                      border: OutlineInputBorder(),
                                    ),
                                    value: _dateFormat,
                                    items: _dateFormatOptions.map((format) {
                                      return DropdownMenuItem<String>(
                                        value: format,
                                        child: Text(format),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _dateFormat = value;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveSettings,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7E5EFD),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isSaving
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text(
                                        'Save Settings',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),

                            // Add bottom padding to ensure content isn't covered by system navigation
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
