/// Profile data model
class Profile {
  final String? id;
  final String? userFullName;
  final String? email;
  final String? username;
  final String? profilePicture;
  final String? profilePictureUrl;
  final String? bloodGroup;
  final int? age;
  final String? gender;
  final double? weight;
  final String? city;
  final DateTime? dateOfBirth;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? role; // 'donor' or 'patient'
  final int? totalDonations; // Total blood donations made by donor

  Profile({
    this.id,
    this.userFullName,
    this.email,
    this.username,
    this.profilePicture,
    this.profilePictureUrl,
    this.bloodGroup,
    this.age,
    this.gender,
    this.weight,
    this.city,
    this.dateOfBirth,
    this.createdAt,
    this.updatedAt,
    this.role,
    this.totalDonations,
  });

  /// Create Profile from JSON
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id']?.toString(),
      userFullName: json['user_full_name']?.toString(),
      email: json['email']?.toString(),
      username: json['username']?.toString(),
      profilePicture: json['profile_picture']?.toString(),
      profilePictureUrl: json['profile_picture_url']?.toString(),
      bloodGroup: json['blood_group']?.toString(),
      age: json['age'] is int ? json['age'] : int.tryParse(json['age']?.toString() ?? ''),
      gender: json['gender']?.toString(),
      weight: json['weight'] is double
          ? json['weight']
          : double.tryParse(json['weight']?.toString() ?? ''),
      city: json['city']?.toString(),
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      role: json['role']?.toString(),
      totalDonations: json['total_donations'] is int
          ? json['total_donations']
          : int.tryParse(json['total_donations']?.toString() ?? '0'),
    );
  }

  /// Convert Profile to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_full_name': userFullName,
      'email': email,
      'username': username,
      'profile_picture': profilePicture,
      'profile_picture_url': profilePictureUrl,
      'blood_group': bloodGroup,
      'age': age,
      'gender': gender,
      'weight': weight,
      'city': city,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'role': role,
      'total_donations': totalDonations,
    };
  }

  /// Create a copy with updated fields
  Profile copyWith({
    String? id,
    String? userFullName,
    String? email,
    String? username,
    String? profilePicture,
    String? profilePictureUrl,
    String? bloodGroup,
    int? age,
    String? gender,
    double? weight,
    String? city,
    DateTime? dateOfBirth,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? role,
    int? totalDonations,
  }) {
    return Profile(
      id: id ?? this.id,
      userFullName: userFullName ?? this.userFullName,
      email: email ?? this.email,
      username: username ?? this.username,
      profilePicture: profilePicture ?? this.profilePicture,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
      city: city ?? this.city,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      role: role ?? this.role,
      totalDonations: totalDonations ?? this.totalDonations,
    );
  }

  /// Check if profile is complete
  bool get isComplete {
    return bloodGroup != null &&
        dateOfBirth != null &&
        gender != null &&
        weight != null &&
        city != null;
  }

  /// Get display name for gender
  String get genderDisplayName {
    switch (gender?.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      case 'prefer_not_to_say':
        return 'Rather not say';
      default:
        return 'Not specified';
    }
  }

  /// Get display name for city
  String get cityDisplayName {
    switch (city?.toLowerCase()) {
      case 'lahore':
        return 'Lahore';
      case 'islamabad':
        return 'Islamabad';
      case 'karachi':
        return 'Karachi';
      case 'multan':
        return 'Multan';
      case 'quetta':
        return 'Quetta';
      default:
        return city ?? 'Unknown';
    }
  }

  @override
  String toString() {
    return 'Profile(id: $id, userFullName: $userFullName, bloodGroup: $bloodGroup, age: $age, gender: $gender, weight: $weight, city: $city, totalDonations: $totalDonations)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Profile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
