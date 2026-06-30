import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

/// SOS Active Screen - Shows active emergency broadcast with live map and responders
/// Displays real map with SOS location and nearby donors who have responded
class SOSActiveScreen extends StatefulWidget {
  const SOSActiveScreen({super.key});

  @override
  State<SOSActiveScreen> createState() => _SOSActiveScreenState();
}

class _SOSActiveScreenState extends State<SOSActiveScreen> {
  // Timer for elapsed time
  Timer? _timer;
  int _elapsedSeconds = 0;

  // Map controller and markers
  late MapController _mapController;
  final List<Marker> _markers = [];
  LatLng? _sosLocation;
  bool _isLoading = true;
  String? _errorMessage;

  // SOS data
  Map<String, dynamic>? _sosRequest;
  List<Map<String, dynamic>> _responders = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _startTimer();
    _loadSOSData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  String get _elapsedTime {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _loadSOSData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get user's active SOS requests
      final response = await ApiService.getActiveSosRequests(
        lat: 0, // We'll get actual location from the SOS data
        lng: 0,
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final requests = data['requests'] as List? ?? [];

        if (requests.isNotEmpty) {
          // Get the most recent SOS request
          final sosRequest = requests.first as Map<String, dynamic>;

          // Parse location
          final lat = sosRequest['hospital_lat'] as double?;
          final lng = sosRequest['hospital_lng'] as double?;

          if (lat != null && lng != null) {
            setState(() {
              _sosRequest = sosRequest;
              _sosLocation = LatLng(lat, lng);
            });

            // Fetch nearby donors/responders
            await _fetchResponders(lat, lng);
          } else {
            setState(() {
              _errorMessage = 'SOS location not available';
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = 'No active SOS requests found';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load SOS data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading SOS: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchResponders(double lat, double lng) async {
    try {
      // Fetch nearby donors
      final response = await ApiService.getNearbyDonors(
        lat: lat,
        lng: lng,
        radius: 50,
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final donorsList = (data['donors'] as List? ?? [])
            .cast<Map<String, dynamic>>();

        setState(() {
          _responders = donorsList;
          _isLoading = false;
        });

        _createMarkers();
      } else {
        setState(() {
          _responders = [];
          _isLoading = false;
        });
        _createMarkers();
      }
    } catch (e) {
      print('Error fetching responders: $e');
      setState(() {
        _responders = [];
        _isLoading = false;
      });
      _createMarkers();
    }
  }

  void _createMarkers() {
    _markers.clear();

    if (_sosLocation == null) return;

    // Add SOS location marker (Blood Drop)
    _markers.add(
      Marker(
        point: _sosLocation!,
        width: 80,
        height: 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ripple
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
            ),
            // Blood drop icon
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFFD62828),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bloodtype,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );

    // Add responder markers
    for (var i = 0; i < _responders.length; i++) {
      final responder = _responders[i];
      final lat = responder['lat'] as double?;
      final lng = responder['lng'] as double?;

      if (lat != null && lng != null) {
        final bloodType = responder['blood_group'] as String? ?? 'Unknown';
        final name = responder['full_name'] as String? ?? 'Donor';

        _markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 60,
            height: 60,
            child: GestureDetector(
              onTap: () => _showResponderDialog(responder),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Blood type badge
                  Positioned(
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 3,
                          ),
                        ],
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
                  ),
                  // Avatar circle
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: AppColors.softPink,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'D',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Map Section
          Container(
            height: 250,
            child: _buildMapSection(),
          ),

          // Live Responders List
          Expanded(
            child: _buildRespondersList(),
          ),

          // Cancel SOS Button
          _buildCancelButton(),

          // Bottom spacing
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFB71C1C),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Back Button
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Title
              Expanded(
                child: Text(
                  'SOS Active — $_elapsedTime',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),

              // Refresh Button
              GestureDetector(
                onTap: _loadSOSData,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null || _sosLocation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Location not available',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _sosLocation!,
            initialZoom: 14,
            minZoom: 4,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            // OpenStreetMap tile layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.blood_donation',
              maxZoom: 18,
            ),
            // Markers layer
            MarkerLayer(markers: _markers),
          ],
        ),

        // Map controls overlay
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            children: [
              // Zoom in button
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  elevation: 2,
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      );
                    },
                  ),
                ),
              ),
              // Zoom out button
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  elevation: 2,
                  child: IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      );
                    },
                  ),
                ),
              ),
              // Recenter button
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                elevation: 2,
                child: IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: () {
                    if (_sosLocation != null) {
                      _mapController.move(_sosLocation!, 15);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRespondersList() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Column(
        children: [
          // List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nearby Donors (${_responders.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Responders List
          Expanded(
            child: _responders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No donors nearby yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your SOS is active and broadcasting',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _responders.length,
                    itemBuilder: (context, index) {
                      final responder = _responders[index];
                      return _ResponderCard(
                        name: responder['full_name'] as String? ?? 'Unknown',
                        bloodType: responder['blood_group'] as String? ?? 'Unknown',
                        distance: _calculateDistance(responder),
                        image: responder['profile_picture'] as String?,
                        isAvailable: responder['is_available_for_donation'] as bool? ?? true,
                        onTap: () {
                          _showResponderDialog(responder);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  double _calculateDistance(Map<String, dynamic> responder) {
    // Simple calculation - in production, use proper Haversine formula
    if (_sosLocation == null) return 0;

    final lat = responder['lat'] as double?;
    final lng = responder['lng'] as double?;

    if (lat == null || lng == null) return 0;

    final dLat = (lat - _sosLocation!.latitude) * 111; // Approx km per degree latitude
    final dLng = (lng - _sosLocation!.longitude) * 111 * (0.5 + 0.5 * (lat / 90).abs()); // Longitude varies by latitude

    return sqrt(dLat * dLat + dLng * dLng);
  }

  Widget _buildCancelButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            _showCancelSOSDialog();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFFB71C1C),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFFB71C1C), width: 2),
            ),
          ),
          child: const Text(
            'Cancel SOS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelSOSDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.warning_rounded,
              color: Color(0xFFD62828),
              size: 24,
            ),
            SizedBox(width: 12),
            Text('Cancel SOS?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this emergency broadcast? Nearby donors will no longer be notified of your request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Keep Active',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel SOS'),
          ),
        ],
      ),
    );
  }

  void _showResponderDialog(Map<String, dynamic> responder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.softPink,
              child: Text(
                (responder['full_name'] as String? ?? 'D')[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              responder['full_name'] as String? ?? 'Unknown',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                responder['blood_group'] as String? ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDialogStat(
                  '${_calculateDistance(responder).toStringAsFixed(1)} km',
                  'Distance',
                ),
                _buildDialogStat(
                  (responder['is_available_for_donation'] as bool? ?? true)
                      ? 'Available'
                      : 'Busy',
                  'Status',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to call or chat
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Contact'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ResponderCard extends StatelessWidget {
  final String name;
  final String bloodType;
  final double distance;
  final String? image;
  final bool isAvailable;
  final VoidCallback onTap;

  const _ResponderCard({
    required this.name,
    required this.bloodType,
    required this.distance,
    this.image,
    required this.isAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Profile Picture with Availability Dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.softPink,
                  backgroundImage: image != null && image!.isNotEmpty
                      ? NetworkImage(image!)
                      : null,
                  child: (image == null || image!.isEmpty)
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'D',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                if (isAvailable)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            // Responder Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Blood Type Row
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
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Distance
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 11,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${distance.toStringAsFixed(1)} km away',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow Icon
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
