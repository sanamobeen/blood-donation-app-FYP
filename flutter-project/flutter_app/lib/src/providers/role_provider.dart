import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

/// Role state management for the entire app
/// Handles role switching and persists the current role
class RoleProvider with ChangeNotifier {
  String? _currentRole;
  bool _isLoading = false;

  // Getters
  String? get currentRole => _currentRole;
  bool get isLoading => _isLoading;
  bool get isDonor => _currentRole == 'donor';
  bool get isPatient => _currentRole == 'patient';
  bool get hasRole => _currentRole != null;

  /// Constructor - load saved role on init
  RoleProvider() {
    _loadSavedRole();
  }

  /// Load saved role from local storage
  Future<void> _loadSavedRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentRole = prefs.getString('user_role');
      notifyListeners();
    } catch (e) {
    }
  }

  /// Get role from API (call this after login)
  Future<void> fetchUserRole() async {
    try {
      _isLoading = true;
      notifyListeners();

      final profileResult = await ApiService.getProfile();

      if (profileResult['success'] == true) {
        // Try multiple paths for the role
        String? userRole;

        // Path 1: data.user.role
        if (profileResult['data'] is Map) {
          final data = profileResult['data'] as Map;
          userRole = data['user']?['role']?.toString();

          // Path 2: data.profile.role (fallback)
          if (userRole == null || userRole.isEmpty) {
            userRole = data['profile']?['role']?.toString();
          }

          // Path 3: Check if role is in the data directly (some endpoints)
          if (userRole == null || userRole.isEmpty) {
            userRole = data['role']?.toString();
          }
        }


        if (userRole != null && userRole.isNotEmpty) {
          await setRole(userRole);
        } else {
        }
      } else {
      }
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set the current role (called after API updates)
  Future<void> setRole(String? role) async {
    _currentRole = role;

    // Save to local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      if (role != null) {
        await prefs.setString('user_role', role);
      } else {
        await prefs.remove('user_role');
      }
    } catch (e) {
    }

    notifyListeners();
  }

  /// Switch role (calls API and updates state)
  Future<Map<String, dynamic>> switchRole(String newRole) async {
    try {
      _isLoading = true;
      notifyListeners();


      // Call API to update role
      final response = await ApiService.updateUserRole(newRole);


      if (response['success'] == true) {
        // Update local state
        await setRole(newRole);
      } else {
      }

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to switch role: $e'
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear role (call on logout)
  Future<void> clearRole() async {
    _currentRole = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role');
    } catch (e) {
    }
    notifyListeners();
  }

  /// Get display name for current role
  String getRoleDisplayName() {
    switch (_currentRole) {
      case 'donor':
        return 'Donor';
      case 'patient':
        return 'Patient';
      default:
        return 'Not Selected';
    }
  }

  /// Get icon for current role
  IconData getRoleIcon() {
    switch (_currentRole) {
      case 'donor':
        return Icons.bloodtype;
      case 'patient':
        return Icons.local_hospital;
      default:
        return Icons.person_outline;
    }
  }
}
