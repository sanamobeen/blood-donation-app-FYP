import 'package:flutter/material.dart';
import '../../models/donor_pledge.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/string_extensions.dart';

/// Patient Donor Management Screen
/// Shows all pledged donors for a patient's blood request with accept/reject actions
class PatientDonorManagementScreen extends StatefulWidget {
  final String requestId;
  final String patientName;
  final String bloodGroup;
  final int unitsNeeded;

  const PatientDonorManagementScreen({
    super.key,
    required this.requestId,
    required this.patientName,
    required this.bloodGroup,
    required this.unitsNeeded,
  });

  @override
  State<PatientDonorManagementScreen> createState() => _PatientDonorManagementScreenState();
}

class _PatientDonorManagementScreenState extends State<PatientDonorManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DonorPledge> _pledges = [];
  PledgeSummary? _summary;
  String _selectedStatusFilter = 'all';

  // Selected pledges for batch operations
  final Set<String> _selectedPledgeIds = {};

  @override
  void initState() {
    super.initState();
    _loadPledgedDonors();
  }

  Future<void> _loadPledgedDonors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getPledgedDonorsForPatient(widget.requestId);

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
            _errorMessage = response['message'] ?? 'Failed to load donors';
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

  List<DonorPledge> get _filteredPledges {
    if (_selectedStatusFilter == 'all') return _pledges;
    return _pledges.where((p) => p.status == _selectedStatusFilter).toList();
  }

  Future<void> _acceptPledge(String pledgeId, {String? note}) async {
    try {
      final response = await ApiService.acceptPledge(
        requestId: widget.requestId,
        pledgeId: pledgeId,
        patientNote: note,
      );

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pledge accepted successfully!'),
            backgroundColor: AppColors.online,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadPledgedDonors();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to accept pledge'),
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

  Future<void> _rejectPledge(String pledgeId, {String? reason}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Pledge'),
        content: const Text('Are you sure you want to reject this pledge?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await ApiService.rejectPledge(
          requestId: widget.requestId,
          pledgeId: pledgeId,
          reason: reason,
        );

        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pledge rejected'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadPledgedDonors();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to reject pledge'),
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

  Future<void> _batchAcceptPledges() async {
    if (_selectedPledgeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select pledges to accept'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final response = await ApiService.acceptPledgesBatch(
        requestId: widget.requestId,
        pledgeIds: _selectedPledgeIds.toList(),
      );

      if (response['success'] == true) {
        final acceptedCount = response['data']?['accepted_count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$acceptedCount pledge(s) accepted successfully!'),
            backgroundColor: AppColors.online,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _selectedPledgeIds.clear();
        });
        _loadPledgedDonors();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to accept pledges'),
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

  void _togglePledgeSelection(String pledgeId) {
    setState(() {
      if (_selectedPledgeIds.contains(pledgeId)) {
        _selectedPledgeIds.remove(pledgeId);
      } else {
        _selectedPledgeIds.add(pledgeId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Manage Donors'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedPledgeIds.isNotEmpty)
            TextButton.icon(
              onPressed: _batchAcceptPledges,
              icon: const Icon(Icons.check_circle, size: 20),
              label: Text('Accept ${_selectedPledgeIds.length}'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.online,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
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
            onPressed: _loadPledgedDonors,
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
        _buildSummaryCards(),

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
    if (_summary == null) return const SizedBox.shrink();

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
    final filters = ['all', 'pending', 'accepted', 'rejected', 'donated'];

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
    final isSelected = _selectedPledgeIds.contains(pledge.id);
    // Use mapped frontend statuses from the DonorPledge model
    final canAccept = pledge.isPending;
    final canReject = pledge.isPending || pledge.isAccepted;
    final canComplete = pledge.isAccepted; // Accepted pledges can be marked as donated

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
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
          // Header with selection checkbox
          Row(
            children: [
              if (canAccept)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _togglePledgeSelection(pledge.id),
                  activeColor: AppColors.primary,
                )
              else
                const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pledge.donorName ?? 'Anonymous Donor',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (pledge.donorBloodGroup != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '🩸 ${pledge.donorBloodGroup}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (pledge.donorCity != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                pledge.donorCity!,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
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

          // Action Buttons
          if (canAccept || canReject || canComplete) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (canComplete)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _completePledgeDonation(
                        pledge.id,
                        pledge.unitsPledged,
                        pledge.donorName ?? 'Donor',
                      ),
                      icon: const Icon(Icons.volunteer_activism, size: 16),
                      label: const Text('Complete Donation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (canComplete && canAccept) const SizedBox(width: 8),
                if (canAccept)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _acceptPledge(pledge.id),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Accept'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.online,
                        side: BorderSide(color: AppColors.online),
                      ),
                    ),
                  ),
                if ((canAccept || canComplete) && canReject) const SizedBox(width: 8),
                if (canReject)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _rejectPledge(pledge.id),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _completePledgeDonation(String pledgeId, int unitsPledged, String donorName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Donation'),
        content: Text(
          'Has $donorName donated $unitsPledged unit${unitsPledged > 1 ? 's' : ''} of blood?\n\n'
          'This will create a donation record and generate a certificate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.online,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Donation'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await ApiService.completePledgeDonation(
          requestId: widget.requestId,
          pledgeId: pledgeId,
          unitsDonated: unitsPledged,
        );

        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Donation completed successfully!'),
              backgroundColor: AppColors.online,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
          _loadPledgedDonors();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to complete donation'),
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

  Widget _buildStatusBadge(DonorPledge pledge) {
    final color = Color(int.parse(pledge.getStatusColor().replaceFirst('#', '0xFF')));
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No pledges found',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Donors who pledge to help will appear here',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
