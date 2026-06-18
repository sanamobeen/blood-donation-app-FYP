import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Service for handling SOS (emergency blood request) notifications
///
/// This service manages:
/// - Sending SOS alerts to nearby compatible donors
/// - Getting SOS notification status
/// - Managing SOS alerts
class SOSService {
  /// Send SOS notification to nearby compatible donors
  ///
  /// [bloodType] Required blood type (e.g., 'A+', 'O-', etc.)
  /// [hospitalName] Name of the hospital
  /// [hospitalAddress] Address of the hospital
  /// [hospitalLat] Latitude of hospital location
  /// [hospitalLng] Longitude of hospital location
  /// [patientName] Name of the patient (optional)
  /// [contactPhone] Contact phone number (optional)
  /// [urgencyLevel] Urgency level: 'critical', 'urgent', or 'normal' (default: 'critical')
  /// [radiusKm] Search radius in kilometers (default: 10)
  ///
  /// Returns a map with success status and notification details
  static Future<Map<String, dynamic>> sendSOSNotification({
    required String bloodType,
    required String hospitalName,
    required String hospitalAddress,
    required double hospitalLat,
    required double hospitalLng,
    String? patientName,
    String? contactPhone,
    String urgencyLevel = 'critical',
    double radiusKm = 10,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken == null || accessToken.isEmpty) {
        return {
          'success': false,
          'message': 'Authentication required. Please login.',
        };
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.getBaseUrl()}/api/sos/notify-donors/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'blood_type': bloodType,
          'hospital_name': hospitalName,
          'hospital_address': hospitalAddress,
          'hospital_lat': hospitalLat,
          'hospital_lng': hospitalLng,
          if (patientName != null) 'patient_name': patientName,
          if (contactPhone != null) 'contact_phone': contactPhone,
          'urgency_level': urgencyLevel,
          'radius_km': radiusKm,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'SOS notifications sent successfully',
          'notification_id': data['notification_id'],
          'notified_count': data['notified_count'] ?? 0,
          'target_radius': data['target_radius'] ?? radiusKm,
          'eligible_donors': data['eligible_donors'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send SOS notifications',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error. Please check your connection.',
      };
    }
  }

  /// Get blood type compatibility information
  ///
  /// Returns which donor blood types can donate to the recipient
  static List<String> getCompatibleBloodTypes(String recipientType) {
    const compatibilityMap = {
      'A+': ['A+', 'A-', 'O+', 'O-'],
      'A-': ['A-', 'O-'],
      'B+': ['B+', 'B-', 'O+', 'O-'],
      'B-': ['B-', 'O-'],
      'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
      'AB-': ['A-', 'B-', 'AB-', 'O-'],
      'O+': ['O+', 'O-'],
      'O-': ['O-'],
    };

    return compatibilityMap[recipientType] ?? [];
  }

  /// Get all blood types
  static List<String> getAllBloodTypes() {
    return ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  }

  /// Validate blood type format
  static bool isValidBloodType(String bloodType) {
    return getAllBloodTypes().contains(bloodType);
  }

  /// Get urgency level options
  static List<String> getUrgencyLevels() {
    return ['critical', 'urgent', 'normal'];
  }

  /// Get recommended radius based on urgency
  static double getRecommendedRadius(String urgencyLevel) {
    switch (urgencyLevel.toLowerCase()) {
      case 'critical':
        return 15; // Wider search for critical cases
      case 'urgent':
        return 10;
      default:
        return 5;
    }
  }
}
