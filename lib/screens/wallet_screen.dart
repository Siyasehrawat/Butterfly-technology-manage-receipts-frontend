import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service_bypass.dart'; // Assuming ApiService is available
import '../services/document_scan_service.dart';
import '../widgets/document_details_dialog.dart'; // Import the new dialog widget
import 'Document_Preview_Screen.dart';
import 'pdf_viewer_screen.dart'; // <CHANGE> Added import for PDF viewer
import 'full_image_view_screen.dart'; // Import the new preview screen

class MyWalletScreen extends StatefulWidget {
  final String userId;
  final String token;

  const MyWalletScreen({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<MyWalletScreen> createState() => _MyWalletScreenState();
}

class _MyWalletScreenState extends State<MyWalletScreen> {
  List<dynamic> _documents = [];
  List<dynamic> _filteredDocuments = [];
  bool _isLoading = true;
  bool _isUploading = false; // To indicate Cloudinary upload in progress
  String? _uploadStatus;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Cloudinary upload URL
  static const String _cloudinaryUploadUrl = 'https://api.cloudinary.com/v1_1/ds1lqhvc3/raw/upload';
  static const String _cloudinaryUploadPreset = 'doc_wallet_uploads';

  // Temporary storage for Cloudinary URL while user fills details
  String? _tempCloudinaryFileUrl;
  PlatformFile? _tempPickedFile; // To keep track of the picked file across async operations

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterDocuments();
    });
  }

  void _filterDocuments() {
    if (_searchQuery.isEmpty) {
      _filteredDocuments = _documents;
    } else {
      _filteredDocuments = _documents.where((doc) {
        final name = doc['title']?.toLowerCase() ?? ''; // Use 'title' from backend
        final type = doc['documentType']?.toLowerCase() ?? ''; // Use 'documentType' from backend
        final tags = (doc['tags'] as List?)?.join(', ').toLowerCase() ?? '';
        final comments = doc['comments']?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) ||
            type.contains(query) ||
            tags.contains(query) ||
            comments.contains(query);
      }).toList();
    }
  }

  Future<void> _fetchDocuments() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await ApiService.get(
        '/doc-wallet/documents',
        queryParameters: {'userId': widget.userId},
        token: widget.token,
      );

      debugPrint('Fetch Documents API Response Status: ${response.statusCode}');
      debugPrint('Fetch Documents API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // Access the 'documents' array nested under 'data'
        final List<dynamic> fetchedDocuments = responseData['data']['documents'] ?? [];
        setState(() {
          _documents = fetchedDocuments;
          _filterDocuments();
        });
        debugPrint('Documents fetched successfully. Count: ${_documents.length}');
        debugPrint('Fetched Documents: $_documents'); // Added debug print for documents
      } else {
        String errorMessage = 'Failed to load Documents.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Failed to load Documents: Server returned non-JSON response.';
          debugPrint('Error decoding JSON for fetch documents: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching documents: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Cloudinary Upload Logic ---
  Future<String?> _uploadFileToCloudinary(PlatformFile file) async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Uploading ${file.name}...';
    });
    try {
      final http.MultipartFile multipartFile = http.MultipartFile.fromBytes(
        'file', // Cloudinary expects 'file' as the key for the file
        file.bytes!,
        filename: file.name,
      );

      final Map<String, String> fields = {
        'upload_preset': _cloudinaryUploadPreset,
      };

      var request = http.MultipartRequest('POST', Uri.parse(_cloudinaryUploadUrl));
      request.files.add(multipartFile);
      request.fields.addAll(fields);

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      debugPrint('Cloudinary Upload Response Status: ${response.statusCode}');
      debugPrint('Cloudinary Upload Response Body: $responseBody');

      if (response.statusCode == 200) {
        final cloudinaryData = json.decode(responseBody);
        final String fileUrl = cloudinaryData['secure_url'] ?? cloudinaryData['url'];
        setState(() {
          _uploadStatus = 'Upload complete!';
        });
        return fileUrl;
      } else {
        String errorMessage = 'Failed to upload file to Cloudinary.';
        try {
          final errorData = json.decode(responseBody);
          errorMessage = errorData['error']['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Failed to upload file: Cloudinary returned non-JSON response.';
          debugPrint('Error decoding JSON for Cloudinary upload: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // --- File Picking and Dialog ---
  Future<void> _pickFileAndInitiateUpload({required String sourceType}) async {
    PlatformFile? file;
    if (sourceType == 'files') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'txt'],
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        file = result.files.first;
      }
    } else if (sourceType == 'photos') {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        file = PlatformFile(
          name: pickedFile.name,
          bytes: bytes,
          size: bytes.length,
          path: pickedFile.path,
        );
      }
    } else if (sourceType == 'take_photo') {
      final pickedFile = await DocumentScanService.captureCroppedDocumentImage();
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        file = PlatformFile(
          name: pickedFile.name,
          bytes: bytes,
          size: bytes.length,
          path: pickedFile.path,
        );
      }
    }

    if (file != null) {
      setState(() {
        _tempPickedFile = file; // Store the file temporarily
        _tempCloudinaryFileUrl = null; // Clear previous URL
      });

      // Await Cloudinary upload before showing the dialog
      _tempCloudinaryFileUrl = await _uploadFileToCloudinary(file);

      // Show details dialog only after Cloudinary upload attempt
      await _showDocumentDetailsDialog(file: file);
    }
  }

  Future<void> _showDocumentDetailsDialog({PlatformFile? file, Map<String, dynamic>? existingDoc}) async {
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevents dialog from closing if user taps outside
      builder: (context) => DocumentDetailsDialog(
        initialDocName: existingDoc?['title'], // Use 'title' from backend
        initialDocType: existingDoc?['documentType'], // Use 'documentType' from backend
        initialDocTags: (existingDoc?['tags'] as List?)?.map((e) => e.toString()).toList(), // Ensure tags are List<String>
        initialDocComments: existingDoc?['comments'],
        isExistingDoc: existingDoc != null,
        tempCloudinaryFileUrl: _tempCloudinaryFileUrl,
        onSave: (name, type, tags, comments) async {
          if (_tempPickedFile != null && _tempCloudinaryFileUrl != null) {
            await _saveDocumentMetadataToBackend(
              _tempPickedFile!,
              _tempCloudinaryFileUrl!,
              name,
              type,
              tags,
              comments,
            );
          }
          _tempPickedFile = null;
          _tempCloudinaryFileUrl = null;
        },
        onUpdate: (docId, name, type, tags, comments) async {
          await _updateDocumentBackend(
            docId,
            name,
            type,
            tags,
            comments,
          );
        },
        existingDocId: existingDoc?['id']?.toString(),
      ),
    );
  }

  // New function to save document metadata to your backend
  Future<void> _saveDocumentMetadataToBackend(
      PlatformFile file,
      String cloudinaryUrl,
      String name,
      String type,
      List<String> tags, // Changed to List<String>
      String comments,
      ) async {
    setState(() {
      _isLoading = true; // Use general loading for backend save
    });
    try {
      // Determine if the file is a photo based on its extension
      bool isPhoto = ['jpg', 'jpeg', 'png'].contains(file.extension?.toLowerCase());

      final response = await ApiService.post(
        '/doc-wallet/upload', // Updated endpoint
        body: {
          'userId': widget.userId,
          'fileUrl': cloudinaryUrl, // Updated field name
          'title': name,
          'documentType': type, // Changed from 'type' to 'documentType'
          'tags': tags, // Pass the List<String> directly, ApiService will handle JSON encoding
          'comments': comments,
          'isPhoto': isPhoto, // Include isPhoto flag
        },
        token: widget.token,
      );

      debugPrint('Backend Save Document API Response Status: ${response.statusCode}');
      debugPrint('Backend Save Document API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchDocuments(); // Refresh the list first
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document saved successfully!'),
              backgroundColor: Color(0xFF7E5EFD),
            ),
          );
        }
      } else {
        String errorMessage = 'Failed to save Document metadata to backend.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Failed to save Document metadata: Server returned non-JSON response.';
          debugPrint('Error decoding JSON for backend save: $e');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving document metadata to backend: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving Document: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Reset general loading
        });
      }
    }
  }

  Future<void> _updateDocumentBackend(
      String docId,
      String name,
      String type,
      List<String> tags, // Changed to List<String>
      String comments,
      ) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await ApiService.put(
        '/doc-wallet/documents/$docId',
        body: {
          'userId': widget.userId,
          'title': name,
          'documentType': type, // Changed from 'document type' to 'documentType'
          'tags': tags, // <CHANGE> Now including tags in the payload
          'comments': comments,
        },
        token: widget.token,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document updated successfully!'),
              backgroundColor: Color(0xFF7E5EFD),
            ),
          );
        }
        _fetchDocuments(); // Refresh the list
      } else {
        String errorMessage = 'Failed to update Document.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Failed to update Document: Server returned non-JSON response.';
          debugPrint('Error decoding JSON for update document: $e');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating Document: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteDocument(String docId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        final response = await ApiService.delete(
          '/doc-wallet/documents/$docId',
          token: widget.token,
          queryParameters: {'userId': widget.userId}, // Pass userId as query param for DELETE
        );

        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Document deleted successfully!'),
                backgroundColor: Color(0xFF7E5EFD),
              ),
            );
          }
          _fetchDocuments(); // Refresh the list
        } else {
          String errorMessage = 'Failed to delete Document.';
          try {
            final errorData = json.decode(response.body);
            errorMessage = errorData['message'] ?? errorMessage;
          } catch (e) {
            errorMessage = 'Failed to delete Document: Server returned non-JSON response.';
            debugPrint('Error decoding JSON for delete document: $e');
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting Document: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // <CHANGE> Added method to handle document preview navigation
  void _navigateToPreview(String fileUrl, String fileName, String mimeType) {
    if (mimeType == 'application/pdf') {
      // Navigate to PDF viewer for PDF files
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            pdfUrl: fileUrl,
          ),
        ),
      );
    } else {
      // Navigate to general document preview for other files
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentPreviewScreen(
            fileUrl: fileUrl,
            fileName: fileName,
            fileType: mimeType,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E5EFD),
        foregroundColor: Colors.white,
        title: const Text('Doc Wallet'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'MR',
                style: TextStyle(
                  color: Color(0xFF7E5EFD),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading && !_isUploading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
            ),
          )
              : Column(
            children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search documents...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 16),
                Row( // Use a Row for "Your Documents" and the new "+" button
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Documents',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton( // Replaced FloatingActionButton with IconButton
                      icon: const Icon(Icons.add_circle, size: 36, color: Color(0xFF7E5EFD)),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (BuildContext context) {
                            return SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  ListTile(
                                    leading: const Text('📷', style: TextStyle(fontSize: 22)),
                                    title: const Text('Take photo'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickFileAndInitiateUpload(sourceType: 'take_photo');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Text('📤', style: TextStyle(fontSize: 22)),
                                    title: const Text('Choose from photos'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickFileAndInitiateUpload(sourceType: 'photos');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Text('📤', style: TextStyle(fontSize: 22)),
                                    title: const Text('Upload from files'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickFileAndInitiateUpload(sourceType: 'files');
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredDocuments.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty ? 'No documents uploaded yet' : 'No documents found for "$_searchQuery"',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _filteredDocuments.length,
              itemBuilder: (context, index) {
                final doc = _filteredDocuments[index];
                final name = doc['title'] ?? 'Untitled Document'; // Mapped from 'title'
                final type = doc['documentType'] ?? 'Unknown'; // For display under title
                final mimeType = doc['fileType'] ?? 'application/octet-stream'; // For preview functionality
                final fileUrl = doc['filePath'] ?? ''; // Mapped from 'filePath'
                final docId = doc['id']?.toString();
                final fileName = doc['fileName'] ?? 'document'; // Use fileName from backend

                return GestureDetector(
                  onTap: () {
                    // <CHANGE> Use the new navigation method for proper PDF handling
                    _navigateToPreview(fileUrl, fileName, mimeType);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7E5EFD),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.description,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  type,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Color(0xFF7E5EFD)),
                                onPressed: () => _showDocumentDetailsDialog(existingDoc: doc),
                                iconSize: 20, // Smaller icon size
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteDocument(docId!),
                                iconSize: 20, // Smaller icon size
                              ),
                              IconButton(
                                icon: const Icon(Icons.visibility, color: Color(0xFF7E5EFD)),
                                onPressed: () {
                                  // <CHANGE> Use the new navigation method for proper PDF handling
                                  _navigateToPreview(fileUrl, fileName, mimeType);
                                },
                                iconSize: 20, // Smaller icon size
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
            ],
          ),

          if (_isUploading) ...[
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Uploading document',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
