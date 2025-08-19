import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputAction

class DocumentDetailsDialog extends StatefulWidget {
  final String? initialDocName;
  final String? initialDocType;
  final List<String>? initialDocTags; // Changed to List<String>
  final String? initialDocComments;
  final bool isExistingDoc;
  final String? tempCloudinaryFileUrl; // This will now be final when dialog opens
  final Function(String name, String type, List<String> tags, String comments) onSave; // Changed tags to List<String>
  final Function(String docId, String name, String type, List<String> tags, String comments) onUpdate; // Changed tags to List<String>
  final String? existingDocId;

  const DocumentDetailsDialog({
    super.key,
    this.initialDocName,
    this.initialDocType,
    this.initialDocTags,
    this.initialDocComments,
    required this.isExistingDoc,
    this.tempCloudinaryFileUrl,
    required this.onSave,
    required this.onUpdate,
    this.existingDocId,
  });

  @override
  State<DocumentDetailsDialog> createState() => _DocumentDetailsDialogState();
}

class _DocumentDetailsDialogState extends State<DocumentDetailsDialog> {
  late TextEditingController _nameController;
  late TextEditingController _typeController;
  late TextEditingController _tagInputController; // For new tag input
  late TextEditingController _commentsController;

  List<String> _tags = []; // List to hold individual tags
  bool _canSave = false;

  final int _maxTags = 5;
  final int _maxCommentLength = 100; // <CHANGE> Added 100 character limit for comments

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDocName);
    _typeController = TextEditingController(text: widget.initialDocType);
    _tagInputController = TextEditingController();
    _commentsController = TextEditingController(text: widget.initialDocComments);

    if (widget.initialDocTags != null) {
      _tags = List.from(widget.initialDocTags!);
    }

    // Add listeners to update _canSave state
    _nameController.addListener(_updateCanSave);
    _typeController.addListener(_updateCanSave);
    _tagInputController.addListener(_updateCanSave); // Listen to tag input for count
    _commentsController.addListener(_updateCanSave); // Listen to comments for any changes

    // Initial check for save button state
    _updateCanSave();
  }

  @override
  void dispose() {
    _nameController.removeListener(_updateCanSave);
    _typeController.removeListener(_updateCanSave);
    _tagInputController.removeListener(_updateCanSave);
    _commentsController.removeListener(_updateCanSave);

    _nameController.dispose();
    _typeController.dispose();
    _tagInputController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  void _updateCanSave() {
    setState(() {
      // For existing documents, save is always enabled if any field changes
      // For new documents, name and type are required, and cloudinary URL must be present
      _canSave = widget.isExistingDoc
          ? true // Always allow update for existing docs
          : (widget.tempCloudinaryFileUrl != null &&
          _nameController.text.isNotEmpty &&
          _typeController.text.isNotEmpty);
    });
  }

  void _addTag(String tag) {
    if (tag.trim().isNotEmpty && _tags.length < _maxTags) {
      setState(() {
        _tags.add(tag.trim());
        _tagInputController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFF5F5F5), // Light background to match image
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 8.0),
      title: Text(
        widget.isExistingDoc ? 'Edit Document Details' : 'Document Details',
        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Make column take minimum space
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document Name
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Document Name ',
                    style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: '*',
                    style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            TextFormField(
              controller: _nameController,
              maxLength: 50,
              decoration: const InputDecoration(
                hintText: 'Enter document name',
                filled: true,
                fillColor: Colors.white,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 0.5),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7E5EFD), width: 1.5),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                counterStyle: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 12),

            // Document Type
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Document Type ',
                    style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: '*',
                    style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            TextFormField(
              controller: _typeController,
              maxLength: 50,
              decoration: const InputDecoration(
                hintText: 'e.g. Insurance',
                filled: true,
                fillColor: Colors.white,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 0.5),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7E5EFD), width: 1.5),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                counterStyle: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 12),

            // Tags
            Text(
              'Tags (${_tags.length}/$_maxTags)',
              style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            TextFormField(
              controller: _tagInputController,
              decoration: const InputDecoration(
                hintText: 'Type a tag and press Enter',
                filled: true,
                fillColor: Colors.white,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 0.5),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7E5EFD), width: 1.5),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              style: const TextStyle(color: Colors.black87),
              onFieldSubmitted: (value) {
                _addTag(value);
              },
              textInputAction: TextInputAction.done, // Show "Done" button on keyboard
            ),
            if (_tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text(tag, style: const TextStyle(color: Colors.white)),
                      backgroundColor: const Color(0xFF7E5EFD),
                      deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white),
                      onDeleted: () => _removeTag(tag),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 12),

            // Comments
            const Text('Comments', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            TextFormField(
              controller: _commentsController,
              maxLength: _maxCommentLength, // <CHANGE> Enforced 100 character limit
              decoration: InputDecoration(
                hintText: 'Enter your comments here (max $_maxCommentLength characters)', // <CHANGE> Updated hint text
                filled: true,
                fillColor: Colors.white,
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey, width: 0.5),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7E5EFD), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                counterStyle: const TextStyle(fontSize: 12, color: Colors.grey), // <CHANGE> Added character counter
              ),
              maxLines: 3,
              style: const TextStyle(color: Colors.black87),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel', style: TextStyle(color: Colors.black54)), // Darker text for cancel
        ),
        ElevatedButton(
          onPressed: _canSave
              ? () {
            if (widget.isExistingDoc) {
              widget.onUpdate(
                widget.existingDocId!,
                _nameController.text,
                _typeController.text,
                _tags, // Pass the list of tags
                _commentsController.text,
              );
            } else {
              widget.onSave(
                _nameController.text,
                _typeController.text,
                _tags, // Pass the list of tags
                _commentsController.text,
              );
            }
            Navigator.pop(context);
          }
              : null, // Disable Save button if not ready
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7E5EFD), // Purple background for save button
            foregroundColor: Colors.white, // White text for save button
          ),
          child: Text(widget.isExistingDoc ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}
