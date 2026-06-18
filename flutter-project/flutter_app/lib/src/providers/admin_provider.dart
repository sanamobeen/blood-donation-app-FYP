import 'package:flutter/material.dart';
import '../models/admin/admin_user_data.dart';
import '../models/admin/admin_dashboard_data.dart';
import '../services/admin_api_service.dart';

/// Admin Provider for state management
/// Handles admin dashboard data, user management, and analytics
class AdminProvider with ChangeNotifier {
  // Dashboard Stats
  AdminDashboardStats? _dashboardStats;
  bool _isLoadingStats = false;
  String? _statsError;

  // Users List
  AdminUsersResponse? _usersResponse;
  List<AdminUserData> _users = [];
  bool _isLoadingUsers = false;
  String? _usersError;
  int _currentPage = 1;
  int _pageSize = 20;
  String? _searchQuery;
  String? _roleFilter;
  String? _bloodTypeFilter;
  String? _statusFilter;

  // User Detail
  AdminUserDetail? _userDetail;
  bool _isLoadingUserDetail = false;
  String? _userDetailError;

  // Analytics Data
  AdminAnalyticsData? _analyticsData;
  bool _isLoadingAnalytics = false;
  String? _analyticsError;
  DateTime? _analyticsStartDate;
  DateTime? _analyticsEndDate;

  // Getters
  AdminDashboardStats? get dashboardStats => _dashboardStats;
  bool get isLoadingStats => _isLoadingStats;
  String? get statsError => _statsError;

  List<AdminUserData> get users => _users;
  int get totalUsers => _usersResponse?.totalCount ?? 0;
  int get totalPages => _usersResponse?.totalPages ?? 1;
  int get currentPage => _currentPage;
  bool get isLoadingUsers => _isLoadingUsers;
  String? get usersError => _usersError;

  AdminUserDetail? get userDetail => _userDetail;
  bool get isLoadingUserDetail => _isLoadingUserDetail;
  String? get userDetailError => _userDetailError;

  AdminAnalyticsData? get analyticsData => _analyticsData;
  bool get isLoadingAnalytics => _isLoadingAnalytics;
  String? get analyticsError => _analyticsError;

  /// Load dashboard statistics
  Future<void> loadDashboardStats() async {
    try {
      _isLoadingStats = true;
      _statsError = null;
      notifyListeners();

      _dashboardStats = await AdminApiService.getDashboardStats();
      _isLoadingStats = false;
      notifyListeners();
    } catch (e) {
      _statsError = e.toString();
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  /// Load users list
  Future<void> loadUsers({
    bool resetPagination = false,
    String? search,
    String? role,
    String? bloodType,
    String? status,
  }) async {
    try {
      _isLoadingUsers = true;
      _usersError = null;
      notifyListeners();

      if (resetPagination) {
        _currentPage = 1;
      }

      // Update filters
      if (search != null) _searchQuery = search;
      if (role != null) _roleFilter = role;
      if (bloodType != null) _bloodTypeFilter = bloodType;
      if (status != null) _statusFilter = status;

      final response = await AdminApiService.getUsers(
        page: _currentPage,
        pageSize: _pageSize,
        search: _searchQuery,
        role: _roleFilter,
        bloodType: _bloodTypeFilter,
        status: _statusFilter,
      );

      _usersResponse = response;
      _users = response.users;
      _isLoadingUsers = false;
      notifyListeners();
    } catch (e) {
      _usersError = e.toString();
      _isLoadingUsers = false;
      notifyListeners();
    }
  }

  /// Load more users (pagination)
  Future<void> loadMoreUsers() async {
    if (_currentPage < totalPages) {
      _currentPage++;
      await loadUsers();
    }
  }

  /// Refresh users list
  Future<void> refreshUsers() async {
    _currentPage = 1;
    await loadUsers(resetPagination: true);
  }

  /// Load user detail
  Future<void> loadUserDetail(String userId) async {
    try {
      _isLoadingUserDetail = true;
      _userDetailError = null;
      notifyListeners();

      _userDetail = await AdminApiService.getUserDetail(userId);
      _isLoadingUserDetail = false;
      notifyListeners();
    } catch (e) {
      _userDetailError = e.toString();
      _isLoadingUserDetail = false;
      notifyListeners();
    }
  }

  /// Activate user
  Future<bool> activateUser(String userId) async {
    try {
      final result = await AdminApiService.activateUser(userId);
      if (result) {
        // Update local user list
        _users = _users.map((u) {
          if (u.id == userId) {
            return AdminUserData.fromJson({...u.toJson(), 'is_active': true});
          }
          return u;
        }).toList();
        notifyListeners();
      }
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Deactivate user
  Future<bool> deactivateUser(String userId) async {
    try {
      final result = await AdminApiService.deactivateUser(userId);
      if (result) {
        // Update local user list
        _users = _users.map((u) {
          if (u.id == userId) {
            return AdminUserData.fromJson({...u.toJson(), 'is_active': false});
          }
          return u;
        }).toList();
        notifyListeners();
      }
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Delete user
  Future<bool> deleteUser(String userId) async {
    try {
      final result = await AdminApiService.deleteUser(userId);
      if (result) {
        // Remove from local list
        _users.removeWhere((u) => u.id == userId);
        notifyListeners();
      }
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Load analytics data
  Future<void> loadAnalyticsData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      _isLoadingAnalytics = true;
      _analyticsError = null;
      notifyListeners();

      // Default to last 30 days if not specified
      final now = DateTime.now();
      _analyticsStartDate = startDate ?? now.subtract(const Duration(days: 30));
      _analyticsEndDate = endDate ?? now;

      _analyticsData = await AdminApiService.getAnalyticsData(
        startDate: _analyticsStartDate!,
        endDate: _analyticsEndDate!,
      );

      _isLoadingAnalytics = false;
      notifyListeners();
    } catch (e) {
      _analyticsError = e.toString();
      _isLoadingAnalytics = false;
      notifyListeners();
    }
  }

  /// Clear all data (logout)
  void clearData() {
    _dashboardStats = null;
    _usersResponse = null;
    _users = [];
    _userDetail = null;
    _analyticsData = null;
    _currentPage = 1;
    _searchQuery = null;
    _roleFilter = null;
    _bloodTypeFilter = null;
    _statusFilter = null;
    _statsError = null;
    _usersError = null;
    _userDetailError = null;
    _analyticsError = null;
    notifyListeners();
  }
}
