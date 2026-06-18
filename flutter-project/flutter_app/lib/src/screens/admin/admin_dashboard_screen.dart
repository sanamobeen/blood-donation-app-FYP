import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/admin/admin_dashboard_data.dart';
import '../../theme/app_theme.dart';
import '../../app_routes.dart';
import '../../services/api_service.dart';
import 'admin_users_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_blood_requests_screen.dart';

/// Modern Responsive Admin Dashboard Screen
/// Adapts layout based on screen size
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedNavIndex = 0;
  bool _isSidebarCollapsed = false;

  final List<NavigationItem> _navItems = const [
    NavigationItem(
      icon: Icons.dashboard_rounded,
      label: 'Dashboard',
    ),
    NavigationItem(
      icon: Icons.people_rounded,
      label: 'Users',
    ),
    NavigationItem(
      icon: Icons.insights_rounded,
      label: 'Analytics',
    ),
    NavigationItem(
      icon: Icons.bloodtype_rounded,
      label: 'Requests',
    ),
    NavigationItem(
      icon: Icons.sos_rounded,
      label: 'SOS Alerts',
    ),
    NavigationItem(
      icon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadDashboardStats();
    });
  }

  bool get _isLargeScreen {
    return MediaQuery.of(context).size.width > 1200;
  }

  bool get _isMediumScreen {
    final width = MediaQuery.of(context).size.width;
    return width > 800 && width <= 1200;
  }

  bool get _isSmallScreen {
    return MediaQuery.of(context).size.width <= 800;
  }

  int _getCrossAxisCount() {
    if (_isSmallScreen) return 1;
    if (_isMediumScreen) return 2;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          // Sidebar - responsive width
          _buildResponsiveSidebar(),

          // Main Content Area
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveSidebar() {
    // Small screen: narrow collapsed sidebar
    if (_isSmallScreen) {
      return _buildCollapsedSidebar();
    }
    // Medium screen: medium sidebar
    if (_isMediumScreen) {
      return _buildMediumSidebar();
    }
    // Large screen: full sidebar with collapsible option
    return _isSidebarCollapsed ? _buildCollapsedSidebar() : _buildFullSidebar();
  }

  Widget _buildFullSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey[200]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSidebarHeader(),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = _selectedNavIndex == index;

                return _buildNavItem(
                  item: item,
                  isSelected: isSelected,
                  showLabel: true,
                  onTap: () => setState(() => _selectedNavIndex = index),
                );
              },
            ),
          ),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildMediumSidebar() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey[200]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCompactHeader(),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = _selectedNavIndex == index;

                return _buildNavItem(
                  item: item,
                  isSelected: isSelected,
                  showLabel: true,
                  isCompact: true,
                  onTap: () => setState(() => _selectedNavIndex = index),
                );
              },
            ),
          ),
          _buildCompactFooter(),
        ],
      ),
    );
  }

  Widget _buildCollapsedSidebar() {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey[200]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildIconHeader(),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = _selectedNavIndex == index;

                return _buildNavItem(
                  item: item,
                  isSelected: isSelected,
                  showLabel: false,
                  onTap: () => setState(() => _selectedNavIndex = index),
                );
              },
            ),
          ),
          _buildIconFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE53935), Color(0xFFC62828)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.bloodtype_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LifeDrop',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Admin Portal',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Collapse button
          IconButton(
            icon: Icon(_isSidebarCollapsed ? Icons.menu_open : Icons.menu, color: Colors.grey[600]),
            onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
            tooltip: 'Toggle sidebar',
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE53935), Color(0xFFC62828)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bloodtype_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LifeDrop',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Center(
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE53935), Color(0xFFC62828)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE53935).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.bloodtype_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required NavigationItem item,
    required bool isSelected,
    required bool showLabel,
    required VoidCallback onTap,
    bool isCompact = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isSelected
            ? const Color(0xFFE53935).withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(color: const Color(0xFFE53935).withOpacity(0.2), width: 1)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE53935)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    color: isSelected ? Colors.white : Colors.grey[700],
                    size: 20,
                  ),
                ),
                if (showLabel) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: isCompact ? 13 : 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? const Color(0xFFE53935) : const Color(0xFF4A4A4A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE53935).withOpacity(0.1),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFFE53935),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin User',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        'admin@lifedrop.com',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFE53935)),
                  tooltip: 'Logout',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE53935).withOpacity(0.1),
            child: const Icon(
              Icons.person,
              color: Color(0xFFE53935),
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFE53935)),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildIconFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: IconButton(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout_rounded, color: Color(0xFFE53935)),
        tooltip: 'Logout',
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildDashboardOverview();
      case 1:
        return const AdminUsersScreen();
      case 2:
        return const AdminAnalyticsScreen();
      case 3:
        return const AdminBloodRequestsScreen();
      case 4:
        return _buildPlaceholder('SOS Alerts Monitoring');
      case 5:
        return _buildPlaceholder('Settings');
      default:
        return _buildDashboardOverview();
    }
  }

  Widget _buildDashboardOverview() {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.isLoadingStats) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE53935)),
          );
        }

        if (adminProvider.statsError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Unable to load dashboard',
                  style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  adminProvider.statsError!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => adminProvider.loadDashboardStats(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final stats = adminProvider.dashboardStats;
        if (stats == null) {
          return const Center(
            child: Text('No data available', style: TextStyle(color: Colors.grey)),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(_isSmallScreen ? 16 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              SizedBox(height: _isSmallScreen ? 16 : 32),
              _buildStatsCards(stats),
              SizedBox(height: _isSmallScreen ? 24 : 32),
              _buildQuickActions(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    if (_isSmallScreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome back!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard Overview',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome back! Here\'s what\'s happening today.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        if (!_isSmallScreen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _getCurrentTime(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStatsCards(AdminDashboardStats stats) {
    final crossAxisCount = _getCrossAxisCount();
    final childAspectRatio = _isSmallScreen ? 1.3 : (_isMediumScreen ? 1.5 : 1.4);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: _isSmallScreen ? 16 : 24,
      crossAxisSpacing: _isSmallScreen ? 16 : 24,
      childAspectRatio: childAspectRatio,
      children: [
        _buildStatCard(
          title: 'Total Users',
          value: stats.totalUsers.toString(),
          growth: stats.usersGrowth,
          icon: Icons.people_rounded,
          color: const Color(0xFF2196F3),
          gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1976D2)]),
        ),
        _buildStatCard(
          title: 'Active Donors',
          value: stats.totalDonors.toString(),
          growth: stats.donorsGrowth,
          icon: Icons.bloodtype_rounded,
          color: const Color(0xFFE53935),
          gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFC62828)]),
        ),
        _buildStatCard(
          title: 'Total Patients',
          value: stats.totalPatients.toString(),
          growth: stats.patientsGrowth,
          icon: Icons.local_hospital_rounded,
          color: const Color(0xFF4CAF50),
          gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF388E3C)]),
        ),
        _buildStatCard(
          title: 'Total Donations',
          value: stats.totalDonations.toString(),
          growth: stats.donationsGrowth,
          icon: Icons.volunteer_activism_rounded,
          color: const Color(0xFFFF9800),
          gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)]),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required double? growth,
    required IconData icon,
    required Color color,
    required Gradient gradient,
  }) {
    final hasGrowth = growth != null;
    final isPositive = hasGrowth && growth >= 0;
    final isSmall = _isSmallScreen;

    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: isSmall ? 44 : 52,
                height: isSmall ? 44 : 52,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: isSmall ? 22 : 26),
              ),
              if (hasGrowth && !isSmall)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? const Color(0xFF4CAF50).withOpacity(0.1)
                        : const Color(0xFFE53935).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPositive
                          ? const Color(0xFF4CAF50).withOpacity(0.3)
                          : const Color(0xFFE53935).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 16,
                        color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${growth!.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmall ? 30 : 36,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmall ? 13 : 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final isSmall = _isSmallScreen;
    final isMedium = _isMediumScreen;

    if (isSmall) {
      // Vertical layout for small screens
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              _buildQuickActionCard(
                title: 'Manage Users',
                description: 'View and manage all users',
                icon: Icons.people_rounded,
                color: const Color(0xFF2196F3),
                onTap: () => setState(() => _selectedNavIndex = 1),
              ),
              const SizedBox(height: 12),
              _buildQuickActionCard(
                title: 'View Analytics',
                description: 'See platform statistics',
                icon: Icons.insights_rounded,
                color: const Color(0xFF9C27B0),
                onTap: () => setState(() => _selectedNavIndex = 2),
              ),
              const SizedBox(height: 12),
              _buildQuickActionCard(
                title: 'Blood Requests',
                description: 'Manage blood requests',
                icon: Icons.bloodtype_rounded,
                color: const Color(0xFFE53935),
                onTap: () => setState(() => _selectedNavIndex = 3),
              ),
              const SizedBox(height: 12),
              _buildQuickActionCard(
                title: 'SOS Alerts',
                description: 'View emergency requests',
                icon: Icons.sos_rounded,
                color: const Color(0xFFFF5722),
                onTap: () => setState(() => _selectedNavIndex = 4),
              ),
            ],
          ),
        ],
      );
    }

    if (isMedium) {
      // 2x2 grid for medium screens
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.5,
            children: [
              _buildQuickActionCard(
                title: 'Manage Users',
                description: 'View and manage all users',
                icon: Icons.people_rounded,
                color: const Color(0xFF2196F3),
                onTap: () => setState(() => _selectedNavIndex = 1),
              ),
              _buildQuickActionCard(
                title: 'View Analytics',
                description: 'See platform statistics',
                icon: Icons.insights_rounded,
                color: const Color(0xFF9C27B0),
                onTap: () => setState(() => _selectedNavIndex = 2),
              ),
              _buildQuickActionCard(
                title: 'Blood Requests',
                description: 'Manage blood requests',
                icon: Icons.bloodtype_rounded,
                color: const Color(0xFFE53935),
                onTap: () => setState(() => _selectedNavIndex = 3),
              ),
              _buildQuickActionCard(
                title: 'SOS Alerts',
                description: 'View emergency requests',
                icon: Icons.sos_rounded,
                color: const Color(0xFFFF5722),
                onTap: () => setState(() => _selectedNavIndex = 4),
              ),
            ],
          ),
        ],
      );
    }

    // Row layout for large screens
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: 'Manage Users',
                description: 'View and manage all users',
                icon: Icons.people_rounded,
                color: const Color(0xFF2196F3),
                onTap: () => setState(() => _selectedNavIndex = 1),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildQuickActionCard(
                title: 'View Analytics',
                description: 'See platform statistics',
                icon: Icons.insights_rounded,
                color: const Color(0xFF9C27B0),
                onTap: () => setState(() => _selectedNavIndex = 2),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildQuickActionCard(
                title: 'Blood Requests',
                description: 'Manage blood requests',
                icon: Icons.bloodtype_rounded,
                color: const Color(0xFFE53935),
                onTap: () => setState(() => _selectedNavIndex = 3),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildQuickActionCard(
                title: 'SOS Alerts',
                description: 'View emergency requests',
                icon: Icons.sos_rounded,
                color: const Color(0xFFFF5722),
                onTap: () => setState(() => _selectedNavIndex = 4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSmall = _isSmallScreen;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isSmall ? 16 : 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[100]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: isSmall ? 48 : 56,
                height: isSmall ? 48 : 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: isSmall ? 24 : 28),
              ),
              SizedBox(width: isSmall ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isSmall ? 15 : 16,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    if (!isSmall) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            '$title Coming Soon',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Call API logout and clear local data
      await ApiService.logout();

      // Navigate to role selection screen and clear ALL routes from the stack
      // After logout, user goes to role selection, then can login/register from there
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.roleSelection,
          (route) => false, // Remove all routes
        );
      }
    }
  }
}

class NavigationItem {
  final IconData icon;
  final String label;

  const NavigationItem({
    required this.icon,
    required this.label,
  });
}
