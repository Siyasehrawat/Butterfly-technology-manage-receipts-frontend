import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/referral_service.dart';

class ReferEarnScreen extends StatefulWidget {
  final String userId;
  final String token;

  const ReferEarnScreen({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  final TextEditingController _applyCodeController = TextEditingController();
  bool _applied = false;
  bool _isLoading = true;
  bool _isApplying = false;
  bool _loadingCopy = true;
  
  String _referralCode = '';
  String _referralLink = '';
  int _friendsReferred = 0;
  int _pointsEarned = 0;
  List<dynamic> _inviteHistory = [];
  
  // Referral copy text from API
  Map<String, dynamic>? _referralCopy;
  String _referrerBannerHeadline = '';
  String _referrerCardDescription = '';
  String _referrerBannerSubheadline = '';
  String _refereeSectionTitle = '';
  String _refereeInstructions = '';
  String _refereePlaceholder = '';
  String _refereeButtonText = '';
  List<Map<String, dynamic>> _howItWorksSteps = [];

  @override
  void initState() {
    super.initState();
    _loadReferralData();
    _loadReferralCopy();
  }

  /// Generate platform-specific referral link
  String _generateReferralLink(String referralCode) {
    if (kIsWeb) {
      // For web, show Play Store link
      return 'https://play.google.com/store/apps/details?id=com.ButterflyTchnology.managereceipt&referrer=ref=$referralCode';
    } else if (Platform.isIOS) {
      // iOS App Store link
      return 'https://apps.apple.com/in/app/manage-receipt-expense-tracker/id6746782746?ref=$referralCode';
    } else if (Platform.isAndroid) {
      // Google Play Store link
      return 'https://play.google.com/store/apps/details?id=com.ButterflyTchnology.managereceipt&referrer=ref=$referralCode';
    } else {
      // Fallback for other platforms - Play Store link
      return 'https://play.google.com/store/apps/details?id=com.ButterflyTchnology.managereceipt&referrer=ref=$referralCode';
    }
  }

  Future<void> _loadReferralCopy() async {
    setState(() => _loadingCopy = true);
    
    // Pass userId to get referral code in the response
    final response = await ReferralService.getReferralCopy(
      widget.token,
      userId: widget.userId,
    );
    
    if (response != null && mounted) {
      setState(() {
        _referralCopy = response;
        
        // Parse response structure: { success: true, data: { referrer: {...}, referee: {...} } }
        final data = response['data'] as Map<String, dynamic>? ?? {};
        
        // Parse referrer text (for the person referring)
        final referrer = data['referrer'] as Map<String, dynamic>? ?? {};
        _referrerBannerHeadline = referrer['bannerHeadline'] as String? ?? '';
        _referrerCardDescription = referrer['cardDescription'] as String? ?? '';
        _referrerBannerSubheadline = referrer['bannerSubheadline'] as String? ?? '';
        
        // Get referral code from API response if available
        final referralCodeFromApi = referrer['referralCode'] as String?;
        if (referralCodeFromApi != null && referralCodeFromApi.isNotEmpty) {
          _referralCode = referralCodeFromApi.toUpperCase();
        }
        
        // Parse referee text (for the person being referred)
        final referee = data['referee'] as Map<String, dynamic>? ?? {};
        _refereeSectionTitle = referee['sectionTitle'] as String? ?? '';
        _refereeInstructions = referee['instructions'] as String? ?? '';
        _refereePlaceholder = referee['placeholder'] as String? ?? '';
        _refereeButtonText = referee['buttonText'] as String? ?? '';
        
        // Parse "How It Works" steps if provided
        final steps = data['howItWorks'] ?? response['howItWorks'] ?? [];
        if (steps is List && steps.isNotEmpty) {
          _howItWorksSteps = steps.map<Map<String, dynamic>>((step) {
            if (step is Map) {
              return Map<String, dynamic>.from(step);
            }
            return {};
          }).toList();
        } else {
          // Keep default steps if not provided
          _howItWorksSteps = [
            {'step': '1', 'title': 'Share Your Code', 'subtitle': 'Share your referral code or link with others.'},
            {'step': '2', 'title': 'User Signs Up', 'subtitle': 'The user downloads the app and enters your code in the Refer & Earn section.'},
            {'step': '3', 'title': 'User Uploads Receipt', 'subtitle': 'The user uploads their first receipt.'},
            {'step': '4', 'title': 'You Get Rewarded', 'subtitle': 'You receive points when the signup process is completed.'},
            {'step': '5', 'title': 'User Gets Bonus', 'subtitle': 'The user also earns bonus points for using your code.'},
          ];
        }
        
        // Update referral link if we got a code from the API
        if (_referralCode.isNotEmpty) {
          _referralLink = _generateReferralLink(_referralCode);
        }
        
        _loadingCopy = false;
      });
    } else if (mounted) {
      setState(() => _loadingCopy = false);
      // Default values are already set in initState
    }
  }

  Future<void> _loadReferralData() async {
    setState(() => _isLoading = true);
    
    final response = await ReferralService.getReferralDashboard(
      widget.userId,
      widget.token,
    );
    
    if (response != null && mounted) {
      // Extract data from the response structure
      final data = response['data'] as Map<String, dynamic>?;
      
      if (data != null) {
        final stats = data['stats'] as Map<String, dynamic>? ?? {};
        final referralCodeFromDashboard = data['referralCode'] as String? ?? '';
        
        setState(() {
          // Only use referral code from dashboard if we don't have one from copy API
          // The copy API is the source of truth for referral code when userId is provided
          if (_referralCode.isEmpty && referralCodeFromDashboard.isNotEmpty) {
            _referralCode = referralCodeFromDashboard;
            _referralLink = _generateReferralLink(referralCodeFromDashboard);
          } else if (_referralCode.isNotEmpty) {
            // Ensure referral link is updated if we have a code
            _referralLink = _generateReferralLink(_referralCode);
          }
          
          _friendsReferred = stats['friendsReferred'] as int? ?? 0;
          _pointsEarned = stats['pointsEarned'] as int? ?? 0;
          _inviteHistory = data['history'] as List<dynamic>? ?? [];
          _applied = stats['hasRedeemedReferral'] as bool? ?? false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid response format')),
          );
        }
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load referral data')),
      );
    }
  }

  Future<void> _applyReferralCode() async {
    final code = _applyCodeController.text.trim().toUpperCase();
    
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a referral code')),
      );
      return;
    }
    
    if (code.length < 4 || code.length > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid referral code')),
      );
      return;
    }

    setState(() => _isApplying = true);

    final result = await ReferralService.applyReferralCode(
      widget.userId,
      code,
      widget.token,
    );

    if (mounted) {
      setState(() => _isApplying = false);
      
      if (result['success'] == true) {
        setState(() => _applied = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Referral code applied successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload data to get updated stats
        _loadReferralData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to apply referral code'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Refer & Earn'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: const Center(
                child: Text(
                  'MR',
                  style: TextStyle(
                    color: Color(0xFF7E5EFD),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: (_isLoading || _loadingCopy)
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7E5EFD)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderCard(
                    title: _referrerBannerHeadline,
                    subtitle: '',
                    description: _referrerBannerSubheadline,
                  ),
                  const SizedBox(height: 16),
                  _ApplyCodeCard(
                    controller: _applyCodeController,
                    onApply: _applyReferralCode,
                    applied: _applied,
                    isApplying: _isApplying,
                    title: _refereeSectionTitle,
                    subtitle: _refereeInstructions,
                    placeholder: _refereePlaceholder,
                    buttonText: _refereeButtonText,
                  ),
                  const SizedBox(height: 16),
                  _ReferralCodeCard(
                    code: _referralCode.isNotEmpty ? _referralCode : 'Loading...',
                    onCopy: _referralCode.isNotEmpty ? () async {
                      await Clipboard.setData(ClipboardData(text: _referralCode));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied code to clipboard')),
                      );
                    } : null,
                  ),
                  const SizedBox(height: 16),
                  _ShareLinkCard(
                    link: _referralLink,
                    referralCode: _referralCode,
                    onShareGeneric: () {
                      final message = '🎁 Join me on Manage Receipt - AI Receipt Scanner & Expense Tracker!\n\n'
                          'Use my referral code: $_referralCode to get bonus points when you sign up!\n\n'
                          'Download now: $_referralLink';
                      Share.share(message);
                    },
                    onShareWhatsApp: () async {
                      final message = '🎁 Join me on Manage Receipt - AI Receipt Scanner & Expense Tracker!\n\n'
                          'Use my referral code: *$_referralCode* to get bonus points when you sign up!\n\n'
                          'Download now: $_referralLink';
                      final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } else {
                        Share.share(message);
                      }
                    },
                    onShareMessage: () async {
                      final message = 'Join me on Manage Receipt! Use code $_referralCode for bonus points. Download: $_referralLink';
                      final sms = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
                      if (await canLaunchUrl(sms)) {
                        await launchUrl(sms);
                      } else {
                        Share.share(message);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _SummaryStat(label: 'Referral Count', value: _friendsReferred.toString())),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryStat(label: 'Points Earned', value: _pointsEarned.toString())),
                    ],
                  ),
                  if (_howItWorksSteps.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'How It Works',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ..._howItWorksSteps.map((step) => _StepTile(
                      step: step['step']?.toString() ?? '',
                      title: step['title'] ?? '',
                      subtitle: step['subtitle'] ?? step['description'] ?? '',
                    )),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFFFF7300)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7300).withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          if (subtitle.isNotEmpty && subtitle != title) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('👥', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      description,
                      style: const TextStyle(color: Colors.white, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReferralCodeCard extends StatelessWidget {
  final String code;
  final VoidCallback? onCopy;
  const _ReferralCodeCard({required this.code, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7E5EFD).withOpacity(0.4), width: 2, style: BorderStyle.solid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Your Referral Code', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  code,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF7E5EFD), letterSpacing: 2),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, color: Color(0xFF7E5EFD)),
                  tooltip: 'Copy',
                  splashRadius: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareLinkCard extends StatelessWidget {
  final String link;
  final String referralCode;
  final VoidCallback onShareGeneric;
  final VoidCallback onShareWhatsApp;
  final VoidCallback onShareMessage;
  const _ShareLinkCard({
    required this.link,
    required this.referralCode,
    required this.onShareGeneric,
    required this.onShareWhatsApp,
    required this.onShareMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Share Your Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: link,
            readOnly: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF6F3FF),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onShareWhatsApp,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                  child: const Text('WhatsApp'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onShareMessage,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7E5EFD)),
                  child: const Text('Message'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onShareGeneric,
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApplyCodeCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onApply;
  final bool applied;
  final bool isApplying;
  final String title;
  final String subtitle;
  final String placeholder;
  final String buttonText;
  
  const _ApplyCodeCard({
    required this.controller,
    required this.onApply,
    required this.applied,
    required this.title,
    required this.subtitle,
    required this.placeholder,
    required this.buttonText,
    this.isApplying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: !applied && !isApplying,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: placeholder,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: (applied || isApplying) ? null : onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E5EFD),
                shape: const StadiumBorder(),
              ),
              child: isApplying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(applied ? 'Code Applied ✓' : buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF7E5EFD),
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  
  const _StepTile({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFF3F0FF),
            child: Text(step, style: const TextStyle(color: Color(0xFF7E5EFD), fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


