import 'package:flutter/material.dart';

/// Actions supported by the Upload bottom sheet
enum UploadAction {
  camera,
  gallery,
  manual,
}

/// Reusable bottom sheet for picking an upload action.
class UploadSheet {
  static Future<void> show(
    BuildContext context, {
    required void Function(UploadAction action) onAction,
  }) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7E5EFD),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 12),
                _buildItem(
                  context: ctx,
                  emoji: '📤',
                  color: const Color(0xFF7E5EFD),
                  title: 'Upload Receipt',
                  subtitle: 'Select from your gallery',
                  onTap: () {
                    Navigator.pop(ctx);
                    onAction(UploadAction.gallery);
                  },
                ),
                const SizedBox(height: 12),
                _buildItem(
                  context: ctx,
                  emoji: '📝',
                  color: const Color(0xFF7E5EFD),
                  title: 'Add Manual Receipt',
                  subtitle: 'Enter receipt details manually',
                  onTap: () {
                    Navigator.pop(ctx);
                    onAction(UploadAction.manual);
                  },
                ),
                const SizedBox(height: 8),
              ],
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
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}




