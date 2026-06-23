import 'package:flutter/material.dart';
import '../../models/donor_pledge.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/string_extensions.dart';

/// My Pledges Screen
/// Shows donor's pledges with status tracking
class MyPledgesScreen extends StatefulWidget {
  const MyPledgesScreen({super.key});

  @override
  State<MyPledgesScreen> createState() => _MyPledgesScreenState();
}

class _MyPledgesScreenState extends State<MyPledgesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DonorPledge> _pledges = [];
  PledgeSummary? _summary;
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadMyPledges();
  }

  Future<void> _loadMyPledges() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getMyPledges();

      if (mounted) {
        if (response['success'] == true && response['data'] != null) {
          final data = response['data'];
          final pledgesList = (data['pledges'] as List? ?? [])
              .map((e) => DonorPledge.fromJson(e))
              .toList();

          setState(() {
            _pledges = pledgesList;
            _summary = PledgeSummary.fromJson(data['summary'] ?? {});
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = response['message'] ?? 'Failed to load pledges';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelPledge(String pledgeId, String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Pledge'),
        content: const Text('Are you sure you want to cancel this pledge?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await ApiService.cancelPledge(pledgeId);

        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pledge cancelled'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadMyPledges();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to cancel pledge'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<DonorPledge> get _filteredPledges {
    if (_selectedStatusFilter == 'all') return _pledges;
    return _pledges.where((p) => p.status == _selectedStatusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Pledges'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Failed to load',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadMyPledges,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final filteredPledges = _filteredPledges;

    return Column(
      children: [
        // Summary Cards
        if (_summary != null) _buildSummaryCards(),

        // Filter Tabs
        _buildFilterTabs(),

        // Pledges List
        Expanded(
          child: filteredPledges.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredPledges.length,
                  itemBuilder: (context, index) {
                    return _buildPledgeCard(filteredPledges[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          _buildSummaryCard('Total', _summary!.total.toString(), Colors.blue),
          const SizedBox(width: 12),
          _buildSummaryCard('Pending', _summary!.pending.toString(), Colors.orange),
          const SizedBox(width: 12),
          _buildSummaryCard('Accepted', _summary!.accepted.toString(), Colors.green),
          const SizedBox(width: 12),
          _buildSummaryCard('Donated', _summary!.donated.toString(), AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = ['all', 'pending', 'accepted', 'rejected', 'donated', 'cancelled'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedStatusFilter == filter;
            final count = filter == 'all'
                ? _pledges.length
                : _pledges.where((p) => p.status == filter).length;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => setState(() => _selectedStatusFilter = filter),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filter.capitalize(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white24 : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            count.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPledgeCard(DonorPledge pledge) {
    final canCancel = pledge.canBeCancelledByDonor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    pledge.bloodGroup ?? '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pledge.patientName ?? 'Patient',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (pledge.hospitalName != null)
                      Text(
                        pledge.hospitalName!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              _buildStatusBadge(pledge),
            ],
          ),

          const SizedBox(height: 12),

          // Pledge Details
          Row(
            children: [
              Icon(Icons.bloodtype, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                '${pledge.unitsPledged} unit${pledge.unitsPledged > 1 ? 's' : ''} pledged',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              if (pledge.unitsReceived > 0) ...[
                const SizedBox(width: 16),
                Icon(Icons.check_circle, size: 16, color: AppColors.online),
                const SizedBox(width: 6),
                Text(
                  '${pledge.unitsReceived} unit${pledge.unitsReceived > 1 ? 's' : ''} received',
                  style: TextStyle(fontSize: 13, color: AppColors.online),
                ),
              ],
            ],
          ),

          if (pledge.note != null && pledge.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pledge.note!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ),
          ],

          if (pledge.patientNote != null && pledge.patientNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.online.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 16, color: AppColors.online),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Patient: ${pledge.patientNote}',
                      style: TextStyle(fontSize: 12, color: AppColors.online),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Status Message and Actions
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusBackgroundColor(pledge.status),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(_getStatusIcon(pledge.status), size: 20, color: _getStatusIconColor(pledge.status)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                  _getStatusMessage(pledge),
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                ),
                if (canCancel)
                  TextButton(
                    onPressed: () => _cancelPledge(pledge.id, pledge.bloodRequest),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(DonorPledge pledge) {
    final color = Color(int.parse(pledge.getStatusColor().replaceAll('#', '0xFF')));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        pledge.displayStatus,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.withOpacity(0.05);
      case 'accepted':
        return Colors.green.withOpacity(0.05);
      case 'rejected':
        return Colors.red.withOpacity(0.05);
      case 'donated':
        return AppColors.primary.withOpacity(0.05);
      case 'cancelled':
        return Colors.grey.withOpacity(0.05);
      default:
        return Colors.grey.withOpacity(0.05);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'donated':
        return Icons.favorite;
      case 'cancelled':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusIconColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'donated':
        return AppColors.primary;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusMessage(DonorPledge pledge) {
    switch (pledge.status) {
      case 'pending':
        return 'Waiting for patient to review your pledge';
      case 'accepted':
        return 'Patient accepted your pledge! Contact them to arrange donation';
      case 'rejected':
        return 'Patient selected other donors. Thank you for your willingness';
      case 'donated':
        return 'Donation completed! Thank you for saving lives';
      case 'cancelled':
        return 'This pledge was cancelled';
      default:
        return '';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.volunteer_activism_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No pledges yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Your pledges will appear here after you pledge to donate',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
