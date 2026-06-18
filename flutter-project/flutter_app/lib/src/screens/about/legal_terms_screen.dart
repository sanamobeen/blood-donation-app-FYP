import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class LegalTermsScreen extends StatelessWidget {
  const LegalTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Legal Terms'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Privacy Policy Section
              _buildSection(
                'Privacy Policy',
                [
                  _buildParagraph(
                    'At Blood Donation, we are committed to protecting your privacy and ensuring the security of your personal information.',
                  ),
                  _buildParagraph(
                    'Information We Collect:',
                    isSubheading: true,
                  ),
                  _buildBulletPoint('Personal information (name, email, phone number)'),
                  _buildBulletPoint('Health information (blood type, donation history)'),
                  _buildBulletPoint('Location data (for finding nearby donors)'),
                  _buildBulletPoint('Device information and usage data'),
                  _buildParagraph(
                    'How We Use Your Information:',
                    isSubheading: true,
                  ),
                  _buildBulletPoint('To connect blood donors with recipients'),
                  _buildBulletPoint('To send important notifications and updates'),
                  _buildBulletPoint('To improve our services and user experience'),
                  _buildBulletPoint('To ensure the safety and authenticity of donors'),
                  _buildParagraph(
                    'Data Protection:',
                    isSubheading: true,
                  ),
                  _buildBulletPoint('All data is encrypted and securely stored'),
                  _buildBulletPoint('Health information is only shared with consent'),
                    _buildBulletPoint('We comply with all applicable data protection laws'),
                  _buildBulletPoint('You can request deletion of your data at any time'),
                ],
              ),
              const SizedBox(height: 32),

              // Terms of Service Section
              _buildSection(
                'Terms of Service',
                [
                  _buildParagraph(
                    'By using the Blood Donation app, you agree to these terms of service.',
                  ),
                  _buildParagraph(
                    'User Responsibilities:',
                    isSubheading: true,
                  ),
                  _buildBulletPoint('Provide accurate and truthful health information'),
                  _buildBulletPoint('Respond to donation requests in good faith'),
                  _buildBulletPoint('Respect other users and maintain professional conduct'),
                  _buildBulletPoint('Follow medical guidelines for blood donation eligibility'),
                  _buildParagraph(
                    'Prohibited Activities:',
                    isSubheading: true,
                  ),
                  _buildBulletPoint('False representation as a blood donor'),
                  _buildBulletPoint('Soliciting payments for donations'),
                  _buildBulletPoint('Sharing inappropriate or offensive content'),
                  _buildBulletPoint('Misusing the platform for commercial purposes'),
                  _buildParagraph(
                    'Disclaimer:',
                    isSubheading: true,
                  ),
                  _buildParagraph(
                    'Blood Donation acts as a connecting platform only. We are not responsible for the actual donation process or medical outcomes. Users should consult healthcare professionals for medical advice.',
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // User Rights Section
              _buildSection(
                'User Rights',
                [
                  _buildParagraph(
                    'Right to Access: You can request a copy of your personal data at any time.',
                  ),
                  _buildParagraph(
                    'Right to Rectification: You can correct inaccurate or incomplete data.',
                  ),
                  _buildParagraph(
                    'Right to Erasure: You can request deletion of your personal data.',
                  ),
                  _buildParagraph(
                    'Right to Withdraw Consent: You can withdraw consent for data processing.',
                  ),
                  _buildParagraph(
                    'Right to Complaint: You can file a complaint with data protection authorities.',
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Contact Section
              _buildSection(
                'Contact Us',
                [
                  _buildParagraph(
                    'For any questions about these terms or your privacy, please contact us at:',
                  ),
                  _buildParagraph(
                    'blooddonation@gmail.com',
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Last Updated
              Center(
                child: Text(
                  'Last Updated: January 2025',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildParagraph(
    String text, {
    bool isSubheading = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isSubheading ? 15 : 14,
          fontWeight: isSubheading ? FontWeight.w600 : FontWeight.w400,
          color: color ?? AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
