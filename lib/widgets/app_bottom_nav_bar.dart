import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feature_flags_provider.dart';
import '../screens/more_options_screen.dart';

/// Reusable bottom navigation bar widget used across multiple screens
class AppBottomNavBar extends StatelessWidget {
  final String currentRoute;
  final String userId;
  final String token;
  final VoidCallback? onUploadTap;

  const AppBottomNavBar({
    Key? key,
    required this.currentRoute,
    required this.userId,
    required this.token,
    this.onUploadTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<FeatureFlagsProvider>(
      builder: (context, featureFlagsProvider, child) {
        final isMrBucksEnabled = featureFlagsProvider.isMrBucksEnabled;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Home
                      Expanded(
                        child: _buildBottomNavItem(
                          context: context,
                          emoji: '🏠',
                          label: 'Home',
                          isSelected: currentRoute == '/dashboard' || currentRoute == 'dashboard',
                          onTap: () {
                            if (currentRoute != '/dashboard' && currentRoute != 'dashboard') {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/dashboard',
                                (route) => false,
                              );
                            }
                          },
                        ),
                      ),
                      
                      // Reports
                      Expanded(
                        child: _buildBottomNavItem(
                          context: context,
                          emoji: '📊',
                          label: 'Reports',
                          isSelected: currentRoute == '/reports' || currentRoute == 'reports',
                          onTap: () {
                            if (currentRoute != '/reports' && currentRoute != 'reports') {
                              Navigator.pushNamed(context, '/reports');
                            }
                          },
                        ),
                      ),
                      
                      // Space for central button
                      const SizedBox(width: 60),
                      
                      // MR Bucks (conditional)
                      if (isMrBucksEnabled)
                        Expanded(
                          child: _buildBottomNavItem(
                            context: context,
                            emoji: '💰',
                            label: 'MR Bucks',
                            isSelected: currentRoute == '/mr_bucks' || currentRoute == 'mr_bucks',
                            onTap: () {
                              if (currentRoute != '/mr_bucks' && currentRoute != 'mr_bucks') {
                                Navigator.pushNamed(context, '/mr_bucks');
                              }
                            },
                          ),
                        ),
                      
                      // More
                      Expanded(
                        child: _buildBottomNavItem(
                          context: context,
                          emoji: '☰',
                          label: 'More',
                          isSelected: currentRoute == '/more' || currentRoute == 'more',
                          onTap: () {
                            if (currentRoute != '/more' && currentRoute != 'more') {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => MoreOptionsScreen(
                                    userId: userId,
                                    token: token,
                                  ),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  // Central Add Button
                  Positioned(
                    left: MediaQuery.of(context).size.width / 2 - 30,
                    top: -20,
                    child: GestureDetector(
                      onTap: onUploadTap,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF905CFF), Color(0xFF7A4BD9)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF905CFF).withOpacity(0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '＋',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                            ),
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
  }

  Widget _buildBottomNavItem({
    required BuildContext context,
    required String emoji,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: TextStyle(
                fontSize: 22,
                color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            if (label.isNotEmpty)
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF7E5EFD) : Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}





