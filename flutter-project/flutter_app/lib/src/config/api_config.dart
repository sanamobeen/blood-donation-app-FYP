import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// API Configuration for different platforms
///
/// Quick Setup:
/// 1. Android Emulator: Uses 10.0.2.2 (automatic)
/// 2. Real Device: Update computerIP below with your IP address
/// 3. iOS Simulator: Uses localhost (automatic)
///
/// Find your IP: Run `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
/// Look for "IPv4 Address" e.g., 192.168.1.5
class ApiConfig {
  // ==================== USER CONFIGURATION ====================

  /// For REAL DEVICE: Update this with your computer's IP address
  /// Example: '192.168.1.5' or '192.168.0.100'
  static const String computerIP = '192.168.1.103'; // ← UPDATE FOR REAL DEVICE

  /// Backend port (default Django port)
  static const int backendPort = 8000;

  // ==================== BASE URL SELECTION ====================

  /// Get the appropriate base URL based on platform
  static String getBaseUrl() {
    // Check for manual override first
    if (forcedBaseUrl != null) {
      return forcedBaseUrl!;
    }

    // Web: Use localhost
    if (kIsWeb) {
      return 'http://localhost:$backendPort';
    }

    // Android Emulator: Use special IP 10.0.2.2
    if (Platform.isAndroid) {
      // For EMULATOR: Uncomment this line
      return 'http://10.0.2.2:$backendPort';

      // For REAL DEVICE: Uncomment this line and update computerIP above
      // return 'http://$computerIP:$backendPort';
    }

    // iOS Simulator: Runs on Mac, use localhost
    if (Platform.isIOS) {
      return 'http://localhost:$backendPort';
    }

    // Desktop: Use localhost
    return 'http://localhost:$backendPort';
  }

  // ==================== API ENDPOINTS ====================

  static String get authEndpoint => '${getBaseUrl()}/api/auth';
  static String get bloodRequestsEndpoint => '${getBaseUrl()}/api/blood-requests';
  static String get requestsEndpoint => '${getBaseUrl()}/api/requests';
  static String get donationsEndpoint => '${getBaseUrl()}/api/donations';
  static String get sosEndpoint => '${getBaseUrl()}/api/sos';
  static String get statsEndpoint => '${getBaseUrl()}/api/stats';
  static String get messagesEndpoint => '${getBaseUrl()}/api/messages';
  static String get chatEndpoint => '${getBaseUrl()}/api/chat';
  static String get assistantEndpoint => '${getBaseUrl()}/api/assistant';
  static String get notificationsEndpoint => '${getBaseUrl()}/api/notifications';
  static String get achievementsEndpoint => '${getBaseUrl()}/api/achievements';
  static String get healthEndpoint => '${getBaseUrl()}/api/health';
  static String get bloodTypesEndpoint => '${getBaseUrl()}/api/blood-types';
  static String get donorEndpoint => '${getBaseUrl()}/api/donor';
  static String get searchEndpoint => '${getBaseUrl()}/api/search';
  static String get adminEndpoint => '${getBaseUrl()}/api/admin';

  // ==================== MANUAL OVERRIDE ====================

  /// Force a specific URL (useful for testing or production)
  static String? forcedBaseUrl;

  /// Reset to auto-detection
  static void resetToAuto() {
    forcedBaseUrl = null;
  }

  /// Print current configuration for debugging
  static void printConfig() {
    if (forcedBaseUrl != null) {
    }
  }

  static String _getPlatformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}

// ==================== USAGE EXAMPLES ====================
/*
/// Android Emulator (default):
/// ApiConfig.authEndpoint = 'http://10.0.2.2:8000/api/auth'
///
/// Real Android Device (update computerIP first):
/// ApiConfig.authEndpoint = 'http://192.168.1.5:8000/api/auth'
///
/// iOS Simulator:
/// ApiConfig.authEndpoint = 'http://localhost:8000/api/auth'
///
/// Force production URL:
/// ApiConfig.forcedBaseUrl = 'https://api.example.com';
/// ApiConfig.authEndpoint = 'https://api.example.com/api/auth'
*/
