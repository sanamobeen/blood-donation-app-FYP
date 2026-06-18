import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../models/selected_location.dart';

/// Location Service - Helper for location-related operations
/// Provides methods for getting current location, calculating distances,
/// managing location permissions, and Nominatim API integration
class LocationService {
  static const String _lastKnownLatKey = 'last_known_lat';
  static const String _lastKnownLngKey = 'last_known_lng';
  static const String _locationTimestampKey = 'location_timestamp';

  // Nominatim API configuration
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'BloodDonationApp';
  static const int _minSearchChars = 2;
  static const Duration _searchDebounce = Duration(milliseconds: 500);

  // Search debounce timer
  Timer? _debounceTimer;

  // Singleton pattern
  LocationService._();
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  /// Get current position
  Future<Position?> getCurrentPosition({bool forceRefresh = false}) async {
    if (_currentPosition != null && !forceRefresh) {
      return _currentPosition;
    }

    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Try to use last known location
        final lastKnown = await getLastKnownLocation();
        if (lastKnown != null) {
          return Position(
            latitude: lastKnown['lat']!,
            longitude: lastKnown['lng']!,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              lastKnown['timestamp']!.toInt(),
            ),
            accuracy: 0.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          );
        }
        return null;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Cache the location
      await _cacheLocation(_currentPosition!);

      return _currentPosition;
    } catch (e) {
      return null;
    }
  }

  /// Get last known location from cache
  Future<Map<String, double>?> getLastKnownLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_lastKnownLatKey);
      final lng = prefs.getDouble(_lastKnownLngKey);
      final timestamp = prefs.getInt(_locationTimestampKey);

      if (lat != null && lng != null && timestamp != null) {
        // Check if location is recent (less than 1 hour old)
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age < 3600000) {
          return {'lat': lat, 'lng': lng, 'timestamp': timestamp.toDouble()};
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Cache location for later use
  Future<void> _cacheLocation(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_lastKnownLatKey, position.latitude);
      await prefs.setDouble(_lastKnownLngKey, position.longitude);
      await prefs.setInt(
        _locationTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
    }
  }

  /// Clear cached location
  Future<void> clearCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastKnownLatKey);
      await prefs.remove(_lastKnownLngKey);
      await prefs.remove(_locationTimestampKey);
      _currentPosition = null;
    } catch (e) {
    }
  }

  /// Calculate distance between two points in kilometers
  double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // Radius of Earth in kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLng = _toRadians(lng2 - lng1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calculate distance between position and a point in kilometers
  double? calculateDistanceFromPosition(
    Position position,
    double destinationLat,
    double destinationLng,
  ) {
    return calculateDistance(
      position.latitude,
      position.longitude,
      destinationLat,
      destinationLng,
    );
  }

  /// Convert degrees to radians
  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  /// Get location permission status
  Future<LocationPermission> getLocationPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Check if location service is enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Start continuous location updates
  void startLocationUpdates({
    LocationSettings? locationSettings,
    required void Function(Position) onLocationUpdate,
    required void Function(dynamic) onError,
  }) {
    _positionStreamSubscription?.cancel();

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      onLocationUpdate,
      onError: onError,
    );
  }

  /// Stop location updates
  void stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Get distance between user and target in formatted string
  Future<String?> getDistanceString(double targetLat, double targetLng) async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    final distance = calculateDistance(
      position.latitude,
      position.longitude,
      targetLat,
      targetLng,
    );

    if (distance < 1) {
      return '${(distance * 1000).toInt()} m away';
    } else {
      return '${distance.toStringAsFixed(1)} km away';
    }
  }

  /// Get current coordinates as a map
  Future<Map<String, double>?> getCurrentCoordinates({bool forceRefresh = false}) async {
    final position = await getCurrentPosition(forceRefresh: forceRefresh);
    if (position == null) return null;

    return {
      'lat': position.latitude,
      'lng': position.longitude,
    };
  }

  /// Check if target is within radius of user location
  Future<bool> isWithinRadius(
    double targetLat,
    double targetLng,
    double radiusKm,
  ) async {
    final position = await getCurrentPosition();
    if (position == null) return false;

    final distance = calculateDistance(
      position.latitude,
      position.longitude,
      targetLat,
      targetLng,
    );

    return distance <= radiusKm;
  }

  /// Dispose resources
  void dispose() {
    stopLocationUpdates();
    _debounceTimer?.cancel();
  }

  // ===== NOMINATIM API METHODS =====

  /// Search for places using Nominatim API
  /// Returns a list of SelectedLocation objects
  Future<List<SelectedLocation>> searchPlaces({
    required String query,
    int limit = 5,
    String? countryCodes,
  }) async {
    if (query.trim().length < _minSearchChars) {
      return [];
    }

    try {
      // Extract city from query for better filtering
      final searchQuery = query.trim();
      String? extractedCity;

      // Major cities in Pakistan for filtering (expanded list)
      final majorCities = [
        'karachi', 'lahore', 'islamabad', 'rawalpindi', 'faisalabad',
        'multan', 'peshawar', 'quetta', 'sialkot', 'gujranwala',
        'sargodha', 'sahiwal', 'hyderabad', 'murree', 'abbottabad',
        'haripur', 'mardan', 'swabi', 'nowshera', 'charsadda',
        'dargai', 'malakand', 'batkhela', 'timergara', 'chakdara',
        'dir', 'chitral', 'bajaur', 'mohmand', 'khyber', 'kurram',
        'orakzai', 'waziristan', 'bannu', 'dikkhan', 'tank', 'kohat',
        'hangu', 'karak', 'lakki marwat', 'bannu', 'jhelum', 'sialkot',
        'gujrat', 'sheikhupura', 'kasur', 'okara', 'rahim yar khan',
        'sadiqabad', 'bhawalpur', 'dera ghazi khan', 'muzaffarabad',
        'mirpur', 'mangla', 'kotli', 'rawalakot', 'pallandri',
        'hunza', 'skardu', 'gilgit', 'chilas', 'astore'
      ];

      // Check if query contains a city name
      final lowerQuery = searchQuery.toLowerCase();
      for (final city in majorCities) {
        if (lowerQuery.contains(city)) {
          extractedCity = city;
          break;
        }
      }

      // Try multiple search strategies in order
      List<SelectedLocation> results = [];

      // Strategy 1: Search with city filter
      results = await _performSearch(
        searchQuery: searchQuery,
        extractedCity: extractedCity,
        countryCodes: countryCodes,
        limit: limit,
      );

      // Strategy 2: If no results and city was specified, try without city filter
      if (results.isEmpty && extractedCity != null) {
        results = await _performSearch(
          searchQuery: searchQuery,
          extractedCity: null,
          countryCodes: countryCodes,
          limit: limit,
        );
      }

      // Strategy 3: Try with just the business name (remove city from query)
      if (results.isEmpty && extractedCity != null) {
        final businessName = searchQuery.toLowerCase().replaceAll(extractedCity, '').trim();
        if (businessName.length >= _minSearchChars) {
          results = await _performSearch(
            searchQuery: businessName,
            extractedCity: extractedCity,
            countryCodes: countryCodes,
            limit: limit,
          );
        }
      }

      // Strategy 4: Try simplified query (first 2 words)
      if (results.isEmpty && searchQuery.contains(' ')) {
        final words = searchQuery.split(' ');
        if (words.length > 2) {
          final simplifiedQuery = words.sublist(0, 2).join(' ');
          results = await _performSearch(
            searchQuery: simplifiedQuery,
            extractedCity: extractedCity,
            countryCodes: countryCodes,
            limit: limit,
          );
        }
      }

      // Strategy 5: Try each word separately
      if (results.isEmpty && searchQuery.contains(' ')) {
        final words = searchQuery.split(' ');
        for (final word in words) {
          if (word.length >= 3) {
            final wordResults = await _performSearch(
              searchQuery: word,
              extractedCity: extractedCity,
              countryCodes: countryCodes,
              limit: 2,
            );
            results.addAll(wordResults);
            if (results.length >= limit) break;
          }
        }
        // Remove duplicates and limit
        results = _removeDuplicates(results);
        if (results.length > limit) {
          results = results.sublist(0, limit);
        }
      }

      return results;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Search failed: $e');
    }
  }

  /// Perform the actual search with given parameters
  Future<List<SelectedLocation>> _performSearch({
    required String searchQuery,
    String? extractedCity,
    String? countryCodes,
    required int limit,
  }) async {
    // Build query parameters with better filtering
    final queryParams = {
      'q': searchQuery,
      'format': 'json',
      'addressdetails': '1',
      'limit': (limit * 3).toString(), // Fetch more results for filtering
      if (countryCodes != null) 'countrycodes': countryCodes,
      'namedetails': '1',
      'extratags': '1',
      // Add city filter if detected
      if (extractedCity != null) 'city': extractedCity,
    };

    final uri = Uri.parse('$_nominatimBaseUrl/search')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
        'Accept-Language': 'en',  // Force English language responses
      },
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => http.Response('Timeout', 408),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      List<SelectedLocation> results = data
          .map((item) => SelectedLocation.fromNominatim(item as Map<String, dynamic>))
          .toList();

      // Filter results to ensure relevance
      if (extractedCity != null) {
        results = _filterByCityRelevance(results, extractedCity, searchQuery);
      }

      // Remove duplicates based on name and address
      results = _removeDuplicates(results);

      // Limit results
      if (results.length > limit) {
        results = results.sublist(0, limit);
      }

      return results;
    } else if (response.statusCode == 408) {
      throw Exception('Request timeout. Please try again.');
    } else {
      throw Exception('Failed to search places: ${response.statusCode}');
    }
  }

  /// Filter results by city relevance
  /// Prioritizes results that are in the specified city or have the city in their name
  List<SelectedLocation> _filterByCityRelevance(
    List<SelectedLocation> results,
    String city,
    String originalQuery,
  ) {
    final cityLower = city.toLowerCase();
    final queryLower = originalQuery.toLowerCase();

    // Sort results by relevance
    results.sort((a, b) {
      int scoreA = _calculateRelevanceScore(a, cityLower, queryLower);
      int scoreB = _calculateRelevanceScore(b, cityLower, queryLower);
      return scoreB.compareTo(scoreA); // Higher score first
    });

    return results;
  }

  /// Calculate relevance score for a location result
  int _calculateRelevanceScore(SelectedLocation location, String city, String query) {
    int score = 0;

    // Check if city is in location name
    if (location.locationName.toLowerCase().contains(city)) {
      score += 10;
    }

    // Check if city is in full address
    if (location.fullAddress.toLowerCase().contains(city)) {
      score += 5;
    }

    // Check if query terms are in the name
    final queryWords = query.split(' ');
    for (final word in queryWords) {
      if (word.length > 2 && location.locationName.toLowerCase().contains(word)) {
        score += 3;
      }
    }

    // Exact match bonus
    if (location.locationName.toLowerCase().contains(query)) {
      score += 15;
    }

    return score;
  }

  /// Remove duplicate locations based on name and coordinates
  List<SelectedLocation> _removeDuplicates(List<SelectedLocation> locations) {
    final Map<String, SelectedLocation> uniqueLocations = {};

    for (final location in locations) {
      // Create a key based on name and rounded coordinates
      final key = '${location.locationName.toLowerCase()}_'
          '${location.latitude.toStringAsFixed(4)}_${location.longitude.toStringAsFixed(4)}';

      if (!uniqueLocations.containsKey(key)) {
        uniqueLocations[key] = location;
      }
    }

    return uniqueLocations.values.toList();
  }

  /// Debounced search - returns a stream of search results
  Stream<List<SelectedLocation>> searchPlacesDebounced({
    required String query,
    int limit = 5,
    String? countryCodes,
  }) async* {
    _debounceTimer?.cancel();

    if (query.trim().length < _minSearchChars) {
      yield [];
      return;
    }

    final completer = Completer<List<SelectedLocation>>();

    _debounceTimer = Timer(_searchDebounce, () async {
      try {
        final results = await searchPlaces(
          query: query,
          limit: limit,
          countryCodes: countryCodes,
        );
        if (!completer.isCompleted) {
          completer.complete(results);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.complete([]);
        }
      }
    });

    final results = await completer.future;
    yield results;
  }

  /// Reverse geocode coordinates to get address
  Future<SelectedLocation> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final queryParams = {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'format': 'json',
        'addressdetails': '1',
        'namedetails': '1',
        'zoom': '18',
      };

      final uri = Uri.parse('$_nominatimBaseUrl/reverse')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
          'Accept-Language': 'en',  // Force English language responses
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('Timeout', 408),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['error'] != null) {
          throw Exception(data['error'].toString());
        }

        return SelectedLocation.fromNominatim(data);
      } else if (response.statusCode == 404) {
        return SelectedLocation.fromCoordinates(
          locationName: 'Selected Location',
          fullAddress: 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}',
          latitude: latitude,
          longitude: longitude,
        );
      } else if (response.statusCode == 408) {
        throw Exception('Request timeout. Please try again.');
      } else {
        throw Exception('Failed to reverse geocode: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Reverse geocoding failed: $e');
    }
  }

  /// Get formatted address from coordinates (convenience method)
  Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final location = await reverseGeocode(
        latitude: latitude,
        longitude: longitude,
      );
      return location.fullAddress;
    } catch (e) {
      return 'Address not found';
    }
  }

  /// Get current location with full address using reverse geocoding
  Future<SelectedLocation> getCurrentLocationWithAddress() async {
    // Check location permission
    final permissionStatus = await Permission.location.request();

    if (permissionStatus.isDenied) {
      final status = await Permission.location.request();
      if (status.isDenied) {
        throw Exception('Location permission is required. Please enable it in settings.');
      }
    }

    if (permissionStatus.isPermanentlyDenied) {
      throw Exception('Location permission permanently denied. Please enable it in app settings.');
    }

    // Check if location service is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable them.');
    }

    LocationPermission locationPermission = await Geolocator.checkPermission();

    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
      if (locationPermission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (locationPermission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. Please enable it in settings.');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Reverse geocode to get address
      final location = await reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      return location;
    } catch (e) {
      throw Exception('Failed to get current location: $e');
    }
  }
}

/// Location settings for location accuracy and updates
class LocationSettingsHelper {
  static LocationSettings get accurateSettings => const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
    timeLimit: Duration(seconds: 30),
  );

  static LocationSettings get balancedSettings => const LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 50,
    timeLimit: Duration(seconds: 60),
  );

  static LocationSettings get lowPowerSettings => const LocationSettings(
    accuracy: LocationAccuracy.low,
    distanceFilter: 100,
    timeLimit: Duration(minutes: 5),
  );
}
