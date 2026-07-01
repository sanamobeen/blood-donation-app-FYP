import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/blood_request.dart';
import '../../widgets/bottom_navigation_bar.dart';
import '../requests/blood_request_detail_screen.dart';
import '../donors/donor_profile_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> with WidgetsBindingObserver {
  int _selectedTabIndex = 0; // Home tab is active

  // Loading state
  bool _isLoading = true;
  bool _isLoadingRequests = true;
  String? _errorMessage;

  // Blood requests data
  BloodRequestListResponse? _requestsResponse;

  // User profile data
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthAndLoadData();
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
      _checkAuthAndLoadData();
    }
  }

  // Also check auth when screen becomes visible (e.g., navigating back)

  Future<void> _checkAuthAndLoadData() async {
    // Check if user is authenticated
    final isAuthenticated = await ApiService.isAuthenticated();
    if (!isAuthenticated && mounted) {
      // Redirect to login if not authenticated
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingRequests = true;
      _errorMessage = null;
    });

    // Load requests and user profile in parallel
    final results = await Future.wait([
      ApiService.getMyBloodRequests(),
      ApiService.getProfile(),
    ]);

    if (mounted) {
      setState(() {
        // Process blood requests (already a BloodRequestListResponse)
        _requestsResponse = results[0] as BloodRequestListResponse;
        _isLoadingRequests = false;

        // Process user profile - handle different response structures
        final profileResult = results[1] as Map<String, dynamic>;
        if (profileResult['success'] == true) {
          // Try different possible paths for profile data
          if (profileResult['data'] is Map && profileResult['data']['profile'] != null) {
            _userProfile = profileResult['data']['profile'];
          } else if (profileResult['data'] is Map) {
            _userProfile = profileResult['data'];
          }
        }

        _isLoading = false;
      });
    }
  }

  List<BloodRequest> get _activeRequests {
    if (_requestsResponse == null) return [];
    final activeRequests = _requestsResponse!.bloodRequests
        .where((r) => r.isActive && (r.status == 'pending' || r.status == 'active'))
        .toList();
    // Return only the 3 most recent requests
    return activeRequests.take(3).toList();
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

                    // Request Blood CTA Card
                    _buildRequestBloodCTA(),
                    const SizedBox(height: 20),

                    // Quick Actions - My Donations
                    _buildQuickActions(),
                    const SizedBox(height: 20),

                    // Your Active Requests
                    _buildActiveRequestsSection(),
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

  Widget _buildHeader() {
    final userName = _userProfile?['user_full_name'] ?? _userProfile?['username'] ?? _userProfile?['name'] ?? 'Patient';
    final profilePicture = _userProfile?['profile_picture'] ?? _userProfile?['profilePictureUrl'];
    final bloodGroup = _userProfile?['blood_group'] ?? _userProfile?['bloodType'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Profile Picture
          GestureDetector(
            onTap: () {
              if (_userProfile != null) {
                // Navigate to user's profile
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DonorProfileScreen(
                      donor: {
                        'name': _userProfile!['user_full_name'] ?? _userProfile!['username'] ?? _userProfile!['name'],
                        'bloodType': _userProfile!['blood_group'] ?? _userProfile!['bloodType'],
                        'blood_group': _userProfile!['blood_group'] ?? _userProfile!['bloodType'],
                        'location': _userProfile!['city'],
                        'distance': '0',
                        'donations': _userProfile!['total_donations']?.toString() ?? '0',
                        'livesSaved': _userProfile!['total_donations']?.toString() ?? '0',
                        'lives_saved': _userProfile!['total_donations']?.toString() ?? '0',
                        'rating': '5.0',
                        'about': 'Blood donor - ready to save lives!',
                        'lastDonation': _userProfile!['last_donation'] ?? 'Not recorded',
                        'last_donation': _userProfile!['last_donation'] ?? 'Not recorded',
                        'image': _userProfile!['profile_picture'] ?? _userProfile!['profilePictureUrl'],
                        'profile_picture': _userProfile!['profile_picture'] ?? _userProfile!['profilePictureUrl'],
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
                  'Hello, $userName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bloodGroup != null ? 'Blood type: $bloodGroup' : 'Every drop counts.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Notification Bell
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.notifications);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.softPink.withValues(alpha: 0.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestBloodCTA() {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.bloodRequestForm);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Left Side - Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Request Blood',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Need blood? Tell us what you need\nand we\'ll help you find donors.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Right Side - Blood Drop Graphic
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bloodtype,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRequestsSection() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active blood requests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.myRequests);
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 24),
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Request Cards
        if (_isLoadingRequests)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          )
        else if (_activeRequests.isEmpty)
          _buildEmptyState()
        else
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _activeRequests.length,
              itemBuilder: (context, index) {
                final request = _activeRequests[index];
                return _RequestCard(
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
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'No active requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a blood request to find donors',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // My Donations Card
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.myDonations);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.1),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.volunteer_activism,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'My Donations',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View donation history & certificates',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // SOS Emergency Card
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.sos);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF5252).withValues(alpha: 0.15),
                      const Color(0xFFFF5252).withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.sos,
                        color: Color(0xFFFF5252),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'SOS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF5252),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Emergency blood request',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
        // Routes: 0=Home, 1=Request, 2=Find Donors (Map), 3=Profile
        switch (index) {
          case 0:
            // Already on Home
            break;
          case 1:
            // Navigate to My Requests
            Navigator.pushReplacementNamed(context, AppRoutes.myRequests);
            break;
          case 2:
            // Navigate to Nearby Donors Map (Find Donors)
            Navigator.pushReplacementNamed(context, AppRoutes.nearbyDonorsMap);
            break;
          case 3:
            // Navigate to Settings (Profile)
            Navigator.pushReplacementNamed(context, AppRoutes.settings);
            break;
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
            // Already on Home
            break;
          case 1:
            // Navigate to Create Request directly
            Navigator.pushNamed(context, AppRoutes.bloodRequestForm);
            break;
          case 2:
            // Navigate to My Requests
            Navigator.pushNamed(context, AppRoutes.myRequests);
            break;
          case 3:
            // Navigate to Messages/Chat
            Navigator.pushNamed(context, AppRoutes.messages);
            break;
          case 4:
            // Navigate to Profile/Settings
            Navigator.pushNamed(context, AppRoutes.settings);
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

class _RequestCard extends StatelessWidget {
  final BloodRequest request;
  final String timeAgo;
  final VoidCallback onTap;

  const _RequestCard({
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
        width: 250,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Profile Avatar with Blood Group Badge + Patient Name
            Row(
              children: [
                // Profile Avatar with Blood Group Badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.softPink,
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: ClipOval(
                        child: request.requesterProfilePicture != null && request.requesterProfilePicture!.isNotEmpty
                            ? Image.network(
                                request.requesterProfilePicture!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: AppColors.softPink,
                                    child: const Icon(Icons.person, color: AppColors.primary, size: 18),
                                  );
                                },
                              )
                            : const Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: 18,
                              ),
                      ),
                    ),
                    // Blood Group Badge
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          request.bloodGroup,
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                // Patient Name
                Expanded(
                  child: Text(
                    request.patientName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Details
            Text(
              '${request.unitsNeeded} Unit${request.unitsNeeded > 1 ? 's' : ''} • ${request.hospitalName ?? 'Location specified'}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Bottom Row: Status Badge + Subtext + Arrow
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        urgencyIcon,
                        size: 10,
                        color: urgencyColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        request.urgencyLevel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: urgencyColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timeAgo,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
