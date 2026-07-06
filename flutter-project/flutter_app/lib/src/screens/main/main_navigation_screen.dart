import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../providers/role_provider.dart';
import '../../services/api_service.dart';
import '../../services/firebase_chat_service.dart';
import '../../services/notification_service.dart';
import '../../models/profile.dart';
import '../../models/blood_request.dart';
import '../../widgets/bottom_navigation_bar.dart';
import '../chat/chat_conversation_screen.dart';
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
  bool _isAcceptingPledge = false; // Add flag to prevent double clicks

  // Blood requests data
  BloodRequestListResponse? _requestsResponse;
  bool _isLoadingRequests = true;

  // Responding donors data (for patients)
  List<Map<String, dynamic>> _respondingDonors = [];
  bool _isLoadingDonors = true;
  int _totalDonorsCount = 0;

  // Notification data
  int _unreadCount = 0;
  int _chatUnreadCount = 0;

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

    // Initialize push notifications
    try {
      await NotificationService().initialize();
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize NotificationService: $e');
    }

    // Load role if not already loaded
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);

    // ALWAYS fetch from API to ensure we have the current user's role
    // This prevents showing the previous user's role when logging in with a different account
    await roleProvider.fetchUserRole();

    // If still no role after fetching, user can still use the app
    // Role selection has been removed - app works without specific role

    // Check if donor has completed health eligibility quiz
    if (mounted && !roleProvider.isPatient) {
      await _checkDonorEligibility();
    }

    if (mounted) {
      _loadData();
      _loadUnreadCount();
      _loadChatUnreadCount();
    }
  }

  Future<void> _checkDonorEligibility() async {
    try {
      final result = await ApiService.getHealthEligibilityStatus();

      if (result['success'] == true) {
        final eligibility = result['eligibility'] as Map<String, dynamic>? ?? {};
        final isStillValid = result['is_still_valid'] as bool? ?? true;
        final healthQuizCompleted = eligibility['health_quiz_completed'] as bool? ?? false;

        // Debug logging
        print('DEBUG: Eligibility check result: $result');
        print('DEBUG: health_quiz_completed: $healthQuizCompleted');
        print('DEBUG: is_still_valid: $isStillValid');

        // If health quiz not completed or eligibility is not valid, redirect to quiz
        if (!healthQuizCompleted || !isStillValid) {
          if (mounted) {
            _showEligibilityRequiredDialog();
          }
        }
      } else {
        // API returned success=false
        print('DEBUG: Eligibility API returned success=false: ${result['message']}');
        if (mounted) {
          _showEligibilityRequiredDialog();
        }
      }
    } catch (e) {
      // Log error and show dialog to ensure user can complete quiz
      print('DEBUG: Eligibility check failed with error: $e');
      if (mounted) {
        _showEligibilityRequiredDialog();
      }
    }
  }

  void _showEligibilityRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.quiz,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Health Quiz Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Before you can start donating, please complete the health eligibility quiz. This helps ensure the safety of both donors and recipients.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to health eligibility quiz
                Navigator.pushReplacementNamed(context, AppRoutes.healthEligibilityQuiz);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Start Quiz',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
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
    }
  }

  Future<void> _loadChatUnreadCount() async {
    try {
      final result = await ApiService.getUnreadChatMessagesCount();
      if (result['success'] == true && mounted) {
        setState(() {
          _chatUnreadCount = result['unread_count'] as int? ?? 0;
        });
      }
    } catch (e) {
      // Silently fail - chat unread count is not critical
    }
  }

  Future<void> _loadData() async {
    // Reset state to ensure fresh data is loaded
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isLoadingRequests = true;
      _isLoadingDonors = true;
      _errorMessage = null;
      _userProfile = null; // Clear previous profile
      _respondingDonors = [];
    });

    try {
      final roleProvider = Provider.of<RoleProvider>(context, listen: false);

      // Load profile and base data in parallel
      final baseResults = await Future.wait([
        ApiService.getProfile(),
        ApiService.getBloodRequests(status: 'pending'),
      ]);

      if (mounted) {
        setState(() {
          // Process profile
          final profileResult = baseResults[0] as Map<String, dynamic>;
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
          _requestsResponse = baseResults[1] as BloodRequestListResponse;
          _isLoadingRequests = false;
        });

        // Load responding donors if patient
        if (roleProvider.isPatient) {
          await _loadRespondingDonors();
        } else {
          setState(() {
            _isLoadingDonors = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          _isLoadingRequests = false;
          _isLoadingDonors = false;
        });
      }
    }
  }

  Future<void> _loadRespondingDonors() async {
    try {
      final result = await ApiService.getRespondingDonorsForPatient();

      if (result['success'] == true && mounted) {
        final donors = result['donors'] as List? ?? [];
        final summary = result['summary'] as Map<String, dynamic>? ?? {};

        setState(() {
          _respondingDonors = donors.map((d) => d as Map<String, dynamic>).toList();
          _totalDonorsCount = summary['total_donors'] as int? ?? 0;
          _isLoadingDonors = false;
        });
      } else {
        setState(() {
          _respondingDonors = [];
          _totalDonorsCount = 0;
          _isLoadingDonors = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _respondingDonors = [];
          _totalDonorsCount = 0;
          _isLoadingDonors = false;
        });
      }
    }
  }

  Future<void> _acceptPledge(Map<String, dynamic> donorData) async {
    // Prevent double clicks
    if (_isAcceptingPledge) {
      return;
    }

    try {
      // Debug: Print donorData structure
      print('DEBUG: donorData = $donorData');

      final donor = donorData['donor'] as Map<String, dynamic>;
      final requestId = donorData['request_id'] as String;
      final pledgeId = donorData['pledge_id'] as String;

      print('DEBUG: requestId = $requestId');
      print('DEBUG: pledgeId = $pledgeId');

      if (requestId.isEmpty || pledgeId.isEmpty) {
        throw Exception('Invalid request ID or pledge ID');
      }

      setState(() {
        _isAcceptingPledge = true;
      });

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Accepting pledge...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Call the accept pledge API
      final response = await ApiService.acceptPledge(
        requestId: requestId,
        pledgeId: pledgeId,
      );

      print('DEBUG: API response = $response');

      if (mounted) {
        if (response['success'] == true) {
          // Refresh the responding donors list and blood requests
          await _loadRespondingDonors();
          await _loadData();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pledge accepted! You can now chat with the donor.'),
              backgroundColor: Colors.green,
            ),
          );

          // Optionally open chat after accepting
          // await _openChatWithDonor(donorData);
        } else {
          // Check if error is about already confirmed pledge
          final message = response['message']?.toString() ?? 'Failed to accept pledge';
          print('DEBUG: Error message = $message');

          if (message.contains('Cannot accept pledge') || message.contains('already')) {
            // Refresh to show current state
            await _loadRespondingDonors();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This pledge has already been accepted.'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('DEBUG: Exception = $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAcceptingPledge = false;
        });
      }
    }
  }

  Future<void> _openChatWithDonor(Map<String, dynamic> donorData) async {
    try {
      final donor = donorData['donor'] as Map<String, dynamic>;
      final pledge = donorData['pledge'] as Map<String, dynamic>;
      final requestId = donorData['request_id'] as String;
      final donorId = donor['id'] as String;
      final donorName = donor['name'] as String? ?? 'Donor';
      final patientName = donorData['patient_name'] as String? ?? 'Patient';

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Opening chat...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get current user ID
      final profile = await ApiService.getProfile();
      if (profile['success'] != true) {
        throw Exception('Failed to get user profile');
      }

      final patientId = profile['data']['user']?['id']?.toString();
      if (patientId == null) {
        throw Exception('User ID not found');
      }

      // Initialize Firebase chat service
      await FirebaseChatService.initialize();

      // Get or create conversation
      final conversation = await FirebaseChatService.instance.getOrCreateConversation(
        requestId: requestId,
        patientId: patientId,
        patientName: patientName,
        donorId: donorId,
        donorName: donorName,
      );

      if (mounted) {
        // Navigate to chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(
              conversation: conversation,
              currentUserId: patientId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
            floatingActionButton: _buildAIHelpButton(),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

          // Responding Donors Section (NEW)
          _buildRespondingDonorsSection(),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Hi, $userName 👋',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          // Notification Bell with badge
          GestureDetector(
            onTap: () async {
              await Navigator.pushNamed(context, AppRoutes.notifications);
              // Refresh unread count when returning
              _loadUnreadCount();
              _loadChatUnreadCount();
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
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
            onTap: () async {
              await Navigator.pushNamed(context, AppRoutes.notifications);
              // Refresh unread count when returning
              _loadUnreadCount();
              _loadChatUnreadCount();
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
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
    // For patients, show only their own requests
    // For donors, show all active requests
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);

    final activeRequests = _requestsResponse?.bloodRequests
            .where((r) {
              // Filter by active and pending status
              if (!r.isActive || r.status != 'pending') return false;

              // If patient, only show their own requests
              if (roleProvider.isPatient) {
                return r.requestedById == _userProfile?.id;
              }

              // Donors see all active requests
              return true;
            })
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

  /// Responding Donors Section (for patients)
  Widget _buildRespondingDonorsSection() {
    if (_isLoadingDonors) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Responding Donors',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_totalDonorsCount > 0)
                    Text(
                      '$_totalDonorsCount donor${_totalDonorsCount > 1 ? 's' : ''} responding',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              if (_totalDonorsCount > 0)
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.myRequests);
                  },
                  child: const Text('View all'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Donor Cards or Empty State
        if (_respondingDonors.isEmpty)
          _buildEmptyDonorsCard()
        else
          ..._respondingDonors.take(5).map((donorData) => _buildDonorCard(donorData)),
      ],
    );
  }

  /// Empty donors card
  Widget _buildEmptyDonorsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'No responding donors yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Donors who respond to your requests will appear here',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Donor card for responding donors section
  Widget _buildDonorCard(Map<String, dynamic> donorData) {
    final donor = donorData['donor'] as Map<String, dynamic>;
    final pledge = donorData['pledge'] as Map<String, dynamic>;

    // Get status color and icon
    Color statusColor;
    IconData statusIcon;
    String statusLabel = pledge['status_display'] as String? ?? 'Unknown';

    switch (pledge['status'] as String? ?? '') {
      case 'pledged':
        statusColor = Colors.orange;
        statusIcon = Icons.volunteer_activism;
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'on_the_way':
        statusColor = Colors.blue;
        statusIcon = Icons.directions_walk;
        break;
      case 'arrived':
      case 'ready':
        statusColor = Colors.purple;
        statusIcon = Icons.location_on;
        break;
      case 'completed':
        statusColor = AppColors.primary;
        statusIcon = Icons.favorite;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    // Parse preferred date and time from note
    final note = pledge['note'] as String? ?? '';
    String? preferredDateTime;
    String displayNote = note;

    // Try to match "Preferred time: HH:MM AM/PM" (12-hour format) first
    final timeMatch12 = RegExp(r'Preferred time: (\d{1,2}:\d{2} [AP]M)', caseSensitive: false).firstMatch(note);
    if (timeMatch12 != null) {
      preferredDateTime = timeMatch12.group(1);
      // Remove the time line from the note for cleaner display
      displayNote = note.replaceAll(RegExp(r'Preferred time: \d{1,2}:\d{2} [AP]M', caseSensitive: false), '').trim();
    } else {
      // Fallback to 24-hour format "Preferred time: HH:MM" (for older pledges)
      final timeMatch24 = RegExp(r'Preferred time: (\d{2}:\d{2})').firstMatch(note);
      if (timeMatch24 != null) {
        final timeStr = timeMatch24.group(1)!;
        // Convert 24-hour format to 12-hour format with AM/PM
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour < 12 ? 'AM' : 'PM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        preferredDateTime = '${displayHour.toString().padLeft(2, '0')}:$minute $period';

        // Remove the time line from the note for cleaner display
        displayNote = note.replaceAll(RegExp(r'Preferred time: \d{2}:\d{2}'), '').trim();
      }
    }

    // Clean up any double newlines left after removing time
    if (displayNote.startsWith('\n\n')) {
      displayNote = displayNote.substring(2);
    }
    if (displayNote.endsWith('\n\n')) {
      displayNote = displayNote.substring(0, displayNote.length - 2);
    }

    // Use preferred time if available (from note), otherwise use pledge created date
    String formattedDate = preferredDateTime ?? '';

    // If no preferred time found, show pledge date/time instead
    if (formattedDate.isEmpty && pledge['created_at'] != null) {
      try {
        final createdAt = DateTime.parse(pledge['created_at'] as String);
        final now = DateTime.now();
        final difference = now.difference(createdAt);

        // Format as relative time (e.g., "2 hours ago")
        if (difference.inMinutes < 60) {
          formattedDate = '${difference.inMinutes} min ago';
        } else if (difference.inHours < 24) {
          formattedDate = '${difference.inHours} hours ago';
        } else if (difference.inDays < 7) {
          formattedDate = '${difference.inDays} days ago';
        } else {
          formattedDate = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
        }
      } catch (e) {
        formattedDate = 'Unknown';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            // Handle all "accepted" statuses (confirmed, on_the_way, arrived, ready)
            color: ['confirmed', 'on_the_way', 'arrived', 'ready'].contains(pledge['status'])
                ? Colors.green.withOpacity(0.3)
                : AppColors.border,
            width: ['confirmed', 'on_the_way', 'arrived', 'ready'].contains(pledge['status']) ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Donor info row
            Row(
              children: [
                // Blood group badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    donor['blood_group'] as String? ?? '--',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Donor name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        donor['name'] as String? ?? 'Unknown Donor',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (donor['city'] != null)
                        Text(
                          donor['city'] as String? ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Preferred date/time row
            if (formattedDate.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      preferredDateTime != null ? 'Preferred: $formattedDate' : 'Pledged: $formattedDate',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    // Show units pledged (blood pint)
                    if (pledge['units_pledged'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade200, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bloodtype, size: 14, color: Colors.red.shade700),
                            const SizedBox(width: 4),
                            Text(
                              '${pledge['units_pledged']} unit${pledge['units_pledged'] == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            if (formattedDate.isNotEmpty && displayNote.isNotEmpty)
              const SizedBox(height: 8),

            // Pledge note (excluding time)
            if (displayNote.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softPink.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  displayNote,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Action buttons - wrap to two rows if needed
            if (pledge['can_accept'] as bool? ?? false)
              // Show accept button prominently on its own row when available
              Column(
                children: [
                  // Accept button (full width)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptPledge(donorData),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept Pledge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Secondary actions (Call and Chat)
                  Row(
                    children: [
                      // Call button
                      if (donor['phone'] != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // TODO: Implement call functionality
                            },
                            icon: const Icon(Icons.call, size: 16),
                            label: const Text('Call'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      if (donor['phone'] != null) const SizedBox(width: 8),
                      // Chat button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openChatWithDonor(donorData),
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: const Text('Chat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              // Show Call and Chat buttons in one row when accept is not available
              Row(
                children: [
                  // Call button
                  if (donor['phone'] != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Implement call functionality
                        },
                        icon: const Icon(Icons.call, size: 16),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (donor['phone'] != null) const SizedBox(width: 8),
                  // Chat button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openChatWithDonor(donorData),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
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
            onTap: () async {
              await Navigator.pushNamed(context, AppRoutes.notifications);
              // Refresh unread count when returning
              _loadUnreadCount();
              _loadChatUnreadCount();
            },
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
                  if (_unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
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
              onPressed: () => Navigator.pushNamed(context, AppRoutes.nearbyDonorsMap),
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
            title: 'SOS',
            icon: Icons.sos,
            onTap: () => Navigator.pushNamed(context, AppRoutes.sos),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            title: 'SOS Active',
            icon: Icons.notifications_active,
            onTap: () => Navigator.pushNamed(context, AppRoutes.sosActive),
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

  Widget _buildAIHelpButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, AppRoutes.aiChatbot),
          customBorder: const CircleBorder(),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(height: 2),
              Text(
                'AI Help',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
        case AppRoutes.messages:
          return 2;
        case AppRoutes.chatList:
          return 2;
        case AppRoutes.settings:
          return 3;
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
      chatUnreadCount: _chatUnreadCount,
      onItemTapped: (index) {
        // Handle navigation taps explicitly
        switch (index) {
          case 0: // Home
            Navigator.pushReplacementNamed(context, AppRoutes.home);
            break;
          case 1: // Requests
            Navigator.pushReplacementNamed(context, getRequestsRoute());
            break;
          case 2: // Chat/Messages
            Navigator.pushReplacementNamed(context, AppRoutes.messages);
            break;
          case 3: // Profile/Settings
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
