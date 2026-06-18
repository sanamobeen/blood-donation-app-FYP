import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_routes.dart';
import '../../theme/app_theme.dart';

/// Marks onboarding as completed
Future<void> _markOnboardingCompleted() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
  } catch (e) {
  }
}

class OnboardingScreen2 extends StatefulWidget {
  const OnboardingScreen2({super.key});

  @override
  State<OnboardingScreen2> createState() => _OnboardingScreen2State();
}

class _OnboardingScreen2State extends State<OnboardingScreen2>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();

    // Repeat pulse animation
    _animationController.repeat(period: const Duration(milliseconds: 2000));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD),
              Colors.white,
              Color(0xFFF5F5F5),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            child: Column(
              children: [
                // Top bar with Skip
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await _markOnboardingCompleted();
                        if (mounted) {
                          Navigator.pushNamed(context, AppRoutes.login);
                        }
                      },
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.primary.withOpacity(0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Map illustration
                Expanded(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: _buildModernMapIllustration(),
                      );
                    },
                  ),
                ),

                // Content section
                Column(
                  children: [
                    // Heading
                    const Text(
                      'Find Blood Donors\nNear You',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Subheading
                    Text(
                      'Connect with donors in real-time. Get notified when someone nearby needs your blood type.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary.withOpacity(0.8),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Page indicators
                    _buildModernPageIndicator(1),
                    const SizedBox(height: 32),

                    // CTA Button
                    _buildModernCTA(
                      text: 'Continue',
                      onPressed: () async {
                        await _markOnboardingCompleted();
                        if (mounted) {
                          Navigator.pushNamed(context, AppRoutes.onboarding3);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernMapIllustration() {
    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Map background card with glassmorphism
          Positioned(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _buildMapContent(),
              ),
            ),
          ),

          // Pulse rings for central location
          _buildPulseRing(80, AppColors.primary.withOpacity(0.2), 0),
          _buildPulseRing(80, AppColors.primary.withOpacity(0.1), 400),

          // Central location pin
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: _buildCentralPin(),
              );
            },
          ),

          // Surrounding pins with staggered animation
          _buildSurroundingPin(Icons.location_on, -60, -40, const Color(0xFFE53935), 0),
          _buildSurroundingPin(Icons.location_on, 60, -50, const Color(0xFFEF5350), 1),
          _buildSurroundingPin(Icons.location_on, -50, 50, const Color(0xFFE57373), 2),
          _buildSurroundingPin(Icons.location_on, 70, 40, const Color(0xFFFFCDD2), 3),
          _buildSurroundingPin(Icons.location_on, 0, -70, const Color(0xFFEF9A9A), 4),
        ],
      ),
    );
  }

  Widget _buildMapContent() {
    return Stack(
      children: [
        // Light background
        Container(color: const Color(0xFFF5F5F5)),

        // Map grid pattern
        ...List.generate(6, (i) {
          return Positioned(
            left: 0,
            right: 0,
            top: i * 50.0 + 20,
            child: Container(
              height: 1,
              color: Colors.grey.shade200,
            ),
          );
        }),
        ...List.generate(6, (i) {
          return Positioned(
            top: 0,
            bottom: 0,
            left: i * 50.0 + 20,
            child: Container(
              width: 1,
              color: Colors.grey.shade200,
            ),
          );
        }),

        // Decorative map elements
        Positioned(
          top: 40,
          left: 30,
          child: _buildMapBlock(Colors.blue.shade100, 60, 40),
        ),
        Positioned(
          bottom: 60,
          right: 40,
          child: _buildMapBlock(AppColors.softPink.withOpacity(0.5), 50, 50),
        ),
        Positioned(
          top: 100,
          right: 50,
          child: _buildMapBlock(Colors.green.shade100, 40, 60),
        ),
        Positioned(
          bottom: 100,
          left: 50,
          child: _buildMapBlock(Colors.amber.shade100, 45, 35),
        ),
      ],
    );
  }

  Widget _buildMapBlock(Color color, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildPulseRing(double size, Color color, int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 1200 + delayMs),
      builder: (context, value, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(1 - value),
              width: 2,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCentralPin() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFE53935)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.my_location_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildSurroundingPin(
    IconData icon,
    double offsetX,
    double offsetY,
    Color color,
    int index,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800 + index * 150),
      builder: (context, value, child) {
        return Positioned(
          left: 160 + offsetX,
          top: 160 + offsetY,
          child: Transform.scale(
            scale: value,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernPageIndicator(int currentPage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: index == currentPage ? 32 : 10,
          height: 10,
          decoration: BoxDecoration(
            gradient: index == currentPage
                ? const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFE53935)],
                  )
                : null,
            color: index == currentPage ? null : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(5),
            boxShadow: index == currentPage
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildModernCTA({required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFFE53935)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(28),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
