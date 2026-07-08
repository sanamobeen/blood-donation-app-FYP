import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/selected_location.dart';
import '../location/location_picker_screen.dart';

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

  // Form controllers
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _patientNameController = TextEditingController();

  // Location data
  SelectedLocation? _selectedLocation;

  // SOS activation
  bool _isActivated = false;
  bool _isSubmitting = false;
  String? _createdSosId; // Store the created SOS ID

  // Location for GPS purposes
  Position? _currentPosition;

  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();

    _loadUserProfile();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _contactPhoneController.dispose();
    _patientNameController.dispose();
    super.dispose();
  }

  /// Load user profile to get existing location data
  Future<void> _loadUserProfile() async {
    try {
      final profileResponse = await ApiService.getProfile();
      if (profileResponse['success'] == true) {
        final profileData = profileResponse['data'];
        final profile = profileData['profile'];

        if (profile != null &&
            profile['location_lat'] != null &&
            profile['location_lng'] != null) {
          final lat = double.tryParse(profile['location_lat'].toString());
          final lng = double.tryParse(profile['location_lng'].toString());

          if (lat != null && lng != null) {
            setState(() {
              _selectedLocation = SelectedLocation(
                locationName: profile['city'] ?? 'Your Location',
                fullAddress: profile['address'] ?? 'Location from profile',
                latitude: lat,
                longitude: lng,
              );
              _isLoadingProfile = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
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
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      // Ignore location errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2D0A0A), Color(0xFF1A0505)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Main SOS Button
                      _buildMainSOSButton(),

                      const SizedBox(height: 32),

                      // Form Card
                      _buildFormCard(),
                    ],
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Back Arrow
          _buildHeaderButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'EMERGENCY SOS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Info Icon
          _buildHeaderButton(
            icon: Icons.info_outline_rounded,
            onTap: () => _showSOSInfoDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildMainSOSButton() {
    return Column(
      children: [
        // Progress Ring
        SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),

              // Main SOS Button
              InkWell(
                onTap: _isActivated || _isSubmitting ? null : _activateSOS,
                borderRadius: BorderRadius.circular(70),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _isSubmitting
                          ? [Colors.grey.shade700, Colors.grey.shade900]
                          : (_isActivated
                              ? [Colors.grey.shade400, Colors.grey.shade500]
                              : [const Color(0xFFE53935), const Color(0xFFD32F2F)]),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 10,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // SOS Icon/Text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 50,
                                height: 50,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 4,
                                  key: ValueKey('loading'),
                                ),
                              )
                            : _isActivated
                                ? Container(
                                    key: const ValueKey('activated'),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      color: Color(0xFFE53935),
                                      size: 50,
                                    ),
                                  )
                                : Column(
                                    key: const ValueKey('sos'),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.emergency_rounded,
                                        size: 42,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'SOS',
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 4,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Status Text
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _isSubmitting
                ? 'Creating SOS request...'
                : _isActivated
                    ? 'Emergency Broadcasted!'
                    : '',
            key: ValueKey(_isSubmitting ? 'submitting' : _isActivated ? 'activated' : 'idle'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _isActivated ? Colors.green.shade400 : Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),

        // Subtitle text
        const SizedBox(height: 8),
        if (!_isActivated && !_isSubmitting)
          Text(
            'Emergency blood request to nearby donors',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Name
            _buildSectionTitle('Patient Name*'),
            const SizedBox(height: 12),
            _buildInputField(
              controller: _patientNameController,
              hintText: 'Enter patient name',
            ),
            const SizedBox(height: 20),

            // Hospital Location
            _buildSectionTitle('Location*'),
            const SizedBox(height: 12),
            _buildLocationSection(),
            const SizedBox(height: 20),

            // Contact Number
            _buildSectionTitle('Emergency Contact*'),
            const SizedBox(height: 12),
            _buildPhoneField(),
            const SizedBox(height: 20),

            // Blood Group
            _buildSectionTitle('Blood Group Required*'),
            const SizedBox(height: 12),
            _buildBloodGroupSelector(),
            const SizedBox(height: 20),

            // Units Needed
            _buildSectionTitle('Units Needed*'),
            const SizedBox(height: 12),
            _buildUnitsSelector(),
            const SizedBox(height: 20),

            // Alert Radius
            _buildSectionTitle('Alert Donors Within'),
            const SizedBox(height: 12),
            _buildDistanceSelector(),
            const SizedBox(height: 20),

            // Submit Button
            _buildSubmitButton(),
            const SizedBox(height: 16),

            // Disclaimer
            Center(
              child: Text(
                '⚠️ Use SOS only in real medical emergencies',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
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

  Widget _buildPhoneField() {
    return TextField(
      controller: _contactPhoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        hintText: '03XX-XXXXXXX',
        helperText: 'Format: 03XXXXXXXXX (11 digits)',
        prefixIcon: Icon(
          Icons.phone,
          color: AppColors.primary,
          size: 20,
        ),
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

  Widget _buildBloodGroupSelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBloodGroup,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.primary,
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          hint: const Text(
            'Select Blood Group',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          items: _bloodGroups.map((String group) {
            return DropdownMenuItem<String>(
              value: group,
              child: Text(group),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() => _selectedBloodGroup = newValue);
          },
        ),
      ),
    );
  }

  Widget _buildUnitsSelector() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            if (_unitsNeeded > 1) {
              setState(() => _unitsNeeded--);
            }
          },
          icon: const Icon(Icons.remove_circle_outline),
          iconSize: 32,
          color: AppColors.primary,
        ),
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Center(
              child: Text(
                '$_unitsNeeded',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            if (_unitsNeeded < 10) {
              setState(() => _unitsNeeded++);
            }
          },
          icon: const Icon(Icons.add_circle_outline),
          iconSize: 32,
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildDistanceSelector() {
    return Column(
      children: [
        // Distance chips row
        Row(
          children: _distanceOptions.map((distance) {
            final isSelected = distance == _selectedDistance;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: distance != _distanceOptions.last ? 8 : 0,
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDistance = distance),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${distance.toInt()} km',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    if (_selectedLocation != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_pin,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedLocation!.locationName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _selectedLocation = null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                _selectedLocation!.fullAddress,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _openLocationPicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.add_location_alt,
              size: 24,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Add Location',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<SelectedLocation>(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(),
      ),
    );

    if (result != null) {
      setState(() => _selectedLocation = result);
    }
  }

  Widget _buildSubmitButton() {
    final isFormValid = _selectedBloodGroup != null &&
        _patientNameController.text.isNotEmpty &&
        _contactPhoneController.text.isNotEmpty &&
        _selectedLocation != null;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isFormValid && !_isSubmitting ? _activateSOS : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFormValid ? AppColors.primary : Colors.grey.shade300,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
              'Activate Emergency SOS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
      ),
    );
  }

  void _activateSOS() async {
    if (_isActivated || _isSubmitting) return;

    // Validate blood group
    if (_selectedBloodGroup == null) {
      return;
    }

    // Validate required fields
    if (_contactPhoneController.text.isEmpty ||
        _patientNameController.text.isEmpty) {
      return;
    }

    // Validate location
    if (_selectedLocation == null) {
      return;
    }

    // Validate phone number
    final phone = _contactPhoneController.text.trim();
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (!digits.startsWith('03') || digits.length != 11) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ApiService.createSosRequest(
        bloodType: _selectedBloodGroup!,
        hospitalName: _selectedLocation!.locationName,
        hospitalAddress: _selectedLocation!.fullAddress,
        contactPhone: phone,
        patientName: _patientNameController.text,
        unitsNeeded: _unitsNeeded,
        hospitalLat: _selectedLocation!.latitude,
        hospitalLng: _selectedLocation!.longitude,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);

        if (result['success'] == true) {
          // Extract SOS ID from response
          final data = result['data'] as Map<String, dynamic>?;
          final sosRequest = data?['sos_request'] as Map<String, dynamic>?;
          _createdSosId = sosRequest?['id'] as String?;

          setState(() => _isActivated = true);
          _showSOSActivatedDialog();
        } else {
          _showError(result['message'] as String? ?? 'Failed to create SOS request');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError('Network error: $e');
      }
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
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'SOS Activated!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your emergency request has been broadcast to donors within ${_selectedDistance.toInt()} km',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.softPink.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Blood: $_selectedBloodGroup | Units: $_unitsNeeded',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
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
                          color: AppColors.primary,
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Go to Home',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (_createdSosId != null) {
                        Navigator.pushReplacementNamed(
                          context,
                          '/sos-active',
                          arguments: {'sosId': _createdSosId},
                        );
                      } else {
                        Navigator.pushReplacementNamed(context, '/sos-active');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
                        fontSize: 15,
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
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('About SOS'),
          ],
        ),
        content: const Text(
          'The SOS feature sends an emergency blood request to all nearby donors instantly. This should only be used in critical situations when blood is needed urgently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.urgencyCritical,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
