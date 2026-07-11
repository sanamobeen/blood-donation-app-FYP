import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

/// SOS Detail Screen - Shows emergency blood request details for donors
/// Allows donors to respond to SOS requests with their ETA
class SOSDetailScreen extends StatefulWidget {
  final String sosId;

  const SOSDetailScreen({
    super.key,
    required this.sosId,
  });

  @override
  State<SOSDetailScreen> createState() => _SOSDetailScreenState();
}

class _SOSDetailScreenState extends State<SOSDetailScreen> {
  // SOS data
  Map<String, dynamic>? _sosData;
  bool _isLoading = true;
  String? _errorMessage;

  // Response data
  bool _isResponding = false;
  bool _hasResponded = false;
  String? _myResponseId; // User's response ID
  String? _myResponseStatus; // User's response status: pending, accepted, rejected, cancelled, etc.
  int? _myEta; // User's estimated arrival time
  final TextEditingController _etaController = TextEditingController(text: '15');
  final TextEditingController _noteController = TextEditingController();
  int _selectedEta = 15;

  // Location
  LatLng? _donorLocation;
  LatLng? _hospitalLocation;

  // Map controller
  late MapController _mapController;

  // Responders list
  List<Map<String, dynamic>> _responders = [];

  // Timer for auto-refresh
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadSOSDetail();
    _getCurrentLocation();
    // Auto-refresh every 15 seconds
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController.dispose();
    _etaController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _loadSOSDetail();
      }
    });
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
        _donorLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadSOSDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getSosDetail(widget.sosId);

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final sosRequest = data['sos_request'] as Map<String, dynamic>? ?? {};
        final responders = (sosRequest['responders'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];

        // Find user's own response (if any)
        final userId = await ApiService.getCurrentUserId();
        Map<String, dynamic>? myResponse;
        for (final responder in responders) {
          if (responder['responder_id'] == userId || responder['donor_id'] == userId) {
            myResponse = responder;
            break;
          }
        }

        setState(() {
          _sosData = sosRequest;
          _hasResponded = sosRequest['has_responded'] as bool? ?? false;
          _responders = responders;
          _myResponseId = myResponse?['id'] as String?;
          _myResponseStatus = myResponse?['status'] as String?;
          _myEta = _parseInt(myResponse?['estimated_arrival_minutes']);
          _isLoading = false;
        });

        // Parse hospital location
        final lat = _parseDouble(sosRequest['hospital_lat']);
        final lng = _parseDouble(sosRequest['hospital_lng']);
        if (lat != null && lng != null) {
          setState(() {
            _hospitalLocation = LatLng(lat, lng);
          });
        }
      } else {
        setState(() {
          _errorMessage = response['message'] as String? ?? 'Failed to load SOS details';
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

  Future<void> _respondToSOS() async {
    setState(() {
      _isResponding = true;
    });

    try {
      final response = await ApiService.respondToSos(
        sosId: widget.sosId,
        canHelp: true,
        estimatedArrivalMinutes: _selectedEta,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
      );

      setState(() {
        _isResponding = false;
      });

      if (response['success'] == true) {
        setState(() {
          _hasResponded = true;
        });
        _showResponseSuccessDialog();
      } else {
        _showErrorDialog(response['message'] as String? ?? 'Failed to respond');
      }
    } catch (e) {
      setState(() {
        _isResponding = false;
      });
      _showErrorDialog('Network error: $e');
    }
  }

  void _showResponseSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Response Sent!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'ve responded to this emergency. The requester will be notified.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ETA: $_selectedEta minutes',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Go back to notifications
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showUpdateEtaDialog() {
    final etaController = TextEditingController(text: _myEta?.toString() ?? '15');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Your ETA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How many minutes until you arrive?'),
            const SizedBox(height: 16),
            TextField(
              controller: etaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ETA (minutes)',
                border: OutlineInputBorder(),
                suffixText: 'min',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newEta = int.tryParse(etaController.text);
              if (newEta != null && newEta > 0) {
                Navigator.pop(context);
                _updateEta(newEta);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEta(int newEta) async {
    if (_myResponseId == null) return;

    setState(() {
      _isResponding = true;
    });

    try {
      final response = await ApiService.updateResponseEta(
        sosId: widget.sosId,
        responseId: _myResponseId!,
        estimatedArrivalMinutes: newEta,
        note: 'Updated ETA',
      );

      setState(() {
        _isResponding = false;
      });

      if (response['success'] == true) {
        setState(() {
          _myEta = newEta;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ETA updated! The requester has been notified.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Reload to get updated data
        _loadSOSDetail();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] as String? ?? 'Failed to update ETA'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isResponding = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmArrival() async {
    if (_myResponseId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Arrival?'),
        content: const Text('Confirm that you have arrived at the hospital?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm Arrival'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isResponding = true;
    });

    try {
      final response = await ApiService.confirmDonorArrival(
        sosId: widget.sosId,
        responseId: _myResponseId!,
      );

      setState(() {
        _isResponding = false;
      });

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Arrival confirmed! The requester has been notified.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Reload to get updated status
        _loadSOSDetail();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] as String? ?? 'Failed to confirm arrival'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isResponding = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmOnMyWay() async {
    if (_myResponseId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm You\'re Coming?'),
        content: const Text('Let the patient know you received their acceptance and you\'re on your way.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm I\'m Coming'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isResponding = true;
    });

    try {
      final response = await ApiService.confirmOnMyWay(
        sosId: widget.sosId,
        responseId: _myResponseId!,
      );

      setState(() {
        _isResponding = false;
      });

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient has been notified you\'re on your way!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] as String? ?? 'Failed to confirm'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isResponding = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelResponse() async {
    if (_myResponseId == null) return;

    // Show confirmation dialog with reason input
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Can\'t Make It?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Let the requester know you won\'t be able to make it.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g., Stuck in traffic',
              ),
              maxLines: 2,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Notify Requester'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isResponding = true;
    });

    try {
      final response = await ApiService.donorCannotArrive(
        sosId: widget.sosId,
        responseId: _myResponseId!,
        reason: reasonController.text.isNotEmpty ? reasonController.text : null,
      );

      setState(() {
        _isResponding = false;
      });

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Requester has been notified.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        // Reload to get updated status
        _loadSOSDetail();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] as String? ?? 'Failed to cancel'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isResponding = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? _buildErrorView()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFD62828),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Back Button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                ),
              ),

              const SizedBox(width: 12),

              // Title
              const Expanded(
                child: Text(
                  'Emergency Request',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),

              // Status Badge
              if (_sosData != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _sosData?['status']?.toString().toUpperCase() ?? 'ACTIVE',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to load SOS details',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadSOSDetail,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_sosData == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadSOSDetail,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map
            _buildMapSection(),

            // Emergency Info Card
            _buildEmergencyInfoCard(),

            // Patient Details
            _buildPatientDetailsCard(),

            // Hospital Details
            _buildHospitalDetailsCard(),

            // Responders
            if (_responders.isNotEmpty) _buildRespondersSection(),

            const SizedBox(height: 16),

            // Response Form (if not already responded)
            if (!_hasResponded) _buildResponseForm(),

            // Already responded message
            if (_hasResponded) _buildRespondedMessage(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    if (_hospitalLocation == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _hospitalLocation!,
              initialZoom: 14,
              minZoom: 4,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.blood_donation',
                maxZoom: 18,
              ),
              MarkerLayer(
                markers: [
                  // Hospital marker
                  if (_hospitalLocation != null)
                    Marker(
                      point: _hospitalLocation!,
                      width: 60,
                      height: 60,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD62828),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.local_hospital, color: Colors.white, size: 28),
                          ),
                        ],
                      ),
                    ),
                  // Donor marker
                  if (_donorLocation != null)
                    Marker(
                      point: _donorLocation!,
                      width: 40,
                      height: 40,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Map controls
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              children: [
                _buildMapControl(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                const SizedBox(height: 8),
                _buildMapControl(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
                const SizedBox(height: 8),
                _buildMapControl(Icons.my_location, () {
                  if (_donorLocation != null) {
                    _mapController.move(_donorLocation!, 15);
                  } else if (_hospitalLocation != null) {
                    _mapController.move(_hospitalLocation!, 15);
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(width: 40, height: 40, child: Icon(icon, size: 20)),
      ),
    );
  }

  Widget _buildEmergencyInfoCard() {
    final bloodType = _sosData?['blood_type'] as String? ?? 'Unknown';
    final unitsNeeded = _parseInt(_sosData?['units_needed']) ?? 1;
    final timeAgo = _formatTimestamp(_sosData?['created_at'] as String?);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFFD62828), const Color(0xFFB71C1C)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildEmergencyStat('Blood Group', bloodType, Icons.bloodtype),
          _buildEmergencyStat('Units', '$unitsNeeded', Icons.water_drop),
          _buildEmergencyStat('Posted', timeAgo, Icons.access_time),
        ],
      ),
    );
  }

  Widget _buildEmergencyStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildPatientDetailsCard() {
    final patientName = _sosData?['patient_name'] as String? ?? 'Unknown';
    final age = _parseInt(_sosData?['age']) ?? 0;
    final gender = _sosData?['gender'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.softPink, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.person, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Patient Information', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(patientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Show age and gender chips only if available
          if (age > 0 || gender.isNotEmpty)
            Row(
              children: [
                if (age > 0) ...[
                  _buildInfoChip('Age: $age', Icons.cake),
                  if (gender.isNotEmpty) const SizedBox(width: 8),
                ],
                if (gender.isNotEmpty)
                  _buildInfoChip(gender[0].toUpperCase() + gender.substring(1), Icons.wc),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppColors.softPink, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildHospitalDetailsCard() {
    final hospitalName = _sosData?['hospital_name'] as String? ?? 'Unknown';
    final hospitalAddress = _sosData?['hospital_address'] as String? ?? '';
    final contactPhone = _sosData?['contact_phone'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.local_hospital, color: Colors.blue.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hospital Information', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(hospitalName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text(hospitalAddress, style: const TextStyle(fontSize: 13))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.phone, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(contactPhone, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRespondersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_responders.length} Responding', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (_responders.isNotEmpty)
                Text('${_responders.length} donor${_responders.length > 1 ? 's' : ''} on the way',
                    style: const TextStyle(fontSize: 12, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_responders.length, (index) {
            final responder = _responders[index];
            return _ResponderCard(
              name: responder['donor_name'] as String? ?? 'Anonymous',
              eta: _parseInt(responder['estimated_arrival_minutes']) ?? 0,
              note: responder['note'] as String?,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResponseForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.emergency, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Can you help?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ETA Section
          _buildSectionTitle('Estimated Time of Arrival*'),
          const SizedBox(height: 12),
          _buildEtaSelector(),
          const SizedBox(height: 20),

          // Notes Section
          _buildSectionTitle('Additional Notes (Optional)'),
          const SizedBox(height: 12),
          _buildNotesField(),
          const SizedBox(height: 24),

          // Submit Button
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildEtaSelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ETA:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedEta,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.primary,
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              items: const [
                DropdownMenuItem(value: 5, child: Text('5 minutes')),
                DropdownMenuItem(value: 10, child: Text('10 minutes')),
                DropdownMenuItem(value: 15, child: Text('15 minutes')),
                DropdownMenuItem(value: 20, child: Text('20 minutes')),
                DropdownMenuItem(value: 30, child: Text('30 minutes')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedEta = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _noteController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Add any additional notes or contact information...',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.focus, width: 2),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isResponding ? null : _respondToSOS,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
        ),
        child: _isResponding
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'I Can Help!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }


  Widget _buildRespondedMessage() {
    // Show different content based on response status
    final status = _myResponseStatus ?? 'pending';
    final Color statusColor;
    final IconData statusIcon;
    final String statusTitle;
    final String statusMessage;

    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusTitle = 'Requester Accepted You!';
        statusMessage = 'You\'re on your way! Update your ETA if needed.';
        break;
      case 'rejected':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        statusTitle = 'Response Not Selected';
        statusMessage = 'The requester selected another donor. Thank you for your willingness to help!';
        break;
      case 'cancelled':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        statusTitle = 'Response Cancelled';
        statusMessage = 'You cancelled your response to this SOS request.';
        break;
      case 'donated':
        statusColor = Colors.red;
        statusIcon = Icons.favorite;
        statusTitle = 'Donation Completed!';
        statusMessage = 'Thank you for your life-saving donation!';
        break;
      case 'no_show':
        statusColor = Colors.red.shade300;
        statusIcon = Icons.person_off;
        statusTitle = 'Marked as No-Show';
        statusMessage = 'Your response was marked as no-show. Please confirm arrival promptly in the future.';
        break;
      default: // pending
        statusColor = Colors.blue;
        statusIcon = Icons.access_time;
        statusTitle = 'You\'ve Responded!';
        statusMessage = 'The requester has been notified. Waiting for their response.';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: status == 'accepted' ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status == 'accepted' ? Colors.green.shade200 : Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: status == 'accepted' ? Colors.green.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: statusColor)),
                    const SizedBox(height: 4),
                    Text(statusMessage, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          // Show action buttons for accepted responses
          if (status == 'accepted' && _myResponseId != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isResponding ? null : () => _confirmOnMyWay(),
                    icon: _isResponding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle, size: 18),
                    label: Text(_isResponding ? 'Confirming...' : 'I\'m Coming'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showUpdateEtaDialog(),
                    icon: const Icon(Icons.access_time, size: 18),
                    label: const Text('Update ETA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmArrival(),
                    icon: const Icon(Icons.location_on, size: 18),
                    label: const Text('Arrived'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _cancelResponse(),
                icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                label: const Text('I Can\'t Make It', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Just now';

    try {
      final dateTime = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${dateTime.day}/${dateTime.month}';
      }
    } catch (e) {
      return 'Unknown';
    }
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
}

class _ResponderCard extends StatelessWidget {
  final String name;
  final int eta;
  final String? note;

  const _ResponderCard({
    required this.name,
    required this.eta,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary,
            child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (note != null && note!.isNotEmpty)
                  Text(note!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
            child: Text('$eta min', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
          ),
        ],
      ),
    );
  }
}
