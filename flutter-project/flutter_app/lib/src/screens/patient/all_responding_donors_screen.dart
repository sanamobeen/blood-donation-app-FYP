import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bottom_navigation_bar.dart';
import '../chat/chat_conversation_screen.dart';
import '../../services/firebase_chat_service.dart';
import '../../providers/role_provider.dart';
import 'package:provider/provider.dart';

/// All Responding Donors Screen
/// Shows all responding donors across all blood requests for a patient
class AllRespondingDonorsScreen extends StatefulWidget {
  const AllRespondingDonorsScreen({super.key});

  @override
  State<AllRespondingDonorsScreen> createState() => _AllRespondingDonorsScreenState();
}

class _AllRespondingDonorsScreenState extends State<AllRespondingDonorsScreen> {
  List<Map<String, dynamic>> _respondingDonors = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _totalDonorsCount = 0;
  bool _isAcceptingPledge = false;

  @override
  void initState() {
    super.initState();
    _loadRespondingDonors();
  }

  Future<void> _loadRespondingDonors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _respondingDonors = [];
    });

    try {
      final result = await ApiService.getRespondingDonorsForPatient();

      if (result['success'] == true && mounted) {
        final donors = result['donors'] as List? ?? [];
        final summary = result['summary'] as Map<String, dynamic>? ?? {};

        setState(() {
          _respondingDonors = donors.map((d) => d as Map<String, dynamic>).toList();
          _totalDonorsCount = summary['total_donors'] as int? ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _respondingDonors = [];
          _totalDonorsCount = 0;
          _isLoading = false;
          _errorMessage = result['message'] ?? 'Failed to load responding donors';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _respondingDonors = [];
          _totalDonorsCount = 0;
          _isLoading = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  Future<void> _acceptPledge(Map<String, dynamic> donorData) async {
    // Prevent double clicks
    if (_isAcceptingPledge) {
      return;
    }

    try {
      final donor = donorData['donor'] as Map<String, dynamic>;
      final requestId = donorData['request_id'] as String;
      final pledgeId = donorData['pledge_id'] as String;

      if (requestId.isEmpty || pledgeId.isEmpty) {
        throw Exception('Invalid request ID or pledge ID');
      }

      setState(() {
        _isAcceptingPledge = true;
      });

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Accepting pledge...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Call the accept pledge API
      final response = await ApiService.acceptPledge(
        requestId: requestId,
        pledgeId: pledgeId,
      );

      if (mounted) {
        if (response['success'] == true) {
          // Refresh the responding donors list
          await _loadRespondingDonors();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pledge accepted! You can now chat with the donor.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Check if error is about already confirmed pledge
          final message = response['message']?.toString() ?? 'Failed to accept pledge';

          if (message.contains('Cannot accept pledge') || message.contains('already')) {
            // Refresh to show current state
            await _loadRespondingDonors();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This pledge has already been accepted.'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAcceptingPledge = false;
        });
      }
    }
  }

  Future<void> _openChatWithDonor(Map<String, dynamic> donorData) async {
    try {
      final donor = donorData['donor'] as Map<String, dynamic>;
      final requestId = donorData['request_id'] as String;
      final donorId = donor['id'] as String;
      final donorName = donor['name'] as String? ?? 'Donor';
      final patientName = donorData['patient_name'] as String? ?? 'Patient';

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Opening chat...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get current user ID
      final profile = await ApiService.getProfile();
      if (profile['success'] != true) {
        throw Exception('Failed to get user profile');
      }

      final patientId = profile['data']['user']?['id']?.toString();
      if (patientId == null) {
        throw Exception('User ID not found');
      }

      // Initialize Firebase chat service
      await FirebaseChatService.initialize();

      // Get or create conversation
      final conversation = await FirebaseChatService.instance.getOrCreateConversation(
        requestId: requestId,
        patientId: patientId,
        patientName: patientName,
        donorId: donorId,
        donorName: donorName,
      );

      if (mounted) {
        // Navigate to chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(
              conversation: conversation,
              currentUserId: patientId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleProvider = Provider.of<RoleProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Responding Donors'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? _buildErrorView()
              : _respondingDonors.isEmpty
                  ? _buildEmptyView()
                  : _buildDonorsList(),
      bottomNavigationBar: roleProvider.isPatient
          ? UnifiedBottomNavigationBar(
              selectedIndex: 0, // Home index
              onItemTapped: (index) {
                switch (index) {
                  case 0: // Home
                    Navigator.pop(context);
                    break;
                  case 1: // Requests
                    Navigator.popAndPushNamed(context, '/my-requests');
                    break;
                  case 2: // Map
                    Navigator.popAndPushNamed(context, '/find-donors');
                    break;
                  case 3: // Chat
                    Navigator.popAndPushNamed(context, '/messages');
                    break;
                  case 4: // Profile
                    Navigator.popAndPushNamed(context, '/settings');
                    break;
                }
              },
            )
          : null,
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadRespondingDonors,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No responding donors yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Donors who respond to your requests will appear here',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonorsList() {
    return Column(
      children: [
        // Summary header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_totalDonorsCount donor${_totalDonorsCount > 1 ? 's' : ''} responding',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'View and manage all responding donors',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Donors list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _respondingDonors.length,
            itemBuilder: (context, index) {
              return _buildDonorCard(_respondingDonors[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDonorCard(Map<String, dynamic> donorData) {
    final donor = donorData['donor'] as Map<String, dynamic>;
    final pledge = donorData['pledge'] as Map<String, dynamic>;

    // Get status color and icon
    Color statusColor;
    IconData statusIcon;
    String statusLabel = pledge['status_display'] as String? ?? 'Unknown';

    switch (pledge['status'] as String? ?? '') {
      case 'pledged':
        statusColor = Colors.orange;
        statusIcon = Icons.volunteer_activism;
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'on_the_way':
        statusColor = Colors.blue;
        statusIcon = Icons.directions_walk;
        break;
      case 'arrived':
      case 'ready':
        statusColor = Colors.purple;
        statusIcon = Icons.location_on;
        break;
      case 'completed':
        statusColor = AppColors.primary;
        statusIcon = Icons.favorite;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    // Parse preferred date and time from note
    final note = pledge['note'] as String? ?? '';
    String? preferredDateTime;
    String displayNote = note;

    // Try to match "Preferred time: HH:MM AM/PM" (12-hour format) first
    final timeMatch12 = RegExp(r'Preferred time: (\d{1,2}:\d{2} [AP]M)', caseSensitive: false).firstMatch(note);
    if (timeMatch12 != null) {
      preferredDateTime = timeMatch12.group(1);
      // Remove the time line from the note for cleaner display
      displayNote = note.replaceAll(RegExp(r'Preferred time: \d{1,2}:\d{2} [AP]M', caseSensitive: false), '').trim();
    } else {
      // Fallback to 24-hour format "Preferred time: HH:MM" (for older pledges)
      final timeMatch24 = RegExp(r'Preferred time: (\d{2}:\d{2})').firstMatch(note);
      if (timeMatch24 != null) {
        final timeStr = timeMatch24.group(1)!;
        // Convert 24-hour format to 12-hour format with AM/PM
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour < 12 ? 'AM' : 'PM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        preferredDateTime = '${displayHour.toString().padLeft(2, '0')}:$minute $period';

        // Remove the time line from the note for cleaner display
        displayNote = note.replaceAll(RegExp(r'Preferred time: \d{2}:\d{2}'), '').trim();
      }
    }

    // Clean up any double newlines left after removing time
    if (displayNote.startsWith('\n\n')) {
      displayNote = displayNote.substring(2);
    }
    if (displayNote.endsWith('\n\n')) {
      displayNote = displayNote.substring(0, displayNote.length - 2);
    }

    // Format preferred date if available
    String formattedDate = '';
    if (pledge['preferred_date'] != null) {
      try {
        final dateStr = pledge['preferred_date'] as String;
        final date = DateTime.parse(dateStr);
        formattedDate = '${date.day}/${date.month}/${date.year}';
        if (preferredDateTime != null) {
          formattedDate += ' at $preferredDateTime';
        }
      } catch (e) {
        formattedDate = pledge['preferred_date'] as String? ?? '';
      }
    } else if (preferredDateTime != null) {
      formattedDate = preferredDateTime;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pledge['status'] == 'confirmed'
              ? Colors.green.withOpacity(0.3)
              : AppColors.border,
          width: pledge['status'] == 'confirmed' ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Donor info row
          Row(
            children: [
              // Blood group badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  donor['blood_group'] as String? ?? '--',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Donor name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donor['name'] as String? ?? 'Unknown Donor',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (donor['city'] != null)
                      Text(
                        donor['city'] as String? ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Preferred date/time row
          if (formattedDate.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Preferred: $formattedDate',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          if (formattedDate.isNotEmpty && displayNote.isNotEmpty)
            const SizedBox(height: 8),

          // Pledge note (excluding time)
          if (displayNote.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softPink.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayNote,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Action buttons
          if (pledge['can_accept'] as bool? ?? false)
            // Show accept button prominently on its own row when available
            Column(
              children: [
                // Accept button (full width)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptPledge(donorData),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept Pledge'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Secondary actions (Call and Chat)
                Row(
                  children: [
                    // Call button
                    if (donor['phone'] != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO: Implement call functionality
                          },
                          icon: const Icon(Icons.call, size: 16),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    if (donor['phone'] != null) const SizedBox(width: 8),
                    // Chat button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openChatWithDonor(donorData),
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text('Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            // Show Call and Chat buttons in one row when accept is not available
            Row(
              children: [
                // Call button
                if (donor['phone'] != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement call functionality
                      },
                      icon: const Icon(Icons.call, size: 16),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (donor['phone'] != null) const SizedBox(width: 8),
                // Chat button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openChatWithDonor(donorData),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
