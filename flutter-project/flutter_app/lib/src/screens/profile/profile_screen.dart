import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/profile.dart';
import '../../widgets/bottom_navigation_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  int _selectedTabIndex = 3; // Profile tab is active

  // Profile data
  Profile? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;

  // Stats (placeholder - will be fetched from backend later)
  final int _donations = 0;
  final int _livesSaved = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthAndFetchProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Check authentication when app resumes
    if (state == AppLifecycleState.resumed) {
      _checkAuthAndFetchProfile();
    }
  }

  Future<void> _checkAuthAndFetchProfile() async {
    // Check if user is authenticated
    final isAuthenticated = await ApiService.isAuthenticated();
    if (!isAuthenticated && mounted) {
      // Redirect to login if not authenticated
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
      return;
    }

    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.getProfile();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final data = result['data']['profile'];
          _userProfile = Profile.fromJson(data);
        } else {
          _errorMessage = result['message'] ?? 'Failed to load profile';
        }
      });
    }
  }

  // Get menu options dynamically based on user role
  List<Map<String, dynamic>> get _menuOptions {
    final isAdmin = _userProfile?.role == 'admin';

    final options = [
      {
        'title': 'Edit Profile',
        'icon': Icons.person_outline,
        'isDestructive': false,
        'route': AppRoutes.editProfile,
      },
      {
        'title': 'My Requests',
        'icon': Icons.bloodtype_outlined,
        'isDestructive': false,
        'route': AppRoutes.myRequests,
      },
      {
        'title': 'Donation History',
        'icon': Icons.water_drop_outlined,
        'isDestructive': false,
        'route': AppRoutes.myDonations,
      },
      {
        'title': 'Health Records',
        'icon': Icons.medical_services_outlined,
        'isDestructive': false,
        'route': '/health-records',
      },
      {
        'title': 'Settings',
        'icon': Icons.settings_outlined,
        'isDestructive': false,
        'route': AppRoutes.settings,
      },
      {
        'title': 'Logout',
        'icon': Icons.logout,
        'isDestructive': true,
        'route': '/logout',
      },
    ];

    // Insert Admin Dashboard option before Settings if user is admin AND on web
    if (kIsWeb && isAdmin) {
      options.insert(options.length - 2, {
        'title': 'Admin Dashboard',
        'icon': Icons.admin_panel_settings,
        'isDestructive': false,
        'route': AppRoutes.adminDashboard,
      });
    }

    return options;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 60,
                          color: AppColors.urgencyCritical,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Main Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Header
                            _buildProfileHeader(),
                            const SizedBox(height: 20),

                            // Stats Section
                            _buildStatsSection(),
                            const SizedBox(height: 20),

                            // Menu Options
                            Expanded(
                              child: _buildMenuSection(),
                            ),
                          ],
                        ),
                      ),

                      // Bottom Navigation
                      _buildBottomNavigation(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final profileImage = _userProfile?.profilePictureUrl ?? 'https://i.pravatar.cc/150?img=12';
    final userName = _userProfile?.userFullName ?? 'Guest User';
    final bloodType = _userProfile?.bloodGroup ?? 'Not Set';
    final donorSince = _userProfile?.createdAt != null
        ? '${_userProfile!.createdAt!.month}/${_userProfile!.createdAt!.year}'
        : 'Not Set';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: const BoxDecoration(
        color: AppColors.urgencyCritical, // Dark red #8B0000
      ),
      child: Column(
        children: [
          // Profile Picture
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: ClipOval(
              child: Image.network(
                profileImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.softPink,
                    child: const Icon(Icons.person, color: AppColors.primary, size: 50),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Name
          Text(
            userName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Blood Type Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              bloodType,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.urgencyCritical,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Donor Status
          Text(
            'Donor since $donorSince',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard('$_donations', 'Donations'),
          _buildStatDivider(),
          _buildStatCard('$_livesSaved', 'Lives Saved'),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.border,
    );
  }

  Widget _buildMenuSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: List.generate(_menuOptions.length, (index) {
            final option = _menuOptions[index];
            final isLast = index == _menuOptions.length - 1;
            return _MenuOptionCard(
              title: option['title'] as String,
              icon: option['icon'] as IconData,
              isDestructive: option['isDestructive'] as bool,
              showDivider: !isLast,
              onTap: () {
                final route = option['route'] as String;
                if (route == '/logout') {
                  _handleLogout();
                } else if (route.startsWith('/')) {
                  Navigator.pushNamed(context, route);
                }
              },
            );
          }),
        ),
      ),
    );
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
            child: const Text('Logout', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Call API logout and clear local data
      await ApiService.logout();

      // Navigate to role selection screen and clear ALL routes from the stack
      // This ensures no cached user data remains in any screen
      // After logout, user goes to role selection, then login/register
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.roleSelection,
          (route) => false, // Remove all routes
        );
      }
    }
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

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
        // Handle navigation based on index
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, AppRoutes.home);
            break;
          case 1:
            Navigator.pushReplacementNamed(context, AppRoutes.nearbyRequests);
            break;
          case 2:
            // Navigate to Map
            Navigator.pushNamed(context, AppRoutes.nearbyDonorsMap);
            break;
          case 3:
            Navigator.pushReplacementNamed(context, AppRoutes.messages);
            break;
          case 4:
            // Navigate to Settings (Profile page now navigates to Settings)
            Navigator.pushReplacementNamed(context, AppRoutes.settings);
            break;
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

class _MenuOptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDestructive;
  final bool showDivider;
  final VoidCallback onTap;

  const _MenuOptionCard({
    required this.title,
    required this.icon,
    required this.isDestructive,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.primary : AppColors.textPrimary;

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
                  color: isDestructive ? AppColors.primary : AppColors.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: 12),

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),

                // Arrow
                Icon(
                  Icons.chevron_right,
                  color: isDestructive ? AppColors.primary : AppColors.textSecondary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: AppColors.border,
            indent: 52,
          ),
      ],
    );
  }
}
