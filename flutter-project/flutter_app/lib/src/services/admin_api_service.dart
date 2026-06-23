import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../models/admin/admin_user_data.dart';
import '../models/admin/admin_dashboard_data.dart';

/// Admin API Service
/// Handles all admin-specific API requests
class AdminApiService {
  // Base URL for admin endpoints
  static String get _baseUrl => ApiConfig.getBaseUrl();

  /// Get all users with pagination and filtering
  static Future<AdminUsersResponse> getUsers({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? role,
    String? bloodType,
    String? status,
  }) async {
    try {
      final headers = await ApiService.getAuthHeaders();
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (role != null) 'role': role,
        if (bloodType != null) 'blood_type': bloodType,
        if (status != null) 'status': status,
      };

      final uri = Uri.parse('$_baseUrl/api/admin/users/')
          .replace(queryParameters: queryParams);


      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        // Extract data from wrapped response
        final data = responseJson['data'] ?? responseJson;
        return AdminUsersResponse.fromJson(data);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Unauthorized: Admin access required');
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load users: $e');
    }
  }

  /// Get detailed user information
  static Future<AdminUserDetail> getUserDetail(String userId) async {
    try {
      final headers = await ApiService.getAuthHeaders();
      final uri = Uri.parse('$_baseUrl/api/admin/users/$userId/');


      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        // Extract data from wrapped response
        final data = responseJson['data'] ?? responseJson;
        return AdminUserDetail.fromJson(data);
      } else {
        throw Exception('Failed to load user details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load user details: $e');
    }
  }

  /// Activate user account
  static Future<bool> activateUser(String userId) async {
    try {
      final headers = await ApiService.getAuthHeaders();
      final uri = Uri.parse('$_baseUrl/api/admin/users/$userId/activate/');

      final response = await http.post(uri, headers: headers);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Deactivate user account
  static Future<bool> deactivateUser(String userId) async {
    try {
      final headers = await ApiService.getAuthHeaders();
      final uri = Uri.parse('$_baseUrl/api/admin/users/$userId/deactivate/');

      final response = await http.post(uri, headers: headers);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Delete user account
  static Future<bool> deleteUser(String userId) async {
    try {
      final headers = await ApiService.getAuthHeaders();
      final uri = Uri.parse('$_baseUrl/api/admin/users/$userId/');

      final response = await http.delete(uri, headers: headers);

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get dashboard statistics
  static Future<AdminDashboardStats> getDashboardStats() async {
    try {
      final headers = await ApiService.getAuthHeaders();
      final uri = Uri.parse('$_baseUrl/api/admin/stats/overview/');


      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        // Extract data from wrapped response
        final data = responseJson['data'] ?? responseJson;
        return AdminDashboardStats.fromJson(data);
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load stats: $e');
    }
  }

  /// Get analytics data
  static Future<AdminAnalyticsData> getAnalyticsData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final headers = await ApiService.getAuthHeaders();
      final queryParams = {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      };

      final uri = Uri.parse('$_baseUrl/api/admin/stats/analytics/')
          .replace(queryParameters: queryParams);


      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        // Extract data from wrapped response
        final data = responseJson['data'] ?? responseJson;
        return AdminAnalyticsData.fromJson(data);
      } else {
        throw Exception('Failed to load analytics: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load analytics: $e');
    }
  }

  /// Get all blood requests for admin
  static Future<AdminBloodRequestsResponse> getBloodRequests({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? urgencyLevel,
    String? bloodGroup,
  }) async {
    try {
      final headers = await ApiService.getAuthHeaders();
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (status != null) 'status': status,
        if (urgencyLevel != null) 'urgency_level': urgencyLevel,
        if (bloodGroup != null) 'blood_group': bloodGroup,
      };

      final uri = Uri.parse('$_baseUrl/api/admin/blood-requests/')
          .replace(queryParameters: queryParams);


      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        // Extract data from wrapped response
        final data = responseJson['data'] ?? responseJson;
        return AdminBloodRequestsResponse.fromJson(data);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Unauthorized: Admin access required');
      } else {
        throw Exception('Failed to load blood requests: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load blood requests: $e');
    }
  }

  /// Get detailed blood request information
  static Future<AdminBloodRequestDetail> getBloodRequestDetail(String requestId) async {
    try {
      final headers = await ApiService.getAuthHeaders();
      final uri = Uri.parse('$_baseUrl/api/admin/blood-requests/$requestId/');


      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        // Extract data from wrapped response
        final data = responseJson['data'] ?? responseJson;
        return AdminBloodRequestDetail.fromJson(data);
      } else {
        throw Exception('Failed to load blood request details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load blood request details: $e');
    }
  }
}

/// Admin Users Response Model
class AdminUsersResponse {
  final List<AdminUserData> users;
  final int totalCount;
  final int totalPages;
  final int currentPage;

  AdminUsersResponse({
    required this.users,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
  });

  factory AdminUsersResponse.fromJson(Map<String, dynamic> json) {
    final usersList = json['users'] as List? ?? [];
    return AdminUsersResponse(
      users: usersList.map((e) => AdminUserData.fromJson(e)).toList(),
      totalCount: json['total_count'] ?? json['count'] ?? 0,
      totalPages: json['total_pages'] ?? 1,
      currentPage: json['current_page'] ?? 1,
    );
  }
}

/// Admin User Detail Model
class AdminUserDetail {
  final AdminUserData user;
  final List<dynamic> donations;
  final List<dynamic> bloodRequests;
  final List<dynamic> pledges;
  final List<dynamic> activityLog;

  AdminUserDetail({
    required this.user,
    required this.donations,
    required this.bloodRequests,
    required this.pledges,
    required this.activityLog,
  });

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) {
    return AdminUserDetail(
      user: AdminUserData.fromJson(json['user']),
      donations: json['donations'] ?? [],
      bloodRequests: json['blood_requests'] ?? [],
      pledges: json['pledges'] ?? [],
      activityLog: json['activity_log'] ?? [],
    );
  }
}

/// Admin Blood Requests Response Model
class AdminBloodRequestsResponse {
  final List<AdminBloodRequestData> bloodRequests;
  final int count;
  final int totalPages;
  final int currentPage;
  final int pageSize;
  final bool hasNext;
  final bool hasPrevious;

  AdminBloodRequestsResponse({
    required this.bloodRequests,
    required this.count,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory AdminBloodRequestsResponse.fromJson(Map<String, dynamic> json) {
    final requestsList = json['blood_requests'] as List? ?? [];
    return AdminBloodRequestsResponse(
      bloodRequests: requestsList
          .map((e) => AdminBloodRequestData.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: json['count'] ?? 0,
      totalPages: json['total_pages'] ?? 1,
      currentPage: json['current_page'] ?? 1,
      pageSize: json['page_size'] ?? 20,
      hasNext: json['has_next'] ?? false,
      hasPrevious: json['has_previous'] ?? false,
    );
  }
}

/// Admin Blood Request Data Model
class AdminBloodRequestData {
  final String id;
  final String patientName;
  final String bloodGroup;
  final int unitsNeeded;
  final int unitsPledged;
  final int unitsReceived;
  final int unitsRemaining;
  final String urgencyLevel;
  final String status;
  final bool isActive;
  final String contactNumber;
  final String? hospitalName;
  final String? location;
  final String? additionalNotes;
  final int respondersCount;
  final AdminBloodRequestUser? requestedBy;
  final String createdAt;
  final String updatedAt;

  AdminBloodRequestData({
    required this.id,
    required this.patientName,
    required this.bloodGroup,
    required this.unitsNeeded,
    required this.unitsPledged,
    required this.unitsReceived,
    required this.unitsRemaining,
    required this.urgencyLevel,
    required this.status,
    required this.isActive,
    required this.contactNumber,
    this.hospitalName,
    this.location,
    this.additionalNotes,
    required this.respondersCount,
    this.requestedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminBloodRequestData.fromJson(Map<String, dynamic> json) {
    return AdminBloodRequestData(
      id: json['id'] ?? '',
      patientName: json['patient_name'] ?? '',
      bloodGroup: json['blood_group'] ?? '',
      unitsNeeded: json['units_needed'] ?? 0,
      unitsPledged: json['units_pledged'] ?? 0,
      unitsReceived: json['units_received'] ?? 0,
      unitsRemaining: json['units_remaining'] ?? 0,
      urgencyLevel: json['urgency_level'] ?? 'normal',
      status: json['status'] ?? 'pending',
      isActive: json['is_active'] ?? true,
      contactNumber: json['contact_number'] ?? '',
      hospitalName: json['hospital_name'],
      location: json['location'],
      additionalNotes: json['additional_notes'],
      respondersCount: json['responders_count'] ?? 0,
      requestedBy: json['requested_by'] != null
          ? AdminBloodRequestUser.fromJson(json['requested_by'])
          : null,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

/// Admin Blood Request User Model
class AdminBloodRequestUser {
  final String id;
  final String email;
  final String? fullName;
  final String role;

  AdminBloodRequestUser({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
  });

  factory AdminBloodRequestUser.fromJson(Map<String, dynamic> json) {
    return AdminBloodRequestUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'],
      role: json['role'] ?? '',
    );
  }
}

/// Admin Blood Request Detail Model
class AdminBloodRequestDetail {
  final AdminBloodRequestData bloodRequest;
  final List<AdminBloodRequestPledge> pledges;
  final int pledgesCount;

  AdminBloodRequestDetail({
    required this.bloodRequest,
    required this.pledges,
    required this.pledgesCount,
  });

  factory AdminBloodRequestDetail.fromJson(Map<String, dynamic> json) {
    final pledgesList = json['pledges'] as List? ?? [];
    return AdminBloodRequestDetail(
      bloodRequest: AdminBloodRequestData.fromJson(json['blood_request']),
      pledges: pledgesList
          .map((e) => AdminBloodRequestPledge.fromJson(e as Map<String, dynamic>))
          .toList(),
      pledgesCount: json['pledges_count'] ?? 0,
    );
  }
}

/// Admin Blood Request Pledge Model
class AdminBloodRequestPledge {
  final String id;
  final AdminBloodRequestPledgeDonor? donor;
  final int unitsPledged;
  final String? note;
  final String status;
  final String createdAt;
  final String? donatedAt;

  AdminBloodRequestPledge({
    required this.id,
    this.donor,
    required this.unitsPledged,
    this.note,
    required this.status,
    required this.createdAt,
    this.donatedAt,
  });

  factory AdminBloodRequestPledge.fromJson(Map<String, dynamic> json) {
    return AdminBloodRequestPledge(
      id: json['id'] ?? '',
      donor: json['donor'] != null
          ? AdminBloodRequestPledgeDonor.fromJson(json['donor'])
          : null,
      unitsPledged: json['units_pledged'] ?? 0,
      note: json['note'],
      status: json['status'] ?? 'pledged',
      createdAt: json['created_at'] ?? '',
      donatedAt: json['donated_at'],
    );
  }
}

/// Admin Blood Request Pledge Donor Model
class AdminBloodRequestPledgeDonor {
  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String? bloodGroup;

  AdminBloodRequestPledgeDonor({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    this.bloodGroup,
  });

  factory AdminBloodRequestPledgeDonor.fromJson(Map<String, dynamic> json) {
    return AdminBloodRequestPledgeDonor(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'],
      phone: json['phone'],
      bloodGroup: json['blood_group'],
    );
  }
}
