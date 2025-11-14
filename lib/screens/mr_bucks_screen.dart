import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service_bypass.dart';
import '../services/redemption_service.dart';
import '../providers/user_provider.dart';

class MrBucksScreen extends StatefulWidget {
  const MrBucksScreen({super.key});

  @override
  State<MrBucksScreen> createState() => _MrBucksScreenState();
}

class _MrBucksScreenState extends State<MrBucksScreen> {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTermsStatus();
    });
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
      body: _checkingTermsStatus
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
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD54F), Color(0xFFFFA726)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
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
                          const Text('🪙', style: TextStyle(fontSize: 40)),
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
                              style: const TextStyle(
                                color: Colors.white,
                                    fontSize: 42,
                                fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    height: 1,
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
                      color: Colors.white,
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
            SizedBox(
              height: 64,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E5EFD),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                onPressed: (_redemptionType == null || _selectedPartner == null) ? null : () {
                  if (_selectedPoints == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select points to redeem')), 
                    );
                    return;
                  }
                  _openRedemptionDialog();
                },
                child: Text(_redemptionType == 'donation' ? 'Continue to Donate' : 'Continue to Redemption'),
              ),
            ),
            const SizedBox(height: 12),
            _SectionHeader(title: 'How to Earn MR Bucks'),
            const SizedBox(height: 8),
            _EarnTile(
              emoji: '📸',
              title: 'Scan, Manual & Upload Receipt',
              subtitle: 'Upload receipts through any method',
              points: '+20 pts',
              color: const Color(0xFF7E5EFD),
            ),
            _EarnTile(
              emoji: '📧',
              title: 'Email Receipt',
              subtitle: 'Send to upload@ManageReceipt.com',
              points: '+30 pts',
              color: Colors.indigo,
            ),
            _EarnTile(
              emoji: '⭐',
              title: 'Preferred Vendor Receipts',
              subtitle: '',
              points: '+50 pts',
              color: Colors.amber.shade800,
            ),
            _EarnTile(
              emoji: '📁',
              title: 'Document Wallet',
              subtitle: 'Store important documents',
              points: '+5 pts',
              color: Colors.deepOrange,
            ),
            _EarnTile(
              emoji: '📊',
              title: 'Expense Reports',
              subtitle: 'Create and submit expense reports',
              points: '+10 pts',
              color: Colors.blue,
            ),
            _EarnTile(
              emoji: '📋',
              title: 'Tax Reports Export',
              subtitle: 'Export your tax reports',
              points: '+10 pts',
              color: Colors.teal,
            ),
            _EarnTile(
              emoji: '📈',
              title: 'Custom Reports Export',
              subtitle: 'Export custom reports',
              points: '+10 pts',
              color: Colors.purple,
            ),
            const SizedBox(height: 24),
          ],
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

// Simple partners grid with selection highlight
class _PartnersGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final List<Map<String, dynamic>> partners;

  const _PartnersGrid({required this.selected, required this.onSelected, required this.partners});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: partners.map((partner) {
        final String partnerName = partner['name'] ?? '';
        final String logoUrl = partner['logo'] ?? '';
        final bool isSel = partnerName == selected;
        
        return GestureDetector(
          onTap: () => onSelected(partnerName),
          child: Container(
            width: (MediaQuery.of(context).size.width - 16 * 2 - 14 * 2) / 3,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
              children: [
                Container(
                  height: 72,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  child: logoUrl.isNotEmpty
                      ? _NetworkPartnerLogo(url: logoUrl, fit: BoxFit.contain)
                      : Icon(
                          Icons.image_not_supported,
                          color: Colors.grey.shade400,
                          size: 32,
                        ),
                ),
                const SizedBox(height: 8),
                Text(partnerName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
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
        setState(() {
          _balance = fetchedBalance;
          // Optional: show recent activity again from summary
          _summaryTransactions = txList;
          _loadingSummary = false;
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
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
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

  Widget _buildPointsHistoryContent() {
    // Use already loaded summary transactions - no need to fetch again
    if (_summaryTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No points history yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start earning points to see your history here!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black38),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_redemptionHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No redemption history yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start redeeming your points to see your history here!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black38),
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
      return '${date.day}/${date.month}/${date.year}';
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
      return '${date.day}/${date.month}/${date.year}';
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
