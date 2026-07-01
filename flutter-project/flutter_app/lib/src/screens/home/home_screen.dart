import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/profile.dart';
import '../../models/blood_request.dart';
import '../../providers/role_provider.dart';
import '../../widgets/bottom_navigation_bar.dart';
import '../donors/donor_profile_screen.dart';
import '../requests/blood_request_detail_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  bool _isLoadingRequests = true;
  Profile? _userProfile;
  String? _errorMessage;
  RoleProvider? _roleProvider;

  // Blood requests data
  BloodRequestListResponse? _requestsResponse;

  // Notifications
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();

    // Get role provider and listen for changes
    _roleProvider = Provider.of<RoleProvider>(context, listen: false);
    _roleProvider!.addListener(_onRoleChanged);

    _checkAuthAndLoadData();
  }

  @override
  void dispose() {
    _roleProvider?.removeListener(_onRoleChanged);
    super.dispose();
  }

  void _onRoleChanged() {
    // Reload data when role changes
    _loadData();
  }

  Future<void> _checkAuthAndLoadData() async {
    // Check if user is authenticated
    final isAuthenticated = await ApiService.isAuthenticated();
    if (!isAuthenticated && mounted) {
      // Redirect to login if not authenticated (NOT role selection)
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    // Fetch user role
    if (_roleProvider != null) {
      await _roleProvider!.fetchUserRole();
    }

    _loadData();
  }

  Future<void> _loadData() async {
    // Reset state to ensure fresh data is loaded
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _userProfile = null; // Clear previous profile
      _requestsResponse = null; // Clear previous requests
    });

    // Load profile, requests, and unread count in parallel
    final results = await Future.wait([
      ApiService.getProfile(),
      ApiService.getBloodRequests(status: 'pending'),
      _loadUnreadCount(),
    ]);

    if (mounted) {
      setState(() {
        // Process profile
        final profileResult = results[0] as Map<String, dynamic>;
        if (profileResult['success'] == true) {
          final data = profileResult['data']['profile'];
          _userProfile = Profile.fromJson(data);
        } else {
          _errorMessage = profileResult['message'];
        }
        _isLoading = false;

        // Process blood requests
        _requestsResponse = results[1] as BloodRequestListResponse;
        _isLoadingRequests = false;
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final result = await ApiService.getUnreadNotificationsCount();
      if (result['success'] == true && mounted) {
        setState(() {
          _unreadCount = result['unread_count'] as int? ?? 0;
        });
      }
    } catch (e) {
      // Silently fail - notification count is not critical
      if (mounted) {
        setState(() {
          _unreadCount = 0;
        });
      }
    }
  }

  List<BloodRequest> get _nearbyRequests {
    if (_requestsResponse == null) return [];
    return _requestsResponse!.bloodRequests
        .where((r) => r.isActive && r.status == 'pending')
        .toList();
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 16),

                    // Quick Search Bar
                    _buildQuickSearchBar(),
                    const SizedBox(height: 16),

                    // Donation Status Card
                    _buildDonationStatusCard(),
                    const SizedBox(height: 20),

                    // Quick Actions
                    _buildSectionTitle('Quick Actions'),
                    const SizedBox(height: 12),
                    _buildQuickActions(),
                    const SizedBox(height: 20),

                    // Urgent Requests
                    _buildUrgentRequestsHeader(),
                    const SizedBox(height: 12),
                    _buildUrgentRequests(),
                    const SizedBox(height: 20),
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

  Widget _buildHeader() {
    final userName = _userProfile?.userFullName ?? 'Guest';
    final profilePicture = _userProfile?.profilePictureUrl;
    final bloodGroup = _userProfile?.bloodGroup ?? '--';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Profile Picture
          GestureDetector(
            onTap: () {
              if (_userProfile != null) {
                // Navigate to donor's public profile
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DonorProfileScreen(
                      donor: {
                        'name': _userProfile!.userFullName,
                        'bloodType': _userProfile!.bloodGroup,
                        'blood_group': _userProfile!.bloodGroup,
                        'location': _userProfile!.city,
                        'distance': '0',
                        'donations': '0',
                        'livesSaved': '0',
                        'lives_saved': '0',
                        'rating': '5.0',
                        'about': 'Blood donor - ready to save lives!',
                        'lastDonation': 'Not recorded',
                        'last_donation': 'Not recorded',
                        'image': _userProfile!.profilePictureUrl,
                        'profile_picture': _userProfile!.profilePictureUrl,
                        'isOnline': true,
                      },
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: ClipOval(
                child: profilePicture != null && profilePicture.isNotEmpty
                    ? Image.network(
                        profilePicture,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.softPink,
                            child: const Icon(Icons.person, color: AppColors.primary),
                          );
                        },
                      )
                    : Container(
                        color: AppColors.softPink,
                        child: const Icon(Icons.person, color: AppColors.primary),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $userName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Ready to save lives today?',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Notification Bell
          GestureDetector(
            onTap: () async {
              await Navigator.pushNamed(context, AppRoutes.notifications);
              // Reload unread count when returning
              _loadUnreadCount();
            },
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.softPink.withValues(alpha: 0.3),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
                    ),
                    child: Icon(
                      _unreadCount > 0 ? Icons.notifications : Icons.notifications_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD62828), // Red for urgency
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          _unreadCount > 99 ? '99+' : '$_unreadCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationStatusCard() {
    final bloodGroup = _userProfile?.bloodGroup ?? '--';
    final totalDonations = _userProfile?.totalDonations ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.softPink.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Left Side - Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Your blood type is',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bloodGroup,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '$totalDonations donation${totalDonations == 1 ? '' : 's'} made',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.myDonations);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'View →',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Right Side - Blood Type Display
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.water_drop, color: Colors.white, size: 32),
                Text(
                  bloodGroup,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildQuickSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchScreen(),
            ),
          );
        },
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search donors or blood requests...',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    // SOS button is only available for patients
    final List<Map<String, dynamic>> _quickActions = [
      {
        'title': 'Donate Now',
        'icon': Icons.bloodtype,
        'route': '/donate',
      },
      {
        'title': 'Nearby Requests',
        'icon': Icons.location_on,
        'route': '/nearby',
      },
      {
        'title': 'My Donations',
        'icon': Icons.volunteer_activism,
        'route': '/my-donations',
      },
    ];

    // Add SOS button only for patients
    if (_roleProvider?.isPatient == true) {
      _quickActions.add({
        'title': 'SOS',
        'icon': Icons.sos,
        'route': '/sos',
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(
          _quickActions.length,
          (index) {
            final action = _quickActions[index];
            return Expanded(
              key: ValueKey('quick_action_$index'),
              child: _QuickActionButton(
                title: action['title'] as String,
                icon: action['icon'] as IconData,
                onTap: () {
                  // Handle navigation
                  final route = action['route'] as String;
                  if (route == '/sos') {
                    Navigator.pushNamed(context, AppRoutes.sos);
                  } else if (route == '/nearby') {
                    Navigator.pushNamed(context, AppRoutes.nearbyRequests);
                  } else if (route == '/my-donations') {
                    Navigator.pushNamed(context, AppRoutes.myDonations);
                  } else {
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUrgentRequestsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Nearby blood requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.nearbyRequests);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 24),
            ),
            child: const Text(
              'View all',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentRequests() {
    if (_isLoadingRequests) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_nearbyRequests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'No urgent requests nearby',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.nearbyRequests);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Browse All Requests'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(
          _nearbyRequests.length,
          (index) {
            final request = _nearbyRequests[index];
            return _BloodRequestCard(
              key: ValueKey('request_${request.id}'),
              request: request,
              timeAgo: _getTimeAgo(request.createdAt),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BloodRequestDetailScreen(
                      requestId: request.id,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return UnifiedBottomNavigationBar(
      selectedIndex: _selectedTabIndex,
      onItemTapped: (index) {
        setState(() => _selectedTabIndex = index);
        // Routes based on bottom nav: 0=Home, 1=Request, 2=Chat, 3=Profile
        switch (index) {
          case 0: // Home
            Navigator.pushReplacementNamed(context, AppRoutes.home);
            break;
          case 1: // Request
            Navigator.pushReplacementNamed(context, AppRoutes.nearbyRequests);
            break;
          case 2: // Chat (Messages)
            Navigator.pushReplacementNamed(context, AppRoutes.messages);
            break;
          case 3: // Profile (Settings)
            Navigator.pushReplacementNamed(context, AppRoutes.settings);
            break;
        }
      },
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, {Key? key}) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      key: key,
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
        // Handle navigation based on index
        switch (index) {
          case 0:
            // Already on Home - navigate to home (refresh/pop to home)
            Navigator.pushReplacementNamed(context, AppRoutes.home);
            break;
          case 1:
            Navigator.pushReplacementNamed(context, AppRoutes.nearbyRequests);
            break;
          case 2:
            // Navigate based on role
            // - Patients: Nearby Donors Map (to find donors)
            // - Donors: Nearby Requests (to find blood requests)
            if (_roleProvider?.isPatient == true) {
              Navigator.pushNamed(context, AppRoutes.nearbyDonorsMap);
            } else {
              Navigator.pushReplacementNamed(context, AppRoutes.nearbyRequests);
            }
            break;
          case 3:
            Navigator.pushReplacementNamed(context, AppRoutes.messages);
            break;
          case 4:
            // Navigate to Settings (Profile/Settings)
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

class _QuickActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.softPink.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BloodRequestCard extends StatelessWidget {
  final BloodRequest request;
  final String timeAgo;
  final VoidCallback onTap;

  const _BloodRequestCard({
    super.key,
    required this.request,
    required this.timeAgo,
    required this.onTap,
  });

  Color _getUrgencyColor(String urgencyLevel) {
    switch (urgencyLevel.toLowerCase()) {
      case 'critical':
        return const Color(0xFFD62828);
      case 'urgent':
        return const Color(0xFFE85D04);
      case 'normal':
        return const Color(0xFFFFA726);
      default:
        return AppColors.primary;
    }
  }

  IconData _getUrgencyIcon(String urgencyLevel) {
    switch (urgencyLevel.toLowerCase()) {
      case 'critical':
        return Icons.crisis_alert;
      case 'urgent':
        return Icons.priority_high;
      case 'normal':
        return Icons.hourglass_empty;
      default:
        return Icons.bloodtype;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urgencyColor = _getUrgencyColor(request.urgencyLevel);
    final urgencyIcon = _getUrgencyIcon(request.urgencyLevel);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: urgencyLevelToColor(request.urgencyLevel),
            width: urgencyLevelToWidth(request.urgencyLevel),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Blood Type Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      request.bloodGroup,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (request.urgencyLevel.toLowerCase() == 'critical')
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD600),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Text(
                          'Urgent',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Request Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Name
                  Text(
                    request.patientName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Location Row
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          request.hospitalName != null && request.hospitalName!.isNotEmpty
                              ? request.hospitalName!
                              : (request.location != null && request.location!.isNotEmpty
                                  ? request.location!
                                  : 'Location specified'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Time and Units Row
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5))),
                      const SizedBox(width: 8),
                      Text(
                        '${request.unitsNeeded} unit${request.unitsNeeded > 1 ? 's' : ''} needed',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Urgency Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: urgencyColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              urgencyIcon,
                              size: 9,
                              color: urgencyColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              request.urgencyLevel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: urgencyColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow Icon
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Color urgencyLevelToColor(String urgencyLevel) {
    switch (urgencyLevel.toLowerCase()) {
      case 'critical':
        return const Color(0xFFD62828);
      case 'urgent':
        return const Color(0xFFE85D04);
      default:
        return AppColors.border;
    }
  }

  double urgencyLevelToWidth(String urgencyLevel) {
    switch (urgencyLevel.toLowerCase()) {
      case 'critical':
        return 2.0;
      case 'urgent':
        return 1.5;
      default:
        return 1.0;
    }
  }
}
