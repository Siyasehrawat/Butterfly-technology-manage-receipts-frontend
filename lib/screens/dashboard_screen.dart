import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/receipt_provider.dart';
import '../providers/user_provider.dart';
import '../providers/setting_provider.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_logo.dart';
import 'receipt_details_screen.dart';
import 'welcome_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userId;
  final String token;

  const DashboardScreen({
    Key? key,
    required this.userId,
    this.token = '',
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<dynamic> savedReceipts = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String _userName = 'User';
  bool _isLoadingUserName = true;
  DateTime? _lastBackPressTime;

  // Upload progress indicators
  String _uploadStatus = 'Uploading receipt...';
  int _currentStep = 0;
  final List<String> _uploadSteps = [
    'Uploading receipt...',
    'Scanning for data...',
    'Filling in missing pieces...',
    'Processing complete!'
  ];
  Timer? _progressTimer;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final receiptProvider = Provider.of<ReceiptProvider>(
        context,
        listen: false,
      );
      receiptProvider.setUserId(widget.userId);
      _initializeScreen();
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  // New method to initialize screen data
  Future<void> _initializeScreen() async {
    await _fetchUserName();
    await _fetchSavedReceipts();
    setState(() {
      _isLoadingUserName = false;
    });
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _fetchUserName() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://manage-receipt-backend-bnl1.onrender.com/api/users/profile'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final user = (data['users'] as List<dynamic>).firstWhere(
              (user) => user['id'] == widget.userId,
          orElse: () => null,
        );

        if (user != null) {
          setState(() {
            _userName = user['name'] ?? 'User';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
    }
  }

  Future<void> _fetchSavedReceipts() async {
    setState(() => _isLoading = true);

    try {
      // Fetch all receipts first, not just limited to 5
      final url = "https://manage-receipt-backend-bnl1.onrender.com/api/receipts/${widget.userId}";

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      debugPrint('Dashboard - Fetch receipts response: ${response.statusCode}');
      debugPrint('Dashboard - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> receipts = data is List ? data : data['receipts'] ?? [];

        debugPrint('Dashboard - Total receipts from API: ${receipts.length}');

        // More lenient filtering - only exclude explicitly unsaved receipts
        receipts = receipts.where((receipt) {
          final isSaved = receipt['isSaved'];
          // Include receipt if isSaved is null, true, or not explicitly false
          final shouldInclude = isSaved == null || isSaved == true || isSaved != false;

          if (!shouldInclude) {
            debugPrint('Dashboard - Excluding receipt: ${receipt['merchant']} (isSaved: $isSaved)');
          }

          return shouldInclude;
        }).toList();

        debugPrint('Dashboard - Receipts after filtering: ${receipts.length}');

        // Sort by most recent first
        receipts.sort((a, b) {
          DateTime? dateA = _parseDate(a['updatedAt']) ??
              _parseDate(a['createdAt']) ??
              _parseDate(a['receiptDate']);
          DateTime? dateB = _parseDate(b['updatedAt']) ??
              _parseDate(b['createdAt']) ??
              _parseDate(b['receiptDate']);

          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;

          return dateB.compareTo(dateA);
        });

        // Take only the 5 most recent for dashboard display
        final recentReceipts = receipts.take(5).toList();

        debugPrint('Dashboard - Showing ${recentReceipts.length} recent receipts');
        for (var receipt in recentReceipts) {
          debugPrint('Dashboard - Receipt: ${receipt['merchant']} - ${receipt['receiptDate']} (isSaved: ${receipt['isSaved']})');
        }

        setState(() {
          savedReceipts = recentReceipts;
          _isLoading = false;
        });
      } else {
        debugPrint('Dashboard - Failed to load receipts: ${response.statusCode} - ${response.body}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Dashboard - Error fetching receipts: $e");
      setState(() => _isLoading = false);
    }
  }

  DateTime? _parseDate(dynamic dateString) {
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

  // Start upload progress animation with timeout
  void _startUploadProgress() {
    setState(() {
      _currentStep = 0;
      _uploadStatus = _uploadSteps[0];
    });

    // Start timeout timer (20 seconds)
    _timeoutTimer = Timer(const Duration(seconds: 20), () {
      if (_isUploading) {
        _handleUploadTimeout();
      }
    });

    _progressTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!_isUploading) {
        timer.cancel();
        return;
      }

      if (_currentStep < _uploadSteps.length - 1) {
        setState(() {
          _currentStep++;
          _uploadStatus = _uploadSteps[_currentStep];
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _handleUploadTimeout() {
    _progressTimer?.cancel();
    _timeoutTimer?.cancel();

    setState(() {
      _isUploading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload timed out. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // Navigate to manual receipt entry
  void _createManualReceipt() async {
    debugPrint('Dashboard - Creating manual receipt');

    // Generate a unique imageId for manual receipts
    final manualImageId = 'manual_${DateTime.now().millisecondsSinceEpoch}_${widget.userId}';

    // Create an empty receipt object for manual entry
    final emptyReceipt = {
      'merchant': '',
      'receiptDate': DateFormat('MM-dd-yyyy').format(DateTime.now()),
      'amount': '',
      'category': '',
      'imageUrl': 'https://via.placeholder.com/300x400/E8E6FF/7E5EFD?text=Manual+Receipt',
      'imageId': manualImageId,
      'isManual': true,
      'isSaved': false, // Start as unsaved
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptDetailsScreen(
          receipt: emptyReceipt,
          imageUrl: emptyReceipt['imageUrl']as String? ?? '',
          userId: widget.userId,
          imageId: manualImageId,
          isNewReceipt: true,
          isPdf: false,
          isManualReceipt: true,
        ),
      ),
    );

    debugPrint('Dashboard - Manual receipt result: $result');

    // Refresh the receipts list if receipt was saved
    if (result == true) {
      debugPrint('Dashboard - Refreshing receipts after manual creation');
      await _fetchSavedReceipts();
    }
  }

  // Show upload dialog with options for Photos and Documents
  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Upload Receipt',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF7E5EFD),
            ),
          ),
          content: const Text(
            'Choose how you want to upload your receipt:',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickAndUploadImageFromGallery();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, color: Color(0xFF7E5EFD)),
                  SizedBox(width: 8),
                  Text(
                    'Photos',
                    style: TextStyle(
                      color: Color(0xFF7E5EFD),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickAndUploadFile();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder, color: Color(0xFF7E5EFD)),
                  SizedBox(width: 8),
                  Text(
                    'Documents',
                    style: TextStyle(
                      color: Color(0xFF7E5EFD),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  // New method specifically for gallery uploads from dialog
  Future<void> _pickAndUploadImageFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _uploadImageToCloudinary(image);
    }
  }

  // Updated method for camera uploads (existing functionality)
  Future<void> _pickAndUploadImageFromCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      await _uploadImageToCloudinary(image);
    }
  }

  Future<void> _uploadImageToCloudinary(dynamic image) async {
    setState(() {
      _isUploading = true;
    });

    _startUploadProgress();

    const cloudinaryUrl =
        'https://api.cloudinary.com/v1_1/ds1lqhvc3/image/upload';
    const uploadPreset = 'receipt_uploads';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
        ..fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: image.name),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('file', image.path),
        );
      }

      var response = await request.send().timeout(const Duration(seconds: 20));
      var responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);

      if (response.statusCode == 200) {
        await _sendImageUrlToBackend(jsonResponse["secure_url"] ?? '');
      } else {
        throw Exception(
            "Cloudinary error: ${jsonResponse['error']?['message'] ?? 'Unknown error'}");
      }
    } on TimeoutException {
      _handleUploadTimeout();
    } on http.ClientException catch (e) {
      debugPrint("Upload Error: $e");
      _progressTimer?.cancel();
      _timeoutTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Network error. Please check your connection and try again.')),
      );
      setState(() {
        _isUploading = false;
      });
    } catch (e) {
      debugPrint("Upload Error: $e");
      _progressTimer?.cancel();
      _timeoutTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to upload image. Please try again.')),
      );
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _sendImageUrlToBackend(String imageUrl) async {
    const backendUrl =
        'https://manage-receipt-backend-bnl1.onrender.com/api/receipts/process-receipt';

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({'imageUrl': imageUrl, 'userId': widget.userId}),
      ).timeout(const Duration(seconds: 20));

      _progressTimer?.cancel();
      _timeoutTimer?.cancel();
      setState(() {
        _isUploading = false;
      });

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);

        if (responseBody != null && responseBody["receiptDetails"] != null) {
          final receiptDetails = responseBody["receiptDetails"];

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReceiptDetailsScreen(
                receipt: receiptDetails,
                imageUrl: receiptDetails['imageUrl'] ?? '',
                userId: widget.userId,
                imageId: receiptDetails['imageId']?.toString() ?? '',
                isNewReceipt: true,
                isPdf: receiptDetails['pdfUrl'] != null,
              ),
            ),
          );

          debugPrint('Dashboard - Image upload result: $result');

          if (result == true) {
            debugPrint('Dashboard - Refreshing receipts after image upload');
            await _fetchSavedReceipts();
          }
        } else {
          throw Exception(
              'Unexpected response structure: Missing receiptDetails');
        }
      } else {
        final error = json.decode(response.body)['error'] ?? 'Unknown error';
        throw Exception('Backend error: $error');
      }
    } on TimeoutException {
      _handleUploadTimeout();
    } catch (e) {
      debugPrint("Backend Error: $e");
      _progressTimer?.cancel();
      _timeoutTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to process receipt. Please try again.'),
        ),
      );
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _logout(BuildContext context) async {
    final authService = AuthService();
    await authService.signOut();

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
    );
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final isPdf = file.extension?.toLowerCase() == 'pdf';
      await _uploadFileToCloudinary(file, isPdf);
    }
  }

  Future<void> _uploadFileToCloudinary(PlatformFile file, bool isPdf) async {
    setState(() {
      _isUploading = true;
    });

    _startUploadProgress();

    final cloudinaryUrl = isPdf
        ? 'https://api.cloudinary.com/v1_1/ds1lqhvc3/raw/upload'
        : 'https://api.cloudinary.com/v1_1/ds1lqhvc3/image/upload';
    const uploadPreset = 'receipt_uploads';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
        ..fields['upload_preset'] = uploadPreset;

      if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('file', file.bytes!,
              filename: file.name),
        );
      } else if (file.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path!,
              filename: file.name),
        );
      } else {
        throw Exception('File data not available');
      }

      var response = await request.send().timeout(const Duration(seconds: 20));
      var responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);

      if (response.statusCode == 200) {
        final url = jsonResponse["secure_url"] ?? '';
        if (isPdf) {
          await _sendPdfUrlToBackend(url);
        } else {
          await _sendImageUrlToBackend(url);
        }
      } else {
        throw Exception(
            "Cloudinary error: ${jsonResponse['error']?['message'] ?? 'Unknown error'}");
      }
    } on TimeoutException {
      _handleUploadTimeout();
    } on http.ClientException catch (e) {
      debugPrint("Upload Error: $e");
      _progressTimer?.cancel();
      _timeoutTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Network error. Please check your connection and try again.')),
      );
      setState(() {
        _isUploading = false;
      });
    } catch (e) {
      debugPrint("Upload Error: $e");
      _progressTimer?.cancel();
      _timeoutTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to upload file. Please try again.')),
      );
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _sendPdfUrlToBackend(String pdfUrl) async {
    const backendUrl =
        'https://manage-receipt-backend-bnl1.onrender.com/api/receipts/process-receipt';

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({'pdfUrl': pdfUrl, 'userId': widget.userId}),
      ).timeout(const Duration(seconds: 20));

      _progressTimer?.cancel();
      _timeoutTimer?.cancel();
      setState(() {
        _isUploading = false;
      });

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);

        if (responseBody != null && responseBody["receiptDetails"] != null) {
          final receiptDetails = responseBody["receiptDetails"];

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReceiptDetailsScreen(
                receipt: receiptDetails,
                imageUrl: receiptDetails['imageUrl'] ?? '',
                userId: widget.userId,
                imageId: receiptDetails['imageId']?.toString() ?? '',
                isNewReceipt: true,
                isPdf: receiptDetails['pdfUrl'] != null,
              ),
            ),
          );

          debugPrint('Dashboard - PDF upload result: $result');

          if (result == true) {
            debugPrint('Dashboard - Refreshing receipts after PDF upload');
            await _fetchSavedReceipts();
          }
        } else {
          throw Exception(
              'Unexpected response structure: Missing receiptDetails');
        }
      } else {
        final error = json.decode(response.body)['error'] ?? 'Unknown error';
        throw Exception('Backend error: $error');
      }
    } on TimeoutException {
      _handleUploadTimeout();
    } catch (e) {
      debugPrint("Backend Error: $e");
      _progressTimer?.cancel();
      _timeoutTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to process PDF. Please try again.'),
        ),
      );
      setState(() {
        _isUploading = false;
      });
    }
  }

  AppDrawer _buildDrawer() {
    return AppDrawer(
      userId: widget.userId,
      token: widget.token,
      onLogout: () => _logout(context),
    );
  }

  Widget _buildReceiptsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
        ),
      );
    }

    if (savedReceipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No receipts uploaded yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first receipt above',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: savedReceipts.length,
      itemBuilder: (context, index) {
        final receipt = savedReceipts[index];
        final imageUrl = receipt['imageLink'] ?? '';
        final merchant = receipt['merchant']?.toString() ?? 'Unknown';
        final amount = receipt['amount']?.toString() ?? '0';
        String category = receipt['category']?.toString() ?? 'Uncategorized';

        String formattedDate = 'No date';
        if (receipt['receiptDate'] != null) {
          try {
            final DateTime? date = _parseDate(receipt['receiptDate']);
            if (date != null) {
              formattedDate = DateFormat('MMMM d, yyyy').format(date);
            }
          } catch (e) {
            debugPrint('Error parsing date: $e');
          }
        }

        final isPdf = imageUrl.toLowerCase().endsWith('.pdf');
        final isManual = receipt['isManual'] == true || imageUrl.contains('placeholder') || imageUrl.contains('Manual+Receipt');

        // Get currency symbol from providers
        final userProvider = Provider.of<UserProvider>(context);
        final settingsProvider = Provider.of<SettingsProvider>(context);
        final currencySymbol = userProvider.currencySymbol ?? settingsProvider.currencySymbol ?? '\$';

        return GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReceiptDetailsScreen(
                  receipt: receipt,
                  imageUrl: imageUrl,
                  userId: widget.userId,
                  imageId: receipt['imageId']?.toString() ?? '',
                  isNewReceipt: false,
                  isPdf: isPdf,
                  isManualReceipt: isManual,
                ),
              ),
            );

            debugPrint('Dashboard - Receipt details result: $result');

            // Refresh if receipt was updated or deleted
            if (result == true || result == false) {
              debugPrint('Dashboard - Refreshing receipts after edit/delete');
              await _fetchSavedReceipts();
            }
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
                  // Thumbnail with icons only (consistent with reports screen)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade100,
                    ),
                    child: Center(
                      child: isManual
                          ? const Icon(
                        Icons.edit_note,
                        size: 36,
                        color: Color(0xFF7E5EFD),
                      )
                          : isPdf
                          ? Icon(
                        Icons.picture_as_pdf,
                        size: 36,
                        color: Colors.red[400],
                      )
                          : const Icon(
                        Icons.receipt,
                        size: 36,
                        color: Color(0xFF7E5EFD),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                merchant,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isManual)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7E5EFD),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Manual',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$currencySymbol $amount', // Added space between currency symbol and amount
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF7E5EFD),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF7E5EFD),
          elevation: 0,
          title: const Center(
            child: AppLogo(isHeaderLogo: true),
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: const [
            SizedBox(width: 48),
          ],
        ),
        drawer: _buildDrawer(),
        body: _isUploading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
              ),
              const SizedBox(height: 24),
              Text(
                _uploadStatus,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we process your receipt',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              // Progress indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _uploadSteps.length,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF7E5EFD),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Step ${_currentStep + 1} of ${_uploadSteps.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Timeout in 20 seconds...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _fetchSavedReceipts,
          color: const Color(0xFF7E5EFD),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  _isLoadingUserName
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF7E5EFD),
                    ),
                  )
                      : Text(
                    'Welcome, $_userName!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7E5EFD),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your receipts, organized and accessible\nin one place.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Take Receipt Photo Button (First)
                  ElevatedButton(
                    onPressed: _isUploading
                        ? null
                        : _pickAndUploadImageFromCamera,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E5EFD),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt),
                        SizedBox(width: 8),
                        Text(
                          'Take Receipt Photo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Upload Receipt Button (Second) - Now shows dialog
                  OutlinedButton(
                    onPressed: _isUploading ? null : _showUploadDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7E5EFD),
                      side: const BorderSide(color: Color(0xFF7E5EFD)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file),
                        SizedBox(width: 8),
                        Text(
                          'Upload Receipt',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Manual Receipt Button (Third)
                  OutlinedButton(
                    onPressed: _isUploading ? null : _createManualReceipt,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7E5EFD),
                      side: const BorderSide(color: Color(0xFF7E5EFD)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_note, color: Color(0xFF7E5EFD)),
                        SizedBox(width: 8),
                        Text(
                          'Add Manual Receipt',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7E5EFD),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Text(
                          'Recent Uploads',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your Latest Receipts at a Glance!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildReceiptsList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}