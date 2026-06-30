/// Blood Request Model
/// Represents a blood donation request for a patient
class BloodRequest {
  final String id;
  final String patientName;
  final String bloodGroup;
  final int unitsNeeded;
  final int unitsPledged;
  final int unitsReceived;
  final int respondersCount;
  final String urgencyLevel;
  final String contactNumber;
  final String? hospitalName;
  final String? location;
  final double? locationLat;
  final double? locationLng;
  final String? additionalNotes;
  final DateTime neededBy; // Required: When blood is needed by
  final String status;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? requesterName;
  final String? requestedById;
  final String? requesterProfilePicture;
  final String? shareId; // External pledge system: Short shareable ID

  BloodRequest({
    required this.id,
    required this.patientName,
    required this.bloodGroup,
    required this.unitsNeeded,
    this.unitsPledged = 0,
    this.unitsReceived = 0,
    this.respondersCount = 0,
    required this.urgencyLevel,
    required this.contactNumber,
    this.hospitalName,
    this.location,
    this.locationLat,
    this.locationLng,
    this.additionalNotes,
    required this.neededBy,
    required this.status,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.requesterName,
    this.requestedById,
    this.requesterProfilePicture,
    this.shareId, // External pledge system
  });

  /// Helper to parse nullable double from JSON (handles String from Django DecimalField)
  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  /// Create BloodRequest from JSON
  factory BloodRequest.fromJson(Map<String, dynamic> json) {
    // Debug logging for share_id parsing
    print('🐛 [BloodRequest.fromJson] Parsing BloodRequest from JSON');
    print('🐛 [BloodRequest.fromJson] JSON keys: ${json.keys.toList()}');
    print('🐛 [BloodRequest.fromJson] share_id raw value: ${json['share_id']}');
    print('🐛 [BloodRequest.fromJson] share_id type: ${json['share_id'].runtimeType}');
    print('🐛 [BloodRequest.fromJson] id value: ${json['id']}');

    final shareIdValue = json['share_id']?.toString();
    print('🐛 [BloodRequest.fromJson] share_id parsed value: $shareIdValue');

    // Safe parsing with null checks and defaults
    return BloodRequest(
      id: json['id']?.toString() ?? '',
      patientName: json['patient_name']?.toString() ?? '',
      bloodGroup: json['blood_group']?.toString() ?? '',
      unitsNeeded: json['units_needed'] is int ? json['units_needed'] as int : int.tryParse(json['units_needed']?.toString() ?? '0') ?? 0,
      unitsPledged: json['units_pledged'] is int ? json['units_pledged'] as int : int.tryParse(json['units_pledged']?.toString() ?? '0') ?? 0,
      unitsReceived: json['units_received'] is int ? json['units_received'] as int : int.tryParse(json['units_received']?.toString() ?? '0') ?? 0,
      respondersCount: json['responders_count'] is int ? json['responders_count'] as int : int.tryParse(json['responders_count']?.toString() ?? '0') ?? 0,
      urgencyLevel: json['urgency_level']?.toString() ?? 'normal',
      contactNumber: json['contact_number']?.toString() ?? '',
      hospitalName: json['hospital_name']?.toString(),
      location: json['location']?.toString(),
      locationLat: _parseNullableDouble(json['location_lat']),
      locationLng: _parseNullableDouble(json['location_lng']),
      additionalNotes: json['additional_notes']?.toString(),
      neededBy: _parseRequiredDateTime(json['needed_by']),
      status: json['status']?.toString() ?? 'pending',
      isActive: json['is_active'] is bool ? json['is_active'] as bool : json['is_active']?.toString() == 'true',
      createdAt: _parseRequiredDateTime(json['created_at']),
      updatedAt: _parseRequiredDateTime(json['updated_at']),
      requesterName: json['requester_name']?.toString(),
      requestedById: json['requested_by_id']?.toString(),
      requesterProfilePicture: json['requester_profile_picture']?.toString(),
      shareId: shareIdValue, // External pledge system
    );
  }

  /// Safe DateTime parsing with fallback (returns null for optional dates)
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Safe DateTime parsing with fallback for required fields (returns DateTime.now() if null)
  static DateTime _parseRequiredDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  /// Convert BloodRequest to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_name': patientName,
      'blood_group': bloodGroup,
      'units_needed': unitsNeeded,
      'units_pledged': unitsPledged,
      'units_received': unitsReceived,
      'responders_count': respondersCount,
      'urgency_level': urgencyLevel,
      'contact_number': contactNumber,
      'hospital_name': hospitalName,
      'location': location,
      'additional_notes': additionalNotes,
      'status': status,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create BloodRequest for API request (creation)
  Map<String, dynamic> toCreateJson() {
    return {
      'patient_name': patientName,
      'blood_group': bloodGroup,
      'units_needed': unitsNeeded,
      'urgency_level': urgencyLevel,
      'contact_number': contactNumber,
      if (hospitalName != null && hospitalName!.isNotEmpty) 'hospital_name': hospitalName,
      if (location != null && location!.isNotEmpty) 'location': location,
      if (additionalNotes != null && additionalNotes!.isNotEmpty) 'additional_notes': additionalNotes,
    };
  }

  /// Check if request is urgent or critical
  bool get isUrgent => urgencyLevel == 'urgent' || urgencyLevel == 'critical';

  /// Get urgency color hex code
  String get urgencyColor {
    switch (urgencyLevel) {
      case 'critical':
        return '#D62828';
      case 'urgent':
        return '#E85D04';
      default:
        return '#FFB74D';
    }
  }

  /// Get status display text
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Active';
      case 'fulfilled':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Copy with method for updating fields
  BloodRequest copyWith({
    String? id,
    String? patientName,
    String? bloodGroup,
    int? unitsNeeded,
    int? unitsPledged,
    int? unitsReceived,
    int? respondersCount,
    String? urgencyLevel,
    String? contactNumber,
    String? hospitalName,
    String? location,
    double? locationLat,
    double? locationLng,
    String? additionalNotes,
    DateTime? neededBy,
    String? status,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? requesterName,
    String? shareId, // External pledge system
  }) {
    return BloodRequest(
      id: id ?? this.id,
      patientName: patientName ?? this.patientName,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      unitsNeeded: unitsNeeded ?? this.unitsNeeded,
      unitsPledged: unitsPledged ?? this.unitsPledged,
      unitsReceived: unitsReceived ?? this.unitsReceived,
      respondersCount: respondersCount ?? this.respondersCount,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      contactNumber: contactNumber ?? this.contactNumber,
      hospitalName: hospitalName ?? this.hospitalName,
      location: location ?? this.location,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      neededBy: neededBy ?? this.neededBy,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      requesterName: requesterName ?? this.requesterName,
      shareId: shareId ?? this.shareId, // External pledge system
    );
  }

  /// Get units remaining to fulfill the request
  int get unitsRemaining => unitsNeeded - unitsPledged;
}

/// Blood Request List Response
class BloodRequestListResponse {
  final bool success;
  final String message;
  final List<BloodRequest> bloodRequests;
  final int count;

  BloodRequestListResponse({
    required this.success,
    required this.message,
    required this.bloodRequests,
    required this.count,
  });

  factory BloodRequestListResponse.fromJson(Map<String, dynamic> json) {
    final List<BloodRequest> requests = [];
    if (json['blood_requests'] != null) {
      for (var item in json['blood_requests']) {
        requests.add(BloodRequest.fromJson(item));
      }
    }

    return BloodRequestListResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      bloodRequests: requests,
      count: json['count'] as int? ?? requests.length,
    );
  }
}

/// Blood Request Detail Response
class BloodRequestDetailResponse {
  final bool success;
  final String message;
  final BloodRequest? bloodRequest;

  BloodRequestDetailResponse({
    required this.success,
    required this.message,
    this.bloodRequest,
  });

  factory BloodRequestDetailResponse.fromJson(Map<String, dynamic> json) {
    return BloodRequestDetailResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      bloodRequest: json['blood_request'] != null
          ? BloodRequest.fromJson(json['blood_request'])
          : null,
    );
  }
}
