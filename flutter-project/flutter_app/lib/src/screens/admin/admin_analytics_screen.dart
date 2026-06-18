import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/admin_provider.dart';
import '../../models/admin/admin_dashboard_data.dart';
import '../../theme/app_theme.dart';

/// Admin Analytics Screen
/// Displays charts and statistics for platform analytics
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Load analytics with default range (last 30 days)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnalytics();
    });
  }

  void _loadAnalytics() {
    context.read<AdminProvider>().loadAnalyticsData(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        _buildHeader(),

        // Date range selector
        _buildDateRangeSelector(),

        // Analytics content
        Expanded(
          child: _buildAnalyticsContent(),
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
          const Icon(Icons.analytics, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Platform Analytics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'View platform statistics and trends',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.grey[50],
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          InkWell(
            onTap: _selectDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedDateRange != null
                        ? '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}'
                        : 'Last 30 Days',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey[700]),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (_selectedDateRange != null)
            TextButton.icon(
              onPressed: () {
                setState(() => _selectedDateRange = null);
                _loadAnalytics();
              },
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _loadAnalytics();
    }
  }

  Widget _buildAnalyticsContent() {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingAnalytics) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.analyticsError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Failed to load analytics',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadAnalytics,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final analytics = provider.analyticsData;
        if (analytics == null) {
          return const Center(child: Text('No analytics data available'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Growth Chart
              _buildChartCard(
                title: 'User Growth',
                child: _buildUserGrowthChart(analytics.userGrowth),
              ),

              const SizedBox(height: 24),

              // Blood Type Distribution & Donation Stats
              Row(
                children: [
                  Expanded(
                    child: _buildChartCard(
                      title: 'Blood Type Distribution',
                      child: _buildBloodTypePieChart(analytics.bloodTypeDistribution),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildChartCard(
                      title: 'Donation Trends',
                      child: _buildDonationBarChart(analytics.donationStats),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Geographic Distribution
              _buildChartCard(
                title: 'Top Locations',
                child: _buildGeographicList(analytics.geographicDistribution),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: title == 'Top Locations' ? null : 300,
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrowthChart(List<UserGrowthData> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey[200]!,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= data.length) {
                  return const SizedBox();
                }
                return Text(
                  _formatShortDate(data[value.toInt()].date),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                );
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox();
                }
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                );
              },
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Total Users line
          LineChartBarData(
            spots: data.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.totalUsers.toDouble());
            }).toList(),
            isCurved: true,
            color: AppTheme.primaryColor,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
          // New Donors line
          LineChartBarData(
            spots: data.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.newDonors.toDouble());
            }).toList(),
            isCurved: true,
            color: Colors.red,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
        minY: 0,
        maxY: data.map((d) => d.totalUsers).reduce((a, b) => a > b ? a : b).toDouble() * 1.1,
      ),
    );
  }

  Widget _buildBloodTypePieChart(List<BloodTypeDistribution> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        sections: data.map((item) {
          final color = _getBloodTypeColor(item.bloodType);
          return PieChartSectionData(
            value: item.count.toDouble(),
            title: '${item.bloodType}\n${item.percentage.toStringAsFixed(0)}%',
            color: color,
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDonationBarChart(List<DonationStatsData> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey[200]!,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= data.length) {
                  return const SizedBox();
                }
                return Text(
                  _formatShortMonth(data[value.toInt()].month),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                );
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min || value == 0) {
                  return const SizedBox();
                }
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                );
              },
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.units.toDouble(),
                color: AppTheme.primaryColor,
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGeographicList(List<GeographicDistribution> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return Column(
      children: data.take(10).map((location) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.city,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (location.state != null)
                      Text(
                        location.state!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${location.userCount} users',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getBloodTypeColor(String bloodType) {
    switch (bloodType) {
      case 'A+':
        return const Color(0xFFE53935);
      case 'A-':
        return const Color(0xFFEF5350);
      case 'B+':
        return const Color(0xFF1E88E5);
      case 'B-':
        return const Color(0xFF42A5F5);
      case 'AB+':
        return const Color(0xFF8E24AA);
      case 'AB-':
        return const Color(0xFFAB47BC);
      case 'O+':
        return const Color(0xFF43A047);
      case 'O-':
        return const Color(0xFF66BB6A);
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatShortDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  String _formatShortMonth(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[date.month - 1];
  }
}
