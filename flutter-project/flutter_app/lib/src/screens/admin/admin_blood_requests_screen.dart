import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';
import '../../theme/app_theme.dart';

/// Admin Blood Requests Screen
/// Displays all blood requests with filtering and management capabilities
class AdminBloodRequestsScreen extends StatefulWidget {
  const AdminBloodRequestsScreen({super.key});

  @override
  State<AdminBloodRequestsScreen> createState() => _AdminBloodRequestsScreenState();
}

class _AdminBloodRequestsScreenState extends State<AdminBloodRequestsScreen> {
  // Data
  AdminBloodRequestsResponse? _bloodRequestsResponse;
  List<AdminBloodRequestData> _bloodRequests = [];

  // Loading states
  bool _isLoading = false;
  String? _errorMessage;

  // Pagination
  int _currentPage = 1;
  final int _pageSize = 20;

  // Filters
  String? _selectedStatus;
  String? _selectedUrgency;
  String? _selectedBloodGroup;

  // Available filter options
  final List<String> _statusOptions = ['All', 'pending', 'fulfilled', 'cancelled'];
  final List<String> _urgencyOptions = ['All', 'critical', 'urgent', 'normal'];
  final List<String> _bloodGroupOptions = [
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

  @override
  void initState() {
    super.initState();
    _loadBloodRequests();
  }

  Future<void> _loadBloodRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AdminApiService.getBloodRequests(
        page: _currentPage,
        pageSize: _pageSize,
        status: _selectedStatus == 'All' ? null : _selectedStatus,
        urgencyLevel: _selectedUrgency == 'All' ? null : _selectedUrgency,
        bloodGroup: _selectedBloodGroup == 'All' ? null : _selectedBloodGroup,
      );

      setState(() {
        _bloodRequestsResponse = response;
        _bloodRequests = response.bloodRequests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _currentPage = 1;
    });
    _loadBloodRequests();
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedUrgency = null;
      _selectedBloodGroup = null;
      _currentPage = 1;
    });
    _loadBloodRequests();
  }

  void _loadPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      _loadBloodRequests();
    }
  }

  void _loadNextPage() {
    if (_bloodRequestsResponse != null && _bloodRequestsResponse!.hasNext) {
      setState(() {
        _currentPage++;
      });
      _loadBloodRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildFiltersBar(),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Blood Requests',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      ),
      actions: [
        if (_bloodRequestsResponse != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                'Total: ${_bloodRequestsResponse!.count}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFiltersBar() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildFilterDropdown(
                  label: 'Status',
                  value: _selectedStatus ?? 'All',
                  options: _statusOptions,
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value == 'All' ? null : value;
                    });
                  },
                ),
                _buildFilterDropdown(
                  label: 'Urgency',
                  value: _selectedUrgency ?? 'All',
                  options: _urgencyOptions,
                  onChanged: (value) {
                    setState(() {
                      _selectedUrgency = value == 'All' ? null : value;
                    });
                  },
                ),
                _buildFilterDropdown(
                  label: 'Blood Group',
                  value: _selectedBloodGroup ?? 'All',
                  options: _bloodGroupOptions,
                  onChanged: (value) {
                    setState(() {
                      _selectedBloodGroup = value == 'All' ? null : value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Apply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          items: options
              .map((option) => DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  ))
              .toList(),
          style: const TextStyle(color: Color(0xFF1A1A1A)),
          dropdownColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFFE53935)),
              const SizedBox(height: 16),
              Text(
                'Loading blood requests...',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Failed to load blood requests',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadBloodRequests,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_bloodRequests.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bloodtype_outlined, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 20),
              Text(
                'No blood requests found',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildBloodRequestCard(_bloodRequests[index]),
            );
          },
          childCount: _bloodRequests.length,
        ),
      ),
    );
  }

  Widget _buildBloodRequestCard(AdminBloodRequestData request) {
    final urgencyColor = _getUrgencyColor(request.urgencyLevel);
    final statusColor = _getStatusColor(request.status);
    final isFulfilled = request.status == 'fulfilled';
    final isCancelled = request.status == 'cancelled';

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with patient name and badges
          Row(
            children: [
              Expanded(
                child: Text(
                  request.patientName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              _buildBadge(request.bloodGroup, const Color(0xFFE53935)),
              const SizedBox(width: 8),
              _buildBadge(request.urgencyLevel.toUpperCase(), urgencyColor),
              const SizedBox(width: 8),
              _buildBadge(request.status.toUpperCase(), statusColor),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar for units
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.unitsPledged} / ${request.unitsNeeded} units pledged',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: request.unitsNeeded > 0
                            ? request.unitsPledged / request.unitsNeeded
                            : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFulfilled
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE53935),
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isFulfilled
                      ? const Color(0xFF4CAF50).withOpacity(0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${request.respondersCount} responders',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isFulfilled ? const Color(0xFF4CAF50) : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hospital and location
          if (request.hospitalName != null || request.location != null)
            Row(
              children: [
                if (request.hospitalName != null) ...[
                  Icon(Icons.local_hospital, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.hospitalName!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (request.location != null) ...[
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request.location!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 8),

          // Contact and requester info
          Row(
            children: [
              Icon(Icons.phone, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                request.contactNumber,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 16),
              if (request.requestedBy != null) ...[
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'By: ${request.requestedBy!.fullName ?? request.requestedBy!.email}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
              Text(
                _formatDate(request.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case 'critical':
        return const Color(0xFFD32F2F);
      case 'urgent':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'fulfilled':
        return const Color(0xFF4CAF50);
      case 'cancelled':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF2196F3);
    }
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
