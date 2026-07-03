import 'package:flutter/material.dart';
import '../utils/string_extensions.dart';

/// Donor Pledge Model
/// Represents a donor's pledge/commitment to donate blood for a request
class DonorPledge {
  final String id;
  final String bloodRequest;
  final String? donor;
  final String? donorName;
  final String? donorEmail;
  final String? donorPhone;
  final String? donorBloodGroup;
  final String? donorCity;
  final String? donorLocation;
  final int? donorAge;
  final DateTime? donorLastDonation;
  final String? bloodGroup;
  final String? patientName;
  final String? hospitalName;
  final int unitsPledged;
  final int unitsReceived;
  final String? note;
  final String status;
  final String? statusDisplay;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final String? patientNote;
  final DateTime createdAt;
  final DateTime? donatedAt;
  final int? daysWaiting;

  DonorPledge({
    required this.id,
    required this.bloodRequest,
    this.donor,
    this.donorName,
    this.donorEmail,
    this.donorPhone,
    this.donorBloodGroup,
    this.donorCity,
    this.donorLocation,
    this.donorAge,
    this.donorLastDonation,
    this.bloodGroup,
    this.patientName,
    this.hospitalName,
    required this.unitsPledged,
    this.unitsReceived = 0,
    this.note,
    required this.status,
    this.statusDisplay,
    this.acceptedAt,
    this.rejectedAt,
    this.patientNote,
    required this.createdAt,
    this.donatedAt,
    this.daysWaiting,
  });

  /// Create DonorPledge from JSON
  factory DonorPledge.fromJson(Map<String, dynamic> json) {
    // Map backend status to frontend status
    String backendStatus = json['status']?.toString() ?? 'pending';
    String frontendStatus = _mapBackendStatusToFrontend(backendStatus);

    return DonorPledge(
      id: json['id']?.toString() ?? '',
      bloodRequest: json['blood_request']?.toString() ?? '',
      donor: json['donor']?.toString(),
      donorName: json['donor_name']?.toString(),
      donorEmail: json['donor_email']?.toString(),
      donorPhone: json['donor_phone']?.toString(),
      donorBloodGroup: json['donor_blood_group']?.toString(),
      donorCity: json['donor_city']?.toString(),
      donorLocation: json['donor_location']?.toString(),
      donorAge: json['donor_age'] as int?,
      donorLastDonation: json['donor_last_donation'] != null
          ? DateTime.parse(json['donor_last_donation'])
          : null,
      bloodGroup: json['blood_group']?.toString(),
      patientName: json['patient_name']?.toString(),
      hospitalName: json['hospital_name']?.toString(),
      unitsPledged: json['units_pledged'] as int? ?? 1,
      unitsReceived: json['units_received'] as int? ?? 0,
      note: json['note']?.toString(),
      status: frontendStatus,
      statusDisplay: json['status_display']?.toString(),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.parse(json['rejected_at'])
          : null,
      patientNote: json['patient_note']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      donatedAt: json['donated_at'] != null
          ? DateTime.parse(json['donated_at'])
          : null,
      daysWaiting: json['days_waiting'] as int?,
    );
  }

  /// Map backend status to frontend status
  static String _mapBackendStatusToFrontend(String backendStatus) {
    switch (backendStatus) {
      case 'pledged':
        return 'pending';
      case 'shortlisted':
        return 'pending';
      case 'confirmed':
        return 'accepted';
      case 'on_the_way':
        return 'accepted';
      case 'arrived':
        return 'accepted';
      case 'ready':
        return 'accepted';
      case 'completed':
        return 'donated';
      case 'rejected':
        return 'rejected';
      case 'cancelled':
        return 'cancelled';
      case 'no_show':
        return 'cancelled';
      default:
        return 'pending';
    }
  }

  /// Convert DonorPledge to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'blood_request': bloodRequest,
      'donor': donor,
      'donor_name': donorName,
      'donor_email': donorEmail,
      'donor_phone': donorPhone,
      'donor_blood_group': donorBloodGroup,
      'donor_city': donorCity,
      'donor_location': donorLocation,
      'donor_age': donorAge,
      'donor_last_donation': donorLastDonation?.toIso8601String(),
      'blood_group': bloodGroup,
      'patient_name': patientName,
      'hospital_name': hospitalName,
      'units_pledged': unitsPledged,
      'units_received': unitsReceived,
      'note': note,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      if (donatedAt != null) 'donated_at': donatedAt!.toIso8601String(),
      if (acceptedAt != null) 'accepted_at': acceptedAt!.toIso8601String(),
      if (rejectedAt != null) 'rejected_at': rejectedAt!.toIso8601String(),
    };
  }

  /// Get status display text
  String get displayStatus {
    return statusDisplay ?? _getStatusDisplay(status);
  }

  String _getStatusDisplay(String s) {
    // Handle both backend statuses (if not mapped) and frontend statuses
    switch (s) {
      case 'pending':
      case 'pledged':
      case 'shortlisted':
        return 'Pending Approval';
      case 'accepted':
      case 'confirmed':
      case 'on_the_way':
      case 'arrived':
      case 'ready':
        return 'Accepted';
      case 'rejected':
        return 'Not Selected';
      case 'donated':
      case 'completed':
        return 'Donated';
      case 'cancelled':
      case 'no_show':
        return 'Cancelled';
      default:
        // Try to capitalize the status
        return s.split('_').map((word) => word.capitalize()).join(' ');
    }
  }

  /// Check if pledge is active
  bool get isActive => status == 'pending' || status == 'accepted' || status == 'donated' ||
                       status == 'pledged' || status == 'shortlisted' || status == 'confirmed' ||
                       status == 'on_the_way' || status == 'arrived' || status == 'ready' ||
                       status == 'completed';

  /// Check if pledge is pending
  bool get isPending => status == 'pending' || status == 'pledged' || status == 'shortlisted';

  /// Check if pledge is accepted
  bool get isAccepted => status == 'accepted' || status == 'confirmed' ||
                         status == 'on_the_way' || status == 'arrived' || status == 'ready';

  /// Check if pledge is rejected
  bool get isRejected => status == 'rejected';

  /// Check if pledge is donated
  bool get isDonated => status == 'donated' || status == 'completed';

  /// Check if pledge can be cancelled by donor
  bool get canBeCancelledByDonor => status == 'pending' || status == 'pledged' || status == 'shortlisted';

  /// Get status color for UI
  String getStatusColor() {
    switch (status) {
      case 'pending':
      case 'pledged':
      case 'shortlisted':
        return '#FFA726'; // Orange
      case 'accepted':
      case 'confirmed':
      case 'on_the_way':
      case 'arrived':
      case 'ready':
        return '#66BB6A'; // Green
      case 'rejected':
        return '#EF5350'; // Red
      case 'donated':
      case 'completed':
        return '#42A5F5'; // Blue
      case 'cancelled':
      case 'no_show':
        return '#9E9E9E'; // Grey
      default:
        return '#9E9E9E';
    }
  }
}

/// Pledge Summary for patient dashboard
class PledgeSummary {
  final int total;
  final int pending;
  final int accepted;
  final int rejected;
  final int donated;

  PledgeSummary({
    required this.total,
    required this.pending,
    required this.accepted,
    required this.rejected,
    required this.donated,
  });

  factory PledgeSummary.fromJson(Map<String, dynamic> json) {
    return PledgeSummary(
      total: json['total'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
      accepted: json['accepted'] as int? ?? 0,
      rejected: json['rejected'] as int? ?? 0,
      donated: json['donated'] as int? ?? 0,
    );
  }
}

/// Pledged Donors Response (for patient)
class PledgedDonorsResponse {
  final bool success;
  final String message;
  final List<DonorPledge> pledges;
  final PledgeSummary summary;
  final Map<String, dynamic>? bloodRequest;

  PledgedDonorsResponse({
    required this.success,
    required this.message,
    required this.pledges,
    required this.summary,
    this.bloodRequest,
  });

  factory PledgedDonorsResponse.fromJson(Map<String, dynamic> json) {
    final List<DonorPledge> pledgeList = [];
    if (json['data'] != null && json['data']['pledges'] != null) {
      for (var item in json['data']['pledges']) {
        pledgeList.add(DonorPledge.fromJson(item));
      }
    }

    return PledgedDonorsResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      pledges: pledgeList,
      summary: PledgeSummary.fromJson(json['data']?['summary'] ?? {}),
      bloodRequest: json['data']?['blood_request'],
    );
  }
}

/// My Pledges Response (for donor)
class MyPledgesResponse {
  final bool success;
  final String message;
  final List<DonorPledge> pledges;
  final PledgeSummary summary;

  MyPledgesResponse({
    required this.success,
    required this.message,
    required this.pledges,
    required this.summary,
  });

  factory MyPledgesResponse.fromJson(Map<String, dynamic> json) {
    final List<DonorPledge> pledgeList = [];
    if (json['data'] != null && json['data']['pledges'] != null) {
      for (var item in json['data']['pledges']) {
        pledgeList.add(DonorPledge.fromJson(item));
      }
    }

    return MyPledgesResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      pledges: pledgeList,
      summary: PledgeSummary.fromJson(json['data']?['summary'] ?? {}),
    );
  }
}

/// Request Progress Response
class RequestProgressResponse {
  final bool success;
  final String message;
  final int unitsNeeded;
  final int unitsPledged;
  final int unitsReceived;
  final int unitsRemaining;
  final int respondersCount;
  final List<DonorPledge> pledges;

  RequestProgressResponse({
    required this.success,
    required this.message,
    required this.unitsNeeded,
    required this.unitsPledged,
    required this.unitsReceived,
    required this.unitsRemaining,
    required this.respondersCount,
    required this.pledges,
  });

  factory RequestProgressResponse.fromJson(Map<String, dynamic> json) {
    final List<DonorPledge> pledgeList = [];
    if (json['data'] != null && json['data']['pledges'] != null) {
      for (var item in json['data']['pledges']) {
        pledgeList.add(DonorPledge.fromJson(item));
      }
    }

    final data = json['data'] as Map<String, dynamic>? ?? {};

    return RequestProgressResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      unitsNeeded: data['units_needed'] as int? ?? 0,
      unitsPledged: data['units_pledged'] as int? ?? 0,
      unitsReceived: data['units_received'] as int? ?? 0,
      unitsRemaining: data['units_remaining'] as int? ?? 0,
      respondersCount: data['responders_count'] as int? ?? 0,
      pledges: pledgeList,
    );
  }

  /// Get progress as percentage (0-100)
  double get progressPercentage {
    if (unitsNeeded == 0) return 0;
    return (unitsPledged / unitsNeeded * 100).clamp(0, 100).toDouble();
  }

  /// Check if request is fully pledged
  bool get isFullyPledged => unitsPledged >= unitsNeeded;

  /// Get number of additional donors needed
  int get donorsNeeded => unitsRemaining > 0 ? unitsRemaining : 0;
}
