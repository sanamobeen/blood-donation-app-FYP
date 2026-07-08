import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/api_config.dart';
import '../app_routes.dart';
import 'local_notification_service.dart';

/// Service for handling Firebase Cloud Messaging (FCM) push notifications
///
/// This service manages:
/// - FCM token registration with backend
/// - Permission requests for notifications
/// - Handling incoming push notifications
/// - Token refresh handling
class NotificationService {
  static const String _fcmTokenKey = 'fcm_token';
  static const String _tokenRegisteredKey = 'token_registered';

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _isInitialized = false;

  /// Navigator key for navigation from notifications
  /// Set this from your app's MaterialApp navigatorKey
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Initialize the notification service
  ///
  /// Call this once on app startup (usually in main.dart)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔔 NotificationService: Starting initialization...');

      // Request permission for iOS
      await _requestPermission();
      debugPrint('🔔 NotificationService: Permission requested');

      // Get and register FCM token
      await _handleFCMToken();
      debugPrint('🔔 NotificationService: FCM token handled');

      // Configure foreground message handling
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Configure background message handling
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle initial message if app was opened from notification
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);

      _isInitialized = true;
      debugPrint('🔔 NotificationService: Initialization complete!');
    } catch (e) {
      debugPrint('🔔 NotificationService: Initialization failed - $e');
    }
  }

  /// Request notification permission from user
  Future<void> _requestPermission() async {
    if (kIsWeb) return;

    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );


    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    } else {
    }
  }

  /// Handle FCM token - get, store, and register with backend
  Future<void> _handleFCMToken() async {
    try {
      debugPrint('🔔 Getting FCM token from Firebase...');
      // Get FCM token
      String? token = await _fcm.getToken();

      if (token != null && token.isNotEmpty) {
        debugPrint('🔔 FCM Token obtained: ${token.substring(0, 20)}...');

        // Save token locally
        await _saveFCMToken(token);
        debugPrint('🔔 FCM Token saved locally');

        // Register with backend
        debugPrint('🔔 Registering token with backend...');
        final success = await registerTokenWithBackend(token);

        if (success) {
          debugPrint('🔔 ✅ FCM Token registered with backend successfully!');
        } else {
          debugPrint('🔔 ❌ Failed to register FCM token with backend');
        }
      } else {
        debugPrint('🔔 ❌ FCM Token is null or empty');
      }
    } catch (e) {
      debugPrint('🔔 ❌ Error handling FCM token: $e');
    }
  }

  /// Handle token refresh
  void _onTokenRefresh(String newToken) {
    _saveFCMToken(newToken);
    registerTokenWithBackend(newToken);
  }

  /// Save FCM token locally
  Future<void> _saveFCMToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmTokenKey, token);
  }

  /// Get stored FCM token
  static Future<String?> getFCMToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fcmTokenKey);
  }

  /// Register FCM token with backend
  Future<bool> registerTokenWithBackend(String token) async {
    try {
      debugPrint('🔔 RegisterTokenWithBackend: Starting...');

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      debugPrint('🔔 Access token exists: ${accessToken != null && accessToken.isNotEmpty}');

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('🔔 ❌ No access token - cannot register FCM token');
        return false;
      }

      // Use the FCM token endpoint from auth endpoint
      debugPrint('🔔 Calling: ${ApiConfig.authEndpoint}/fcm-token/');
      final response = await http.post(
        Uri.parse('${ApiConfig.authEndpoint}/fcm-token/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'fcm_token': token,
        }),
      );

      debugPrint('🔔 Response status code: ${response.statusCode}');
      debugPrint('🔔 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Mark as registered
        await prefs.setBool(_tokenRegisteredKey, true);
        debugPrint('🔔 ✅ FCM token registered successfully');
        return true;
      } else {
        debugPrint('🔔 ❌ FCM token registration failed with status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('🔔 ❌ Exception in registerTokenWithBackend: $e');
      return false;
    }
  }

  /// Deactivate all device tokens (useful for logout)
  Future<void> deactivateAllTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null || accessToken.isEmpty) {
        return;
      }

      await http.post(
        Uri.parse('${ApiConfig.notificationsEndpoint}/deactivate-all/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      await prefs.setBool(_tokenRegisteredKey, false);
    } catch (e) {
    }
  }

  /// Handle incoming notification when app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    final type = message.data['type'];

    // Handle SOS notifications specially
    if (type == 'sos_alert') {
      _showSOSNotification(message);
      return;
    }

    // Show local notification for other foreground messages
    LocalNotificationService().showNotification(
      id: message.hashCode,
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  /// Show SOS notification with special styling
  void _showSOSNotification(RemoteMessage message) {
    final urgency = message.data['urgency'] ?? 'normal';
    final bloodType = message.data['blood_type'] ?? 'Unknown';
    final hospitalName = message.data['hospital_name'] ?? 'Unknown Hospital';

    // Show high-priority notification
    LocalNotificationService().showNotification(
      id: message.hashCode,
      title: '🚨 URGENT: Blood Needed!',
      body: '$bloodType blood needed at $hospitalName\nTap to help now!',
      payload: jsonEncode(message.data),
      channelId: 'sos_critical',
      importance: Importance.max,
      priority: Priority.high,
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    // Extract data and navigate
    final type = message.data['type'];
    final sosId = message.data['sos_id'];
    final urgency = message.data['urgency'];

    if (type == 'sos_alert') {
      // Navigate to SOS details or pledge screen
      _navigateToSOSDetails(message.data);
    } else if (type == 'sos_created' && sosId != null) {
      // Navigate to SOS details
      _navigateToSOSDetails(message.data);
    }
  }

  /// Navigate to SOS details screen
  void _navigateToSOSDetails(Map<String, dynamic> data) {
    if (navigatorKey?.currentState == null) {
      debugPrint('Navigator key not set or not ready for SOS navigation');
      return;
    }

    final sosId = data['sos_id'] as String?;
    if (sosId == null || sosId.isEmpty) {
      debugPrint('SOS ID not found in notification data');
      return;
    }

    try {
      // Navigate to SOS detail screen
      navigatorKey!.currentState!.pushNamed(
        AppRoutes.sosDetail,
        arguments: {'sosId': sosId},
      );
    } catch (e) {
      debugPrint('Failed to navigate to SOS detail: $e');
    }
  }

  /// Get device type string
  String _getDeviceType() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Get device name
  String _getDeviceName() {
    if (kIsWeb) return 'Web Browser';
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iOS Device';
    return 'Unknown Device';
  }

  /// Check if user has granted notification permission
  Future<bool> hasPermission() async {
    if (kIsWeb) return true;

    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Open app settings for notifications
  Future<void> openNotificationSettings() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // For iOS and Android, the user needs to manually open settings
      // Consider using 'open_app_settings' package
    }
  }
}
