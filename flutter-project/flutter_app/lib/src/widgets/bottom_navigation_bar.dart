import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_routes.dart';
import '../theme/app_theme.dart' show AppColors;
import '../providers/role_provider.dart';

/// Unified Bottom Navigation Bar widget
/// Used consistently across all screens for: Home, Request, Chat, Profile
/// Adapts navigation based on user role (Patient vs Donor)
class UnifiedBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int)? onItemTapped;
  final int? chatUnreadCount;

  const UnifiedBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    this.onItemTapped,
    this.chatUnreadCount,
  });

  /// Get the route for the Requests tab based on user role
  /// - Patients: My Requests (view their own blood requests)
  /// - Donors: Nearby Requests (view requests they can help with)
  static String _getRequestsRoute(BuildContext context) {
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);
    // Default to nearby requests for donors/no role
    if (roleProvider.isPatient) {
      return AppRoutes.myRequests;
    }
    return AppRoutes.nearbyRequests;
  }

  static List<NavItem> _getNavItems(BuildContext context) {
    final requestsRoute = _getRequestsRoute(context);

    return [
      NavItem(
        icon: Icons.home_rounded,
        activeIcon: Icons.home_rounded,
        label: 'Home',
        route: AppRoutes.home,
      ),
      NavItem(
        icon: Icons.bloodtype_outlined,
        activeIcon: Icons.bloodtype,
        label: 'Request',
        route: requestsRoute,
      ),
      NavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Chat',
        route: AppRoutes.messages,
      ),
      NavItem(
        icon: Icons.person_rounded,
        activeIcon: Icons.person,
        label: 'Profile',
        route: AppRoutes.settings,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _getNavItems(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = selectedIndex == index;

              return _buildNavItem(
                context: context,
                item: item,
                isSelected: isSelected,
                onTap: () => _handleItemTap(context, item, index),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required NavItem item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Check if this is the chat item and has unread count
    final bool isChatItem = item.label == 'Chat';
    final bool hasUnread = isChatItem && chatUnreadCount != null && chatUnreadCount! > 0;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 24,
                ),
                if (hasUnread)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        chatUnreadCount! > 9 ? '9+' : chatUnreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleItemTap(BuildContext context, NavItem item, int index) {
    // Haptic feedback
    HapticFeedback.lightImpact();

    // Call custom onTap if provided
    if (onItemTapped != null) {
      onItemTapped!(index);
      return;
    }

    // Default navigation behavior
    if (item.route.isNotEmpty) {
      Navigator.pushReplacementNamed(context, item.route);
    }
  }
}

/// Navigation item model
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}
