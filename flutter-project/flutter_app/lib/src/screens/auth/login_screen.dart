import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedRole; // 'donor' or 'patient'

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get role from navigation arguments (must be in didChangeDependencies)
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['selectedRole'] != null) {
      _selectedRole = args['selectedRole'];
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Validate inputs
    if (_emailController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Call login API
    final result = await ApiService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // Get user role from login response first
      String? userRole;
      if (result['data'] != null && result['data']['user'] != null) {
        userRole = result['data']['user']['role']?.toString();
      }

      // IMPORTANT: If user selected a role at role selection screen, use it
      // This overrides the backend role and updates the backend to match
      if (_selectedRole != null && _selectedRole!.isNotEmpty) {
        // Update the backend to match the selected role
        final updateResult = await ApiService.updateUserRole(_selectedRole!);
        if (updateResult['success'] == true) {
          userRole = _selectedRole;
        }
        // If update fails, still use the selected role locally
        userRole = _selectedRole;
      }

      // Login successful - check if profile exists
      final profileResult = await ApiService.getProfile();

      if (!mounted) return;

      // Navigate based on whether profile exists and user role
      if (profileResult['success'] == true && profileResult['data'] != null) {
        // If we didn't get role from login response, try to get it from profile response
        if (userRole == null) {
          // Check in user object
          if (profileResult['data']['user'] != null) {
            userRole = profileResult['data']['user']['role']?.toString();
          }

          // Check in profile object
          if (userRole == null && profileResult['data']['profile'] != null) {
            userRole = profileResult['data']['profile']['role']?.toString();
          }
        }


        // Check if admin user is trying to login from mobile
        if (userRole == 'admin' && !kIsWeb) {
          _showAdminMobileDialog();
          return;
        }

        // Navigate admin users on web directly to admin dashboard
        if (userRole == 'admin' && kIsWeb) {
          Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
          return;
        }

        // Navigate to unified main navigation (role handling is done internally)
        Navigator.pushReplacementNamed(context, AppRoutes.mainNavigation);
      } else {
        // No profile - go to profile setup
        Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
      }
    } else {
      setState(() => _errorMessage = result['message'] ?? 'Login failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Login failed'),
          backgroundColor: AppColors.urgencyCritical,
        ),
      );
    }
  }

  /// Show dialog for admin users on mobile, directing them to web
  void _showAdminMobileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('Admin Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin dashboard is only available on web.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please visit lifedrop.com on your browser to access admin features.',
              style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text('User & Profile Management', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text('Analytics & Statistics', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text('Platform Monitoring', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isLoading = false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isLoading = false);
              // Open web admin dashboard in browser
              _launchWebAdmin();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Web Admin'),
          ),
        ],
      ),
    );
  }

  /// Launch web admin dashboard in browser
  Future<void> _launchWebAdmin() async {
    final url = Uri.parse('http://localhost:8080'); // Or your production URL
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch web browser')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Full content including logo, welcome text, and form fields
    final fullContent = Column(
      children: [
        const SizedBox(height: 40),

        // Logo Section
        Center(
          child: Column(
            children: [
              // Blood drop icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.water_drop,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // Blood Donation text
              const Text(
                'Blood Donation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),

              // Tagline
              const Text(
                'Every drop counts',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        // Welcome Section
        const Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        const Text(
          'Login to continue your life-saving journey.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Email Field
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Email',
            prefixIcon: const Icon(Icons.mail_outline),
            prefixIconColor: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),

        // Password Field
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            prefixIconColor: AppColors.textSecondary,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Forgot Password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.forgotPassword);
            },
            child: const Text(
              'Forgot password?',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Error Message
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // Login Button
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            text: _isLoading ? 'Logging in...' : 'Log in',
            onPressed: _isLoading ? null : _handleLogin,
          ),
        ),
        const SizedBox(height: 24),

        // Sign Up Link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'New here? ',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.signUp,
                  arguments: _selectedRole != null
                      ? {'selectedRole': _selectedRole}
                      : null,
                );
              },
              child: const Text(
                'Sign up',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: kIsWeb
            ? // Web: Everything in a centered box
            Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 550),
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xFFE0E0E0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: fullContent,
                    ),
                  ),
                ),
              )
            : // Mobile: Full-width layout without box
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: fullContent,
              ),
            ),
      ),
    );
  }
}
