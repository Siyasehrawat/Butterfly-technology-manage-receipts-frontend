import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/receipt_provider.dart';

class EditMerchantScreen extends StatefulWidget {
  final String initialValue;

  const EditMerchantScreen({
    super.key,
    required this.initialValue,
  });

  @override
  State<EditMerchantScreen> createState() => _EditMerchantScreenState();
}

class _EditMerchantScreenState extends State<EditMerchantScreen> {
  late TextEditingController _controller;
  List<String> _merchants = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _loadMerchants();
  }

  Future<void> _loadMerchants() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final merchants = await Provider.of<ReceiptProvider>(context, listen: false).getMerchants();
      setState(() {
        _merchants = merchants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Purple header with back button and logo
          Container(
            color: const Color(0xFF7E5EFD),
            padding: const EdgeInsets.only(top: 40, bottom: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Merchant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/logo.png',
                      width: 30,
                      height: 30,
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          'MR',
                          style: TextStyle(
                            color: Color(0xFF7E5EFD),
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // White content area
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Merchant name text field
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Enter Merchant Name',
                      border: UnderlineInputBorder(),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF7E5EFD)),
                      ),
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),

                  // Suggestions list
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                        ),
                      ),
                    )
                  else if (_merchants.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _merchants.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(_merchants[index]),
                            onTap: () {
                              _controller.text = _merchants[index];
                            },
                          );
                        },
                      ),
                    ),

                  const Spacer(),

                  // Save button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, _controller.text);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E5EFD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}