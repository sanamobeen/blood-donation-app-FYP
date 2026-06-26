import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';

/// Nearby Donors Map Screen
/// Shows nearby donors on an OpenStreetMap with markers
/// PATIENTS ONLY - Patients use this to find nearby donors
class NearbyDonorsMapScreen extends StatefulWidget {
  const NearbyDonorsMapScreen({super.key});

  @override
  State<NearbyDonorsMapScreen> createState() => _NearbyDonorsMapScreenState();
}

class _NearbyDonorsMapScreenState extends State<NearbyDonorsMapScreen> {
  late MapController _mapController;
  final List<Marker> _markers = [];
  final List<CircleMarker> _circles = [];
  bool _isLoading = true;
  bool _isCheckingRole = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _nearbyDonors = [];

  // Current location
  double? _currentLat;
  double? _currentLng;

  // Search radius in km
  double _searchRadius = 50.0;

  // Camera position
  LatLng? _initialCenter;

  // GPS Tracking
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTrackingEnabled = true;
  Position? _currentPosition;

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

      if (profile['success'] == true && profile['data'] != null) {
        final userData = profile['data'];
        final userRole = userData['role'] ?? userData['profile']?['role'];

        // Only patients should access this screen
        if (userRole != 'patient') {
          setState(() {
            _isCheckingRole = false;
            _errorMessage = 'This feature is only available for patients.\n\nDonors should use the "Nearby Requests" feature to find blood requests near them.';
          });
          return;
        }
      }

      // If role check passes, initialize map
      await _initializeMap();
    } catch (e) {
      setState(() {
        _isCheckingRole = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _initializeMap() async {
    setState(() {
      _isCheckingRole = false;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current location
      await _getCurrentLocation();

      if (_currentLat != null && _currentLng != null) {
        // Set initial camera position
        _initialCenter = LatLng(_currentLat!, _currentLng!);

        // Fetch nearby donors
        await _fetchNearbyDonors();
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
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions are denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied';
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
        _currentPosition = position;
      });

      // Start GPS tracking stream
      _startLocationTracking();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: $e';
      });
    }
  }

  /// Starts continuous GPS tracking using position stream
  void _startLocationTracking() {
    // Cancel existing subscription if any
    _positionStreamSubscription?.cancel();

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
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

          // Update markers with new location
          _createMarkers();

          // If tracking is enabled, center map on user
          if (_isTrackingEnabled && _currentLat != null && _currentLng != null) {
            _mapController.move(LatLng(_currentLat!, _currentLng!), 16);
          }
        }
      },
      onError: (error) {
      },
    );
  }

  /// Toggles GPS tracking on/off
  void _toggleTracking() {
    setState(() {
      _isTrackingEnabled = !_isTrackingEnabled;
    });

    // If enabling, center on current location
    if (_isTrackingEnabled && _currentLat != null && _currentLng != null) {
      _mapController.move(LatLng(_currentLat!, _currentLng!), 16);
    }

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isTrackingEnabled ? 'GPS Tracking enabled' : 'GPS Tracking disabled'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Recenters map on current location
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

  Future<void> _fetchNearbyDonors() async {
    if (_currentLat == null || _currentLng == null) return;

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
            _nearbyDonors = donorsList;
            _isLoading = false;
          });

          // Create markers for each donor
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

  void _createMarkers() {
    _markers.clear();
    _circles.clear();

    // Add circle for search radius
    if (_currentLat != null && _currentLng != null) {
      _circles.add(
        CircleMarker(
          point: LatLng(_currentLat!, _currentLng!),
          radius: _searchRadius * 1000, // Convert km to meters
          color: Colors.blue.withValues(alpha: 0.1),
          borderStrokeWidth: 2,
          borderColor: Colors.blue.withValues(alpha: 0.3),
          useRadiusInMeter: true,
        ),
      );
    }

    // Add markers for nearby donors with enhanced info
    for (int i = 0; i < _nearbyDonors.length; i++) {
      final donor = _nearbyDonors[i];

      // Check if donor has location
      if (donor['location_lat'] != null && donor['location_lng'] != null) {
        final donorLat = donor['location_lat'] as num;
        final donorLng = donor['location_lng'] as num;
        final bloodGroup = donor['blood_group']?.toString() ?? 'N/A';
        final distance = donor['distance_km'] ?? 0.0;

        // Create enhanced marker with blood group and distance
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
                  // Main marker circle
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
                  // Blood group text
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
                  // Distance badge below marker
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

    setState(() {});
  }

  void _showDonorDetails(Map<String, dynamic> donor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DonorDetailsSheet(donor: donor),
    );
  }

  Future<void> _refreshMap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _getCurrentLocation();
    await _fetchNearbyDonors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Donors'),
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
              _fetchNearbyDonors();
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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
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
                onPressed: () {
                  // Navigate to nearby requests (for donors)
                  Navigator.pushReplacementNamed(context, '/nearby-requests');
                },
                icon: const Icon(Icons.directions_run),
                label: const Text('Go to Nearby Requests'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_initialCenter == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show empty message overlay if no donors found
    if (_nearbyDonors.isEmpty) {
      // Still show the map, but with an overlay message
      return Stack(
        children: [
          _buildMap(),
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No nearby donors found. Try increasing the search radius.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
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
            // OpenStreetMap tile layer - use alternative CDN
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.blood_donation',
              maxZoom: 18,
            ),
            // Search radius circle
            CircleLayer(circles: _circles),
            // Donor markers
            MarkerLayer(markers: _markers),
            // Current location marker with pulsing effect when tracking
            if (_currentLat != null && _currentLng != null)
              MarkerLayer(
                markers: [
                  // Pulsing outer circles when tracking is enabled
                  if (_isTrackingEnabled)
                    Marker(
                      width: 100,
                      height: 100,
                      point: LatLng(_currentLat!, _currentLng!),
                      child: _PulsingLocationMarker(),
                    ),
                  // Main location marker
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
              ),
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
            child: Text(
              'Search Radius: ${_searchRadius.toInt()} km\nFound: ${_nearbyDonors.length} donors',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
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
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          'A+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Blood Donor (Blood Group)'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red, width: 1),
                      ),
                      child: const Text(
                        '2.5km',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 7,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Distance from you',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
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
  }

/// Donor Details Bottom Sheet
class DonorDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> donor;

  const DonorDetailsSheet({super.key, required this.donor});

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
          // Handle
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

          // Donor name
          Text(
            donor['full_name'] ?? 'Anonymous Donor',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // Blood group badge
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

          // Details
          _buildDetailRow(Icons.accessibility, 'Gender', donor['gender'] ?? 'N/A'),
          _buildDetailRow(Icons.calendar_today, 'Age', donor['age']?.toString() ?? 'N/A'),
          _buildDetailRow(Icons.phone, 'Phone', donor['phone_number'] ?? 'N/A'),
          _buildDetailRow(Icons.location_on, 'Distance', '${donor['distance_km']?.toString() ?? '0'} km'),
          _buildDetailRow(Icons.star, 'Reliability Score', '${donor['reliability_score'] ?? '100'}/100'),

          const SizedBox(height: 24),

          // Reliability badge
          if (donor['is_top_donor'] == true || donor['is_reliable'] == true)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      donor['is_top_donor'] == true
                          ? 'Top Donor - Highly reliable!'
                          : 'Reliable Donor',
                      style: TextStyle(
                        color: Colors.amber[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Navigate to create blood request screen with pre-filled data
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact this donor through blood request'),
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

/// Pulsing Location Marker Widget
/// Shows animated pulsing circles around current location when tracking is enabled
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
            // Outer pulsing circle
            Container(
              width: 50 + (_animation.value * 50),
              height: 50 + (_animation.value * 50),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: 0.3 - (_animation.value * 0.3)),
              ),
            ),
            // Inner pulsing circle
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
