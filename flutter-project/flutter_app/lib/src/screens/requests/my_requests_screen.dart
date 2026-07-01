import 'package:flutter/material.dart';
import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/blood_request.dart';
import '../../widgets/bottom_navigation_bar.dart';
import 'blood_request_detail_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  int _selectedTab = 0; // 0: Active, 1: Completed, 2: All
  bool _isLoading = true;
  BloodRequestListResponse? _requestsResponse;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  String _getStatusFilter() {
    switch (_selectedTab) {
      case 0: // Active
        return 'active';
      case 1: // Completed
        return 'completed';
      case 2: // All
      default:
        return 'all';
    }
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statusFilter = _getStatusFilter();
      final response = await ApiService.getMyBloodRequests(status: statusFilter);

      if (mounted) {
        setState(() {
          _requestsResponse = response;
          _isLoading = false;
          if (!response.success) {
            _errorMessage = response.message;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load requests';
        });
      }
    }
  }

  List<BloodRequest> get _filteredRequests {
    if (_requestsResponse == null) return [];
    // Backend handles the filtering now based on status parameter
    return _requestsResponse!.bloodRequests;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'critical':
        return const Color(0xFFD62828);
      case 'urgent':
        return const Color(0xFFE85D04);
      case 'normal':
        return const Color(0xFFFFB74D);
      case 'fulfilled':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFF757575);
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getStatusBackgroundColor(String urgencyLevel) {
    switch (urgencyLevel.toLowerCase()) {
      case 'critical':
        return const Color(0xFFFFEBEE);
      case 'urgent':
        return const Color(0xFFFFF3E0);
      case 'normal':
        return const Color(0xFFFFF8E1);
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getStatusTextColor(String urgencyLevel) {
    switch (urgencyLevel.toLowerCase()) {
      case 'critical':
        return const Color(0xFFD62828);
      case 'urgent':
        return const Color(0xFFE85D04);
      case 'normal':
        return const Color(0xFFF57C00);
      default:
        return AppColors.textSecondary;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
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
            // Header
            _buildHeader(),

            // Tab Navigation
            _buildTabNavigation(),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _filteredRequests.isEmpty
                          ? _buildEmptyState()
                          : _buildRequestList(),
            ),

            // Bottom Navigation
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // Back Arrow
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.softPink.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'My Requests',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Refresh button
          GestureDetector(
            onTap: _loadRequests,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.softPink.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabNavigation() {
    return Column(
      children: [
        // Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildTab('Active', 0),
              _buildTab('Completed', 1),
              _buildTab('All', 2),
            ],
          ),
        ),
        // Divider
        const Divider(height: 1, thickness: 1, color: AppColors.border),
      ],
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTab != index) {
            setState(() {
              _selectedTab = index;
            });
            // Reload requests with new status filter
            _loadRequests();
          }
        },
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            // Indicator line
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.urgencyCritical,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Failed to load requests',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadRequests,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No ${_selectedTab == 0 ? 'active' : _selectedTab == 1 ? 'completed' : ''} requests',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _filteredRequests.length,
      itemBuilder: (context, index) {
        final request = _filteredRequests[index];
        return _RequestCard(
          request: request,
          statusBackgroundColor: _getStatusBackgroundColor(request.urgencyLevel),
          statusTextColor: _getStatusTextColor(request.urgencyLevel),
          onTap: () {
            // Navigate to detail screen with request ID
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
    );
  }

  Widget _buildBottomNavigation() {
    return UnifiedBottomNavigationBar(
      selectedIndex: 1, // Requests is index 1
      onItemTapped: (index) {
        // Handle navigation with 4-item nav: 0=Home, 1=Request, 2=Chat, 3=Profile
        switch (index) {
          case 0: // Home
            Navigator.pushReplacementNamed(context, AppRoutes.home);
            break;
          case 1: // Requests - already here
            Navigator.pushReplacementNamed(context, AppRoutes.myRequests);
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
}

class _RequestCard extends StatelessWidget {
  final BloodRequest request;
  final Color statusBackgroundColor;
  final Color statusTextColor;
  final VoidCallback onTap;

  const _RequestCard({
    required this.request,
    required this.statusBackgroundColor,
    required this.statusTextColor,
    required this.onTap,
  });

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
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
            // Blood Type Badge
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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

            // Info Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Units and Status Row
                  Row(
                    children: [
                      Text(
                        '${request.unitsNeeded} Unit${request.unitsNeeded > 1 ? 's' : ''} Needed',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          request.urgencyLevel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Hospital and Location
                  Text(
                    request.hospitalName != null && request.hospitalName!.isNotEmpty
                        ? '${request.hospitalName}${request.location != null && request.location!.isNotEmpty ? ', ${request.location}' : ''}'
                        : request.location ?? 'No location specified',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Patient and Time
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          request.patientName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getTimeAgo(request.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
}
