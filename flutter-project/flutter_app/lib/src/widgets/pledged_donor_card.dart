import 'package:flutter/material.dart';
import '../models/donor_pledge.dart';
import '../theme/app_theme.dart';
import '../app_routes.dart';
import '../services/firebase_chat_service.dart';
import '../models/chat_conversation.dart';
import '../screens/chat/chat_conversation_screen.dart';

/// Card widget displaying a pledged donor's information
class PledgedDonorCard extends StatelessWidget {
  final DonorPledge pledge;
  final VoidCallback? onCancel;
  final VoidCallback? onComplete;
  final String? requestId;
  final String? currentUserId;
  final bool isRequestCreator;
  final bool isCompleting;

  const PledgedDonorCard({
    super.key,
    required this.pledge,
    this.onCancel,
    this.onComplete,
    this.requestId,
    this.currentUserId,
    this.isRequestCreator = false,
    this.isCompleting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pledge.status == 'donated'
              ? AppColors.online
              : AppColors.softPink,
          width: pledge.status == 'donated' ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with donor info and status
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.softPink.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    pledge.donorName != null
                        ? _getInitials(pledge.donorName!)
                        : '?',
                    style: AppTypography.h3.copyWith(
                      color: AppColors.primary,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Donor info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pledge.donorName ?? 'Anonymous Donor',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _buildBloodTypeChip(pledge.bloodGroup ?? '?'),
                        const SizedBox(width: 8),
                        Text(
                          '${pledge.unitsPledged} ${pledge.unitsPledged == 1 ? 'unit' : 'units'} pledged',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status badge
              _buildStatusBadge(pledge.status),
            ],
          ),
          const SizedBox(height: 12),

          // Preferred date and time
          if (pledge.preferredDate != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Can donate: ${_formatPreferredDate(pledge.preferredDate!)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Note
          if (pledge.note != null && pledge.note!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pledge.note!,
                      style: AppTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Action buttons
          Row(
            children: [
              // Chat button - Only show to patient (request creator), NOT to donor viewing their own pledge
              if (isRequestCreator) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openChat(context),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],

              // Complete button (patient only, for pledged/accepted pledges)
              if (isRequestCreator && onComplete != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isCompleting ? null : onComplete,
                    icon: isCompleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle, size: 18),
                    label: Text(isCompleting ? 'Completing...' : 'Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.online,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],

              // Cancel button (donor only, for pledged status - NOT shown to patients)
              if (!isRequestCreator && pledge.status == 'pledged' && onCancel != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBloodTypeChip(String bloodType) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🩸',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            bloodType,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status) {
      case 'pledged':
        bgColor = AppColors.primary.withOpacity(0.1);
        textColor = AppColors.primary;
        icon = Icons.handshake;
        label = 'Pledged';
        break;
      case 'accepted':
        bgColor = AppColors.online.withOpacity(0.1);
        textColor = AppColors.online;
        icon = Icons.check_circle_outline;
        label = 'Accepted';
        break;
      case 'donated':
        bgColor = AppColors.online.withOpacity(0.15);
        textColor = AppColors.online;
        icon = Icons.verified;
        label = 'Donated';
        break;
      case 'cancelled':
        bgColor = AppColors.textSecondary.withOpacity(0.1);
        textColor = AppColors.textSecondary;
        icon = Icons.cancel;
        label = 'Cancelled';
        break;
      default:
        bgColor = AppColors.border;
        textColor = AppColors.textSecondary;
        icon = Icons.help_outline;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  String _formatPreferredDate(String preferredDate) {
    try {
      // Try parsing with time (YYYY-MM-DD HH:MM format)
      final dateTimeWithTime = RegExp(r'^(\d{4})-(\d{2})-(\d{2})\s(\d{2}):(\d{2})$');
      final match = dateTimeWithTime.firstMatch(preferredDate);

      if (match != null) {
        final day = match.group(3);
        final month = match.group(2);
        final year = match.group(1);
        final hour = match.group(4);
        final minute = match.group(5);
        // Format: DD/MM/YYYY at HH:MM
        return '$day/$month/$year at $hour:$minute';
      }

      // If no time, return just the date
      final parts = preferredDate.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }

      return preferredDate;
    } catch (e) {
      return preferredDate;
    }
  }

  void _openChat(BuildContext context) async {
    // Check if donor ID exists
    if (pledge.donor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donor information not available'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      if (context.mounted) {
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Initialize Firebase
      await FirebaseChatService.initialize();

      // Get current user ID
      final currentUserId = await FirebaseChatService.instance.getCurrentUserId();
      if (currentUserId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login to chat'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Create or get conversation
      // Current user (patient) chats with donor
      final conversation = await FirebaseChatService.instance.getOrCreateConversation(
        requestId: pledge.bloodRequest,
        patientId: currentUserId, // Current user is patient
        patientName: pledge.patientName ?? 'Patient',
        donorId: pledge.donor!, // The pledged donor
        donorName: pledge.donorName ?? 'Donor',
      );

      // Navigate to chat screen
      if (context.mounted) {
        // Remove loading SnackBar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(
              conversation: conversation,
              currentUserId: currentUserId,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirebaseChatService.getFirebaseErrorMessage(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }
}

/// Widget for displaying "more donors needed" placeholder
class DonorNeededCard extends StatelessWidget {
  final int count;

  const DonorNeededCard({
    super.key,
    this.count = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softPink.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.softPink,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.softPink.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Icon(
                Icons.person_add,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count more ${count == 1 ? 'donor' : 'donors'} needed',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Help save a life by donating',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.favorite_border,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
