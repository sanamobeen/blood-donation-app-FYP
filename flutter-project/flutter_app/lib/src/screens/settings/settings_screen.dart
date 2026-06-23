import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/bottom_navigation_bar.dart';

// String extension for capitalize
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedTabIndex = 4; // Profile tab is index 4

  // Toggle states
  bool _donationRemindersEnabled = true;

  // User data
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Always reload profile when screen opens to ensure fresh data
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Reset state to ensure fresh data
    setState(() {
      _isLoading = true;
      _userProfile = null;
    });

    final result = await ApiService.getProfile();
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          // Handle different response structures
          if (result['data'] is Map && result['data']['profile'] != null) {
            _userProfile = Map<String, dynamic>.from(result['data']['profile']);
            // Also store user data if available
            if (result['data']['user'] != null) {
              _userProfile!['email'] = result['data']['user']['email'];
              _userProfile!['username'] = result['data']['user']['username'];
              _userProfile!['role'] = result['data']['user']['role'];
            }
          } else if (result['data'] is Map) {
            _userProfile = Map<String, dynamic>.from(result['data']);
          }
        }
        _isLoading = false;
      });
    }
  }

  String get _userName {
    return _userProfile?['user_full_name'] ?? _userProfile?['username'] ?? _userProfile?['name'] ?? 'User';
  }

  String get _userEmail {
    // Try multiple possible email field locations
    return _userProfile?['email'] ??
           _userProfile?['user']?['email'] ??
           'user@email.com';
  }

  String get _profileImage {
    // Try profile_picture_url first (from backend), then profile_picture
    return _userProfile?['profile_picture_url'] ??
           _userProfile?['profile_picture'] ??
           '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Profile Section
                    _buildUserProfileSection(),
                    const SizedBox(height: 24),

                    // Account Section
                    _buildSettingsSection(
                      title: 'Account',
                      icon: Icons.person_outline,
                      items: [
                        _SettingsItem(
                          title: 'Edit profile',
                          icon: Icons.person_outline,
                          onTap: () {
                            Navigator.pushNamed(context, AppRoutes.editProfile);
                          },
                        ),
                        _SettingsItem(
                          title: 'Switch Role',
                          icon: Icons.swap_horiz_rounded,
                          value: _userProfile != null
                              ? 'Current: ${_userProfile!['role']?.toString().capitalize()}'
                              : 'Donor/Patient',
                          onTap: () {
                            final currentRole = _userProfile?['role']?.toString() ?? 'patient';
                            Navigator.pushNamed(
                              context,
                              AppRoutes.roleSwitch,
                              arguments: {'currentRole': currentRole},
                            );
                          },
                        ),
                        // Show Admin Dashboard option only for admin users on web
                        if (kIsWeb && _userProfile?['role']?.toString().toLowerCase() == 'admin')
                          _SettingsItem(
                            title: 'Admin Dashboard',
                            icon: Icons.admin_panel_settings,
                            onTap: () {
                              Navigator.pushNamed(context, AppRoutes.adminDashboard);
                            },
                          ),
                        _SettingsItem(
                          title: 'Change password',
                          icon: Icons.lock_outline,
                          onTap: () {
                            Navigator.pushNamed(context, AppRoutes.changePassword);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Health Section
                    _buildSettingsSection(
                      title: 'Health',
                      icon: Icons.favorite_border,
                      items: [
                        _SettingsItem(
                          title: 'Medical info',
                          icon: Icons.description_outlined,
                          onTap: () => _navigateTo(AppRoutes.medicalInfo),
                        ),
                        _SettingsItem(
                          title: 'Donation reminders',
                          icon: Icons.event_outlined,
                          trailing: Switch(
                            value: _donationRemindersEnabled,
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              setState(() {
                                _donationRemindersEnabled = value;
                              });
                            },
                          ),
                          onTap: () {
                            setState(() {
                              _donationRemindersEnabled = !_donationRemindersEnabled;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Support Section
                    _buildSettingsSection(
                      title: 'Support',
                      icon: Icons.help_outline,
                      items: [
                        _SettingsItem(
                          title: 'AI Assistant',
                          icon: Icons.smart_toy_outlined,
                          onTap: () {
                            Navigator.pushNamed(context, AppRoutes.aiChatbot);
                          },
                        ),
                        _SettingsItem(
                          title: 'Help',
                          icon: Icons.help_outline,
                          onTap: () {
                            Navigator.pushNamed(context, AppRoutes.help);
                          },
                        ),
                        _SettingsItem(
                          title: 'About',
                          icon: Icons.info_outline,
                          onTap: () => _navigateTo(AppRoutes.about),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Logout Section
                    _buildLogoutSection(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom Navigation
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileSection() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: ClipOval(
              child: _profileImage.isNotEmpty
                  ? Image.network(
                _profileImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.softPink,
                    child: const Icon(Icons.person, color: AppColors.primary, size: 30),
                  );
                },
              )
                  : Container(
                color: AppColors.softPink,
                child: const Icon(Icons.person, color: AppColors.primary, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Name and Email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required List<_SettingsItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Settings Items Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isLast = index == items.length - 1;
              return _SettingsItemCard(
                title: item.title,
                icon: item.icon,
                trailing: item.trailing,
                value: item.value,
                isDestructive: item.isDestructive,
                showDivider: !isLast,
                onTap: item.onTap,
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _handleLogout,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.logout,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(String route) {
    // Handle navigation
    if (route == '/logout') {
      _handleLogout();
    } else {
      Navigator.pushNamed(context, route);
    }
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Call API logout and clear local data
      await ApiService.logout();

      // Navigate to role selection screen and clear ALL routes from the stack
      // User goes to role selection, then can login/register from there
      // Note: We keep onboarding_completed flag since user has already seen onboarding
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.roleSelection,
          (route) => false, // Remove all routes
        );
      }
    }
  }

  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: Text('$feature feature will be available soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return UnifiedBottomNavigationBar(
      selectedIndex: _selectedTabIndex,
      onItemTapped: (index) {
        setState(() => _selectedTabIndex = index);
        final routes = [
          AppRoutes.home,
          AppRoutes.nearbyRequests,
          AppRoutes.findDonors,
          AppRoutes.messages,
          AppRoutes.settings,
        ];
        if (routes[index].isNotEmpty) {
          Navigator.pushReplacementNamed(context, routes[index]);
        }
      },
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, String route) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
        // Always navigate to the route when tapped
        if (route.startsWith('/')) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final String? value;
  final bool isDestructive;
  final VoidCallback? onTap;

  _SettingsItem({
    required this.title,
    required this.icon,
    this.trailing,
    this.value,
    this.isDestructive = false,
    this.onTap,
  });
}

class _SettingsItemCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final String? value;
  final bool isDestructive;
  final bool showDivider;
  final VoidCallback? onTap;

  const _SettingsItemCard({
    required this.title,
    required this.icon,
    this.trailing,
    this.value,
    this.isDestructive = false,
    this.showDivider = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.primary : AppColors.textSecondary;

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon
                Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
                const SizedBox(width: 12),

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: isDestructive ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),

                // Value (if any)
                if (value != null) ...[
                  Text(
                    value!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Trailing widget (toggle switch) or Arrow
                if (trailing != null)
                  trailing!
                else
                  Icon(
                    Icons.chevron_right,
                    color: color,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: AppColors.border,
            indent: 50,
          ),
      ],
    );
  }
}
