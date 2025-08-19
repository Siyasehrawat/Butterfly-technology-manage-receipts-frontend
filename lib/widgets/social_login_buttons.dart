import 'package:flutter/material.dart';

class SocialLoginButtons extends StatefulWidget {
  final bool requireTermsAcceptance;
  final bool termsAccepted;
  final Future<Map<String, dynamic>> Function()? onGoogle;
  final Future<Map<String, dynamic>> Function()? onApple;
  final bool showGoogle;
  final bool showApple;

  const SocialLoginButtons({
    super.key,
    required this.requireTermsAcceptance,
    required this.termsAccepted,
    this.onGoogle,
    this.onApple,
    this.showGoogle = true,
    this.showApple = true,
  });

  @override
  State<SocialLoginButtons> createState() => _SocialLoginButtonsState();
}

class _SocialLoginButtonsState extends State<SocialLoginButtons> {
  bool _isProcessing = false;

  void _maybeShowTermsSnackBar() {
    if (!widget.termsAccepted && widget.requireTermsAcceptance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms and Conditions to continue.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleTap(Future<Map<String, dynamic>> Function()? action) async {
    if (action == null) return;
    if (widget.requireTermsAcceptance && !widget.termsAccepted) {
      _maybeShowTermsSnackBar();
      return;
    }

    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool anyEnabled = (widget.showGoogle && widget.onGoogle != null) || (widget.showApple && widget.onApple != null);
    if (!anyEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: const [
              Expanded(child: Divider(thickness: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Or Connect Using',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(child: Divider(thickness: 1)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.showGoogle && widget.onGoogle != null)
                  Container(
                    width: 52,
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: _SocialIconButton(
                      assetPath: 'assets/google.png',
                      semanticLabel: 'Continue with Google',
                      onTap: () => _handleTap(widget.onGoogle),
                      disabled: _isProcessing,
                    ),
                  ),
                if (widget.showApple && widget.onApple != null)
                  Container(
                    width: 52,
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: _SocialIconButton(
                      assetPath: 'assets/apple.png',
                      semanticLabel: 'Continue with Apple',
                      onTap: () => _handleTap(widget.onApple),
                      disabled: _isProcessing,
                      isApple: true,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final String assetPath;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool disabled;
  final bool isApple;

  const _SocialIconButton({
    required this.assetPath,
    required this.semanticLabel,
    this.onTap,
    this.disabled = false,
    this.isApple = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isApple ? Colors.black : const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isApple ? Colors.black : const Color(0xFFE5E5E5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  semanticLabel: semanticLabel,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
