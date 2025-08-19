import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/user_provider.dart';
import '../services/api_service_bypass.dart';

class EditTagsScreen extends StatefulWidget {
  final List<String> initialValues; // Changed to List for multi-selection
  final String userId; // Added userId

  const EditTagsScreen({
    Key? key,
    this.initialValues = const [],
    required this.userId,
  }) : super(key: key);

  @override
  State<EditTagsScreen> createState() => _EditTagsScreenState();
}

class _EditTagsScreenState extends State<EditTagsScreen> {
  List<String> _tags = [];
  List<String> _selectedTags = [];
  bool _isLoading = true;
  bool _isInitializing = true;

  // Fallback tags
  static const List<String> _fallbackTags = [
    'Work',
    'Personal',
    'Travel',
    'Food',
    'Shopping',
    'Utilities',
  ];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    debugPrint('=== EditTagsScreen Initialization Started ===');

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (userProvider.userId == null || userProvider.userId!.isEmpty) {
      debugPrint('UserProvider not initialized, loading from storage...');
      try {
        await userProvider.initFromStorage();
        debugPrint('UserProvider initialized from storage');
      } catch (e) {
        debugPrint('Error initializing UserProvider from storage: $e');
      }
    }

    if (widget.userId.isEmpty) {
      debugPrint('ERROR: userId is empty in widget.userId!');
      setState(() {
        _isInitializing = false;
        _isLoading = false;
      });
      _showUserIdError();
      return;
    }

    setState(() {
      _selectedTags = List.from(widget.initialValues);
      _isInitializing = false;
    });

    await _loadTags();
  }

  void _showUserIdError() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Authentication Error'),
          content: const Text('User session not found. Please log in again.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/sign_in',
                      (route) => false,
                );
              },
              child: const Text('Login'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadTags() async {
    if (widget.userId.isEmpty) {
      debugPrint('Cannot load tags: userId is empty');
      return;
    }

    debugPrint('=== Loading Tags ===');
    debugPrint('userId being used: "${widget.userId}"');

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      // Corrected API endpoint to use query parameters for userId
      final response = await ApiService.get(
        '/receipts/tags?userId=${widget.userId}',
        token: userProvider.token, // Ensure token is passed
      );

      debugPrint('Tags API Response Status: ${response.statusCode}');
      debugPrint('Tags API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Parsed API Response: $data');

        // Assuming the response directly contains a 'tags' list or can be extracted
        if (data['tags'] != null && data['tags'] is List) {
          List<String> fetchedTags = List<String>.from(data['tags']);
          debugPrint('Fetched tags: $fetchedTags');

          if (mounted) {
            setState(() {
              _tags = fetchedTags;
              _isLoading = false;
            });
            debugPrint('Successfully loaded ${_tags.length} tags: $_tags');
          }
        } else {
          debugPrint('API response structure unexpected: ${data.keys}');
          if (mounted) {
            setState(() {
              _tags = List.from(_fallbackTags);
              _isLoading = false;
            });
            debugPrint('Using fallback tags due to unexpected API response structure');
          }
        }
      } else {
        debugPrint('API request failed with status: ${response.statusCode}');
        debugPrint('Error response body: ${response.body}');

        if (mounted) {
          setState(() {
            _tags = List.from(_fallbackTags);
            _isLoading = false;
          });
          debugPrint('Using fallback tags due to API error: ${response.statusCode}');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load tags (${response.statusCode}). Using default tags.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Exception loading tags: $e');
      debugPrint('Stack trace: ${StackTrace.current}');

      if (mounted) {
        setState(() {
          _tags = List.from(_fallbackTags);
          _isLoading = false;
        });
        debugPrint('Using fallback tags due to exception: $e');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tags: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleTag(String tagName) {
    debugPrint('Toggling tag: $tagName');
    setState(() {
      if (_selectedTags.contains(tagName)) {
        _selectedTags.remove(tagName);
      } else {
        _selectedTags.add(tagName);
      }
    });
    debugPrint('Selected tags: $_selectedTags');
  }

  void _applyFilter() {
    debugPrint('Applying filter/selection');
    debugPrint('Selected tags: $_selectedTags');

    final result = {
      'names': _selectedTags,
    };
    debugPrint('Returning result for tags: $result');
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (_isInitializing) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF7E5EFD),
              foregroundColor: Colors.white,
              title: const Text('Tags'),
            ),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                  ),
                  SizedBox(height: 16),
                  Text('Initializing...'),
                ],
              ),
            ),
          );
        }

        if (!userProvider.isLoggedIn || userProvider.userId == null || userProvider.userId!.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF7E5EFD),
              foregroundColor: Colors.white,
              title: const Text('Tags'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Not logged in',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Please log in to view tags',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/sign_in',
                            (route) => false,
                      );
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF7E5EFD),
            foregroundColor: Colors.white,
            title: const Text('Filter by Tags'),
            actions: [
              TextButton(
                onPressed: () {
                  debugPrint('Clear button pressed');
                  Navigator.pop(context, {
                    'names': [],
                  });
                },
                child: const Text(
                  'Clear',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                ),
                SizedBox(height: 16),
                Text('Loading tags...'),
              ],
            ),
          )
              : Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                color: const Color(0xFFF5F5F5),
                child: Text(
                  'Select one or more tags to filter receipts',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadTags,
                  color: const Color(0xFF7E5EFD),
                  child: _tags.isEmpty
                      ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tag, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No tags available',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Pull down to refresh',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    itemCount: _tags.length,
                    itemBuilder: (context, index) {
                      final tagName = _tags[index];
                      final isSelected = _selectedTags.contains(tagName);

                      return ListTile(
                        title: Text(
                          tagName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xFF7E5EFD))
                            : const Icon(Icons.circle_outlined, color: Colors.grey),
                        onTap: () => _toggleTag(tagName),
                        selected: isSelected,
                        selectedTileColor: const Color(0xFFE8E6FF),
                      );
                    },
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _selectedTags.isNotEmpty ? _applyFilter : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E5EFD),
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Apply Filter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
