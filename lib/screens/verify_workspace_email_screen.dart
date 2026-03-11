import 'package:flutter/material.dart';

import '../services/workspace_service.dart';
import 'workspace_onboarding_screen.dart';
import 'workspace_team_size_screen.dart';

class VerifyWorkspaceEmailScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String email;

  const VerifyWorkspaceEmailScreen({
    Key? key,
    required this.userId,
    required this.token,
    required this.email,
  }) : super(key: key);

  @override
  State<VerifyWorkspaceEmailScreen> createState() => _VerifyWorkspaceEmailScreenState();
}

class _VerifyWorkspaceEmailScreenState extends State<VerifyWorkspaceEmailScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  // Generate a workspace name from email
  String _generateWorkspaceName(String email) {
    try {
      // Extract the part before @ and capitalize it
      final username = email.split('@')[0];
      // Replace dots, underscores with spaces and capitalize first letter
      final cleanName = username
          .replaceAll('.', ' ')
          .replaceAll('_', ' ')
          .replaceAll(RegExp(r'\d+'), '') // Remove numbers
          .trim();
      
      if (cleanName.isEmpty) {
        return 'My Workspace';
      }
      
      // Capitalize first letter of each word
      final words = cleanName.split(' ');
      final capitalized = words.map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
      
      return '$capitalized Workspace';
    } catch (e) {
      return 'My Workspace';
    }
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      // Call API to verify the code
      final result = await WorkspaceService.verifyCompanyEmailCode(
        userId: widget.userId,
        companyEmail: widget.email,
        code: _code,
        token: widget.token,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final hasWorkspace = data['hasWorkspace'] ?? false;

        if (hasWorkspace) {
          // User already has a workspace, show message and go to workspace onboarding
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Workspace already exists for this email!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WorkspaceOnboardingScreen(
                userId: widget.userId,
                token: widget.token,
              ),
            ),
          );
        } else {
          // No workspace yet, go to team size screen to continue setup
          // Generate a default workspace name from the email
          final defaultWorkspaceName = _generateWorkspaceName(widget.email);
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WorkspaceTeamSizeScreen(
                userId: widget.userId,
                token: widget.token,
                workspaceName: defaultWorkspaceName,
                companyEmail: widget.email,
              ),
            ),
          );
        }
      } else {
        // Show error with detailed message
        final errorMessage = result['error']?.toString() ?? 'Invalid verification code';
        final statusCode = result['statusCode'];
        
        debugPrint('❌ Verification failed: $errorMessage (Status: $statusCode)');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              statusCode == 500 
                ? 'Server error: $errorMessage\nPlease try again or contact support.'
                : errorMessage,
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verify Email',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: const Center(
                child: Text(
                  'MR',
                  style: TextStyle(
                    color: Color(0xFF7E5EFD),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Enter Verification Code',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We've sent a 6–digit code to ${widget.email}",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 40,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 0,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF7E5EFD),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) => _onDigitChanged(index, value),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            const Text(
              'Code expires in 04:59',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Verify & Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Change Email',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Didn't receive the code? ",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    // Resend verification code
                    try {
                      final result = await WorkspaceService.sendCompanyEmailCode(
                        userId: widget.userId,
                        companyEmail: widget.email,
                        token: widget.token,
                      );
                      
                      if (mounted) {
                        if (result['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Verification code resent successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['error']?.toString() ?? 'Failed to resend code'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Resend Code',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7E5EFD),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



