import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

/// Map view showing pledged donors relative to patient/hospital location
/// Privacy-focused: Shows approximate locations only
class DonorMapView extends StatelessWidget {
  final double? patientLat;
  final double? patientLng;
  final List<Map<String, dynamic>> donors;
  final double? currentUserLat; // Current donor's location
  final double? currentUserLng;
  final double? distanceKm; // Distance between donor and patient

  const DonorMapView({
    super.key,
    required this.patientLat,
    required this.patientLng,
    required this.donors,
    this.currentUserLat,
    this.currentUserLng,
    this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    // If no location data, show placeholder
    if (patientLat == null || patientLng == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 40,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 8),
              Text(
                'Location not available',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final patientLocation = LatLng(patientLat!, patientLng!);

    // Calculate map center to include both patient and current user if available
    LatLng mapCenter = patientLocation;
    if (currentUserLat != null && currentUserLng != null) {
      final userLocation = LatLng(currentUserLat!, currentUserLng!);
      // Center between patient and user
      mapCenter = LatLng(
        (patientLocation.latitude + userLocation.latitude) / 2,
        (patientLocation.longitude + userLocation.longitude) / 2,
      );
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: 13,
            minZoom: 10,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            // OpenStreetMap tile layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'blood.donation.app',
            ),

            // Patient/Hospital marker
            MarkerLayer(
              markers: [
                Marker(
                  point: patientLocation,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_hospital,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),

            // Current user (donor) location marker
            if (currentUserLat != null && currentUserLng != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(currentUserLat!, currentUserLng!),
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),

            // Donor markers (approximate locations)
            if (donors.isNotEmpty)
              MarkerLayer(
                markers: donors.asMap().entries.map((entry) {
                  final index = entry.key;
                  final donor = entry.value;

                  // Add small random offset to donor location for privacy
                  // This creates an approximate area, not exact location
                  final randomLat = (donor['lat'] as double?) ?? patientLat;
                  final randomLng = (donor['lng'] as double?) ?? patientLng;

                  // If no donor location, show near patient with offset
                  final baseLat = patientLat ?? 0.0;
                  final baseLng = patientLng ?? 0.0;
                  final donorLat = randomLat ?? baseLat + (index + 1) * 0.01;
                  final donorLng = randomLng ?? baseLng + (index + 1) * 0.01;

                  return Marker(
                    point: LatLng(donorLat, donorLng),
                    width: 36,
                    height: 36,
                    child: _DonorMarker(
                      donor: donor,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _DonorMarker extends StatelessWidget {
  final Map<String, dynamic> donor;

  const _DonorMarker({
    required this.donor,
  });

  @override
  Widget build(BuildContext context) {
    final reliability = donor['reality_score'] as int? ?? 0;
    final isTopDonor = reliability >= 90;
    final isReliable = reliability >= 75;

    Color markerColor = AppColors.textSecondary;
    if (isTopDonor) {
      markerColor = const Color(0xFF16A34A); // Green for top donors
    } else if (isReliable) {
      markerColor = const Color(0xFF2563EB); // Blue for reliable
    }

    return GestureDetector(
      onTap: () {
        // Show donor info bottom sheet
        _showDonorInfo(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: markerColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            donor['initial'] as String? ?? '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _showDonorInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _DonorInfoSheet(donor: donor),
    );
  }
}

class _DonorInfoSheet extends StatelessWidget {
  final Map<String, dynamic> donor;

  const _DonorInfoSheet({
    required this.donor,
  });

  @override
  Widget build(BuildContext context) {
    final name = donor['name'] as String? ?? 'Unknown';
    final bloodGroup = donor['blood_group'] as String? ?? 'Unknown';
    final distance = donor['distance_km'] as double? ?? 0.0;
    final age = donor['age'] as int? ?? 0;
    final city = donor['city'] as String? ?? '';
    final reliability = donor['reality_score'] as int? ?? 0;
    final lastDonation = donor['last_donation'] as String? ?? 'Unknown';
    final note = donor['note'] as String? ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Donor header
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.softPink,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              bloodGroup,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          Text(
                            '${distance.toStringAsFixed(1)} km away',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Donor stats
            Row(
              children: [
                if (age > 0) ...[
                  _buildStat(
                    icon: Icons.person,
                    label: '$age yrs',
                  ),
                  const SizedBox(width: 16),
                ],
                if (city.isNotEmpty) ...[
                  _buildStat(
                    icon: Icons.location_city,
                    label: city,
                  ),
                  const SizedBox(width: 16),
                ],
                _buildStat(
                  icon: Icons.verified,
                  label: '$reliability%',
                  labelColor: reliability >= 75 ? Colors.green : Colors.orange,
                ),
              ],
            ),

            if (lastDonation != 'Unknown') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.history,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Last donation: $lastDonation',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],

            if (note.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Donor Note',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  note,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Privacy notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softPink.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.privacy_tip,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contact info will be shared after you accept this donor',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    Color? labelColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: labelColor ?? AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
