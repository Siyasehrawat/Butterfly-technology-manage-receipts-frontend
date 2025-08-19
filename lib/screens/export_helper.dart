import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
      bool showProgress = filteredReceipts.length > 100;

      if (showProgress && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Preparing export for large dataset...'),
              ],
            ),
            backgroundColor: Color(0xFF7E5EFD),
            duration: Duration(seconds: 3),
          ),
        );
      }

      String fromDate = '';
      String toDate = '';

      if (filters['fromDate'] != null && filters['toDate'] != null) {
        fromDate = filters['fromDate'];
        toDate = filters['toDate'];
      } else {
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
        'chunkSize': filteredReceipts.length > 500 ? 500 : null, // Chunk large requests
        'totalReceipts': filteredReceipts.length,
      };

      debugPrint('Exporting with data: $exportData');

      final response = await http.post(
        Uri.parse('${dotenv.env['API_BASE_URL']}/api/receipts/export'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(exportData),
      ).timeout(
        Duration(minutes: filteredReceipts.length > 1000 ? 5 : 1), // Longer timeout for large datasets
        onTimeout: () {
          throw Exception('Export request timed out. Please try with a smaller date range or contact support.');
        },
      );

      debugPrint('Export response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Uint8List excelBytes = response.bodyBytes;
        debugPrint('Excel file size: ${excelBytes.length} bytes');

        await _saveAndShareExcelFile(context, excelBytes, fromDate, toDate);
      } else if (response.statusCode == 413) {
        throw Exception('Dataset too large for export. Please try with a smaller date range or fewer receipts.');
      } else if (response.statusCode == 504 || response.statusCode == 502) {
        throw Exception('Export request timed out. Please try with a smaller date range.');
      } else {
        throw Exception('Export failed with status: ${response.statusCode}\nResponse: ${response.body}');
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (context.mounted) {
        String errorMessage = 'Export failed: ${e.toString()}';

        if (e.toString().contains('timed out') || e.toString().contains('timeout')) {
          errorMessage = 'Export timed out. Please try with a smaller date range or fewer receipts.';
        } else if (e.toString().contains('too large')) {
          errorMessage = 'Too many receipts to export at once. Please try with a smaller date range.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                exportToExcel(
                  context: context,
                  userId: userId,
                  filteredReceipts: filteredReceipts,
                  filters: filters,
                  setExporting: setExporting,
                );
              },
            ),
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

  static Future<void> _saveAndShareExcelFile(
      BuildContext context,
      Uint8List bytes,
      String fromDate,
      String toDate,
      ) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'receipts_${fromDate}_to_${toDate}_$timestamp.xlsx';

      Directory directory;

      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();

        final downloadsDir = Directory('${directory.path}/Downloads');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        directory = downloadsDir;
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes);

      debugPrint('File saved to: ${file.path}');

      await _shareFile(file.path, filename);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Excel file exported successfully!'),
                Text(
                  'File: $filename',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const Text(
                  'The file has been shared. You can save it to your preferred location.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF7E5EFD),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Share Again',
              textColor: Colors.white,
              onPressed: () => _shareFile(file.path, filename),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Save and share file error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export file: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  static Future<void> _shareFile(String filePath, String filename) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Receipt Export - $filename',
        subject: 'Exported Receipts',
      );
    } catch (e) {
      debugPrint('Share file error: $e');
    }
  }
}
