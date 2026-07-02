/// Donor Availability Model
/// Stores donor's weekly availability schedule with time slots
class DonorAvailability {
  // Days of the week that the donor is available
  final Set<String> availableDays;

  // Time slots for each day (key: day name, value: list of time slot IDs)
  // Time slot IDs: 2-hour slots covering 24 hours
  final Map<String, List<String>> timeSlotsPerDay;

  // Whether donor is available all day (no time slot restrictions)
  final bool availableAllDay;

  static const List<String> daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const Map<String, String> timeSlotLabels = {
    '12am_2am': '12AM - 2AM',
    '2am_4am': '2AM - 4AM',
    '4am_6am': '4AM - 6AM',
    '6am_8am': '6AM - 8AM',
    '8am_10am': '8AM - 10AM',
    '10am_12pm': '10AM - 12PM',
    '12pm_2pm': '12PM - 2PM',
    '2pm_4pm': '2PM - 4PM',
    '4pm_6pm': '4PM - 6PM',
    '6pm_8pm': '6PM - 8PM',
    '8pm_10pm': '8PM - 10PM',
    '10pm_12am': '10PM - 12AM',
  };

  static const List<String> timeSlotIds = [
    '12am_2am',
    '2am_4am',
    '4am_6am',
    '6am_8am',
    '8am_10am',
    '10am_12pm',
    '12pm_2pm',
    '2pm_4pm',
    '4pm_6pm',
    '6pm_8pm',
    '8pm_10pm',
    '10pm_12am',
  ];

  DonorAvailability({
    required this.availableDays,
    required this.timeSlotsPerDay,
    this.availableAllDay = false,
  });

  /// Create DonorAvailability from JSON
  factory DonorAvailability.fromJson(Map<String, dynamic> json) {
    final availableDays = Set<String>.from(
      json['available_days'] ?? [],
    );

    final timeSlotsPerDay = <String, List<String>>{};
    if (json['time_slots'] != null) {
      (json['time_slots'] as Map).forEach((key, value) {
        timeSlotsPerDay[key] = List<String>.from(value);
      });
    }

    return DonorAvailability(
      availableDays: availableDays,
      timeSlotsPerDay: timeSlotsPerDay,
      availableAllDay: json['available_all_day'] ?? false,
    );
  }

  /// Convert DonorAvailability to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'available_days': availableDays.toList(),
      'time_slots': timeSlotsPerDay,
      'available_all_day': availableAllDay,
    };
  }

  /// Get time slots for a specific day
  List<String> getTimeSlotsForDay(String day) {
    if (availableAllDay) {
      return timeSlotIds;
    }
    return timeSlotsPerDay[day] ?? [];
  }

  /// Check if donor is available on a specific day
  bool isAvailableOnDay(String day) {
    return availableDays.contains(day);
  }

  /// Check if donor is available on a specific day and time slot
  bool isAvailableAtTime(String day, String timeSlotId) {
    if (!availableDays.contains(day)) {
      return false;
    }
    if (availableAllDay) {
      return true;
    }
    final daySlots = timeSlotsPerDay[day] ?? [];
    return daySlots.contains(timeSlotId);
  }

  /// Get display label for a time slot
  static String getTimeSlotLabel(String timeSlotId) {
    return timeSlotLabels[timeSlotId] ?? timeSlotId;
  }

  /// Get short day name (first 3 letters)
  static String getShortDayName(String day) {
    return day.substring(0, 3);
  }

  /// Create a copy with modified fields
  DonorAvailability copyWith({
    Set<String>? availableDays,
    Map<String, List<String>>? timeSlotsPerDay,
    bool? availableAllDay,
  }) {
    return DonorAvailability(
      availableDays: availableDays ?? this.availableDays,
      timeSlotsPerDay: timeSlotsPerDay ?? this.timeSlotsPerDay,
      availableAllDay: availableAllDay ?? this.availableAllDay,
    );
  }

  @override
  String toString() {
    return 'DonorAvailability(availableDays: $availableDays, availableAllDay: $availableAllDay, timeSlotsPerDay: $timeSlotsPerDay)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DonorAvailability &&
        other.availableDays.toString() == availableDays.toString() &&
        other.availableAllDay == availableAllDay &&
        _mapsEqual(other.timeSlotsPerDay, timeSlotsPerDay);
  }

  bool _mapsEqual(Map<String, List<String>> a, Map<String, List<String>> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_listEquals(b[key]!, a[key]!)) {
        return false;
      }
    }
    return true;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      availableDays.hashCode ^
      availableAllDay.hashCode ^
      timeSlotsPerDay.hashCode;
}
