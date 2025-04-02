import 'package:flutter/material.dart';

class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or Connect Using',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSocialButton(
              onPressed: () {
                // Google login functionality would be implemented here
              },
              icon: Icons.g_mobiledata,
              color: Colors.red,
            ),
            _buildSocialButton(
              onPressed: () {
                // Facebook login functionality would be implemented here
              },
              icon: Icons.facebook,
              color: Colors.blue,
            ),
            _buildSocialButton(
              onPressed: () {
                // Apple login functionality would be implemented here
              },
              icon: Icons.apple,
              color: Colors.black,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 32,
        color: color,
      ),
    );
  }
}