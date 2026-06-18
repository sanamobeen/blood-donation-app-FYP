import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for displaying local notifications
///
/// Used for showing notifications when the app is in foreground
/// since Firebase doesn't automatically show them in that state.
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;

  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize local notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {

      // Android initialization settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      // Combined initialization settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize the plugin
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create notification channel for Android (required for Android 8.0+)
      if (!kIsWeb && Platform.isAndroid) {
        await _createAndroidNotificationChannel();
      }

      _isInitialized = true;
    } catch (e) {
    }
  }

  /// Create Android notification channel (required for Android 8.0+)
  Future<void> _createAndroidNotificationChannel() async {
    // SOS Alerts Channel
    const sosAlertsChannel = AndroidNotificationChannel(
      'sos_alerts', // Channel ID
      'SOS Alerts', // Channel name
      description: 'Critical SOS and emergency blood request notifications',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    // SOS Critical Channel (highest priority)
    const sosCriticalChannel = AndroidNotificationChannel(
      'sos_critical', // Channel ID
      'SOS Critical', // Channel name
      description: 'Critical SOS alerts - highest priority notifications',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm'),
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(sosAlertsChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(sosCriticalChannel);
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap - you can navigate based on payload
  }

  /// Show a local notification
  ///
  /// [id] Unique ID for this notification
  /// [title] Notification title
  /// [body] Notification body text
  /// [payload] Optional data payload (JSON string)
  /// [channelId] Android channel ID (default: 'sos_alerts')
  /// [importance] Android importance level (default: Importance.high)
  /// [priority] Android priority level (default: Priority.high)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'sos_alerts',
    Importance importance = Importance.high,
    Priority priority = Priority.high,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Android notification details
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: importance,
      priority: priority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      // Use custom sound for critical alerts
      sound: channelId == 'sos_critical'
          ? const RawResourceAndroidNotificationSound('alarm')
          : null,
    );

    // iOS notification details
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: channelId == 'sos_critical' ? 'alarm.caf' : null,
    );

    // Combined notification details
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
    }
  }

  /// Get channel name for a given channel ID
  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'sos_critical':
        return 'SOS Critical';
      case 'sos_alerts':
        return 'SOS Alerts';
      default:
        return 'Notifications';
    }
  }

  /// Get channel description for a given channel ID
  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'sos_critical':
        return 'Critical SOS alerts - highest priority notifications';
      case 'sos_alerts':
        return 'Critical SOS and emergency blood request notifications';
      default:
        return 'General notifications';
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
