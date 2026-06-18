import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/blood_type_chip.dart';

/// SOS Active Screen - Shows active emergency broadcast with live responders
/// Displayed after SOS is activated, showing map and nearby donor responses
class SOSActiveScreen extends StatefulWidget {
  const SOSActiveScreen({super.key});

  @override
  State<SOSActiveScreen> createState() => _SOSActiveScreenState();
}

class _SOSActiveScreenState extends State<SOSActiveScreen> {
  // Timer for elapsed time
  Timer? _timer;
  int _elapsedSeconds = 83; // Starting at 1:23 (83 seconds)

  // Broadcast stats
  int _donorsNotified = 47;
  int _respondedCount = 8;

  // Sort options
  String _selectedSort = 'Newest first';

  // Sample responders data
  final List<Map<String, dynamic>> _responders = [
    {
      'id': '1',
      'name': 'Arjun N.',
      'bloodType': 'O+',
      'units': 2,
      'distance': 1.2,
      'image': 'https://i.pravatar.cc/150?img=68',
      'isAvailable': true,
      'responseTime': 'Just now',
    },
    {
      'id': '2',
      'name': 'Priya S.',
      'bloodType': 'B+',
      'units': 1,
      'distance': 2.4,
      'image': 'https://i.pravatar.cc/150?img=47',
      'isAvailable': true,
      'responseTime': '1 min ago',
    },
    {
      'id': '3',
      'name': 'Rohit K.',
      'bloodType': 'O+',
      'units': 2,
      'distance': 3.1,
      'image': 'https://i.pravatar.cc/150?img=33',
      'isAvailable': true,
      'responseTime': '2 min ago',
    },
    {
      'id': '4',
      'name': 'Meera T.',
      'bloodType': 'A+',
      'units': 1,
      'distance': 4.7,
      'image': 'https://i.pravatar.cc/150?img=45',
      'isAvailable': true,
      'responseTime': '3 min ago',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Map Section
          _buildMapSection(),

          // Live Responders List
          Expanded(
            child: _buildRespondersList(),
          ),

          // Cancel SOS Button
          _buildCancelButton(),

          // Bottom Broadcast Indicator
          _buildBottomIndicator(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFB71C1C), // Dark red
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () {
                      _showCancelSOSDialog();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.sos_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SOS Active — $_elapsedTime elapsed',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_donorsNotified donors notified — $_respondedCount responded',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Shield Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: Colors.white,
                      size: 20,
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

  Widget _buildMapSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E6), // Light beige map color
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Stack(
        children: [
          // Map Grid Lines
          ..._buildMapGrid(),

          // Neighborhood Labels
          ..._buildNeighborhoodLabels(),

          // SOS Location Marker (Blood Drop)
          Positioned(
            left: MediaQuery.of(context).size.width * 0.4,
            top: 70,
            child: Column(
              children: [
                // Outer ripple circle
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                // Inner ripple circle
                Positioned(
                  left: 20,
                  top: 20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                // Blood drop icon
                Positioned(
                  left: 40,
                  top: 40,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD62828),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bloodtype,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Responder Profile Icons on Map
          ..._buildResponderMapMarkers(),

          // User's Location (Blue dot)
          Positioned(
            left: MediaQuery.of(context).size.width * 0.55,
            top: 130,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // Compass/Rotate Icon
          Positioned(
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: () {
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMapGrid() {
    return List.generate(15, (index) {
      return Positioned(
        top: (index % 5) * 50.0,
        left: ((index / 5).floor() * 80.0),
        child: Container(
          width: 80,
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFFE0D6C0).withOpacity(0.4),
              width: 1,
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildNeighborhoodLabels() {
    final neighborhoods = [
      {'name': 'DOMLUR', 'x': 0.15, 'y': 0.2},
      {'name': 'INORANAGAR', 'x': 0.65, 'y': 0.15},
      {'name': 'KORAMANGALA', 'x': 0.1, 'y': 0.7},
      {'name': 'BELLANDUR', 'x': 0.75, 'y': 0.75},
    ];

    return neighborhoods.map((data) {
      return Positioned(
        left: MediaQuery.of(context).size.width * (data['x'] as double),
        top: (data['y'] as double) * 150,
        child: Text(
          data['name'] as String,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withOpacity(0.7),
            letterSpacing: 1,
          ),
        ),
      );
    }).toList();
  }

  // Build responder profile icons displayed on the map
  List<Widget> _buildResponderMapMarkers() {
    // Positions for responders on map (0.0-1.0 relative to map area)
    final markerPositions = [
      {'x': 0.25, 'y': 0.35, 'responderIndex': 0}, // Arjun N.
      {'x': 0.70, 'y': 0.25, 'responderIndex': 1}, // Priya S.
      {'x': 0.15, 'y': 0.65, 'responderIndex': 2}, // Rohit K.
      {'x': 0.80, 'y': 0.55, 'responderIndex': 3}, // Meera T.
    ];

    return markerPositions.map((pos) {
      final index = pos['responderIndex'] as int;
      final responder = _responders[index];

      return Positioned(
        left: MediaQuery.of(context).size.width * (pos['x'] as double) - 20,
        top: 30 + (pos['y'] as double) * 140,
        child: GestureDetector(
          onTap: () {
            _showResponderDialog(responder);
          },
          child: Column(
            children: [
              // Blood type badge above avatar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  responder['bloodType'] as String,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Avatar with shadow
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(responder['image'] as String),
                      backgroundColor: AppColors.softPink,
                    ),
                  ),
                  // Online indicator
                  if (responder['isAvailable'] as bool)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.online,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildRespondersList() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Live Responders',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_respondedCount',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                // Sort Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Newest first',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Responders List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _responders.length,
              itemBuilder: (context, index) {
                final responder = _responders[index];
                return _ResponderCard(
                  name: responder['name'] as String,
                  bloodType: responder['bloodType'] as String,
                  units: responder['units'] as int,
                  distance: responder['distance'] as double,
                  image: responder['image'] as String,
                  isAvailable: responder['isAvailable'] as bool,
                  responseTime: responder['responseTime'] as String,
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

  Widget _buildCancelButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.primary, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextButton(
        onPressed: () {
          _showCancelSOSDialog();
        },
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Cancel SOS',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomIndicator() {
    return Container(
      height: 40,
      color: const Color(0xFFD62828),
      child: Center(
        child: Text(
          '3 SOS ACTIVE BROADCAST',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 2,
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
              backgroundImage: NetworkImage(responder['image'] as String),
            ),
            const SizedBox(height: 16),
            Text(
              responder['name'] as String,
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
                responder['bloodType'] as String,
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
                  '${responder['units']}',
                  'Units',
                ),
                _buildDialogStat(
                  '${responder['distance']} km',
                  'Distance',
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
  final int units;
  final double distance;
  final String image;
  final bool isAvailable;
  final String responseTime;
  final VoidCallback onTap;

  const _ResponderCard({
    required this.name,
    required this.bloodType,
    required this.units,
    required this.distance,
    required this.image,
    required this.isAvailable,
    required this.responseTime,
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Profile Picture with Availability Dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(image),
                  backgroundColor: AppColors.softPink,
                ),
                if (isAvailable)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
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
                  // Name and Response Time
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isAvailable)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.online,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const Spacer(),
                      Text(
                        responseTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Blood Type Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      bloodType,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Units and Distance
                  Row(
                    children: [
                      Icon(
                        Icons.bloodtype_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$units Unit${units > 1 ? 's' : ''} available',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${distance.toStringAsFixed(1)} km',
                        style: TextStyle(
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
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
