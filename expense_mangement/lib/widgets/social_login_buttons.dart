import 'package:flutter/material.dart';

class SocialLoginButtons extends StatefulWidget {
  final bool requireTermsAcceptance;
  final bool termsAccepted;

  const SocialLoginButtons({
    super.key,
    required this.requireTermsAcceptance,
    required this.termsAccepted
  });

  @override
  State<SocialLoginButtons> createState() => _SocialLoginButtonsState();
}

class _SocialLoginButtonsState extends State<SocialLoginButtons> {
  @override
  Widget build(BuildContext context) {
    // Return an empty container to hide social login buttons
    return Container();
  }
}