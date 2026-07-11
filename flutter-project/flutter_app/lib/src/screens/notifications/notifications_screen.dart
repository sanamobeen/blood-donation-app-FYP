import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/notification.dart' as model;
import '../../theme/app_theme.dart';
import '../../widgets/bottom_navigation_bar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedTabIndex = 0;

  // Sample notifications data
  final List<model.NotificationItem> _notifications = [
    // Today's notifications
    model.NotificationItem(
      id: '1',
      title: 'Urgent request near you',
      description: 'A+ blood needed at City Care Hospital',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      type: model.NotificationType.urgentRequest,
      isRead: false,
    ),
    model.NotificationItem(
      id: '2',
      title: 'Donation reminder',
      description: 'You can donate again in 12 days. Stay healthy!',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      type: model.NotificationType.donationReminder,
      isRead: false,
    ),
    model.NotificationItem(
      id: '3',
      title: 'Thank you!',
      description: 'Your donation on 12 May has helped save a life.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: model.NotificationType.thankYou,
      isRead: true,
    ),
    // Yesterday's notifications
    model.NotificationItem(
      id: '5',
      title: 'New request posted',
      description: 'B- blood needed at Sunrise Hospital',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      type: model.NotificationType.newRequest,
      isRead: true,
    ),
    model.NotificationItem(
      id: '6',
      title: 'Donation reminder',
      description: 'You are eligible to donate. Make a difference!',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 10)),
      type: model.NotificationType.donationReminder,
      isRead: true,
    ),
  ];

  List<model.NotificationItem> get _todayNotifications {
    final now = DateTime.now();
    return _notifications.where((notification) {
      return notification.timestamp.day == now.day &&
          notification.timestamp.month == now.month &&
          notification.timestamp.year == now.year;
    }).toList();
  }

  List<model.NotificationItem> get _yesterdayNotifications {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _notifications.where((notification) {
      return notification.timestamp.day == yesterday.day &&
          notification.timestamp.month == yesterday.month &&
          notification.timestamp.year == yesterday.year;
    }).toList();
  }

  IconData _getNotificationIcon(model.NotificationType type) {
    switch (type) {
      case model.NotificationType.urgentRequest:
        return Icons.notifications;
      case model.NotificationType.donationReminder:
        return Icons.water_drop;
      case model.NotificationType.thankYou:
        return Icons.favorite;
      case model.NotificationType.newRequest:
        return Icons.person;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      final hour = timestamp.hour;
      final minute = timestamp.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final formattedMinute = minute.toString().padLeft(2, '0');
      return '$formattedHour:$formattedMinute $period';
    } else {
      final hour = timestamp.hour;
      final minute = timestamp.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final formattedMinute = minute.toString().padLeft(2, '0');
      return 'Yesterday, $formattedHour:$formattedMinute $period';
    }
  }

  void _markAsRead(String id) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 16),

                    // Today's Notifications
                    if (_todayNotifications.isNotEmpty) ...[
                      _buildSectionHeader('Today'),
                      const SizedBox(height: 8),
                      _buildNotificationsList(_todayNotifications),
                      const SizedBox(height: 16),
                    ],

                    // Yesterday's Notifications
                    if (_yesterdayNotifications.isNotEmpty) ...[
                      _buildSectionHeader('Yesterday'),
                      const SizedBox(height: 8),
                      _buildNotificationsList(_yesterdayNotifications),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.softPink.withValues(alpha: 0.5),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Title on the left
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
        ],
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

  Widget _buildNotificationsList(List<model.NotificationItem> notifications) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: notifications.map((notification) {
          return _NotificationCard(
            notification: notification,
            icon: _getNotificationIcon(notification.type),
            timestamp: _formatTimestamp(notification.timestamp),
            onTap: () {
              _markAsRead(notification.id);
              // Handle notification tap
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return UnifiedBottomNavigationBar(
      selectedIndex: _selectedTabIndex,
      onItemTapped: (index) {
        setState(() => _selectedTabIndex = index);
        // Routes: 0=Home, 1=Request, 2=Chat, 3=Profile
        switch (index) {
          case 0:
            Navigator.popUntil(context, (route) => route.isFirst || route.settings.name == AppRoutes.home);
            break;
          case 1:
            Navigator.pushReplacementNamed(context, AppRoutes.nearbyRequests);
            break;
          case 2:
            // Navigate to Messages (Chat)
            Navigator.pushReplacementNamed(context, AppRoutes.messages);
            break;
          case 3:
            // Navigate to Settings (Profile)
            Navigator.pushReplacementNamed(context, AppRoutes.settings);
            break;
        }
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final model.NotificationItem notification;
  final IconData icon;
  final String timestamp;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.icon,
    required this.timestamp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
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
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
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
                    notification.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.description,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
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
                if (!notification.isRead) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
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
