import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const NoInternetScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        elevation: 0,
        title: const Center(
          child: AppLogo(isHeaderLogo: true),
        ),
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "OOPS!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48, // Larger font size
                  fontWeight: FontWeight.w900, // Extra bold
                  color: Color(0xFF7E5EFD), // Purple color
                ),
              ),
              const SizedBox(height: 32), // Spacing after OOPS!
              Image.asset(
                'assets/offline.png', // Use the path you provided
                width: 200, // Adjust size as needed
                height: 200, // Adjust size as needed
              ),
              const SizedBox(height: 16), // Adjusted spacing after image
              const Text(
                "looks like you are offline, please check\nyour internet connection",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16, // Slightly smaller font size
                  fontWeight: FontWeight.w500,
                  color: Colors.grey, // Grey color
                ),
              ),
              const SizedBox(height: 40), // Adjusted spacing before button
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD), // Purple background
                  foregroundColor: Colors.white, // White text
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30), // Rounded corners
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32), // Smaller padding
                  minimumSize: const Size(150, 48), // Smaller fixed size
                ),
                child: const Text(
                  "Retry",
                  style: TextStyle(
                    fontSize: 16, // Adjusted font size
                    fontWeight: FontWeight.w600,
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
