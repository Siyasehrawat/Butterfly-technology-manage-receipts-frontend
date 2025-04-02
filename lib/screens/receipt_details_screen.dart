import 'package:flutter/material.dart';

class ReceiptDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> receipt;

  const ReceiptDetailsScreen({
    super.key,
    required this.receipt,
  });

  @override
  State<ReceiptDetailsScreen> createState() => _ReceiptDetailsScreenState();
}

class _ReceiptDetailsScreenState extends State<ReceiptDetailsScreen> {
  late TextEditingController _merchantController;
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  late TextEditingController _amountController;
  late TextEditingController _categoryController;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.receipt['store']);
    _dateController = TextEditingController(text: widget.receipt['date']);
    _timeController = TextEditingController(text: '18:30:00');
    _amountController =
        TextEditingController(text: '\$${widget.receipt['amount']}');
    _categoryController = TextEditingController(text: widget.receipt['category']);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // Menu functionality would be implemented here
          },
        ),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF8A56FF),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () {
                    // Menu functionality would be implemented here
                  },
                ),
                const Spacer(),
                Image.asset(
                  'assets/logo.png',
                  width: 60,
                  height: 60,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.receipt,
                        size: 30,
                        color: Color(0xFF7E5EFD),
                      ),
                    );
                  },
                ),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Receipt Image
                  Image.asset(
                    'assets/receipt_sample.png',
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 300,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.receipt_long,
                            size: 100,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Receipt Details',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'All receipt information in one organized view.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0E6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildEditableField(
                                'Merchant',
                                _merchantController,
                              ),
                              const Divider(),
                              _buildEditableField(
                                'Date',
                                _dateController,
                              ),
                              const Divider(),
                              _buildEditableField(
                                'Time',
                                _timeController,
                              ),
                              const Divider(),
                              _buildEditableField(
                                'Amount',
                                _amountController,
                              ),
                              const Divider(),
                              _buildEditableField(
                                'Category',
                                _categoryController,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () {
                            // Save receipt details functionality would be implemented here
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Receipt details saved!'),
                                backgroundColor: Color(0xFF7E5EFD),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildEditableField(String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.edit,
            color: Color(0xFF7E5EFD),
            size: 20,
          ),
          onPressed: () {
            // Edit field functionality would be implemented here
          },
        ),
      ],
    );
  }
}