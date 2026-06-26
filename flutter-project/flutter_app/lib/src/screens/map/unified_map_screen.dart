import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';
import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../models/blood_request.dart';
import '../../widgets/pledge_dialog.dart';
import '../requests/blood_request_detail_screen.dart';
import '../donors/donor_profile_screen.dart';

/// Unified Map Screen
/// Shows current location and:
/// - For PATIENTS: nearby donors
/// - For DONORS: nearby blood requests (patients)
class UnifiedMapScreen extends StatefulWidget {
  const UnifiedMapScreen({super.key});

  @override
  State<UnifiedMapScreen> createState() => _UnifiedMapScreenState();
}

class _UnifiedMapScreenState extends State<UnifiedMapScreen> {
  late MapController _mapController;
  final List<Marker> _markers = [];
  final List<CircleMarker> _circles = [];
  bool _isLoading = true;
  bool _isCheckingRole = true;
  String? _errorMessage;
  String? _userRole;

  // Current location
  double? _currentLat;
  double? _currentLng;
  Position? _currentPosition;

  // Profile location (fallback)
  double? _profileLocationLat;
  double? _profileLocationLng;

  // Search radius in km
  double _searchRadius = 50.0;

  // Camera position
  LatLng? _initialCenter;

  // Data
  List<Map<String, dynamic>> _nearbyItems = [];
  String _userBloodGroup = '';

  // GPS Tracking
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTrackingEnabled = true;

  // For donors - pledged request IDs
  Set<String> _pledgedRequestIds = {};

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _checkRoleAndInitialize();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkRoleAndInitialize() async {
    setState(() {
      _isCheckingRole = true;
    });

    try {
      // Get current user profile to check role
      final profile = await ApiService.getProfile();
      debugPrint('Profile response: $profile');

      if (profile['success'] == true && profile['data'] != null) {
        final userData = profile['data'];
        final profileData = userData['profile'];
        final user = userData['user'];

        // FIXED: Check both locations for role
        _userRole = user?['role'] ?? userData['role'] ?? profileData?['role'];
        debugPrint('Detected user role: $_userRole');

        // Load blood group
        if (profileData != null && profileData['blood_group'] != null) {
          _userBloodGroup = profileData['blood_group'].toString().toUpperCase();
          debugPrint('User blood group: $_userBloodGroup');
        }

        // Load profile location as fallback if GPS fails
        if (profileData != null &&
            profileData['location_lat'] != null &&
            profileData['location_lng'] != null) {
          final profileLat = double.tryParse(profileData['location_lat'].toString());
          final profileLng = double.tryParse(profileData['location_lng'].toString());
          if (profileLat != null && profileLng != null) {
            _profileLocationLat = profileLat;
            _profileLocationLng = profileLng;
            debugPrint('Profile location loaded: $profileLat, $profileLng');
          }
        }

        // For donors, load their pledges
        if (_userRole == 'donor') {
          await _loadMyPledges();
          debugPrint('Loaded pledges: $_pledgedRequestIds');
        }
      }

      // Initialize map
      await _initializeMap();
    } catch (e) {
      debugPrint('Error in checkRoleAndInitialize: $e');
      setState(() {
        _isCheckingRole = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _loadMyPledges() async {
    try {
      final pledgesResponse = await ApiService.getMyPledges();
      if (pledgesResponse['success'] == true) {
        final pledges = pledgesResponse['pledges'] as List? ?? [];
        setState(() {
          _pledgedRequestIds = pledges
              .map((p) => p['blood_request']?.toString() ?? '')
              .toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading pledges: $e');
    }
  }

  Future<void> _initializeMap() async {
    setState(() {
      _isCheckingRole = false;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current location FIRST
      await _getCurrentLocation();

      if (_currentLat != null && _currentLng != null) {
        // Set initial camera position to user's location
        _initialCenter = LatLng(_currentLat!, _currentLng!);
        debugPrint('====================================');
        debugPrint('Map Initial Center Set:');
        debugPrint('Latitude: $_currentLat');
        debugPrint('Longitude: $_currentLng');
        debugPrint('InitialCenter: $_initialCenter');
        debugPrint('====================================');

        // Fetch nearby items based on role
        await _fetchNearbyItems();
      } else {
        setState(() {
          _errorMessage = 'Could not get your location. Please enable location services.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      debugPrint('====================================');
      debugPrint('Getting user location from database...');

      // PRIMARY: Use profile location from database
      if (_profileLocationLat != null && _profileLocationLng != null) {
        setState(() {
          _currentLat = _profileLocationLat;
          _currentLng = _profileLocationLng;
        });
        debugPrint('Using profile location from database:');
        debugPrint('Latitude: $_currentLat');
        debugPrint('Longitude: $_currentLng');
        debugPrint('====================================');

        // Still try to get GPS for tracking, but don't override profile location
        _startLocationTracking();
        return;
      }

      // FALLBACK: If no profile location, try GPS
      debugPrint('No profile location found, trying GPS...');

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Please set your location in your profile first.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Please set your location in your profile first.';
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
        _currentPosition = position;
      });

      debugPrint('Using GPS location:');
      debugPrint('Latitude: $_currentLat');
      debugPrint('Longitude: $_currentLng');
      debugPrint('====================================');

      _startLocationTracking();
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _errorMessage = 'Please set your location in your profile first.';
      });
    }
  }

  /// Calculate distance between two coordinates in km using Haversine formula
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    double dLat = _toRadians(lat2 - lat1);
    double dLng = _toRadians(lng2 - lng1);
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        (sin(dLng / 2) * sin(dLng / 2));
    double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * 3.14159265359 / 180;
  }

  void _startLocationTracking() {
    _positionStreamSubscription?.cancel();

    // Only track GPS if we're using GPS location (not profile location)
    if (_profileLocationLat == null || _profileLocationLng == null) {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        timeLimit: Duration(seconds: 5),
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          if (mounted) {
            setState(() {
              _currentLat = position.latitude;
              _currentLng = position.longitude;
              _currentPosition = position;
            });

            _createMarkers();

            if (_isTrackingEnabled && _currentLat != null && _currentLng != null) {
              _mapController.move(LatLng(_currentLat!, _currentLng!), 16);
            }
          }
        },
        onError: (error) {
          debugPrint('Location stream error: $error');
        },
      );
    } else {
      debugPrint('Using profile location, GPS tracking disabled');
    }
  }

  Future<void> _fetchNearbyItems() async {
    if (_currentLat == null || _currentLng == null) {
      debugPrint('Cannot fetch items: current location is null');
      return;
    }

    debugPrint('Fetching nearby items for role: $_userRole');
    debugPrint('Current location: $_currentLat, $_currentLng');

    try {
      if (_userRole == 'patient') {
        await _fetchNearbyDonors();
      } else if (_userRole == 'donor') {
        await _fetchNearbyRequests();
      } else {
        debugPrint('Unknown role: $_userRole');
        setState(() {
          _errorMessage = 'Unable to determine your role.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching nearby items: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchNearbyDonors() async {
    try {
      final response = await ApiService.getNearbyDonors(
        lat: _currentLat!,
        lng: _currentLng!,
        radius: _searchRadius,
      );

      if (mounted) {
        if (response['success'] == true && response['data'] != null) {
          final data = response['data'];
          final donorsList = (data['donors'] as List? ?? [])
              .cast<Map<String, dynamic>>();

          setState(() {
            _nearbyItems = donorsList;
            _isLoading = false;
          });

          _createMarkers();
        } else {
          setState(() {
            _errorMessage = response['message'] ?? 'Failed to fetch nearby donors';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchNearbyRequests() async {
    debugPrint('Fetching nearby requests...');
    try {
      final response = await ApiService.getNearbyBloodRequests(
        lat: _currentLat!,
        lng: _currentLng!,
        radius: _searchRadius,
      );

      debugPrint('Nearby requests response: ${response.toString()}');

      if (mounted) {
        if (response['success'] == true) {
          // Handle both response formats - with or without 'data' wrapper
          final requestsList = response['data'] != null
              ? (response['data']['requests'] as List? ?? [])
                  .cast<Map<String, dynamic>>()
              : (response['requests'] as List? ?? [])
                  .cast<Map<String, dynamic>>();

          debugPrint('Found ${requestsList.length} nearby requests');

          setState(() {
            _nearbyItems = requestsList;
            _isLoading = false;
          });

          _createMarkers();
        } else {
          debugPrint('Failed to fetch requests: ${response['message']}');
          setState(() {
            _errorMessage = response['message'] ?? 'Failed to fetch nearby requests';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Exception fetching nearby requests: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _createMarkers() {
    _markers.clear();
    _circles.clear();

    debugPrint('Creating markers for role: $_userRole');
    debugPrint('Nearby items count: ${_nearbyItems.length}');

    // Add circle for search radius
    if (_currentLat != null && _currentLng != null) {
      _circles.add(
        CircleMarker(
          point: LatLng(_currentLat!, _currentLng!),
          radius: _searchRadius * 1000,
          color: Colors.blue.withValues(alpha: 0.1),
          borderStrokeWidth: 2,
          borderColor: Colors.blue.withValues(alpha: 0.3),
          useRadiusInMeter: true,
        ),
      );
      debugPrint('Added search radius circle at $_currentLat, $_currentLng');

      // ALWAYS add current location marker
      debugPrint('Adding current location marker at $_currentLat, $_currentLng');
    } else {
      debugPrint('Cannot add search radius circle: current location is null');
    }

    // For patients: create donor markers
    if (_userRole == 'patient') {
      for (final donor in _nearbyItems) {
        if (donor['location_lat'] != null && donor['location_lng'] != null) {
          final donorLat = donor['location_lat'] as num;
          final donorLng = donor['location_lng'] as num;
          final bloodGroup = donor['blood_group']?.toString() ?? 'N/A';
          final distance = donor['distance_km'] ?? 0.0;

          _markers.add(
            Marker(
              width: 80,
              height: 80,
              point: LatLng(donorLat.toDouble(), donorLng.toDouble()),
              child: GestureDetector(
                onTap: () => _showDonorDetails(donor),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 18,
                      child: Text(
                        bloodGroup,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          distance < 1
                              ? '${(distance * 1000).toInt()}m'
                              : '${distance.toStringAsFixed(1)}km',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
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
      }
    }
    // For donors: create request markers
    else if (_userRole == 'donor') {
      debugPrint('Creating ${_nearbyItems.length} request markers for donor role');
      for (final request in _nearbyItems) {
        debugPrint('Processing request: ${request['id']} - location: ${request['location_lat']}, ${request['location_lng']}');
        if (request['location_lat'] != null && request['location_lng'] != null) {
          final reqLat = double.tryParse(request['location_lat'].toString());
          final reqLng = double.tryParse(request['location_lng'].toString());

          if (reqLat != null && reqLng != null) {
            final bloodGroup = request['blood_group']?.toString() ?? 'N/A';
            final unitsNeeded = request['units_needed'] ?? 1;
            final urgency = request['urgency_level']?.toString() ?? 'normal';
            final isPledged = _pledgedRequestIds.contains(request['id']?.toString());

            // Get urgency color
            Color urgencyColor;
            if (urgency == 'critical') {
              urgencyColor = const Color(0xFFD62828);
            } else if (urgency == 'urgent') {
              urgencyColor = const Color(0xFFE85D04);
            } else {
              urgencyColor = const Color(0xFFFFB74D);
            }

            _markers.add(
              Marker(
                width: 90,
                height: 90,
                point: LatLng(reqLat, reqLng),
                child: GestureDetector(
                  onTap: () => _showRequestDetails(request),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isPledged ? Colors.green : urgencyColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 15,
                        child: Text(
                          bloodGroup,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isPledged ? Colors.green : urgencyColor, width: 1),
                          ),
                          child: Text(
                            isPledged ? 'Pledged' : '$unitsNeeded units',
                            style: TextStyle(
                              color: isPledged ? Colors.green : urgencyColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            debugPrint('Added marker for request ${request['id']} at $reqLat, $reqLng');
          }
        }
      }
    }

    debugPrint('Created ${_markers.length} markers');
    setState(() {});
  }

  void _showDonorDetails(Map<String, dynamic> donor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DonorDetailsSheet(donor: donor),
    );
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RequestDetailsSheet(
        request: request,
        userBloodGroup: _userBloodGroup,
        isPledged: _pledgedRequestIds.contains(request['id']?.toString()),
        onPledge: () {
          setState(() {
            _pledgedRequestIds.add(request['id']?.toString() ?? '');
          });
          _createMarkers();
          _fetchNearbyRequests();
        },
      ),
    );
  }

  Future<void> _refreshMap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _getCurrentLocation();
    await _fetchNearbyItems();
  }

  void _toggleTracking() {
    setState(() {
      _isTrackingEnabled = !_isTrackingEnabled;
    });

    if (_isTrackingEnabled && _currentLat != null && _currentLng != null) {
      _mapController.move(LatLng(_currentLat!, _currentLng!), 16);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isTrackingEnabled ? 'GPS Tracking enabled' : 'GPS Tracking disabled'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _recenterOnCurrentLocation() {
    if (_currentLat != null && _currentLng != null) {
      _mapController.move(LatLng(_currentLat!, _currentLng!), 16);
      setState(() {
        _isTrackingEnabled = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Centered on your location'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('===== BUILD CALLED =====');
    debugPrint('isLoading: $_isLoading, isCheckingRole: $_isCheckingRole');
    debugPrint('currentLat: $_currentLat, currentLng: $_currentLng');
    debugPrint('nearbyItems length: ${_nearbyItems.length}');
    debugPrint('initialCenter: $_initialCenter');
    debugPrint('markers count: ${_markers.length}');
    debugPrint('isTrackingEnabled: $_isTrackingEnabled');
    debugPrint('=====================');

    return Scaffold(
      appBar: AppBar(
        title: Text(_userRole == 'donor' ? 'Nearby Requests' : 'Nearby Donors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMap,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<double>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _searchRadius = value;
              });
              _fetchNearbyItems();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 10.0, child: Text('10 km')),
              const PopupMenuItem(value: 25.0, child: Text('25 km')),
              const PopupMenuItem(value: 50.0, child: Text('50 km')),
              const PopupMenuItem(value: 100.0, child: Text('100 km')),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isCheckingRole) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _currentLat == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshMap,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_initialCenter == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show empty message overlay if no items found
    if (_nearbyItems.isEmpty) {
      return Stack(
        children: [
          _buildMap(),
          Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _userRole == 'patient' ? Icons.person_search : Icons.bloodtype,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userRole == 'patient'
                        ? 'No Nearby Donors Found'
                        : 'No Nearby Blood Requests',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userRole == 'patient'
                        ? 'There are no donors available in your area.\nTry increasing the search radius.'
                        : 'There are no blood requests near you.\nTry increasing the search radius or check back later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'Your location: ${_currentLat?.toStringAsFixed(4)}, ${_currentLng?.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _searchRadius = 100.0;
                      });
                      _fetchNearbyItems();
                    },
                    icon: const Icon(Icons.zoom_out_map),
                    label: const Text('Search 100 km radius'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return _buildMap();
  }

  Widget _buildCurrentLocationMarker() {
    debugPrint('===== BUILDING CURRENT LOCATION MARKER =====');
    debugPrint('currentLat: $_currentLat, currentLng: $_currentLng');
    debugPrint('isTrackingEnabled: $_isTrackingEnabled');
    debugPrint('=====================================');

    if (_currentLat == null || _currentLng == null) {
      debugPrint('Cannot build marker: location is null');
      return const SizedBox.shrink();
    }

    debugPrint('Building current location marker at $_currentLat, $_currentLng');

    try {
      return MarkerLayer(
        markers: [
          if (_isTrackingEnabled)
            Marker(
              width: 100,
              height: 100,
              point: LatLng(_currentLat!, _currentLng!),
              child: const _PulsingLocationMarker(),
            ),
          Marker(
            width: 44,
            height: 44,
            point: LatLng(_currentLat!, _currentLng!),
            child: Container(
              decoration: BoxDecoration(
                color: _isTrackingEnabled ? Colors.green : Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: (_isTrackingEnabled ? Colors.green : Colors.blue).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _isTrackingEnabled ? Icons.gps_fixed : Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      );
    } catch (e) {
      debugPrint('Error building current location marker: $e');
      return const SizedBox.shrink();
    }
  }

  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter!,
            initialZoom: 12,
            minZoom: 4,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.blood_donation',
              maxZoom: 18,
            ),
            CircleLayer(circles: _circles),
            MarkerLayer(markers: _markers),
            // Current location marker
            _buildCurrentLocationMarker(),
          ],
        ),
        // Search radius indicator
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search Radius: ${_searchRadius.toInt()} km\nFound: ${_nearbyItems.length} ${_userRole == 'patient' ? 'donors' : 'requests'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_currentLat != null && _currentLng != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Your Location:',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_currentLat!.toStringAsFixed(6)}, ${_currentLng!.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[700],
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        // Legend
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Your location
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _isTrackingEnabled ? Colors.green : Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Icon(
                          _isTrackingEnabled ? Icons.gps_fixed : Icons.person,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_isTrackingEnabled ? 'Your Location (Tracking)' : 'Your Location'),
                  ],
                ),
                const SizedBox(height: 8),
                // Donor/Request marker
                if (_userRole == 'patient')
                  _buildLegendItem(
                    color: Colors.red,
                    label: 'A+',
                    description: 'Blood Donor',
                  )
                else
                  _buildLegendItem(
                    color: const Color(0xFFD62828),
                    label: 'A+',
                    description: 'Blood Request',
                    showPledged: true,
                  ),
              ],
            ),
          ),
        ),
        // OpenStreetMap attribution
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenStreetMap',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String description,
    bool showPledged = false,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(description),
        if (showPledged) ...[
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Center(
              child: Text(
                '✓',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text('You pledged', style: TextStyle(fontSize: 11)),
        ],
      ],
    );
  }
}

/// Donor Details Bottom Sheet
class _DonorDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> donor;

  const _DonorDetailsSheet({required this.donor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            donor['full_name'] ?? 'Anonymous Donor',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              donor['blood_group'] ?? 'N/A',
              style: TextStyle(
                color: Colors.red[900],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(Icons.location_on, 'Distance', '${donor['distance_km']?.toString() ?? '0'} km'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Create a blood request to contact this donor'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create Blood Request',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Request Details Bottom Sheet
class _RequestDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> request;
  final String userBloodGroup;
  final bool isPledged;
  final VoidCallback onPledge;

  const _RequestDetailsSheet({
    required this.request,
    required this.userBloodGroup,
    required this.isPledged,
    required this.onPledge,
  });

  @override
  Widget build(BuildContext context) {
    final bloodGroup = request['blood_group']?.toString() ?? 'N/A';
    final urgency = request['urgency_level']?.toString() ?? 'normal';

    // Determine if blood group is compatible
    final isCompatible = _isBloodGroupCompatible(userBloodGroup, bloodGroup);

    Color urgencyColor;
    if (urgency == 'critical') {
      urgencyColor = const Color(0xFFD62828);
    } else if (urgency == 'urgent') {
      urgencyColor = const Color(0xFFE85D04);
    } else {
      urgencyColor = const Color(0xFFFFB74D);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: urgencyColor),
                ),
                child: Text(
                  urgency.toUpperCase(),
                  style: TextStyle(
                    color: urgencyColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Blood Request',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            request['patient_name']?.toString() ?? 'Patient',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              bloodGroup,
              style: TextStyle(
                color: Colors.red[900],
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.bloodtype, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '${request['units_needed'] ?? 1} unit${(request['units_needed'] ?? 1) > 1 ? 's' : ''} needed',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              Icon(Icons.location_on, color: Colors.grey[600], size: 20),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request['hospital_name']?.toString() ?? 'Location',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (!isCompatible) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your blood group ($userBloodGroup) is not compatible with $bloodGroup',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (isPledged)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You have pledged to donate',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCompatible
                    ? () => _handlePledge(context)
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: isCompatible ? urgencyColor : Colors.grey,
                ),
                child: Text(
                  isCompatible
                      ? 'Pledge to Donate'
                      : 'Not Compatible',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _handlePledge(BuildContext context) {
    Navigator.pop(context);

    final patientName = request['patient_name']?.toString() ?? 'Patient';
    final bloodGroup = request['blood_group']?.toString() ?? 'N/A';
    final unitsNeeded = (request['units_needed'] as num?)?.toInt() ?? 1;
    final hospitalName = request['hospital_name']?.toString() ?? 'Hospital';
    final requiredBy = request['required_by']?.toString() ?? '';
    final patientId = request['requested_by']?.toString();
    final requestId = request['id']?.toString() ?? '';

    showPledgeDialog(
      context: context,
      requestId: requestId,
      patientName: patientName,
      bloodGroup: bloodGroup,
      unitsNeeded: unitsNeeded,
      hospitalName: hospitalName,
      requiredBy: requiredBy,
      patientId: patientId,
      onPledgeCreated: onPledge,
    );
  }

  bool _isBloodGroupCompatible(String donorGroup, String recipientGroup) {
    if (donorGroup.isEmpty || recipientGroup.isEmpty) return true;

    // O- is universal donor
    if (donorGroup == 'O-') return true;

    // AB+ can receive from all
    if (recipientGroup == 'AB+') return true;

    // Same blood group is always compatible
    if (donorGroup == recipientGroup) return true;

    // A+ can receive from A+, A-, O+, O-
    if (recipientGroup == 'A+') {
      return ['A+', 'A-', 'O+', 'O-'].contains(donorGroup);
    }

    // A- can receive from A-, O-
    if (recipientGroup == 'A-') {
      return ['A-', 'O-'].contains(donorGroup);
    }

    // B+ can receive from B+, B-, O+, O-
    if (recipientGroup == 'B+') {
      return ['B+', 'B-', 'O+', 'O-'].contains(donorGroup);
    }

    // B- can receive from B-, O-
    if (recipientGroup == 'B-') {
      return ['B-', 'O-'].contains(donorGroup);
    }

    // AB+ can receive from all (already handled)
    // AB- can receive from A-, B-, AB-, O-
    if (recipientGroup == 'AB-') {
      return ['A-', 'B-', 'AB-', 'O-'].contains(donorGroup);
    }

    // O+ can receive from O+, O-
    if (recipientGroup == 'O+') {
      return ['O+', 'O-'].contains(donorGroup);
    }

    return false;
  }
}

/// Pulsing Location Marker Widget
class _PulsingLocationMarker extends StatefulWidget {
  const _PulsingLocationMarker();

  @override
  State<_PulsingLocationMarker> createState() => _PulsingLocationMarkerState();
}

class _PulsingLocationMarkerState extends State<_PulsingLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 50 + (_animation.value * 50),
              height: 50 + (_animation.value * 50),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: 0.3 - (_animation.value * 0.3)),
              ),
            ),
            Container(
              width: 30 + (_animation.value * 20),
              height: 30 + (_animation.value * 20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: 0.5 - (_animation.value * 0.3)),
              ),
            ),
          ],
        );
      },
    );
  }
}
