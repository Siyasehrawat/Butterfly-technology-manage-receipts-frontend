import 'package:flutter/material.dart';

class AdminDetailedAnalyticsScreen extends StatelessWidget {
  final String adminId;
  final String token;

  const AdminDetailedAnalyticsScreen({
    Key? key,
    required this.adminId,
    required this.token,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        title: const Text('Admin - Detailed Analysis'),
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Detailed analytics coming soon',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

