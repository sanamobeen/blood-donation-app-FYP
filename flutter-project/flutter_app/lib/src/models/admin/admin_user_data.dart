/// Admin User Data Model
/// Represents user information for admin dashboard
class AdminUserData {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String role;
  final String? bloodType;
  final String? city;
  final String? state;
  final String country;
  final String? profilePicture;
  final bool isActive;
  final double profileCompletion;
  final int totalDonations;
  final DateTime? lastDonationDate;
  final DateTime createdAt;
  final DateTime? lastLogin;

  AdminUserData({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    required this.role,
    this.bloodType,
    this.city,
    this.state,
    required this.country,
    this.profilePicture,
    required this.isActive,
    required this.profileCompletion,
    required this.totalDonations,
    this.lastDonationDate,
    required this.createdAt,
    this.lastLogin,
  });

  factory AdminUserData.fromJson(Map<String, dynamic> json) {
    return AdminUserData(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'],
      role: json['role'] ?? 'user',
      bloodType: json['blood_type'] ?? json['bloodType'],
      city: json['city'],
      state: json['state'],
      country: json['country'] ?? '',
      profilePicture: json['profile_picture'] ?? json['profilePicture'],
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      profileCompletion: (json['profile_completion'] ?? json['profileCompletion'] ?? 0).toDouble(),
      totalDonations: json['total_donations'] ?? json['totalDonations'] ?? 0,
      lastDonationDate: json['last_donation_date'] != null
          ? DateTime.parse(json['last_donation_date'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'role': role,
      'blood_type': bloodType,
      'city': city,
      'state': state,
      'country': country,
      'profile_picture': profilePicture,
      'is_active': isActive,
      'profile_completion': profileCompletion,
      'total_donations': totalDonations,
      'last_donation_date': lastDonationDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  /// Get display role name
  String get displayRole {
    switch (role.toLowerCase()) {
      case 'donor':
        return 'Donor';
      case 'patient':
        return 'Patient';
      default:
        return 'User';
    }
  }

  /// Check if user is donor
  bool get isDonor => role.toLowerCase() == 'donor';

  /// Check if user is patient
  bool get isPatient => role.toLowerCase() == 'patient';

  /// Get full location string
  String get fullLocation {
    final parts = [city, state, country].where((p) => p != null && p.isNotEmpty);
    return parts.join(', ');
  }
}
