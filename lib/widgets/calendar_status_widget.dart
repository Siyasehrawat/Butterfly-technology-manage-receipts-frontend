import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/calendar_sync_service.dart';
import '../providers/user_provider.dart';

/// Widget that displays Google Calendar connection status
/// and allows users to connect/disconnect their calendar
class CalendarStatusWidget extends StatefulWidget {
  const CalendarStatusWidget({Key? key}) : super(key: key);
  
  @override
  State<CalendarStatusWidget> createState() => _CalendarStatusWidgetState();
}

class _CalendarStatusWidgetState extends State<CalendarStatusWidget> {
  bool _isConnected = false;
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _checkStatus();
  }
  
  Future<void> _checkStatus() async {
    if (!mounted) return;
    
    final user = Provider.of<UserProvider>(context, listen: false);
    final userId = user.userId;
    
    if (userId == null) {
      setState(() {
        _error = 'User not logged in';
        _isLoading = false;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final status = await CalendarSyncService.getCalendarStatus(
        userId,
        token: user.token,
      );
      
      if (!mounted) return;
      
      setState(() {
        _isConnected = status?['calendarSyncEnabled'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _error = 'Failed to check calendar status';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _connectCalendar() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final userId = user.userId;
    
    if (userId == null) {
      _showSnackBar('Please log in first', isError: true);
      return;
    }
    
    try {
      final connected = await CalendarSyncService.connectCalendar(
        userId,
        token: user.token,
        context: context,
      );
      
      if (!mounted) return;
      
      if (connected) {
        _showSnackBar('✅ Google Calendar connected successfully!');
        await _checkStatus();
      } else {
        _showSnackBar('Failed to connect calendar. Please try again.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e', isError: true);
    }
  }
  
  Future<void> _disconnectCalendar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Disconnect Calendar?'),
          ],
        ),
        content: const Text(
          'Your existing reminders will remain in Google Calendar, '
          'but new reminders won\'t sync until you reconnect.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Disconnect',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    final user = Provider.of<UserProvider>(context, listen: false);
    final userId = user.userId;
    
    if (userId == null) return;
    
    try {
      final success = await CalendarSyncService.disconnectCalendar(
        userId,
        token: user.token,
      );
      
      if (!mounted) return;
      
      if (success) {
        _showSnackBar('Calendar disconnected');
        await _checkStatus();
      } else {
        _showSnackBar('Failed to disconnect calendar', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e', isError: true);
    }
  }
  
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF7E5EFD),
        duration: Duration(milliseconds: isError ? 3000 : 2000),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              const Color(0xFF7E5EFD).withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E5EFD).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      size: 24,
                      color: Color(0xFF7E5EFD),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google Calendar Sync',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Sync bill reminders to your calendar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Content
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                    ),
                  ),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_isConnected)
                _buildConnectedView()
              else
                _buildDisconnectedView(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildConnectedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
              const SizedBox(width: 6),
              Text(
                'Connected',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Description
        const Text(
          '✅ Your bill reminders are automatically synced to Google Calendar',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        
        // Disconnect Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _disconnectCalendar,
            icon: const Icon(Icons.link_off, size: 18),
            label: const Text('Disconnect Calendar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDisconnectedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel, color: Colors.grey.shade600, size: 16),
              const SizedBox(width: 6),
              Text(
                'Not Connected',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Benefits List
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF7E5EFD).withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF7E5EFD).withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Connect to get:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              _BenefitItem(text: 'Automatic calendar reminders'),
              _BenefitItem(text: 'See bills in your daily schedule'),
              _BenefitItem(text: 'Never miss a payment'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Connect Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _connectCalendar,
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Connect Google Calendar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E5EFD),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final String text;
  
  const _BenefitItem({required this.text});
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Color(0xFF7E5EFD),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



