import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/receipt_provider.dart';
import '../providers/user_provider.dart';
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
  Map<int, String> categoryMap = {}; // Map to store category ID to name mapping
  bool _isLoading = true;
  bool _isUploading = false;
  String _userName = 'User';
  bool _isLoadingUserName = true;
  DateTime? _lastBackPressTime; // Track the last back button press time

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final receiptProvider = Provider.of<ReceiptProvider>(
        context,
        listen: false,
      );
      receiptProvider.setUserId(widget.userId);
      _fetchUserName().then((name) {
        setState(() {
          _userName = name;
          _isLoadingUserName = false;
        });
        _fetchCategories().then((_) => _fetchSavedReceipts());
      });
    });
  }

  // Handle back button press with double-press to exit
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

  Future<String> _fetchUserName() async {
    try {
      final response = await http.get(
        Uri.parse('https://manage-receipt-backend-bnl1.onrender.com/api/users/profile'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final user = (data['users'] as List<dynamic>).firstWhere(
              (user) => user['id'] == widget.userId,
          orElse: () => null,
        );

        if (user != null) {
          return user['name'] ?? 'User';
        }
      }
      return 'User';
    } catch (e) {
      debugPrint('Error fetching user name: $e');
      return 'User';
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final url =
      Uri.parse('https://manage-receipt-backend-bnl1.onrender.com/api/categories/get-all-categories');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Create a map of category ID to category name
        for (var category in data) {
          categoryMap[category['categoryId']] = category['name'];
        }

        // Add a fallback for "Other" category
        categoryMap[0] = 'Other';
      } else {
        // Fallback categories if API fails
        categoryMap = {
          1: 'Meal',
          2: 'Education',
          3: 'Medical',
          4: 'Shopping',
          5: 'Travel',
          6: 'Rent',
          0: 'Other',
        };
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      // Fallback categories if API fails
      categoryMap = {
        1: 'Meal',
        2: 'Education',
        3: 'Medical',
        4: 'Shopping',
        5: 'Travel',
        6: 'Rent',
        0: 'Other',
      };
    }
  }

  Future<void> _fetchSavedReceipts() async {
    setState(() => _isLoading = true);
    final url = 'https://manage-receipt-backend-bnl1.onrender.com/api/receipts/${widget.userId}';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> receipts = data is List ? data : data['receipts'] ?? [];

        // Sort receipts by updatedAt (newest first), then createdAt, then receiptDate
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

          return dateB.compareTo(dateA); // Newest first
        });

        setState(() {
          savedReceipts = receipts;
          _isLoading = false;
        });
      } else {
        debugPrint(
            'Failed to load receipts: ${response.statusCode} - ${response.body}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching receipts: $e");
      setState(() => _isLoading = false);
    }
  }

  // Helper method to parse dates safely
  DateTime? _parseDate(dynamic dateString) {
    if (dateString == null) return null;
    try {
      // Try parsing with the default format (YYYY-MM-DD)
      return DateTime.parse(dateString.toString());
    } catch (e) {
      try {
        // If parsing fails, handle MM-DD-YYYY format explicitly
        final DateFormat formatter = DateFormat('MM-dd-yyyy');
        return formatter.parse(dateString.toString());
      } catch (e) {
        debugPrint('Error parsing date: $e');
        return null;
      }
    }
  }

  Future<void> _uploadImageToCloudinary(
      BuildContext context, dynamic image) async {
    setState(() {
      _isUploading = true;
    });

    const cloudinaryUrl =
        'https://api.cloudinary.com/v1_1/dexex1gzu/image/upload';
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

      // Add a timeout for the request
      var response = await request.send().timeout(const Duration(seconds: 20));
      var responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);

      if (response.statusCode == 200) {
        await _sendImageUrlToBackend(context, jsonResponse["secure_url"] ?? '');
      } else {
        throw Exception(
            "Cloudinary error: ${jsonResponse['error']?['message'] ?? 'Unknown error'}");
      }
    } on TimeoutException {
      debugPrint("Upload Error: Request timed out");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload timed out. Please try again.')),
      );
      setState(() {
        _isUploading = false;
      });
    } on http.ClientException catch (e) {
      debugPrint("Upload Error: $e");
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to upload image. Please try again.')),
      );
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _sendImageUrlToBackend(
      BuildContext context, String imageUrl) async {
    const backendUrl = 'https://manage-receipt-backend-bnl1.onrender.com/api/receipts/process-receipt';

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({'imageUrl': imageUrl, 'userId': widget.userId}),
      );

      setState(() {
        _isUploading = false;
      });

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);

        // Check if the response contains the expected receiptDetails
        if (responseBody != null && responseBody["receiptDetails"] != null) {
          final receiptDetails = responseBody["receiptDetails"];

          // Navigate to receipt details screen and wait for result
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReceiptDetailsScreen(
                receipt: receiptDetails,
                imageUrl: receiptDetails['imageUrl'] ?? '',
                userId: widget.userId,
                imageId: receiptDetails['imageId']?.toString() ?? '',
                isNewReceipt: true,
              ),
            ),
          );

          // Only refresh the receipts list if the receipt was saved
          if (result == true) {
            _fetchSavedReceipts();
          }
        } else {
          // Handle unexpected response structure
          throw Exception(
              'Unexpected response structure: Missing receiptDetails');
        }
      } else {
        // Handle backend error message
        final error = json.decode(response.body)['error'] ?? 'Unknown error';
        throw Exception('Backend error: $error');
      }
    } catch (e) {
      debugPrint("Backend Error: $e");
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

  Future<void> _pickAndUploadImage(
      BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image != null) {
      await _uploadImageToCloudinary(context, image);
    }
  }

  // Add logout method
  void _logout(BuildContext context) async {
    final authService = AuthService();
    await authService.signOut();

    // Update the user provider
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.logout();

    // Navigate to welcome screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false, // Remove all previous routes
    );
  }

  AppDrawer _buildDrawer() {
    return AppDrawer(
      userId: widget.userId,
      token: widget.token,
      onLogout: () => _logout(context), // Pass the logout function
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
          ],
        ),
      );
    }

    // Show only the last 5 receipts
    final recentReceipts = savedReceipts.take(5).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentReceipts.length,
      itemBuilder: (context, index) {
        final receipt = recentReceipts[index];
        final imageUrl =
            receipt['imageLink'] ?? ''; // Map imageLink from backend
        final merchant = receipt['merchant']?.toString() ?? 'Unknown';
        final amount = receipt['amount']?.toString() ?? '0';

        // Get category name from categoryId
        String category = 'Uncategorized';
        if (receipt['categoryId'] != null) {
          final categoryId =
              int.tryParse(receipt['categoryId'].toString()) ?? 0;
          category = categoryMap[categoryId] ?? 'Uncategorized';
        }

        // Format the receiptDate
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
                ),
              ),
            );

            // Refresh the list if the receipt was updated
            if (result == true) {
              _fetchSavedReceipts();
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EAFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Receipt thumbnail
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child,
                            loadingProgress) =>
                        loadingProgress == null
                            ? child
                            : const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation<Color>(
                                Color(0xFF7E5EFD)),
                          ),
                        ),
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(
                          Icons.receipt,
                          size: 30,
                          color: Color(0xFF7E5EFD),
                        ),
                      )
                          : const Icon(
                        Icons.receipt,
                        size: 30,
                        color: Color(0xFF7E5EFD),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Receipt details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchant,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$$amount',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Category and date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF7E5EFD),
                        ),
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
      onWillPop: _onWillPop, // Handle back button press
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF7E5EFD),
          elevation: 0,
          title: const Center(
            // Updated logo implementation
            child: AppLogo(isHeaderLogo: true),
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: const [
            // Adding an empty action to balance the appbar
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
                'Uploading receipt...',
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

                  // Upload Photo Button
                  OutlinedButton(
                    onPressed: _isUploading
                        ? null
                        : () => _pickAndUploadImage(
                        context, ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7E5EFD),
                      side: const BorderSide(color: Color(0xFF7E5EFD)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: const Text(
                      'Upload receipt Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Take Photo Button
                  ElevatedButton(
                    onPressed: _isUploading
                        ? null
                        : () => _pickAndUploadImage(
                        context, ImageSource.camera),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E5EFD),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: const Text(
                      'Take receipt  Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Recent Uploads Section
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

                  // Receipts List
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