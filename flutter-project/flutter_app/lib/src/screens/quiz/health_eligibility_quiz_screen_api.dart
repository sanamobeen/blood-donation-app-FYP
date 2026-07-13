import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

/// Health Eligibility Quiz Screen with API integration
class HealthEligibilityQuizScreenApi extends StatefulWidget {
  const HealthEligibilityQuizScreenApi({super.key});

  @override
  State<HealthEligibilityQuizScreenApi> createState() => _HealthEligibilityQuizScreenApiState();
}

class _HealthEligibilityQuizScreenApiState extends State<HealthEligibilityQuizScreenApi> {
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Quiz data
  List<Map<String, dynamic>> _questions = [];
  String _quizVersion = '';

  // Current state
  int _currentQuestionIndex = 0;
  Map<String, dynamic> _responses = {};

  // Result
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getHealthQuiz();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        final questions = data['questions'] as List? ?? [];

        setState(() {
          _questions = questions.map((q) => q as Map<String, dynamic>).toList();
          _quizVersion = data['quiz_version'] as String? ?? 'v1.0';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _showError('Failed to load quiz. Please try again.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Use default questions if API fails
      _useDefaultQuestions();
    }
  }

  void _useDefaultQuestions() {
    setState(() {
      _questions = [
        {
          'id': '1',
          'question': 'Have you donated blood in the last 90 days?',
          'type': 'boolean',
          'options': ['Yes', 'No'],
        },
        {
          'id': '2',
          'question': 'Are you currently taking any medications?',
          'type': 'boolean',
          'options': ['Yes', 'No'],
        },
        {
          'id': '3',
          'question': 'Have you traveled outside your country in the last 28 days?',
          'type': 'boolean',
          'options': ['Yes', 'No'],
        },
        {
          'id': '4',
          'question': 'Have you had any illness, fever, or infection in the last 14 days?',
          'type': 'boolean',
          'options': ['Yes', 'No'],
        },
        {
          'id': '5',
          'question': 'Do you weigh at least 45 kg?',
          'type': 'boolean',
          'options': ['Yes', 'No'],
        },
        {
          'id': '6',
          'question': 'Have you had any tattoos or piercings in the last 6 months?',
          'type': 'boolean',
          'options': ['Yes', 'No'],
        },
        {
          'id': '7',
          'question': 'Have you had any major surgery in the last 6 months?',
          'type': 'boolean',
          'options': ['Yes', 'No'],
        },
        {
          'id': '8',
          'question': 'Are you currently breastfeeding or pregnant?',
          'type': 'boolean',
          'options': ['Yes', 'No'],
        },
        {
          'id': '9',
          'question': 'Have you ever received a blood transfusion?',
          'type': 'boolean',
          'options': ['Yes', 'No'],
        },
        {
          'id': '10',
          'question': 'Do you have any chronic medical conditions?',
          'type': 'boolean',
          'options': ['Yes', 'No'],
        },
      ];
      _quizVersion = 'v1.0';
    });
  }

  Future<void> _submitQuiz() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await ApiService.submitHealthQuiz(_responses);
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;

        setState(() {
          _result = data;
          _isSubmitting = false;
        });

        _showResultDialog();
      } else {
        setState(() {
          _isSubmitting = false;
        });
        _showError(result['message'] as String? ?? 'Failed to submit quiz');
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showError('Network error: $e');
    }
  }

  void _selectAnswer(String answer) {
    final currentQuestion = _questions[_currentQuestionIndex];
    final questionId = currentQuestion['id'].toString();

    setState(() {
      _responses[questionId] = answer == 'Yes';

      // Auto-advance to next question
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_currentQuestionIndex < _questions.length - 1) {
          setState(() {
            _currentQuestionIndex++;
          });
        } else {
          // Quiz complete
          _submitQuiz();
        }
      });
    });
  }

  void _skipQuestion() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final questionId = currentQuestion['id'].toString();

    setState(() {
      _responses[questionId] = null;

      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        _submitQuiz();
      }
    });
  }

  void _showResultDialog() {
    if (_result == null) return;

    final isEligible = _result['is_eligible'] as bool? ?? false;
    final ineligibilityReasons = _result['ineligibility_reasons'] as List? ?? [];
    final eligibilityValidUntil = _result['eligibility_valid_until'] as String?;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isEligible
                    ? const Color(0xFF4CAF50)
                    : Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEligible
                    ? Icons.check_circle
                    : Icons.info,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              isEligible
                  ? 'Eligible to Donate!'
                  : 'Not Currently Eligible',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              isEligible
                  ? 'Congratulations! You meet all the requirements to donate blood.'
                  : 'Based on your responses, you\'re not currently eligible to donate.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),

            // Ineligibility reasons
            if (!isEligible && ineligibilityReasons.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reasons:',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...ineligibilityReasons.map((reason) => Padding(
                          key: ValueKey('ineligible_reason_$reason'),
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $reason',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ],

            // Valid until date
            if (isEligible && eligibilityValidUntil != null) ...[
              const SizedBox(height: 12),
              Text(
                'Eligibility valid until: $eligibilityValidUntil',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: const Text('Go Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (isEligible) {
                        Navigator.popAndPushNamed(context, '/blood-request-form');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(isEligible ? 'Continue' : 'Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading eligibility quiz...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_result != null) {
      return _buildResultScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Progress Bar
            _buildProgressBar(),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final isEligible = _result['is_eligible'] as bool? ?? false;
    final ineligibilityReasons = _result['ineligibility_reasons'] as List? ?? [];
    final eligibilityValidUntil = _result['eligibility_valid_until'] as String?;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isEligible
                        ? const Color(0xFF4CAF50)
                        : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEligible
                        ? Icons.check_circle
                        : Icons.info,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  isEligible
                      ? 'Eligible to Donate!'
                      : 'Not Currently Eligible',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Message
                Text(
                  isEligible
                      ? 'Congratulations! You meet all the requirements to donate blood.'
                      : 'Based on your responses, you\'re not currently eligible to donate.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Ineligibility reasons
                if (!isEligible && ineligibilityReasons.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Reasons:',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...ineligibilityReasons.map((reason) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: Colors.orange)),
                                  Expanded(
                                    child: Text(
                                      reason.toString(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
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

                // Valid until date
                if (isEligible && eligibilityValidUntil != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.event,
                          color: Color(0xFF4CAF50),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Valid until: $eligibilityValidUntil',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Actions
                SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (isEligible) {
                        Navigator.pushNamed(context, '/blood-request-form');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isEligible ? 'Continue' : 'Go Back'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
            'Blood Donor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          // Help Icon
          GestureDetector(
            onTap: () {
              _showQuizInfo();
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
    final progress = _questions.isEmpty
        ? 0.0
        : (_currentQuestionIndex + 1) / _questions.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Progress Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
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
              widthFactor: progress,
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
            color: AppColors.primary.withOpacity(0.3),
          ),
          // Checklist items around
          Positioned(
            top: 30,
            right: 25,
            child: _buildCheckIcon(),
          ),
          Positioned(
            bottom: 40,
            right: 20,
            child: _buildCheckIcon(),
          ),
          Positioned(
            top: 50,
            left: 25,
            child: _buildCheckIcon(),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckIcon() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: const Icon(
        Icons.check,
        size: 14,
        color: AppColors.online,
      ),
    );
  }

  Widget _buildQuestion() {
    if (_questions.isEmpty) return const SizedBox.shrink();

    final currentQuestionData = _questions[_currentQuestionIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        currentQuestionData['question'] as String? ?? '',
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
    if (_questions.isEmpty) return const SizedBox.shrink();

    final currentQuestionData = _questions[_currentQuestionIndex];
    final options = currentQuestionData['options'] as List? ?? ['Yes', 'No'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(options.length, (index) {
          final option = options[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildOptionButton(
              label: option.toString(),
              onTap: () {
                _selectAnswer(option.toString());
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOptionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFE0E0E0),
            width: 1,
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
                color: const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE0E0E0),
                  width: 2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Label
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return TextButton(
      onPressed: _isSubmitting ? null : _skipQuestion,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 24),
      ),
      child: Text(
        _isSubmitting ? 'Submitting...' : 'Skip this question',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _isSubmitting ? Colors.grey : AppColors.textSecondary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  void _showQuizInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About This Quiz'),
        content: const Text(
          'This health eligibility quiz helps determine if you can safely donate blood. '
          'Your responses are confidential and are only used to assess your eligibility.',
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

  void Navigator_popAndPushNamed(BuildContext context, String route) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route);
  }
}
