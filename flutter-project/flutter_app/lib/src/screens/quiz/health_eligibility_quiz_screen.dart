import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../app_routes.dart';
import '../../services/api_service.dart';

class HealthEligibilityQuizScreen extends StatefulWidget {
  const HealthEligibilityQuizScreen({super.key});

  @override
  State<HealthEligibilityQuizScreen> createState() => _HealthEligibilityQuizScreenState();
}

class _HealthEligibilityQuizScreenState extends State<HealthEligibilityQuizScreen>
    with TickerProviderStateMixin {
  int currentQuestionIndex = 0;
  int totalQuestions = 0;
  String? selectedAnswer;

  // Questions fetched from backend
  List<dynamic> questions = [];

  // Store user responses: {questionId: answer}
  final Map<String, String> userResponses = {};

  // Loading states
  bool isLoadingQuestions = true;
  bool isSubmitting = false;
  bool showIntro = true;
  String? errorMessage;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchQuestions();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuestions() async {
    try {
      final result = await ApiService.getHealthQuiz();

      if (mounted) {
        if (result['success'] == true) {
          final questionsData = result['questions'];

          if (questionsData is List) {
            setState(() {
              questions = List<dynamic>.from(questionsData);
              totalQuestions = questions.length;
              isLoadingQuestions = false;
            });
          } else {
            setState(() {
              errorMessage = 'Invalid questions format received';
              isLoadingQuestions = false;
            });
          }
        } else {
          setState(() {
            errorMessage = result['message'] ?? 'Failed to load questions';
            isLoadingQuestions = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error loading questions: $e';
          isLoadingQuestions = false;
        });
      }
    }
  }

  Future<void> _submitQuiz() async {
    if (userResponses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer at least one question')),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final result = await ApiService.submitHealthQuiz(userResponses);

      if (mounted) {
        setState(() {
          isSubmitting = false;
        });

        if (result['success'] == true) {
          final data = result['data'] ?? {};
          final isEligible = data['is_eligible'] ?? false;
          final message = data['message'] ?? '';
          final canProceed = data['can_proceed'] ?? false;
          final reasons = data['disqualification_reasons'] as List<dynamic>? ?? [];

          _showResultScreen(
            isEligible: isEligible,
            message: message,
            canProceed: canProceed,
            reasons: reasons,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to submit quiz')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting quiz: $e')),
        );
      }
    }
  }

  void _showResultScreen({
    required bool isEligible,
    required String message,
    required bool canProceed,
    required List<dynamic> reasons,
  }) {
    setState(() {
      showIntro = false;
    });

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        _QuizResultScreen(
          isEligible: isEligible,
          message: message,
          canProceed: canProceed,
          reasons: reasons,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _goToNextQuestion() {
    final currentQuestionData = questions[currentQuestionIndex];
    final questionId = currentQuestionData['id']?.toString() ?? currentQuestionIndex.toString();

    if (selectedAnswer != null) {
      userResponses[questionId] = selectedAnswer!;
    }

    if (currentQuestionIndex < questions.length - 1) {
      // Animate transition
      _fadeController.reverse().then((_) {
        setState(() {
          currentQuestionIndex++;
          selectedAnswer = null;
        });
        _fadeController.forward();
      });
    } else {
      _submitQuiz();
    }
  }

  void _startQuiz() {
    setState(() {
      showIntro = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Progress Bar
            if (!showIntro && !isLoadingQuestions && questions.isNotEmpty)
              _buildProgressBar(),

            // Main Content
            Expanded(
              child: isLoadingQuestions ? _buildLoadingState() : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading quiz questions...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (errorMessage != null) {
      return _buildErrorState();
    }

    if (questions.isEmpty) {
      return _buildEmptyState();
    }

    if (showIntro) {
      return _buildIntroScreen();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Question number badge
              _buildQuestionNumberBadge(),

              const SizedBox(height: 32),

              // Question card
              _buildQuestionCard(),

              const SizedBox(height: 32),

              // Options
              _buildOptions(),

              const SizedBox(height: 32),

              // Skip button
              _buildSkipButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Color(0xFFFF6B6B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _fetchQuestions,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.quiz_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No questions available',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Hero illustration
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.softPink.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.health_and_safety_rounded,
                  size: 100,
                  color: AppColors.primary.withOpacity(0.3),
                ),
                Positioned(
                  top: 20,
                  right: 30,
                  child: _buildFloatingIcon(Icons.favorite_rounded, Colors.red),
                ),
                Positioned(
                  bottom: 40,
                  right: 20,
                  child: _buildFloatingIcon(Icons.bloodtype_rounded, AppColors.primary),
                ),
                Positioned(
                  top: 50,
                  left: 25,
                  child: _buildFloatingIcon(Icons.verified_rounded, Colors.green),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            'Health Eligibility Quiz',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Before you can donate blood, we need to ask you a few health-related questions. '
              'This helps ensure the safety of both donors and recipients.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 48),

          // Quiz info cards
          _buildInfoCard(
            icon: Icons.timer_rounded,
            title: 'Quick & Easy',
            description: 'Takes only 2-3 minutes',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.privacy_tip_rounded,
            title: 'Confidential',
            description: 'Your responses are private',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.verified_rounded,
            title: 'Valid for 30 Days',
            description: 'No need to retake until then',
          ),

          const SizedBox(height: 48),

          // Start button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Start Quiz',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFloatingIcon(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 20,
        color: color,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.softPink.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showIntro)
            const SizedBox(width: 44)
          else
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.softPink.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),

          // App Name with logo
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bloodtype_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Blood Donor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          // Help icon
          GestureDetector(
            onTap: () {
              _showHelpDialog();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.softPink.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.help_outline_rounded,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            const Text('Quiz Help'),
          ],
        ),
        content: const Text(
          'This quiz helps us determine if you\'re eligible to donate blood. '
          'Answer honestly to ensure everyone\'s safety. Your eligibility is valid for 30 days.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = totalQuestions > 0 ? (currentQuestionIndex + 1) / totalQuestions : 0;
    final progressPercent = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${currentQuestionIndex + 1} of $totalQuestions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$progressPercent%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionNumberBadge() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'Q${currentQuestionIndex + 1}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard() {
    final currentQuestionData = questions[currentQuestionIndex];
    final questionText = currentQuestionData['question_text'] ?? currentQuestionData['question'] ?? 'No question text';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        questionText,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOptions() {
    final currentQuestionData = questions[currentQuestionIndex];
    final options = currentQuestionData['options'] as List<dynamic>?;

    if (options == null || options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: List.generate(options.length, (index) {
        final option = options[index].toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildOptionCard(
            label: option,
            isSelected: selectedAnswer == option,
            onTap: () {
              setState(() {
                selectedAnswer = option;
              });
              Future.delayed(const Duration(milliseconds: 300), () {
                _goToNextQuestion();
              });
            },
          ),
        );
      }),
    );
  }

  Widget _buildOptionCard({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.primary.withOpacity(0.1),
        child: Row(
          children: [
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.grey.shade200,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: AppColors.primary,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Option text
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return TextButton(
      onPressed: () {
        _goToNextQuestion();
      },
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 24),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.skip_next_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Skip this question',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizResultScreen extends StatelessWidget {
  final bool isEligible;
  final String message;
  final bool canProceed;
  final List<dynamic> reasons;

  const _QuizResultScreen({
    required this.isEligible,
    required this.message,
    required this.canProceed,
    required this.reasons,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Result icon
              _buildResultIcon(),

              const SizedBox(height: 32),

              // Result title
              Text(
                isEligible ? 'You\'re Eligible!' : 'Not Eligible',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isEligible ? AppColors.online : const Color(0xFFFF6B6B),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Result message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Reasons for ineligibility
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFF6B6B).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: const Color(0xFFFF6B6B),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reasons:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...reasons.map((reason) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6B6B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                reason.toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Always navigate to main navigation (donor home screen)
                    // Eligibility will control pledge button visibility
                    Navigator.pushReplacementNamed(context, AppRoutes.mainNavigation);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEligible ? AppColors.primary : AppColors.textSecondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Continue to App',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: isEligible ? AppColors.online.withOpacity(0.1) : const Color(0xFFFF6B6B).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isEligible ? Icons.check_rounded : Icons.close_rounded,
        color: isEligible ? AppColors.online : const Color(0xFFFF6B6B),
        size: 60,
      ),
    );
  }
}
