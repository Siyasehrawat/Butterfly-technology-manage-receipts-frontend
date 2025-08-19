import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum ExportFormat { excel, pdf }

class ExportService {
  static Future<void> showExportDialog({
    required BuildContext context,
    required String userId,
    required List<Map<String, dynamic>> receiptsToExport,
    required Map<String, dynamic> filters,
    required bool selectedOnly,
    required Set<String> selectedIds,
    required Function(bool) setExporting,
  }) async {
    if (receiptsToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(selectedOnly ? 'No receipts selected for export' : 'No receipts to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show format selection dialog
    final format = await showDialog<ExportFormat>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Choose Export Format',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF7E5EFD),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selectedOnly
                    ? 'Export ${receiptsToExport.length} selected receipts'
                    : 'Export ${receiptsToExport.length} receipts',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Color(0xFF7E5EFD)),
                title: const Text('Excel (.xlsx)'),
                subtitle: const Text('Spreadsheet format with data analysis'),
                onTap: () => Navigator.pop(context, ExportFormat.excel),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('PDF (.pdf)'),
                subtitle: const Text('Formatted document for printing'),
                onTap: () => Navigator.pop(context, ExportFormat.pdf),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (format != null) {
      await _exportReceipts(
        context: context,
        userId: userId,
        receiptsToExport: receiptsToExport,
        filters: filters,
        selectedOnly: selectedOnly,
        selectedIds: selectedIds,
        format: format,
        setExporting: setExporting,
      );
    }
  }

  static Future<void> _exportReceipts({
    required BuildContext context,
    required String userId,
    required List<Map<String, dynamic>> receiptsToExport,
    required Map<String, dynamic> filters,
    required bool selectedOnly,
    required Set<String> selectedIds,
    required ExportFormat format,
    required Function(bool) setExporting,
  }) async {
    setExporting(true);

    try {
      // Determine date range for export
      String fromDate = '';
      String toDate = '';

      if (filters['fromDate'] != null && filters['toDate'] != null) {
        fromDate = filters['fromDate'];
        toDate = filters['toDate'];
      } else {
        // If no specific date range, use the range of filtered receipts
        if (receiptsToExport.isNotEmpty) {
          final dates = receiptsToExport
              .map((r) => _parseDate(r['receiptDate']))
              .where((d) => d != null)
              .cast<DateTime>()
              .toList();

          if (dates.isNotEmpty) {
            dates.sort();
            fromDate = dates.first.toIso8601String().split('T')[0];
            toDate = dates.last.toIso8601String().split('T')[0];
          } else {
            // Fallback to current month
            final now = DateTime.now();
            fromDate = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];
            toDate = DateTime(now.year, now.month + 1, 0).toIso8601String().split('T')[0];
          }
        }
      }

      final exportData = {
        'userId': userId,
        'fromDate': fromDate,
        'toDate': toDate,
        'selectedOnly': selectedOnly,
        'selectedIds': selectedOnly ? selectedIds.toList() : null,
        'format': format == ExportFormat.excel ? 'excel' : 'pdf',
      };

      debugPrint('Exporting with data: $exportData');

      final response = await http.post(
        Uri.parse('${dotenv.env['API_BASE_URL']}/api/receipts/export'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(exportData),
      );

      debugPrint('Export response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Uint8List fileBytes = response.bodyBytes;
        debugPrint('${format == ExportFormat.excel ? 'Excel' : 'PDF'} file size: ${fileBytes.length} bytes');

        await _saveFile(context, fileBytes, fromDate, toDate, selectedOnly, format);
      } else {
        throw Exception('Export failed with status: ${response.statusCode}\nResponse: ${response.body}');
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setExporting(false);
    }
  }

  static DateTime? _parseDate(dynamic dateString) {
    if (dateString == null) return null;
    try {
      return DateTime.parse(dateString.toString());
    } catch (e) {
      try {
        final DateFormat formatter = DateFormat('MM-dd-yyyy');
        return formatter.parse(dateString.toString());
      } catch (e) {
        debugPrint('Error parsing date: $e');
        return null;
      }
    }
  }

  static Future<void> _saveFile(
      BuildContext context,
      Uint8List bytes,
      String fromDate,
      String toDate,
      bool selectedOnly,
      ExportFormat format,
      ) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final prefix = selectedOnly ? 'selected_receipts' : 'receipts';
      final extension = format == ExportFormat.excel ? 'xlsx' : 'pdf';
      final filename = '${prefix}_${fromDate}_to_${toDate}_$timestamp.$extension';

      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final manageStatus = await Permission.manageExternalStorage.request();
          if (!manageStatus.isGranted) {
            throw Exception('Storage permission denied');
          }
        }

        Directory? directory;
        final possiblePaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Downloads',
          '/sdcard/Download',
          '/sdcard/Downloads',
        ];

        for (final path in possiblePaths) {
          final testDir = Directory(path);
          if (await testDir.exists()) {
            directory = testDir;
            break;
          }
        }

        directory ??= await getExternalStorageDirectory();

        if (directory == null) {
          throw Exception('Could not access storage directory');
        }

        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${format == ExportFormat.excel ? 'Excel' : 'PDF'} file saved: $filename'),
              backgroundColor: const Color(0xFF7E5EFD),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Share',
                textColor: Colors.white,
                onPressed: () => _shareFile(file.path),
              ),
            ),
          );
        }
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);

        await _shareFile(file.path);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${format == ExportFormat.excel ? 'Excel' : 'PDF'} file ready to share'),
              backgroundColor: const Color(0xFF7E5EFD),
            ),
          );
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${format == ExportFormat.excel ? 'Excel' : 'PDF'} file saved: $filename'),
              backgroundColor: const Color(0xFF7E5EFD),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Save file error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  static Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Receipt Export',
        subject: 'Exported Receipts',
      );
    } catch (e) {
      debugPrint('Share file error: $e');
    }
  }
}
