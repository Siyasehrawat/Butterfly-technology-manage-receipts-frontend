import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final bool isHeaderLogo;
  final bool isDrawerLogo;

  const AppLogo({
    super.key,
    this.isHeaderLogo = false,
    this.isDrawerLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isDrawerLogo) {
      // Logo for drawer header
      return Container(
        width: 140,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'Manage Receipt',
            style: TextStyle(
              color: Color(0xFF7E5EFD),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      );
    } else if (isHeaderLogo) {
      // Horizontal logo for headers (MR box + Manage Receipt text)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // MR Logo square
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Manage Receipt text
          const Text(
            'Manage Receipt',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      // Large logo for auth screens (centered with MR in middle and text below)
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // MR Logo square
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'MR',
                style: TextStyle(
                  color: Color(0xFF7E5EFD),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Manage Receipt text
          const Text(
            'Manage Receipt',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
  }
}