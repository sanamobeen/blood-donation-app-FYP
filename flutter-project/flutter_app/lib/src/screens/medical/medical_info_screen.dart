import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class MedicalInfoScreen extends StatefulWidget {
  const MedicalInfoScreen({super.key});

  @override
  State<MedicalInfoScreen> createState() => _MedicalInfoScreenState();
}

class _MedicalInfoScreenState extends State<MedicalInfoScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _medicalInfo;
  List<String> _medications = [];
  List<String> _allergies = [];
  List<String> _healthConditions = [];
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _allergyController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMedicalInfo();
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _allergyController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicalInfo() async {
    try {
      // Load user profile which contains basic medical info
      final response = await ApiService.getProfile();
      if (response['success']) {
        setState(() {
          _medicalInfo = response['data']['profile'];
          // Load additional medical info if available
          _medications = List<String>.from(
            _medicalInfo!['medications'] ?? [],
          );
          _allergies = List<String>.from(
            _medicalInfo!['allergies'] ?? [],
          );
          _healthConditions = List<String>.from(
            _medicalInfo!['health_conditions'] ?? [],
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // Use default values if API fails
      setState(() {
        _medicalInfo = {};
        _medications = [];
        _allergies = [];
        _healthConditions = [];
      });
    }
  }

  Future<void> _saveMedicalInfo() async {
    setState(() => _isSaving = true);

    try {
      final response = await ApiService.updateMedicalInfo(
        medications: _medications,
        allergies: _allergies,
        healthConditions: _healthConditions,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['success'] ? 'Medical info updated' : 'Failed to update'),
            backgroundColor: response['success'] ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update medical info'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Medical Information'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading && !_isSaving)
            TextButton(
              onPressed: _saveMedicalInfo,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Blood Type Card
                  _buildBloodTypeCard(),
                  const SizedBox(height: 16),

                  // Eligibility Status
                  _buildEligibilityCard(),
                  const SizedBox(height: 16),

                  // Basic Health Info
                  _buildBasicHealthCard(),
                  const SizedBox(height: 16),

                  // Health Conditions
                  _buildHealthConditionsCard(),
                  const SizedBox(height: 16),

                  // Medications
                  _buildMedicationsCard(),
                  const SizedBox(height: 16),

                  // Allergies
                  _buildAllergiesCard(),
                  const SizedBox(height: 16),

                  // Donation History Summary
                  _buildDonationHistoryCard(),
                  const SizedBox(height: 16),

                  // Emergency Information
                  _buildEmergencyCard(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildBloodTypeCard() {
    final bloodGroup = _medicalInfo?['blood_group'] ?? 'Unknown';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                bloodGroup,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Blood Type',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your blood group is $bloodGroup',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.bloodtype,
            color: Colors.white,
            size: 32,
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityCard() {
    final isEligible = _medicalInfo?['is_eligible'] ?? true;
    final nextEligibleDate = _medicalInfo?['next_eligible_date'];
    final eligibilityReason = _medicalInfo?['eligibility_reason'] ?? 'Check eligibility quiz';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEligible ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEligible ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isEligible ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEligible ? Icons.check_circle : Icons.cancel,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEligible ? 'Eligible to Donate' : 'Not Eligible to Donate',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isEligible ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEligible
                      ? 'You can donate blood now!'
                      : 'Reason: $eligibilityReason',
                  style: TextStyle(
                    fontSize: 13,
                    color: isEligible ? const Color(0xFF388E3C) : const Color(0xFFD32F2F),
                  ),
                ),
                if (!isEligible && nextEligibleDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Next eligible date: ${_formatDate(nextEligibleDate)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFD32F2F),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicHealthCard() {
    final age = _medicalInfo?['age'] ?? 'Not set';
    final weight = _medicalInfo?['weight']?.toString() ?? 'Not set';
    final gender = _medicalInfo?['gender'] ?? 'Not set';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Basic Health Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHealthStat('Age', age is String ? age : '$age yrs'),
              _buildVerticalDivider(),
              _buildHealthStat('Weight', weight is String ? weight : '${weight}kg'),
              _buildVerticalDivider(),
              _buildHealthStat('Gender', gender.toString().split('.').last),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: AppColors.border,
    );
  }

  Widget _buildHealthConditionsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medical_information, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Health Conditions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _buildAddButton(
                onTap: () => _showAddDialog(
                  title: 'Add Health Condition',
                  controller: _conditionController,
                  onAdd: () {
                    setState(() {
                      if (_conditionController.text.trim().isNotEmpty) {
                        _healthConditions.add(_conditionController.text.trim());
                        _conditionController.clear();
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_healthConditions.isEmpty)
            _buildEmptyState('No health conditions recorded')
          else
            ...(_healthConditions.map((condition) => Container(
                  key: ValueKey('health_condition_$condition'),
                  child: _buildListItem(
                    condition,
                    onDelete: () {
                      setState(() => _healthConditions.remove(condition));
                    },
                  ),
                ))),
        ],
      ),
    );
  }

  Widget _buildMedicationsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medication, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Medications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _buildAddButton(
                onTap: () => _showAddDialog(
                  title: 'Add Medication',
                  controller: _medicationController,
                  onAdd: () {
                    setState(() {
                      if (_medicationController.text.trim().isNotEmpty) {
                        _medications.add(_medicationController.text.trim());
                        _medicationController.clear();
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_medications.isEmpty)
            _buildEmptyState('No medications recorded')
          else
            ...(_medications.map((med) => _buildListItem(
                  med,
                  onDelete: () {
                    setState(() => _medications.remove(med));
                  },
                ))),
        ],
      ),
    );
  }

  Widget _buildAllergiesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                'Allergies',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _buildAddButton(
                onTap: () => _showAddDialog(
                  title: 'Add Allergy',
                  controller: _allergyController,
                  onAdd: () {
                    setState(() {
                      if (_allergyController.text.trim().isNotEmpty) {
                        _allergies.add(_allergyController.text.trim());
                        _allergyController.clear();
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_allergies.isEmpty)
            _buildEmptyState('No allergies recorded')
          else
            ...(_allergies.map((allergy) => _buildListItem(
                  allergy,
                  onDelete: () {
                    setState(() => _allergies.remove(allergy));
                  },
                ))),
        ],
      ),
    );
  }

  Widget _buildDonationHistoryCard() {
    final totalDonations = _medicalInfo?['total_donations'] ?? 0;
    final lastDonationDate = _medicalInfo?['last_donation_date'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Donation History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DonationStatCard(
                  icon: Icons.volunteer_activism,
                  label: 'Total Donations',
                  value: '$totalDonations',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DonationStatCard(
                  icon: Icons.calendar_today,
                  label: 'Last Donation',
                  value: lastDonationDate != null
                      ? _formatDate(lastDonationDate)
                      : 'Never',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emergency, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                'Emergency Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'In case of emergency, medical personnel should know:',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _EmergencyInfoItem(
            label: 'Blood Type',
            value: _medicalInfo?['blood_group'] ?? 'Unknown',
          ),
          _EmergencyInfoItem(
            label: 'Allergies',
            value: _allergies.isEmpty ? 'None recorded' : _allergies.join(', '),
          ),
          _EmergencyInfoItem(
            label: 'Medications',
            value: _medications.isEmpty ? 'None recorded' : _medications.join(', '),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.add,
          color: AppColors.primary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildListItem(String text, {required VoidCallback onDelete}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.circle,
              size: 6,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.close,
                size: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  void _showAddDialog({
    required String title,
    required TextEditingController controller,
    required VoidCallback onAdd,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter details...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onAdd();
              Navigator.pop(context);
            },
            child: const Text(
              'Add',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateInput) {
    if (dateInput == null) return 'Not recorded';
    String dateString = dateInput.toString();
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

class _DonationStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DonationStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmergencyInfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _EmergencyInfoItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.orange.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
