import 'dart:async';
import 'package:flutter/material.dart' hide Banner;
import 'package:url_launcher/url_launcher.dart';
import '../models/banner_model.dart';
import '../screens/refer_earn_screen.dart';
import '../providers/user_provider.dart';
import 'package:provider/provider.dart';

class BannerCarousel extends StatefulWidget {
  final List<BannerModel> banners;

  const BannerCarousel({
    Key? key,
    required this.banners,
  }) : super(key: key);

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoSwipeTimer;
  int _swipeCount = 0;
  bool _hasCompletedCycle = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    if (widget.banners.isNotEmpty) {
      _startAutoSwipe();
    }
  }

  @override
  void didUpdateWidget(BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset when banners change
    if (oldWidget.banners.length != widget.banners.length) {
      _swipeCount = 0;
      _hasCompletedCycle = false;
      _currentIndex = 0;
      _autoSwipeTimer?.cancel();
      _pageController.jumpToPage(0);
      if (widget.banners.isNotEmpty) {
        _startAutoSwipe();
      }
    }
  }

  void _startAutoSwipe() {
    if (widget.banners.isEmpty || widget.banners.length <= 1) return;

    _autoSwipeTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_hasCompletedCycle || !mounted) {
        timer.cancel();
        return;
      }

      _swipeCount++;

      // Check if we've completed one full cycle
      if (_swipeCount >= widget.banners.length) {
        _hasCompletedCycle = true;
        timer.cancel();
        return;
      }

      // Move to next banner
      final nextIndex = (_currentIndex + 1) % widget.banners.length;
      setState(() {
        _currentIndex = nextIndex;
      });

      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Stop auto-swipe on manual swipe
    if (_autoSwipeTimer != null) {
      _autoSwipeTimer!.cancel();
      _autoSwipeTimer = null;
      _hasCompletedCycle = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoSwipeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.banners.length == 1) {
      // Single banner, no carousel needed
      return _buildBannerCard(widget.banners[0]);
    }

    return Column(
      children: [
        SizedBox(
          height: 80,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              return _buildBannerCard(widget.banners[index]);
            },
          ),
        ),
        // Page indicators
        if (widget.banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.banners.length,
                (index) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index
                        ? const Color(0xFF7E5EFD)
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBannerCard(BannerModel banner) {
    return GestureDetector(
      onTap: () => _handleBannerPress(banner),
      child: Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: _parseGradient(banner.backgroundColor),
          color: _parseGradient(banner.backgroundColor) == null
              ? _parseColor(banner.backgroundColor) ?? const Color(0xFFFF6B6B)
              : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (_parseColor(banner.backgroundColor) ?? const Color(0xFFFF6B6B))
                  .withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  if (banner.icon != null)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _buildIcon(banner.icon!),
                      ),
                    ),
                  if (banner.icon != null) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          banner.title,
                          style: TextStyle(
                            color: _parseColor(banner.textColor) ?? Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (banner.subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            banner.subtitle!,
                            style: TextStyle(
                              color: (_parseColor(banner.textColor) ?? Colors.white)
                                  .withOpacity(0.9),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (banner.actionText != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  banner.actionText!,
                  style: TextStyle(
                    color: _parseColor(banner.backgroundColor) ?? const Color(0xFFFF6B6B),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(String iconName) {
    // Map icon names to emoji or icons
    final iconMap = {
      'gift': '🎁',
      'split': '🔀',
      'referral': '🎁',
      'refer': '🎁',
    };

    final emoji = iconMap[iconName.toLowerCase()] ?? '📢';
    return Text(
      emoji,
      style: const TextStyle(fontSize: 24),
    );
  }

  Color? _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return null;

    try {
      // Handle hex colors
      if (colorString.startsWith('#')) {
        final hex = colorString.replaceFirst('#', '');
        if (hex.length == 6) {
          return Color(int.parse('FF$hex', radix: 16));
        } else if (hex.length == 8) {
          return Color(int.parse(hex, radix: 16));
        }
      }

      // Handle rgb/rgba
      if (colorString.startsWith('rgb')) {
        final match = RegExp(r'rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)')
            .firstMatch(colorString);
        if (match != null) {
          final r = int.parse(match.group(1)!);
          final g = int.parse(match.group(2)!);
          final b = int.parse(match.group(3)!);
          final a = match.group(4) != null ? double.parse(match.group(4)!) : 1.0;
          return Color.fromRGBO(r, g, b, a);
        }
      }
    } catch (e) {
      debugPrint('Error parsing color: $colorString - $e');
    }

    return null;
  }

  Gradient? _parseGradient(String? gradientString) {
    if (gradientString == null || gradientString.isEmpty) return null;

    // Check if it's a gradient
    if (!gradientString.contains('gradient')) {
      return null;
    }

    try {
      // Parse linear-gradient(135deg, #FF6B35 0%, #F7931E 100%)
      final match = RegExp(
        r'linear-gradient\((\d+)deg,\s*(#[0-9A-Fa-f]{6})\s+(\d+)%,\s*(#[0-9A-Fa-f]{6})\s+(\d+)%\)',
      ).firstMatch(gradientString);

      if (match != null) {
        final angle = int.parse(match.group(1)!);
        final color1 = _parseColor(match.group(2)!);
        final color2 = _parseColor(match.group(4)!);

        if (color1 != null && color2 != null) {
          // Convert angle to Alignment
          Alignment begin;
          Alignment end;

          if (angle == 0 || angle == 360) {
            begin = Alignment.centerLeft;
            end = Alignment.centerRight;
          } else if (angle == 90) {
            begin = Alignment.topCenter;
            end = Alignment.bottomCenter;
          } else if (angle == 135) {
            begin = Alignment.topLeft;
            end = Alignment.bottomRight;
          } else if (angle == 180) {
            begin = Alignment.centerRight;
            end = Alignment.centerLeft;
          } else if (angle == 270) {
            begin = Alignment.bottomCenter;
            end = Alignment.topCenter;
          } else {
            // Default to topLeft to bottomRight for other angles
            begin = Alignment.topLeft;
            end = Alignment.bottomRight;
          }

          return LinearGradient(
            begin: begin,
            end: end,
            colors: [color1, color2],
          );
        }
      }
    } catch (e) {
      debugPrint('Error parsing gradient: $gradientString - $e');
    }

    return null;
  }

  Future<void> _handleBannerPress(BannerModel banner) async {
    // Stop auto-swipe on tap
    if (_autoSwipeTimer != null) {
      _autoSwipeTimer!.cancel();
      _autoSwipeTimer = null;
      _hasCompletedCycle = true;
    }

    if (banner.actionType == null || banner.actionUrl == null) {
      return;
    }

    switch (banner.actionType) {
      case 'navigate':
        // Handle internal navigation
        await _handleNavigation(banner.actionUrl!);
        break;
      case 'external_link':
        // Open external URL
        final uri = Uri.parse(banner.actionUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        break;
      case 'internal_link':
        // Similar to navigate
        await _handleNavigation(banner.actionUrl!);
        break;
      default:
        // No action
        break;
    }
  }

  Future<void> _handleNavigation(String route) async {
    if (route.isEmpty) return;
    
    final trimmedRoute = route.trim();
    final normalizedRoute = trimmedRoute.toLowerCase();
    
    // STEP 1: Pattern matching for special cases FIRST (screens without named routes)
    // These are special screens that need custom navigation (like ReferEarnScreen)
    if (normalizedRoute == '/referrals' || 
        normalizedRoute == '/refer-earn' || 
        normalizedRoute == '/refer_earn') {
      // Navigate to Refer & Earn screen (custom navigation, not a named route)
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ReferEarnScreen(
              userId: userProvider.userId ?? '',
              token: userProvider.token ?? '',
            ),
          ),
        );
        return;
      }
    }
    
    // STEP 2: Try standard named routes (these are defined in main.dart)
    final namedRoutes = [
      '/reports',
      '/split_receipts',
      '/split-receipts',
      '/subscription_plans',
      '/subscription',
      '/workspaces',
      '/workspace',
      '/mr_bucks',
      '/mr-bucks',
      '/bill_reminders',
      '/reminder',
    ];
    
    if (namedRoutes.contains(normalizedRoute)) {
      if (mounted) {
        try {
          Navigator.of(context).pushNamed(normalizedRoute);
          return;
        } catch (e) {
          debugPrint('BannerCarousel: Failed to navigate to $normalizedRoute: $e');
        }
      }
    }
    
    // STEP 3: Try exact route match for any other named routes
    if (trimmedRoute.startsWith('/')) {
      if (mounted) {
        try {
          Navigator.of(context).pushNamed(trimmedRoute);
          return;
        } catch (e) {
          debugPrint('BannerCarousel: Route $trimmedRoute not found: $e');
        }
      }
    }
    
    // STEP 4: Try without leading slash if it wasn't there originally
    if (!trimmedRoute.startsWith('/')) {
      if (mounted) {
        try {
          Navigator.of(context).pushNamed('/$trimmedRoute');
          return;
        } catch (e) {
          debugPrint('BannerCarousel: Failed to navigate to route /$trimmedRoute: $e');
        }
      }
    }
    
    // STEP 5: Treat as external URL if all else fails
    try {
      final uri = Uri.parse(trimmedRoute);
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
    } catch (e) {
      debugPrint('BannerCarousel: Failed to parse as URL: $trimmedRoute - $e');
    }
    
    debugPrint('BannerCarousel: Could not navigate to route: $trimmedRoute');
  }
}

