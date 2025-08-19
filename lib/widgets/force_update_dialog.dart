import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;
  final String minRequiredVersion;
  final String message;
  final String downloadUrl;
  final bool forceUpdate;
  final bool optionalUpdate;
  final bool isVersionConflict;
  final VoidCallback? onLater;

  const ForceUpdateDialog({
    Key? key,
    required this.currentVersion,
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.message,
    required this.downloadUrl,
    this.forceUpdate = false,
    this.optionalUpdate = false,
    this.isVersionConflict = false,
    this.onLater,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !forceUpdate, // Prevent back button if force update
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Blurred background
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.6),
              ),
            ),
            // Centered compact dialog
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                width: 320, // Fixed smaller width
                constraints: const BoxConstraints(
                  maxHeight: 480, // Smaller max height
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16), // Smaller border radius
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Compact header with icon
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20), // Reduced padding
                      decoration: BoxDecoration(
                        color: _getHeaderColor(),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 60, // Smaller icon container
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getTitleIcon(),
                              color: Colors.white,
                              size: 30, // Smaller icon
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _getTitleText(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20, // Smaller title
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Compact content
                    Padding(
                      padding: const EdgeInsets.all(20), // Reduced padding
                      child: Column(
                        children: [
                          const Text(
                            'A new version is required to continue. Please update to access all features.',
                            style: TextStyle(
                              fontSize: 14, // Smaller text
                              color: Colors.black87,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          // Compact warning message
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  color: Colors.red.shade600,
                                  size: 18, // Smaller icon
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This update is required to continue using the app.',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12, // Smaller text
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Compact action button
                          SizedBox(
                            width: double.infinity,
                            height: 44, // Smaller button height
                            child: ElevatedButton(
                              onPressed: () => _launchStore(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getButtonColor(),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22), // Rounded button
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_getStoreIcon(), size: 18), // Smaller icon
                                  const SizedBox(width: 8),
                                  Text(
                                    _getButtonText(),
                                    style: const TextStyle(
                                      fontSize: 14, // Smaller text
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Optional "Later" button for non-force updates
                          if (!forceUpdate && onLater != null) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onLater!();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey.shade600,
                                ),
                                child: const Text(
                                  'Maybe Later',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTitleIcon() {
    if (isVersionConflict) return Icons.error_rounded;
    if (forceUpdate) return Icons.system_update_rounded;
    return Icons.update_rounded;
  }

  Color _getHeaderColor() {
    if (isVersionConflict) return Colors.red;
    if (forceUpdate) {
      return const Color(0xFF7E5EFD);
    }
    return const Color(0xFF7E5EFD);
  }

  String _getTitleText() {
    if (isVersionConflict) return 'Version Conflict';
    if (forceUpdate) return 'Update Required';
    return 'Update Available';
  }

  Color _getButtonColor() {
    if (isVersionConflict) return Colors.red;
    return const Color(0xFF7E5EFD);
  }

  String _getButtonText() {
    if (isVersionConflict) return 'Contact Support';
    return 'Update Now';
  }

  IconData _getStoreIcon() {
    if (kIsWeb) return Icons.download_rounded;
    if (Platform.isAndroid) return Icons.shop_rounded;
    if (Platform.isIOS) return Icons.store_rounded;
    return Icons.download_rounded;
  }

  Future<void> _launchStore(BuildContext context) async {
    try {
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar(context, 'Could not open store. Please update manually.');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Error opening store: $e');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
