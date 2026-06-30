import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/bottom_navigation_bar.dart';
import '../../app_routes.dart';

/// Notifications Screen with API integration
class NotificationsScreenApi extends StatefulWidget {
  const NotificationsScreenApi({super.key});

  @override
  State<NotificationsScreenApi> createState() => _NotificationsScreenApiState();
}

class _NotificationsScreenApiState extends State<NotificationsScreenApi> {
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  String? _errorMessage;

  // Notification preferences
  Map<String, bool>? _preferences;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getNotifications();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        final notifications = data['notifications'] as List? ?? [];

        setState(() {
          _notifications = notifications.map((n) => n as Map<String, dynamic>).toList();
          _unreadCount = data['unread_count'] as int? ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] as String? ?? 'Failed to load notifications';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    await ApiService.markNotificationAsRead(notificationId);
    setState(() {
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index]['is_read'] = true;
        if (_unreadCount > 0) _unreadCount--;
      }
    });
  }

  Future<void> _markAllAsRead() async {
    await ApiService.markAllNotificationsAsRead();
    setState(() {
      for (var notification in _notifications) {
        notification['is_read'] = true;
      }
      _unreadCount = 0;
    });
  }

  Future<void> _deleteNotification(String notificationId) async {
    await ApiService.deleteNotification(notificationId);
    setState(() {
      _notifications.removeWhere((n) => n['id'] == notificationId);
    });
  }

  Future<void> _loadPreferences() async {
    final result = await ApiService.getNotificationPreferences();
    if (result['success'] == true && result['data'] != null) {
      setState(() {
        _preferences = Map<String, bool>.from(
          result['data'] as Map? ?? {},
        );
      });
    }
  }

  Future<void> _updatePreference(String key, bool value) async {
    if (_preferences == null) return;

    setState(() {
      _preferences![key] = value;
    });

    await ApiService.updateNotificationPreferences(_preferences!);
  }

  List<Map<String, dynamic>> get _unreadNotifications {
    return _notifications.where((n) => n['is_read'] == false).toList();
  }

  List<Map<String, dynamic>> get _readNotifications {
    return _notifications.where((n) => n['is_read'] == true).toList();
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
      case 'external_pledge':
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
        return Colors.red;
      case 'donation_completed':
      case 'thank_you':
        return Colors.green;
      default:
        return AppColors.primary;
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final dateTime = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Main Content
            Expanded(
              child: _buildContent(),
            ),

            // Bottom Navigation
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.softPink.withOpacity(0.5),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),

          // Title
          Text(
            'Notifications${_unreadCount > 0 ? ' ($_unreadCount)' : ''}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          // Settings icon
          GestureDetector(
            onTap: () {
              _showNotificationSettings();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.softPink.withOpacity(0.5),
              ),
              child: const Icon(
                Icons.settings,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mark all as read button
            if (_unreadCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: const Icon(Icons.mark_email_read, size: 18),
                  label: const Text('Mark all as read'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),

            // Unread Notifications
            if (_unreadNotifications.isNotEmpty) ...[
              _buildSectionHeader('Unread (${_unreadNotifications.length})'),
              const SizedBox(height: 8),
              _buildNotificationsList(_unreadNotifications),
              const SizedBox(height: 16),
            ],

            // Read Notifications
            if (_readNotifications.isNotEmpty) ...[
              _buildSectionHeader('Earlier (${_readNotifications.length})'),
              const SizedBox(height: 8),
              _buildNotificationsList(_readNotifications),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildNotificationsList(List<Map<String, dynamic>> notifications) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: notifications.map((notification) {
          return _NotificationCard(
            notification: notification,
            icon: _getNotificationIcon(notification['type'] as String?),
            color: _getNotificationColor(notification['type'] as String?),
            timestamp: _formatTimestamp(notification['created_at'] as String?),
            onTap: () async {
              // Mark as read before navigating
              await _markAsRead(notification['id'] as String);
              // Navigate to detail screen
              final result = await Navigator.pushNamed(
                context,
                AppRoutes.notificationDetail,
                arguments: notification,
              );
              // Handle delete action from detail screen
              if (result == 'delete') {
                _deleteNotification(notification['id'] as String);
              }
              // Reload notifications to reflect any changes
              _loadNotifications();
            },
            onLongPress: () {
              _showNotificationOptions(notification['id'] as String);
            },
          );
        }).toList(),
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = notification['type'] as String?;
    final data = notification['data'] as Map<String, dynamic>?;

    switch (type) {
      case 'blood_request_match':
      case 'urgent_request':
      case 'new_request':
      case 'external_pledge':
        final requestId = data?['request_id'] as String?;
        if (requestId != null) {
          Navigator.pushNamed(context, '/blood-request-detail/$requestId');
        }
        break;
      case 'message_received':
        Navigator.pushNamed(context, '/messages');
        break;
      case 'sos_alert':
        final sosId = data?['sos_id'] as String?;
        if (sosId != null) {
          Navigator.pushNamed(context, '/sos-detail/$sosId');
        }
        break;
      default:
    }
  }

  void _showNotificationOptions(String notificationId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mark_email_read),
              title: const Text('Mark as read'),
              onTap: () {
                Navigator.pop(context);
                _markAsRead(notificationId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteNotification(notificationId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettings() {
    if (_preferences == null) {
      _loadPreferences();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Notification Settings'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPreferenceTile(
                    'Blood Request Matches',
                    'blood_request_match',
                    setDialogState,
                  ),
                  _buildPreferenceTile(
                    'Urgent SOS Alerts',
                    'sos_alert',
                    setDialogState,
                  ),
                  _buildPreferenceTile(
                    'Donation Reminders',
                    'donation_reminder',
                    setDialogState,
                  ),
                  _buildPreferenceTile(
                    'Messages',
                    'message_received',
                    setDialogState,
                  ),
                  const Divider(),
                  _buildPreferenceTile(
                    'Email Notifications',
                    'email_notifications',
                    setDialogState,
                  ),
                  _buildPreferenceTile(
                    'Push Notifications',
                    'push_notifications',
                    setDialogState,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreferenceTile(
    String label,
    String key,
    StateSetter setDialogState,
  ) {
    return SwitchListTile(
      title: Text(label),
      value: _preferences?[key] ?? true,
      onChanged: (value) {
        setDialogState(() {
          _preferences?[key] = value;
        });
        _updatePreference(key, value);
      },
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildBottomNavigation() {
    return UnifiedBottomNavigationBar(
      selectedIndex: _selectedTabIndex,
      onItemTapped: (index) {
        setState(() => _selectedTabIndex = index);
        final routes = [
          AppRoutes.home,
          AppRoutes.nearbyRequests,
          AppRoutes.findDonors,
          AppRoutes.messages,
          AppRoutes.settings,
        ];
        if (routes[index].isNotEmpty) {
          Navigator.pushReplacementNamed(context, routes[index]);
        }
      },
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
        // Handle navigation
        switch (index) {
          case 0:
            Navigator.popUntil(context, (route) => route.isFirst);
            break;
          case 1:
            Navigator.popAndPushNamed(context, '/nearby-requests');
            break;
          case 2:
            Navigator.popAndPushNamed(context, '/nearby-donors-map');
            break;
          case 3:
            Navigator.popAndPushNamed(context, '/messages');
            break;
          case 4:
            Navigator.popAndPushNamed(context, '/settings');
            break;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
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

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final IconData icon;
  final Color color;
  final String timestamp;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NotificationCard({
    required this.notification,
    required this.icon,
    required this.color,
    required this.timestamp,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] as bool? ?? false;
    final message = notification['message'] as String? ?? '';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead ? AppColors.border : color.withOpacity(0.3),
            width: isRead ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Notification Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] as String? ?? 'Notification',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isRead ? FontWeight.w400 : FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Timestamp and unread indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timestamp,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (!isRead) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
