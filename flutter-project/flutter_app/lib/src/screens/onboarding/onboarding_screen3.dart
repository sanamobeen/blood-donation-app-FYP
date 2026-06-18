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

class OnboardingScreen3 extends StatefulWidget {
  const OnboardingScreen3({super.key});

  @override
  State<OnboardingScreen3> createState() => _OnboardingScreen3State();
}

class _OnboardingScreen3State extends State<OnboardingScreen3>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _badgeAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _badgeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1, curve: Curves.ease),
      ),
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF0F5),
              Colors.white,
              Color(0xFFFFF5F5),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            child: Column(
              children: [
                // Top bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await _markOnboardingCompleted();
                        if (mounted) {
                          Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
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

                // Badge illustration
                Expanded(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: _buildHeroBadgeIllustration(),
                      );
                    },
                  ),
                ),

                // Content section
                Column(
                  children: [
                    // Heading
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppColors.primary, Color(0xFFE53935)],
                      ).createShader(bounds),
                      child: const Text(
                        'Save Lives\nWith Every Drop',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Subheading
                    Text(
                      'One donation can save up to 3 lives. Join thousands of heroes making a difference.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary.withOpacity(0.8),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatItem('100K+', 'Donors'),
                        Container(
                          width: 1,
                          height: 40,
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          color: Colors.grey.shade300,
                        ),
                        _buildStatItem('50K+', 'Lives Saved'),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Page indicators
                    _buildModernPageIndicator(2),
                    const SizedBox(height: 32),

                    // CTA Button - "Get Started" for final screen
                    _buildModernCTA(
                      text: 'Get Started',
                      onPressed: () async {
                        await _markOnboardingCompleted();
                        if (mounted) {
                          Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
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

  Widget _buildHeroBadgeIllustration() {
    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background decorative elements
          Positioned(
            top: 20,
            left: 40,
            child: _buildSparkle(),
          ),
          Positioned(
            top: 40,
            right: 30,
            child: _buildSparkle(size: 20),
          ),
          Positioned(
            bottom: 60,
            left: 30,
            child: _buildSparkle(size: 16),
          ),
          Positioned(
            bottom: 40,
            right: 50,
            child: _buildSparkle(size: 24),
          ),

          // Hero badge
          AnimatedBuilder(
            animation: _badgeAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _badgeAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Main badge circle
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFE53935), AppColors.primary],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.5),
                            blurRadius: 50,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: const Color(0xFFE53935).withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.volunteer_activism_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    // Ribbon
                    _buildRibbon(),
                  ],
                ),
              );
            },
          ),

          // Stars and sparkles around badge
          _buildFloatingStar(-90, -50, 0),
          _buildFloatingStar(80, -70, 1),
          _buildFloatingStar(-80, 80, 2),
          _buildFloatingStar(90, 60, 3),
        ],
      ),
    );
  }

  Widget _buildSparkle({double size = 24}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star, size: size * 0.7, color: Colors.amber.shade700),
          ),
        );
      },
    );
  }

  Widget _buildRibbon() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left ribbon
        _buildRibbonSide(isLeft: true),
        const SizedBox(width: 100),
        // Right ribbon
        _buildRibbonSide(isLeft: false),
      ],
    );
  }

  Widget _buildRibbonSide({required bool isLeft}) {
    return ClipPath(
      clipper: _RibbonClipper(isLeft: isLeft),
      child: Container(
        width: 40,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFE53935),
              AppColors.primary,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingStar(double offsetX, double offsetY, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 1000 + index * 200),
      builder: (context, value, child) {
        final rotation = value * 3.14159 * 2;
        return Positioned(
          left: 160 + offsetX,
          top: 160 + offsetY,
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: 0.5 + (value * 0.5),
              child: Icon(
                Icons.star_rounded,
                size: 28,
                color: Colors.amber.shade400.withOpacity(value),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withOpacity(0.7),
          ),
        ),
      ],
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
                    'Get Started',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(
                    Icons.check_circle_rounded,
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

class _RibbonClipper extends CustomClipper<Path> {
  _RibbonClipper({required this.isLeft});

  final bool isLeft;

  @override
  Path getClip(Size size) {
    final path = Path();

    if (isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width * 0.4, 0);
      path.lineTo(size.width, size.height * 0.4);
      path.lineTo(size.width * 0.6, size.height);
      path.lineTo(0, size.height * 0.6);
      path.lineTo(size.width * 0.4, size.height * 0.4);
      path.lineTo(0, size.height * 0.2);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width * 0.6, 0);
      path.lineTo(0, size.height * 0.4);
      path.lineTo(size.width * 0.4, size.height);
      path.lineTo(size.width, size.height * 0.6);
      path.lineTo(size.width * 0.6, size.height * 0.4);
      path.lineTo(size.width, size.height * 0.2);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
