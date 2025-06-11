import 'package:flutter/material.dart';

class CurvedBackground extends StatelessWidget {
  final Widget child;

  const CurvedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // Purple background with curved bottom
        Container(
          width: double.infinity,
          height: screenHeight * 0.45, // 45% of screen height
          decoration: const BoxDecoration(
            color: Color(0xFF7E5EFD),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        // Content
        SafeArea(child: child),
      ],
    );
  }
}