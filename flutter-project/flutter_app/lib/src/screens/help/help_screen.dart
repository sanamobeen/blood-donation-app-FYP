import 'package:flutter/material.dart';
import '../../app_routes.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FAQItem> _filteredFAQs = [];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _filteredFAQs = faqItems;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFAQs(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFAQs = faqItems;
      } else {
        _filteredFAQs = faqItems
            .where((item) =>
                item.question.toLowerCase().contains(query.toLowerCase()) ||
                item.answer.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      if (category == 'All') {
        _filteredFAQs = faqItems;
      } else {
        _filteredFAQs = faqItems.where((item) => item.category == category).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Help Center'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Search Bar
              _buildSearchBar(),
              const SizedBox(height: 24),

              // Quick Help Actions
              _buildQuickActions(),
              const SizedBox(height: 24),

              // Categories Filter
              _buildCategoryFilter(),
              const SizedBox(height: 16),

              // FAQ Section
              _buildFAQSection(),
              const SizedBox(height: 24),

              // Contact Support
              _buildContactSupport(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for help...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.7),
                  ),
                ),
                onChanged: _filterFAQs,
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _filterFAQs('');
                },
                child: Icon(Icons.clear, color: AppColors.textSecondary, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: SizedBox(
          width: 200,
          child: _QuickActionCard(
            icon: Icons.email_outlined,
            title: 'Email Us',
            subtitle: 'blooddonation@gmail.com',
            onTap: () => _showEmailDialog(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['All', 'Account', 'Requests', 'Donation', 'Technical'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = _selectedCategory == category;

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilterChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (_) => _filterByCategory(category),
                selectedColor: AppColors.primary.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFAQSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_filteredFAQs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'No results found',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: _filteredFAQs.map((faq) => _FAQCard(
                    key: ValueKey('faq_${faq.question}'),
                    faq: faq,
                  )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildContactSupport() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Need More Help?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Our support team is available 24/7 to assist you.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _ContactButton(
              icon: Icons.email,
              label: 'Email Us',
              onTap: () => _showEmailDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('For general inquiries:'),
            SizedBox(height: 4),
            Text(
              'blooddonation@gmail.com',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 16),
            Text('For urgent matters:'),
            SizedBox(height: 4),
            Text(
              'blooddonation@gmail.com',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// FAQ Card Widget
class _FAQCard extends StatefulWidget {
  final FAQItem faq;

  const _FAQCard({super.key, required this.faq});

  @override
  State<_FAQCard> createState() => _FAQCardState();
}

class _FAQCardState extends State<_FAQCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.faq.question,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.faq.answer,
                style: const TextStyle(
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

// Quick Action Card Widget
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.softPink.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Contact Button Widget
class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// FAQ Data Class
class FAQItem {
  final String question;
  final String answer;
  final String category;

  FAQItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}

// FAQ Data
final List<FAQItem> faqItems = [
  // Account Category
  FAQItem(
    question: 'How do I register as a donor?',
    answer: 'To register as a donor, download the Blood Donor app, click "Sign Up", select "Donor" as your role, and complete your profile with your blood type, location, and contact information.',
    category: 'Account',
  ),
  FAQItem(
    question: 'How do I update my profile information?',
    answer: 'Go to Settings > Edit Profile to update your personal information, blood type, location, and profile picture.',
    category: 'Account',
  ),
  FAQItem(
    question: 'How do I delete my account?',
    answer: 'To delete your account, go to Settings > Privacy > Delete Account. Note that this action is irreversible and all your data will be permanently removed.',
    category: 'Account',
  ),

  // Requests Category
  FAQItem(
    question: 'How do I request blood?',
    answer: 'Navigate to the "Requests" section and tap "Create New Request". Fill in the required details including blood type, hospital name, urgency level, and contact information.',
    category: 'Requests',
  ),
  FAQItem(
    question: 'How do I find nearby blood requests?',
    answer: 'Go to "Requests" > "Nearby Requests" to see all pending blood requests in your area. You can filter by blood type and distance.',
    category: 'Requests',
  ),
  FAQItem(
    question: 'What happens after I respond to a request?',
    answer: 'After responding, a chat will be opened between you and the requester. You can coordinate the donation details directly through the chat.',
    category: 'Requests',
  ),

  // Donation Category
  FAQItem(
    question: 'How often can I donate blood?',
    answer: 'Generally, you can donate whole blood every 56 days (8 weeks). For platelets, you can donate more frequently. Always consult with healthcare professionals.',
    category: 'Donation',
  ),
  FAQItem(
    question: 'What are the eligibility requirements for donating blood?',
    answer: 'You must be between 18-65 years old, weigh at least 50kg, be in good health, and meet certain medical criteria. Take our eligibility quiz for detailed information.',
    category: 'Donation',
  ),
  FAQItem(
    question: 'How do I track my donation history?',
    answer: 'Go to "Profile" > "My Donations" to view your complete donation history, including dates, locations, and lives impacted.',
    category: 'Donation',
  ),

  // Technical Category
  FAQItem(
    question: 'I\'m not receiving notifications. What should I do?',
    answer: 'Check your phone settings and ensure Blood Donor has permission to send notifications. Also, verify notification settings in the app under Settings > Preferences > Notifications.',
    category: 'Technical',
  ),
  FAQItem(
    question: 'How do I change my password?',
    answer: 'Go to Settings > Account > Change Password. You\'ll need to enter your current password and then set a new one.',
    category: 'Technical',
  ),
  FAQItem(
    question: 'Is my personal information secure?',
    answer: 'Yes, we use industry-standard encryption and security measures to protect your data. Your medical information is only shared with relevant parties when you initiate a donation request.',
    category: 'Technical',
  ),
  FAQItem(
    question: 'How do I enable location services?',
    answer: 'Go to your phone\'s settings, find Blood Donor, and enable location access. This allows us to show nearby donors and requests.',
    category: 'Technical',
  ),
];
