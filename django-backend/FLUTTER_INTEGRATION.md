# Flutter API Integration Guide

This guide shows how to integrate the Django REST API with your Flutter Blood Donation app.

## Prerequisites

Add these dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.2.0
  flutter_secure_storage: ^9.0.0
  jwt_decoder: ^2.0.1
```

## API Service Implementation

### Create `lib/src/services/api_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, 127.0.0.1 for iOS Simulator
  static const String baseUrl = 'http://10.0.2.2:8000/api/auth';

  // Secure storage for tokens
  final _storage = const FlutterSecureStorage();

  // Get stored access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  // Get stored refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  // Check if token is expired
  bool isTokenExpired(String token) {
    return JwtDecoder.isExpired(token);
  }

  // Refresh access token
  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.write(key: 'access_token', value: data['access']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get authenticated request headers
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAccessToken();

    // Check if token needs refresh
    if (token != null && isTokenExpired(token)) {
      final refreshed = await refreshAccessToken();
      if (!refreshed) {
        throw Exception('Session expired. Please login again.');
      }
    }

    final newToken = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (newToken != null) 'Authorization': 'Bearer $newToken',
    };
  }

  // Handle API errors
  void _handleError(http.Response response) {
    final data = jsonDecode(response.body);
    final message = data['message'] ?? 'An error occurred';
    throw Exception(message);
  }

  // ============ AUTHENTICATION ENDPOINTS ============

  /// Register a new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String? phoneNum,
    String? address,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.toLowerCase().trim(),
          'password': password,
          'password_confirm': password,
          'full_name': fullName,
          'phone_num': phoneNum,
          'address': address,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Save tokens
        await _storage.write(
          key: 'access_token',
          value: data['tokens']['access'],
        );
        await _storage.write(
          key: 'refresh_token',
          value: data['tokens']['refresh'],
        );
        await _storage.write(
          key: 'user_id',
          value: data['user']['id'],
        );

        return data;
      } else {
        _handleError(response);
        throw Exception('Registration failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.toLowerCase().trim(),
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Save tokens
        await _storage.write(
          key: 'access_token',
          value: data['tokens']['access'],
        );
        await _storage.write(
          key: 'refresh_token',
          value: data['tokens']['refresh'],
        );
        await _storage.write(
          key: 'user_id',
          value: data['user']['id'],
        );

        return data;
      } else {
        _handleError(response);
        throw Exception('Login failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Logout user
  Future<bool> logout() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        await clearTokens();
        return true;
      }

      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/logout/'),
        headers: headers,
        body: jsonEncode({'refresh': refreshToken}),
      );

      await clearTokens();
      return response.statusCode == 200;
    } catch (e) {
      // Clear tokens even if API call fails
      await clearTokens();
      return true;
    }
  }

  /// Clear stored tokens
  Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_id');
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && !isTokenExpired(token);
  }

  // ============ OTP ENDPOINTS ============

  /// Send OTP to phone number
  Future<Map<String, dynamic>> sendOtp(String phoneNum) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-otp/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_num': phoneNum}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        _handleError(response);
        throw Exception('Failed to send OTP');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Verify OTP code
  Future<Map<String, dynamic>> verifyOtp({
    required String phoneNum,
    required String otpCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_num': phoneNum,
          'otp_code': otpCode,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        _handleError(response);
        throw Exception('OTP verification failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Resend OTP
  Future<Map<String, dynamic>> resendOtp(String phoneNum) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/resend-otp/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_num': phoneNum}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        _handleError(response);
        throw Exception('Failed to resend OTP');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ============ PROFILE ENDPOINTS ============

  /// Get user profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/profile/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        _handleError(response);
        throw Exception('Failed to fetch profile');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phoneNum,
    String? address,
  }) async {
    try {
      final headers = await getAuthHeaders();
      final body = <String, dynamic>{};

      if (fullName != null) body['full_name'] = fullName;
      if (phoneNum != null) body['phone_num'] = phoneNum;
      if (address != null) body['address'] = address;

      final response = await http.patch(
        Uri.parse('$baseUrl/profile/update/'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        _handleError(response);
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Change password
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/change-password/'),
        headers: headers,
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
          'new_password_confirm': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Update tokens with new ones
        if (data['tokens'] != null) {
          await _storage.write(
            key: 'access_token',
            value: data['tokens']['access'],
          );
          await _storage.write(
            key: 'refresh_token',
            value: data['tokens']['refresh'],
          );
        }

        return true;
      } else {
        _handleError(response);
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
```

## Usage Examples

### Registration with Phone Verification

```dart
final apiService = ApiService();

// Step 1: Register user
try {
  final result = await apiService.register(
    email: 'user@example.com',
    password: 'SecurePass123',
    fullName: 'John Doe',
    phoneNum: '+1234567890',
  );
  print('Registration successful: ${result['user']['email']}');

  // Step 2: Send OTP
  final otpResult = await apiService.sendOtp('+1234567890');
  print('OTP sent: ${otpResult['otp_code']}'); // Remove in production!

  // Step 3: Verify OTP (user enters OTP from SMS)
  final verifyResult = await apiService.verifyOtp(
    phoneNum: '+1234567890',
    otpCode: '123456', // From user input
  );

  if (verifyResult['success']) {
    print('Phone verified!');
  }
} catch (e) {
  print('Error: $e');
}
```

### Login Flow

```dart
try {
  final result = await apiService.login(
    email: 'user@example.com',
    password: 'SecurePass123',
  );

  print('Login successful!');
  print('User: ${result['user']['full_name']}');
  print('Phone Verified: ${result['user']['phone_verified']}');
} catch (e) {
  print('Login failed: $e');
}
```

### Profile Update

```dart
try {
  final result = await apiService.updateProfile(
    fullName: 'John Updated Doe',
    address: 'New Address',
  );

  print('Profile updated: ${result['user']['full_name']}');
} catch (e) {
  print('Update failed: $e');
}
```

### Protected API Calls

```dart
Future<void> fetchProtectedData() async {
  // Check if logged in
  if (!await apiService.isLoggedIn()) {
    // Navigate to login
    return;
  }

  try {
    final profile = await apiService.getProfile();
    print('User profile: ${profile}');
  } catch (e) {
    print('Error fetching profile: $e');
  }
}
```

## Error Handling Best Practices

```dart
class ApiErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error.toString().contains('Session expired')) {
      return 'Please login again';
    } else if (error.toString().contains('Invalid email or password')) {
      return 'Incorrect email or password';
    } else if (error.toString().contains('A user with this email already exists')) {
      return 'An account with this email already exists';
    } else if (error.toString().contains('OTP has expired')) {
      return 'The OTP has expired. Please request a new one';
    } else if (error.toString().contains('Invalid OTP')) {
      return 'Incorrect verification code';
    }
    return 'An unexpected error occurred. Please try again';
  }
}

// Usage
try {
  await apiService.login(email: email, password: password);
} catch (e) {
  final message = ApiErrorHandler.getErrorMessage(e);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
```

## Testing with Different Devices

```dart
class ApiService {
  static String get baseUrl {
    // Detect platform and return appropriate URL
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api/auth';  // Android Emulator
    } else if (Platform.isIOS) {
      return 'http://127.0.0.1:8000/api/auth';  // iOS Simulator
    } else {
      // For physical devices, use your computer's IP address
      return 'http://192.168.1.100:8000/api/auth';
    }
  }
}
```

## Security Best Practices

1. **Always use HTTPS in production**
2. **Store tokens securely** with `flutter_secure_storage`
3. **Implement token refresh** before expiry
4. **Clear tokens on logout**
5. **Validate input on both client and server**
6. **Never log sensitive data** (passwords, tokens)
7. **Use certificate pinning** in production (optional)

## Next Steps

1. Create a state management solution (Provider, Riverpod, Bloc)
2. Implement auto-token refresh interceptor
3. Add loading states and error handling UI
4. Create authentication guards for protected routes
5. Implement biometric authentication (optional)
