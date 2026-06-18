import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons/primary_button.dart';

/// Marks onboarding as completed so the splash screen doesn't show it again
Future<void> _markOnboardingCompleted() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
  } catch (e) {
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFF5F5),
              Colors.white,
              const Color(0xFFFFF0F5),
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
                          Navigator.pushNamed(context, AppRoutes.roleSelection);
                        }
                      },
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.primary.withOpacity(0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Main illustration
                Expanded(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: _buildProfessionalIllustration(),
                        ),
                      );
                    },
                  ),
                ),

                // Content section
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: Column(
                          children: [
                            // Main heading with gradient text effect
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [AppColors.primary, Color(0xFFE53935)],
                              ).createShader(bounds),
                              child: const Text(
                                'Donate Blood,\nSave Lives',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Subheading with better typography
                            Text(
                              'Every drop counts. Your donation can give someone a second chance at life.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary.withOpacity(0.8),
                                height: 1.6,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Modern page indicators
                            _buildModernPageIndicator(0),
                            const SizedBox(height: 32),

                            // Modern CTA Button
                            _buildModernCTA(
                              text: 'Continue',
                              onPressed: () async {
                                await _markOnboardingCompleted();
                                if (mounted) {
                                  Navigator.pushNamed(context, AppRoutes.onboarding2);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalIllustration() {
    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background gradient circle
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.softPink.withOpacity(0.15),
                ],
              ),
            ),
          ),

          // Rotating rings
          _buildRotatingRing(240, AppColors.primary.withOpacity(0.08), 0),
          _buildRotatingRing(200, AppColors.primary.withOpacity(0.12), 1),
          _buildRotatingRing(260, AppColors.primary.withOpacity(0.05), 2),

          // Main heart with glow effect
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE53935), AppColors.primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              size: 70,
              color: Colors.white,
            ),
          ),

          // Floating blood drops
          _buildFloatingIcon(Icons.water_drop, 32, -80, -60, const Color(0xFFE53935), 0),
          _buildFloatingIcon(Icons.water_drop, 24, 70, -80, const Color(0xFFEF5350), 1),
          _buildFloatingIcon(Icons.water_drop, 28, -70, 70, const Color(0xFFE57373), 2),
          _buildFloatingIcon(Icons.water_drop, 20, 80, 60, const Color(0xFFFFCDD2), 3),
        ],
      ),
    );
  }

  Widget _buildRotatingRing(double size, Color color, int direction) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Transform.rotate(
          angle: value * 3.14159 * 2 * (direction == 0 ? 1 : direction == 1 ? -1 : 0.5),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingIcon(
    IconData icon,
    double size,
    double offsetX,
    double offsetY,
    Color color,
    int index,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 1200 + index * 200),
      builder: (context, value, child) {
        final offset = value * 20;
        return Positioned(
          left: 160 + offsetX - (offsetX > 0 ? offset : -offset),
          top: 160 + offsetY - (offsetY > 0 ? offset : -offset),
          child: Transform.scale(
            scale: value,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: size, color: color),
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
                      offset: const Offset(0, 2),
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
