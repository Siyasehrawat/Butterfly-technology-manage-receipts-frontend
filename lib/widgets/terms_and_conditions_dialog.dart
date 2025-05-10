import 'package:flutter/material.dart';

class TermsAndConditionsDialog extends StatelessWidget {
  const TermsAndConditionsDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Terms and Conditions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Acceptance of Terms',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'By accessing or using the Manage Receipt application, you agree to be bound by these Terms and Conditions and all applicable laws and regulations. If you do not agree with any of these terms, you are prohibited from using or accessing this application.',
                    ),
                    SizedBox(height: 16),
                    Text(
                      '2. Use License',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Permission is granted to temporarily use the Manage Receipt application for personal, non-commercial purposes only. This is the grant of a license, not a transfer of title.',
                    ),
                    SizedBox(height: 16),
                    Text(
                      '3. User Account',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'To use certain features of the application, you must register for an account. You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.',
                    ),
                    SizedBox(height: 16),
                    Text(
                      '4. Privacy Policy',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your use of the Manage Receipt application is also governed by our Privacy Policy, which is incorporated into these Terms and Conditions by reference.',
                    ),
                    SizedBox(height: 16),
                    Text(
                      '5. Data Storage',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'We store receipt data on secure servers. While we implement safeguards, no system is 100% secure. We cannot guarantee absolute security of your data.',
                    ),
                    SizedBox(height: 16),
                    Text(
                      '6. Limitation of Liability',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The Manage Receipt application and its services are provided "as is" without warranties of any kind. In no event shall Manage Receipt be liable for any damages arising out of the use or inability to use the application.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}