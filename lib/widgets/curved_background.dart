import 'package:flutter/material.dart';

class CurvedBackground extends StatelessWidget {
  final Widget child;

  const CurvedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipPath(
            clipper: CurvedBackgroundClipper(),
            child: Container(
              color: const Color(0xFF7E5EFD),
            ),
          ),
        ),
        child, // The main screen content will be placed on top of this
      ],
    );
  }
}

// Custom Clipper for the curved design
class CurvedBackgroundClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.464); // Start from the left bottom of purple section

    path.quadraticBezierTo(
      size.width * 0.5, size.height * 0.55, // Control point
      size.width, size.height * 0.464, // End point (right side)
    );

    path.lineTo(size.width, 0); // Move to top-right
    path.close(); // Close the shape
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
