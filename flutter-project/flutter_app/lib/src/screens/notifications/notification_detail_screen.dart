import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../app_routes.dart';
import '../../services/api_service.dart';

/// Notification Detail Screen
/// Shows full details of a single notification with professional UI
class NotificationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> notification;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
  });

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  bool _isRead = false;
  bool _isDeleting = false;
  bool _isProcessing = false; // For accept/reject actions
  String? _sosIdToNavigate; // Store SOS ID for navigation
  String? _responseId; // Store response ID for accept/reject

  @override
  void initState() {
    super.initState();
    _isRead = widget.notification['is_read'] as bool? ?? false;

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 0.1, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'blood_request_match':
      case 'urgent_request':
        return Icons.bloodtype_rounded;
      case 'donation_reminder':
        return Icons.water_drop;
      case 'thank_you':
      case 'donation_completed':
        return Icons.favorite_rounded;
      case 'new_request':
        return Icons.person_add_rounded;
      case 'message_received':
        return Icons.chat_bubble_rounded;
      case 'sos_alert':
        return Icons.emergency_rounded;
      case 'sos_response':
        return Icons.volunteer_activism_rounded;
      case 'sos_response_accepted':
        return Icons.check_circle_rounded;
      case 'sos_response_rejected':
        return Icons.info_outline_rounded;
      case 'donor_on_my_way':
        return Icons.directions_car_rounded;
      case 'external_pledge':
      case 'new_pledge':
        return Icons.volunteer_activism_rounded;
      case 'pledge_confirmed':
        return Icons.check_circle_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'sos_alert':
      case 'urgent_request':
      case 'external_pledge':
      case 'new_pledge':
      case 'pledge_confirmed':
      case 'sos_response':
        return const Color(0xFFD62828);
      case 'sos_response_accepted':
      case 'donation_completed':
      case 'thank_you':
        return const Color(0xFF2B9348);
      case 'sos_response_rejected':
        return Colors.grey;
      case 'donor_on_my_way':
        return const Color(0xFF2196F3);
      case 'blood_request_match':
        return const Color(0xFFE85D04);
      case 'message_received':
        return const Color(0xFF0077B6);
      default:
        return AppColors.primary;
    }
  }

  String _getNotificationTypeLabel(String? type) {
    switch (type) {
      case 'blood_request_match':
        return 'Blood Request Match';
      case 'urgent_request':
        return 'Urgent Request';
      case 'donation_reminder':
        return 'Donation Reminder';
      case 'thank_you':
        return 'Thank You';
      case 'donation_completed':
        return 'Donation Completed';
      case 'new_request':
        return 'New Request';
      case 'message_received':
        return 'New Message';
      case 'sos_alert':
        return 'SOS Alert';
      case 'sos_response':
        return 'SOS - Donor Response';
      case 'sos_response_accepted':
        return 'Response Accepted';
      case 'sos_response_rejected':
        return 'Response Not Selected';
      case 'donor_on_my_way':
        return 'Donor On The Way';
      case 'external_pledge':
        return 'Blood Pledge Received';
      case 'new_pledge':
        return 'Blood Pledge Received';
      case 'pledge_confirmed':
        return 'Pledge Confirmed';
      default:
        return 'Notification';
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final dateTime = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        final hour = dateTime.hour.toString().padLeft(2, '0');
        final minute = dateTime.minute.toString().padLeft(2, '0');
        return 'Today at $hour:$minute';
      } else if (difference.inDays == 1) {
        final hour = dateTime.hour.toString().padLeft(2, '0');
        final minute = dateTime.minute.toString().padLeft(2, '0');
        return 'Yesterday at $hour:$minute';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        final day = dateTime.day.toString().padLeft(2, '0');
        final month = dateTime.month.toString().padLeft(2, '0');
        final year = dateTime.year;
        final hour = dateTime.hour.toString().padLeft(2, '0');
        final minute = dateTime.minute.toString().padLeft(2, '0');
        return '$day/$month/$year at $hour:$minute';
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _handleDelete() async {
    setState(() {
      _isDeleting = true;
    });

    // Wait a bit for animation
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      Navigator.pop(context, 'delete');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll(RegExp(r'[^\d+]'), ''),
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone call')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.notification['type'] as String?;
    final color = _getNotificationColor(type);
    final icon = _getNotificationIcon(type);
    final typeLabel = _getNotificationTypeLabel(type);
    final title = widget.notification['title'] as String? ?? 'Notification';
    final message = widget.notification['message'] as String? ?? '';
    final timestamp = _formatTimestamp(widget.notification['created_at'] as String?);
    final data = widget.notification['data'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value * 100),
              child: child,
            ),
          );
        },
        child: Column(
          children: [
            // Header
            _buildHeader(color, icon, typeLabel),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Timestamp row
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timestamp,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _isRead
                                  ? Colors.grey.shade200
                                  : color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isRead
                                      ? Icons.check_circle_outline
                                      : Icons.mark_email_read,
                                  size: 14,
                                  color: _isRead
                                      ? Colors.grey.shade600
                                      : color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isRead ? 'Read' : 'Unread',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _isRead
                                        ? Colors.grey.shade600
                                        : color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Message card
                      _buildMessageCard(message, color),
                      const SizedBox(height: 24),

                      // Location card if present (for pledged donors)
                      if (_hasLocationData(data))
                        _buildLocationCard(data, color),

                      // Action button if applicable
                      if (_hasAction(type))
                        _buildActionButton(color, type, data),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color color, IconData icon, String typeLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Back button
            _buildHeaderButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context, _isRead),
            ),

            const SizedBox(width: 16),

            // Notification icon with label
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Notification Details',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Delete button
            _buildHeaderButton(
              icon: Icons.delete_outline_rounded,
              color: Colors.red,
              backgroundColor: Colors.red.withOpacity(0.1),
              onTap: _isDeleting ? null : _handleDelete,
              isLoading: _isDeleting,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback? onTap,
    Color color = AppColors.primary,
    Color? backgroundColor,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.softPink.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              )
            : Icon(
                icon,
                color: color,
                size: 22,
              ),
      ),
    );
  }

  Widget _buildMessageCard(String message, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.mail_outline_rounded,
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Message',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalData(Map<String, dynamic> data, Color color) {
    final filteredData = data.entries
        .where((entry) =>
            entry.key != 'notification_id' &&
            entry.key != 'id' &&
            entry.value != null &&
            entry.value.toString().isNotEmpty)
        .toList();

    if (filteredData.isEmpty) return const SizedBox.shrink();

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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: filteredData.asMap().entries.map((entry) {
          final index = entry.key;
          final dataEntry = entry.value;
          final isLast = index == filteredData.length - 1;

          return Column(
            children: [
              _buildDataRow(dataEntry, color),
              if (!isLast) ...[
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: AppColors.border.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDataRow(MapEntry<String, dynamic> dataEntry, Color color) {
    final label = _formatKey(dataEntry.key);
    final value = dataEntry.value.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    return key
        .split('_')
        .map((word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  bool _hasLocationData(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data.containsKey('donor_name') ||
        data.containsKey('donor_phone') ||
        data.containsKey('patient_name') ||
        data.containsKey('patient_phone') ||
        data.containsKey('blood_group') ||
        data.containsKey('location') ||
        data.containsKey('address') ||
        data.containsKey('city') ||
        data.containsKey('distance') ||
        data.containsKey('hospital_name') ||
        data.containsKey('responder_name') ||
        data.containsKey('responder_email') ||
        data.containsKey('responder_blood_type') ||
        data.containsKey('estimated_arrival_minutes');
  }

  Widget _buildLocationCard(Map<String, dynamic>? data, Color color) {
    if (data == null) return const SizedBox.shrink();

    // Get data for both donor and patient
    final donorName = data['donor_name'] as String?;
    final donorPhone = data['donor_phone'] as String?;
    final patientName = data['patient_name'] as String?;
    final patientPhone = data['patient_phone'] as String?;
    final location = data['location'] as String? ?? data['address'] as String?;
    final city = data['city'] as String?;
    final hospitalName = data['hospital_name'] as String?;
    final distance = data['distance'] as String?;
    final bloodGroup = data['blood_group'] as String?;
    final pledgeId = data['pledge_id'] as String?;
    final unitsPledged = data['units_pledged'] as int?;
    final conversationId = data['conversation_id'] as String?;
    final unitsNeeded = data['units_needed'] as int?;

    // SOS responder data
    final responderName = data['responder_name'] as String?;
    final responderEmail = data['responder_email'] as String?;
    final responderBloodType = data['responder_blood_type'] as String?;
    final etaMinutes = data['estimated_arrival_minutes'] as int?;
    final note = data['note'] as String?;

    // Determine if this is SOS responder info, donor info, or patient info
    final isSosResponder = responderName != null || responderEmail != null;
    final isPatientInfo = patientName != null || patientPhone != null;

    // Use appropriate display values
    final displayName = isSosResponder
        ? responderName
        : (isPatientInfo ? patientName : donorName);
    final displayPhone = isSosResponder ? null : (isPatientInfo ? patientPhone : donorPhone);
    final displayBloodGroup = isSosResponder ? responderBloodType : bloodGroup;
    final infoType = isSosResponder ? 'Donor Response' : (isPatientInfo ? 'Patient Information' : 'Donor Information');
    final icon = isSosResponder ? Icons.volunteer_activism_rounded : (isPatientInfo ? Icons.person_rounded : Icons.volunteer_activism_rounded);

    // Check if there's any data to display
    if (displayName == null &&
        displayPhone == null &&
        location == null &&
        hospitalName == null &&
        distance == null &&
        displayBloodGroup == null &&
        etaMinutes == null &&
        note == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient background
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.15),
                  color.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        infoType,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (displayName != null)
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (bloodGroup != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      bloodGroup,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Information rows
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Blood Group (show first if available)
                if (bloodGroup != null) ...[
                  _buildDetailRow(
                    icon: Icons.bloodtype_rounded,
                    label: 'Blood Group',
                    value: bloodGroup,
                    color: color,
                  ),
                  const SizedBox(height: 16),
                ],

                // ETA for SOS responders
                if (etaMinutes != null) ...[
                  _buildDetailRow(
                    icon: Icons.access_time_rounded,
                    label: 'Estimated Arrival',
                    value: '$etaMinutes minutes',
                    color: color,
                  ),
                  const SizedBox(height: 16),
                ],

                // Note from responder
                if (note != null && note.isNotEmpty) ...[
                  _buildDetailRow(
                    icon: Icons.note_rounded,
                    label: 'Note',
                    value: note,
                    color: color,
                  ),
                  const SizedBox(height: 16),
                ],

                // Units Pledged
                if (unitsPledged != null) ...[
                  _buildDetailRow(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'Units Pledged',
                    value: '$unitsPledged ${unitsPledged == 1 ? 'unit' : 'units'}',
                    color: color,
                  ),
                  const SizedBox(height: 16),
                ],

                // Phone number with call button
                if (displayPhone != null) ...[
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.phone_rounded,
                          size: 22,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contact Number',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayPhone ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => _makePhoneCall(displayPhone ?? ''),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.call_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Call',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Location/City
                if (location != null || city != null) ...[
                  _buildDetailRow(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    value: city != null
                        ? '${(location ?? '').isNotEmpty ? '$location, ' : ''}$city'
                        : location ?? city ?? '',
                    color: color,
                  ),
                  const SizedBox(height: 16),
                ],

                // Distance if available
                if (distance != null) ...[
                  _buildDetailRow(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: distance,
                    color: color,
                  ),
                ],

                // Hospital if available
                if (hospitalName != null) ...[
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.local_hospital_rounded,
                    label: 'Hospital',
                    value: hospitalName,
                    color: color,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 22,
            color: color,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(Color color, String? type, Map<String, dynamic>? data) {
    // For SOS response notifications, show accept/reject buttons ONLY for patient
    // Check if this notification contains responder data (meaning it's sent TO patient ABOUT a donor)
    if (type == 'sos_response') {
      final sosId = data?['sos_id'] as String?;
      final responseId = data?['response_id'] as String?;
      final responderName = data?['responder_name'] as String?;
      final responderEmail = data?['responder_email'] as String?;

      // Only show accept/decline buttons if there's responder data (for patient only)
      // If no responder data, this might be for the donor - show NO action buttons
      if (responderName == null && responderEmail == null) {
        return const SizedBox.shrink();
      }

      // This is for the patient - show accept/decline buttons
      if (sosId != null && responseId != null) {
        _sosIdToNavigate = sosId;
        _responseId = responseId;
      }

      return Column(
        children: [
          // Accept Button
          Container(
            width: double.infinity,
            height: 56,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2B9348), // Green for accept
                  const Color(0xFF2B9348).withOpacity(0.8),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2B9348).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : () => _acceptResponder(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Accept Donor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.check_rounded, size: 20),
                      ],
                    ),
            ),
          ),

          // Reject Button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade600,
                  Colors.grey.shade700,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : () => _rejectResponder(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Decline',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(Icons.close_rounded, size: 20),
                ],
              ),
            ),
          ),

          // View SOS Button
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 1.5),
            ),
            child: OutlinedButton(
              onPressed: () {
                if (_sosIdToNavigate != null) {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.sosDetail,
                    arguments: {'sosId': _sosIdToNavigate},
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'View All Responders',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.people_outline_rounded, size: 20, color: color),
                ],
              ),
            ),
          ),
        ],
      );
    }

    String buttonText;
    IconData actionIcon;
    String route;

    switch (type) {
      case 'blood_request_match':
      case 'urgent_request':
      case 'new_request':
      case 'external_pledge':
      case 'new_pledge':
        buttonText = 'View Blood Request';
        actionIcon = Icons.bloodtype_rounded;
        final requestId = data?['request_id'] as String? ?? data?['pledge_id'] as String?;
        route = requestId != null ? '/blood-request-detail/$requestId' : '';
        break;
      case 'pledge_confirmed':
        // Check if there's a conversation available
        final conversationId = data?['conversation_id'] as String?;
        if (conversationId != null && conversationId.isNotEmpty) {
          buttonText = 'Open Chat';
          actionIcon = Icons.chat_bubble_rounded;
          route = '/chat/$conversationId';
        } else {
          buttonText = 'View Blood Request';
          actionIcon = Icons.bloodtype_rounded;
          final requestId = data?['request_id'] as String?;
          route = requestId != null ? '/blood-request-detail/$requestId' : '';
        }
        break;
      case 'message_received':
        buttonText = 'Open Conversation';
        actionIcon = Icons.chat_bubble_rounded;
        route = '/messages';
        break;
      case 'sos_alert':
        buttonText = 'View SOS Alert';
        actionIcon = Icons.emergency_rounded;
        final sosId = data?['sos_id'] as String?;
        route = sosId != null ? '_sos_special' : ''; // Special marker for SOS
        if (sosId != null) {
          _sosIdToNavigate = sosId;
        }
        break;
      case 'sos_response_accepted':
        buttonText = 'View Request Details';
        actionIcon = Icons.location_on_rounded;
        final acceptedSosId = data?['sos_id'] as String?;
        route = acceptedSosId != null ? '_sos_special' : '';
        if (acceptedSosId != null) {
          _sosIdToNavigate = acceptedSosId;
        }
        break;
      case 'donor_on_my_way':
        buttonText = 'View Donor Status';
        actionIcon = Icons.directions_car_rounded;
        final onMyWaySosId = data?['sos_id'] as String?;
        route = onMyWaySosId != null ? '_sos_special' : '';
        if (onMyWaySosId != null) {
          _sosIdToNavigate = onMyWaySosId;
        }
        break;
      case 'sos_response_rejected':
        buttonText = 'View Other Requests';
        actionIcon = Icons.search_rounded;
        final rejectedSosId = data?['sos_id'] as String?;
        route = rejectedSosId != null ? '_sos_special' : '';
        if (rejectedSosId != null) {
          _sosIdToNavigate = rejectedSosId;
        }
        break;
      default:
        return const SizedBox.shrink();
    }

    if (route.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.8),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          // Special handling for SOS alerts with arguments
          if (route == '_sos_special' && _sosIdToNavigate != null) {
            Navigator.pushNamed(
              context,
              AppRoutes.sosDetail,
              arguments: {'sosId': _sosIdToNavigate},
            );
          } else if (route.isNotEmpty) {
            Navigator.pushNamed(context, route);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              buttonText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 12),
            Icon(actionIcon, size: 20),
          ],
        ),
      ),
    );
  }

  bool _hasAction(String? type) {
    return type == 'blood_request_match' ||
        type == 'urgent_request' ||
        type == 'new_request' ||
        type == 'external_pledge' ||
        type == 'new_pledge' ||
        type == 'pledge_confirmed' ||
        type == 'message_received' ||
        type == 'sos_alert' ||
        type == 'sos_response' ||
        type == 'sos_response_accepted' ||
        type == 'donor_on_my_way';
  }

  /// Accept responder's offer
  Future<void> _acceptResponder() async {
    if (_sosIdToNavigate == null || _responseId == null) {
      _showError('Missing SOS or response ID');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await ApiService.acceptSosResponse(
        sosId: _sosIdToNavigate!,
        responseId: _responseId!,
      );

      if (mounted) {
        setState(() => _isProcessing = false);

        if (result['success'] == true) {
          _showSuccessDialog('Donor Accepted',
              'The donor has been notified and is on their way to help!');
        } else {
          _showError(result['message'] as String? ?? 'Failed to accept donor');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Network error: $e');
      }
    }
  }

  /// Reject responder's offer
  Future<void> _rejectResponder() async {
    if (_sosIdToNavigate == null || _responseId == null) {
      _showError('Missing SOS or response ID');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Donor?'),
        content: const Text(
          'Are you sure you want to decline this donor? They will be notified that you are unable to accept their offer at this time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final result = await ApiService.rejectSosResponse(
        sosId: _sosIdToNavigate!,
        responseId: _responseId!,
      );

      if (mounted) {
        setState(() => _isProcessing = false);

        if (result['success'] == true) {
          _showSuccessDialog('Donor Declined',
              'The donor has been notified. You can view other responders.');
        } else {
          _showError(result['message'] as String? ?? 'Failed to decline donor');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Network error: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Return to notifications list with refresh
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
