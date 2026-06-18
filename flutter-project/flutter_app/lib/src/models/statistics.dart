/// Statistics Models
/// For public and user statistics

/// Public Statistics
class PublicStats {
  final int totalDonors;
  final int totalDonations;
  final int activeRequests;
  final int livesSaved;
  final Map<String, BloodTypeDistribution> bloodTypeDistribution;

  PublicStats({
    required this.totalDonors,
    required this.totalDonations,
    required this.activeRequests,
    required this.livesSaved,
    required this.bloodTypeDistribution,
  });

  factory PublicStats.fromJson(Map<String, dynamic> json) {
    final Map<String, BloodTypeDistribution> distribution = {};
    if (json['blood_type_distribution'] != null) {
      (json['blood_type_distribution'] as Map<String, dynamic>).forEach((key, value) {
        distribution[key] = BloodTypeDistribution.fromJson(value);
      });
    }

    return PublicStats(
      totalDonors: json['total_donors'] as int? ?? 0,
      totalDonations: json['total_donations'] as int? ?? 0,
      activeRequests: json['active_requests'] as int? ?? 0,
      livesSaved: json['lives_saved'] as int? ?? 0,
      bloodTypeDistribution: distribution,
    );
  }
}

/// Blood Type Distribution
class BloodTypeDistribution {
  final int count;
  final int percentage;

  BloodTypeDistribution({
    required this.count,
    required this.percentage,
  });

  factory BloodTypeDistribution.fromJson(Map<String, dynamic> json) {
    return BloodTypeDistribution(
      count: json['count'] as int? ?? 0,
      percentage: json['percentage'] as int? ?? 0,
    );
  }
}

/// User Statistics
class UserStats {
  final int totalDonations;
  final int totalUnitsDonated;
  final int livesSaved;
  final int requestsCreated;
  final int sosResponded;
  final int achievementsCount;
  final int points;

  UserStats({
    required this.totalDonations,
    required this.totalUnitsDonated,
    required this.livesSaved,
    required this.requestsCreated,
    required this.sosResponded,
    required this.achievementsCount,
    required this.points,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalDonations: json['total_donations'] as int? ?? 0,
      totalUnitsDonated: json['total_units_donated'] as int? ?? 0,
      livesSaved: json['lives_saved'] as int? ?? 0,
      requestsCreated: json['requests_created'] as int? ?? 0,
      sosResponded: json['sos_responded'] as int? ?? 0,
      achievementsCount: json['achievements_count'] as int? ?? 0,
      points: json['points'] as int? ?? 0,
    );
  }
}
