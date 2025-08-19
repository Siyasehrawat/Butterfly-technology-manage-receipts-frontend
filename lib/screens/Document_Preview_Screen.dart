import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'pdf_viewer_screen.dart'; // <CHANGE> Added import for PDF viewer

class DocumentPreviewScreen extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final String fileType; // e.g., "image/png", "application/pdf"

  const DocumentPreviewScreen({
    super.key,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  bool _isDownloading = false;
  String? _downloadMessage;

  bool get _isImage => widget.fileType.startsWith('image/');
  bool get _isPdf => widget.fileType == 'application/pdf';

  @override
  void initState() {
    super.initState();
    // <CHANGE> Auto-navigate to PDF viewer if it's a PDF file
    if (_isPdf) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              pdfUrl: widget.fileUrl,
            ),
          ),
        );
      });
    }
  }

  Future<void> _downloadFile() async {
    setState(() {
      _isDownloading = true;
      _downloadMessage = 'Downloading...';
    });

    try {
      final response = await http.get(Uri.parse(widget.fileUrl));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/${widget.fileName}';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          _downloadMessage = 'Downloaded to ${file.path}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document downloaded to ${file.path}')),
        );
      } else {
        setState(() {
          _downloadMessage = 'Failed to download: ${response.statusCode}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download document: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        _downloadMessage = 'Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading document: $e')),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _shareFile() async {
    setState(() {
      _downloadMessage = 'Preparing to share...';
    });
    try {
      final response = await http.get(Uri.parse(widget.fileUrl));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/${widget.fileName}';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles([XFile(file.path)], text: 'Check out this document from Doc Wallet!');
        setState(() {
          _downloadMessage = null; // Clear message after sharing
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to prepare document for sharing: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing document: $e')),
      );
    } finally {
      setState(() {
        _downloadMessage = null;
      });
    }
  }

  Future<void> _openExternal() async {
    final uri = Uri.parse(widget.fileUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${widget.fileName}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // <CHANGE> Don't show this screen for PDFs since they auto-navigate
    if (_isPdf) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.fileName),
        actions: [
          if (_isDownloading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _isDownloading ? null : _downloadFile,
            tooltip: 'Download',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _isDownloading ? null : _shareFile,
            tooltip: 'Share',
          ),
        ],
      ),
      body: Center(
        child: _isImage
            ? InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            widget.fileUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image,
                      size: 100,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_drive_file, // <CHANGE> Removed PDF-specific icon since PDFs are handled separately
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Cannot preview this file type (${widget.fileType}).',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Externally'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
