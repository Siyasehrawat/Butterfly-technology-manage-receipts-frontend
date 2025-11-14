import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/share_intent_service.dart';
import '../models/receipt_models.dart';

/// Receipt Upload Screen demonstrating proper line items implementation
/// 
/// This screen shows how to:
/// 1. Handle file selection (camera, gallery, file picker)
/// 2. Upload files with progress tracking
/// 3. Process receipts with OCR (preserving _lineItemsPromise)
/// 4. Save receipts with line items for background processing
class ReceiptUploadScreen extends StatefulWidget {
  const ReceiptUploadScreen({Key? key}) : super(key: key);

  @override
  _ReceiptUploadScreenState createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> {
  bool _isUploading = false;
  String? _uploadStatus;
  ShareIntentStatus _currentStatus = ShareIntentStatus.idle;
  String? _receiptId;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Upload'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upload Status Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getStatusIcon(),
                          color: _getStatusColor(),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Upload Status',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_uploadStatus != null)
                      Text(
                        _uploadStatus!,
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontSize: 16,
                        ),
                      ),
                    if (_receiptId != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Receipt ID: $_receiptId',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Error: $_errorMessage',
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Upload Buttons
            if (!_isUploading) ...[
              ElevatedButton.icon(
                onPressed: _pickImageFromGallery,
                icon: const Text('📤', style: TextStyle(fontSize: 20)),
                label: const Text('Select from Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              
              const SizedBox(height: 12),
              
              ElevatedButton.icon(
                onPressed: _pickImageFromCamera,
                icon: const Text('📷', style: TextStyle(fontSize: 20)),
                label: const Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              
              const SizedBox(height: 12),
              
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Text('📤', style: TextStyle(fontSize: 20)),
                label: const Text('Select File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ] else ...[
              // Upload Progress
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing receipt...'),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Line Items Information
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Line Items Processing',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Line items are processed in the background\n'
                      '• The _lineItemsPromise is preserved from OCR to save\n'
                      '• Background processing continues even after timeout\n'
                      '• Check logs for "Background update complete" message',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Debug Information
            if (_isUploading || _receiptId != null)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.bug_report,
                              color: Colors.orange[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Debug Information',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Check console logs for:\n'
                          '• 🔍 OCR Request/Response\n'
                          '• 🔍 Line items status and promise\n'
                          '• ✅/⚠️ _lineItemsPromise inclusion\n'
                          '• 📤 Save payload details\n'
                          '• 📥 Save response',
                          style: TextStyle(fontSize: 12),
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

  Future<void> _pickImageFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        await _handleDirectUpload(file);
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    // Note: You would implement camera functionality here
    // For now, we'll use file picker as a fallback
    _showError('Camera functionality not implemented. Use file picker instead.');
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        await _handleDirectUpload(file);
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _handleDirectUpload(File file) async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Starting upload...';
      _currentStatus = ShareIntentStatus.uploading;
      _errorMessage = null;
      _receiptId = null;
    });

    try {
      final result = await ShareIntentService.handleSharedFile(
        file,
        onProgress: (status, message) {
          setState(() {
            _currentStatus = status;
            _uploadStatus = message;
          });
        },
      );

      if (result.status == ShareIntentStatus.completed && result.receiptId != null) {
        setState(() {
          _uploadStatus = 'Receipt saved successfully!';
          _receiptId = result.receiptId;
          _currentStatus = ShareIntentStatus.completed;
        });
        _showSuccess('Receipt saved with ID: ${result.receiptId}');
      } else {
        throw Exception(result.error ?? result.message ?? 'Unknown error');
      }
    } catch (e) {
      setState(() {
        _uploadStatus = 'Upload failed: $e';
        _errorMessage = e.toString();
        _currentStatus = ShareIntentStatus.error;
      });

      _showError('Upload failed: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  IconData _getStatusIcon() {
    switch (_currentStatus) {
      case ShareIntentStatus.idle:
        return Icons.upload_file;
      case ShareIntentStatus.uploading:
        return Icons.cloud_upload;
      case ShareIntentStatus.processing:
        return Icons.auto_fix_high;
      case ShareIntentStatus.saving:
        return Icons.save;
      case ShareIntentStatus.completed:
        return Icons.check_circle;
      case ShareIntentStatus.error:
        return Icons.error;
    }
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case ShareIntentStatus.idle:
        return Colors.grey;
      case ShareIntentStatus.uploading:
      case ShareIntentStatus.processing:
      case ShareIntentStatus.saving:
        return Colors.blue;
      case ShareIntentStatus.completed:
        return Colors.green;
      case ShareIntentStatus.error:
        return Colors.red;
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}


