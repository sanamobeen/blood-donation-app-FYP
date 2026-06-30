import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class SOSScreenApi extends StatefulWidget {
  const SOSScreenApi({super.key});

  @override
  State<SOSScreenApi> createState() => _SOSScreenApiState();
}

class _SOSScreenApiState extends State<SOSScreenApi> {
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

  // Form controllers
  final TextEditingController _hospitalNameController = TextEditingController();
  final TextEditingController _hospitalAddressController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController(text: '35');
  late TextEditingController _situationController;
  String _selectedGender = 'female';

  // SOS activation
  bool _isHolding = false;
  bool _isActivated = false;
  bool _isSubmitting = false;

  // Location
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _situationController = TextEditingController(text: _situationDescription);
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _hospitalNameController.dispose();
    _hospitalAddressController.dispose();
    _contactPhoneController.dispose();
    _patientNameController.dispose();
    _ageController.dispose();
    _situationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
    }
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
            _activateSOS();
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
              color: _isSubmitting ? Colors.grey.shade600 : const Color(0xFFD62828),
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
                      _isSubmitting ? Icons.hourglass_empty : Icons.emergency_rounded,
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

                // Loading indicator when holding/submitting
                if (_isHolding || _isSubmitting)
                  const Positioned.fill(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),

                // Checkmark when activated
                if (_isActivated && !_isHolding && !_isSubmitting)
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
            _isSubmitting
                ? 'Creating SOS request...'
                : _isActivated
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
            // Patient Information Section
            _buildSectionTitle('Patient Information'),
            const SizedBox(height: 12),
            _buildPatientInfoFields(),

            const SizedBox(height: 20),

            // Hospital Information Section
            _buildSectionTitle('Hospital Information'),
            const SizedBox(height: 12),
            _buildHospitalInfoFields(),

            const SizedBox(height: 20),

            // Your Blood Group
            _buildSectionTitle('Blood Group Required'),
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
            _buildSectionTitle('Additional Notes (Optional)'),
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

  Widget _buildPatientInfoFields() {
    return Column(
      children: [
        // Patient Name
        _buildTextField(
          controller: _patientNameController,
          hintText: 'Enter patient name',
          prefixIcon: Icons.person,
        ),
        const SizedBox(height: 12),

        // Age and Gender Row
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _ageController,
                hintText: 'Age',
                prefixIcon: Icons.cake,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderSelector(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHospitalInfoFields() {
    return Column(
      children: [
        // Hospital Name
        _buildTextField(
          controller: _hospitalNameController,
          hintText: 'Hospital name',
          prefixIcon: Icons.local_hospital,
        ),
        const SizedBox(height: 12),

        // Hospital Address
        _buildTextField(
          controller: _hospitalAddressController,
          hintText: 'Hospital address',
          prefixIcon: Icons.location_on,
        ),
        const SizedBox(height: 12),

        // Contact Phone
        _buildTextField(
          controller: _contactPhoneController,
          hintText: '03XX-XXXXXXX',
          prefixIcon: Icons.phone,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
  }) {
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
        children: [
          Icon(
            prefixIcon,
            color: const Color(0xFFD62828),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
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
      child: DropdownButton<String>(
        value: _selectedGender,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFFD62828),
        ),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFFD62828),
        ),
        underline: const SizedBox.shrink(),
        items: ['male', 'female', 'other'].map((String gender) {
          return DropdownMenuItem<String>(
            value: gender,
            child: Text(gender[0].toUpperCase() + gender.substring(1)), // Display with capital first letter
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedGender = newValue!;
          });
        },
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
                    'Blood group:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
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
            'Units needed:',
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
                '$_unitsNeeded',
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
                'Alert radius:',
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
          color: _isSubmitting ? Colors.grey.shade600 : const Color(0xFFD62828),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD62828).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSubmitting ? Icons.hourglass_empty : Icons.emergency_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              _isSubmitting ? 'Creating...' : 'Activate SOS',
              style: const TextStyle(
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

  void _activateSOS() async {
    if (_isActivated || _isSubmitting) return;

    // Validate blood group is selected
    if (_selectedBloodGroup == null) {
      _showErrorDialog('Please select a blood group first');
      return;
    }

    // Validate required fields
    if (_hospitalNameController.text.isEmpty ||
        _hospitalAddressController.text.isEmpty ||
        _contactPhoneController.text.isEmpty ||
        _patientNameController.text.isEmpty) {
      _showErrorDialog('Please fill in all required fields');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Send blood group string directly (backend expects "O+", "A+", etc., not integer IDs)
      final result = await ApiService.createSosRequest(
        bloodType: _selectedBloodGroup!,
        hospitalName: _hospitalNameController.text,
        hospitalAddress: _hospitalNameController.text,
        contactPhone: _contactPhoneController.text,
        patientName: _patientNameController.text,
        age: int.tryParse(_ageController.text) ?? 35,
        gender: _selectedGender,
        unitsNeeded: _unitsNeeded,
        hospitalLat: _currentPosition != null
            ? double.parse(_currentPosition!.latitude.toStringAsFixed(6))
            : null,
        hospitalLng: _currentPosition != null
            ? double.parse(_currentPosition!.longitude.toStringAsFixed(6))
            : null,
      );

      setState(() {
        _isSubmitting = false;
      });

      if (result['success'] == true) {
        setState(() {
          _isActivated = true;
        });
        _showSOSActivatedDialog();
      } else {
        _showErrorDialog(result['message'] as String? ?? 'Failed to create SOS request');
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showErrorDialog('Network error: $e');
    }
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
                      Navigator.pushReplacementNamed(context, '/sos-active');
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
                      'View Responses',
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
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
