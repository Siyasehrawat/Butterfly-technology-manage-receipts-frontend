import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/workspace_service.dart';

class WorkspaceNeedsRequestsScreen extends StatefulWidget {
  final String userId;
  final String token;
  final String workspaceId;
  final bool isManager;

  const WorkspaceNeedsRequestsScreen({
    Key? key,
    required this.userId,
    required this.token,
    required this.workspaceId,
    this.isManager = false,
  }) : super(key: key);

  @override
  State<WorkspaceNeedsRequestsScreen> createState() => _WorkspaceNeedsRequestsScreenState();
}

class _WorkspaceNeedsRequestsScreenState extends State<WorkspaceNeedsRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loadingMy = true;
  bool _loadingTeam = true;
  String? _errorMy;
  String? _errorTeam;
  List<Map<String, dynamic>> _myRequests = [];
  List<Map<String, dynamic>> _teamRequests = [];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _rejectReasonController = TextEditingController();
  String? _requestType;
  String? _priority;
  String? _editingRequestId;

  @override
  void initState() {
    super.initState();
    // Only show 2 tabs if manager, 1 tab for regular users
    _tabController = TabController(length: widget.isManager ? 2 : 1, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild when tab changes
    });
    _loadMyRequests();
    // Only load team requests if manager
    if (widget.isManager) {
      _loadTeamRequests();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rejectReasonController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyRequests() async {
    setState(() {
      _loadingMy = true;
      _errorMy = null;
    });

    final res = await WorkspaceService.listNeedsRequests(
      workspaceId: widget.workspaceId,
      userId: widget.userId, // Using userId as fallback until memberId is available
      query: {'userId': widget.userId},
      token: widget.token,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      try {
        final data = res['data'] as Map<String, dynamic>;
        final list = (data['requests'] ?? []) as List<dynamic>;
        setState(() {
          _myRequests = list.map(_normalizeRequest).toList();
          _loadingMy = false;
        });
      } catch (e) {
        setState(() {
          _errorMy = 'Failed to parse requests';
          _loadingMy = false;
        });
      }
    } else {
      setState(() {
        _errorMy = res['error']?.toString() ?? 'Failed to load requests';
        _loadingMy = false;
      });
    }
  }

  Future<void> _loadTeamRequests() async {
    setState(() {
      _loadingTeam = true;
      _errorTeam = null;
    });

    final res = await WorkspaceService.listNeedsRequests(
      workspaceId: widget.workspaceId,
      userId: widget.userId, // Using userId as fallback until memberId is available
      query: {'status': 'all'},
      token: widget.token,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      try {
        final data = res['data'] as Map<String, dynamic>;
        final list = (data['requests'] ?? []) as List<dynamic>;
        setState(() {
          _teamRequests = list.map(_normalizeRequest).toList();
          _loadingTeam = false;
        });
      } catch (e) {
        setState(() {
          _errorTeam = 'Failed to parse requests';
          _loadingTeam = false;
        });
      }
    } else {
      setState(() {
        _errorTeam = res['error']?.toString() ?? 'Failed to load requests';
        _loadingTeam = false;
      });
    }
  }

  String _mapApiToRequestType(String? apiValue) {
    if (apiValue == null) return 'other';
    final value = apiValue.toLowerCase();
    if (value.contains('software') || value.contains('subscription') || value.contains('license')) {
      return 'software_license';
    } else if (value.contains('hardware') || value.contains('equipment')) {
      return 'hardware_equipment';
    } else if (value.contains('training') || value.contains('certification')) {
      return 'training_certification';
    } else if (value.contains('travel')) {
      return 'travel_expense';
    } else if (value.contains('office') || value.contains('supplies')) {
      return 'office_supplies';
    }
    return 'other';
  }

  Map<String, dynamic> _normalizeRequest(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final apiRequestType = map['requestType'] ?? map['category'] ?? '';
    return {
      'id': map['id'] ?? map['_id'] ?? map['requestId'] ?? '',
      'title': map['title'] ?? map['requestName'] ?? 'Request',
      'description': map['description'] ?? '',
      'status': (map['status'] ?? 'pending').toString().toLowerCase(),
      'requestType': _mapApiToRequestType(apiRequestType),
      'priority': (map['priority'] ?? 'medium').toString().toLowerCase(),
      'submittedBy': map['submittedBy']?['name'] ?? 
                    map['submittedBy']?.toString() ?? 
                    map['requester']?['name'] ?? 
                    map['requester']?.toString() ?? 
                    '',
      'submittedAt': map['submittedAt'] ?? map['createdAt'] ?? map['date'] ?? '',
    };
  }

  String _mapRequestTypeToApi(String? requestType) {
    if (requestType == null) return 'Other';
    switch (requestType) {
      case 'software_license':
        return 'Software Subscription';
      case 'hardware_equipment':
        return 'Hardware';
      case 'training_certification':
        return 'Service';
      case 'travel_expense':
        return 'Service';
      case 'office_supplies':
        return 'Service';
      case 'other':
        return 'Other';
      default:
        return requestType;
    }
  }

  Future<void> _createRequest() async {
    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();
    if (widget.workspaceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace is required to submit a request')),
      );
      return;
    }
    if (title.isEmpty || desc.isEmpty || _requestType == null || _priority == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required')),
      );
      return;
    }

    final res = await WorkspaceService.createNeedsRequest(
      workspaceId: widget.workspaceId,
      userId: widget.userId, // Using userId as fallback until memberId is available
      body: {
        'requestType': _requestType,
        'category': _mapRequestTypeToApi(_requestType),
        'title': title,
        'requestName': title,
        'description': desc,
        'priority': _priority,
        'metadata': {},
      },
      token: widget.token,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      Navigator.pop(context);
      _titleController.clear();
      _descriptionController.clear();
      _requestType = null;
      _priority = null;
      await Future.wait([
        _loadMyRequests(),
        _loadTeamRequests(),
      ]);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Failed to create request')),
      );
    }
  }

  Future<void> _updateRequestFields(String requestId) async {
    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();
    if (title.isEmpty || desc.isEmpty || _requestType == null || _priority == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required')),
      );
      return;
    }

    final res = await WorkspaceService.updateNeedsRequest(
      workspaceId: widget.workspaceId,
      requestId: requestId,
      userId: widget.userId, // Using userId as fallback until memberId is available
      body: {
        'title': title,
        'requestName': title,
        'description': desc,
        'requestType': _requestType,
        'category': _mapRequestTypeToApi(_requestType),
        'priority': _priority,
      },
      token: widget.token,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      Navigator.pop(context);
      _titleController.clear();
      _descriptionController.clear();
      _requestType = null;
      _priority = null;
      _editingRequestId = null;
      await Future.wait([
        _loadMyRequests(),
        _loadTeamRequests(),
      ]);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request updated successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Failed to update request')),
      );
    }
  }

  Future<void> _updateRequest(String requestId, String status, {String? notes}) async {
    if (requestId.isEmpty) return;
    final res = await WorkspaceService.updateNeedsRequest(
      workspaceId: widget.workspaceId,
      requestId: requestId,
      userId: widget.userId, // Using userId as fallback until memberId is available
      body: {
        'status': status,
        if (notes != null && notes.isNotEmpty) 'reviewNotes': notes,
      },
      token: widget.token,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      await Future.wait([
        _loadMyRequests(),
        _loadTeamRequests(),
      ]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request ${status == 'approved' ? 'approved' : status == 'rejected' ? 'rejected' : status}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Update failed')),
      );
    }
  }

  void _showApproveDialog(String requestId, String requestName) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Approve Request',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.black87,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Question text
                Text(
                  'Are you sure you want to approve "$requestName"?',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E5EFD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _updateRequest(requestId, 'approved');
                      },
                      child: const Text(
                        'Approve',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRejectDialog(String requestId, String requestName) {
    _rejectReasonController.clear();
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reject Request',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.black87,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Question text
                Text(
                  'Are you sure you want to reject "$requestName"?',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                // Reason field
                const Text(
                  'Reason (Optional):',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _rejectReasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter reason for rejection...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        _rejectReasonController.clear();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        final reason = _rejectReasonController.text.trim();
                        Navigator.pop(context);
                        _updateRequest(
                          requestId,
                          'rejected',
                          notes: reason.isNotEmpty ? reason : null,
                        );
                        _rejectReasonController.clear();
                      },
                      child: const Text(
                        'Reject',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateSheet() {
    _titleController.clear();
    _descriptionController.clear();
    _requestType = null;
    _priority = null;
    _editingRequestId = null;
    _showRequestModal();
  }

  void _showEditSheet(Map<String, dynamic> request) {
    _titleController.text = request['title'] ?? '';
    _descriptionController.text = request['description'] ?? '';
    _requestType = request['requestType'] ?? null;
    _priority = request['priority'] ?? null;
    _editingRequestId = request['id'] ?? '';
    _showRequestModal();
  }

  void _showRequestModal() {
    final isEditing = _editingRequestId != null;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title and close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Request' : 'Create New Request',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.black87,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Request Type
                  _buildLabelWithAsterisk('Request Type'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _requestType,
                    decoration: InputDecoration(
                      hintText: 'Select request type',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'software_license', child: Text('Software License')),
                      DropdownMenuItem(value: 'hardware_equipment', child: Text('Hardware Equipment')),
                      DropdownMenuItem(value: 'training_certification', child: Text('Training/Certification')),
                      DropdownMenuItem(value: 'travel_expense', child: Text('Travel Expense')),
                      DropdownMenuItem(value: 'office_supplies', child: Text('Office Supplies')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _requestType = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  // Request Name
                  _buildLabelWithAsterisk('Request Name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Enter request name',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Priority
                  _buildLabelWithAsterisk('Priority'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: InputDecoration(
                      hintText: 'Select priority',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _priority = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  // Description with grammar assistant icon
                  _buildLabelWithAsterisk('Description'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Describe your request in detail...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7E5EFD), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E5EFD),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: isEditing
                            ? () => _updateRequestFields(_editingRequestId!)
                            : _createRequest,
                        child: Text(
                          isEditing ? 'Update Request' : 'Create Request',
                          style: const TextStyle(fontSize: 14),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isManager ? 'Needs Requests (Manager)' : 'Needs Requests',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () async {
              await Future.wait([_loadMyRequests(), _loadTeamRequests()]);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black87),
            onPressed: _showCreateSheet,
          ),
        ],
        bottom: widget.isManager
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          label: 'My Requests',
                          isSelected: _tabController.index == 0,
                          onTap: () {
                            _tabController.animateTo(0);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTabButton(
                          label: 'Team Requests',
                          isSelected: _tabController.index == 1,
                          onTap: () {
                            _tabController.animateTo(1);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: widget.isManager
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildMyRequestsTab(),
                _buildTeamRequestsTab(),
              ],
            )
          : _buildMyRequestsTab(),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1ECFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyRequestsTab() {
    if (_loadingMy) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMy != null) {
      return _buildErrorState(_errorMy!, _loadMyRequests);
    }
    if (_myRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_outlined,
        title: 'No requests yet',
        subtitle: 'Your resource requests will appear here',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMyRequests,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _myRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final r = _myRequests[index];
          final status = r['status'] ?? 'pending';
          final statusColor = _statusColor(status);
          return _buildRequestCard(
            request: r,
            statusLabel: _formatStatus(status),
            statusColor: statusColor,
            showEditButton: status == 'pending',
            onEdit: () => _showEditSheet(r),
          );
        },
      ),
    );
  }

  Widget _buildTeamRequestsTab() {
    if (_loadingTeam) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorTeam != null) {
      return _buildErrorState(_errorTeam!, _loadTeamRequests);
    }
    if (_teamRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group_outlined,
        title: 'No team requests',
        subtitle: 'Team resource requests will appear here',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadTeamRequests,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _teamRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final r = _teamRequests[index];
          final status = r['status'] ?? 'pending';
          final statusColor = _statusColor(status);
          final actions = _buildTeamActions(r);
          return _buildRequestCard(
            request: r,
            statusLabel: _formatStatus(status),
            statusColor: statusColor,
            primaryActionLabel: actions.$1,
            primaryActionColor: actions.$5,
            primaryTextColor: actions.$6,
            onPrimary: actions.$2,
            secondaryActionLabel: actions.$3,
            secondaryActionColor: actions.$7,
            secondaryTextColor: actions.$8,
            onSecondary: actions.$4,
          );
        },
      ),
    );
  }

  (String?, VoidCallback?, String?, VoidCallback?, Color?, Color?, Color?, Color?)
      _buildTeamActions(Map<String, dynamic> req) {
    final status = (req['status'] ?? 'pending').toString().toLowerCase();
    final id = req['id']?.toString() ?? '';
    final title = req['title'] ?? 'Request';

    if (status == 'pending') {
      return (
        'Approve',
        () => _showApproveDialog(id, title),
        'Reject',
        () => _showRejectDialog(id, title),
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
        const Color(0xFFFFEBEE),
        const Color(0xFFC62828),
      );
    }
    if (status == 'approved') {
      return (
        'Mark Fulfilled',
        () => _updateRequest(id, 'fulfilled'),
        null,
        null,
        const Color(0xFFE3F2FD),
        const Color(0xFF1976D2),
        null,
        null,
      );
    }
    return (null, null, null, null, null, null, null, null);
  }

  Color _statusColor(String? status) {
    switch ((status ?? 'pending').toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'fulfilled':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String _formatStatus(String? status) {
    final s = (status ?? 'pending').toLowerCase();
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF1ECFF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 64,
                color: const Color(0xFF7E5EFD),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, Future<void> Function() retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: retry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard({
    required Map<String, dynamic> request,
    required String statusLabel,
    required Color statusColor,
    String? primaryActionLabel,
    Color? primaryActionColor,
    Color? primaryTextColor,
    String? secondaryActionLabel,
    Color? secondaryActionColor,
    Color? secondaryTextColor,
    VoidCallback? onPrimary,
    VoidCallback? onSecondary,
    bool showEditButton = false,
    VoidCallback? onEdit,
  }) {
    final title = request['title'] ?? '';
    final description = request['description'] ?? '';
    final requestType = request['requestType'] ?? '';
    final priority = request['priority'] ?? 'medium';
    final submittedBy = request['submittedBy'] ?? '';
    final submittedAt = request['submittedAt'] ?? '';
    
    final priorityColor = _priorityColor(priority);
    final topBorderColor = _getTopBorderColor(statusColor);
    final requestTypeIcon = _getRequestTypeIcon(requestType);
    final requestTypeLabel = _formatRequestType(requestType);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top colored border
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: topBorderColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusBackgroundColor(statusColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Request Type, Requester, and Priority in one line
                Row(
                  children: [
                    // Request Type
                    Icon(requestTypeIcon, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Flexible(
                      flex: 2,
                      child: Text(
                        requestTypeLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Requester
                    if (submittedBy.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Flexible(
                        flex: 2,
                        child: Text(
                          submittedBy,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Description with purple accent
                Container(
                  padding: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Color(0xFF7E5EFD), width: 3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Date and Priority on same line
                if (submittedAt.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(submittedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Priority Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor['background'],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          priority.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: priorityColor['text'],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                // Action Buttons
                if (primaryActionLabel != null || secondaryActionLabel != null || showEditButton)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (showEditButton) ...[
                        _buildActionButton(
                          label: 'Edit',
                          backgroundColor: const Color(0xFF2196F3),
                          textColor: Colors.white,
                          onPressed: onEdit,
                        ),
                      ],
                      if (primaryActionLabel != null) ...[
                        if (showEditButton) const SizedBox(width: 8),
                        _buildActionButton(
                          label: primaryActionLabel,
                          backgroundColor: primaryActionColor ?? Colors.white,
                          textColor: primaryTextColor ?? Colors.black87,
                          onPressed: onPrimary,
                        ),
                      ],
                      if (secondaryActionLabel != null) ...[
                        const SizedBox(width: 8),
                        _buildActionButton(
                          label: secondaryActionLabel,
                          backgroundColor: secondaryActionColor ?? Colors.white,
                          textColor: secondaryTextColor ?? Colors.black87,
                          onPressed: onSecondary,
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  IconData _getRequestTypeIcon(String requestType) {
    final type = requestType.toLowerCase();
    if (type.contains('software') || type.contains('license')) {
      return Icons.description_outlined;
    } else if (type.contains('hardware') || type.contains('equipment')) {
      return Icons.computer_outlined;
    } else if (type.contains('training') || type.contains('certification')) {
      return Icons.school_outlined;
    } else if (type.contains('travel')) {
      return Icons.flight_outlined;
    } else if (type.contains('office') || type.contains('supplies')) {
      return Icons.inventory_2_outlined;
    }
    return Icons.category_outlined;
  }

  String _formatRequestType(String requestType) {
    final type = requestType.toLowerCase();
    if (type.contains('software') || type.contains('license')) {
      return 'Software License';
    } else if (type.contains('hardware') || type.contains('equipment')) {
      return 'Hardware Equipment';
    } else if (type.contains('training') || type.contains('certification')) {
      return 'Training/Certification';
    } else if (type.contains('travel')) {
      return 'Travel Expense';
    } else if (type.contains('office') || type.contains('supplies')) {
      return 'Office Supplies';
    }
    return 'Other';
  }

  Map<String, Color> _priorityColor(String priority) {
    final p = priority.toLowerCase();
    switch (p) {
      case 'high':
        return {
          'background': const Color(0xFFFFEBEE),
          'text': const Color(0xFFC62828),
        };
      case 'medium':
        return {
          'background': const Color(0xFFFFF3E0),
          'text': const Color(0xFFE65100),
        };
      case 'low':
        return {
          'background': const Color(0xFFE8F5E9),
          'text': const Color(0xFF2E7D32),
        };
      default:
        return {
          'background': const Color(0xFFFFF3E0),
          'text': const Color(0xFFE65100),
        };
    }
  }

  Color _getTopBorderColor(Color statusColor) {
    if (statusColor == Colors.green) {
      return Colors.green;
    } else if (statusColor == Colors.red) {
      return Colors.red;
    } else if (statusColor == Colors.blue) {
      return Colors.blue;
    }
    return Colors.orange;
  }

  Color _getStatusBackgroundColor(Color statusColor) {
    if (statusColor == Colors.green) {
      return const Color(0xFFE8F5E9);
    } else if (statusColor == Colors.red) {
      return const Color(0xFFFFEBEE);
    } else if (statusColor == Colors.blue) {
      return const Color(0xFFE3F2FD);
    }
    return const Color(0xFFFFF3E0);
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildLabelWithAsterisk(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(
              color: Colors.red,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}




