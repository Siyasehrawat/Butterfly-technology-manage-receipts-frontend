import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class ExportHelper {
  static Future<void> exportToExcel({
    required BuildContext context,
    required String userId,
    required List<Map<String, dynamic>> filteredReceipts,
    required Map<String, dynamic> filters,
    required Function(bool) setExporting,
  }) async {
    if (filteredReceipts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No receipts to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
        if (filteredReceipts.isNotEmpty) {
          final dates = filteredReceipts
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
      };

      debugPrint('Exporting with data: $exportData');

      final response = await http.post(
        Uri.parse('https://manage-receipt-backend-bnl1.onrender.com/api/receipts/export'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(exportData),
      );

      debugPrint('Export response status: ${response.statusCode}');
      debugPrint('Export response headers: ${response.headers}');

      if (response.statusCode == 200) {
        // The response body contains the binary Excel data
        final Uint8List excelBytes = response.bodyBytes;
        debugPrint('Excel file size: ${excelBytes.length} bytes');

        // Save the file
        await _saveExcelFile(context, excelBytes, fromDate, toDate);
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

  static Future<void> _saveExcelFile(
      BuildContext context,
      Uint8List bytes,
      String fromDate,
      String toDate,
      ) async {
    try {
      // Generate filename with timestamp to avoid conflicts
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'receipts_${fromDate}_to_${toDate}_$timestamp.xlsx';

      if (Platform.isAndroid) {
        // Request storage permission for Android
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final manageStatus = await Permission.manageExternalStorage.request();
          if (!manageStatus.isGranted) {
            throw Exception('Storage permission denied');
          }
        }

        // Use public Downloads directory
        Directory? directory;
        try {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        } catch (e) {
          directory = await getExternalStorageDirectory();
        }

        if (directory == null) {
          throw Exception('Could not find a valid directory to save the file.');
        }
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);

        debugPrint('File saved to: ${file.path}');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel file saved: $filename'),
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
        // For iOS, save to app documents and share immediately
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);

        debugPrint('File saved to: ${file.path}');

        // Share the file on iOS
        await _shareFile(file.path);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Excel file ready to share'),
              backgroundColor: Color(0xFF7E5EFD),
            ),
          );
        }
      } else {
        // For other platforms, save to documents
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);

        debugPrint('File saved to: ${file.path}');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel file saved: $filename'),
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