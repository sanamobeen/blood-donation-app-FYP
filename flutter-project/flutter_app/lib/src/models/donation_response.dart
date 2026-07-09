/// Donation Response Models
/// For donation acknowledgment and certificate functionality

/// Donation with acknowledgment status
class DonationResponse {
  final String id;
  final String donorEmail;
  final String donorName;
  final String? bloodRequest;
  final String? hospitalName;
  final String? patientName;
  final String? bloodType;
  final String? bloodTypeCode;
  final int units;
  final String donationDate;
  final String? donationCenter;
  final bool acknowledgedByPatient;
  final String? acknowledgedAt;
  final bool isFulfilled;
  final bool canBeAcknowledgedBy;
  final DateTime createdAt;

  DonationResponse({
    required this.id,
    required this.donorEmail,
    required this.donorName,
    this.bloodRequest,
    this.hospitalName,
    this.patientName,
    this.bloodType,
    this.bloodTypeCode,
    required this.units,
    required this.donationDate,
    this.donationCenter,
    required this.acknowledgedByPatient,
    this.acknowledgedAt,
    required this.isFulfilled,
    required this.canBeAcknowledgedBy,
    required this.createdAt,
  });

  factory DonationResponse.fromJson(Map<String, dynamic> json) {
    return DonationResponse(
      id: json['id'] as String,
      donorEmail: json['donor_email'] as String? ?? '',
      donorName: json['donor_name'] as String? ?? '',
      bloodRequest: json['blood_request'] as String?,
      hospitalName: json['hospital_name'] as String?,
      patientName: json['patient_name'] as String?,
      bloodType: json['blood_type'] as String?,
      bloodTypeCode: json['blood_type_code'] as String?,
      units: json['units'] as int? ?? 0,
      donationDate: json['donation_date'] as String? ?? '',
      donationCenter: json['donation_center'] as String?,
      acknowledgedByPatient: json['acknowledged_by_patient'] as bool? ?? false,
      acknowledgedAt: json['acknowledged_at'] as String?,
      isFulfilled: json['is_fulfilled'] as bool? ?? false,
      canBeAcknowledgedBy: json['can_be_acknowledged_by'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  /// Get status display text
  String get statusDisplay {
    if (isFulfilled) return 'Completed ✓';
    if (acknowledgedByPatient) return 'Acknowledged';
    return 'Pending acknowledgment';
  }

  /// Get status color
  String get statusColor {
    if (isFulfilled) return '#2A9D8F';
    if (acknowledgedByPatient) return '#E9C46A';
    return '#6C757D';
  }
}

/// Blood Request Responses (who offered to help)
class BloodRequestResponses {
  final List<DonationResponse> responses;
  final int acknowledgedCount;
  final int pendingCount;
  final int totalUnitsReceived;
  final int unitsNeeded;

  BloodRequestResponses({
    required this.responses,
    required this.acknowledgedCount,
    required this.pendingCount,
    required this.totalUnitsReceived,
    required this.unitsNeeded,
  });

  factory BloodRequestResponses.fromJson(Map<String, dynamic> json) {
    final List<DonationResponse> responseList = [];
    if (json['responses'] != null) {
      for (var item in json['responses']) {
        responseList.add(DonationResponse.fromJson(item));
      }
    }

    return BloodRequestResponses(
      responses: responseList,
      acknowledgedCount: json['acknowledged_count'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      totalUnitsReceived: json['total_units_received'] as int? ?? 0,
      unitsNeeded: json['units_needed'] as int? ?? 0,
    );
  }

  /// Check if request is fully fulfilled
  bool get isFullyFulfilled => totalUnitsReceived >= unitsNeeded;

  /// Get fulfillment percentage
  int get fulfillmentPercentage {
    if (unitsNeeded == 0) return 0;
    return ((totalUnitsReceived / unitsNeeded) * 100).round();
  }
}
