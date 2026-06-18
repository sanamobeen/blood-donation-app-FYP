/// Model for representing a selected location from the location picker
class SelectedLocation {
  /// The name of the location (e.g., "City Hospital", "ESS Gulberg")
  final String locationName;

  /// The full address of the location
  final String fullAddress;

  /// Latitude coordinate
  final double latitude;

  /// Longitude coordinate
  final double longitude;

  /// Optional place ID from Nominatim
  final String? placeId;

  /// Optional display name from Nominatim API
  final String? displayName;

  SelectedLocation({
    required this.locationName,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.displayName,
  });

  /// Create from Nominatim API response
  factory SelectedLocation.fromNominatim(Map<String, dynamic> data) {
    // Extract location name from display name or address components
    String locationName = '';
    String fullAddress = '';

    // Try to get a meaningful name
    if (data['name'] != null && data['name'].toString().isNotEmpty) {
      locationName = data['name'].toString();
    } else if (data['display_name'] != null) {
      final displayName = data['display_name'].toString();
      // Use first part of display name as location name
      final parts = displayName.split(',');
      if (parts.isNotEmpty) {
        locationName = parts[0].trim();
      }
    }

    // If still no name, try address components
    if (locationName.isEmpty && data['address'] != null) {
      final address = data['address'] as Map<String, dynamic>;
      // Priority order for location name
      locationName = address['hospital']?.toString() ??
          address['amenity']?.toString() ??
          address['shop']?.toString() ??
          address['building']?.toString() ??
          address['road']?.toString() ??
          'Selected Location';
    }

    // Full address from display_name
    fullAddress = data['display_name']?.toString() ?? '';

    // Extract coordinates
    double lat = 0.0;
    double lon = 0.0;

    if (data['lat'] != null) {
      lat = double.tryParse(data['lat'].toString()) ?? 0.0;
    }
    if (data['lon'] != null) {
      lon = double.tryParse(data['lon'].toString()) ?? 0.0;
    }

    return SelectedLocation(
      locationName: locationName,
      fullAddress: fullAddress,
      latitude: lat,
      longitude: lon,
      placeId: data['place_id']?.toString(),
      displayName: data['display_name']?.toString(),
    );
  }

  /// Create from manual map selection
  factory SelectedLocation.fromCoordinates({
    required String locationName,
    required String fullAddress,
    required double latitude,
    required double longitude,
  }) {
    return SelectedLocation(
      locationName: locationName,
      fullAddress: fullAddress,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'location_name': locationName,
      'full_address': fullAddress,
      'latitude': latitude,
      'longitude': longitude,
      if (placeId != null) 'place_id': placeId,
    };
  }

  /// Create from JSON
  factory SelectedLocation.fromJson(Map<String, dynamic> json) {
    return SelectedLocation(
      locationName: json['location_name'] ?? json['locationName'] ?? '',
      fullAddress: json['full_address'] ?? json['fullAddress'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      placeId: json['place_id'],
      displayName: json['display_name'],
    );
  }

  /// Copy with method for immutability
  SelectedLocation copyWith({
    String? locationName,
    String? fullAddress,
    double? latitude,
    double? longitude,
    String? placeId,
    String? displayName,
  }) {
    return SelectedLocation(
      locationName: locationName ?? this.locationName,
      fullAddress: fullAddress ?? this.fullAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeId: placeId ?? this.placeId,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  String toString() {
    return '$locationName - $fullAddress';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SelectedLocation &&
        other.locationName == locationName &&
        other.fullAddress == fullAddress &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return locationName.hashCode ^
        fullAddress.hashCode ^
        latitude.hashCode ^
        longitude.hashCode;
  }
}
