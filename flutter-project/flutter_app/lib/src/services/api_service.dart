import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/profile.dart';
import '../models/blood_request.dart';

/// API Service for handling all backend requests
class ApiService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';

  // Get stored access token
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  // Get stored refresh token
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // Get current user ID
  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Save tokens
  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  // Save user ID
  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  // Clear tokens
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
  }

  // Get auth headers
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAccessToken();
    if (token != null) {
    } else {
    }
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    try {
      final token = await getAccessToken();
      final isAuth = token != null && token.isNotEmpty;
      return isAuth;
    } catch (e) {
      return false;
    }
  }

  /// Refresh access token using refresh token
  static Future<bool> _refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }


      final response = await http.post(
        Uri.parse('${ApiConfig.authEndpoint}/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['access'] != null) {
          await saveTokens(data['access'], refreshToken);
          return true;
        }
      }

      // If refresh fails, clear tokens (user needs to login again)
      await clearTokens();
      return false;
    } catch (e) {
      await clearTokens();
      return false;
    }
  }

  // ===== AUTH API =====

  /// Login user
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.authEndpoint}/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      // Check if response body is empty
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Save tokens
        if (data['tokens'] != null) {
          await saveTokens(
            data['tokens']['access'],
            data['tokens']['refresh'],
          );
        }

        // Save user ID if available
        if (data['user'] != null && data['user']['id'] != null) {
          await saveUserId(data['user']['id'].toString());
        }

        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Register user
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String? phoneNum,
    String? role,
  }) async {
    try {

      final response = await http.post(
        Uri.parse('${ApiConfig.authEndpoint}/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'password_confirm': password,
          'full_name': fullName,
          if (phoneNum != null) 'phone_num': phoneNum,
          if (role != null) 'role': role,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        // Save tokens
        if (data['tokens'] != null) {
          final accessToken = data['tokens']['access'] as String;
          final refreshToken = data['tokens']['refresh'] as String;


          await saveTokens(accessToken, refreshToken);

          // Save user ID if available
          if (data['user'] != null && data['user']['id'] != null) {
            await saveUserId(data['user']['id'].toString());
          }

          // Verify tokens were saved
          final savedToken = await getAccessToken();

          return {'success': true, 'data': data};
        } else {
          return {'success': true, 'data': data};
        }
      } else {
        return {'success': false, 'message': data['message'] ?? 'Registration failed', 'errors': data['errors']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Logout user
  static Future<Map<String, dynamic>> logout() async {
    try {
      final refreshToken = await getRefreshToken();
      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.authEndpoint}/logout/'),
        headers: headers,
        body: jsonEncode({'refresh': refreshToken}),
      );

      await clearTokens();
      return {'success': true};
    } catch (e) {
      await clearTokens();
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ===== PASSWORD RESET API =====

  /// Forgot password - send reset link
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {

      final response = await http.post(
        Uri.parse('${ApiConfig.authEndpoint}/forgot-password/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'],
          'email': data['email'],
          'reset_token': data['token'] // Only available in DEBUG mode
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to send reset email'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Reset password with token
  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String email,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    try {

      final response = await http.post(
        Uri.parse('${ApiConfig.authEndpoint}/reset-password/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'token': token,
          'new_password': newPassword,
          'confirm_password': newPasswordConfirm,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to reset password', 'errors': data['errors']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Change password (for authenticated users who know their current password)
  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.authEndpoint}/change-password/'),
        headers: headers,
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
          'new_password_confirm': newPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Password changed successfully - new tokens returned
        // Note: Backend returns new tokens, so we should update them
        if (data['data'] != null && data['data']['tokens'] != null) {
          final tokens = data['data']['tokens'];
          final accessToken = tokens['access'] as String?;
          final refreshToken = tokens['refresh'] as String?;
          if (accessToken != null && refreshToken != null) {
            await saveTokens(accessToken, refreshToken);
          }
        }
        return {
          'success': true,
          'message': data['message'] ?? 'Password changed successfully',
          'tokens': data['data']?['tokens'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to change password',
          'errors': data['errors'],
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ===== PROFILE API =====

  /// Create user profile
  static Future<Map<String, dynamic>> createProfile({
    String? bloodGroup,
    String? dateOfBirth,
    String? gender,
    String? weight,
    String? city,
    String? profilePicturePath,
    double? locationLat,
    double? locationLng,
    String? address,
  }) async {
    try {
      // Check if user is authenticated
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'You must be logged in to create a profile',
          'requires_auth': true
        };
      }


      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.authEndpoint}/profile/create/'),
      );

      // Add Authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      if (bloodGroup != null) request.fields['blood_group'] = bloodGroup;
      if (dateOfBirth != null) request.fields['date_of_birth'] = dateOfBirth;
      if (gender != null) request.fields['gender'] = gender;
      if (weight != null) request.fields['weight'] = weight;
      if (city != null) request.fields['city'] = city;

      // Add location fields (for donors)
      if (locationLat != null) request.fields['location_lat'] = locationLat.toString();
      if (locationLng != null) request.fields['location_lng'] = locationLng.toString();
      if (address != null) request.fields['address'] = address;

      // Add profile picture if provided
      if (profilePicturePath != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_picture',
          profilePicturePath,
        ));
      }


      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);


      if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Authentication failed. Please login again.',
          'requires_auth': true
        };
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Profile creation failed', 'errors': data['errors']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get user profile
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final headers = await getAuthHeaders();

      var response = await http.get(
        Uri.parse('${ApiConfig.authEndpoint}/profile/detail/'),
        headers: headers,
      );

      // Handle 401 - try to refresh token and retry
      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();

        if (refreshed) {
          final newHeaders = await getAuthHeaders();
          response = await http.get(
            Uri.parse('${ApiConfig.authEndpoint}/profile/detail/'),
            headers: newHeaders,
          );
        }
      }

      // Check if response body is empty
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      // Try to parse JSON
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch profile'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    String? bloodGroup,
    String? dateOfBirth,
    String? gender,
    String? weight,
    String? city,
    String? profilePicturePath,
    double? locationLat,
    double? locationLng,
    String? address,
  }) async {
    try {
      final headers = await getAuthHeaders();

      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${ApiConfig.authEndpoint}/profile/update/full/'),
      );

      request.headers.addAll({
        'Authorization': headers['Authorization'] ?? '',
      });

      // Add text fields
      if (bloodGroup != null) request.fields['blood_group'] = bloodGroup;
      if (dateOfBirth != null) request.fields['date_of_birth'] = dateOfBirth;
      if (gender != null) request.fields['gender'] = gender;
      if (weight != null) request.fields['weight'] = weight;
      if (city != null) request.fields['city'] = city;

      // Add location fields
      if (locationLat != null) request.fields['location_lat'] = locationLat.toString();
      if (locationLng != null) request.fields['location_lng'] = locationLng.toString();
      if (address != null) request.fields['address'] = address;

      // Add profile picture if provided
      if (profilePicturePath != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_picture',
          profilePicturePath,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Profile update failed', 'errors': data['errors']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Delete user profile
  static Future<Map<String, dynamic>> deleteProfile() async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.delete(
        Uri.parse('${ApiConfig.authEndpoint}/profile/delete/'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Profile deletion failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update user role
  static Future<Map<String, dynamic>> updateUserRole(String newRole) async {
    try {
      var headers = await getAuthHeaders();


      var response = await http.patch(
        Uri.parse('${ApiConfig.authEndpoint}/profile/update-role/'),
        headers: headers,
        body: jsonEncode({'role': newRole}),
      );


      // Handle 401 - try to refresh token and retry
      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();

        if (refreshed) {
          headers = await getAuthHeaders();
          response = await http.patch(
            Uri.parse('${ApiConfig.authEndpoint}/profile/update-role/'),
            headers: headers,
            body: jsonEncode({'role': newRole}),
          );
        } else {
          return {'success': false, 'message': 'Session expired. Please login again.'};
        }
      }


      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // Backend returns: {success: true, message: "...", data: {user: {...}}}

        if (responseData['success'] == true) {
          // Return the response with success=true and user data
          return {
            'success': true,
            'message': responseData['message'] ?? 'Role updated successfully',
            'user': responseData['data']?['user']
          };
        }
        return {'success': false, 'message': 'Failed to update role'};
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Session expired. Please login again.'};
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {'success': false, 'message': errorData['message'] ?? 'Role update failed'};
        } catch (e) {
          return {'success': false, 'message': 'Role update failed with status ${response.statusCode}'};
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ===== BLOOD REQUEST API =====

  /// Get all blood requests (public endpoint, but sends auth to exclude own requests)
  static Future<BloodRequestListResponse> getBloodRequests({
    String? bloodGroup,
    String? urgencyLevel,
    String? status = 'pending',
  }) async {
    try {

      // Build query parameters
      final queryParams = <String, String>{
        if (bloodGroup != null) 'blood_group': bloodGroup,
        if (urgencyLevel != null) 'urgency_level': urgencyLevel,
        if (status != null) 'status': status,
      };

      final uri = Uri.parse('${ApiConfig.bloodRequestsEndpoint}')
          .replace(queryParameters: queryParams);

      // Get auth headers to exclude user's own requests
      final headers = await getAuthHeaders();
      final response = await http.get(uri, headers: headers);


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BloodRequestListResponse.fromJson(data);
      } else {
        return BloodRequestListResponse(
          success: false,
          message: 'Failed to fetch blood requests',
          bloodRequests: [],
          count: 0,
        );
      }
    } catch (e) {
      return BloodRequestListResponse(
        success: false,
        message: 'Network error: $e',
        bloodRequests: [],
        count: 0,
      );
    }
  }

  /// Create a new blood request (public endpoint)
  static Future<Map<String, dynamic>> createBloodRequest({
    required String patientName,
    required String bloodGroup,
    required int unitsNeeded,
    required String urgencyLevel,
    required String contactNumber,
    String? hospitalName,
    String? location,
    String? additionalNotes,
    double? locationLat,
    double? locationLng,
  }) async {
    try {

      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/create/'),
        headers: headers,
        body: jsonEncode({
          'patient_name': patientName,
          'blood_group': bloodGroup,
          'units_needed': unitsNeeded,
          'urgency_level': urgencyLevel,
          'contact_number': contactNumber,
          if (hospitalName != null && hospitalName.isNotEmpty) 'hospital_name': hospitalName,
          if (location != null && location.isNotEmpty) 'location': location,
          if (additionalNotes != null && additionalNotes.isNotEmpty) 'additional_notes': additionalNotes,
          if (locationLat != null && locationLng != null) 'location_lat': locationLat,
          if (locationLat != null && locationLng != null) 'location_lng': locationLng,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'],
          'blood_request': data['blood_request'] != null
              ? BloodRequest.fromJson(data['blood_request'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create blood request',
          'errors': data['errors'],
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get a specific blood request detail (public endpoint, but sends auth for consistency)
  static Future<BloodRequestDetailResponse> getBloodRequestDetail(String requestId) async {
    print('🐛 [ApiService.getBloodRequestDetail] Fetching request ID: $requestId');

    try {

      // Get auth headers for consistency
      final headers = await getAuthHeaders();
      final url = Uri.parse('${ApiConfig.bloodRequestsEndpoint}/$requestId/');
      print('🐛 [ApiService.getBloodRequestDetail] URL: $url');

      final response = await http.get(
        url,
        headers: headers,
      );

      print('🐛 [ApiService.getBloodRequestDetail] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🐛 [ApiService.getBloodRequestDetail] Response data keys: ${data.keys.toList()}');

        // Check if blood_request exists in response
        if (data['blood_request'] != null) {
          final bloodRequestData = data['blood_request'] as Map<String, dynamic>;
          print('🐛 [ApiService.getBloodRequestDetail] blood_request keys: ${bloodRequestData.keys.toList()}');
          print('🐛 [ApiService.getBloodRequestDetail] blood_request.share_id: ${bloodRequestData['share_id']}');
          print('🐛 [ApiService.getBloodRequestDetail] blood_request.id: ${bloodRequestData['id']}');
        } else {
          print('🐛 [ApiService.getBloodRequestDetail] ERROR: blood_request is null in response!');
        }

        return BloodRequestDetailResponse.fromJson(data);
      } else {
        print('🐛 [ApiService.getBloodRequestDetail] ERROR: Status code ${response.statusCode}');
        print('🐛 [ApiService.getBloodRequestDetail] Response body: ${response.body}');
        return BloodRequestDetailResponse(
          success: false,
          message: 'Failed to fetch blood request detail',
        );
      }
    } catch (e) {
      print('🐛 [ApiService.getBloodRequestDetail] EXCEPTION: $e');
      return BloodRequestDetailResponse(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  /// Update a blood request (requires authentication)
  static Future<Map<String, dynamic>> updateBloodRequest({
    required String requestId,
    String? status,
    bool? isActive,
    String? additionalNotes,
  }) async {
    try {

      final headers = await getAuthHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/$requestId/update/'),
        headers: headers,
        body: jsonEncode({
          if (status != null) 'status': status,
          if (isActive != null) 'is_active': isActive,
          if (additionalNotes != null) 'additional_notes': additionalNotes,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'],
          'blood_request': data['blood_request'] != null
              ? BloodRequest.fromJson(data['blood_request'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update blood request',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Delete a blood request (soft delete, requires authentication)
  static Future<Map<String, dynamic>> deleteBloodRequest(String requestId) async {
    try {

      final headers = await getAuthHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/$requestId/delete/'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to delete blood request'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get current user's blood requests (requires authentication)
  /// Optional status filter: 'active', 'completed', or 'all' (default)
  static Future<BloodRequestListResponse> getMyBloodRequests({String? status}) async {
    try {

      final headers = await getAuthHeaders();
      // Build URL with optional status parameter
      final uri = status != null && status.isNotEmpty
          ? Uri.parse('${ApiConfig.bloodRequestsEndpoint}/my-requests/?status=$status')
          : Uri.parse('${ApiConfig.bloodRequestsEndpoint}/my-requests/');

      var response = await http.get(uri, headers: headers);


      // Handle 401 - try to refresh token and retry
      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();

        if (refreshed) {
          // Retry with new token
          final newHeaders = await getAuthHeaders();
          response = await http.get(uri, headers: newHeaders);
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BloodRequestListResponse.fromJson(data);
      } else {
        return BloodRequestListResponse(
          success: false,
          message: 'Failed to fetch your blood requests',
          bloodRequests: [],
          count: 0,
        );
      }
    } catch (e) {
      return BloodRequestListResponse(
        success: false,
        message: 'Network error: $e',
        bloodRequests: [],
        count: 0,
      );
    }
  }

  /// Get all available donors
  static Future<Map<String, dynamic>> getDonors({
    String? bloodGroup,
    String? city,
  }) async {
    try {

      // Build query parameters
      final queryParams = <String, String>{};
      if (bloodGroup != null) queryParams['blood_type'] = bloodGroup;
      if (city != null) queryParams['city'] = city;

      // Build URL with query parameters
      var uri = Uri.parse('${ApiConfig.authEndpoint}/donors/');
      if (queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http.get(uri);


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch donors',
          'donors': [],
          'count': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
        'donors': [],
        'count': 0,
      };
    }
  }

  // ===== OTP API =====

  /// Send OTP to phone number
  static Future<Map<String, dynamic>> sendOtp(String phoneNum) async {
    try {

      final response = await http.post(
        Uri.parse('${ApiConfig.authEndpoint}/send-otp/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_num': phoneNum}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to send OTP'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Verify OTP code
  static Future<Map<String, dynamic>> verifyOtp(String phoneNum, String otpCode) async {
    try {

      final response = await http.post(
        Uri.parse('${ApiConfig.authEndpoint}/verify-otp/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_num': phoneNum, 'otp_code': otpCode}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to verify OTP'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Resend OTP
  static Future<Map<String, dynamic>> resendOtp(String phoneNum) async {
    return await sendOtp(phoneNum);
  }

  // ===== DONOR PROFILE API =====

  /// Toggle donor availability
  static Future<Map<String, dynamic>> toggleAvailability() async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.authEndpoint}/donor/toggle-availability/'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to update availability'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update donor location
  static Future<Map<String, dynamic>> updateLocation({
    required double lat,
    required double lng,
    String? address,
    String? city,
    String? state,
    String? country,
    String? postalCode,
  }) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.patch(
        Uri.parse('${ApiConfig.authEndpoint}/donor/update-location/'),
        headers: headers,
        body: jsonEncode({
          'location_lat': lat,
          'location_lng': lng,
          if (address != null) 'address': address,
          if (city != null) 'city': city,
          if (state != null) 'state': state,
          if (country != null) 'country': country,
          if (postalCode != null) 'postal_code': postalCode,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to update location'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get nearby donors
  static Future<Map<String, dynamic>> getNearbyDonors({
    required double lat,
    required double lng,
    double radius = 50,
    String? bloodType,
  }) async {
    try {

      final queryParams = <String, String>{
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius': radius.toString(),
        if (bloodType != null) 'blood_type': bloodType,
      };

      final uri = Uri.parse('${ApiConfig.authEndpoint}/donors/nearby/')
          .replace(queryParameters: queryParams);

      final headers = await getAuthHeaders();
      var response = await http.get(uri, headers: headers);

      // Handle 401 - try to refresh token and retry
      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();

        if (refreshed) {
          final newHeaders = await getAuthHeaders();
          response = await http.get(uri, headers: newHeaders);
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch nearby donors',
          'donors': [],
          'count': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
        'donors': [],
        'count': 0,
      };
    }
  }

  // ===== BLOOD REQUEST EXTENSIONS =====

  /// Cancel blood request
  static Future<Map<String, dynamic>> cancelBloodRequest(String requestId) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/$requestId/cancel/'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to cancel request'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get nearby blood requests (sends auth to exclude user's own requests)
  static Future<Map<String, dynamic>> getNearbyBloodRequests({
    required double lat,
    required double lng,
    double radius = 50,
    String? bloodType,
  }) async {
    try {

      final queryParams = <String, String>{
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius': radius.toString(),
        if (bloodType != null) 'blood_type': bloodType,
      };

      final uri = Uri.parse('${ApiConfig.bloodRequestsEndpoint}/nearby/')
          .replace(queryParameters: queryParams);

      // Get auth headers to exclude user's own requests
      final headers = await getAuthHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch nearby requests',
          'requests': [],
          'count': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
        'requests': [],
        'count': 0,
      };
    }
  }

  // ===== PLEDGE API =====

  /// Create a pledge for a blood request
  static Future<Map<String, dynamic>> createPledge({
    required String requestId,
    required int unitsPledged,
    String? note,
  }) async {
    try {

      final headers = await getAuthHeaders();

      final requestBody = jsonEncode({
        'units_pledged': unitsPledged,
        if (note != null) 'note': note,
      });

      final response = await http.post(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/$requestId/pledge/'),
        headers: headers,
        body: requestBody,
      );


      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        if (data['errors'] != null) {
        }
        return {'success': false, 'message': data['message'] ?? 'Failed to create pledge', 'errors': data['errors']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get all pledges for a blood request (sends auth for proper permissions)
  static Future<Map<String, dynamic>> getRequestPledges(String requestId) async {
    try {

      // Get auth headers for proper permissions
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/$requestId/pledges/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch pledges',
          'pledges': [],
          'count': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
        'pledges': [],
        'count': 0,
      };
    }
  }

  /// Get request progress (sends auth for proper permissions)
  static Future<Map<String, dynamic>> getRequestProgress(String requestId) async {
    try {

      // Get auth headers for proper permissions
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/$requestId/progress/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch progress',
          'data': null,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
        'data': null,
      };
    }
  }

  /// Cancel a pledge
  static Future<Map<String, dynamic>> cancelPledge(String pledgeId) async {
    try {

      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/pledges/$pledgeId/cancel/'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to cancel pledge'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Check donor eligibility to pledge/donate
  static Future<Map<String, dynamic>> getDonorEligibility() async {
    try {

      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/donor-eligibility/'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to check eligibility'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ===== SOS API =====

  /// Create SOS emergency request
  static Future<Map<String, dynamic>> createSosRequest({
    required String bloodType,
    required String hospitalName,
    required String hospitalAddress,
    required String contactPhone,
    required String patientName,
    required int age,
    required String gender,
    int unitsNeeded = 1,
    double? hospitalLat,
    double? hospitalLng,
  }) async {
    try {

      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.sosEndpoint}/'),
        headers: headers,
        body: jsonEncode({
          'blood_type': bloodType,
          'hospital_name': hospitalName,
          'hospital_address': hospitalAddress,
          'contact_phone': contactPhone,
          'patient_name': patientName,
          'age': age,
          'gender': gender,
          'units_needed': unitsNeeded,
          if (hospitalLat != null) 'hospital_lat': hospitalLat,
          if (hospitalLng != null) 'hospital_lng': hospitalLng,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to create SOS request'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get active SOS requests
  static Future<Map<String, dynamic>> getActiveSosRequests({
    required double lat,
    required double lng,
    double radius = 100,
    String? bloodType,
  }) async {
    try {

      final queryParams = <String, String>{
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius': radius.toString(),
        if (bloodType != null) 'blood_type': bloodType,
      };

      final uri = Uri.parse('${ApiConfig.sosEndpoint}/active/')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch SOS requests',
          'requests': [],
          'count': 0,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
        'requests': [],
        'count': 0,
      };
    }
  }

  /// Get SOS details
  static Future<Map<String, dynamic>> getSosDetail(String sosId) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.sosEndpoint}/$sosId/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to fetch SOS details'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Respond to SOS
  static Future<Map<String, dynamic>> respondToSos({
    required String sosId,
    bool canHelp = true,
    int? estimatedArrivalMinutes,
    String? note,
  }) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.sosEndpoint}/$sosId/respond/'),
        headers: headers,
        body: jsonEncode({
          'can_help': canHelp,
          if (estimatedArrivalMinutes != null) 'estimated_arrival_minutes': estimatedArrivalMinutes,
          if (note != null) 'note': note,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to respond to SOS'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Resolve SOS
  static Future<Map<String, dynamic>> resolveSos({
    required String sosId,
    String? resolutionNote,
  }) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.sosEndpoint}/$sosId/resolve/'),
        headers: headers,
        body: jsonEncode({
          if (resolutionNote != null) 'resolution_note': resolutionNote,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to resolve SOS'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Cancel SOS
  static Future<Map<String, dynamic>> cancelSos(String sosId) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.sosEndpoint}/$sosId/cancel/'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to cancel SOS'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ===== STATISTICS API =====

  /// Get public statistics
  static Future<Map<String, dynamic>> getPublicStats() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.statsEndpoint}/public/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': 'Failed to fetch statistics'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get user statistics
  static Future<Map<String, dynamic>> getUserStats() async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.statsEndpoint}/user/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': 'Failed to fetch your statistics'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ===== DONATION ACKNOWLEDGMENT API =====

  /// Create donation linked to blood request
  static Future<Map<String, dynamic>> createDonationForRequest({
    required String bloodRequestId,
    required int bloodTypeId,
    required int units,
    required String donationDate,
    String? donationCenter,
    String? donationCenterAddress,
    double? hemoglobinLevel,
    String? bloodPressure,
    String? healthStatus,
    String? notes,
  }) async {
    try {

      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.donationsEndpoint}/'),
        headers: headers,
        body: jsonEncode({
          'blood_request': bloodRequestId,
          'blood_type': bloodTypeId,
          'units': units,
          'donation_date': donationDate,
          if (donationCenter != null) 'donation_center': donationCenter,
          if (donationCenterAddress != null) 'donation_center_address': donationCenterAddress,
          if (hemoglobinLevel != null) 'hemoglobin_level': hemoglobinLevel,
          if (bloodPressure != null) 'blood_pressure': bloodPressure,
          if (healthStatus != null) 'health_status': healthStatus,
          if (notes != null) 'notes': notes,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to record donation'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Acknowledge donation (patient confirms)
  static Future<Map<String, dynamic>> acknowledgeDonation(String donationId) async {
    try {

      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.donationsEndpoint}/$donationId/acknowledge'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to acknowledge donation'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get donation certificate
  static Future<Map<String, dynamic>> getDonationCertificate(String donationId) async {
    try {

      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.donationsEndpoint}/$donationId/certificate/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Return the response as is - certificate fields are at root level
        return data;
      } else {
        return {'success': false, 'message': 'Failed to get certificate'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get blood request responses (who donated)
  static Future<Map<String, dynamic>> getBloodRequestResponses(String requestId) async {
    try {

      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.donationsEndpoint}/request-responses/$requestId/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': 'Failed to get responses'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get my donations with acknowledgment status
  static Future<Map<String, dynamic>> getMyDonationsWithStatus() async {
    try {
      final headers = await getAuthHeaders();

      var response = await http.get(
        Uri.parse('${ApiConfig.donationsEndpoint}/my/'),
        headers: headers,
      );

      // Handle 401 - try to refresh token
      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          final newHeaders = await getAuthHeaders();
          response = await http.get(
            Uri.parse('${ApiConfig.donationsEndpoint}/my/'),
            headers: newHeaders,
          );
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to fetch donations'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ===== BLOOD TYPES API =====

  /// Get all blood types
  static Future<Map<String, dynamic>> getBloodTypes() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.bloodTypesEndpoint}/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to fetch blood types'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ===== MESSAGING API =====

  /// Get all conversations
  static Future<Map<String, dynamic>> getConversations() async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.chatEndpoint}/conversations/'),
        headers: headers,
      );

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          final newHeaders = await getAuthHeaders();
          final retryResponse = await http.get(
            Uri.parse('${ApiConfig.chatEndpoint}/conversations/'),
            headers: newHeaders,
          );
          if (retryResponse.statusCode == 200) {
            final data = jsonDecode(retryResponse.body);
            return {'success': true, 'data': data};
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to fetch conversations'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get conversation messages
  static Future<Map<String, dynamic>> getConversationMessages(String conversationId) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.chatEndpoint}/conversations/$conversationId/messages/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to fetch messages'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Create a new conversation
  static Future<Map<String, dynamic>> createConversation({
    required String bloodRequestId,
    required String participantId,
  }) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.chatEndpoint}/conversations/create/'),
        headers: headers,
        body: jsonEncode({
          'blood_request_id': bloodRequestId,
          'participant_id': participantId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to create conversation'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Send message
  static Future<Map<String, dynamic>> sendMessage({
    String? conversationId,
    String? recipientId,
    required String content,
    String? relatedRequestId,
  }) async {
    try {
      final headers = await getAuthHeaders();

      // If no conversation ID, we need to create one first
      if (conversationId == null && relatedRequestId != null && recipientId != null) {
        final convResult = await createConversation(
          bloodRequestId: relatedRequestId,
          participantId: recipientId,
        );

        if (convResult['success'] == true && convResult['data'] != null) {
          final conversationData = convResult['data']['conversation'];
          conversationId = conversationData['id'];
        } else {
          return {'success': false, 'message': 'Failed to create conversation'};
        }
      }

      if (conversationId == null) {
        return {'success': false, 'message': 'Conversation ID is required'};
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.chatEndpoint}/conversations/$conversationId/send/'),
        headers: headers,
        body: jsonEncode({
          'content': content,
          'message_type': 'text',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to send message'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Mark messages as read
  /// Note: Django backend automatically marks messages as read when fetching messages via getConversationMessages
  static Future<Map<String, dynamic>> markMessagesAsRead(String conversationId) async {
    // Backend auto-marks as read on getConversationMessages, so this is a no-op
    return {'success': true, 'message': 'Messages automatically marked as read on fetch'};
  }

  /// Delete conversation
  static Future<Map<String, dynamic>> deleteConversation(String conversationId) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.delete(
        Uri.parse('${ApiConfig.messagesEndpoint}/conversations/$conversationId/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to delete conversation'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ===== NOTIFICATIONS API =====

  /// Get notifications
  static Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    bool? isRead,
    String? type,
  }) async {
    try {
      final headers = await getAuthHeaders();

      final queryParams = <String, String>{
        'page': page.toString(),
        if (isRead != null) 'is_read': isRead.toString(),
        if (type != null) 'type': type,
      };

      final uri = Uri.parse('${ApiConfig.notificationsEndpoint}/')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          final newHeaders = await getAuthHeaders();
          final retryResponse = await http.get(uri, headers: newHeaders);
          if (retryResponse.statusCode == 200) {
            final data = jsonDecode(retryResponse.body);
            return {'success': true, 'data': data};
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to fetch notifications'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get unread notifications count
  static Future<Map<String, dynamic>> getUnreadNotificationsCount() async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.notificationsEndpoint}/unread-count/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'unread_count': data['unread_count'] as int? ?? 0
        };
      } else {
        return {'success': false, 'message': 'Failed to get unread count'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Mark notification as read
  static Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.notificationsEndpoint}/$notificationId/mark-read/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to mark notification as read'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Mark all notifications as read
  static Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.post(
        Uri.parse('${ApiConfig.notificationsEndpoint}/mark-all-read/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to mark all as read'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Delete notification
  static Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.delete(
        Uri.parse('${ApiConfig.notificationsEndpoint}/$notificationId/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'message': 'Failed to delete notification'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get notification preferences
  static Future<Map<String, dynamic>> getNotificationPreferences() async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.notificationsEndpoint}/preferences/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to fetch preferences'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update notification preferences
  static Future<Map<String, dynamic>> updateNotificationPreferences(Map<String, dynamic> preferences) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.patch(
        Uri.parse('${ApiConfig.notificationsEndpoint}/preferences/'),
        headers: headers,
        body: jsonEncode(preferences),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to update preferences'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ===== MEDICAL INFO API =====

  /// Update medical information (medications, allergies, health conditions)
  static Future<Map<String, dynamic>> updateMedicalInfo({
    required List<String> medications,
    required List<String> allergies,
    required List<String> healthConditions,
  }) async {
    try {
      final headers = await getAuthHeaders();


      final response = await http.patch(
        Uri.parse('${ApiConfig.authEndpoint}/profile/update-medical/'),
        headers: headers,
        body: jsonEncode({
          'medications': medications,
          'allergies': allergies,
          'health_conditions': healthConditions,
        }),
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Failed to update medical info'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ===== ACHIEVEMENTS API =====

  /// Get all achievements
  static Future<Map<String, dynamic>> getAchievements() async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.achievementsEndpoint}/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to fetch achievements'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get my achievements
  static Future<Map<String, dynamic>> getMyAchievements() async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.achievementsEndpoint}/my/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to fetch my achievements'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get achievement details
  static Future<Map<String, dynamic>> getAchievementDetails(String achievementId) async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.achievementsEndpoint}/$achievementId/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to fetch achievement details'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ===== HEALTH ELIGIBILITY API =====
  // Quiz feature removed from donor side
  // The following methods have been disabled:
  // - getHealthQuiz()
  // - submitHealthQuiz()
  // - checkEligibilityStatus()

  // ===== SEARCH API =====

  /// Search donors
  static Future<Map<String, dynamic>> searchDonors({
    String? query,
    String? bloodType,
    String? city,
    double? lat,
    double? lng,
    double? radius,
  }) async {
    try {
      final queryParams = <String, String>{
        if (query != null) 'q': query,
        if (bloodType != null) 'blood_type': bloodType,
        if (city != null) 'city': city,
        if (lat != null) 'lat': lat.toString(),
        if (lng != null) 'lng': lng.toString(),
        if (radius != null) 'radius': radius.toString(),
      };

      final uri = Uri.parse('${ApiConfig.searchEndpoint}/donors/')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to search donors'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Search blood requests
  static Future<Map<String, dynamic>> searchBloodRequests({
    String? bloodType,
    String? urgency,
    String? city,
    double? lat,
    double? lng,
    double? radius,
  }) async {
    try {
      final queryParams = <String, String>{
        if (bloodType != null) 'blood_type': bloodType,
        if (urgency != null) 'urgency': urgency,
        if (city != null) 'city': city,
        if (lat != null) 'lat': lat.toString(),
        if (lng != null) 'lng': lng.toString(),
        if (radius != null) 'radius': radius.toString(),
      };

      final uri = Uri.parse('${ApiConfig.searchEndpoint}/requests/')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to search requests'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ===== ADMIN DASHBOARD API =====

  /// Get dashboard summary statistics
  static Future<Map<String, dynamic>> getDashboardSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {

      final headers = await getAuthHeaders();

      final queryParams = <String, String>{
        if (startDate != null) 'start': _formatDate(startDate),
        if (endDate != null) 'end': _formatDate(endDate),
      };

      final uri = Uri.parse('${ApiConfig.adminEndpoint}/dashboard/summary/')
          .replace(queryParameters: queryParams);

      var response = await http.get(uri, headers: headers);

      // Handle 401 - try to refresh token
      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();

        if (refreshed) {
          final newHeaders = await getAuthHeaders();
          response = await http.get(uri, headers: newHeaders);
        }
      }


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 403) {
        return {'success': false, 'message': 'Admin access required'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch summary'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get dashboard analytics (chart data)
  static Future<Map<String, dynamic>> getDashboardAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {

      final headers = await getAuthHeaders();

      final queryParams = <String, String>{
        if (startDate != null) 'start': _formatDate(startDate),
        if (endDate != null) 'end': _formatDate(endDate),
      };

      final uri = Uri.parse('${ApiConfig.adminEndpoint}/dashboard/analytics/')
          .replace(queryParameters: queryParams);

      var response = await http.get(uri, headers: headers);

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          final newHeaders = await getAuthHeaders();
          response = await http.get(uri, headers: newHeaders);
        }
      }


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch analytics'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get recent activity feed
  static Future<Map<String, dynamic>> getDashboardActivity({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {

      final headers = await getAuthHeaders();

      final queryParams = <String, String>{
        if (startDate != null) 'start': _formatDate(startDate),
        if (endDate != null) 'end': _formatDate(endDate),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('${ApiConfig.adminEndpoint}/dashboard/activity/')
          .replace(queryParameters: queryParams);

      var response = await http.get(uri, headers: headers);

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          final newHeaders = await getAuthHeaders();
          response = await http.get(uri, headers: newHeaders);
        }
      }


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch activity'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get dashboard location data
  static Future<Map<String, dynamic>> getDashboardLocations({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  }) async {
    try {

      final headers = await getAuthHeaders();

      final queryParams = <String, String>{
        if (startDate != null) 'start': _formatDate(startDate),
        if (endDate != null) 'end': _formatDate(endDate),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('${ApiConfig.adminEndpoint}/dashboard/locations/')
          .replace(queryParameters: queryParams);

      var response = await http.get(uri, headers: headers);

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          final newHeaders = await getAuthHeaders();
          response = await http.get(uri, headers: newHeaders);
        }
      }


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch locations'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get blood type statistics
  static Future<Map<String, dynamic>> getDashboardBloodTypes({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {

      final headers = await getAuthHeaders();

      final queryParams = <String, String>{
        if (startDate != null) 'start': _formatDate(startDate),
        if (endDate != null) 'end': _formatDate(endDate),
      };

      final uri = Uri.parse('${ApiConfig.adminEndpoint}/dashboard/blood-types/')
          .replace(queryParameters: queryParams);

      var response = await http.get(uri, headers: headers);

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          final newHeaders = await getAuthHeaders();
          response = await http.get(uri, headers: newHeaders);
        }
      }


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch blood types'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get dashboard trends comparison
  static Future<Map<String, dynamic>> getDashboardTrends({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {

      final headers = await getAuthHeaders();

      final queryParams = <String, String>{
        if (startDate != null) 'start': _formatDate(startDate),
        if (endDate != null) 'end': _formatDate(endDate),
      };

      final uri = Uri.parse('${ApiConfig.adminEndpoint}/dashboard/trends/')
          .replace(queryParameters: queryParams);

      var response = await http.get(uri, headers: headers);

      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          final newHeaders = await getAuthHeaders();
          response = await http.get(uri, headers: newHeaders);
        }
      }


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch trends'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Helper: Format DateTime to YYYY-MM-DD string
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================================
  // Patient Pledge Management Methods
  // ============================================================================

  /// Get pledged donors for a blood request (patient only)
  static Future<Map<String, dynamic>> getPledgedDonorsForPatient(String requestId) async {
    try {

      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/$requestId/pledges/patient/'),
        headers: headers,
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 403) {
        return {'success': false, 'message': 'You are not authorized to view these pledges'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch pledged donors'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Accept a donor's pledge (patient only)
  static Future<Map<String, dynamic>> acceptPledge({
    required String requestId,
    required String pledgeId,
    String? patientNote,
  }) async {
    try {
      print('DEBUG acceptPledge: requestId=$requestId, pledgeId=$pledgeId');

      final headers = await getAuthHeaders();
      print('DEBUG acceptPledge: Headers=$headers');

      final url = '${ApiConfig.bloodRequestsEndpoint}/$requestId/pledges/$pledgeId/accept/';
      print('DEBUG acceptPledge: URL=$url');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          if (patientNote != null) 'patient_note': patientNote,
        }),
      );

      print('DEBUG acceptPledge: Status code=${response.statusCode}');
      print('DEBUG acceptPledge: Response body=${response.body}');

      // Try to parse as JSON, but handle non-JSON responses
      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (jsonError) {
        print('DEBUG acceptPledge: JSON parse error: $jsonError');
        print('DEBUG acceptPledge: Response is not valid JSON');
        return {
          'success': false,
          'message': 'Server returned non-JSON response. Status: ${response.statusCode}. Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}'
        };
      }

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message']?.toString() ?? data['detail']?.toString() ?? 'Failed to accept pledge'};
      }
    } catch (e) {
      print('DEBUG acceptPledge: Exception=$e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Reject a donor's pledge (patient only)
  static Future<Map<String, dynamic>> rejectPledge({
    required String requestId,
    required String pledgeId,
    String? reason,
  }) async {
    try {

      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/$requestId/pledges/$pledgeId/reject/'),
        headers: headers,
        body: jsonEncode({
          if (reason != null) 'reason': reason,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to reject pledge'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Accept multiple pledges at once (patient only)
  static Future<Map<String, dynamic>> acceptPledgesBatch({
    required String requestId,
    required List<String> pledgeIds,
    String? patientNote,
  }) async {
    try {

      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/$requestId/pledges/accept-batch/'),
        headers: headers,
        body: jsonEncode({
          'pledge_ids': pledgeIds,
          if (patientNote != null) 'patient_note': patientNote,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to accept pledges'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Confirm donation received from donor (patient only)
  static Future<Map<String, dynamic>> confirmDonation({
    required String requestId,
    required String pledgeId,
    required int unitsReceived,
    String? patientNote,
  }) async {
    try {

      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/$requestId/pledges/$pledgeId/confirm-donation/'),
        headers: headers,
        body: jsonEncode({
          'units_received': unitsReceived,
          if (patientNote != null) 'patient_note': patientNote,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to confirm donation'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Complete donation from a pledge (patient only) - Simplified endpoint
  static Future<Map<String, dynamic>> completePledgeDonation({
    required String requestId,
    required String pledgeId,
    required int unitsDonated,
    String? patientNote,
  }) async {
    try {

      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/$requestId/pledges/$pledgeId/complete/'),
        headers: headers,
        body: jsonEncode({
          'units_donated': unitsDonated,
          if (patientNote != null) 'patient_note': patientNote,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to complete donation'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get current donor's pledges with status
  static Future<Map<String, dynamic>> getMyPledges({String? status}) async {
    try {

      final headers = await getAuthHeaders();
      String url = '${ApiConfig.bloodRequestsEndpoint}/my-pledges/';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch your pledges',
          'pledges': [],
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get all responding donors for patient's blood requests
  static Future<Map<String, dynamic>> getRespondingDonorsForPatient() async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.bloodRequestsEndpoint}/responding-donors/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch responding donors',
          'donors': [],
          'summary': {'total_donors': 0},
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
        'donors': [],
        'summary': {'total_donors': 0},
      };
    }
  }

  // ===== PROFILE EDIT API =====

  /// Upload profile picture
  static Future<Map<String, dynamic>> uploadProfilePicture(String imagePath) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'You must be logged in to upload a profile picture',
        };
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.authEndpoint}/profile/upload-picture/'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Add profile picture file
      request.files.add(await http.MultipartFile.fromPath(
        'profile_picture',
        imagePath,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Authentication failed. Please login again.',
        };
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to upload profile picture'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update combined profile (user + profile data)
  static Future<Map<String, dynamic>> updateCombinedProfile({
    String? fullName,
    String? phoneNum,
    String? bloodGroup,
    String? dateOfBirth,
    String? gender,
    String? weight,
    String? city,
    String? locationLat,
    String? locationLng,
    String? address,
  }) async {
    try {
      final headers = await getAuthHeaders();

      // Build request body with only non-null values
      final Map<String, dynamic> requestBody = {};
      if (fullName != null && fullName.isNotEmpty) requestBody['full_name'] = fullName;
      if (phoneNum != null && phoneNum.isNotEmpty) requestBody['phone_num'] = phoneNum;
      if (bloodGroup != null && bloodGroup.isNotEmpty) requestBody['blood_group'] = bloodGroup;
      if (dateOfBirth != null && dateOfBirth.isNotEmpty) requestBody['date_of_birth'] = dateOfBirth;
      if (gender != null && gender.isNotEmpty) requestBody['gender'] = gender;
      if (weight != null && weight.isNotEmpty) requestBody['weight'] = weight;
      if (city != null && city.isNotEmpty) requestBody['city'] = city;
      if (locationLat != null && locationLat.isNotEmpty) requestBody['location_lat'] = double.tryParse(locationLat);
      if (locationLng != null && locationLng.isNotEmpty) requestBody['location_lng'] = double.tryParse(locationLng);
      if (address != null && address.isNotEmpty) requestBody['address'] = address;

      final response = await http.patch(
        Uri.parse('${ApiConfig.authEndpoint}/profile/update-combined/'),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      // Handle 401 - try to refresh token and retry
      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();

        if (refreshed) {
          final newHeaders = await getAuthHeaders();
          final retryResponse = await http.patch(
            Uri.parse('${ApiConfig.authEndpoint}/profile/update-combined/'),
            headers: newHeaders,
            body: jsonEncode(requestBody),
          );

          if (retryResponse.statusCode == 200) {
            final data = jsonDecode(retryResponse.body);
            return {'success': true, 'data': data};
          }
        }
        return {'success': false, 'message': 'Session expired. Please login again.'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to update profile', 'errors': data['errors']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get unread chat messages count
  static Future<Map<String, dynamic>> getUnreadChatMessagesCount() async {
    try {
      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.chatEndpoint}/unread-count/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'unread_count': data['data']['unread_count'] as int? ?? 0
        };
      } else {
        return {'success': false, 'message': 'Failed to get unread chat count'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
