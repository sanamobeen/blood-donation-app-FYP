/// Admin Dashboard Statistics Model
/// Contains overview statistics for admin dashboard
class AdminDashboardStats {
  final int totalUsers;
  final int totalDonors;
  final int totalPatients;
  final int activeBloodRequests;
  final int fulfilledRequestsThisMonth;
  final int totalDonations;
  final int livesSaved;
  final int activeSOSRequests;

  // Growth percentages (can be null if no previous data)
  final double? usersGrowth;
  final double? donorsGrowth;
  final double? patientsGrowth;
  final double? donationsGrowth;

  AdminDashboardStats({
    required this.totalUsers,
    required this.totalDonors,
    required this.totalPatients,
    required this.activeBloodRequests,
    required this.fulfilledRequestsThisMonth,
    required this.totalDonations,
    required this.livesSaved,
    required this.activeSOSRequests,
    this.usersGrowth,
    this.donorsGrowth,
    this.patientsGrowth,
    this.donationsGrowth,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      totalUsers: json['total_users'] ?? json['totalUsers'] ?? 0,
      totalDonors: json['total_donors'] ?? json['totalDonors'] ?? 0,
      totalPatients: json['total_patients'] ?? json['totalPatients'] ?? 0,
      activeBloodRequests: json['active_blood_requests'] ?? json['activeBloodRequests'] ?? 0,
      fulfilledRequestsThisMonth: json['fulfilled_requests_this_month'] ?? json['fulfilledRequestsThisMonth'] ?? 0,
      totalDonations: json['total_donations'] ?? json['totalDonations'] ?? 0,
      livesSaved: json['lives_saved'] ?? json['livesSaved'] ?? 0,
      activeSOSRequests: json['active_sos_requests'] ?? json['activeSOSRequests'] ?? 0,
      usersGrowth: json['users_growth']?.toDouble(),
      donorsGrowth: json['donors_growth']?.toDouble(),
      patientsGrowth: json['patients_growth']?.toDouble(),
      donationsGrowth: json['donations_growth']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_users': totalUsers,
      'total_donors': totalDonors,
      'total_patients': totalPatients,
      'active_blood_requests': activeBloodRequests,
      'fulfilled_requests_this_month': fulfilledRequestsThisMonth,
      'total_donations': totalDonations,
      'lives_saved': livesSaved,
      'active_sos_requests': activeSOSRequests,
      'users_growth': usersGrowth,
      'donors_growth': donorsGrowth,
      'patients_growth': patientsGrowth,
      'donations_growth': donationsGrowth,
    };
  }
}

/// User Growth Data for Charts
class UserGrowthData {
  final DateTime date;
  final int totalUsers;
  final int newDonors;
  final int newPatients;

  UserGrowthData({
    required this.date,
    required this.totalUsers,
    required this.newDonors,
    required this.newPatients,
  });

  factory UserGrowthData.fromJson(Map<String, dynamic> json) {
    return UserGrowthData(
      date: DateTime.parse(json['date']),
      totalUsers: json['total_users'] ?? 0,
      newDonors: json['new_donors'] ?? 0,
      newPatients: json['new_patients'] ?? 0,
    );
  }
}

/// Blood Type Distribution Data
class BloodTypeDistribution {
  final String bloodType;
  final int count;
  final double percentage;

  BloodTypeDistribution({
    required this.bloodType,
    required this.count,
    required this.percentage,
  });

  factory BloodTypeDistribution.fromJson(Map<String, dynamic> json) {
    return BloodTypeDistribution(
      bloodType: json['blood_type'] ?? '',
      count: json['count'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

/// Donation Statistics Data
class DonationStatsData {
  final DateTime month;
  final int donations;
  final int units;

  DonationStatsData({
    required this.month,
    required this.donations,
    required this.units,
  });

  factory DonationStatsData.fromJson(Map<String, dynamic> json) {
    return DonationStatsData(
      month: DateTime.parse(json['month']),
      donations: json['donations'] ?? 0,
      units: json['units'] ?? 0,
    );
  }
}

/// Geographic Distribution Data
class GeographicDistribution {
  final String city;
  final String? state;
  final int userCount;
  final int donorCount;

  GeographicDistribution({
    required this.city,
    this.state,
    required this.userCount,
    required this.donorCount,
  });

  factory GeographicDistribution.fromJson(Map<String, dynamic> json) {
    return GeographicDistribution(
      city: json['city'] ?? '',
      state: json['state'],
      userCount: json['user_count'] ?? 0,
      donorCount: json['donor_count'] ?? 0,
    );
  }
}

/// Complete Analytics Data Model
class AdminAnalyticsData {
  final List<UserGrowthData> userGrowth;
  final List<BloodTypeDistribution> bloodTypeDistribution;
  final List<DonationStatsData> donationStats;
  final List<GeographicDistribution> geographicDistribution;
  final DateTime startDate;
  final DateTime endDate;

  AdminAnalyticsData({
    required this.userGrowth,
    required this.bloodTypeDistribution,
    required this.donationStats,
    required this.geographicDistribution,
    required this.startDate,
    required this.endDate,
  });

  factory AdminAnalyticsData.fromJson(Map<String, dynamic> json) {
    return AdminAnalyticsData(
      userGrowth: (json['user_growth'] as List? ?? [])
          .map((e) => UserGrowthData.fromJson(e))
          .toList(),
      bloodTypeDistribution: (json['blood_type_distribution'] as List? ?? [])
          .map((e) => BloodTypeDistribution.fromJson(e))
          .toList(),
      donationStats: (json['donation_stats'] as List? ?? [])
          .map((e) => DonationStatsData.fromJson(e))
          .toList(),
      geographicDistribution: (json['geographic_distribution'] as List? ?? [])
          .map((e) => GeographicDistribution.fromJson(e))
          .toList(),
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
    );
  }
}
