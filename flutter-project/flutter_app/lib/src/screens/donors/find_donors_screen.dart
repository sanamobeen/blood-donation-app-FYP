import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../app_routes.dart';
import '../donors/donor_profile_screen.dart';

/// Enhanced Find Donors Screen with API integration
/// Features: location-based search, filters, actual donor data
class FindDonorsScreen extends StatefulWidget {
  const FindDonorsScreen({super.key});

  @override
  State<FindDonorsScreen> createState() => _FindDonorsScreenState();
}

class _FindDonorsScreenState extends State<FindDonorsScreen> {
  // Pakistan center coordinate
  static const LatLng pakistanCenter = LatLng(30.0, 69.0);

  // View mode - list or map
  bool _isMapView = false;

  // Map controller
  late MapController _mapController;
  final List<Marker> _markers = [];
  final List<CircleMarker> _circles = [];

  // Filter states
  String _selectedBloodGroup = 'All';
  double _distanceKm = 10.0;
  bool _availableOnly = true;
  int get _filterCount => (_selectedBloodGroup != 'All' ? 1 : 0) +
      (_distanceKm != 10.0 ? 1 : 0) +
      (_availableOnly ? 0 : 0);

  // Search controller
  final TextEditingController _searchController = TextEditingController();

  // Data
  List<Map<String, dynamic>> _donors = [];
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  String? _errorMessage;
  double? _userLat;
  double? _userLng;
  String? _userCity;

  // Bottom sheet filter states
  String _selectedGender = 'Any';
  double _ageMin = 18.0;
  double _ageMax = 60.0;
  String _selectedLastDonation = 'Any time';
  bool _verifiedOnly = false;

  // Pagination
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
    _searchDonors();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoading && _hasMore) {
        _currentPage++;
        _searchDonors(isLoadMore: true);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _errorMessage = 'Location services are disabled. Please enable them.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
            _errorMessage = 'Location permissions are denied. Please grant permissions.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _errorMessage = 'Location permissions are permanently denied. Please enable them in settings.';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
        _isLoadingLocation = false;
        _errorMessage = null;
      });

      // Search donors with new location
      _searchDonors();
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _errorMessage = 'Error getting location: $e';
      });
    }
  }

  Future<void> _searchDonors({bool isLoadMore = false}) async {
    if (_userLat == null || _userLng == null) {
      if (!isLoadMore) {
        setState(() {
          _isLoading = true;
          _errorMessage = 'Getting your location...';
        });
      }
      return;
    }

    if (!isLoadMore) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
      });
    }

    try {
      final bloodTypeParam = _selectedBloodGroup == 'All' ? null : _selectedBloodGroup;

      final result = await ApiService.searchDonors(
        query: _searchController.text.trim().isEmpty ? null : _searchController.text,
        bloodType: bloodTypeParam,
        city: _userCity,
        lat: _userLat,
        lng: _userLng,
        radius: _distanceKm,
      );

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        final donors = data['donors'] as List? ?? [];

        setState(() {
          if (isLoadMore) {
            _donors.addAll(donors.map((d) => d as Map<String, dynamic>).toList());
          } else {
            _donors = donors.map((d) => d as Map<String, dynamic>).toList();
          }
          _hasMore = donors.length == 20;
          _isLoading = false;
          _errorMessage = null;
        });
        // Create markers for map view
        if (!isLoadMore) {
          _createMarkers();
        }
      } else {
        setState(() {
          if (isLoadMore) {
            _hasMore = false;
          } else {
            _donors = [];
            _errorMessage = result['message'] as String? ?? 'No donors found';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching donors: $e';
        _isLoading = false;
      });
    }
  }

  /// Create map markers from donor list
  void _createMarkers() {
    _markers.clear();
    _circles.clear();

    // Add circle for search radius (only if user location available)
    if (_userLat != null && _userLng != null) {
      _circles.add(
        CircleMarker(
          point: LatLng(_userLat!, _userLng!),
          radius: _distanceKm * 1000, // Convert km to meters
          color: AppColors.primary.withValues(alpha: 0.1),
          borderStrokeWidth: 2,
          borderColor: AppColors.primary.withValues(alpha: 0.3),
          useRadiusInMeter: true,
        ),
      );
    }

    // Pakistan city coordinates for demo markers when no location data
    final Map<String, LatLng> pakistanCities = {
      'karachi': const LatLng(24.8607, 67.0011),
      'lahore': const LatLng(31.5204, 74.3587),
      'islamabad': const LatLng(33.6844, 73.0479),
      'rawalpindi': const LatLng(33.5651, 73.0169),
      'faisalabad': const LatLng(31.4504, 73.1350),
      'multan': const LatLng(30.1575, 71.5249),
      'peshawar': const LatLng(34.0151, 71.5249),
      'quetta': const LatLng(30.1798, 66.9750),
      'sialkot': const LatLng(32.4945, 74.5229),
      'gujranwala': const LatLng(32.1877, 74.1913),
    };
    final cityKeys = pakistanCities.keys.toList();

    // Add markers for each donor
    for (int i = 0; i < _donors.length; i++) {
      final donor = _donors[i];

      // Get donor location or create offset for demo
      double? donorLat = donor['location_lat'] as double?;
      double? donorLng = donor['location_lng'] as double?;

      // If no location, create offset from user location or use Pakistan cities for demo
      if (donorLat == null || donorLng == null) {
        if (_userLat != null && _userLng != null) {
          // Offset from user location
          donorLat = _userLat! + (i + 1) * 0.01;
          donorLng = _userLng! + (i + 1) * 0.01;
        } else {
          // Use Pakistan cities for demo distribution
          final cityIndex = i % cityKeys.length;
          final city = pakistanCities[cityKeys[cityIndex]];
          if (city != null) {
            // Add small random offset for each donor in same city
            donorLat = city.latitude + (i * 0.005);
            donorLng = city.longitude + (i * 0.005);
          } else {
            continue; // Skip if no location available
          }
        }
      }

      // Get donor info for marker
      final bloodType = donor['blood_type'] as String? ?? '??';
      final fullName = donor['full_name'] as String? ?? 'Donor';
      final initials = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

      // Create marker
      _markers.add(
        Marker(
          width: 45,
          height: 45,
          point: LatLng(donorLat, donorLng),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DonorProfileScreen(donor: donor),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bloodType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    setState(() {});
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

            // Search Bar
            _buildSearchBar(),

            // Location Status
            if (_isLoadingLocation)
              _buildLocationStatus(),

            // Main Content
            Expanded(
              child: _isLoading && _donors.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _isMapView
                      ? _buildMapView()
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Results Section
                              _buildResultsSection(),
                            ],
                          ),
                        ),
            ),
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
              'Find Donors',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // View Toggle Button (Map/List)
          GestureDetector(
            onTap: () {
              setState(() {
                _isMapView = !_isMapView;
              });
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.softPink.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isMapView ? Icons.list_rounded : Icons.map_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filter Icon with Badge
          GestureDetector(
            onTap: () {
              _showFilterBottomSheet();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.softPink.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  if (_filterCount > 0)
                    Positioned(
                      top: 8,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_filterCount',
                          style: const TextStyle(
                            color: Colors.white,
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
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(
              Icons.search,
              color: AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or location',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _searchDonors(),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _searchDonors();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isLoadingLocation
            ? AppColors.primary.withOpacity(0.1)
            : (_errorMessage != null ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (_isLoadingLocation)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else if (_errorMessage != null)
            const Icon(Icons.error_outline, color: Colors.red, size: 16)
          else
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isLoadingLocation
                  ? 'Getting your location...'
                  : (_errorMessage ?? 'Using your current location'),
              style: TextStyle(
                fontSize: 12,
                color: _errorMessage != null ? Colors.red : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Results Count
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_donors.length} donors found',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_userLat != null && _userLng != null)
                  Text(
                    'Near you',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),

          // Donor List
          if (_donors.isEmpty && !_isLoading)
            _buildEmptyState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              controller: _scrollController,
              itemCount: _donors.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _donors.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }

                final donor = _donors[index];
                return _DonorCard(
                  donor: donor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DonorProfileScreen(donor: donor),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox.shrink();
  }

  /// Build the map view showing donor markers
  Widget _buildMapView() {
    // Always center on Pakistan
    const pakistanCenter = LatLng(30.3753, 69.3451);

    return Stack(
      children: [
        // Map container with background color
        Container(
          color: Colors.lightBlue.withValues(alpha: 0.1),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: pakistanCenter,
              initialZoom: 6,  // Good zoom level for viewing Pakistan
              minZoom: 4,      // Can still see surrounding region, not full world
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
            // Pakistan boundary polygon (always show)
            PolygonLayer(
              polygons: [
                Polygon(
                  points: const [
                    LatLng(37.5, 74.5),  // Northern tip
                    LatLng(36.0, 75.5),
                    LatLng(34.0, 76.5),
                    LatLng(32.0, 77.0),  // Northeast
                    LatLng(30.0, 77.5),
                    LatLng(28.0, 77.0),
                    LatLng(26.0, 76.0),
                    LatLng(25.0, 75.0),
                    LatLng(24.0, 73.5),
                    LatLng(23.5, 71.0), // Southeast
                    LatLng(24.0, 68.0),
                    LatLng(25.0, 66.5),
                    LatLng(26.0, 65.0), // Southwest
                    LatLng(27.0, 63.0),
                    LatLng(29.0, 61.5),
                    LatLng(31.0, 60.5),
                    LatLng(33.0, 60.0), // Northwest
                    LatLng(35.0, 61.0),
                    LatLng(36.5, 62.5),
                    LatLng(37.0, 64.0),
                    LatLng(37.5, 67.0),
                    LatLng(37.5, 74.5), // Back to northern tip
                  ],
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderColor: AppColors.primary,
                  borderStrokeWidth: 2,
                  isFilled: true,
                ),
              ],
            ),
            // Search radius circle
            CircleLayer(circles: _circles),
            // Donor markers
            MarkerLayer(markers: _markers),
            // City markers for Pakistan (always show)
            MarkerLayer(
              markers: [
                  // Karachi
                  Marker(
                    width: 80,
                    height: 30,
                    point: const LatLng(24.8607, 67.0011),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primary),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: const Text(
                        'Karachi',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Lahore
                  Marker(
                    width: 60,
                    height: 30,
                    point: const LatLng(31.5204, 74.3587),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primary),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: const Text(
                        'Lahore',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Islamabad
                  Marker(
                    width: 70,
                    height: 30,
                    point: const LatLng(33.6844, 73.0479),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primary),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: const Text(
                        'Islamabad',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Peshawar
                  Marker(
                    width: 70,
                    height: 30,
                    point: const LatLng(34.0151, 71.5249),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primary),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: const Text(
                        'Peshawar',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Quetta
                  Marker(
                    width: 50,
                    height: 30,
                    point: const LatLng(30.1798, 66.9750),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primary),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: const Text(
                        'Quetta',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Pakistan Center Label
                  Marker(
                    width: 100,
                    height: 40,
                    point: const LatLng(26.0, 68.0), // South-central Pakistan
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Text(
                        '🇵🇰 PAKISTAN',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            // Large Pakistan center marker (very visible)
            if (_userLat == null)
              MarkerLayer(
                markers: [
                  Marker(
                    width: 100,
                    height: 100,
                    point: pakistanCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '🇵🇰',
                            style: TextStyle(fontSize: 30),
                          ),
                          Text(
                            'PAKISTAN',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            // Current location marker (only show if user location available)
            if (_userLat != null && _userLng != null)
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: LatLng(_userLat!, _userLng!),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
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
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        ),
        // Donors count overlay
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_donors.length} donors',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Empty state overlay
        if (_donors.isEmpty && !_isLoading)
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
                      _userLat != null
                          ? 'No donors found in this area. Try adjusting filters or increasing search radius.'
                          : 'No donors found in Pakistan. Try adjusting filters or search for specific blood groups.',
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
        // Map legend
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
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.person, color: Colors.white, size: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Your Location'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.bloodtype, color: Colors.white, size: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Donor'),
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

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        selectedBloodGroup: _selectedBloodGroup,
        distanceKm: _distanceKm,
        selectedGender: _selectedGender,
        ageMin: _ageMin,
        ageMax: _ageMax,
        selectedLastDonation: _selectedLastDonation,
        verifiedOnly: _verifiedOnly,
        availableOnly: _availableOnly,
        onBloodGroupChanged: (value) {
          setState(() {
            _selectedBloodGroup = value;
          });
        },
        onDistanceChanged: (value) {
          setState(() {
            _distanceKm = value;
          });
        },
        onGenderChanged: (value) {
          setState(() {
            _selectedGender = value;
          });
        },
        onAgeRangeChanged: (min, max) {
          setState(() {
            _ageMin = min;
            _ageMax = max;
          });
        },
        onLastDonationChanged: (value) {
          setState(() {
            _selectedLastDonation = value;
          });
        },
        onVerifiedOnlyChanged: (value) {
          setState(() {
            _verifiedOnly = value;
          });
        },
        onAvailableOnlyChanged: (value) {
          setState(() {
            _availableOnly = value;
          });
        },
        onReset: () {
          setState(() {
            _selectedBloodGroup = 'All';
            _distanceKm = 10.0;
            _selectedGender = 'Any';
            _ageMin = 18.0;
            _ageMax = 60.0;
            _selectedLastDonation = 'Any time';
            _verifiedOnly = false;
            _availableOnly = true;
          });
          Navigator.pop(context);
          _searchDonors();
        },
        onApply: () {
          Navigator.pop(context);
          _searchDonors();
        },
      ),
    );
  }
}

class _DonorCard extends StatelessWidget {
  final Map<String, dynamic> donor;
  final VoidCallback onTap;

  const _DonorCard({
    required this.donor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = donor['full_name'] as String? ?? 'Unknown';
    final bloodType = donor['blood_type'] as String? ?? 'Unknown';
    final distance = donor['distance_km'] as double?;
    final isAvailable = donor['is_available'] as bool? ?? false;
    final totalDonations = donor['total_donations'] as int? ?? 0;
    final lastDonation = donor['last_donation_date'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.softPink,
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          bloodType,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (distance != null)
                        Text(
                          '${distance.toStringAsFixed(1)} km away',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isAvailable) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Available',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (totalDonations > 0)
                        Text(
                          '$totalDonations donation${totalDonations > 1 ? 's' : ''}',
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

            // Arrow
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBottomSheet extends StatefulWidget {
  final String selectedBloodGroup;
  final double distanceKm;
  final String selectedGender;
  final double ageMin;
  final double ageMax;
  final String selectedLastDonation;
  final bool verifiedOnly;
  final bool availableOnly;
  final Function(String) onBloodGroupChanged;
  final Function(double) onDistanceChanged;
  final Function(String) onGenderChanged;
  final Function(double, double) onAgeRangeChanged;
  final Function(String) onLastDonationChanged;
  final Function(bool) onVerifiedOnlyChanged;
  final Function(bool) onAvailableOnlyChanged;
  final VoidCallback onReset;
  final VoidCallback onApply;

  const _FilterBottomSheet({
    required this.selectedBloodGroup,
    required this.distanceKm,
    required this.selectedGender,
    required this.ageMin,
    required this.ageMax,
    required this.selectedLastDonation,
    required this.verifiedOnly,
    required this.availableOnly,
    required this.onBloodGroupChanged,
    required this.onDistanceChanged,
    required this.onGenderChanged,
    required this.onAgeRangeChanged,
    required this.onLastDonationChanged,
    required this.onVerifiedOnlyChanged,
    required this.onAvailableOnlyChanged,
    required this.onReset,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _selectedBloodGroup;
  late double _distanceKm;
  late String _selectedGender;
  late double _ageMin;
  late double _ageMax;
  late String _selectedLastDonation;
  late bool _verifiedOnly;
  late bool _availableOnly;

  final List<String> _bloodGroups = ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _genders = ['Any', 'Male', 'Female'];
  final List<String> _lastDonationOptions = ['Any time', 'Within 3 months', 'Within 6 months', 'Within 1 year'];

  @override
  void initState() {
    super.initState();
    _selectedBloodGroup = widget.selectedBloodGroup;
    _distanceKm = widget.distanceKm;
    _selectedGender = widget.selectedGender;
    _ageMin = widget.ageMin;
    _ageMax = widget.ageMax;
    _selectedLastDonation = widget.selectedLastDonation;
    _verifiedOnly = widget.verifiedOnly;
    _availableOnly = widget.availableOnly;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Text(
                  'Filter donors',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Blood Group
                  _buildSectionHeader('Blood Group'),
                  const SizedBox(height: 12),
                  _buildBloodGroupGrid(),
                  const SizedBox(height: 24),

                  // Distance
                  _buildSectionHeader('Distance'),
                  const SizedBox(height: 12),
                  _buildDistanceSlider(),
                  const SizedBox(height: 24),

                  // Gender
                  _buildSectionHeader('Gender'),
                  const SizedBox(height: 12),
                  _buildGenderButtons(),
                  const SizedBox(height: 24),

                  // Age Range
                  _buildSectionHeader('Age range'),
                  const SizedBox(height: 12),
                  _buildAgeRangeSlider(),
                  const SizedBox(height: 24),

                  // Availability
                  _buildAvailabilityToggle(),
                  const SizedBox(height: 24),

                  // Verified Only
                  _buildVerifiedToggle(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Reset Button
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onReset,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.primary, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Apply Button
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // Apply all changes
                      widget.onBloodGroupChanged(_selectedBloodGroup);
                      widget.onDistanceChanged(_distanceKm);
                      widget.onGenderChanged(_selectedGender);
                      widget.onAgeRangeChanged(_ageMin, _ageMax);
                      widget.onLastDonationChanged(_selectedLastDonation);
                      widget.onVerifiedOnlyChanged(_verifiedOnly);
                      widget.onAvailableOnlyChanged(_availableOnly);
                      widget.onApply();
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildBloodGroupGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _bloodGroups.length,
      itemBuilder: (context, index) {
        final bloodGroup = _bloodGroups[index];
        final isSelected = _selectedBloodGroup == bloodGroup;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedBloodGroup = bloodGroup;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                bloodGroup,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDistanceSlider() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Distance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Within ${_distanceKm.toInt()} km',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: const Color(0xFFE0E0E0),
            thumbColor: AppColors.primary,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayColor: AppColors.primary.withOpacity(0.1),
            trackHeight: 4,
          ),
          child: Slider(
            value: _distanceKm,
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: (value) {
              setState(() {
                _distanceKm = value;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '1 km',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              Text(
                '100 km',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderButtons() {
    return Row(
      children: _genders.map((gender) {
        final isSelected = _selectedGender == gender;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedGender = gender;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: gender != _genders.last ? 8 : 0),
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFE0E0E0),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  gender,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAgeRangeSlider() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Age range',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${_ageMin.toInt()} - ${_ageMax.toInt() > 60 ? '60+' : _ageMax.toInt()} yrs',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: const Color(0xFFE0E0E0),
            thumbColor: AppColors.primary,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayColor: AppColors.primary.withOpacity(0.1),
            trackHeight: 4,
          ),
          child: RangeSlider(
            values: RangeValues(_ageMin, _ageMax),
            min: 18,
            max: 60,
            divisions: 42,
            onChanged: (values) {
              setState(() {
                _ageMin = values.start;
                _ageMax = values.end;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '18',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              Text(
                '60+',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityToggle() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Available now',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Show only donors who are available',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _availableOnly = !_availableOnly;
            });
          },
          child: Container(
            width: 52,
            height: 28,
            decoration: BoxDecoration(
              color: _availableOnly ? AppColors.primary : const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _availableOnly ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedToggle() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verified only',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Show only verified donors',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _verifiedOnly = !_verifiedOnly;
            });
          },
          child: Container(
            width: 52,
            height: 28,
            decoration: BoxDecoration(
              color: _verifiedOnly ? AppColors.primary : const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _verifiedOnly ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
