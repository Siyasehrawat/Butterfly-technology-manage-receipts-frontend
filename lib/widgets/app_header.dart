import 'package:flutter/material.dart';
import 'app_logo.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final bool showLogo;

  const AppHeader({
    super.key,
    this.title = '',
    this.onBackPressed,
    this.showLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF7E5EFD),
      padding: const EdgeInsets.only(top: 40, bottom: 16),
      child: Row(
        children: [
          if (onBackPressed != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBackPressed,
            )
          else
            const SizedBox(width: 16),

          if (showLogo)
          // Show the full logo
            const Expanded(
              child: Center(
                child: AppLogo(isHeaderLogo: true),
              ),
            )
          else
          // Show the title text
            Expanded(
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // MR logo on the right
          Container(
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
        ],
      ),
    );
  }
}