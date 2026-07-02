import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/availability_scheduler.dart';
import '../../services/api_service.dart';
import '../../models/profile.dart';
import '../../models/selected_location.dart';
import '../../models/donor_availability.dart';
import '../location/location_picker_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  // Profile picture
  final ImagePicker _imagePicker = ImagePicker();
  String? _profileImagePath;

  // Loading state
  bool _isLoading = false;
  bool _isCheckingAuth = true;
  String? _errorMessage;

  // User role (donor/patient)
  String? _userRole;

  // Location data (only for donors)
  SelectedLocation? _selectedLocation;

  // Blood groups
  static const List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  String? _selectedBloodGroup;

  // Date of birth
  DateTime? _selectedDate;
  final TextEditingController _dobController = TextEditingController();

  // Gender
  String? _selectedGender; // 'Male' or 'Female'

  // Weight
  final TextEditingController _weightController = TextEditingController();

  // City
  String? _selectedCity;
  static const List<String> cities = [
    'Lahore',
    'Islamabad',
    'Karachi',
    'Multan',
    'Quetta',
  ];

  // Donor availability data
  DonorAvailability? _donorAvailability;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _checkAuthentication();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role');
    });
  }

  Future<void> _checkAuthentication() async {
    final isAuthenticated = await ApiService.isAuthenticated();
    setState(() {
      _isCheckingAuth = false;
    });

    if (!isAuthenticated) {
      // Show error and redirect to login
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login first to setup your profile'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  @override
  void dispose() {
    _dobController.dispose();
    _weightController.dispose();
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
            if (_profileImagePath != null)
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
      });
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
    }
  }

  bool _isFormValid() {
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

  void _continuePressed() async {
    if (_isFormValid()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Format date for API (YYYY-MM-DD)
      final formattedDate = _selectedDate != null
          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
          : null;

      // Call API to create profile
      final result = await ApiService.createProfile(
        bloodGroup: _selectedBloodGroup,
        dateOfBirth: formattedDate,
        gender: _selectedGender?.toLowerCase(),
        weight: _weightController.text,
        city: _selectedCity?.toLowerCase(),
        profilePicturePath: _profileImagePath,
        // Location fields (only for donors)
        locationLat: _userRole == 'donor' && _selectedLocation != null
            ? _selectedLocation!.latitude
            : null,
        locationLng: _userRole == 'donor' && _selectedLocation != null
            ? _selectedLocation!.longitude
            : null,
        address: _userRole == 'donor' && _selectedLocation != null
            ? _selectedLocation!.fullAddress
            : null,
        // Availability data (only for donors)
        availabilityData: _userRole == 'donor' && _donorAvailability != null
            ? _donorAvailability!.toJson()
            : null,
      );

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        // Profile created successfully - navigate based on user role
        if (mounted) {
          // Get user profile to determine role
          final profileResult = await ApiService.getProfile();
          String? userRole;

          if (profileResult['success'] == true && profileResult['data'] != null) {
            // Check in user object
            userRole = profileResult['data']['user']?['role']?.toString();

            // Check in profile object if not found in user
            if (userRole == null && profileResult['data']['profile'] != null) {
              userRole = profileResult['data']['profile']['role']?.toString();
            }
          }


          // Profile created successfully - navigate based on user role
          // The main navigation screen will show the appropriate UI based on user's role
          if (mounted) {
            // For donors: Navigate to Health Eligibility Quiz first
            if (_userRole == 'donor') {
              Navigator.pushReplacementNamed(context, AppRoutes.healthEligibilityQuiz);
            } else {
              // For patients: Go directly to main navigation
              Navigator.pushReplacementNamed(context, AppRoutes.mainNavigation);
            }
          }
        }
      } else {
        // Show error message
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to create profile';
        });

        // Show snackbar with specific message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Profile creation failed'),
              backgroundColor: AppColors.urgencyCritical,
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {},
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // If authentication failed, redirect to login
        if (result['requires_auth'] == true) {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          }
        }
      }
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
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking authentication
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Verifying authentication...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
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
                  const SizedBox(height: 2),

                  // Back Button
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Logo Section
                  Center(
                    child: Column(
                      children: [
                        // Blood drop icon
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.water_drop,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Blood Donation text
                        const Text(
                          'Blood Donation',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Tagline
                        const Text(
                          'Every drop counts',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Main Title
                  const Text(
                    'Tell us about you',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  const Text(
                    'Help us personalize your experience.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Profile Picture Section
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
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
                            child: _profileImagePath != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: Image.network(
                                      _profileImagePath!,
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
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to add photo',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Blood Group Section
                  Row(
                    children: [
                      const Icon(
                        Icons.bloodtype,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Blood group',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

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
                  const SizedBox(height: 2),

                  // Date of Birth Section
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Date of birth',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: TextField(
                      controller: _dobController,
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: 'DD / MM / YYYY',
                        suffixIcon: const Icon(Icons.calendar_today),
                        filled: true,
                        fillColor: AppColors.inputBackground,
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border, width: 1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Gender Section
                  Row(
                    children: [
                      const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Gender',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Gender Toggle
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedGender = 'Male';
                            });
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
                  const SizedBox(height: 2),

                  // Weight Section
                  Row(
                    children: [
                      const Icon(
                        Icons.monitor_weight,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Weight (kg)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      hintText: 'Enter weight in kg',
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 2),

                  // City Section
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'City',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

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
                  const SizedBox(height: 2),

                  // Location Section (only for donors)
                  if (_userRole == 'donor') ...[
                    // Location Section
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

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
                    const SizedBox(height: 2),
                  ],

                  // Available to Donate Section (only for donors)
                  if (_userRole == 'donor')
                    AvailabilityScheduler(
                      initialAvailability: _donorAvailability,
                      onAvailabilityChanged: (availability) {
                        setState(() {
                          _donorAvailability = availability;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),

          // Continue Button - Positioned at bottom
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
                  text: _isLoading ? 'Creating Profile...' : 'Continue',
                  onPressed: (_isFormValid() && !_isLoading) ? _continuePressed : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
