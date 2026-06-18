import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../providers/role_provider.dart';
import '../../services/api_service.dart';
import '../../models/profile.dart';
import '../../models/blood_request.dart';
import '../../widgets/bottom_navigation_bar.dart';
import '../donors/donor_profile_screen.dart';
import '../requests/blood_request_detail_screen.dart';
import '../role/role_switch_screen.dart';
import '../search/search_screen.dart';

/// Unified main navigation screen that adapts based on user's current role
/// Single login, role switching, and context-aware UI
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  Profile? _userProfile;
  String? _errorMessage;
  RoleProvider? _roleProvider;

  // Blood requests data
  BloodRequestListResponse? _requestsResponse;
  bool _isLoadingRequests = true;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to role provider changes
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);
    if (_roleProvider != roleProvider) {
      _roleProvider?.removeListener(_onRoleChanged);
      _roleProvider = roleProvider;
      _roleProvider!.addListener(_onRoleChanged);
    }
  }

  @override
  void dispose() {
    _roleProvider?.removeListener(_onRoleChanged);
    super.dispose();
  }

  void _onRoleChanged() {
    // Reload profile data when role changes
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _checkAuthAndLoadData() async {
    // Check authentication
    final isAuthenticated = await ApiService.isAuthenticated();
    if (!isAuthenticated && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    // Load role if not already loaded
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);

    // ALWAYS fetch from API to ensure we have the current user's role
    // This prevents showing the previous user's role when logging in with a different account
    await roleProvider.fetchUserRole();

    // If still no role after fetching, user can still use the app
    // Role selection has been removed - app works without specific role

    if (mounted) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    // Reset state to ensure fresh data is loaded
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isLoadingRequests = true;
      _errorMessage = null;
      _userProfile = null; // Clear previous profile
    });

    try {
      // Load profile and requests in parallel
      final results = await Future.wait([
        ApiService.getProfile(),
        ApiService.getBloodRequests(status: 'pending'),
      ]);

      if (mounted) {
        setState(() {
          // Process profile
          final profileResult = results[0] as Map<String, dynamic>;
          if (profileResult['success'] == true) {
            final data = profileResult['data'];
            // Check if profile exists (for donors) or only user data (for patients)
            if (data.containsKey('profile') && data['profile'] != null) {
              _userProfile = Profile.fromJson(data['profile']);
            } else if (data.containsKey('user') && data['user'] != null) {
              // Create minimal profile from user data for patients
              _userProfile = Profile(
                id: data['user']['id']?.toString(),
                userFullName: data['user']['full_name']?.toString(),
                email: data['user']['email']?.toString(),
                role: data['user']['role']?.toString(),
              );
            }
          } else {
            _errorMessage = profileResult['message'];
          }
          _isLoading = false;

          // Process blood requests
          _requestsResponse = results[1] as BloodRequestListResponse;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          _isLoadingRequests = false;
        });
      }
    }
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, child) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) async {
            // Only handle if we successfully popped
            if (!didPop) return;

            // Note: This callback is called AFTER the pop happens
            // We can't prevent pops here, but we can track the state
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: _isLoading
                  ? _buildLoadingScreen()
                  : _buildBody(roleProvider),
            ),
            bottomNavigationBar: _buildBottomNavigation(roleProvider),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(RoleProvider roleProvider) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildBody(RoleProvider roleProvider) {

    if (roleProvider.isDonor) {
      return _buildDonorContent();
    } else if (roleProvider.isPatient) {
      return _buildPatientContent();
    } else {
      return _buildNoRoleContent();
    }
  }

  /// Donor Mode Content
  Widget _buildDonorContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with greeting
          _buildGreetingHeader(),
          const SizedBox(height: 16),

          // Blood Type Card
          _buildBloodTypeCard(),
          const SizedBox(height: 20),

          // Quick Actions
          _buildSectionTitle('Quick Actions'),
          const SizedBox(height: 12),
          _buildQuickActions(),
          const SizedBox(height: 20),

          // Nearby Requests (Donors can see requests to respond to)
          _buildUrgentRequestsHeader(),
          const SizedBox(height: 12),
          _buildUrgentRequests(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Patient Mode Content
  Widget _buildPatientContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with greeting and profile picture
          _buildNewPatientHeader(),
          const SizedBox(height: 20),

          // Request Blood Button
          _buildRequestBloodButton(),
          const SizedBox(height: 20),

          // Quick Actions for Patients
          _buildSectionTitle('Quick Actions'),
          const SizedBox(height: 12),
          _buildPatientQuickActions(),
          const SizedBox(height: 20),

          // Active Blood Requests Section
          _buildActiveRequestsSection(),
          const SizedBox(height: 80), // Bottom nav spacing
        ],
      ),
    );
  }

  /// Show when no role is selected
  Widget _buildNoRoleContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Role Selected',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please select a role to continue',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showRoleSwitchBottomSheet(context, Provider.of<RoleProvider>(context, listen: false)),
              icon: const Icon(Icons.person_search),
              label: const Text('Select Role'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingHeader() {
    final userName = _userProfile?.userFullName ?? 'Guest';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'Hi, $userName 👋',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildBloodTypeCard() {
    final bloodGroup = _userProfile?.bloodGroup ?? '--';
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);

    return GestureDetector(
      onTap: () {
        if (_userProfile != null) {
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
                  'about': roleProvider.isDonor ? 'Blood donor - ready to save lives!' : 'Patient',
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
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleProvider.isDonor
                        ? 'Your blood type is'
                        : 'Blood type reference',
                    style: const TextStyle(
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
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.red,
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
      ),
    );
  }

  /// New Patient Header - redesigned
  Widget _buildNewPatientHeader() {
    final userName = _userProfile?.userFullName ?? 'Patient';
    final profilePicture = _userProfile?.profilePictureUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Profile Icon - red circle with person silhouette
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Greeting and Tagline
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $userName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text(
                  'Every drop counts.',
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
            onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Request Blood Button - prominent CTA
  Widget _buildRequestBloodButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, AppRoutes.bloodRequestForm),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Plus icon in red circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Title and Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request Blood',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Need blood? Tell us what you need and we\'ll help you find donors.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Blood drop icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.water_drop,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Active Blood Requests Section
  Widget _buildActiveRequestsSection() {
    final activeRequests = _requestsResponse?.bloodRequests
            .where((r) => r.isActive && r.status == 'pending')
            .toList() ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active blood requests',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.myRequests),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Request Cards
        if (activeRequests.isEmpty)
          _buildEmptyRequestsCard()
        else
          ...activeRequests.take(3).map((request) => Container(
                key: ValueKey('request_card_${request.id}'),
                child: _buildRequestCard(request),
              )),
      ],
    );
  }

  Widget _buildEmptyRequestsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No active requests',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(BloodRequest request) {
    // Determine urgency level
    String urgency;
    Color urgencyColor;
    IconData urgencyIcon;

    if (request.urgencyLevel == 'critical') {
      urgency = 'CRITICAL';
      urgencyColor = AppColors.urgencyCritical;
      urgencyIcon = Icons.favorite;
    } else if (request.urgencyLevel == 'urgent') {
      urgency = 'URGENT';
      urgencyColor = AppColors.urgencyUrgent;
      urgencyIcon = Icons.warning;
    } else {
      urgency = 'NORMAL';
      urgencyColor = AppColors.urgencyNormal;
      urgencyIcon = Icons.info;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
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
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Urgency Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  urgencyIcon,
                  color: urgencyColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Request Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request for ${request.bloodGroup}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${request.unitsNeeded} Unit${request.unitsNeeded > 1 ? 's' : ''} • ${request.hospitalName ?? request.location ?? "Location specified"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Urgency Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: urgencyColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  urgency,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
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

  /// Patient-specific header with profile picture
  Widget _buildPatientHeader() {
    final userName = _userProfile?.userFullName ?? 'Guest';
    final profilePicture = _userProfile?.profilePictureUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Profile Picture
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
            child: Container(
              width: 56,
              height: 56,
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
          const SizedBox(width: 16),

          // Greeting and Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hi,',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Notification Bell
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.softPink.withOpacity(0.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
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

  /// Nearby blood requests section for patients
  Widget _buildNearbyRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Nearby Donors',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.findDonors),
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Donors list preview
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.softPink,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Donor',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'A+',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
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
              const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search donors or blood requests...',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _QuickActionButton(
            key: const ValueKey('action_donate'),
            title: 'Donate',
            icon: Icons.bloodtype,
            onTap: () => Navigator.pushNamed(context, AppRoutes.myDonations),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            key: const ValueKey('action_requests'),
            title: 'Requests',
            icon: Icons.location_on,
            onTap: () => Navigator.pushNamed(context, AppRoutes.nearbyRequests),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            key: const ValueKey('action_ai_help'),
            title: 'AI Help',
            icon: Icons.smart_toy_outlined,
            onTap: () => Navigator.pushNamed(context, AppRoutes.aiChatbot),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            key: const ValueKey('action_chat'),
            title: 'Chat',
            icon: Icons.message,
            onTap: () => Navigator.pushNamed(context, AppRoutes.messages),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _QuickActionButton(
            title: 'Request',
            icon: Icons.add_circle,
            onTap: () => Navigator.pushNamed(context, AppRoutes.bloodRequestForm),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            title: 'Chat',
            icon: Icons.message,
            onTap: () => Navigator.pushNamed(context, AppRoutes.messages),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            title: 'AI Help',
            icon: Icons.smart_toy_outlined,
            onTap: () => Navigator.pushNamed(context, AppRoutes.aiChatbot),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            title: 'SOS',
            icon: Icons.sos,
            onTap: () => Navigator.pushNamed(context, AppRoutes.sos),
          ),
        ],
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
            'Nearby Requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.nearbyRequests),
            child: const Text('View all'),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentRequests() {
    if (_isLoadingRequests) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final nearbyRequests = _requestsResponse?.bloodRequests
            .where((r) => r.isActive && r.status == 'pending')
            .toList() ??
        [];

    if (nearbyRequests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('No urgent requests nearby'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: nearbyRequests.take(3).map((request) {
          return _BloodRequestCard(
            request: request,
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
        }).toList(),
      ),
    );
  }

  Widget _buildMyRequestsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Blood Requests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.myRequests),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('Tap "View all" to see your requests'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(RoleProvider roleProvider) {
    // Determine current route index based on role
    int getCurrentIndex() {
      final currentRoute = ModalRoute.of(context)?.settings.name;

      // Default to Home (index 0) if route is null or unrecognized
      if (currentRoute == null || currentRoute == AppRoutes.mainNavigation) {
        return 0;
      }

      switch (currentRoute) {
        case AppRoutes.home:
          return 0;
        case AppRoutes.nearbyRequests:
          // Donors use nearby requests (index 1)
          return 1;
        case AppRoutes.myRequests:
          // Patients use my requests (index 1)
          return 1;
        case AppRoutes.findDonors:
          return 2;
        case AppRoutes.messages:
          return 3;
        case AppRoutes.chatList:
          return 3;
        case AppRoutes.settings:
          return 4;
        default:
          return 0;
      }
    }

    // Get the requests route based on role
    String getRequestsRoute() {
      return roleProvider.isPatient ? AppRoutes.myRequests : AppRoutes.nearbyRequests;
    }

    return UnifiedBottomNavigationBar(
      selectedIndex: getCurrentIndex(),
      onItemTapped: (index) {
        // Handle navigation taps explicitly
        switch (index) {
          case 0: // Home
            Navigator.pushReplacementNamed(context, AppRoutes.home);
            break;
          case 1: // Requests
            Navigator.pushReplacementNamed(context, getRequestsRoute());
            break;
          case 2: // Map
            Navigator.pushReplacementNamed(context, AppRoutes.findDonors);
            break;
          case 3: // Chat/Messages
            Navigator.pushReplacementNamed(context, AppRoutes.messages);
            break;
          case 4: // Profile/Settings
            Navigator.pushReplacementNamed(context, AppRoutes.settings);
            break;
        }
      },
    );
  }

  void _showRoleSwitchBottomSheet(BuildContext context, RoleProvider roleProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoleSwitchScreen(currentRole: roleProvider.currentRole ?? ''),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
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
                  color: AppColors.softPink.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BloodRequestCard extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback onTap;

  const _BloodRequestCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  request.bloodGroup,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${request.unitsNeeded} unit${request.unitsNeeded > 1 ? 's' : ''} needed',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.hospitalName ?? request.location ?? 'Location specified',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
