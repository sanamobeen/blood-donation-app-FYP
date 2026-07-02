import 'package:flutter/material.dart';
import '../models/donor_availability.dart';
import '../theme/app_theme.dart';

/// Availability Scheduler Widget
/// Allows donors to select their weekly availability with time slots
class AvailabilityScheduler extends StatefulWidget {
  final DonorAvailability? initialAvailability;
  final ValueChanged<DonorAvailability?> onAvailabilityChanged;

  const AvailabilityScheduler({
    super.key,
    this.initialAvailability,
    required this.onAvailabilityChanged,
  });

  @override
  State<AvailabilityScheduler> createState() => _AvailabilitySchedulerState();
}

class _AvailabilitySchedulerState extends State<AvailabilityScheduler> {
  late Set<String> _selectedDays;
  late Map<String, List<String>> _timeSlotsPerDay;
  late bool _availableAllDay;

  @override
  void initState() {
    super.initState();
    if (widget.initialAvailability != null) {
      _selectedDays = Set.from(widget.initialAvailability!.availableDays);
      _timeSlotsPerDay = Map.from(widget.initialAvailability!.timeSlotsPerDay);
      _availableAllDay = widget.initialAvailability!.availableAllDay;
    } else {
      _selectedDays = {};
      _timeSlotsPerDay = {};
      _availableAllDay = false;
    }
  }

  void _notifyAvailabilityChanged() {
    final availability = _selectedDays.isEmpty
        ? null
        : DonorAvailability(
            availableDays: _selectedDays,
            timeSlotsPerDay: _timeSlotsPerDay,
            availableAllDay: _availableAllDay,
          );
    widget.onAvailabilityChanged(availability);
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
        _timeSlotsPerDay.remove(day);
      } else {
        _selectedDays.add(day);
        // Start with empty time slots for new day - user will select specific slots
        _timeSlotsPerDay[day] = [];
      }
      _notifyAvailabilityChanged();
    });
  }

  void _toggleTimeSlot(String day, String timeSlotId) {
    setState(() {
      if (!_timeSlotsPerDay.containsKey(day)) {
        _timeSlotsPerDay[day] = [];
      }

      final slots = _timeSlotsPerDay[day]!;
      if (slots.contains(timeSlotId)) {
        slots.remove(timeSlotId);
      } else {
        slots.add(timeSlotId);
      }

      _notifyAvailabilityChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            const Icon(
              Icons.access_time,
              color: AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              'Your Availability',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Day Selector
        _buildDaySelector(),

        // Time Slot Selector (only show if days are selected)
        if (_selectedDays.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildTimeSlotSelector(),
        ],

        // Helper text
        const SizedBox(height: 8),
        Text(
          _selectedDays.isEmpty
              ? 'Select the days you\'re available to donate'
              : 'You\'re available on ${_selectedDays.length} day${_selectedDays.length == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildDaySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DonorAvailability.daysOfWeek.map((day) {
        final isSelected = _selectedDays.contains(day);
        return GestureDetector(
          onTap: () => _toggleDay(day),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DonorAvailability.getShortDayName(day),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeSlotSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            const Icon(
              Icons.schedule,
              color: AppColors.primary,
              size: 14,
            ),
            const SizedBox(width: 8),
            const Text(
              'Available Time Slots',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Time Slot Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: DonorAvailability.timeSlotIds.length,
          itemBuilder: (context, index) {
            final timeSlotId = DonorAvailability.timeSlotIds[index];
            final label = DonorAvailability.getTimeSlotLabel(timeSlotId);

            // Check if this time slot is selected for ANY of the selected days
            final isSelectedForAnyDay = _selectedDays.any((day) {
              final slots = _timeSlotsPerDay[day] ?? [];
              return slots.contains(timeSlotId);
            });

            return GestureDetector(
              onTap: () {
                // Toggle this time slot for all selected days
                setState(() {
                  for (final day in _selectedDays) {
                    _toggleTimeSlot(day, timeSlotId);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelectedForAnyDay
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.white,
                  border: Border.all(
                    color: isSelectedForAnyDay
                        ? AppColors.primary
                        : AppColors.border,
                    width: isSelectedForAnyDay ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (isSelectedForAnyDay)
                      Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 16,
                      )
                    else
                      Icon(
                        Icons.radio_button_unchecked,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                        size: 16,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelectedForAnyDay
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // All Day Toggle
        GestureDetector(
          onTap: () {
            setState(() {
              _availableAllDay = !_availableAllDay;
              _notifyAvailabilityChanged();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _availableAllDay
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.white,
              border: Border.all(
                color: _availableAllDay ? AppColors.primary : AppColors.border,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _availableAllDay ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _availableAllDay ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.5),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Available all day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _availableAllDay ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '(Skip time slots)',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
