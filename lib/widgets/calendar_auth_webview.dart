import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'calendar_auth_fallback.dart';

/// WebView widget for Google Calendar OAuth authentication
/// Handles the OAuth flow and automatically closes when authentication is complete
class CalendarAuthWebView extends StatefulWidget {
  final String authUrl;
  final String userId;
  
  const CalendarAuthWebView({
    Key? key,
    required this.authUrl,
    required this.userId,
  }) : super(key: key);
  
  @override
  State<CalendarAuthWebView> createState() => _CalendarAuthWebViewState();
}

class _CalendarAuthWebViewState extends State<CalendarAuthWebView> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _useExternalBrowser = false;
  
  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }
  
  void _initializeWebView() {
    try {
      // Check if we're on web platform or if WebView is not available
      if (kIsWeb) {
        debugPrint('🌐 Running on web platform, using external browser');
        _useExternalBrowser = true;
        _openInExternalBrowser();
        return;
      }
      
      // Initialize WebView for mobile platforms with proper user agent
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setUserAgent('Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              debugPrint('📱 Calendar Auth: Page started loading: $url');
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            },
            onPageFinished: (url) {
              debugPrint('📱 Calendar Auth: Page finished loading: $url');
              setState(() => _isLoading = false);
              
              // Check if we reached the success page
              if (_isSuccessUrl(url)) {
                debugPrint('✅ Calendar Auth: Success detected!');
                // Wait a bit for backend to save tokens, then close with success
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    Navigator.pop(context, true);
                  }
                });
              }
            },
            onWebResourceError: (error) {
              debugPrint('❌ Calendar Auth: WebView error: ${error.description}');
              setState(() {
                _errorMessage = 'Google Calendar integration is currently in development mode. Please contact support or try using external browser.';
                _isLoading = false;
              });
            },
            onNavigationRequest: (request) {
              debugPrint('📱 Calendar Auth: Navigation request: ${request.url}');
              
              // Check for Google OAuth error pages
              if (request.url.contains('error=403') || 
                  request.url.contains('disallowed_useragent') ||
                  request.url.contains('Access blocked') ||
                  request.url.contains('access_denied') ||
                  request.url.contains('verification process') ||
                  request.url.contains('developer-approved testers')) {
                debugPrint('❌ Google OAuth blocked or not verified');
                
                // Show specific error dialog for verification issues
                if (request.url.contains('verification process') || 
                    request.url.contains('developer-approved testers')) {
                  _showGoogleVerificationError();
                } else {
                  // For other errors, try external browser
                  _openInExternalBrowser();
                }
                
                return NavigationDecision.prevent;
              }
              
              // Allow all other navigation
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.authUrl));
        
    } catch (e) {
      debugPrint('❌ WebView initialization failed: $e');
      // Fallback to external browser
      _useExternalBrowser = true;
      _openInExternalBrowser();
    }
  }
  
  void _openInExternalBrowser() async {
    try {
      debugPrint('🌐 Opening OAuth URL in external browser: ${widget.authUrl}');
      
      if (await canLaunchUrl(Uri.parse(widget.authUrl))) {
        await launchUrl(
          Uri.parse(widget.authUrl),
          mode: LaunchMode.externalApplication,
        );
        
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
        
        // Show instructions to user
        _showBrowserInstructions();
      } else {
        setState(() {
          _errorMessage = 'Cannot open browser. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to open external browser: $e');
      setState(() {
        _errorMessage = 'Failed to open browser: $e';
        _isLoading = false;
      });
    }
  }

  void _showGoogleVerificationError() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Google Calendar Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Google Calendar integration is currently in development mode and requires verification.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Solutions:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Contact support to be added as a test user\n'
                    '• Wait for Google verification to complete\n'
                    '• Use manual calendar sync as alternative',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, false);
              _openInExternalBrowser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text(
              'Try Anyway',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showBrowserInstructions() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: const [
            Icon(Icons.open_in_browser, color: Color(0xFF7E5EFD)),
            SizedBox(width: 8),
            Text('Complete Authentication'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A browser window has opened for Google authentication.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('1. Sign in to your Google account'),
            const Text('2. Grant calendar permissions'),
            const Text('3. Return to this app'),
            const Text('4. Tap "I\'m Done" below'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Note:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'If you see a "verification process" error, the Google Calendar integration is still in development. Contact support for access.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, false); // Close WebView with failure
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              // Wait a moment for backend to process
              await Future.delayed(const Duration(seconds: 2));
              
              // Close with success
              if (mounted) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E5EFD),
            ),
            child: const Text(
              'I\'m Done',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Check if the URL indicates successful authentication
  bool _isSuccessUrl(String url) {
    return url.contains('/oauth/callback') || 
           url.contains('calendar-connected') ||
           url.contains('success') ||
           url.toLowerCase().contains('calendar connected successfully');
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
      body: Stack(
        children: [
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                              _initializeWebView();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E5EFD),
                          ),
                          child: const Text(
                            'Try Again',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _openInExternalBrowser();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            'Use Browser',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else if (_useExternalBrowser)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.open_in_browser,
                      size: 64,
                      color: Color(0xFF7E5EFD),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Authentication Opened in Browser',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Please complete the authentication in your browser and return to this app.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'I\'m Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_controller != null)
            WebViewWidget(controller: _controller!)
          else
            // Fallback when WebView fails to initialize
            const Center(
              child: Text(
                'Initializing...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
            ),
          
          // Loading indicator
          if (_isLoading && !_useExternalBrowser)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading authentication...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}

