import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';
import 'dashboard_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  final WidgetBuilder? navigateToAfterSave;

  const CompleteProfileScreen({super.key, this.navigateToAfterSave});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCountry;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>();
    _selectedCountry = user.country;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userProvider = context.read<UserProvider>();
    
    // Validate required fields
    if (_selectedCountry == null || _selectedCountry!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your country'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (userProvider.userId == null || userProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User session not found. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // Call the complete-profile API endpoint
      final response = await ApiService.post(
        '/users/complete-profile',
        body: {
          'userId': userProvider.userId!,
          'country': _selectedCountry!,
        },
        token: userProvider.token!,
      );

      if (response.statusCode == 200) {
        // Profile completed successfully
        final responseData = json.decode(response.body);
        
        // Update the user provider with the new information
        userProvider.updateUserInfo(
          userId: userProvider.userId!,
          token: userProvider.token!,
        );
        
        await userProvider.setCountry(_selectedCountry!);
        
        // Update canUpdatePassword from backend response if provided
        final canUpdatePassword = responseData['canUpdatePassword'] ?? responseData['canupdatepassword'];
        if (canUpdatePassword != null) {
          await userProvider.setCanUpdatePassword(canUpdatePassword);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile completed successfully!'),
              backgroundColor: Color(0xFF7E5EFD),
            ),
          );
          
          if (widget.navigateToAfterSave != null) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: widget.navigateToAfterSave!),
              (route) => false,
            );
          } else {
            // Navigate to dashboard after completing profile
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  userId: userProvider.userId ?? '',
                  token: userProvider.token ?? '',
                ),
              ),
              (route) => false,
            );
          }
        }
      } else {
        // Handle API error response
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error'] ?? errorData['message'] ?? 'Failed to complete profile';
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error completing profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Complete Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
              MediaQuery.of(context).size.width > 600 ? 48 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last step - you\'re almost done!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your country to continue.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),

                // Info card explaining why country is needed
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7E5EFD).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info_outline, color: Color(0xFF7E5EFD), size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Why we need your country',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'We use your country information to provide accurate currency formats, tax calculations, and region-specific features for better receipt management.',
                              style: TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Select your country *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                DropdownMenu<String>(
                  initialSelection: _selectedCountry,
                  onSelected: (val) => setState(() => _selectedCountry = val),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'India', label: 'India'),
                    DropdownMenuEntry(value: 'United States', label: 'United States'),
                  ],
                  menuHeight: 200,
                  hintText: 'Choose your country',
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E5EFD),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'COMPLETE PROFILE',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


