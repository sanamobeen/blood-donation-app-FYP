import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/role_provider.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  // Blood groups
  final List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-',
  ];

  // Distance options
  final List<double> _distanceOptions = [5, 15, 25, 50];
  double _selectedDistance = 5;

  // Selected values
  String? _selectedBloodGroup;
  int _unitsNeeded = 1;
  String _situationDescription = '';

  // Controllers
  late TextEditingController _situationController;

  // SOS activation
  bool _isHolding = false;
  bool _isActivated = false;

  @override
  void initState() {
    super.initState();
    _situationController = TextEditingController(text: _situationDescription);
    // Check if user is a patient
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserRole();
    });
  }

  @override
  void dispose() {
    _situationController.dispose();
    super.dispose();
  }

  void _checkUserRole() {
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);

    if (!roleProvider.isPatient) {
      // Show access denied dialog and navigate back
      _showAccessDeniedDialog();
    }
  }

  void _showAccessDeniedDialog() {
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);
    String currentRole = roleProvider.currentRole ?? 'None';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block,
                color: Colors.orange.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Access Denied'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The SOS emergency feature is only available for patients.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your current role: $currentRole',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'If you need blood as a donor, please use the regular blood request feature.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: const Text(
              'Go Back',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Navigate to role switch screen
              Navigator.pushReplacementNamed(context, '/role-switch');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Switch to Patient',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF3D0A0A),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Main Content
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Main SOS Button
                    _buildMainSOSButton(),

                    const SizedBox(height: 24),

                    // Form Card
                    Expanded(
                      child: _buildFormCard(),
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
                color: const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFFD62828),
                size: 20,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'EMERGENCY SOS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD62828),
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Info Icon
          GestureDetector(
            onTap: () {
              _showSOSInfoDialog();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFD62828),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSOSButton() {
    return GestureDetector(
      onLongPressStart: (_) {
        setState(() {
          _isHolding = true;
        });
        // Simulate activation after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isHolding) {
            setState(() {
              _isActivated = true;
              _isHolding = false;
            });
            // Show activation dialog
            _showSOSActivatedDialog();
          }
        });
      },
      onLongPressEnd: (_) {
        setState(() {
          _isHolding = false;
        });
      },
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD62828),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3D0A0A).withValues(alpha: 0.6),
                  blurRadius: 30,
                  spreadRadius: 8,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse effect when holding
                if (_isHolding)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 3,
                        ),
                      ),
                    ),
                  ),

                // SOS Text
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emergency_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SOS',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),

                // Loading indicator when holding
                if (_isHolding)
                  const Positioned.fill(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),

                // Checkmark when activated
                if (_isActivated && !_isHolding)
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Color(0xFFD62828),
                      size: 40,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isActivated
                ? 'Emergency Broadcasted!'
                : 'Hold to broadcast emergency',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFB),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border.all(
          color: const Color(0xFFD62828).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD62828).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Your Blood Group
            _buildSectionTitle('Your Blood Group'),
            const SizedBox(height: 12),
            _buildBloodGroupSelector(),

            const SizedBox(height: 20),

            // Units Needed
            _buildSectionTitle('Units Needed'),
            const SizedBox(height: 12),
            _buildUnitsSelector(),

            const SizedBox(height: 20),

            // Alert Donors Within
            _buildSectionTitle('Alert Donors Within'),
            const SizedBox(height: 12),
            _buildDistanceSelector(),

            const SizedBox(height: 20),

            // Situation Description
            _buildSectionTitle('Situation Description'),
            const SizedBox(height: 12),
            _buildSituationDescription(),

            const SizedBox(height: 24),

            // Activate Button
            _buildActivateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF424242),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildBloodGroupSelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD62828).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD62828),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bloodtype,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Selected blood group:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedBloodGroup == null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedBloodGroup = _bloodGroups.first;
                });
              },
              child: Text(
                'Select blood group',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            DropdownButton<String>(
              value: _selectedBloodGroup,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFFD62828),
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD62828),
              ),
              underline: const SizedBox.shrink(),
              items: _bloodGroups.map((String group) {
                return DropdownMenuItem<String>(
                  value: group,
                  child: Row(
                    children: [
                      Text(
                        group,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD62828),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        group.contains('+') ? '(Positive)' : '(Negative)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedBloodGroup = newValue!;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUnitsSelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD62828).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Selected:',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF757575),
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              // Minus Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_unitsNeeded > 1) _unitsNeeded--;
                  });
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD62828),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$_unitsNeeded Units',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD62828),
                ),
              ),
              const SizedBox(width: 16),
              // Plus Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_unitsNeeded < 10) _unitsNeeded++;
                  });
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD62828),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceSelector() {
    return Column(
      children: [
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFD62828).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Distance selected:',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF757575),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${_selectedDistance.toInt()} km',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD62828),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Slider
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFD62828),
            inactiveTrackColor: const Color(0xFFFFCDD2),
            thumbColor: const Color(0xFFD62828),
            overlayColor: const Color(0xFFD62828).withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            trackHeight: 6,
          ),
          child: Slider(
            value: _selectedDistance,
            min: 5,
            max: 50,
            divisions: 3,
            onChanged: (value) {
              setState(() {
                _selectedDistance = value;
              });
            },
          ),
        ),
        // Distance markers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _distanceOptions.map((distance) {
              final isSelected = distance == _selectedDistance;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDistance = distance;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFD62828)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFD62828),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${distance.toInt()} km',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFFD62828),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSituationDescription() {
    final characterCount = _situationDescription.length;
    final maxLength = 250;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFD62828).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: TextField(
            maxLines: 4,
            maxLength: maxLength,
            controller: _situationController,
            onChanged: (value) {
              setState(() {
                _situationDescription = value;
              });
            },
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF424242),
              height: 1.5,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Character count
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$characterCount/$maxLength',
              style: TextStyle(
                fontSize: 12,
                color: characterCount > maxLength * 0.8
                    ? const Color(0xFFD62828)
                    : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivateButton() {
    return GestureDetector(
      onTap: () {
        _activateSOS();
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFD62828),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD62828).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emergency_rounded,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Activate SOS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _activateSOS() {
    if (_isActivated) return;

    // Validate blood group is selected
    if (_selectedBloodGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a blood group first'),
          backgroundColor: Color(0xFFD62828),
        ),
      );
      return;
    }

    setState(() {
      _isActivated = true;
    });

    // Show activation dialog
    _showSOSActivatedDialog();
  }

  void _showSOSActivatedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'SOS Activated!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your emergency request has been broadcast to all donors within ${_selectedDistance.toInt()} km radius.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Blood Group: $_selectedBloodGroup | Units: $_unitsNeeded',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD62828),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Go back to home
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFFD62828),
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Go to Home',
                      style: TextStyle(
                        color: Color(0xFFD62828),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to nearby donors map
                      Navigator.pushReplacementNamed(context, '/nearby-donors-map');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD62828),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'View Donors',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSOSInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFD62828),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('About SOS'),
          ],
        ),
        content: const Text(
          'The SOS feature sends an emergency blood request to all nearby donors instantly. Use this only in critical situations when blood is needed urgently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: Color(0xFFD62828),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBloodGroupInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Find Your Blood Group'),
        content: const Text(
          'If you don\'t know your blood group, you can:\n\n1. Check your old medical records\n2. Visit a nearby diagnostic center\n3. Use a home blood group testing kit\n\nKnowing your blood group is important for emergency situations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: Color(0xFFD62828),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
