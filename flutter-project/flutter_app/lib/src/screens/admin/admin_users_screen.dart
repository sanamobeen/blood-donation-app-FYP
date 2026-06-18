import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/admin/admin_user_data.dart';
import '../../theme/app_theme.dart';
import 'admin_user_detail_screen.dart';

/// Admin Users Management Screen
/// Displays list of all users with search and filter capabilities
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _roleFilter;
  String? _bloodTypeFilter;
  String? _statusFilter;

  final List<String> _roleOptions = ['All', 'Donor', 'Patient'];
  final List<String> _bloodTypeOptions = [
    'All',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  final List<String> _statusOptions = ['All', 'Active', 'Inactive'];

  @override
  void initState() {
    super.initState();
    // Load users on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    context.read<AdminProvider>().loadUsers(
          search: _searchController.text.isNotEmpty ? _searchController.text : null,
          role: _roleFilter == 'All' ? null : _roleFilter?.toLowerCase(),
          bloodType: _bloodTypeFilter == 'All' ? null : _bloodTypeFilter,
          status: _statusFilter == 'All' ? null : _statusFilter?.toLowerCase(),
        );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _roleFilter = null;
      _bloodTypeFilter = null;
      _statusFilter = null;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with filters
        _buildHeader(),

        // Filters bar
        _buildFiltersBar(),

        // Users table
        Expanded(
          child: _buildUsersTable(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.people, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Management',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Consumer<AdminProvider>(
                builder: (context, provider, _) {
                  return Text(
                    '${provider.totalUsers} total users',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ],
          ),
          const Spacer(),
          // Export button
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Export functionality
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.grey[50],
      child: Row(
        children: [
          // Search box
          Expanded(
            child: _SearchBox(
              controller: _searchController,
              onChanged: () => _applyFilters(),
              onClear: () {
                _searchController.clear();
                _applyFilters();
              },
            ),
          ),

          const SizedBox(width: 16),

          // Role filter
          _buildFilterDropdown(
            value: _roleFilter ?? 'All',
            items: _roleOptions,
            label: 'Role',
            onChanged: (value) {
              setState(() => _roleFilter = value);
              _applyFilters();
            },
          ),

          const SizedBox(width: 12),

          // Blood type filter
          _buildFilterDropdown(
            value: _bloodTypeFilter ?? 'All',
            items: _bloodTypeOptions,
            label: 'Blood Type',
            onChanged: (value) {
              setState(() => _bloodTypeFilter = value);
              _applyFilters();
            },
          ),

          const SizedBox(width: 12),

          // Status filter
          _buildFilterDropdown(
            value: _statusFilter ?? 'All',
            items: _statusOptions,
            label: 'Status',
            onChanged: (value) {
              setState(() => _statusFilter = value);
              _applyFilters();
            },
          ),

          const SizedBox(width: 12),

          // Clear filters button
          if (_roleFilter != null || _bloodTypeFilter != null || _statusFilter != null)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          dropdownColor: Colors.white,
          icon: Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey[700]),
          itemHeight: 48,
          menuMaxHeight: 300,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildUsersTable() {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingUsers && provider.users.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.usersError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Failed to load users',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.refreshUsers(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return Container(
          color: Colors.white,
          child: ListView(
            children: [
              // Table header
              _buildTableHeader(),

              // Table rows
              ...provider.users.map((user) => _buildUserRow(user)),

              // Pagination (if needed)
              if (provider.currentPage < provider.totalPages)
                _buildPaginationRow(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: _TableHeaderCell('User')),
          Expanded(flex: 2, child: _TableHeaderCell('Email')),
          Expanded(flex: 1, child: _TableHeaderCell('Role')),
          Expanded(flex: 1, child: _TableHeaderCell('Blood Type')),
          Expanded(flex: 2, child: _TableHeaderCell('Location')),
          Expanded(flex: 1, child: _TableHeaderCell('Status')),
          Expanded(flex: 1, child: _TableHeaderCell('Donations')),
          Expanded(flex: 1, child: _TableHeaderCell('Joined')),
          Expanded(flex: 1, child: _TableHeaderCell('')),
        ],
      ),
    );
  }

  Widget _buildUserRow(AdminUserData user) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminUserDetailScreen(userId: user.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Row(
          children: [
            // User info
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: user.profilePicture != null
                        ? NetworkImage(user.profilePicture!)
                        : null,
                    child: user.profilePicture == null
                        ? Text(
                            user.fullName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user.phoneNumber != null)
                          Text(
                            user.phoneNumber!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Email
            Expanded(
              flex: 2,
              child: Text(
                user.email,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Role
            Expanded(
              flex: 1,
              child: _RoleBadge(user.displayRole),
            ),

            // Blood Type
            Expanded(
              flex: 1,
              child: user.bloodType != null
                  ? _BloodTypeChip(user.bloodType!)
                  : Text(
                      '-',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
            ),

            // Location
            Expanded(
              flex: 2,
              child: Text(
                user.fullLocation,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Status
            Expanded(
              flex: 1,
              child: _StatusBadge(user.isActive),
            ),

            // Donations
            Expanded(
              flex: 1,
              child: Text(
                '${user.totalDonations}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),

            // Joined date
            Expanded(
              flex: 1,
              child: Text(
                _formatDate(user.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),

            // Actions
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onPressed: () => _showUserActions(context, user),
                    tooltip: 'Actions',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationRow(AdminProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ElevatedButton(
          onPressed: () => provider.loadMoreUsers(),
          child: const Text('Load More'),
        ),
      ),
    );
  }

  void _showUserActions(BuildContext context, AdminUserData user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminUserDetailScreen(userId: user.id),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                user.isActive ? Icons.block : Icons.check_circle,
                color: user.isActive ? Colors.red : Colors.green,
              ),
              title: Text(user.isActive ? 'Deactivate User' : 'Activate User'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(user.isActive ? 'Deactivate User' : 'Activate User'),
                    content: Text(
                      'Are you sure you want to ${user.isActive ? 'deactivate' : 'activate'} ${user.fullName}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: user.isActive ? Colors.red : Colors.green,
                        ),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  if (user.isActive) {
                    await context.read<AdminProvider>().deactivateUser(user.id);
                  } else {
                    await context.read<AdminProvider>().activateUser(user.id);
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete User', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete User'),
                    content: Text(
                      'Are you sure you want to delete ${user.fullName}? This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await context.read<AdminProvider>().deleteUser(user.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _SearchBox extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onClear;

  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              decoration: const InputDecoration(
                hintText: 'Search by name, email, or phone',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (_) => widget.onChanged(),
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: widget.onClear,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String label;

  const _TableHeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
        letterSpacing: 0.5,
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge(this.role);

  @override
  Widget build(BuildContext context) {
    final color = role == 'Donor' ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _BloodTypeChip extends StatelessWidget {
  final String bloodType;

  const _BloodTypeChip(this.bloodType);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Text(
        bloodType,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge(this.isActive);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
