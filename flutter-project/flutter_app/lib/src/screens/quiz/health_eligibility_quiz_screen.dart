import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../app_routes.dart';
import '../../services/api_service.dart';

class HealthEligibilityQuizScreen extends StatefulWidget {
  const HealthEligibilityQuizScreen({super.key});

  @override
  State<HealthEligibilityQuizScreen> createState() => _HealthEligibilityQuizScreenState();
}

class _HealthEligibilityQuizScreenState extends State<HealthEligibilityQuizScreen> {
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
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
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
      // If no responses, show error
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

          // Show result dialog
          _showResultDialog(
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

  void _showResultDialog({
    required bool isEligible,
    required String message,
    required bool canProceed,
    required List<dynamic> reasons,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isEligible ? AppColors.online : const Color(0xFFFF6B6B),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEligible ? Icons.check_rounded : Icons.close_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isEligible ? 'Eligible!' : 'Not Eligible',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isEligible ? AppColors.online : const Color(0xFFFF6B6B),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Reasons:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ...reasons.map((reason) => Padding(
                  key: ValueKey('ineligible_reason_$reason'),
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: AppColors.primary)),
                      Expanded(
                        child: Text(
                          reason.toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          if (canProceed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Proceed to nearby requests for donors
                  Navigator.pushReplacementNamed(context, AppRoutes.nearbyRequests);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'View Nearby Blood Requests',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Go back to home
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textSecondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _goToNextQuestion() {
    final currentQuestionData = questions[currentQuestionIndex];
    final questionId = currentQuestionData['id']?.toString() ?? currentQuestionIndex.toString();

    // Store the response
    if (selectedAnswer != null) {
      userResponses[questionId] = selectedAnswer!;
    }

    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        selectedAnswer = null;
      });
    } else {
      // Quiz completed, submit responses
      _submitQuiz();
    }
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
            if (!isLoadingQuestions && questions.isNotEmpty) _buildProgressBar(),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoadingQuestions) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading quiz questions...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: const Color(0xFFFF6B6B)),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchQuestions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return const Center(
        child: Text('No questions available'),
      );
    }

    return Column(
      children: [
        // Illustration
        _buildIllustration(),

        const SizedBox(height: 32),

        // Question
        _buildQuestion(),

        const SizedBox(height: 32),

        // Options
        _buildOptions(),

        const SizedBox(height: 24),

        // Skip Button
        _buildSkipButton(),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
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

          // App Name
          const Text(
            'LifeDrop',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          // Help Icon
          GestureDetector(
            onTap: () {
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

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Progress Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${currentQuestionIndex + 1} of $totalQuestions',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'HEALTH ELIGIBILITY QUIZ',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: totalQuestions > 0 ? (currentQuestionIndex + 1) / totalQuestions : 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.softPink.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Blood donor illustration
          Icon(
            Icons.person_rounded,
            size: 80,
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          // Checklist items around
          Positioned(
            top: 30,
            right: 25,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                size: 14,
                color: AppColors.online,
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: 20,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                size: 14,
                color: AppColors.online,
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 25,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                size: 14,
                color: AppColors.online,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final currentQuestionData = questions[currentQuestionIndex];
    final questionText = currentQuestionData['question_text'] ?? currentQuestionData['question'] ?? 'No question text';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        questionText,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.3,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(options.length, (index) {
          final option = options[index].toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildOptionButton(
              label: option,
              isSelected: selectedAnswer == option,
              onTap: () {
                setState(() {
                  selectedAnswer = option;
                });
                // Auto-advance to next question after a short delay
                Future.delayed(const Duration(milliseconds: 300), () {
                  _goToNextQuestion();
                });
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOptionButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFE0E0E0),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: AppColors.primary,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
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
      child: const Text(
        'Skip this question',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
