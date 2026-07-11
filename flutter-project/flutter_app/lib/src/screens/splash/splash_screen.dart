import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();

    // Add a safety timeout to prevent getting stuck
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      }
    });

    // Check authentication status and navigate accordingly
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Minimum splash display time for better UX
    const minSplashTime = Duration(milliseconds: 2500);
    final startTime = DateTime.now();


    try {
      // Check if onboarding was completed
      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

      // Check if user is authenticated (has valid token)
      final isAuthenticated = await ApiService.isAuthenticated();

      // Calculate remaining time to show splash
      final elapsed = DateTime.now().difference(startTime);
      final remaining = minSplashTime - elapsed;

      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }

      if (!mounted) {
        return;
      }


      if (isAuthenticated) {
        // User is logged in - check if admin on web

        if (kIsWeb) {
          // On web, check if user is admin and redirect to admin dashboard
          try {
            final profileResult = await ApiService.getProfile();
            if (profileResult['success'] == true) {
              final data = profileResult['data'] as Map?;
              final userRole = data?['user']?['role']?.toString().toLowerCase() ??
                             data?['profile']?['role']?.toString().toLowerCase() ??
                             '';


              if (userRole == 'admin') {
                if (mounted) {
                  Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
                }
                return;
              }
            }
          } catch (e) {
          }
        }

        // For mobile or non-admin users on web, go to main navigation
        Navigator.pushReplacementNamed(context, AppRoutes.mainNavigation);
      } else {
        // User not logged in
        if (!onboardingCompleted) {
          // First time user or after logout - show full onboarding flow
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
          }
        } else {
          // Returning user who completed onboarding - go to role selection
          // From role selection, user can login or register
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
          }
        }
      }
    } catch (e) {
      // Error checking auth - ensure minimum time then go to onboarding
      final elapsed = DateTime.now().difference(startTime);
      final remaining = minSplashTime - elapsed;

      if (remaining > Duration.zero && mounted) {
        await Future.delayed(remaining);
      }

      // Default to onboarding on error (full flow)
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo - Enhanced Blood Drop
                      _buildWaterDropLogo(),
                      const SizedBox(height: 40),

                      // App Name
                      const Text(
                        'Blood Donor',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontFamily: AppTypography.fontFamily,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tagline
                      const Text(
                        'Every drop saves a life',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          fontFamily: AppTypography.fontFamily,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaterDropLogo() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect behind the drop
          Positioned(
            top: 25,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main blood drop (teardrop shape - point up, round bottom)
          CustomPaint(
            size: const Size(140, 140),
            painter: _BloodDropPainter(),
          ),
        ],
      ),
    );
  }
}

class _BloodDropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseColor = const Color(0xFFE53935);

    // Create gradient for the blood drop (top to bottom)
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFFF5252), // Lighter red at top (point)
        baseColor,
        const Color(0xFFC62828),
        const Color(0xFFB71C1C), // Darkest at bottom (round)
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: size.width / 2))
      ..style = PaintingStyle.fill;

    final path = Path();

    // Teardrop shape dimensions
    final dropWidth = size.width * 0.65;
    final dropHeight = size.height * 0.82;

    // Position the drop
    final topY = center.dy - dropHeight * 0.4;
    final bottomY = center.dy + dropHeight * 0.45;
    final bottomRadius = dropWidth * 0.5; // Large radius for rounded bottom

    // Start at the pointed top
    path.moveTo(center.dx, topY);

    // Right side - curve down and outward to the rounded bottom
    path.cubicTo(
      center.dx + dropWidth * 0.3,
      topY + dropHeight * 0.25,
      center.dx + dropWidth * 0.55,
      bottomY - dropHeight * 0.15,
      center.dx + bottomRadius,
      bottomY,
    );

    // Draw the rounded bottom arc (semi-circle)
    path.arcToPoint(
      Offset(center.dx - bottomRadius, bottomY),
      radius: Radius.circular(bottomRadius),
      clockwise: true,
    );

    // Left side - curve back up to the pointed top
    path.cubicTo(
      center.dx - dropWidth * 0.55,
      bottomY - dropHeight * 0.15,
      center.dx - dropWidth * 0.3,
      topY + dropHeight * 0.25,
      center.dx,
      topY,
    );

    path.close();
    canvas.drawPath(path, paint);

    // Add subtle shadow at bottom
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(
      Offset(center.dx, bottomY + 3),
      dropWidth * 0.35,
      shadowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.fill;

    final path = Path();

    // Create diagonal shine/reflection for teardrop (upper left side)
    // Start from upper left
    path.moveTo(size.width * 0.0, size.height * 0.2);

    // Diagonal curve going down-right
    path.quadraticBezierTo(
      size.width * 0.5, size.height * 0.3,
      size.width * 0.85, size.height * 0.6,
    );

    // Return back
    path.quadraticBezierTo(
      size.width * 0.4, size.height * 0.5,
      size.width * 0.0, size.height * 0.2,
    );

    canvas.drawPath(path, paint);

    // Add a smaller highlight near the top
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final highlightPath = Path();
    highlightPath.addOval(Rect.fromCircle(
      center: Offset(size.width * 0.35, size.height * 0.35),
      radius: size.width * 0.08,
    ));
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
