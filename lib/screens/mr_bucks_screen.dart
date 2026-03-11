import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service_bypass.dart';
import '../services/redemption_service.dart';
import '../services/rewards_service.dart';
import '../services/referral_service.dart';
import '../providers/user_provider.dart';
import 'package:flutter/services.dart';
import '../widgets/upload_bottom_sheet.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'refer_earn_screen.dart';
import 'receipt_details_screen.dart';
import 'track_distance_screen.dart';
import '../providers/receipt_provider.dart';

const LinearGradient _mrBucksGradient = LinearGradient(
  colors: [Color(0xFFFF9500), Color(0xFFFF7300)],
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
);

class MrBucksScreen extends StatefulWidget {
  const MrBucksScreen({super.key});

  @override
  State<MrBucksScreen> createState() => _MrBucksScreenState();
}

class _MrBucksScreenState extends State<MrBucksScreen> with WidgetsBindingObserver {
  // Redemption state
  int? _selectedPoints;
  String? _selectedPartner;
  // Rewards service removed; balance optionally local until API integrated
  int? _balance = 0;
  bool _loadingSummary = false;
  bool _loadingCatalog = false;
  final int _limit = 10;
  int _offset = 0;
  String? _redemptionType; // 'gift' or 'donation'
  
  // Catalog data
  String? _currency;
  List<Map<String, dynamic>> _giftCards = [];
  List<Map<String, dynamic>> _donations = [];
  List<Map<String, dynamic>> _pointOptions = [];
  Map<String, dynamic>? _redemptionRules;

  int get _availablePoints => _balance ?? 0;
  List<Map<String, dynamic>> _summaryTransactions = const [];

  // Redemption history state
  List<Map<String, dynamic>> _redemptionHistory = [];
  bool _loadingRedemptionHistory = false;
  int _selectedHistoryTab = 0; // 0 = Points History, 1 = Redemption History

  // Terms & Conditions state
  bool _termsAccepted = false;
  bool _checkingTermsStatus = true;
  String? _termsText;

  // Earn rules state
  List<Map<String, dynamic>> _earnRules = [];
  bool _loadingEarnRules = false;
  String? _earnRulesError;

  // Coin shower animation state
  int? _previousBalance;
  bool _showCoinShower = false;
  bool _isScreenVisible = false;
  String? _lastSeenTransactionId; // Track the most recent transaction ID we've seen

  // Referral copy state
  String? _referralCode;
  String _referralCardDescription = '';
  String _referralBannerHeadline = '';
  bool _loadingReferralCopy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLastSeenTransactionId();
      _checkTermsStatus();
      _fetchEarnRules();
      _loadReferralCopy();
    });
  }

  /// Load the last seen transaction ID from SharedPreferences
  Future<void> _loadLastSeenTransactionId() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId;
      if (userId == null || userId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final lastSeenId = prefs.getString('mr_bucks_last_transaction_$userId');
      if (lastSeenId != null && lastSeenId.isNotEmpty) {
        setState(() {
          _lastSeenTransactionId = lastSeenId;
        });
      }
    } catch (e) {
      debugPrint('Error loading last seen transaction ID: $e');
    }
  }

  /// Save the last seen transaction ID to SharedPreferences
  Future<void> _saveLastSeenTransactionId(String transactionId) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId;
      if (userId == null || userId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mr_bucks_last_transaction_$userId', transactionId);
      setState(() {
        _lastSeenTransactionId = transactionId;
      });
    } catch (e) {
      debugPrint('Error saving last seen transaction ID: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if screen is visible and refresh if needed
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      if (!_isScreenVisible) {
        _isScreenVisible = true;
        // Refresh summary when screen becomes visible to check for new points
        // The _fetchSummary method will automatically detect new transactions and show animation
        if (_termsAccepted && !_loadingSummary) {
          _fetchSummary();
        }
      }
    } else {
      _isScreenVisible = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh summary when app resumes to check for new points
      // The _fetchSummary method will automatically detect new transactions and show animation
      if (_termsAccepted && !_loadingSummary && mounted && ModalRoute.of(context)?.isCurrent == true) {
        _fetchSummary();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('MR Bucks'),
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
      body: Stack(
        children: [
          _checkingTermsStatus
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
                  ),
                )
              : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: const [
                  Text(
                    'My Rewards',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7E5EFD),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Earn points and unlock amazing coupons!',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                gradient: _mrBucksGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7300).withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Your Points Balance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.25),
                          offset: const Offset(0, 1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    height: 68,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                          Image.asset(
                            'assets/coin.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 10),
                      _loadingSummary
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              _formatPoints(_availablePoints),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                height: 1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.35),
                                    offset: const Offset(0, 3),
                                    blurRadius: 8,
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
            ),
            const SizedBox(height: 16),
            // Recent activity removed per API scope; summary only.
            const SizedBox(height: 12),
            _ReferEarnCallout(
              onTap: _openReferEarn,
              referralCode: _referralCode,
              cardDescription: _referralCardDescription,
              bannerHeadline: _referralBannerHeadline,
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Select Points to Redeem',
              trailing: IconButton(
                icon: const Icon(Icons.history, color: Color(0xFF7E5EFD)),
                onPressed: () => _showRedemptionHistoryDialog(),
                tooltip: 'View Redemption History',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _pointOptions.map((option) {
                final int pts = option['points'] ?? 0;
                final num apiAmount = option['amount'] ?? 0;
                final bool selected = _selectedPoints == pts;
                final currency = _currency ?? 'USD';
                final String amountStr = currency == 'INR' 
                    ? '₹${apiAmount.toStringAsFixed(0)}'
                    : '\$${apiAmount.toStringAsFixed(currency == 'USD' ? 0 : 2)}';
                final bool affordable = _availablePoints >= pts;
                final Color borderColor = selected
                    ? const Color(0xFF7E5EFD)
                    : Colors.black12;
                final double borderWidth = selected ? 2 : 1;
                final Widget chip = Container(
                    width: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: borderWidth),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '${_formatPoints(pts)}  = $amountStr',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: selected ? const Color(0xFF7E5EFD) : Colors.black87,
                      ),
                    ),
                  );
                return Opacity(
                  opacity: affordable ? 1.0 : 0.4,
                  child: IgnorePointer(
                    ignoring: !affordable,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPoints = pts),
                      child: chip,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            _SectionHeader(title: 'Select Redemption Type'),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _redemptionType = 'gift'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _redemptionType == 'gift' ? const Color(0xFF7E5EFD) : Colors.black12, width: 2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('🎁', style: TextStyle(fontSize: 24)),
                            SizedBox(height: 8),
                            Text('Gift Card', style: TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _redemptionType = 'donation'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _redemptionType == 'donation' ? const Color(0xFF7E5EFD) : Colors.black12, width: 2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('❤️', style: TextStyle(fontSize: 24)),
                            SizedBox(height: 8),
                            Text('Donate', style: TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_redemptionType != null) Builder(builder: (context) {
              final partners = _redemptionType == 'donation' ? _donations : _giftCards;
              if (partners.isEmpty) {
                return _loadingCatalog
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const SizedBox.shrink();
              }
              
              // Check if selected partner still exists in the list
              final partnerNames = partners.map((p) => p['name'] as String? ?? '').toList();
              if (_selectedPartner == null || !partnerNames.contains(_selectedPartner)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && partners.isNotEmpty) {
                    final firstName = partners.first['name'] as String? ?? '';
                    setState(() => _selectedPartner = firstName);
                  }
                });
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_redemptionType == 'donation' ? 'Select Donation Partner' : 'Select Gift Card Partner', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _PartnersGrid(
                    partners: partners,
                    selected: _selectedPartner ?? '',
                    onSelected: (v) => setState(() => _selectedPartner = v),
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),
            _GradientButton(
              label: _redemptionType == 'donation' ? 'Continue to Donate' : 'Continue to Redemption',
              onPressed: (_redemptionType == null || _selectedPartner == null)
                  ? null
                  : () {
                      if (_selectedPoints == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select points to redeem')),
                        );
                        return;
                      }
                      _openRedemptionDialog();
                    },
            ),
            const SizedBox(height: 16),
            _GradientButton(
              label: 'Start Earning',
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
              },
            ),
            const SizedBox(height: 12),
            _SectionHeader(title: 'How to Earn MR Bucks'),
            const SizedBox(height: 8),
            _buildEarnRulesSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
          if (_showCoinShower)
            CoinShowerWidget(
              onComplete: () {
                setState(() {
                  _showCoinShower = false;
                });
              },
            ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentRoute: 'mr_bucks',
        userId: Provider.of<UserProvider>(context, listen: false).userId ?? '',
        token: Provider.of<UserProvider>(context, listen: false).token ?? '',
        onUploadTap: () {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final userId = userProvider.userId ?? '';
          final country = userProvider.country;
          UploadSheet.show(
            context,
            country: country,
            onAction: (action) async {
              switch (action) {
                case UploadAction.camera:
                  await _handleUploadFromHere(context, userId, source: ImageSource.camera);
                  break;
                case UploadAction.gallery:
                  await _handleUploadFromHere(context, userId, source: ImageSource.gallery);
                  break;
                case UploadAction.manual:
                  await _openManualReceipt(context, userId);
                  break;
                case UploadAction.trackDistance:
                  await _openTrackDistance(context, userId);
                  break;
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _handleUploadFromHere(BuildContext context, String userId, {required ImageSource source}) async {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    receiptProvider.setUserId(userId);

    final receiptData = await receiptProvider.uploadAndProcessReceipt(source);
    if (receiptData == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptDetailsScreen(
          receipt: receiptData,
          imageUrl: receiptData['decryptedImageUrl'] ?? receiptData['imageUrl'] ?? '',
          userId: userId,
          imageId: (receiptData['imageId']?.toString()) ?? '',
          isNewReceipt: true,
          isPdf: false,
        ),
      ),
    );
  }

  Future<void> _openManualReceipt(BuildContext context, String userId) async {
    final emptyReceipt = {
      'merchant': '',
      'receiptDate': DateTime.now().toIso8601String(),
      'amount': '',
      'category': '',
    };

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptDetailsScreen(
          receipt: emptyReceipt,
          imageUrl: '',
          userId: userId,
          imageId: '',
          isNewReceipt: true,
          isPdf: false,
          isManualReceipt: true,
        ),
      ),
    );
  }

  Future<void> _openTrackDistance(BuildContext context, String userId) async {
    final token = Provider.of<UserProvider>(context, listen: false).token ?? '';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackDistanceScreen(
          userId: userId,
          token: token,
        ),
      ),
    );
  }

}

class _StatCard extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.color,
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _EarnTile extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final String title;
  final String subtitle;
  final String points;
  final Color color;

  const _EarnTile({
    this.icon,
    this.emoji,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: emoji != null
              ? Text(emoji!, style: const TextStyle(fontSize: 20))
              : Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            points,
            style: const TextStyle(
              color: Color(0xFFF57C00),
              fontWeight: FontWeight.w700,
            ),
          ),
        )
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _GradientButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? _mrBucksGradient : null,
          color: enabled ? null : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(26),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF7300).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            foregroundColor: Colors.white,
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferEarnCallout extends StatelessWidget {
  final VoidCallback onTap;
  final String? referralCode;
  final String cardDescription;
  final String bannerHeadline;
  
  const _ReferEarnCallout({
    required this.onTap,
    this.referralCode,
    required this.cardDescription,
    required this.bannerHeadline,
  });

  Future<void> _copyReferralCode(BuildContext context) async {
    if (referralCode == null || referralCode!.isEmpty) return;
    
    await Clipboard.setData(ClipboardData(text: referralCode!));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Referral code copied to clipboard!'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF7E5EFD),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 18,
              bottom: 18,
              child: Container(
                width: 8,
                decoration: const BoxDecoration(
                  gradient: _mrBucksGradient,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.group, color: Color(0xFFFF7300), size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (bannerHeadline.isNotEmpty)
                          Text(
                            bannerHeadline,
                            style: const TextStyle(
                              color: Colors.black54,
                            ),
                          ),
                        if (bannerHeadline.isNotEmpty && cardDescription.isNotEmpty)
                          const SizedBox(height: 4),
                        if (cardDescription.isNotEmpty)
                          Text(
                            cardDescription,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        // Display referral code if available
                        if (referralCode != null && referralCode!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _copyReferralCode(context),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF7E5EFD).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    referralCode!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF7E5EFD),
                                      fontFamily: 'monospace',
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.copy,
                                    size: 16,
                                    color: Color(0xFF7E5EFD),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple partners grid with selection highlight
class _PartnersGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final List<Map<String, dynamic>> partners;

  const _PartnersGrid({required this.selected, required this.onSelected, required this.partners});

  String _formatPartnerName(String name) {
    // Fix specific names
    if (name.toUpperCase() == 'DONATEKART') {
      return 'Donatekart';
    }
    // Return as-is for other names
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: partners.map((partner) {
        final String partnerName = partner['name'] ?? '';
        final String formattedName = _formatPartnerName(partnerName);
        final String logoUrl = partner['logo'] ?? '';
        final bool isSel = partnerName == selected;
        
        return GestureDetector(
          onTap: () => onSelected(partnerName),
          child: Container(
            width: (MediaQuery.of(context).size.width - 16 * 2 - 14 * 2) / 3,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSel ? const Color(0xFF7E5EFD) : Colors.black12, width: isSel ? 2 : 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 68,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: logoUrl.isNotEmpty
                        ? _NetworkPartnerLogo(url: logoUrl, fit: BoxFit.contain)
                        : Icon(
                            Icons.image_not_supported,
                            color: Colors.grey.shade400,
                            size: 32,
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: Center(
                    child: Text(
                      formattedName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Top-level helper usable across widgets
String _formatIsoStr(String iso) {
  try {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}

class _LedgerTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _LedgerTile({required this.entry});

  Color _pointsColor(int p) => p >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
  IconData _iconFor(String type, int points) {
    if (type.toUpperCase() == 'REDEMPTION' || points < 0) return Icons.redeem;
    return Icons.add_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final int points = (entry['points'] ?? 0) is int
        ? entry['points'] as int
        : int.tryParse('${entry['points'] ?? '0'}') ?? 0;
    final String desc = '${entry['description'] ?? ''}';
    final String type = '${entry['entryType'] ?? ''}';
    final String createdAt = '${entry['createdAt'] ?? ''}';
    final String subtitle = createdAt.isNotEmpty ? _formatIsoStr(createdAt) : type;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: Icon(_iconFor(type, points), color: Colors.grey.shade700),
        ),
        title: Text(desc.isNotEmpty ? desc : type, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Text(
          points >= 0 ? '+$points' : '$points',
          style: TextStyle(fontWeight: FontWeight.w800, color: _pointsColor(points)),
        ),
      ),
    );
  }
}

extension on _MrBucksScreenState {
  Future<void> _fetchCatalog() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId;
      final token = userProvider.token;
      if (userId == null || userId.isEmpty) return;

      setState(() => _loadingCatalog = true);

      final catalog = await RedemptionService.getCatalog(userId, token);

      if (!mounted) return;

      if (catalog != null) {
        // Parse gift cards (now with id, name, and logo)
        final List<dynamic> giftCardsData = (catalog['giftCards'] as List<dynamic>?) ?? [];
        final giftCardsList = giftCardsData
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        
        // Parse donations (now with id, name, and logo)
        final List<dynamic> donationsData = (catalog['donations'] as List<dynamic>?) ?? [];
        final donationsList = donationsData
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        
        // Parse redemption rules
        final redemptionRules = catalog['redemptionRules'] as Map<String, dynamic>?;
        final List<dynamic> pointOptionsData = (redemptionRules?['pointOptions'] as List<dynamic>?) ?? [];
        final pointOptionsList = pointOptionsData
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        
        setState(() {
          _currency = catalog['currency'] as String? ?? 'USD';
          _giftCards = giftCardsList;
          _donations = donationsList;
          _pointOptions = pointOptionsList;
          _redemptionRules = redemptionRules;
          _loadingCatalog = false;
        });
      } else {
        // Fallback to default values if API fails
        setState(() {
          _currency = userProvider.effectiveCurrencyCode;
          _giftCards = [];
          _donations = [];
          _pointOptions = [];
          _loadingCatalog = false;
        });
      }
    } catch (e) {
      debugPrint('Catalog fetch error: $e');
      if (!mounted) return;
      // Fallback to default values on error
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      setState(() {
        _currency = userProvider.effectiveCurrencyCode;
        _giftCards = [];
        _donations = [];
        _pointOptions = [];
        _loadingCatalog = false;
      });
    }
  }

  Future<void> _fetchEarnRules() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token;

      setState(() {
        _loadingEarnRules = true;
        _earnRulesError = null;
      });

      final response = await RewardsService.getEarnRules(token: token);

      if (!mounted) return;

      if (response != null && response['success'] == true) {
        // Parse the response structure: { success: true, data: [...] }
        final data = response['data'];
        List<dynamic> rulesList = [];
        
        if (data is List) {
          rulesList = data;
        } else if (data is Map) {
          rulesList = data['earnRules'] ?? data['rules'] ?? [];
        }

        // Filter only active rules and sort by priority (higher priority first)
        final earnRulesList = rulesList
            .where((rule) {
              final ruleMap = rule as Map<String, dynamic>;
              return ruleMap['isActive'] == true;
            })
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList()
          ..sort((a, b) {
            final priorityA = a['priority'] as int? ?? 0;
            final priorityB = b['priority'] as int? ?? 0;
            return priorityB.compareTo(priorityA); // Higher priority first
          });

        setState(() {
          _earnRules = earnRulesList;
          _loadingEarnRules = false;
        });
      } else {
        setState(() {
          _loadingEarnRules = false;
          _earnRulesError = 'Failed to load earn rules';
        });
      }
    } catch (e) {
      debugPrint('Error fetching earn rules: $e');
      if (!mounted) return;
      setState(() {
        _loadingEarnRules = false;
        _earnRulesError = 'Error loading earn rules';
      });
    }
  }

  Future<void> _loadReferralCopy() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token;
      final userId = userProvider.userId;

      if (token == null || token.isEmpty) return;

      setState(() {
        _loadingReferralCopy = true;
      });

      // Fetch referral copy with userId to get referral code
      final response = await ReferralService.getReferralCopy(
        token,
        userId: userId,
      );

      if (!mounted) return;

      if (response != null && response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        final referrer = data['referrer'] as Map<String, dynamic>? ?? {};

        setState(() {
          // Update text content from API
          _referralBannerHeadline = referrer['bannerHeadline'] as String? ?? '';
          _referralCardDescription = referrer['cardDescription'] as String? ?? '';
          
          // Get referral code if available
          final referralCodeFromApi = referrer['referralCode'] as String?;
          if (referralCodeFromApi != null && referralCodeFromApi.isNotEmpty) {
            _referralCode = referralCodeFromApi.toUpperCase();
          }
          
          _loadingReferralCopy = false;
        });
      } else {
        setState(() {
          _loadingReferralCopy = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading referral copy: $e');
      if (!mounted) return;
      setState(() {
        _loadingReferralCopy = false;
      });
    }
  }

  Future<void> _fetchSummary() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId;
      if (userId == null || userId.isEmpty) return;

      setState(() => _loadingSummary = true);

      final resp = await ApiService.get(
        '/points/users/$userId/summary',
        queryParameters: {
          'limit': _limit.toString(),
          'offset': _offset.toString(),
        },
      );

      if (resp.statusCode == 200) {
        final Map<String, dynamic> parsedJson = json.decode(resp.body) is Map
            ? Map<String, dynamic>.from(json.decode(resp.body) as Map)
            : <String, dynamic>{};
        final data = Map<String, dynamic>.from(parsedJson['data'] ?? {});
        final int fetchedBalance = (data['balance'] ?? 0) is int
            ? data['balance'] as int
            : int.tryParse('${data['balance'] ?? '0'}') ?? 0;
        final List<dynamic> tx = (data['transactions'] ?? []) as List<dynamic>;
        final txList = tx.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();

        if (!mounted) return;
        
        // Check for new AWARD transactions (points earned)
        // Transactions are sorted by createdAt (most recent first)
        bool pointsEarned = false;
        String? newAwardTransactionId;
        
        if (txList.isNotEmpty) {
          // Get the most recent transaction
          final mostRecentTx = txList.first;
          final txId = mostRecentTx['id'] as String?;
          final entryType = mostRecentTx['entryType'] as String?;
          final points = (mostRecentTx['points'] ?? 0) is int
              ? mostRecentTx['points'] as int
              : int.tryParse('${mostRecentTx['points'] ?? '0'}') ?? 0;
          
          // Check if this is a new AWARD transaction we haven't seen before
          if (txId != null && 
              txId.isNotEmpty && 
              entryType == 'AWARD' && 
              points > 0 &&
              txId != _lastSeenTransactionId) {
            // This is a new award transaction!
            pointsEarned = true;
            newAwardTransactionId = txId;
          }
          
          // Update last seen transaction ID to the most recent one (even if not an award)
          // This ensures we don't show animation for old transactions
          if (txId != null && txId.isNotEmpty && txId != _lastSeenTransactionId) {
            _saveLastSeenTransactionId(txId);
          }
        }
        
        // Also check if balance increased as a fallback (in case transaction tracking fails)
        final int? oldBalance = _previousBalance;
        final bool balanceIncreased = oldBalance != null && fetchedBalance > oldBalance;
        
        // Show coin shower if we detected a new award OR balance increased significantly
        // (Use balance as fallback, but prefer transaction-based detection)
        final bool shouldShowAnimation = pointsEarned || (balanceIncreased && _lastSeenTransactionId == null);
        
        setState(() {
          _balance = fetchedBalance;
          // Optional: show recent activity again from summary
          _summaryTransactions = txList;
          _loadingSummary = false;
          
          // Update previous balance
          if (oldBalance == null) {
            // First load - set previous balance without triggering animation
            _previousBalance = fetchedBalance;
          } else {
            _previousBalance = fetchedBalance;
          }
          
          // Trigger coin shower if points were earned
          if (shouldShowAnimation) {
            _showCoinShower = true;
          }
        });
      } else {
        if (!mounted) return;
        setState(() => _loadingSummary = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSummary = false);
    }
  }

  // Ledger fetching removed per API scope; summary only.

  Future<void> _fetchRedemptionHistory() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId;
      if (userId == null || userId.isEmpty) return;

      setState(() => _loadingRedemptionHistory = true);

      final resp = await ApiService.get(
        '/redemptions/users/$userId/redemptions',
        queryParameters: {
          'limit': '50',
          'offset': '0',
        },
      );

      debugPrint('Redemption History API Response: ${resp.statusCode}');
      debugPrint('Redemption History API Body: ${resp.body}');

      if (resp.statusCode == 200) {
        final Map<String, dynamic> parsedJson = json.decode(resp.body) is Map
            ? Map<String, dynamic>.from(json.decode(resp.body) as Map)
            : <String, dynamic>{};
        final data = Map<String, dynamic>.from(parsedJson['data'] ?? {});
        final List<dynamic> records = (data['records'] ?? []) as List<dynamic>;
        final redemptionList = records.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();

        if (!mounted) return;
        setState(() {
          _redemptionHistory = redemptionList;
          _loadingRedemptionHistory = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loadingRedemptionHistory = false);
      }
    } catch (e) {
      debugPrint('Redemption History API Exception: $e');
      if (!mounted) return;
      setState(() => _loadingRedemptionHistory = false);
    }
  }

  String _formatPoints(int pts) {
    final s = pts.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final fromEnd = s.length - i - 1;
      if (fromEnd % 3 == 0 && i != s.length - 1) buf.write(',');
    }
    return '$buf';
  }

  String _formatIso(String iso) {
    try {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return iso;
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  // Get partner data (including logo URL) from catalog
  Map<String, dynamic>? _getPartnerData(String partnerName) {
    final partners = _redemptionType == 'donation' ? _donations : _giftCards;
    try {
      return partners.firstWhere(
        (p) => (p['name'] as String? ?? '').toLowerCase() == partnerName.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }


  // Terms & Conditions methods
  Future<void> _checkTermsStatus() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId;
      if (userId == null || userId.isEmpty) {
        setState(() => _checkingTermsStatus = false);
        return;
      }

      final resp = await ApiService.get('/points/users/$userId/terms-status');

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final Map<String, dynamic> parsedJson = json.decode(resp.body) is Map
            ? Map<String, dynamic>.from(json.decode(resp.body) as Map)
            : <String, dynamic>{};
        
        // API returns: { "success": true, "data": { "termsAccepted": true } }
        final data = Map<String, dynamic>.from(parsedJson['data'] ?? {});
        final bool accepted = data['termsAccepted'] == true;
        
        setState(() {
          _termsAccepted = accepted;
          _checkingTermsStatus = false;
        });

        if (!accepted) {
          // Show terms dialog
          await _fetchAndShowTermsDialog();
        } else {
          // Load MR Bucks data
          _fetchSummary();
          _fetchCatalog();
          _fetchRedemptionHistory();
          _fetchEarnRules();
        }
      } else {
        setState(() => _checkingTermsStatus = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingTermsStatus = false);
    }
  }

  Future<void> _fetchAndShowTermsDialog() async {
    try {
      // Fetch terms content
      final resp = await ApiService.get('/points/terms');

      if (!mounted) return;

      String? termsText;
      if (resp.statusCode == 200) {
        // API returns: { "success": true, "data": { "terms": { "text": "..." } } }
        try {
          final Map<String, dynamic> parsedJson = json.decode(resp.body) is Map
              ? Map<String, dynamic>.from(json.decode(resp.body) as Map)
              : <String, dynamic>{};
          
          final data = Map<String, dynamic>.from(parsedJson['data'] ?? {});
          final terms = data['terms'] is Map ? Map<String, dynamic>.from(data['terms'] as Map) : null;
          termsText = terms?['text'] as String?;
        } catch (_) {
          termsText = null;
        }
      }

      setState(() => _termsText = termsText);

      if (!mounted) return;
      
      await _showTermsDialog();
    } catch (_) {
      if (mounted) {
        setState(() => _termsText = null);
        await _showTermsDialog();
      }
    }
  }

  Future<void> _showTermsDialog() async {
    final scrollController = ScrollController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Function to check if button should be enabled based on scroll position
            bool getIsScrolledToBottom() {
              if (!scrollController.hasClients) return false;
              
              final maxScroll = scrollController.position.maxScrollExtent;
              final currentScroll = scrollController.position.pixels;
              
              // If content doesn't require scrolling (maxScrollExtent is 0 or very small)
              if (maxScroll <= 5) {
                return true; // All content visible, enable button
              }
              
              // Content requires scrolling - check if user scrolled 90%
              final threshold = maxScroll * 0.9;
              return currentScroll >= threshold;
            }

            // Force rebuild when scroll changes
            void onScrollChanged() {
              setState(() {});
            }

            // Check scroll state after first frame when scroll controller is attached
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (scrollController.hasClients) {
                setState(() {});
              }
            });

            scrollController.addListener(onScrollChanged);
            
            final isScrolledToBottom = getIsScrolledToBottom();

            return PopScope(
              canPop: false,
              onPopInvoked: (didPop) async {
                if (!didPop) {
                  Navigator.of(ctx).pop();
                  // Navigate to dashboard
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
                  }
                }
              },
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(this.context).size.height * 0.65,
                  maxWidth: 500,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFF7E5EFD),
                      ),
                      child: const Text(
                        'Please review our terms before proceeding',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Scroll indicator at top
                    if (!isScrolledToBottom)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.arrow_downward, size: 16, color: Color(0xFF7E5EFD)),
                            SizedBox(width: 6),
                            Text(
                              'Scroll to read all terms',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7E5EFD),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Content
                    Flexible(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          // Force rebuild when scroll metrics are updated (e.g., when content is laid out)
                          if (notification is ScrollUpdateNotification || notification is ScrollMetricsNotification) {
                            onScrollChanged();
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          child: _buildTermsContent(),
                        ),
                      ),
                    ),
                    // Footer with button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isScrolledToBottom 
                                ? const Color(0xFF7E5EFD) 
                                : Colors.grey,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: isScrolledToBottom
                              ? () async {
                                  Navigator.of(ctx).pop();
                                  await _acceptTerms();
                                }
                              : null,
                          child: const Text(
                            'I Agree & Accept',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            );
          },
        );
      },
    );
  }

  Widget _buildTermsContent() {
    if (_termsText == null || _termsText!.isEmpty) {
      return const Text(
        'MR Bucks Terms & Conditions\n\nPlease accept our terms to continue.\n\nFor full terms, contact support@managereceipt.com',
        style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
      );
    }

    // Display the text with proper line breaks and URL detection
    return _buildFormattedTermsText(_termsText!);
  }

  Widget _buildFormattedTermsText(String text) {
    // Split text into paragraphs
    final paragraphs = text.split('\n\n');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        if (paragraph.trim().isEmpty) {
          return const SizedBox(height: 10);
        }
        
        // Check if paragraph contains a URL
        final urlRegex = RegExp(r'(https?://[^\s]+)');
        final hasUrl = urlRegex.hasMatch(paragraph);
        
        if (hasUrl) {
          // Parse text with URL
          final parts = <TextSpan>[];
          final matches = urlRegex.allMatches(paragraph);
          int lastIndex = 0;
          
          for (final match in matches) {
            // Add text before URL
            if (match.start > lastIndex) {
              parts.add(TextSpan(
                text: paragraph.substring(lastIndex, match.start),
                style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
              ));
            }
            
            // Add clickable URL
            parts.add(TextSpan(
              text: match.group(0),
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF7E5EFD),
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  final url = match.group(0);
                  if (url != null) {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
            ));
            
            lastIndex = match.end;
          }
          
          // Add remaining text
          if (lastIndex < paragraph.length) {
            parts.add(TextSpan(
              text: paragraph.substring(lastIndex),
              style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
            ));
          }
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RichText(
              text: TextSpan(children: parts),
            ),
          );
        } else {
          // Regular text paragraph
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              paragraph,
              style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildSection({required String icon, required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF7E5EFD)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
      ],
    );
  }

  Widget _buildSectionTitle({required String icon, required String title}) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF7E5EFD)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubSection({required String title, required String description}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
      ],
    );
  }

  Widget _buildSubSectionWithBullets({required String title, required String description, required List<String> bulletPoints}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
        ],
        const SizedBox(height: 4),
        ..._buildBulletList(bulletPoints),
      ],
    );
  }

  List<Widget> _buildBulletList(List<String> items) {
    return items.map((item) => Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14, height: 1.5)),
          Expanded(
            child: Text(item, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
          ),
        ],
      ),
    )).toList();
  }

  Widget _buildKeyValue(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
          children: [
            TextSpan(text: '$key ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptTerms() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId;
      if (userId == null || userId.isEmpty) return;

      final resp = await ApiService.post(
        '/points/users/$userId/accept-terms',
        body: {},
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        // API returns: { "success": true, "message": "...", "data": { "termsAccepted": true, "terms": "..." } }
        final Map<String, dynamic> parsedJson = json.decode(resp.body) is Map
            ? Map<String, dynamic>.from(json.decode(resp.body) as Map)
            : <String, dynamic>{};
        
        final data = Map<String, dynamic>.from(parsedJson['data'] ?? {});
        final bool accepted = data['termsAccepted'] == true;
        
        setState(() => _termsAccepted = accepted);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terms accepted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Load MR Bucks data
        _fetchSummary();
        _fetchCatalog();
        _fetchRedemptionHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept terms. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRedemptionHistoryDialog() {
    // Only fetch redemption history if not already loaded
    if (_redemptionHistory.isEmpty && !_loadingRedemptionHistory) {
      _fetchRedemptionHistory();
    }
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isEmpty = (_selectedHistoryTab == 0 && _summaryTransactions.isEmpty) ||
                (_selectedHistoryTab == 1 && _redemptionHistory.isEmpty && !_loadingRedemptionHistory);
            
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: isEmpty 
                      ? MediaQuery.of(context).size.height * 0.4
                      : MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E5EFD),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history, color: Colors.white),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(ctx).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Tabs
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  _selectedHistoryTab = 0;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedHistoryTab == 0
                                      ? const Color(0xFF7E5EFD)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Text(
                                  'Points History',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedHistoryTab == 0
                                        ? Colors.white
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  _selectedHistoryTab = 1;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedHistoryTab == 1
                                      ? const Color(0xFF7E5EFD)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Text(
                                  'Redemption History',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedHistoryTab == 1
                                        ? Colors.white
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Flexible(
                      child: _selectedHistoryTab == 0
                          ? _buildPointsHistoryContent()
                          : _buildRedemptionHistoryContent(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEarnRulesSection() {
    if (_loadingEarnRules) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E5EFD)),
          ),
        ),
      );
    }

    if (_earnRulesError != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.grey, size: 48),
              const SizedBox(height: 12),
              Text(
                _earnRulesError!,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _fetchEarnRules,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_earnRules.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No earn rules available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: _earnRules.map((rule) {
        return _buildEarnTileFromRule(rule);
      }).toList(),
    );
  }

  Widget _buildEarnTileFromRule(Map<String, dynamic> rule) {
    // Extract data from API response structure
    final name = rule['name'] ?? '';
    final description = rule['description'] ?? '';
    final pointsObj = rule['points'] as Map<String, dynamic>?;
    final pointsMin = pointsObj?['min'] ?? 0;
    final pointsMax = pointsObj?['max'] ?? 0;
    final ruleType = rule['ruleType'] as String? ?? '';
    final metadata = rule['metadata'] as Map<String, dynamic>?;
    
    // Format points - use min if min == max, otherwise show range
    String pointsText;
    if (pointsMin == pointsMax) {
      pointsText = '+$pointsMin pts';
    } else {
      pointsText = '+$pointsMin-$pointsMax pts';
    }

    // Get emoji/icon based on rule type and name
    String? emoji;
    IconData? icon;
    Color color;
    
    // Map rule types and names to appropriate icons/colors
    final nameLower = name.toLowerCase();
    if (nameLower.contains('preferred vendor') || nameLower.contains('vendor')) {
      emoji = '⭐';
      color = Colors.amber.shade800;
    } else if (nameLower.contains('email')) {
      emoji = '📧';
      color = Colors.indigo;
    } else if (nameLower.contains('refer') || nameLower.contains('referral')) {
      emoji = '👥';
      color = Colors.pink;
    } else if (nameLower.contains('scan') || nameLower.contains('manual') || nameLower.contains('upload receipt')) {
      emoji = '📸';
      color = const Color(0xFF7E5EFD);
    } else if (nameLower.contains('document wallet') || nameLower.contains('doc wallet')) {
      emoji = '📁';
      color = Colors.deepOrange;
    } else if (nameLower.contains('expense report')) {
      emoji = '📊';
      color = Colors.blue;
    } else if (nameLower.contains('tax report')) {
      emoji = '📋';
      color = Colors.teal;
    } else if (nameLower.contains('custom report')) {
      emoji = '📈';
      color = Colors.purple;
    } else if (nameLower.contains('terms')) {
      emoji = '✅';
      color = Colors.green;
    } else {
      // Default fallback
      icon = Icons.stars;
      color = const Color(0xFF7E5EFD);
    }

    return _EarnTile(
      emoji: emoji,
      icon: icon,
      title: name,
      subtitle: description,
      points: pointsText,
      color: color,
    );
  }

  Color _parseColorFromHex(String hexString) {
    try {
      // Remove # if present
      String hex = hexString.replaceAll('#', '');
      
      // Handle 3-digit hex
      if (hex.length == 3) {
        hex = hex.split('').map((c) => '$c$c').join();
      }
      
      // Add alpha if missing
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      debugPrint('Error parsing color: $hexString, $e');
      return const Color(0xFF7E5EFD); // Default purple
    }
  }

  IconData? _getIconFromName(String iconName) {
    // Map common icon names to Flutter icons
    final iconMap = {
      'camera': Icons.camera_alt,
      'email': Icons.email,
      'star': Icons.star,
      'folder': Icons.folder,
      'chart': Icons.bar_chart,
      'file': Icons.description,
      'trending': Icons.trending_up,
      'people': Icons.people,
      'receipt': Icons.receipt,
      'upload': Icons.cloud_upload,
      'wallet': Icons.account_balance_wallet,
      'report': Icons.assessment,
      'export': Icons.file_download,
    };
    
    return iconMap[iconName.toLowerCase()];
  }

  void _openReferEarn() {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId ?? '';
      final token = userProvider.token ?? '';
      if (userId.isEmpty || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in to access Refer & Earn.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReferEarnScreen(userId: userId, token: token),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open Refer & Earn right now.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPointsHistoryContent() {
    // Use already loaded summary transactions - no need to fetch again
    if (_summaryTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        constraints: const BoxConstraints(
          minHeight: 150,
          maxHeight: 200,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No points history yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Start earning points to see your history here!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black38),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: _summaryTransactions.length,
      itemBuilder: (context, index) {
        return _PointsHistoryTile(transaction: _summaryTransactions[index]);
      },
    );
  }

  Widget _buildRedemptionHistoryContent() {
    if (_loadingRedemptionHistory) {
      return Container(
        constraints: const BoxConstraints(
          minHeight: 150,
          maxHeight: 200,
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_redemptionHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        constraints: const BoxConstraints(
          minHeight: 150,
          maxHeight: 200,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No redemption history yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Start redeeming your points to see your history here!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black38),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: _redemptionHistory.length,
      itemBuilder: (context, index) {
        return _RedemptionHistoryTile(redemption: _redemptionHistory[index]);
      },
    );
  }

  Future<void> _openRedemptionDialog() async {
    final selectedPts = _selectedPoints;
    if (selectedPts == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select points to redeem')),
        );
      }
      return;
    }
    final user = Provider.of<UserProvider>(context, listen: false);
    final userId = user.userId;
    final token = user.token;
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
      }
      return;
    }

    final nameController = TextEditingController(text: user.effectiveUsername);
    final emailController = TextEditingController(text: user.effectiveEmail);
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    final currency = _currency ?? 'USD';
    final amount = RedemptionService.calculateAmount(selectedPts, currency);
    final amountStr = currency == 'INR' 
        ? '₹${amount.toStringAsFixed(0)}'
        : '\$${amount.toStringAsFixed(currency == 'USD' ? 0 : 2)}';

    await showDialog(
      context: context,
      builder: (ctx) {
        bool otpRequested = false;
        bool sendingOtp = false;
        bool verifyingOtp = false;
        String? redemptionId;
        final otpController = TextEditingController();
        String? dialogMessage;
        String? fullNameError;
        String? emailError;

        String normalizeMessage(String? raw) {
          if (raw == null) return '';
          final message = raw.trim();
          if (message.isEmpty) return '';
          final lower = message.toLowerCase();

          if (lower.contains('full') && lower.contains('name')) {
            if (lower.contains('null') || lower.contains('empty') || lower.contains('required')) {
              return 'Full name is required.';
            }
          }
          if (lower.contains('email')) {
            if (lower.contains('null') || lower.contains('empty') || lower.contains('required')) {
              return 'Email address is required.';
            }
            if (lower.contains('invalid')) {
              return 'Please enter a valid email address.';
            }
          }
          if (lower.contains('otp')) {
            if (lower.contains('not verified')) {
              return 'The OTP you entered is incorrect or has already been used.';
            }
            if (lower.contains('invalid')) {
              return 'The OTP you entered is invalid. Please try again.';
            }
            if (lower.contains('expired')) {
              return 'Your OTP has expired. Please request a new one.';
            }
            if (lower.contains('null') || lower.contains('empty') || lower.contains('required')) {
              return 'OTP is required. Please enter the code sent to your email.';
            }
          }
          if (lower.contains('phone')) {
            if (lower.contains('invalid')) {
              return 'Please enter a valid phone number.';
            }
            if (lower.contains('null') || lower.contains('empty') || lower.contains('required')) {
              return 'Phone number is required.';
            }
          }
          if (lower.contains('address')) {
            if (lower.contains('null') || lower.contains('empty') || lower.contains('required')) {
              return 'Address is required.';
            }
          }
          if (lower.contains('partner') && lower.contains('select')) {
            return 'Please select a redemption partner to continue.';
          }
          if (lower.contains('user not found')) {
            return 'We could not verify your account. Please log in again.';
          }
          if (lower.contains('failed to send otp') || lower.contains('could not send otp')) {
            return 'We could not send the OTP. Please check your details and try again.';
          }
          if (lower.contains('failed to initiate redemption')) {
            return 'We were unable to start your redemption. Please try again later.';
          }
          if (lower.contains('failed to verify otp')) {
            return 'We were unable to verify the OTP. Please request a new code and try again.';
          }

          return message;
        }

        String combineMessages(String primary, List<dynamic>? extras) {
          final messages = <String>[];
          final normalizedPrimary = normalizeMessage(primary);
          if (normalizedPrimary.isNotEmpty) messages.add(normalizedPrimary);
          if (extras != null) {
            for (final extra in extras) {
              final normalized = normalizeMessage('$extra');
              if (normalized.isNotEmpty && !messages.contains(normalized)) {
                messages.add(normalized);
              }
            }
          }
          return messages.join('\n');
        }

        void showMessage(String? message, {bool success = false}) {
          setState(() {
            dialogMessage = normalizeMessage(message);
            if (success) {
              dialogMessage = null;
            }
          });
        }

        Widget buildLabel(String text, {bool required = false}) {
          if (!required) {
            return Text(text, style: const TextStyle(fontWeight: FontWeight.w600));
          }
          return RichText(
            text: TextSpan(
              text: text,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              children: const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                Text(
                  _redemptionType == 'donation' ? 'Complete Donation' : 'Complete Gift Card Redemption',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF7E5EFD)),
                ),
                const SizedBox(height: 8),
                Text(
                  _redemptionType == 'donation' 
                      ? 'Fill in your details to complete your donation'
                      : 'Fill in your details to receive your gift card',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                
                // Selected Partner/Gift Card Info with Amount in one row
                if (_selectedPartner != null) ...[
                  Builder(
                    builder: (context) {
                      final partnerData = _getPartnerData(_selectedPartner!);
                      final logoUrl = partnerData?['logo'] as String? ?? '';
                      
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF7E5EFD).withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            // Left side - Gift Card info
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: logoUrl.isNotEmpty
                                  ? _NetworkPartnerLogo(
                                      url: logoUrl,
                                      fit: BoxFit.contain,
                                    )
                                  : _redemptionType == 'donation'
                                      ? const Icon(Icons.favorite, color: Colors.red, size: 28)
                                      : Icon(
                                          Icons.card_giftcard,
                                          color: Colors.grey.shade400,
                                          size: 28,
                                        ),
                            ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPartner!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _redemptionType == 'donation' ? 'Donation' : 'Gift Card',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7E5EFD),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Right side - Amount
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${_formatPoints(selectedPts)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF7E5EFD),
                              ),
                            ),
                            Text(
                              '= $amountStr',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 14),
                buildLabel('Full Name', required: true),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    border: const OutlineInputBorder(),
                    errorText: fullNameError,
                  ),
                  onChanged: (_) {
                    if (fullNameError != null) {
                      setState(() => fullNameError = null);
                    }
                  },
                ),
                const SizedBox(height: 12),
                buildLabel('Email Address', required: true),
                const SizedBox(height: 6),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !otpRequested,
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    border: const OutlineInputBorder(),
                    errorText: emailError,
                    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    suffixIcon: sendingOtp
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : TextButton(
                            onPressed: otpRequested ? null : () async {
                              if (emailController.text.trim().isEmpty) {
                                setState(() => emailError = 'Email address is required.');
                                showMessage('Please enter your email address.');
                                return;
                              }
                              if (nameController.text.trim().isEmpty) {
                                setState(() => fullNameError = 'Full name is required.');
                                showMessage('Please enter your full name.');
                                return;
                              }
                              if (_selectedPartner == null) {
                                showMessage('Please select a partner to continue.');
                                return;
                              }

                              setState(() {
                                sendingOtp = true;
                                dialogMessage = null;
                                fullNameError = null;
                                emailError = null;
                              });

                              final result = await RedemptionService.initiateRedemption(
                                userId: userId!,
                                type: _redemptionType == 'donation' ? 'DONATION' : 'GIFT_CARD',
                                brandOrOrg: _selectedPartner!,
                                amount: amount,
                                email: emailController.text.trim(),
                                token: token,
                                phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                                fullName: nameController.text.trim(),
                                address: addressController.text.trim().isNotEmpty ? addressController.text.trim() : null,
                              );

                              setState(() => sendingOtp = false);

                              if (result != null && result['redemptionId'] != null) {
                                redemptionId = result['redemptionId'] as String;
                                setState(() => otpRequested = true);
                                showMessage('OTP sent successfully. Please check your email.', success: true);
                              } else {
                                final errorMsg = result?['message'] ?? 'Failed to send OTP';
                                final errors = result?['errors'] as List<dynamic>?;
                                showMessage(combineMessages(errorMsg, errors));
                              }
                            },
                            child: const Text('Send OTP'),
                          ),
                  ),
                  onChanged: (_) {
                    if (emailError != null) {
                      setState(() => emailError = null);
                    }
                  },
                ),
                if (otpRequested) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Enter OTP', border: OutlineInputBorder()),
                    onChanged: (_) {
                      if (dialogMessage != null && dialogMessage!.toLowerCase().contains('otp')) {
                        setState(() => dialogMessage = null);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Phone Number',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Enter your phone number', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                const Text(
                  'Address',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: addressController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter your address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7E5EFD), shape: const StadiumBorder()),
                    onPressed: verifyingOtp ? null : () async {
                      if (emailController.text.trim().isEmpty || nameController.text.trim().isEmpty) {
                        setState(() {
                          fullNameError = nameController.text.trim().isEmpty ? 'Full name is required.' : null;
                          emailError = emailController.text.trim().isEmpty ? 'Email address is required.' : null;
                        });
                        showMessage('Full name and email address are required.');
                        return;
                      }
                      if (!otpRequested || otpController.text.trim().isEmpty) {
                        showMessage(
                          !otpRequested
                              ? 'Please request an OTP and enter it before proceeding.'
                              : 'OTP is required. Please enter the code sent to your email.',
                        );
                        return;
                      }
                      if (redemptionId == null) {
                        showMessage('We could not find your OTP request. Please send OTP again.');
                        return;
                      }

                      setState(() => verifyingOtp = true);

                      final result = await RedemptionService.verifyOtp(
                        userId: userId!,
                        redemptionId: redemptionId!,
                        otp: otpController.text.trim(),
                        token: token,
                        email: emailController.text.trim(),
                      );

                      setState(() => verifyingOtp = false);

                      if (result != null && result['success'] == true) {
                        Navigator.of(ctx).pop();
                        _showSuccess();
                        // Refresh balance
                        _fetchSummary();
                      } else {
                        final errorMsg = result?['message'] ?? 'Failed to verify OTP';
                        final errors = result?['errors'] as List<dynamic>?;
                        showMessage(combineMessages(errorMsg, errors));
                      }
                    },
                    child: verifyingOtp
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Confirm Redemption'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  void _showSuccess() {
    final selectedPts = _selectedPoints ?? 0;
    final currency = _currency ?? 'USD';
    final amount = RedemptionService.calculateAmount(selectedPts, currency);
    final amountStr = currency == 'INR' 
        ? '₹${amount.toStringAsFixed(0)}'
        : '\$${amount.toStringAsFixed(currency == 'USD' ? 0 : 2)}';
    
    final isDonation = _redemptionType == 'donation';
    final message = isDonation
        ? '${_formatPoints(selectedPts)} MR Bucks ($amountStr) have been donated.\n\nYour donation request is under review. You will receive a confirmation email within 2 business days.'
        : '${_formatPoints(selectedPts)} MR Bucks ($amountStr) have been redeemed.\n\nYour gift card will be emailed to you within 2 business days.';
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isDonation ? 'Donation successful!' : 'Redemption successful!'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Reset selection
                setState(() {
                  _selectedPoints = null;
                  _redemptionType = null;
                  _selectedPartner = null;
                });
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

// Network Partner Logo Widget (for URL-based images)
class _NetworkPartnerLogo extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const _NetworkPartnerLogo({required this.url, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Center(
        child: Icon(Icons.image_not_supported, color: Colors.grey.shade500, size: 20),
      );
    }

    // Check if it's an SVG URL
    if (url.toLowerCase().endsWith('.svg')) {
      return Center(
        child: SvgPicture.network(
          url,
          fit: fit,
          placeholderBuilder: (context) => SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
            ),
          ),
        ),
      );
    }

    // Regular image (PNG, JPG, etc.)
    return Center(
      child: Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading network image $url: $error');
          return Center(
            child: Icon(Icons.image_not_supported, color: Colors.grey.shade500, size: 20),
          );
        },
      ),
    );
  }
}

// Points History Tile Widget
class _PointsHistoryTile extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const _PointsHistoryTile({required this.transaction});

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      // US format: MM/DD/YYYY
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = transaction['points'] ?? 0;
    final entryType = transaction['entryType'] ?? '';
    final description = transaction['description'] ?? '';
    final createdAt = transaction['createdAt'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: points >= 0
                  ? const Color(0xFF7E5EFD).withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              points >= 0 ? Icons.add_circle : Icons.remove_circle,
              color: points >= 0 ? const Color(0xFF7E5EFD) : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entryType == 'AWARD' ? 'Points Earned' : 'Points Redeemed',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 11, color: Colors.black38),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Points
          Text(
            points >= 0 ? '+$points' : '$points',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: points >= 0 ? const Color(0xFF7E5EFD) : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

// Redemption History Tile Widget
class _RedemptionHistoryTile extends StatelessWidget {
  final Map<String, dynamic> redemption;

  const _RedemptionHistoryTile({required this.redemption});

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'FULFILLED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'FAILED':
      case 'DENIED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'FULFILLED':
        return 'Approved';
      case 'PENDING':
        return 'Pending';
      case 'FAILED':
        return 'Failed';
      case 'DENIED':
        return 'Denied';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'FULFILLED':
        return Icons.check_circle;
      case 'PENDING':
        return Icons.access_time;
      case 'FAILED':
      case 'DENIED':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      // US format: MM/DD/YYYY
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pointsSpent = redemption['pointsSpent'] ?? 0;
    final amount = redemption['amount'] ?? 0.0;
    final status = redemption['status'] ?? 'UNKNOWN';
    final providerType = redemption['providerType'] ?? '';
    final brand = redemption['brand'] ?? '';
    final createdAt = redemption['createdAt'] ?? '';
    final message = redemption['message'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Brand and Status
          Row(
            children: [
              // Brand/Type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand.isNotEmpty ? brand : providerType,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      providerType == 'GIFT_CARD' ? 'Gift Card' : 'Donation',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      size: 14,
                      color: _getStatusColor(status),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getStatusText(status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Points and Amount
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Points Spent',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$pointsSpent MR Bucks',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7E5EFD),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Date
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 12, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                _formatDate(createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          // Message (if status is FAILED/DENIED)
          if (message.isNotEmpty && (status.toUpperCase() == 'FAILED' || status.toUpperCase() == 'DENIED')) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
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

/// Coin Shower Animation Widget
/// Displays animated coins falling from the top of the screen
class CoinShowerWidget extends StatefulWidget {
  final VoidCallback onComplete;

  const CoinShowerWidget({
    super.key,
    required this.onComplete,
  });

  @override
  State<CoinShowerWidget> createState() => _CoinShowerWidgetState();
}

class _CoinShowerWidgetState extends State<CoinShowerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_CoinAnimation> _coins = [];
  final Random _random = Random();
  // Slightly fewer coins & shorter duration for smoother performance
  static const int _coinCount = 20;
  static const Duration _animationDuration = Duration(milliseconds: 2200);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _animationDuration,
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete();
        }
      });

    // Initialize coins with random positions and movement characteristics
    for (int i = 0; i < _coinCount; i++) {
      _coins.add(_CoinAnimation(
        startX: _random.nextDouble(),
        delay: _random.nextDouble() * 0.3, // keep small variance to stagger coins
        fallSpeed: 0.7 + _random.nextDouble() * 0.6,
        rotationSpeed: 2 + _random.nextDouble() * 4,
        horizontalDrift: -0.25 + _random.nextDouble() * 0.5,
      ));
    }

    // Start animation immediately to align with balance update
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final progress = _controller.value;
          return Stack(
            children: _coins.map((coin) {
              final adjustedProgress =
                  ((progress - coin.delay) / (1 - coin.delay)).clamp(0.0, 1.0);

              if (adjustedProgress <= 0 || adjustedProgress >= 1.0) {
                return const SizedBox.shrink();
              }

              // Position calculations
              final x = (coin.startX +
                      coin.horizontalDrift * adjustedProgress) *
                  size.width;
              final y = adjustedProgress *
                  coin.fallSpeed *
                  size.height *
                  1.1; // little overshoot past screen bottom

              // Rotation & scaling
              final rotation =
                  adjustedProgress * coin.rotationSpeed * 2 * pi;
              final scale = 0.6 +
                  (adjustedProgress < 0.3
                      ? adjustedProgress / 0.3 * 0.4
                      : 0.4 +
                          (adjustedProgress - 0.3) / 0.7 * 0.2);

              // Opacity fade in/out
              final opacity = adjustedProgress < 0.1
                  ? adjustedProgress / 0.1
                  : adjustedProgress > 0.85
                      ? (1 - adjustedProgress) / 0.15
                      : 1.0;

              return Positioned(
                left: x - 20,
                top: y - 20,
                child: Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      // Lightweight reward coin icon optimized for animation
                      child: const _RewardCoinIcon(size: 40),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _CoinAnimation {
  final double startX;
  final double delay;
  final double fallSpeed;
  final double rotationSpeed;
  final double horizontalDrift;

  _CoinAnimation({
    required this.startX,
    required this.delay,
    required this.fallSpeed,
    required this.rotationSpeed,
    required this.horizontalDrift,
  });
}

class _RewardCoinIcon extends StatelessWidget {
  final double size;

  const _RewardCoinIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    final double innerSize = size * 0.76;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        // No shadow here to keep the animation lightweight
      ),
      child: Center(
        child: Container(
          width: innerSize,
          height: innerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF8E1), Color(0xFFFFD54F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Icon(
            Icons.workspace_premium,
            color: Colors.orange.shade700,
            size: innerSize * 0.6,
          ),
        ),
      ),
    );
  }
}
