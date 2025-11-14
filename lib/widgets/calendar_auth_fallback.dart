import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fallback widget for Google Calendar OAuth when WebView is not available
/// Opens OAuth in external browser and provides instructions to user
class CalendarAuthFallback extends StatefulWidget {
  final String authUrl;
  final String userId;
  
  const CalendarAuthFallback({
    Key? key,
    required this.authUrl,
    required this.userId,
  }) : super(key: key);
  
  @override
  State<CalendarAuthFallback> createState() => _CalendarAuthFallbackState();
}

class _CalendarAuthFallbackState extends State<CalendarAuthFallback> {
  bool _browserOpened = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _openInBrowser();
  }
  
  Future<void> _openInBrowser() async {
    try {
      debugPrint('🌐 Opening OAuth URL in external browser: ${widget.authUrl}');
      
      if (await canLaunchUrl(Uri.parse(widget.authUrl))) {
        await launchUrl(
          Uri.parse(widget.authUrl),
          mode: LaunchMode.externalApplication,
        );
        
        setState(() {
          _browserOpened = true;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Cannot open browser. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to open external browser: $e');
      setState(() {
        _errorMessage = 'Failed to open browser: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text(
          'Connect Google Calendar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_errorMessage != null) ...[
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _openInBrowser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ] else ...[
              // Success state - browser opened
              const Icon(
                Icons.open_in_browser,
                size: 64,
                color: Color(0xFF7E5EFD),
              ),
              const SizedBox(height: 24),
              const Text(
                'Authentication Opened in Browser',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please complete the Google Calendar authentication in your browser.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E5EFD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7E5EFD).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Steps to complete:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF7E5EFD),
                      ),
                    ),
                    SizedBox(height: 12),
                    _StepItem(number: '1', text: 'Sign in to your Google account'),
                    _StepItem(number: '2', text: 'Grant calendar permissions'),
                    _StepItem(number: '3', text: 'Return to this app'),
                    _StepItem(number: '4', text: 'Tap "I\'m Done" below'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _openInBrowser,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7E5EFD),
                        side: const BorderSide(color: Color(0xFF7E5EFD)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Open Again'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'I\'m Done',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String number;
  final String text;
  
  const _StepItem({
    required this.number,
    required this.text,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF7E5EFD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


