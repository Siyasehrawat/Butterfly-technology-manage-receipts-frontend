import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'share_intent_service.dart';
import '../models/receipt_models.dart';

class ShareIntentHandler {
  static const MethodChannel _channel = MethodChannel('share_intent');
  static final ValueNotifier<_ProgressState> _progressState =
      ValueNotifier<_ProgressState>(
    const _ProgressState(message: 'Processing receipt...', step: 1, total: 4),
  );
  static bool _dialogVisible = false;

  /// Handle share intent from other apps
  static Future<void> handleShareIntent({
    Function(ShareIntentResult result)? onComplete,
    Function(ShareIntentStatus status, String? message)? onProgress,
  }) async {
    try {
      final String? filePath = await _channel.invokeMethod('getSharedFile');

      if (filePath != null) {
        final File file = File(filePath);

        if (await file.exists()) {
          await _processSharedFile(
            file,
            onComplete: onComplete,
            onProgress: onProgress,
          );
        } else {
          onComplete?.call(ShareIntentResult.error('Shared file not found'));
        }
      } else {
        onComplete?.call(ShareIntentResult.error('No shared file received'));
      }
    } catch (e) {
      print('Share intent error: $e');
      onComplete?.call(ShareIntentResult.error('Share intent failed: $e'));
    }
  }

  /// Process shared file
  static Future<void> _processSharedFile(
      File file, {
        Function(ShareIntentResult result)? onComplete,
        Function(ShareIntentStatus status, String? message)? onProgress,
      }) async {
    try {
      // Handle the complete flow
      final result = await ShareIntentService.handleSharedFile(
        file,
        onProgress: onProgress,
      );

      onComplete?.call(result);
    } catch (e) {
      print('Process shared file error: $e');
      onComplete?.call(ShareIntentResult.error('Process shared file failed: $e'));
    }
  }

  /// Handle file picker for manual selection
  static Future<void> handleFilePicker({
    Function(ShareIntentResult result)? onComplete,
    Function(ShareIntentStatus status, String? message)? onProgress,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final File file = File(result.files.first.path!);
        await _processSharedFile(
          file,
          onComplete: onComplete,
          onProgress: onProgress,
        );
      } else {
        onComplete?.call(ShareIntentResult.error('No file selected'));
      }
    } catch (e) {
      print('File picker error: $e');
      onComplete?.call(ShareIntentResult.error('File picker failed: $e'));
    }
  }

  /// Show processing dialog
  static void showProcessingDialog(BuildContext context) {
    if (_dialogVisible) return;
    _dialogVisible = true;
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ValueListenableBuilder<_ProgressState>(
          valueListenable: _progressState,
          builder: (context, state, _) {
            final progress = state.step / state.total;
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Step ${state.step} of ${state.total}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Show result dialog
  static void showResultDialog(
      BuildContext context,
      ShareIntentResult result, {
        VoidCallback? onDismiss,
      }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(result.status == ShareIntentStatus.completed ? 'Success' : 'Error'),
          content: Text(result.message ?? result.error ?? 'Unknown error'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss?.call();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show processing dialog with progress
  static void showProcessingDialogWithProgress(
      BuildContext context,
      ShareIntentStatus status,
      String? message,
      ) {
    // Map statuses to dashboard-like steps
    final steps = <ShareIntentStatus, int>{
      ShareIntentStatus.uploading: 1,
      ShareIntentStatus.processing: 2,
      ShareIntentStatus.saving: 3,
      ShareIntentStatus.completed: 4,
      ShareIntentStatus.error: 4,
    };
    final mappedStep = steps[status] ?? 1;
    final displayMessage = message ?? _statusToMessage(status);
    _progressState.value = _progressState.value.copyWith(
      message: displayMessage,
      step: mappedStep,
      total: 4,
    );
    if (!_dialogVisible) {
      showProcessingDialog(context);
    }
  }

  /// Dismiss processing dialog
  static void dismissProcessingDialog(BuildContext context) {
    if (_dialogVisible) {
      Navigator.of(context).pop();
      _dialogVisible = false;
      _progressState.value = const _ProgressState(
        message: 'Processing receipt...',
        step: 1,
        total: 4,
      );
    }
  }

  /// Handle share intent with UI feedback
  static Future<void> handleShareIntentWithUI(
      BuildContext context, {
        Function(ShareIntentResult result)? onComplete,
      }) async {
    // Show processing dialog
    showProcessingDialog(context);

    await handleShareIntent(
      onComplete: (result) {
        // Dismiss processing dialog
        dismissProcessingDialog(context);

        // Show result dialog
        showResultDialog(
          context,
          result,
          onDismiss: () {
            onComplete?.call(result);
          },
        );
      },
      onProgress: (status, message) {
        showProcessingDialogWithProgress(context, status, message);
      },
    );
  }

  /// Handle file picker with UI feedback
  static Future<void> handleFilePickerWithUI(
      BuildContext context, {
        Function(ShareIntentResult result)? onComplete,
      }) async {
    // Show processing dialog
    showProcessingDialog(context);

    await handleFilePicker(
      onComplete: (result) {
        // Dismiss processing dialog
        dismissProcessingDialog(context);

        // Show result dialog
        showResultDialog(
          context,
          result,
          onDismiss: () {
            onComplete?.call(result);
          },
        );
      },
      onProgress: (status, message) {
        showProcessingDialogWithProgress(context, status, message);
      },
    );
  }
}

class _ProgressState {
  final String message;
  final int step;
  final int total;
  const _ProgressState({required this.message, required this.step, required this.total});

  _ProgressState copyWith({String? message, int? step, int? total}) {
    return _ProgressState(
      message: message ?? this.message,
      step: step ?? this.step,
      total: total ?? this.total,
    );
  }
}

String _statusToMessage(ShareIntentStatus status) {
  switch (status) {
    case ShareIntentStatus.idle:
      return 'Ready';
    case ShareIntentStatus.uploading:
      return 'Uploading receipt...';
    case ShareIntentStatus.processing:
      return 'Scanning for data...';
    case ShareIntentStatus.saving:
      return 'Filling in missing pieces...';
    case ShareIntentStatus.completed:
      return 'Processing complete!';
    case ShareIntentStatus.error:
      return 'An error occurred';
  }
}