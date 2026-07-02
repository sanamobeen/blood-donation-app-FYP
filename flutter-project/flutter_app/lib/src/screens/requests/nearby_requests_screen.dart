import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/blood_request.dart';
import '../../models/donor_availability.dart';
import '../../widgets/bottom_navigation_bar.dart';
import 'blood_request_detail_screen.dart';
import '../../widgets/pledge_dialog.dart';

class NearbyRequestsScreen extends StatefulWidget {
  const NearbyRequestsScreen({super.key});

  @override
  State<NearbyRequestsScreen> createState() => _NearbyRequestsScreenState();
}

class _NearbyRequestsScreenState extends State<NearbyRequestsScreen> {
  String _selectedFilter = 'All';
  bool _isLoading = true;
  BloodRequestListResponse? _requestsResponse;
  String? _errorMessage;
  Set<String> _pledgedRequestIds = {}; // Track request IDs user has pledged to
  String? _currentUserId; // Track current user ID to prevent self-pledges

  // SOS requests
  List<Map<String, dynamic>> _sosRequests = [];

  // User's blood group for filtering
  String? _userBloodGroup;
  List<String> _compatibleBloodGroups = [];

  // Donor's availability data
  DonorAvailability? _donorAvailability;

  // Donor's profile location (from their profile, not GPS)
  double? _donorProfileLat;
  double? _donorProfileLng;
  String? _donorCity;

  // User GPS location for 5km filter
  Position? _userPosition;
  bool _isLoadingLocation = false;
  String? _locationErrorMessage;

  // Map view state
  bool _showMapView = false;
  final MapController _mapController = MapController();

  // Pakistan center coordinates
  static const LatLng _pakistanCenter = LatLng(30.3753, 69.3451);

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUserLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Load current user ID and blood group first
    await _loadCurrentUserId();
    await _loadUserBloodGroup();
    // Load pledges, then requests
    await _loadMyPledges();
    _loadRequests();
  }

  /// Load user's blood group and profile location from profile
  Future<void> _loadUserBloodGroup() async {
    try {
      final profileResponse = await ApiService.getProfile();
      if (profileResponse['success'] == true) {
        final profileData = profileResponse['data'];
        final profile = profileData['profile'];

        if (profile != null) {
          // Load blood group
          if (profile['blood_group'] != null) {
            final bloodGroup = profile['blood_group'].toString().toUpperCase();
            setState(() {
              _userBloodGroup = bloodGroup;
              _compatibleBloodGroups = _getCompatibleBloodGroups(bloodGroup);
            });
          }

          // Load donor's profile location (from their profile, not GPS)
          if (profile['location_lat'] != null && profile['location_lng'] != null) {
            final lat = double.tryParse(profile['location_lat'].toString());
            final lng = double.tryParse(profile['location_lng'].toString());
            if (lat != null && lng != null) {
              setState(() {
                _donorProfileLat = lat;
                _donorProfileLng = lng;
                _donorCity = profile['city']?.toString();
              });
            }
          }

          // Load donor's availability data
          if (profile['availability'] != null) {
            try {
              setState(() {
                _donorAvailability = DonorAvailability.fromJson(profile['availability']);
              });
            } catch (e) {
              debugPrint('Error loading availability: $e');
            }
          }
        }
      }
    } catch (e) {
      // If blood group cannot be loaded, show all requests
      setState(() {
        _compatibleBloodGroups = [];
      });
    }
  }

  /// Get compatible blood groups for donation based on donor's blood type
  /// Blood donation compatibility rules for Red Blood Cells
  List<String> _getCompatibleBloodGroups(String donorBloodGroup) {
    // Compatibility: Donor can donate to which recipients
    switch (donorBloodGroup) {
      case 'A+':
        return ['A+', 'AB+'];
      case 'A-':
        return ['A+', 'A-', 'AB+', 'AB-'];
      case 'B+':
        return ['B+', 'AB+'];
      case 'B-':
        return ['B+', 'B-', 'AB+', 'AB-'];
      case 'AB+':
        return ['AB+']; // Can only donate to AB+
      case 'AB-':
        return ['AB+', 'AB-'];
      case 'O+':
        return ['A+', 'B+', 'AB+', 'O+'];
      case 'O-':
        return ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']; // Universal donor
      default:
        return []; // Unknown blood type, show no requests
    }
  }

  /// Get user's current location for distance filtering
  Future<void> _loadUserLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationErrorMessage = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationErrorMessage = 'Location services are disabled';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      // Check for location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _locationErrorMessage = 'Location permission denied';
              _isLoadingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationErrorMessage = 'Location permission permanently denied';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _userPosition = position;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationErrorMessage = 'Could not get location: ${e.toString()}';
          _isLoadingLocation = false;
        });
      }
    }
  }

  /// Calculate distance between two coordinates in kilometers
  double _calculateDistanceInKm(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final userId = await ApiService.getCurrentUserId();
      if (mounted) {
        setState(() {
          _currentUserId = userId;
        });
      }
    } catch (e) {
    }
  }

  Future<void> _loadMyPledges() async {
    try {
      final isAuthenticated = await ApiService.isAuthenticated();
      if (!isAuthenticated) return;

      final response = await ApiService.getMyPledges();
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final pledges = data['pledges'] as List?;
        if (pledges != null) {
          setState(() {
            _pledgedRequestIds = pledges
                .map((p) => p['blood_request']?.toString())
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toSet();
          });
        }
      }
    } catch (e) {
    }
  }

  Future<void> _handlePledge(BloodRequest request) async {
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

    // Check if this is the user's own request
    if (_currentUserId != null && request.requestedById == _currentUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot pledge to your own request'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Check if already pledged
    if (_pledgedRequestIds.contains(request.id)) {
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

    // Show pledge dialog
    if (mounted) {
      await showPledgeDialog(
        context: context,
        requestId: request.id,
        patientName: request.patientName,
        bloodGroup: request.bloodGroup,
        unitsNeeded: request.unitsNeeded,
        hospitalName: request.hospitalName ?? 'Hospital',
        requiredBy: _formatNeededByTime(request.neededBy),
        onPledgeCreated: () {
          // Add to pledged set and reload requests after pledge
          setState(() {
            _pledgedRequestIds.add(request.id);
          });
          _loadRequests();
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

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch regular blood requests from backend
      final bloodRequestsResponse = await ApiService.getBloodRequests(status: 'pending');

      // Fetch active SOS requests
      final sosResponse = await ApiService.getActiveSosRequests(
        lat: _donorProfileLat ?? 31.5204,
        lng: _donorProfileLng ?? 74.3587,
      );

      if (mounted) {
        setState(() {
          _requestsResponse = bloodRequestsResponse;
          _isLoading = false;
          if (!bloodRequestsResponse.success) {
            _errorMessage = bloodRequestsResponse.message;
          }

          // Store SOS requests separately for display
          _sosRequests = sosResponse['success'] == true
              ? (sosResponse['data']?['requests'] as List? ?? [])
                  .cast<Map<String, dynamic>>()
              : [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load requests';
          _sosRequests = [];
        });
      }
    }
  }

  /// Get time slot ID from hour (0-23)
  /// Returns the 2-hour time slot ID for the given hour
  String _getTimeSlotFromHour(int hour) {
    if (hour >= 0 && hour < 2) return '12am_2am';
    if (hour >= 2 && hour < 4) return '2am_4am';
    if (hour >= 4 && hour < 6) return '4am_6am';
    if (hour >= 6 && hour < 8) return '6am_8am';
    if (hour >= 8 && hour < 10) return '8am_10am';
    if (hour >= 10 && hour < 12) return '10am_12pm';
    if (hour >= 12 && hour < 14) return '12pm_2pm';
    if (hour >= 14 && hour < 16) return '2pm_4pm';
    if (hour >= 16 && hour < 18) return '4pm_6pm';
    if (hour >= 18 && hour < 20) return '6pm_8pm';
    if (hour >= 20 && hour < 22) return '8pm_10pm';
    return '10pm_12am'; // 22-23
  }

  /// Check if donor is available for the given blood request
  /// Returns true if donor is available during the request's needed time
  bool _isDonorAvailableForRequest(BloodRequest request) {
    // If no availability data set, show all requests
    if (_donorAvailability == null) return true;

    // If donor is available all day, show all requests
    if (_donorAvailability!.availableAllDay) return true;

    // FIX: Convert UTC to local time before checking availability
    // The backend stores neededBy in UTC, but donor availability is in local time
    final localNeededBy = request.neededBy.toLocal();

    // Get the day of week from neededBy date (using local time)
    final dayName = DonorAvailability.daysOfWeek[localNeededBy.weekday - 1]; // weekday is 1-7, daysOfWeek is 0-indexed

    // Check if donor is available on this day
    if (!_donorAvailability!.isAvailableOnDay(dayName)) return false;

    // Get the time slot from the neededBy hour (using local time)
    final timeSlotId = _getTimeSlotFromHour(localNeededBy.hour);

    // Check if donor is available during this time slot
    return _donorAvailability!.isAvailableAtTime(dayName, timeSlotId);
  }

  List<BloodRequest> get _filteredRequests {
    if (_requestsResponse == null) return [];

    final requests = _requestsResponse!.bloodRequests;

    List<BloodRequest> filtered;

    // First, filter by blood group compatibility if user has a blood group
    if (_compatibleBloodGroups.isNotEmpty) {
      filtered = requests.where((r) {
        final requestBloodGroup = r.bloodGroup.toUpperCase();
        return _compatibleBloodGroups.contains(requestBloodGroup);
      }).toList();
    } else {
      // If no blood group set, show all requests
      filtered = requests;
    }

    // Then filter by donor availability time slots
    filtered = filtered.where((r) => _isDonorAvailableForRequest(r)).toList();

    // Then apply additional filters
    switch (_selectedFilter) {
      case 'All':
        // Already filtered by blood group and availability above
        break;
      case 'Urgent':
        filtered = filtered.where((r) => r.urgencyLevel == 'urgent').toList();
        break;
      default:
        break;
    }

    // Sort by time (latest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  // Get blood requests with valid location coordinates for map display
  List<BloodRequest> get _requestsWithLocation {
    return _filteredRequests
        .where((r) => r.locationLat != null && r.locationLng != null)
        .toList();
  }

  // Get combined list of all requests (SOS + regular blood requests)
  // Returns a list of maps with type indicator
  List<Map<String, dynamic>> get _allRequests {
    final List<Map<String, dynamic>> combined = [];

    // Add SOS requests first (highest priority)
    for (var sos in _sosRequests) {
      // Check blood type compatibility
      if (_compatibleBloodGroups.isEmpty ||
          _compatibleBloodGroups.contains(sos['blood_type'])) {
        combined.add({
          'type': 'sos',
          'data': sos,
        });
      }
    }

    // Add regular blood requests
    for (var request in _filteredRequests) {
      combined.add({
        'type': 'blood_request',
        'data': request,
      });
    }

    // Sort by time (latest first)
    combined.sort((a, b) {
      final aTime = a['type'] == 'sos'
          ? DateTime.parse(a['data']['created_at'])
          : (a['data'] as BloodRequest).createdAt;
      final bTime = b['type'] == 'sos'
          ? DateTime.parse(b['data']['created_at'])
          : (b['data'] as BloodRequest).createdAt;
      return bTime.compareTo(aTime);
    });

    return combined;
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  /// Format the neededBy date/time in a readable format for the card
  String _formatNeededByTime(DateTime dateTime) {
    // FIX: Convert UTC to local time for display
    // The backend stores neededBy in UTC, but users expect to see local time
    final localDateTime = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final neededDate = DateTime(localDateTime.year, localDateTime.month, localDateTime.day);

    // Format time (using local time)
    final hour = localDateTime.hour;
    final minute = localDateTime.minute;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr = '${displayHour}:${minute.toString().padLeft(2, '0')} $amPm';

    // Format date (using local time)
    if (neededDate == today) {
      return 'Today, $timeStr';
    } else if (neededDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow, $timeStr';
    } else if (neededDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $timeStr';
    } else if (localDateTime.difference(now).inDays.abs() < 7) {
      // Within a week, show day name
      final dayName = DonorAvailability.daysOfWeek[localDateTime.weekday - 1];
      return '${DonorAvailability.getShortDayName(dayName)}, $timeStr';
    } else {
      // Show date
      return '${localDateTime.day}/${localDateTime.month}, $timeStr';
    }
  }

  Color _getPriorityColor(String urgencyLevel) {
    switch (urgencyLevel.toLowerCase()) {
      case 'critical':
        return const Color(0xFFE53935);
      case 'urgent':
        return const Color(0xFFFFA000);
      default:
        return const Color(0xFF43A047);
    }
  }

  /// Build location status widget for 5km filter
  Widget _buildLocationStatus() {
    if (_isLoadingLocation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Getting your location...',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (_locationErrorMessage != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.urgencyCritical.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off,
              size: 14,
              color: AppColors.urgencyCritical,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _locationErrorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.urgencyCritical,
                ),
              ),
            ),
            TextButton(
              onPressed: _loadUserLocation,
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_userPosition != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.online.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on,
              size: 14,
              color: AppColors.online,
            ),
            const SizedBox(width: 8),
            const Text(
              'Showing requests within 5km of your location',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.online,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
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
                      'Requests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      icon: Icon(_showMapView ? Icons.list : Icons.map_outlined),
                      onPressed: () {
                        setState(() {
                          _showMapView = !_showMapView;
                        });
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            // Blood Group Filter Indicator (if user has blood group set)
            if (_userBloodGroup != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bloodtype,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your blood group: $_userBloodGroup',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '• Showing: ${_compatibleBloodGroups.join(", ")}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Filter Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: ['All', 'Urgent', 'Map'].map((filter) {
                  final isSelected = filter == 'Map' ? _showMapView : _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterButton(
                      label: filter,
                      isSelected: isSelected,
                      onTap: () {
                        if (filter == 'Map') {
                          // Toggle map view
                          setState(() {
                            _showMapView = !_showMapView;
                          });
                        } else {
                          // Set selected filter and hide map view
                          setState(() {
                            _selectedFilter = filter;
                            _showMapView = false;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Request List or Map View
            Expanded(
              child: _buildContent(),
            ),

            // Bottom Navigation
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
            ),
            SizedBox(height: 16),
            Text(
              'Loading requests...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.urgencyCritical,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
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

    if (_showMapView) {
      return _buildMapView();
    }

    if (_filteredRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No nearby requests found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check back later for new requests',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _allRequests.length,
      itemBuilder: (context, index) {
        final requestItem = _allRequests[index];
        final isSOS = requestItem['type'] == 'sos';
        final request = requestItem['data'];

        if (isSOS) {
          // Show SOS request card with special styling
          final sosData = request as Map<String, dynamic>;
          final bloodType = sosData['blood_type'] ?? 'Unknown';
          final hospitalName = sosData['hospital_name'] ?? 'Unknown Hospital';
          final patientName = sosData['requester_name'] ?? 'Patient';
          final unitsNeeded = sosData['units_needed'] ?? 1;
          final respondersCount = sosData['responders_count'] ?? 0;
          final createdAt = DateTime.parse(sosData['created_at']);

          // Calculate distance
          String distanceText = 'Nearby';
          if (_donorProfileLat != null && _donorProfileLng != null &&
              sosData['hospital_lat'] != null && sosData['hospital_lng'] != null) {
            final distanceKm = _calculateDistanceInKm(
              _donorProfileLat!,
              _donorProfileLng!,
              sosData['hospital_lat'],
              sosData['hospital_lng'],
            );
            distanceText = _formatDistance(distanceKm);
          }

          return _SOSRequestCard(
            name: patientName,
            bloodType: bloodType,
            hospital: hospitalName,
            distance: distanceText,
            time: _getTimeAgo(createdAt),
            unitsNeeded: unitsNeeded,
            respondersCount: respondersCount,
            sosId: sosData['id'],
          );
        } else {
          // Show regular blood request card
          final bloodRequest = request as BloodRequest;
          final priorityColor = _getPriorityColor(bloodRequest.urgencyLevel);

          // Calculate distance using donor's REGISTERED location
          String distanceText = 'Location unknown';
          if (_donorProfileLat != null && _donorProfileLng != null &&
              bloodRequest.locationLat != null && bloodRequest.locationLng != null) {
            final distanceKm = _calculateDistanceInKm(
              _donorProfileLat!,
              _donorProfileLng!,
              bloodRequest.locationLat!,
              bloodRequest.locationLng!,
            );
            distanceText = _formatDistance(distanceKm);
          }

          return _RequestCard(
            name: bloodRequest.patientName,
            initials: _getInitials(bloodRequest.patientName),
            bloodType: bloodRequest.bloodGroup,
            hospital: bloodRequest.hospitalName ?? 'Location specified',
            distance: distanceText,
            time: _getTimeAgo(bloodRequest.createdAt),
            neededBy: _formatNeededByTime(bloodRequest.neededBy),
            priority: bloodRequest.urgencyLevel,
            priorityColor: priorityColor,
            requestId: bloodRequest.id,
            unitsNeeded: bloodRequest.unitsNeeded,
            hasPledged: _pledgedRequestIds.contains(bloodRequest.id),
            isOwnRequest: _currentUserId != null && bloodRequest.requestedById == _currentUserId,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BloodRequestDetailScreen(
                  requestId: bloodRequest.id,
                ),
              ),
            );
          },
          onPledge: () => _handlePledge(bloodRequest),
        );
        }
      },
    );
  }

  /// Format distance for display
  String _formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      // Show in meters if less than 1km
      final meters = (distanceKm * 1000).round();
      return '${meters}m away';
    } else if (distanceKm < 10) {
      // Show 1 decimal place for distances < 10km
      return '${distanceKm.toStringAsFixed(1)}km away';
    } else {
      // Show whole number for longer distances
      return '${distanceKm.round()}km away';
    }
  }

  Widget _buildMapView() {
    final requestsWithLocation = _requestsWithLocation;

    if (requestsWithLocation.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.map_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No location data available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_filteredRequests.length} requests found, but none have location information',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate bounds to fit all markers
    double minLat = requestsWithLocation[0].locationLat!;
    double maxLat = requestsWithLocation[0].locationLat!;
    double minLng = requestsWithLocation[0].locationLng!;
    double maxLng = requestsWithLocation[0].locationLng!;

    for (final request in requestsWithLocation) {
      if (request.locationLat! < minLat) minLat = request.locationLat!;
      if (request.locationLat! > maxLat) maxLat = request.locationLat!;
      if (request.locationLng! < minLng) minLng = request.locationLng!;
      if (request.locationLng! > maxLng) maxLng = request.locationLng!;
    }

    // Include donor's location in bounds (prioritize profile location, fallback to GPS)
    LatLng? donorLocation;
    if (_donorProfileLat != null && _donorProfileLng != null) {
      // Use profile location from database as primary source
      donorLocation = LatLng(_donorProfileLat!, _donorProfileLng!);
      minLat = min(minLat, donorLocation.latitude);
      maxLat = max(maxLat, donorLocation.latitude);
      minLng = min(minLng, donorLocation.longitude);
      maxLng = max(maxLng, donorLocation.longitude);
    } else if (_userPosition != null) {
      // Fallback to GPS location if no profile location
      donorLocation = LatLng(_userPosition!.latitude, _userPosition!.longitude);
      minLat = min(minLat, donorLocation.latitude);
      maxLat = max(maxLat, donorLocation.latitude);
      minLng = min(minLng, donorLocation.longitude);
      maxLng = max(maxLng, donorLocation.longitude);
    }

    // Calculate center and appropriate zoom level
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    // Calculate appropriate zoom level based on bounds
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = max(latDiff, lngDiff);

    // Estimate zoom level (heuristic calculation)
    // Zoom level 0 shows entire world (~360 degrees)
    // Each zoom level halves the visible area
    double initialZoom = 10;
    if (maxDiff > 0) {
      // Convert degrees to approximate zoom level
      // At zoom 10, approximately 0.1 degrees is visible
      // Formula: zoom = log2(360 / diff) - 1
      initialZoom = (log2(360 / maxDiff) - 1).clamp(10, 14).toDouble();
    }

    // Ensure reasonable bounds for zoom (more focused)
    initialZoom = initialZoom.clamp(10.0, 14.0);

    // Build all markers including donor location
    final List<Marker> allMarkers = [];
    allMarkers.addAll(_buildBloodRequestMarkers(requestsWithLocation));

    // Add donor's location marker (profile location or GPS fallback)
    if (donorLocation != null) {
      allMarkers.add(
        Marker(
          point: donorLocation,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: const Text(
                      'YOU',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Build route polylines from donor to each request
    final List<Polyline> routePolylines = [];

    if (donorLocation != null) {
      for (final request in requestsWithLocation) {
        final requestLocation = LatLng(request.locationLat!, request.locationLng!);

        // Create green polyline from donor to request
        routePolylines.add(
          Polyline(
            points: [donorLocation, requestLocation],
            strokeWidth: 3,
            color: Colors.green.withValues(alpha: 0.6),
            borderStrokeWidth: 1,
            borderColor: Colors.white,
          ),
        );
      }
    }

    return Container(
      color: Colors.grey[200], // Fallback background color
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: initialZoom,
          minZoom: 2,
          maxZoom: 18,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
        // Use OpenStreetMap tiles - use alternative CDN
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.bloodDonation.app',
          maxZoom: 18,
        ),
        // Blue route lines from donor to all requests
        if (routePolylines.isNotEmpty)
          PolylineLayer(
            polylines: routePolylines,
          ),
        // Location pins
        MarkerLayer(
          markers: allMarkers,
        ),
      ],
      ),
    );
  }

  double log2(double n) {
    return log(n) / log(2);
  }

  List<Marker> _buildBloodRequestMarkers(List<BloodRequest> requests) {
    return requests.map((request) {
      final latLng = LatLng(request.locationLat!, request.locationLng!);
      final priorityColor = _getPriorityColor(request.urgencyLevel);
      final hasPledged = _pledgedRequestIds.contains(request.id);
      final isOwnRequest = _currentUserId != null && request.requestedById == _currentUserId;

      return Marker(
        point: latLng,
        width: 44,
        height: 56,
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
          child: _LocationPinMarker(
            bloodGroup: request.bloodGroup,
            urgencyColor: priorityColor,
            hasPledged: hasPledged,
            isOwnRequest: isOwnRequest,
          ),
        ),
      );
    }).toList();
  }

  // Location pin marker widget with urgency color
  Widget _LocationPinMarker({
    required String bloodGroup,
    required Color urgencyColor,
    required bool hasPledged,
    required bool isOwnRequest,
  }) {
    // Dim the pin if already pledged or own request
    final pinColor = (hasPledged || isOwnRequest)
        ? Colors.grey
        : urgencyColor;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Pin shadow
        Positioned(
          bottom: 0,
          child: Container(
            width: 36,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        // Main pin body (teardrop shape)
        Container(
          width: 44,
          height: 56,
          child: Column(
            children: [
              // Pin head (circle with blood type)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: pinColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    bloodGroup,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // Pin point (triangle)
              CustomPaint(
                size: const Size(16, 12),
                painter: _PinPointPainter(color: pinColor, strokeColor: Colors.white),
              ),
            ],
          ),
        ),
        // Pledged indicator
        if (hasPledged || isOwnRequest)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: pinColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                hasPledged ? Icons.check : Icons.person,
                size: 10,
                color: pinColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return UnifiedBottomNavigationBar(
      selectedIndex: 1, // Requests is index 1
      onItemTapped: (index) {
        // Handle navigation based on index: 0=Home, 1=Request, 2=Chat, 3=Profile
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, AppRoutes.home);
            break;
          case 1:
            // Already on Requests - refresh
            Navigator.pushReplacementNamed(context, AppRoutes.nearbyRequests);
            break;
          case 2:
            // Navigate to Messages (Chat)
            Navigator.pushReplacementNamed(context, AppRoutes.messages);
            break;
          case 3:
            // Navigate to Profile (Settings)
            Navigator.pushReplacementNamed(context, AppRoutes.settings);
            break;
        }
      },
    );
  }

}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final String name;
  final String initials;
  final String bloodType;
  final String hospital;
  final String distance;
  final String time;
  final String? neededBy; // New: Patient's needed date/time
  final String priority;
  final Color priorityColor;
  final VoidCallback onTap;
  final String requestId;
  final int unitsNeeded;
  final bool hasPledged;
  final bool isOwnRequest;
  final VoidCallback? onPledge;

  const _RequestCard({
    required this.name,
    required this.initials,
    required this.bloodType,
    required this.hospital,
    required this.distance,
    required this.time,
    this.neededBy,
    required this.priority,
    required this.priorityColor,
    required this.onTap,
    required this.requestId,
    this.unitsNeeded = 1,
    this.hasPledged = false,
    this.isOwnRequest = false,
    this.onPledge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main content row (tap to view details)
          GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                // Profile Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
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
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              bloodType,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hospital,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hospital,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Show needed by time if available, otherwise show time ago
                          if (neededBy != null) ...[
                            const Icon(Icons.schedule, size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              neededBy!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$unitsNeeded unit${unitsNeeded > 1 ? "s" : ""} needed',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('•'),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  priority == 'critical' ? Icons.crisis_alert : Icons.priority_high,
                                  size: 10,
                                  color: priorityColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  priority,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: priorityColor,
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
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Pledge Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (hasPledged || isOwnRequest) ? null : onPledge,
              icon: Icon(
                isOwnRequest
                    ? Icons.person
                    : hasPledged
                        ? Icons.check_circle
                        : Icons.volunteer_activism,
                size: 16,
              ),
              label: Text(
                isOwnRequest
                    ? 'Your Request'
                    : hasPledged
                        ? 'You Have Pledged'
                        : 'I Can Help - Donate Now',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: (hasPledged || isOwnRequest)
                    ? AppColors.textSecondary
                    : AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SOSRequestCard extends StatelessWidget {
  final String name;
  final String bloodType;
  final String hospital;
  final String distance;
  final String time;
  final int unitsNeeded;
  final int respondersCount;
  final String sosId;

  const _SOSRequestCard({
    required this.name,
    required this.bloodType,
    required this.hospital,
    required this.distance,
    required this.time,
    required this.unitsNeeded,
    required this.respondersCount,
    required this.sosId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD62828), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD62828).withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // SOS Badge Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emergency,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'SOS EMERGENCY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tap to respond now',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main content
          Row(
            children: [
              // Blood Type Icon
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Color(0xFFD62828),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    bloodType,
                    style: const TextStyle(
                      fontSize: 14,
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
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_hospital,
                          size: 12,
                          color: Color(0xFFD62828),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hospital,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          distance,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD62828),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$unitsNeeded unit${unitsNeeded > 1 ? "s" : ""}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Respond Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Navigate to SOS response screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('SOS response feature coming soon!'),
                    backgroundColor: Color(0xFFD62828),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.emergency_share, size: 16),
              label: Text(
                'Respond to SOS - Help Now!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62828),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for pin point (triangle)
class _PinPointPainter extends CustomPainter {
  final Color color;
  final Color strokeColor;

  _PinPointPainter({required this.color, required this.strokeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path();
    // Draw triangle pointing down
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Add stroke
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
