import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../services/api_service.dart';
import '../../providers/role_provider.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? selectedRole;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Header - centered in middle
              const Text(
                'I am a...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                'Choose your role to get started',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 24),

              // Donor Card
              _RoleCard(
                icon: Icons.bloodtype,
                title: 'Donor',
                description: 'I want to donate blood and help save lives.',
                isSelected: selectedRole == 'donor',
                isLoading: _isLoading && selectedRole == 'donor',
                onTap: () => _selectRole('donor'),
              ),
              const SizedBox(height: 16),

              // Patient/Requester Card
              _RoleCard(
                icon: Icons.favorite,
                title: 'Patient/Requester',
                description: 'I need blood or want to request for someone.',
                isSelected: selectedRole == 'patient',
                isLoading: _isLoading && selectedRole == 'patient',
                onTap: () => _selectRole('patient'),
              ),

              // Admin Card - ONLY show on Web platform
              if (kIsWeb) ...[
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.admin_panel_settings,
                  title: 'Admin',
                  description: 'Platform administrator with dashboard access.',
                  isSelected: selectedRole == 'admin',
                  isLoading: _isLoading && selectedRole == 'admin',
                  onTap: () => _selectRole('admin'),
                ),
              ],

              // Show admin info on mobile
              if (!kIsWeb) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFE53935), width: 1),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Color(0xFFE53935)),
                      const SizedBox(height: 8),
                      const Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE53935),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Admin features are available on web only.\nVisit blooddonor.com on your browser.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Security Message
              const Spacer(flex: 3),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        children: [
                          WidgetSpan(
                            child: Icon(
                              Icons.shield,
                              size: 16,
                              color: Color(0xFFE53935),
                            ),
                            alignment: PlaceholderAlignment.middle,
                          ),
                          TextSpan(
                            text: ' Your information is secure\nand always protected',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle role selection - works for both logged-in and non-logged-in users
  Future<void> _selectRole(String role) async {
    setState(() {
      selectedRole = role;
      _isLoading = true;
    });

    try {
      // Check if user is already logged in
      final isAuthenticated = await ApiService.isAuthenticated();

      if (isAuthenticated) {
        // User is logged in - save role and go to main navigation
        final roleProvider = Provider.of<RoleProvider>(context, listen: false);
        final response = await roleProvider.switchRole(role);

        if (response['success'] == true && mounted) {
          // Navigate to main navigation
          Navigator.pushReplacementNamed(context, AppRoutes.mainNavigation);
        } else if (mounted) {
          // Show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to save role'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      } else {
        // User not logged in - go to login with role pre-selected
        if (mounted) {
          Navigator.pushNamed(
            context,
            AppRoutes.login,
            arguments: {'selectedRole': role},
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFE53935), width: 1),
        ),
        color: isSelected ? const Color(0xFFE53935) : Colors.white,
        elevation: isSelected ? 0 : 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Icon(
                icon,
                size: 48,
                color: isSelected ? Colors.white : const Color(0xFFE53935),
              ),
              const SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),

              // Checkmark for selected state OR loading indicator
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFE53935),
                          ),
                        )
                      : const Icon(
                          Icons.check,
                          size: 16,
                          color: Color(0xFFE53935),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
