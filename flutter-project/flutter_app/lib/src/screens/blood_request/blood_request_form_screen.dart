import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../models/selected_location.dart';
import '../../app_routes.dart';
import '../location/location_picker_screen.dart';

class BloodRequestFormScreen extends StatefulWidget {
  const BloodRequestFormScreen({super.key});

  @override
  State<BloodRequestFormScreen> createState() => _BloodRequestFormScreenState();
}

class _BloodRequestFormScreenState extends State<BloodRequestFormScreen> {
  // Form controllers
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _unitsController = TextEditingController(text: '1');
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Selected values
  String _selectedBloodType = 'A+';
  String _selectedUrgency = 'normal';
  DateTime? _selectedNeededByDate;

  // Location data
  SelectedLocation? _selectedLocation;

  // Loading states
  bool _isLoading = false;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quiz section removed from patient side
    // No longer loading quiz responses from navigation
  }

  /// Load quiz responses from navigation arguments (disabled)
  void _loadQuizResponses() {
    // Quiz functionality removed from patient side
    // Keeping this method for potential future use
  }

  /// Load user profile to get existing location data
  Future<void> _loadUserProfile() async {
    try {
      final profileResponse = await ApiService.getProfile();
      if (profileResponse['success'] == true) {
        final profileData = profileResponse['data'];
        final profile = profileData['profile'];

        // Check if user has existing location data from donor profile
        if (profile != null &&
            profile['location_lat'] != null &&
            profile['location_lng'] != null) {
          final lat = double.tryParse(profile['location_lat'].toString());
          final lng = double.tryParse(profile['location_lng'].toString());

          if (lat != null && lng != null) {
            // Use existing location as default
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
      // Ignore error, user will need to select location manually
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  // Blood type options
  final List<String> _bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  // Urgency levels
  final List<Map<String, dynamic>> _urgencyLevels = [
    {'value': 'critical', 'label': 'Critical', 'color': const Color(0xFFD62828)},
    {'value': 'urgent', 'label': 'Urgent', 'color': const Color(0xFFE85D04)},
    {'value': 'normal', 'label': 'Normal', 'color': const Color(0xFFFFB74D)},
  ];

  @override
  void dispose() {
    _patientNameController.dispose();
    _unitsController.dispose();
    _contactNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Request Blood'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
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

                  // Blood Type Selection
                  _buildSectionTitle('Blood Group*'),
                  const SizedBox(height: 12),
                  _buildBloodTypeSelector(),
                  const SizedBox(height: 20),

                  // Units Needed
                  _buildSectionTitle('Units Needed*'),
                  const SizedBox(height: 12),
                  _buildUnitsSelector(),
                  const SizedBox(height: 20),

                  // Urgency Level
                  _buildSectionTitle('Urgency Level*'),
                  const SizedBox(height: 12),
                  _buildUrgencySelector(),
                  const SizedBox(height: 20),

                  // Needed By Date
                  _buildSectionTitle('Needed By*'),
                  const SizedBox(height: 12),
                  _buildNeededByDatePicker(),
                  const SizedBox(height: 20),

                  // Contact Number
                  _buildSectionTitle('Contact Number*'),
                  const SizedBox(height: 12),
                  _buildPhoneField(),
                  const SizedBox(height: 20),

                  // Location Section
                  _buildSectionTitle('Location*'),
                  const SizedBox(height: 12),
                  _buildLocationSection(),
                  const SizedBox(height: 20),

                  // Additional Notes
                  _buildSectionTitle('Additional Notes (Optional)'),
                  const SizedBox(height: 12),
                  _buildNotesField(),
                  const SizedBox(height: 30),

                  // Submit Button
                  _buildSubmitButton(),
                  const SizedBox(height: 20),
                ],
              ),
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

  Widget _buildBloodTypeSelector() {
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
          value: _selectedBloodType,
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
          items: _bloodTypes.map((String bloodType) {
            return DropdownMenuItem<String>(
              value: bloodType,
              child: Text(bloodType),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedBloodType = newValue;
              });
            }
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
            final currentUnits = int.tryParse(_unitsController.text) ?? 1;
            if (currentUnits > 1) {
              setState(() {
                _unitsController.text = (currentUnits - 1).toString();
              });
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
                _unitsController.text.isEmpty ? '1' : _unitsController.text,
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
            final currentUnits = int.tryParse(_unitsController.text) ?? 1;
            if (currentUnits < 50) {
              setState(() {
                _unitsController.text = (currentUnits + 1).toString();
              });
            }
          },
          icon: const Icon(Icons.add_circle_outline),
          iconSize: 32,
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextField(
      controller: controller,
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
      controller: _contactNumberController,
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

  Widget _buildUrgencySelector() {
    return Row(
      children: _urgencyLevels.map((urgency) {
        final value = urgency['value'] as String;
        final label = urgency['label'] as String;
        final color = urgency['color'] as Color;
        final isSelected = _selectedUrgency == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: value != _urgencyLevels.last['value'] ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedUrgency = value;
                });
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
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
    );
  }

  Widget _buildNeededByDatePicker() {
    return InkWell(
      onTap: _pickNeededByDate,
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
              Icons.calendar_today,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedNeededByDate == null
                    ? 'Select date when blood is needed by*'
                    : '${_formatDate(_selectedNeededByDate!)} ${_formatTime(_selectedNeededByDate!)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _selectedNeededByDate == null
                      ? AppColors.textSecondary.withValues(alpha: 0.8)
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (_selectedNeededByDate != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() => _selectedNeededByDate = null);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $amPm';
  }

  Future<void> _pickNeededByDate() async {
    // Get fresh current time
    final now = DateTime.now();
    // Reset to start of today for date comparison
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = today; // Start from today (no past dates)
    final lastDate = today.add(const Duration(days: 30)); // Max 30 days from today

    // Calculate initial date - if already selected, use that, otherwise use today's date
    DateTime initialDate = _selectedNeededByDate ?? today;

    // Ensure initial date is within valid range
    if (initialDate.isBefore(firstDate)) {
      initialDate = today;
    }
    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      // Get fresh time after date picking (user might have taken time)
      final freshNow = DateTime.now();
      final freshToday = DateTime(freshNow.year, freshNow.month, freshNow.day);

      // Determine if user picked today
      final isToday = pickedDate.year == freshNow.year &&
                      pickedDate.month == freshNow.month &&
                      pickedDate.day == freshNow.day;

      // Calculate initial time for time picker
      TimeOfDay initialTime;

      if (_selectedNeededByDate != null &&
          _selectedNeededByDate!.year == pickedDate.year &&
          _selectedNeededByDate!.month == pickedDate.month &&
          _selectedNeededByDate!.day == pickedDate.day) {
        // Use existing time if editing the same date
        initialTime = TimeOfDay.fromDateTime(_selectedNeededByDate!);
      } else {
        // Show current time by default for both today and future dates
        // Patient can then adjust according to their requirement
        initialTime = TimeOfDay.fromDateTime(freshNow);
      }

      // Now pick time
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null && mounted) {
        // Get FRESH time again after time picking (user might have taken more time)
        final validationNow = DateTime.now();

        // Create the combined DateTime
        final selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // Validate: ensure date/time is at least 1 hour from now
        // Compare at minute level by creating a threshold DateTime
        final nowAtMinutePrecision = DateTime(
          validationNow.year,
          validationNow.month,
          validationNow.day,
          validationNow.hour,
          validationNow.minute,
        );
        final oneHourFromNow = nowAtMinutePrecision.add(const Duration(hours: 1));

        // Show SOS if selected time is not after 1 hour from now
        if (!selectedDateTime.isAfter(oneHourFromNow)) {
          // For urgent needs (within 1 hour), show SOS dialog
          _showSosDialog();
          return;
        }

        setState(() {
          _selectedNeededByDate = selectedDateTime;
        });
      }
    }
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Add any additional notes or medical information...',
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

  Widget _buildLocationSection() {
    if (_selectedLocation != null) {
      // Show selected location with option to change
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
                  onPressed: () {
                    setState(() => _selectedLocation = null);
                  },
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

    // Show "Add Location" button
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

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _handleSubmit(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Submit Request',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
      setState(() {
        _selectedLocation = result;
      });
    }
  }

  Future<void> _handleSubmit() async {
    // Validate required fields
    if (_patientNameController.text.trim().isEmpty) {
      _showError('Please enter patient name');
      return;
    }
    if (_contactNumberController.text.trim().isEmpty) {
      _showError('Please enter contact number');
      return;
    }
    if (_selectedNeededByDate == null) {
      _showError('Please select when blood is needed by');
      return;
    }
    if (_selectedLocation == null) {
      _showError('Please select location');
      return;
    }

    // Validate that the selected date/time is at least 1 hour from now
    final now = DateTime.now();
    // Compare at minute level for accuracy
    final nowAtMinutePrecision = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    final oneHourFromNow = nowAtMinutePrecision.add(const Duration(hours: 1));

    if (!_selectedNeededByDate!.isAfter(oneHourFromNow)) {
      _showSosDialog();
      return;
    }

    // Validate phone number format (03XXXXXXXXX - 11 digits starting with 03)
    final phone = _contactNumberController.text.trim();
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (!digits.startsWith('03') || digits.length != 11) {
      _showError('Please enter a valid phone number (e.g., 03123456789)');
      return;
    }

    final units = int.tryParse(_unitsController.text) ?? 0;
    if (units < 1) {
      _showError('Please select at least 1 unit');
      return;
    }

    // Show loading
    setState(() {
      _isLoading = true;
    });

    try {
      // Quiz section removed - no longer sending quiz responses
      // Call API to create blood request with location details
      final result = await ApiService.createBloodRequest(
        patientName: _patientNameController.text.trim(),
        bloodGroup: _selectedBloodType,
        unitsNeeded: units,
        urgencyLevel: _selectedUrgency,
        contactNumber: phone,
        hospitalName: _selectedLocation!.locationName,
        location: _selectedLocation!.fullAddress,
        locationLat: double.parse(_selectedLocation!.latitude.toStringAsFixed(6)),
        locationLng: double.parse(_selectedLocation!.longitude.toStringAsFixed(6)),
        neededBy: _selectedNeededByDate!,
        additionalNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      // Hide loading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (result['success'] == true) {
        // Show success dialog
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        // Show error
        final message = result['message'] as String? ?? 'Failed to submit request';
        _showError(message);
      }
    } catch (e) {
      // Hide loading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showError('An error occurred. Please try again.');
    }
  }

  void _showSuccessDialog() {
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
              decoration: const BoxDecoration(
                color: Color(0xFF66BB6A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Request Submitted'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your blood request has been submitted successfully.',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_pin,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _selectedLocation!.locationName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                _selectedLocation!.fullAddress,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'We\'ll notify you when we find matching donors nearby.',
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
              'Done',
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

  /// Show dialog with SOS button for urgent requests
  void _showSosDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.emergency,
              color: Color(0xFFD62828),
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Urgent Blood Request',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'For urgent blood requests (within 1 hour), please use the SOS Emergency feature for immediate help.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, AppRoutes.sos);
            },
            icon: const Icon(Icons.emergency_share, size: 18),
            label: const Text('Go to SOS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
