/// SOS Emergency Request Model
/// Represents an emergency blood donation request
class SosRequest {
  final String id;
  final String requesterName;
  final String requesterEmail;
  final String bloodType;
  final String bloodTypeDisplay;
  final String patientName;
  final int age;
  final String gender;
  final String hospitalName;
  final String hospitalAddress;
  final double? hospitalLat;
  final double? hospitalLng;
  final String contactPhone;
  final int unitsNeeded;
  final String status;
  final int respondersCount;
  final int timeRemainingMinutes;
  final bool isActive;
  final DateTime createdAt;

  SosRequest({
    required this.id,
    required this.requesterName,
    required this.requesterEmail,
    required this.bloodType,
    required this.bloodTypeDisplay,
    required this.patientName,
    required this.age,
    required this.gender,
    required this.hospitalName,
    required this.hospitalAddress,
    this.hospitalLat,
    this.hospitalLng,
    required this.contactPhone,
    required this.unitsNeeded,
    required this.status,
    required this.respondersCount,
    required this.timeRemainingMinutes,
    required this.isActive,
    required this.createdAt,
  });

  factory SosRequest.fromJson(Map<String, dynamic> json) {
    return SosRequest(
      id: json['id'] as String,
      requesterName: json['requester_name'] as String? ?? '',
      requesterEmail: json['requester_email'] as String? ?? '',
      bloodType: json['blood_type'] as String? ?? '',
      bloodTypeDisplay: json['blood_type_display'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? '',
      age: json['age'] as int? ?? 0,
      gender: json['gender'] as String? ?? '',
      hospitalName: json['hospital_name'] as String? ?? '',
      hospitalAddress: json['hospital_address'] as String? ?? '',
      hospitalLat: json['hospital_lat'] as double?,
      hospitalLng: json['hospital_lng'] as double?,
      contactPhone: json['contact_phone'] as String? ?? '',
      unitsNeeded: json['units_needed'] as int? ?? 1,
      status: json['status'] as String? ?? 'active',
      respondersCount: json['responders_count'] as int? ?? 0,
      timeRemainingMinutes: json['time_remaining_minutes'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  /// Check if SOS is critical (less than 30 minutes remaining)
  bool get isCritical => timeRemainingMinutes < 30;

  /// Get status color
  String get statusColor {
    switch (status) {
      case 'active':
        return isCritical ? '#D62828' : '#E85D04';
      case 'resolved':
        return '#2A9D8F';
      case 'cancelled':
        return '#6C757D';
      default:
        return '#6C757D';
    }
  }

  /// Get status display text
  String get statusDisplay {
    switch (status) {
      case 'active':
        return 'Active';
      case 'resolved':
        return 'Resolved';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

/// SOS Requests List Response
class SosRequestListResponse {
  final bool success;
  final String message;
  final List<SosRequest> requests;
  final int count;

  SosRequestListResponse({
    required this.success,
    required this.message,
    required this.requests,
    required this.count,
  });

  factory SosRequestListResponse.fromJson(Map<String, dynamic> json) {
    final List<SosRequest> requestList = [];
    if (json['requests'] != null) {
      for (var item in json['requests']) {
        requestList.add(SosRequest.fromJson(item));
      }
    }

    return SosRequestListResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      requests: requestList,
      count: json['count'] as int? ?? requestList.length,
    );
  }
}
