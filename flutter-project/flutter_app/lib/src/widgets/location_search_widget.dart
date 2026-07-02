import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

/// Location search widget with autocomplete functionality
/// Allows users to search for locations and get coordinates
class LocationSearchWidget extends StatefulWidget {
  final String? initialAddress;
  final Function(String address, double lat, double lng) onLocationSelected;
  final String? hintText;
  final bool autoFocus;

  const LocationSearchWidget({
    super.key,
    this.initialAddress,
    required this.onLocationSelected,
    this.hintText,
    this.autoFocus = false,
  });

  @override
  State<LocationSearchWidget> createState() => _LocationSearchWidgetState();
}

class _LocationSearchWidgetState extends State<LocationSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoading = false;
  List<LocationSuggestion> _suggestions = [];
  String _selectedAddress = '';
  double? _selectedLat;
  double? _selectedLng;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialAddress ?? '';
    _selectedAddress = widget.initialAddress ?? '';
    if (widget.autoFocus) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchLocations(String query) async {
    if (query.trim().isEmpty || query.length < 3) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use geocoding to search for locations
      // locationFromAddress returns coordinates
      final locations = await locationFromAddress(query);

      // Now reverse geocode each location to get readable addresses
      final suggestions = <LocationSuggestion>[];

      for (final location in locations) {
        try {
          // Get placemarks for each location to format the address
          final placemarks = await placemarkFromCoordinates(
            location.latitude,
            location.longitude,
          );

          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            final address = _formatPlacemarkAddress(placemark, location);

            suggestions.add(LocationSuggestion(
              address: address,
              lat: location.latitude,
              lng: location.longitude,
            ));
          }
        } catch (e) {
          // If reverse geocoding fails for this location, use coordinates as fallback
          suggestions.add(LocationSuggestion(
            address: '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
            lat: location.latitude,
            lng: location.longitude,
          ));
        }

        // Limit suggestions to avoid overwhelming results
        if (suggestions.length >= 5) break;
      }

      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      // If search fails, try searching with common hospital names
      try {
        // Add common hospital names to the query
        final searchQuery = query.contains('hospital') ? query : '$query hospital';
        final locations = await locationFromAddress(searchQuery);

        final suggestions = <LocationSuggestion>[];
        for (final location in locations) {
          suggestions.add(LocationSuggestion(
            address: searchQuery,
            lat: location.latitude,
            lng: location.longitude,
          ));

          if (suggestions.length >= 5) break;
        }

        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
      } catch (e2) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
    }
  }

  String _formatPlacemarkAddress(Placemark placemark, Location? location) {
    final parts = <String>[];

    // Add name if available (this could be hospital/venue name)
    if (placemark.name != null && placemark.name!.isNotEmpty) {
      parts.add(placemark.name!);
    }

    // Add street if available
    if (placemark.street != null && placemark.street!.isNotEmpty) {
      parts.add(placemark.street!);
    }

    // Add sub-locality if available
    if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      parts.add(placemark.subLocality!);
    }

    // Add locality (city) if available
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      parts.add(placemark.locality!);
    }

    // Add administrative area (state/province) if available
    if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
      parts.add(placemark.administrativeArea!);
    }

    // Add country if available
    if (placemark.country != null && placemark.country!.isNotEmpty) {
      parts.add(placemark.country!);
    }

    return parts.isNotEmpty ? parts.join(', ') : 'Unknown Location';
  }

  void _selectSuggestion(LocationSuggestion suggestion) {
    setState(() {
      _selectedAddress = suggestion.address;
      _selectedLat = suggestion.lat;
      _selectedLng = suggestion.lng;
      _searchController.text = suggestion.address;
      _suggestions = [];
    });

    widget.onLocationSelected(
      suggestion.address,
      suggestion.lat,
      suggestion.lng,
    );

    _searchFocusNode.unfocus();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = _formatPlacemarkAddress(placemark, null);

        setState(() {
          _selectedAddress = address;
          _selectedLat = position.latitude;
          _selectedLng = position.longitude;
          _searchController.text = address;
        });

        widget.onLocationSelected(
          address,
          position.latitude,
          position.longitude,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search Input Field
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFD62828).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 16, right: 12),
                child: Icon(
                  Icons.location_on,
                  color: Color(0xFFD62828),
                  size: 20,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: widget.hintText ?? 'Search hospital location...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    // Debounce search - only search after 3 characters
                    if (value.length >= 3) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (_searchController.text == value) {
                          _searchLocations(value);
                        }
                      });
                    } else {
                      // Clear suggestions if less than 3 characters
                      setState(() {
                        _suggestions = [];
                      });
                    }
                  },
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFD62828),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: _getCurrentLocation,
                  child: const Icon(
                    Icons.my_location,
                    color: Color(0xFFD62828),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Suggestions List
        if (_suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    suggestion.address,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}

class LocationSuggestion {
  final String address;
  final double lat;
  final double lng;

  LocationSuggestion({
    required this.address,
    required this.lat,
    required this.lng,
  });
}
