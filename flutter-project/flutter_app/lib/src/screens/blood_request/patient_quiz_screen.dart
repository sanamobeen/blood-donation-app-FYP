import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PatientQuizScreen extends StatefulWidget {
  const PatientQuizScreen({super.key});

  @override
  State<PatientQuizScreen> createState() => _PatientQuizScreenState();
}

class _PatientQuizScreenState extends State<PatientQuizScreen> {
  // Quiz responses
  bool _quizHadBloodTransfusion = false;
  bool _quizHadTattooPiercing = false;
  bool _quizHadSurgery = false;
  bool _quizOnMedication = false;
  bool _quizHasChronicDisease = false;
  bool _quizTraveledMalariaArea = false;
  String _quizOtherMedicalInfo = '';

  // Quiz questions data
  final List<QuizQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _initializeQuestions();
  }

  void _initializeQuestions() {
    // Questions will be initialized with their current values
    _questions.addAll([
      QuizQuestion(
        id: 'had_blood_transfusion',
        question: 'Has the patient had a blood transfusion in the last 3 months?',
        icon: Icons.bloodtype_outlined,
        color: const Color(0xFFE53935),
        onChanged: (value) => setState(() => _quizHadBloodTransfusion = value),
        getValue: () => _quizHadBloodTransfusion,
      ),
      QuizQuestion(
        id: 'had_tattoo_piercing',
        question: 'Has the patient had any tattoos or piercings in the last 6 months?',
        icon: Icons.brush_outlined,
        color: const Color(0xFF8E24AA),
        onChanged: (value) => setState(() => _quizHadTattooPiercing = value),
        getValue: () => _quizHadTattooPiercing,
      ),
      QuizQuestion(
        id: 'had_surgery',
        question: 'Has the patient had any major surgery in the last 6 months?',
        icon: Icons.medical_services_outlined,
        color: const Color(0xFF1E88E5),
        onChanged: (value) => setState(() => _quizHadSurgery = value),
        getValue: () => _quizHadSurgery,
      ),
      QuizQuestion(
        id: 'on_medication',
        question: 'Is the patient currently on any medication?',
        icon: Icons.medication_outlined,
        color: const Color(0xFF43A047),
        onChanged: (value) => setState(() => _quizOnMedication = value),
        getValue: () => _quizOnMedication,
      ),
      QuizQuestion(
        id: 'has_chronic_disease',
        question: 'Does the patient have any chronic diseases (diabetes, hypertension, etc.)?',
        icon: Icons.monitor_heart_outlined,
        color: const Color(0xFFFB8C00),
        onChanged: (value) => setState(() => _quizHasChronicDisease = value),
        getValue: () => _quizHasChronicDisease,
      ),
      QuizQuestion(
        id: 'traveled_malaria_area',
        question: 'Has the patient traveled to any malaria-prone areas in the last 12 months?',
        icon: Icons.flight_takeoff_outlined,
        color: const Color(0xFF5E35B1),
        onChanged: (value) => setState(() => _quizTraveledMalariaArea = value),
        getValue: () => _quizTraveledMalariaArea,
      ),
    ]);
  }

  int get _answeredQuestions {
    return (_quizHadBloodTransfusion ? 1 : 0) +
        (_quizHadTattooPiercing ? 1 : 0) +
        (_quizHadSurgery ? 1 : 0) +
        (_quizOnMedication ? 1 : 0) +
        (_quizHasChronicDisease ? 1 : 0) +
        (_quizTraveledMalariaArea ? 1 : 0);
  }

  double get _progress => _answeredQuestions / _questions.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, color: AppColors.primary, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Medical History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Section
            _buildProgressSection(),

            // Questions List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: _questions.length + 1, // +1 for additional info
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  if (index < _questions.length) {
                    return _buildQuestionCard(_questions[index]);
                  } else {
                    return _buildAdditionalInfoCard();
                  }
                },
              ),
            ),

            // Continue Button
            _buildContinueButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Complete Your Profile',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_answeredQuestions of ${_questions.length} answered',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(_progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
              value: _progress,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(QuizQuestion question) {
    final value = question.getValue();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: question.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  question.icon,
                  color: question.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  question.question,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Yes/No buttons
          Row(
            children: [
              Expanded(
                child: _buildOptionButton(
                  label: 'Yes',
                  isSelected: value == true,
                  onTap: () => question.onChanged(true),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOptionButton(
                  label: 'No',
                  isSelected: value == false,
                  onTap: () => question.onChanged(false),
                  color: value == false ? AppColors.primary : const Color(0xFF757575),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF78909C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.note_add_outlined,
                  color: Color(0xFF78909C),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Additional Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
            ),
            child: TextField(
              onChanged: (value) => setState(() => _quizOtherMedicalInfo = value),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Any other medical information you\'d like to share...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                border: InputBorder.none,
              ),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _handleContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _handleContinue() {
    // Collect quiz responses
    final quizResponses = {
      'had_blood_transfusion': _quizHadBloodTransfusion,
      'had_tattoo_piercing': _quizHadTattooPiercing,
      'had_surgery': _quizHadSurgery,
      'on_medication': _quizOnMedication,
      'has_chronic_disease': _quizHasChronicDisease,
      'traveled_malaria_area': _quizTraveledMalariaArea,
      'other_medical_info': _quizOtherMedicalInfo.trim().isEmpty ? null : _quizOtherMedicalInfo.trim(),
    };

    // Check for risk factors
    final riskFactors = _getRiskFactors(quizResponses);

    if (riskFactors.isNotEmpty) {
      // Show warning dialog
      _showMedicalWarningDialog(riskFactors, quizResponses);
    } else {
      // No risk factors, proceed directly
      Navigator.pushReplacementNamed(
        context,
        '/blood-request-form',
        arguments: quizResponses,
      );
    }
  }

  List<RiskFactor> _getRiskFactors(Map<String, dynamic> responses) {
    final risks = <RiskFactor>[];

    if (responses['had_blood_transfusion'] == true) {
      risks.add(RiskFactor(
        title: 'Recent Blood Transfusion',
        description: 'Patient had a blood transfusion in the last 3 months',
        icon: Icons.bloodtype_outlined,
        color: const Color(0xFFE53935),
        recommendation: 'Consult with a doctor before proceeding with blood donation.',
      ));
    }

    if (responses['had_tattoo_piercing'] == true) {
      risks.add(RiskFactor(
        title: 'Recent Tattoo/Piercing',
        description: 'Patient had tattoos or piercings in the last 6 months',
        icon: Icons.brush_outlined,
        color: const Color(0xFF8E24AA),
        recommendation: 'Wait 6 months from the date of tattoo/piercing for safe donation.',
      ));
    }

    if (responses['had_surgery'] == true) {
      risks.add(RiskFactor(
        title: 'Recent Surgery',
        description: 'Patient had major surgery in the last 6 months',
        icon: Icons.medical_services_outlined,
        color: const Color(0xFF1E88E5),
        recommendation: 'Wait 6 months after surgery before donating blood.',
      ));
    }

    if (responses['on_medication'] == true) {
      risks.add(RiskFactor(
        title: 'Current Medication',
        description: 'Patient is currently on medication',
        icon: Icons.medication_outlined,
        color: const Color(0xFF43A047),
        recommendation: 'Certain medications may temporarily defer donation. Consult healthcare provider.',
      ));
    }

    if (responses['has_chronic_disease'] == true) {
      risks.add(RiskFactor(
        title: 'Chronic Disease',
        description: 'Patient has chronic diseases (diabetes, hypertension, etc.)',
        icon: Icons.monitor_heart_outlined,
        color: const Color(0xFFFB8C00),
        recommendation: 'Chronic conditions require medical evaluation before blood donation.',
      ));
    }

    if (responses['traveled_malaria_area'] == true) {
      risks.add(RiskFactor(
        title: 'Malaria Risk Travel',
        description: 'Patient traveled to malaria-prone areas in the last 12 months',
        icon: Icons.flight_takeoff_outlined,
        color: const Color(0xFF5E35B1),
        recommendation: 'Wait 12 months after returning from malaria-prone areas.',
      ));
    }

    return risks;
  }

  void _showMedicalWarningDialog(List<RiskFactor> riskFactors, Map<String, dynamic> quizResponses) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        title: null,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD32F2F),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Medical Risk Factors Detected',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD32F2F),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Based on your responses, we found ${riskFactors.length} risk factor(s) that may affect blood donation.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Risk factors list
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              constraints: const BoxConstraints(maxHeight: 250),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: riskFactors.map((risk) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: risk.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: risk.color.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(risk.icon, size: 18, color: risk.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  risk.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: risk.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            risk.recommendation,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),

            // Disclaimer
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please consult with a healthcare professional for proper medical evaluation.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[900],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Go Back',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(
                          context,
                          '/blood-request-form',
                          arguments: quizResponses,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'I Understand, Continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class QuizQuestion {
  final String id;
  final String question;
  final IconData icon;
  final Color color;
  final ValueChanged<bool> onChanged;
  final bool Function() getValue;

  QuizQuestion({
    required this.id,
    required this.question,
    required this.icon,
    required this.color,
    required this.onChanged,
    required this.getValue,
  });
}

class RiskFactor {
  final String title;
  final String description;
  final String recommendation;
  final IconData icon;
  final Color color;

  RiskFactor({
    required this.title,
    required this.description,
    required this.recommendation,
    required this.icon,
    required this.color,
  });
}
