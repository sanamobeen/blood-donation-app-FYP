import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../providers/role_provider.dart';
import '../../services/api_service.dart';
import '../location/location_picker_screen.dart';
import '../../models/selected_location.dart';

// String extension for capitalize
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

class RoleSwitchScreen extends StatelessWidget {
  final String currentRole;

  const RoleSwitchScreen({
    super.key,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);
    // Use provider's role if available, otherwise use the passed role
    final role = roleProvider.hasRole ? roleProvider.currentRole! : (currentRole.isEmpty ? 'patient' : currentRole);
    final isDonor = role == 'donor';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Switch Role'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.swap_horiz_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Switch Your Role',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You are currently logged in as ${role.capitalize()}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Role Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Current Role Card (Disabled)
                    _RoleCard(
                      role: role,
                      isCurrent: true,
                      icon: isDonor ? Icons.bloodtype : Icons.local_hospital,
                      title: isDonor ? 'Donor Mode' : 'Patient Mode',
                      description: isDonor
                          ? 'Donate blood and save lives'
                          : 'Request blood when needed',
                      onTap: () {},
                    ),

                    const SizedBox(height: 16),

                    // Switch Button
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(Icons.swap_vert, color: AppColors.textSecondary),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Other Role Card (Active)
                    _RoleCard(
                      role: isDonor ? 'patient' : 'donor',
                      isCurrent: false,
                      icon: isDonor ? Icons.local_hospital : Icons.bloodtype,
                      title: isDonor ? 'Switch to Patient Mode' : 'Switch to Donor Mode',
                      description: isDonor
                          ? 'Request blood when you or your loved ones need it'
                          : 'Donate blood and help save lives',
                      onTap: () => _switchRole(context, isDonor ? 'patient' : 'donor'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Info Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'About Role Switching',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'You can switch between Donor and Patient roles at any time. Your profile information will be preserved, and you can switch back whenever you want.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchRole(BuildContext context, String newRole) async {
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);
    final navigator = Navigator.of(context);

    // If switching to donor, check if user has location
    if (newRole == 'donor') {
      final hasLocation = await _checkUserHasLocation();

      if (!hasLocation) {
        // Show dialog explaining location is required
        final shouldAddLocation = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Required'),
            content: const Text(
              'To donate blood and help save lives, we need to know your location. This helps us match you with blood requests near you.\n\nWould you like to add your location now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Add Location',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        );

        if (shouldAddLocation != true) {
          // User cancelled, don't proceed with role switch
          return;
        }

        // Show location picker
        final selectedLocation = await Navigator.push<SelectedLocation>(
          context,
          MaterialPageRoute(
            builder: (context) => const LocationPickerScreen(),
          ),
        );

        if (selectedLocation == null) {
          // User didn't select location, don't proceed
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location is required to switch to donor mode'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Update user profile with location
        await _updateUserLocation(selectedLocation);
      }
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Switch to ${newRole.capitalize()} Mode'),
        content: Text('Are you sure you want to switch to ${newRole.capitalize()} mode?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Switch',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Use Provider to switch role (this will call API and update state)
        final response = await roleProvider.switchRole(newRole);

        // Close loading dialog
        navigator.pop();

        if (response['success'] == true) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switched to ${newRole.capitalize()} mode successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Use pushNamedAndRemoveUntil to replace entire stack with main navigation
          navigator.pushNamedAndRemoveUntil(
            AppRoutes.mainNavigation,
            (route) => false, // Remove all routes from stack
          );
        } else {
          // Show error message
          final errorMessage = response['message'] ?? 'Failed to switch role';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        // Close loading dialog
        if (navigator.canPop()) {
          navigator.pop();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Check if user has location in their profile
  Future<bool> _checkUserHasLocation() async {
    try {
      final profileResponse = await ApiService.getProfile();
      if (profileResponse['success'] == true) {
        final profileData = profileResponse['data'];
        final profile = profileData['profile'];

        // Check if user has location data
        if (profile != null &&
            profile['location_lat'] != null &&
            profile['location_lng'] != null) {
          final lat = double.tryParse(profile['location_lat'].toString());
          final lng = double.tryParse(profile['location_lng'].toString());
          return (lat != null && lng != null);
        }
      }
      return false;
    } catch (e) {
      // On error, assume no location
      return false;
    }
  }

  /// Update user profile with location
  Future<void> _updateUserLocation(SelectedLocation location) async {
    try {
      await ApiService.updateProfile(
        locationLat: location.latitude,
        locationLng: location.longitude,
        address: location.fullAddress,
        city: location.locationName,
      );
    } catch (e) {
      // Silently fail - location will be requested again on next donor switch
    }
  }
}

class _RoleCard extends StatelessWidget {
  final String role;
  final bool isCurrent;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.isCurrent,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCurrent ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent ? AppColors.primary : AppColors.border,
            width: isCurrent ? 2 : 1,
          ),
          boxShadow: isCurrent
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppColors.primary
                    : AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isCurrent ? Colors.white : AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Current',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isCurrent)
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textSecondary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
