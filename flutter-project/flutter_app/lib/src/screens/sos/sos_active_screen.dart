import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

/// SOS Active Screen - Shows active emergency broadcast with live map and responders
/// Displays real map with SOS location and nearby donors who have responded
class SOSActiveScreen extends StatefulWidget {
  /// Optional SOS ID - if provided, will load this specific SOS request
  final String? sosId;

  const SOSActiveScreen({
    super.key,
    this.sosId,
  });

  @override
  State<SOSActiveScreen> createState() => _SOSActiveScreenState();
}

class _SOSActiveScreenState extends State<SOSActiveScreen> {
  // Timer for elapsed time
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isTimerStopped = false; // Flag to track if timer is stopped

  // Map controller and markers
  late MapController _mapController;
  final List<Marker> _markers = [];
  LatLng? _sosLocation;
  bool _isLoading = true;
  String? _errorMessage;

  // SOS data
  String? _sosId; // Store SOS ID for actions
  List<Map<String, dynamic>> _responders = [];
  bool _isSOSResolved = false; // Track if SOS is resolved

  // Location
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _startTimer();
    _getCurrentLocation();
    _loadSOSData();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isTimerStopped) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _stopTimer() {
    setState(() {
      _isTimerStopped = true;
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
      // If SOS ID is provided (from navigation), fetch that specific SOS
      if (widget.sosId != null) {
        final response = await ApiService.getSosDetail(widget.sosId!);

        if (response['success'] == true) {
          final data = response['data'] as Map<String, dynamic>?;
          final sosRequest = data?['sos_request'] as Map<String, dynamic>?;
          final responders = data?['responders'] as List?;

          if (sosRequest != null) {
            _processSOSRequest(sosRequest, responders);
          } else {
            setState(() {
              _errorMessage = 'SOS request data not available';
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = response['message'] ?? 'Failed to load SOS details';
            _isLoading = false;
          });
        }
        return;
      }

      // Otherwise, get current user's active SOS requests
      final response = await ApiService.getMyActiveSosRequests();

      if (response['success'] == true) {
        // FIXED: requests is directly in response, not in response['data']['requests']
        final requests = response['requests'] as List?;

        print('🔍 DEBUG: Number of requests = ${requests?.length ?? 0}');

        if (requests != null && requests.isNotEmpty) {
          // Get the most recent SOS request (created by this user)
          final sosRequest = requests.first as Map<String, dynamic>;
          final responders = sosRequest['responders'] as List?;
          print('🔍 DEBUG: Responders from API = ${responders?.length ?? 0}');
          _processSOSRequest(sosRequest, responders);
        } else {
          setState(() {
            _errorMessage = 'No active SOS requests found. Create an SOS request to see responders here.';
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

  void _processSOSRequest(Map<String, dynamic> sosRequest, [List? responders]) {
    // Parse location
    final lat = _parseDouble(sosRequest['hospital_lat']);
    final lng = _parseDouble(sosRequest['hospital_lng']);

    if (lat != null && lng != null) {
      // Load responders - use passed list or try to get from sosRequest
      List<Map<String, dynamic>> responderList = [];

      if (responders != null && responders.isNotEmpty) {
        // Convert List<dynamic> to List<Map<String, dynamic>>
        responderList = responders
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (sosRequest['responders'] != null) {
        // Extract from sosRequest
        final respondersList = sosRequest['responders'] as List?;
        if (respondersList != null && respondersList.isNotEmpty) {
          responderList = respondersList
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      setState(() {
        _sosId = sosRequest['id'] as String?;
        _sosLocation = LatLng(lat, lng);
        _responders = responderList;
        _isLoading = false;
      });

      // Debug output
      print('🔍 DEBUG: SOS ID = $_sosId');
      print('🔍 DEBUG: Responders count = ${responderList.length}');
      if (responderList.isNotEmpty) {
        for (var i = 0; i < responderList.length; i++) {
          print('🔍 DEBUG: Responder $i = ${responderList[i]}');
        }
      }

      _createMarkers();
    } else {
      setState(() {
        _errorMessage = 'SOS location not available';
        _isLoading = false;
      });
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
      // Responders may or may not have location data depending on backend response
      final lat = _parseDouble(responder['lat']) ?? _parseDouble(responder['donor_lat']);
      final lng = _parseDouble(responder['lng']) ?? _parseDouble(responder['donor_lng']);

      if (lat != null && lng != null) {
        final bloodType = responder['blood_group'] as String? ?? 'Unknown';
        final name = responder['responder_name'] as String? ?? responder['donor_name'] as String? ?? responder['full_name'] as String? ?? 'Donor';

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
      decoration: BoxDecoration(
        color: _isSOSResolved ? Colors.green : const Color(0xFFB71C1C),
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
                  _isSOSResolved ? 'SOS Completed ✓' : 'SOS Active — $_elapsedTime',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),

              // Refresh Button
              if (!_isSOSResolved)
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
                      final responseId = responder['id'] as String?;
                      final status = responder['status'] as String? ?? 'pending';
                      final eta = _parseInt(responder['estimated_arrival_minutes']);

                      // Calculate minutes past ETA
                      final acceptedAt = _parseDateTime(responder['accepted_at']);
                      final minutesLate = acceptedAt != null && eta != null
                          ? (_elapsedSeconds / 60).floor() - eta
                          : null;

                      // Debug output
                      print('🔍 Card $index: status=$status, responseId=$responseId, sosId=$_sosId');
                      print('🔍 Card $index: onAccept=${status == 'pending' && responseId != null && _sosId != null}');

                      return _ResponderCard(
                        name: responder['responder_name'] as String? ?? responder['donor_name'] as String? ?? responder['full_name'] as String? ?? 'Unknown',
                        bloodType: responder['blood_group'] as String? ?? 'Unknown',
                        distance: _calculateDistance(responder),
                        image: responder['profile_picture'] as String?,
                        isAvailable: true,
                        eta: eta,
                        status: status,
                        responseId: responseId,
                        sosId: _sosId,
                        minutesLate: minutesLate != null ? (minutesLate > 0 ? minutesLate : null) : null,
                        onTap: () {
                          _showResponderDialog(responder);
                        },
                        onAccept: status == 'pending' && responseId != null && _sosId != null
                            ? () => _acceptResponder(responseId!)
                            : null,
                        onConfirm: status == 'accepted' && responseId != null && _sosId != null
                            ? () => _confirmDonation(responseId!)
                            : null,
                        onNotifyLate: (minutesLate != null && minutesLate >= 5) && responseId != null && _sosId != null
                            ? () => _notifyDonorLate(responseId!, minutesLate)
                            : null,
                        onMarkNoShow: (minutesLate != null && minutesLate >= 10) && responseId != null && _sosId != null
                            ? () => _markNoShow(responseId!)
                            : null,
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

    final lat = _parseDouble(responder['lat']) ?? _parseDouble(responder['donor_lat']);
    final lng = _parseDouble(responder['lng']) ?? _parseDouble(responder['donor_lng']);

    if (lat == null || lng == null) return 0;

    final dLat = (lat - _sosLocation!.latitude) * 111; // Approx km per degree latitude
    final dLng = (lng - _sosLocation!.longitude) * 111 * (0.5 + 0.5 * (lat / 90).abs()); // Longitude varies by latitude

    return sqrt(dLat * dLat + dLng * dLng);
  }

  Future<void> _acceptResponder(String responseId) async {
    if (_sosId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Accept Donor?'),
        content: const Text('This donor will be notified that you have accepted them. They can now contact you for coordination.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Call API to accept
    final result = await ApiService.acceptSosResponse(sosId: _sosId!, responseId: responseId);

    if (result['success'] == true) {
      // Reload data to show updated status
      _loadSOSData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donor accepted! They will be notified.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Failed to accept donor'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDonation(String responseId) async {
    if (_sosId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Donation?'),
        content: const Text('Please confirm that this donor has completed the blood donation. This will help track successful donations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm Donation'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Call API to confirm
    final result = await ApiService.confirmDonation(sosId: _sosId!, responseId: responseId);

    if (result['success'] == true) {
      // Stop the timer and mark SOS as resolved
      _stopTimer();
      setState(() {
        _isSOSResolved = true;
      });

      // Reload data to show updated status
      _loadSOSData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donation confirmed! SOS completed successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Failed to confirm donation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _notifyDonorLate(String responseId, int minutesLate) async {
    if (_sosId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remind Donor?'),
        content: Text('The donor is $minutesLate minutes late. Send them a gentle reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Send Reminder'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Call API to notify donor
    final result = await ApiService.notifyDonorLate(
      sosId: _sosId!,
      responseId: responseId,
      minutesLate: minutesLate,
    );

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder sent to donor!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Failed to send reminder'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markNoShow(String responseId) async {
    if (_sosId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as No-Show?'),
        content: const Text('This will mark the donor as no-show. They will be notified. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
            child: const Text('Mark No-Show'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Call API to mark no-show
    final result = await ApiService.markNoShow(
      sosId: _sosId!,
      responseId: responseId,
    );

    if (result['success'] == true) {
      // Reload data to show updated status
      _loadSOSData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donor marked as no-show'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Failed to mark no-show'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCancelButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            if (_isSOSResolved) {
              // Just close the screen if SOS is resolved
              Navigator.pop(context);
            } else {
              _showCancelSOSDialog();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _isSOSResolved ? Colors.green : const Color(0xFFB71C1C),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: _isSOSResolved ? Colors.green : const Color(0xFFB71C1C),
                width: 2,
              ),
            ),
          ),
          child: Text(
            _isSOSResolved ? 'Close' : 'Cancel SOS',
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
    // Handle different field names from backend
    final name = responder['donor_name'] as String? ?? responder['full_name'] as String? ?? responder['responder_name'] as String? ?? 'Unknown';
    final bloodGroup = responder['blood_group'] as String? ?? 'Unknown';
    final eta = _parseInt(responder['estimated_arrival_minutes']);
    final distance = _calculateDistance(responder);
    final phone = responder['contact_phone'] as String? ?? responder['phone'] as String?;
    final note = responder['note'] as String?;
    final status = responder['status'] as String? ?? 'pending';
    final respondedAt = responder['responded_at'] as String? ?? responder['created_at'] as String?;

    // Format response time
    String responseTimeStr = '';
    if (respondedAt != null) {
      try {
        final respondedTime = DateTime.parse(respondedAt).toLocal();
        final now = DateTime.now();
        final difference = now.difference(respondedTime);
        if (difference.inMinutes < 60) {
          responseTimeStr = '${difference.inMinutes}m ago';
        } else if (difference.inHours < 24) {
          responseTimeStr = '${difference.inHours}h ago';
        } else {
          responseTimeStr = '${respondedTime.day}/${respondedTime.month}';
        }
      } catch (e) {
        responseTimeStr = 'Unknown';
      }
    }

    // Status display
    String statusDisplay = '';
    Color statusColor = Colors.grey;
    switch (status) {
      case 'pending':
        statusDisplay = 'Waiting';
        statusColor = Colors.orange;
        break;
      case 'accepted':
        statusDisplay = 'Accepted';
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusDisplay = 'Passed';
        statusColor = Colors.grey;
        break;
      case 'donated':
        statusDisplay = 'Donated ✓';
        statusColor = Colors.red;
        break;
      case 'no_show':
        statusDisplay = 'No-Show';
        statusColor = Colors.red.shade300;
        break;
      default:
        statusDisplay = status;
        statusColor = Colors.grey;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar and Status
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: AppColors.softPink,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'D',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  // Status badge
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Blood Group
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bloodtype,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      bloodGroup,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDialogStat(
                    '${distance.toStringAsFixed(1)} km',
                    'Distance',
                    Icons.location_on_rounded,
                  ),
                  if (eta != null)
                    _buildDialogStat(
                      '$eta min',
                      'ETA',
                      Icons.access_time,
                    )
                  else
                    _buildDialogStat(
                      'Available',
                      'Status',
                      Icons.check_circle,
                    ),
                  _buildDialogStat(
                    responseTimeStr.isNotEmpty ? responseTimeStr : 'Now',
                    'Responded',
                    Icons.schedule,
                  ),
                ],
              ),

              // Note from donor (if available)
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Message from donor:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        note,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Phone number (if available)
              if (phone != null && phone.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone, size: 18, color: Colors.green.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          phone,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // Could add phone call functionality here
                        },
                        icon: Icon(Icons.call, color: Colors.green.shade700),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16,
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

  Widget _buildDialogStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Parse a value as double, handling both double and string inputs
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Parse a value as int, handling both int and string inputs
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Parse a datetime string into DateTime object
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}

class _ResponderCard extends StatelessWidget {
  final String name;
  final String bloodType;
  final double distance;
  final String? image;
  final bool isAvailable;
  final int? eta; // Estimated time of arrival in minutes
  final String? status; // Response status: pending, accepted, donated, etc.
  final String? responseId; // Response ID for actions
  final String? sosId; // SOS ID for actions
  final int? elapsedMinutes; // Minutes since acceptance (for no-show calculation)
  final int? minutesLate; // Minutes past ETA (for late notification)
  final VoidCallback onTap;
  final VoidCallback? onAccept; // Callback for accept action
  final VoidCallback? onConfirm; // Callback for confirm donation action
  final VoidCallback? onMarkNoShow; // Callback for mark no-show action
  final VoidCallback? onNotifyLate; // Callback for notify donor late action

  const _ResponderCard({
    required this.name,
    required this.bloodType,
    required this.distance,
    this.image,
    required this.isAvailable,
    this.eta,
    this.status,
    this.responseId,
    this.sosId,
    this.elapsedMinutes,
    this.minutesLate,
    required this.onTap,
    this.onAccept,
    this.onConfirm,
    this.onMarkNoShow,
    this.onNotifyLate,
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

                  // Distance and ETA Row
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
                      if (eta != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 10, color: Colors.green),
                              const SizedBox(width: 2),
                              Text(
                                '${eta}m',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Action Buttons or Status Badge
            _buildActionSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection() {
    // Show action buttons based on status
    if (status == 'pending' && onAccept != null) {
      // Show Accept button
      return GestureDetector(
        onTap: onAccept,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text(
                'Accept',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (status == 'accepted') {
      // For accepted status, show different buttons based on lateness
      if (minutesLate != null && minutesLate! >= 5) {
        // Donor is late - show both "Notify Late" and "Confirm" buttons
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onNotifyLate != null)
              GestureDetector(
                onTap: onNotifyLate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.white, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        'Remind',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (onNotifyLate != null && onConfirm != null) const SizedBox(width: 6),
            if (onConfirm != null)
              GestureDetector(
                onTap: onConfirm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.favorite, color: Colors.white, size: 14),
                      SizedBox(width: 3),
                      Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (onMarkNoShow != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onMarkNoShow,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_off, color: Colors.white, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        'No-Show',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      } else if (onConfirm != null) {
        // Show Confirm Donation button (not late yet)
        return GestureDetector(
          onTap: onConfirm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.favorite, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  'Confirm',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Accepted but no actions available - show accepted badge
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 4),
              Text(
                'Accepted',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        );
      }
    } else if (status == 'donated') {
      // Show Donated badge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 4),
            Text(
              'Donated',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    } else if (status == 'rejected') {
      // Show Rejected badge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Passed',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      );
    } else {
      // Default arrow icon
      return Icon(
        Icons.arrow_forward_ios_rounded,
        size: 12,
        color: Colors.grey.shade400,
      );
    }
  }
}
