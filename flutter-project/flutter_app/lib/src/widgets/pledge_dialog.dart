import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/firebase_chat_service.dart';
import '../models/chat_conversation.dart';
import '../screens/chat/chat_conversation_screen.dart';

/// Dialog for donors to pledge to donate blood for a request
class PledgeDialog extends StatefulWidget {
  final String requestId;
  final String patientName;
  final String bloodGroup;
  final int unitsNeeded;
  final String hospitalName;
  final String requiredBy;
  final String? patientId; // Added patient ID for chat creation
  final VoidCallback onPledgeCreated;

  const PledgeDialog({
    super.key,
    required this.requestId,
    required this.patientName,
    required this.bloodGroup,
    required this.unitsNeeded,
    required this.hospitalName,
    required this.requiredBy,
    this.patientId,
    required this.onPledgeCreated,
  });

  @override
  State<PledgeDialog> createState() => _PledgeDialogState();
}

class _PledgeDialogState extends State<PledgeDialog> {
  final _noteController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<String?> _getCurrentUserId() async {
    try {
      final profile = await ApiService.getProfile();
      if (profile['success'] == true) {
        return profile['data']['user']?['id']?.toString();
      }
    } catch (e) {
    }
    return null;
  }

  Future<String> _getCurrentUserName() async {
    try {
      final profile = await ApiService.getProfile();
      if (profile['success'] == true) {
        return profile['data']['user']?['full_name']?.toString() ?? 'Donor';
      }
    } catch (e) {
    }
    return 'Donor';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      // After selecting date, automatically show time picker
      _selectTime();
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submitPledge() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preferred donation date')),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preferred donation time')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Format date as YYYY-MM-DD for API (backend uses DateField, not DateTime)
    final formattedDate = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

    // Note: Time is collected for user reference but backend only stores date
    final formattedTime = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    // Include time in the note for the patient to see
    final noteWithTime = _noteController.text.trim().isEmpty
        ? 'Preferred time: $formattedTime'
        : '${_noteController.text.trim()}\n\nPreferred time: $formattedTime';

    // Call the real API (send only the date, not datetime)
    final response = await ApiService.createPledge(
      requestId: widget.requestId,
      unitsPledged: 1,
      preferredDate: formattedDate,
      note: noteWithTime,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (response['success'] == true) {
        Navigator.of(context).pop();
        widget.onPledgeCreated();

        // Create chat conversation and navigate to it
        try {
          await FirebaseChatService.initialize();

          final donorId = await _getCurrentUserId();
          if (donorId != null && widget.patientId != null) {
            final donorName = await _getCurrentUserName();

            final conversation = await FirebaseChatService.instance.getOrCreateConversation(
              requestId: widget.requestId,
              patientId: widget.patientId!,
              patientName: widget.patientName,
              donorId: donorId,
              donorName: donorName,
            );

            // Send system message
            await FirebaseChatService.instance.sendSystemMessage(
              conversationId: conversation.id,
              text: '🎉 You pledged to donate ${widget.bloodGroup} blood to ${widget.patientName}!',
            );

            // Navigate to chat
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatConversationScreen(
                    conversation: conversation,
                    currentUserId: donorId,
                  ),
                ),
              );
            }
          }
        } catch (e) {
          // Continue even if chat creation fails
        }
      } else {
        // Show error message
        final message = response['message'] ?? 'Failed to create pledge';

        // Close dialog if already pledged (prevent multiple popups)
        if (message.contains('already pledged') || message.contains('already')) {
          Navigator.of(context).pop();
          // Call onPledgeCreated to refresh the UI (since they already have a pledge)
          widget.onPledgeCreated();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.urgencyCritical,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.volunteer_activism,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pledge Your Donation',
                    style: AppTypography.h3.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Blood request summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.softPink.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.softPink),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.patientName,
                    style: AppTypography.h3,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip('🩸 ${widget.bloodGroup}'),
                      const SizedBox(width: 8),
                      _buildInfoChip('${widget.unitsNeeded} units needed'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.hospitalName,
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Required by: ${widget.requiredBy}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Note input
            Text(
              'Add a note for the patient (optional)',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'I can donate in the morning...',
                filled: true,
                fillColor: AppColors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.focus, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Combined Date and Time picker
            Text(
              'When can you donate?',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  border: Border.all(
                    color: _selectedDate != null && _selectedTime != null
                        ? AppColors.focus
                        : AppColors.border,
                    width: _selectedDate != null && _selectedTime != null ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: _selectedDate != null && _selectedTime != null
                          ? AppColors.focus
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDate != null && _selectedTime != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} at ${_formatTime(_selectedTime!)}'
                            : 'Select date and time',
                        style: AppTypography.body.copyWith(
                          color: _selectedDate != null && _selectedTime != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: _selectedDate != null && _selectedTime != null
                          ? AppColors.focus
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTypography.button.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitPledge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : FittedBox(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Confirm Pledge',
                                  style: AppTypography.button,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Show pledge dialog
Future<void> showPledgeDialog({
  required BuildContext context,
  required String requestId,
  required String patientName,
  required String bloodGroup,
  required int unitsNeeded,
  required String hospitalName,
  required String requiredBy,
  String? patientId,
  required VoidCallback onPledgeCreated,
}) {
  return showDialog(
    context: context,
    builder: (context) => PledgeDialog(
      requestId: requestId,
      patientName: patientName,
      bloodGroup: bloodGroup,
      unitsNeeded: unitsNeeded,
      hospitalName: hospitalName,
      requiredBy: requiredBy,
      patientId: patientId,
      onPledgeCreated: onPledgeCreated,
    ),
  );
}
