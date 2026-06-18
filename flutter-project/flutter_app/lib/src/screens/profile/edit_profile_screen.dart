import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../services/api_service.dart';
import '../../models/profile.dart';
import '../../models/selected_location.dart';
import '../location/location_picker_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Profile picture
  final ImagePicker _imagePicker = ImagePicker();
  String? _profileImagePath;
  String? _profilePictureUrl;

  // Loading state
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  bool _hasChanges = false;

  // User role (donor/patient)
  String? _userRole;
  String? _originalRole;

  // Location data (only for donors)
  SelectedLocation? _selectedLocation;
  SelectedLocation? _originalLocation;

  // Blood groups
  static const List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  String? _selectedBloodGroup;
  String? _originalBloodGroup;

  // Date of birth
  DateTime? _selectedDate;
  DateTime? _originalDate;
  final TextEditingController _dobController = TextEditingController();

  // Gender
  String? _selectedGender;
  String? _originalGender;

  // Weight
  final TextEditingController _weightController = TextEditingController();
  String? _originalWeight;

  // City
  String? _selectedCity;
  String? _originalCity;
  static const List<String> cities = [
    'Lahore',
    'Islamabad',
    'Karachi',
    'Multan',
    'Quetta',
  ];

  // Available to donate
  bool _availableToDonate = true;
  bool? _originalAvailableToDonate;

  // Basic info
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _originalFullName;
  String? _originalPhone;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _fetchProfile();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role');
      _originalRole = _userRole;
    });
  }

  Future<void> _fetchProfile() async {
    final result = await ApiService.getProfile();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final data = result['data'];
          final profileData = data['profile'];

          // Load basic info
          _fullNameController.text = profileData['user_full_name'] ?? '';
          _phoneController.text = data['user']?['phone_num'] ?? '';
          _originalFullName = _fullNameController.text;
          _originalPhone = _phoneController.text;

          // Load profile picture
          _profilePictureUrl = profileData['profile_picture_url'] ??
              profileData['profile_picture'];
          _originalFullName = _fullNameController.text;

          // Load blood group
          _selectedBloodGroup = profileData['blood_group'];
          _originalBloodGroup = _selectedBloodGroup;

          // Load date of birth
          if (profileData['date_of_birth'] != null) {
            try {
              _selectedDate = DateTime.parse(profileData['date_of_birth']);
              _dobController.text = '${_selectedDate!.day.toString().padLeft(2, '0')} / ${_selectedDate!.month.toString().padLeft(2, '0')} / ${_selectedDate!.year}';
              _originalDate = _selectedDate;
            } catch (e) {
              // Invalid date format
            }
          }

          // Load gender
          _selectedGender = profileData['gender'];
          if (_selectedGender != null) {
            _selectedGender = _selectedGender![0].toUpperCase() + _selectedGender!.substring(1);
          }
          _originalGender = _selectedGender;

          // Load weight
          final weight = profileData['weight'];
          if (weight != null) {
            _weightController.text = weight.toString();
            _originalWeight = _weightController.text;
          }

          // Load city
          _selectedCity = profileData['city'];
          if (_selectedCity != null) {
            _selectedCity = _selectedCity![0].toUpperCase() + _selectedCity!.substring(1);
          }
          _originalCity = _selectedCity;

          // Load location (if available)
          if (profileData['location_lat'] != null && profileData['location_lng'] != null) {
            // Use address field if available, otherwise fall back to city
            final locationName = profileData['address'] ?? profileData['city'] ?? 'Unknown';
            final fullAddress = profileData['address'] ?? profileData['city'] ?? 'Unknown';

            _selectedLocation = SelectedLocation(
              latitude: double.tryParse(profileData['location_lat'].toString()) ?? 0.0,
              longitude: double.tryParse(profileData['location_lng'].toString()) ?? 0.0,
              locationName: locationName,
              fullAddress: fullAddress,
            );
            _originalLocation = _selectedLocation;
          }

          // Load availability status (from profile data if available)
          // This would need to be added to the API response
        } else {
          _errorMessage = result['message'] ?? 'Failed to load profile';
        }
      });
    }
  }

  void _checkForChanges() {
    setState(() {
      _hasChanges =
          _fullNameController.text != (_originalFullName ?? '') ||
          _phoneController.text != (_originalPhone ?? '') ||
          _selectedBloodGroup != _originalBloodGroup ||
          _selectedGender != _originalGender ||
          _weightController.text != (_originalWeight ?? '') ||
          _selectedCity != _originalCity ||
          _selectedDate != _originalDate ||
          _profileImagePath != null ||
          (_userRole == 'donor' && _selectedLocation != _originalLocation);
    });
  }

  @override
  void dispose() {
    _dobController.dispose();
    _weightController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Profile picture picker
  Future<void> _pickImage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (_profileImagePath != null || _profilePictureUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );

    if (selected == null) return;

    if (selected == 'remove') {
      setState(() {
        _profileImagePath = null;
        _profilePictureUrl = null;
      });
      _checkForChanges();
      return;
    }

    final XFile? image = await _imagePicker.pickImage(
      source: selected == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _profileImagePath = image.path;
      });
      _checkForChanges();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 18 * 365)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = '${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}';
      });
      _checkForChanges();
    }
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
      _checkForChanges();
    }
  }

  bool _isFormValid() {
    // Basic validation - all required fields must be present
    final baseValid = _selectedBloodGroup != null &&
        _selectedDate != null &&
        _selectedGender != null &&
        _weightController.text.isNotEmpty &&
        _selectedCity != null;

    // Location is required only for donors
    if (_userRole == 'donor') {
      return baseValid && _selectedLocation != null;
    }
    return baseValid;
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges && _profileImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes to save'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Upload profile picture if changed
      if (_profileImagePath != null) {
        final uploadResult = await ApiService.uploadProfilePicture(_profileImagePath!);
        if (!uploadResult['success']) {
          throw Exception(uploadResult['message'] ?? 'Failed to upload profile picture');
        }
        // Don't set _profilePictureUrl here, let the API return it
      }

      // Format date for API (YYYY-MM-DD)
      final formattedDate = _selectedDate != null
          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
          : null;

      // Call API to update profile
      final result = await ApiService.updateCombinedProfile(
        fullName: _fullNameController.text.trim(),
        phoneNum: _phoneController.text.trim(),
        bloodGroup: _selectedBloodGroup,
        dateOfBirth: formattedDate,
        gender: _selectedGender?.toLowerCase(),
        weight: _weightController.text.trim(),
        city: _selectedCity?.toLowerCase(),
        locationLat: _userRole == 'donor' && _selectedLocation != null
            ? _selectedLocation!.latitude.toString()
            : null,
        locationLng: _userRole == 'donor' && _selectedLocation != null
            ? _selectedLocation!.longitude.toString()
            : null,
        address: _userRole == 'donor' && _selectedLocation != null
            ? _selectedLocation!.fullAddress
            : null,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (result['success'] == true) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // Go back to profile screen
          Navigator.pop(context, true);
        } else {
          // Show error message
          setState(() {
            _errorMessage = result['message'] ?? 'Failed to update profile';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Profile update failed'),
              backgroundColor: AppColors.urgencyCritical,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.urgencyCritical,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildProfilePicture() {
    final imageUrl = _profilePictureUrl;
    final fileImage = _profileImagePath;

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.inputBackground,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: fileImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.file(
                  File(fileImage),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.person,
                      size: 40,
                      color: AppColors.textSecondary,
                    );
                  },
                ),
              )
            : imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.textSecondary,
                        );
                      },
                    ),
                  )
                : const Icon(
                    Icons.camera_alt,
                    size: 30,
                    color: AppColors.textSecondary,
                  ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: const Text('Edit Profile'),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Edit Profile'),
        actions: [
          if (_hasChanges)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'Unsaved changes',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: 80,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Profile Picture Section
                  Center(
                    child: Column(
                      children: [
                        _buildProfilePicture(),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to change photo',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Basic Information Section
                  _buildSectionHeader('Basic Information', Icons.person_outline),
                  const SizedBox(height: 8),

                  // Full Name
                  TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your full name',
                    ),
                    onChanged: (_) => _checkForChanges(),
                  ),
                  const SizedBox(height: 8),

                  // Email (read-only)
                  TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: _originalFullName?.toString() ?? '',
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border, width: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Phone
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter your phone number',
                    ),
                    onChanged: (_) => _checkForChanges(),
                  ),
                  const SizedBox(height: 16),

                  // Blood Group Section
                  _buildSectionHeader('Blood Group', Icons.bloodtype),
                  const SizedBox(height: 8),

                  // Blood Group Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1.8,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: bloodGroups.length,
                    itemBuilder: (context, index) {
                      final group = bloodGroups[index];
                      final isSelected = _selectedBloodGroup == group;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedBloodGroup = group;
                          });
                          _checkForChanges();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.white,
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            group,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Personal Details Section
                  _buildSectionHeader('Personal Details', Icons.info_outline),
                  const SizedBox(height: 8),

                  // Date of Birth
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: TextField(
                      controller: _dobController,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Date of Birth',
                        hintText: 'DD / MM / YYYY',
                        suffixIcon: const Icon(Icons.calendar_today),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border, width: 1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Gender Toggle
 TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      suffixIcon: Icon(
                        _selectedGender == 'Male' ? Icons.male : _selectedGender == 'Female' ? Icons.female : Icons.help_outline,
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border, width: 1),
                      ),
                    ),
                    controller: TextEditingController(text: _selectedGender ?? 'Not specified'),
                  ),
                  const SizedBox(height: 8),

                  // Gender Selection Row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedGender = 'Male';
                            });
                            _checkForChanges();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _selectedGender == 'Male'
                                  ? AppColors.softPink.withValues(alpha: 0.5)
                                  : Colors.white,
                              border: Border.all(
                                color: _selectedGender == 'Male'
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Male',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedGender = 'Female';
                            });
                            _checkForChanges();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _selectedGender == 'Female'
                                  ? AppColors.softPink.withValues(alpha: 0.5)
                                  : Colors.white,
                              border: Border.all(
                                color: _selectedGender == 'Female'
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Female',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Weight
                  TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      hintText: 'Enter your weight in kg',
                      suffixText: 'kg',
                    ),
                    onChanged: (_) => _checkForChanges(),
                  ),
                  const SizedBox(height: 16),

                  // Location Section
                  _buildSectionHeader('Location', Icons.location_on),
                  const SizedBox(height: 8),

                  // City Dropdown
                  GestureDetector(
                    onTap: () async {
                      final selected = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'Select City',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Flexible(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: cities.length,
                                    itemBuilder: (context, index) {
                                      final city = cities[index];
                                      return ListTile(
                                        title: Text(city, style: const TextStyle(fontSize: 14)),
                                        dense: true,
                                        onTap: () => Navigator.pop(context, city),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (selected != null) {
                        setState(() {
                          _selectedCity = selected;
                        });
                        _checkForChanges();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        border: Border.all(color: AppColors.border, width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedCity ?? 'Search your city',
                              style: TextStyle(
                                fontSize: 13,
                                color: _selectedCity != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Location Section (only for donors)
                  if (_userRole == 'donor') ...[
                    // Location Picker
                    if (_selectedLocation != null)
                      // Show selected location
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          border: Border.all(color: AppColors.border, width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_pin,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedLocation!.locationName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setState(() => _selectedLocation = null);
                                    _checkForChanges();
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Text(
                                _selectedLocation!.fullAddress,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // Show "Add Location" button
                      InkWell(
                        onTap: _openLocationPicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.inputBackground,
                            border: Border.all(color: AppColors.border, width: 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.add_location_alt,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Add your location',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: AppColors.textSecondary.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),

          // Save Button - Positioned at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SafeArea(
                child: PrimaryButton(
                  text: _isSaving ? 'Saving...' : 'Save Changes',
                  onPressed: (_isSaving || !_isFormValid()) ? null : _saveChanges,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
