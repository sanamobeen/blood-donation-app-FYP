import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/firebase_chat_service.dart';
import '../../models/blood_request.dart';
import '../../models/donor_pledge.dart';
import '../../widgets/blood_request_progress_bar.dart';
import '../../widgets/pledged_donor_card.dart';
import '../../widgets/pledge_dialog.dart';
import '../../widgets/donor_map_view.dart';
import '../chat/chat_conversation_screen.dart';
import '../patient/patient_donor_management_screen.dart';

class BloodRequestDetailScreen extends StatefulWidget {
  final String requestId;

  const BloodRequestDetailScreen({
    super.key,
    required this.requestId,
  });

  // Factory constructor for demo/mock mode
  const BloodRequestDetailScreen.demo({super.key})
      : requestId = '00000000-0000-0000-0000-000000000000';

  @override
  State<BloodRequestDetailScreen> createState() => _BloodRequestDetailScreenState();
}

class _BloodRequestDetailScreenState extends State<BloodRequestDetailScreen> {
  bool _isLoading = true;
  bool _isLoadingPledges = false;
  bool _isCheckingEligibility = false;
  bool _isAuthenticated = false;
  bool _isCompletingDonation = false;
  BloodRequest? _request;
  String? _errorMessage;
  List<DonorPledge> _pledges = [];
  RequestProgressResponse? _progress;
  bool _isEligibleToDonate = true;
  String? _ineligibilityMessage;
  int _cooldownDaysRemaining = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Load user ID first and wait for it
    await _loadCurrentUserId();
    // Then load request detail
    _loadRequestDetail();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final userId = await ApiService.getCurrentUserId();
      final isAuthenticated = await ApiService.isAuthenticated();
      if (mounted) {
        setState(() {
          _currentUserId = userId;
          _isAuthenticated = isAuthenticated && userId != null;
        });
      }
    } catch (e) {
    }
  }

  /// Check if current user is the creator of this request
  bool _isRequestCreator() {
    if (_currentUserId == null || _request?.requestedById == null) return false;
    return _currentUserId == _request!.requestedById;
  }

  Future<void> _loadRequestDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getBloodRequestDetail(widget.requestId);

      if (mounted) {
        setState(() {
          if (response.success && response.bloodRequest != null) {
            _request = response.bloodRequest;
          } else {
            _errorMessage = response.message;
          }
          _isLoading = false;
        });
      }

      // Load data based on user role
      if (_isRequestCreator()) {
        // Patient: Load pledged donors list (so they can see who pledged)
        _loadProgressAndPledges();
      } else {
        // Donor: Load only their own pledge (if any) and check eligibility
        _loadDonorOwnPledge();
        _checkDonorEligibility();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load request details';
        });
      }
    }
  }

  Future<void> _loadProgressAndPledges() async {
    setState(() {
      _isLoadingPledges = true;
    });

    try {
      // Load pledges
      final pledgesResponse = await ApiService.getRequestPledges(widget.requestId);
      final progressResponse = await ApiService.getRequestProgress(widget.requestId);

      if (mounted) {
        setState(() {
          if (pledgesResponse['success'] == true && pledgesResponse['pledges'] != null) {
            _pledges = (pledgesResponse['pledges'] as List)
                .map((e) => DonorPledge.fromJson(e))
                .toList();
          }

          if (progressResponse['success'] == true && progressResponse['data'] != null) {
            _progress = RequestProgressResponse.fromJson(progressResponse);
          }

          _isLoadingPledges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPledges = false;
        });
      }
    }
  }

  Future<void> _checkDonorEligibility() async {
    setState(() {
      _isCheckingEligibility = true;
    });

    try {
      final isAuthenticated = await ApiService.isAuthenticated();
      if (!isAuthenticated) {
        if (mounted) {
          setState(() {
            _isEligibleToDonate = false;
            _ineligibilityMessage = 'Please login to pledge';
            _isCheckingEligibility = false;
          });
        }
        return;
      }

      final response = await ApiService.getDonorEligibility();

      if (mounted) {
        setState(() {
          if (response['success'] == true && response['data'] != null) {
            final data = response['data']['data'] as Map<String, dynamic>?;
            _isEligibleToDonate = data?['is_eligible'] ?? true;
            _ineligibilityMessage = data?['message'];
            _cooldownDaysRemaining = data?['cooldown_days_remaining'] ?? 0;
          } else {
            // If check fails, assume eligible (don't block user)
            _isEligibleToDonate = true;
          }
          _isCheckingEligibility = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // If check fails, assume eligible
          _isEligibleToDonate = true;
          _isCheckingEligibility = false;
        });
      }
    }
  }

  Future<void> _loadDonorOwnPledge() async {
    // Only load if authenticated
    if (!_isAuthenticated || _currentUserId == null) return;

    try {
      final pledgesResponse = await ApiService.getRequestPledges(widget.requestId);

      if (mounted && pledgesResponse['success'] == true && pledgesResponse['pledges'] != null) {
        final allPledges = (pledgesResponse['pledges'] as List)
            .map((e) => DonorPledge.fromJson(e))
            .toList();

        // Filter to show only the donor's own pledge
        final ownPledge = allPledges.where((p) => p.donor == _currentUserId).toList();

        setState(() {
          _pledges = ownPledge;
        });
      }
    } catch (e) {
      // Silently fail - pledges are optional for donors
    }
  }

  bool _canPledge() {
    if (_request?.status != 'pending') return false;
    if (_request == null) return false;
    // Don't block pledging when units are met - patients review all pledges
    if (_isCheckingEligibility) return false;
    if (!_isEligibleToDonate) return false;
    // Don't show pledge button to the request creator
    if (_isRequestCreator()) return false;
    // Don't show pledge button if donor already pledged
    if (_pledges.isNotEmpty) return false;
    return true;
  }

  String _getPledgeButtonText() {
    if (_request?.status != 'pending' || _request == null) {
      return _request?.status == 'fulfilled' ? 'Request Fulfilled' : 'Request Not Active';
    }
    if (_isRequestCreator()) {
      return 'Your Blood Request';
    }
    if (_pledges.isNotEmpty) {
      return 'You Have Pledged';
    }
    if (_isCheckingEligibility) {
      return 'Checking Eligibility...';
    }
    if (_isRequestCreator()) {
      return 'Your Blood Request';
    }
    if (_pledges.isNotEmpty) {
      return 'You Have Pledged';
    }
    if (_isCheckingEligibility) {
      return 'Checking Eligibility...';
    }
    if (!_isEligibleToDonate) {
      if (_cooldownDaysRemaining > 0) {
        return 'Wait $_cooldownDaysRemaining days to donate';
      }
      return _ineligibilityMessage ?? 'Not Eligible';
    }
    return 'I Can Help - Pledge 1 Unit';
  }

  Color _getUrgencyColor(String urgencyLevel) {
    switch (urgencyLevel.toLowerCase()) {
      case 'critical':
        return const Color(0xFFD62828);
      case 'urgent':
        return const Color(0xFFE85D04);
      case 'normal':
        return const Color(0xFFFFB74D);
      default:
        return AppColors.primary;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFF4CAF50);
      case 'fulfilled':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFF757575);
      default:
        return AppColors.textSecondary;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
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

            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _request == null
                          ? _buildEmptyState()
                          : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
          const Expanded(
            child: Text(
              'Request Detail',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // More options menu
          if (_request != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'share':
                    _shareRequest();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 20),
                      SizedBox(width: 12),
                      Text('Share Request'),
                    ],
                  ),
                ),
              ],
            ),
          if (_request == null)
            const SizedBox(width: 44),
        ],
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
            _errorMessage ?? 'Failed to load request',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadRequestDetail,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 16),
          Text('Request not found'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final urgencyColor = _getUrgencyColor(_request!.urgencyLevel);
    final statusColor = _getStatusColor(_request!.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _request!.status == 'pending'
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _request!.status == 'pending' ? Icons.check : Icons.info,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _request!.status == 'pending'
                            ? 'Active Request'
                            : _request!.status == 'fulfilled'
                                ? 'Completed'
                                : 'Cancelled',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _request!.status == 'pending'
                            ? 'We\'ll notify you when we find matching donors.'
                            : 'This request has been ${_request!.statusDisplay.toLowerCase()}.',
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Blood Group & Urgency
          Row(
            children: [
              // Blood Group
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    _request!.bloodGroup,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Urgency & Units
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _request!.urgencyLevel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: urgencyColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.bloodtype,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_request!.unitsNeeded} Unit${_request!.unitsNeeded > 1 ? 's' : ''} Needed',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Patient Information
          const Text(
            'Patient Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _request!.patientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.phone,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _request!.contactNumber,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Hospital & Location
          if (_request!.hospitalName != null || _request!.location != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hospital Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_request!.hospitalName != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.local_hospital,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _request!.hospitalName!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_request!.location != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _request!.location!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),

          // Additional Notes
          if (_request!.additionalNotes != null && _request!.additionalNotes!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Additional Notes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Text(
                    _request!.additionalNotes!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),

          // Request Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Requested ${_getTimeAgo(_request!.createdAt)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (_request!.requesterName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Requested by ${_request!.requesterName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Donor Map - Show only to patient when there are pledged donors
          if (_isRequestCreator() && _pledges.isNotEmpty) ...[
            const Text(
              'Donor Locations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            DonorMapView(
              patientLat: _request!.locationLat != null
                  ? double.tryParse(_request!.locationLat.toString())
                  : null,
              patientLng: _request!.locationLng != null
                  ? double.tryParse(_request!.locationLng.toString())
                  : null,
              donors: _pledges.map((pledge) {
                // Create approximate donor location for privacy
                // In production, this would come from backend
                final randomOffset = (_pledges.indexOf(pledge) + 1) * 0.01;

                // Format last donation date
                String lastDonationFormatted = 'Unknown';
                if (pledge.donorLastDonation != null) {
                  final now = DateTime.now();
                  final difference = now.difference(pledge.donorLastDonation!);
                  if (difference.inDays < 30) {
                    lastDonationFormatted = '${difference.inDays} days ago';
                  } else if (difference.inDays < 365) {
                    lastDonationFormatted = '${(difference.inDays / 30).floor()} months ago';
                  } else {
                    lastDonationFormatted = '${(difference.inDays / 365).floor()} years ago';
                  }
                }

                // Create donor initial from name
                String initial = '?';
                if (pledge.donorName != null && pledge.donorName!.isNotEmpty) {
                  final parts = pledge.donorName!.split(' ');
                  if (parts.isNotEmpty) {
                    initial = parts[0][0].toUpperCase();
                    if (parts.length > 1) {
                      initial += parts[1][0].toUpperCase();
                    }
                  }
                }

                return {
                  'name': pledge.donorName ?? 'Anonymous',
                  'initial': initial,
                  'blood_group': pledge.donorBloodGroup ?? pledge.bloodGroup ?? 'Unknown',
                  'distance_km': 0.0, // Would come from backend calculation
                  'age': pledge.donorAge ?? 0,
                  'city': pledge.donorCity ?? '',
                  'reality_score': 75, // Would come from backend
                  'last_donation': lastDonationFormatted,
                  'note': pledge.note ?? '',
                  'lat': _request!.locationLat != null
                      ? _request!.locationLat! + randomOffset
                      : null,
                  'lng': _request!.locationLng != null
                      ? _request!.locationLng! + randomOffset
                      : null,
                };
              }).toList(),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tap on donor markers to view details',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Pledged Donors Section - Show to Patient (all donors) or Donor (their own pledge only)
          if (_isRequestCreator() || _pledges.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isRequestCreator() ? 'Pledged Donors' : 'Your Pledge',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                // Manage Donors button for patient
                if (_isRequestCreator())
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PatientDonorManagementScreen(
                            requestId: widget.requestId,
                            patientName: _request!.patientName,
                            bloodGroup: _request!.bloodGroup,
                            unitsNeeded: _request!.unitsNeeded,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.manage_accounts, size: 18),
                    label: const Text('Manage Donors'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Loading indicator for pledges
            if (_isLoadingPledges)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              )
            else ...[
              // Show pledged donors (all for patient, own for donor)
              ..._pledges.map((pledge) => PledgedDonorCard(
                key: ValueKey('pledge_${pledge.id}'),
                pledge: pledge,
                requestId: widget.requestId,
                currentUserId: _currentUserId,
                isRequestCreator: _isRequestCreator(),
                isCompleting: _isCompletingDonation,
                onComplete: _isRequestCreator() && (pledge.status == 'pledged' || pledge.status == 'accepted')
                    ? () => _completeDonation(pledge)
                    : null,
              )),

              // Show "more donors needed" placeholder (only for patient)
              if (_isRequestCreator() && _request!.unitsPledged < _request!.unitsNeeded)
                DonorNeededCard(
                  count: _request!.unitsRemaining,
                ),
            ],
            const SizedBox(height: 20),
          ],

          // Info message for donors (non-creators) who haven't pledged yet
          if (!_isRequestCreator() && _pledges.isEmpty && _request!.unitsPledged > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.softPink.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_request!.unitsPledged} ${_request!.unitsPledged == 1 ? "donor has" : "donors have"} pledged to help. Your identity will be kept private.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // "I Can Help" Button - Only show to donors, NOT to request creator (patient)
          if (!_isRequestCreator()) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canPledge() ? () => _showPledgeDialog() : null,
                icon: const Icon(Icons.volunteer_activism, size: 18),
                label: Text(_getPledgeButtonText()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Chat with Patient Button - Only show to authenticated donors, NOT to request creator
          if (!_isRequestCreator() && _isAuthenticated) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openChatWithPatient,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Chat with Patient'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Share Request Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _shareRequest,
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share Request'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _showPledgeDialog() async {
    // Check if user is authenticated
    final isAuthenticated = await ApiService.isAuthenticated();
    if (!isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to pledge'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Check if user has already pledged
    if (_pledges.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already pledged to this request'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Check eligibility before showing dialog
    if (!_canPledge()) {
      if (mounted) {
        String message = 'Cannot pledge at this time';
        if (_request!.status != 'pending') {
          message = 'This request is no longer accepting pledges';
        } else if (!_isEligibleToDonate) {
          message = _ineligibilityMessage ?? 'Not eligible to donate';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Show pledge dialog
    if (mounted) {
      await showPledgeDialog(
        context: context,
        requestId: widget.requestId,
        patientName: _request!.patientName,
        bloodGroup: _request!.bloodGroup,
        unitsNeeded: _request!.unitsNeeded,
        hospitalName: _request!.hospitalName ?? 'Hospital',
        requiredBy: '${_request!.createdAt.day}/${_request!.createdAt.month}/${_request!.createdAt.year}',
        patientId: _request!.requestedById,
        onPledgeCreated: () {
          // Reload data after pledge
          _loadRequestDetail();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pledge created successfully!'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.online,
            ),
          );
        },
      );
    }
  }

  void _shareRequest() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openChatWithPatient() async {
    // Debug logging

    // Check if user is authenticated (using already-loaded flag)
    if (!_isAuthenticated || _currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to chat'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Check if request has patient info
    if (_request?.patientName == null || _request?.requestedById == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient information not available'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
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
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Initialize Firebase
      await FirebaseChatService.initialize();

      // Get current user's name from profile
      final profile = await ApiService.getProfile();
      String currentUserName = 'Donor';
      if (profile['success'] == true) {
        final userData = profile['data']?['user'];
        currentUserName = userData?['full_name'] ?? userData?['email'] ?? 'Donor';
      }

      // Create or get conversation
      // Current user (donor) chats with patient
      final conversation = await FirebaseChatService.instance.getOrCreateConversation(
        requestId: widget.requestId,
        patientId: _request!.requestedById!, // Patient's ID
        patientName: _request!.patientName!, // Patient's name
        donorId: _currentUserId!, // Current donor's ID
        donorName: currentUserName, // Current donor's name
      );


      // Hide loading SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Navigate to Firebase chat screen
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(
              conversation: conversation,
              currentUserId: _currentUserId!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirebaseChatService.getFirebaseErrorMessage(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  /// Complete donation from a pledge (patient only)
  Future<void> _completeDonation(DonorPledge pledge) async {
    // Show confirmation dialog
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Donation Completion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please confirm that you have received blood from ${pledge.donorName ?? "this donor"}.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softPink.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will mark ${pledge.unitsPledged} ${pledge.unitsPledged == 1 ? "unit" : "units"} as received.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.online,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Donation'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Proceed with completion
    setState(() {
      _isCompletingDonation = true;
    });

    try {
      final response = await ApiService.completePledgeDonation(
        requestId: widget.requestId,
        pledgeId: pledge.id,
        unitsDonated: pledge.unitsPledged,
      );

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      response['message'] ?? 'Donation completed successfully!',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.online,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );

          // Reload request details to update UI
          _loadRequestDetail();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'Failed to complete donation',
              ),
              backgroundColor: AppColors.urgencyCritical,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing donation: ${e.toString()}'),
            backgroundColor: AppColors.urgencyCritical,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCompletingDonation = false;
        });
      }
    }
  }
}
