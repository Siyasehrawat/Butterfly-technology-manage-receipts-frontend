import 'package:flutter/material.dart';
import '../utils/country_utils.dart';

/// Actions supported by the Upload bottom sheet
enum UploadAction {
  camera,
  gallery,
  manual,
  trackDistance,
}

/// Reusable bottom sheet for picking an upload action.
class UploadSheet {
  static Future<void> show(
    BuildContext context, {
    required void Function(UploadAction action) onAction,
    String? country,
  }) async {
    final isIndia = CountryUtils.isIndia(country);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  MediaQuery.of(ctx).padding.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Upload Receipt',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7E5EFD),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black87),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Only show Track Distance if user is not from India
                    if (!isIndia) ...[
                      _buildItem(
                        context: ctx,
                        emoji: '🚗',
                        color: Colors.red,
                        title: 'Track Distance',
                        subtitle: 'Track your distance and mileage',
                        onTap: () {
                          Navigator.pop(ctx);
                          onAction(UploadAction.trackDistance);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildItem(
                      context: ctx,
                      emoji: '📷',
                      color: const Color(0xFF7E5EFD),
                      title: 'Take Receipt Photo',
                      subtitle: 'Capture a photo of your receipt',
                      onTap: () {
                        Navigator.pop(ctx);
                        onAction(UploadAction.camera);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildItem(
                      context: ctx,
                      emoji: '📤',
                      color: Colors.green,
                      title: 'Upload Receipt',
                      subtitle: 'Select from your gallery',
                      onTap: () {
                        Navigator.pop(ctx);
                        onAction(UploadAction.gallery);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildItem(
                      context: ctx,
                      emoji: '📝',
                      color: Colors.orange,
                      title: 'Add Manual Receipt',
                      subtitle: 'Enter receipt details manually',
                      onTap: () {
                        Navigator.pop(ctx);
                        onAction(UploadAction.manual);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildItem({
    required BuildContext context,
    required String emoji,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF1F5FF),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}




