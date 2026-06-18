import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Progress bar widget showing blood request fulfillment progress
class BloodRequestProgressBar extends StatelessWidget {
  final int unitsNeeded;
  final int unitsPledged;
  final int unitsReceived;
  final int respondersCount;

  const BloodRequestProgressBar({
    super.key,
    required this.unitsNeeded,
    required this.unitsPledged,
    this.unitsReceived = 0,
    this.respondersCount = 0,
  });

  /// Get progress percentage (0-100)
  double get progressPercentage {
    if (unitsNeeded == 0) return 0;
    return (unitsPledged / unitsNeeded).clamp(0.0, 1.0);
  }

  /// Get units remaining
  int get unitsRemaining => unitsNeeded - unitsPledged;

  /// Get progress color based on completion
  Color get progressColor {
    final percentage = progressPercentage;
    if (percentage >= 1.0) return AppColors.online;
    if (percentage >= 0.5) return AppColors.primary;
    return AppColors.urgencyUrgent;
  }

  @override
  Widget build(BuildContext context) {
    final percentage = progressPercentage;
    final remaining = unitsRemaining;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.softPink),
        boxShadow: [
          BoxShadow(
            color: AppColors.softPink.withOpacity(0.2),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: AppTypography.h3.copyWith(fontSize: 18),
              ),
              if (percentage >= 1.0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.online.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.online,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Complete!',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.online,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: AppColors.softPink.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _buildStat(
                label: 'Pledged',
                value: '$unitsPledged/$unitsNeeded',
                icon: Icons.volunteer_activism,
              ),
              const SizedBox(width: 16),
              if (unitsReceived > 0)
                _buildStat(
                  label: 'Received',
                  value: '$unitsReceived',
                  icon: Icons.bloodtype,
                ),
              if (unitsReceived > 0) const SizedBox(width: 16),
              _buildStat(
                label: 'Donors',
                value: '$respondersCount',
                icon: Icons.people,
              ),
            ],
          ),

          // Remaining message
          if (remaining > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.softPink.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$remaining more ${remaining == 1 ? 'donor' : 'donors'} needed',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact version of the progress bar for use in cards
class CompactProgressBar extends StatelessWidget {
  final int unitsNeeded;
  final int unitsPledged;

  const CompactProgressBar({
    super.key,
    required this.unitsNeeded,
    required this.unitsPledged,
  });

  double get progressPercentage {
    if (unitsNeeded == 0) return 0;
    return (unitsPledged / unitsNeeded).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final percentage = progressPercentage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$unitsPledged/$unitsNeeded units pledged',
              style: AppTypography.bodySmall,
            ),
            Text(
              '${(percentage * 100).toInt()}%',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: AppColors.softPink.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
