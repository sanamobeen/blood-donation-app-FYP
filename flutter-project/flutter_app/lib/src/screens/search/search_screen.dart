import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../donors/donor_profile_screen.dart';
import '../../app_routes.dart';

/// Enhanced Search Screen with API integration for donors and blood requests
/// Features: debouncing, recent searches, better UX, advanced filters
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  int _selectedTab = 0; // 0 = Donors, 1 = Requests

  bool _isSearching = false;
  bool _isLoading = false;
  bool _hasSearched = false;

  List<Map<String, dynamic>> _donors = [];
  List<Map<String, dynamic>> _requests = [];
  List<String> _recentSearches = [];

  String? _errorMessage;
  String _lastQuery = '';

  // Debounce timer
  Timer? _debounceTimer;

  // Filters
  String? _selectedBloodType;
  String? _selectedCity;
  String? _selectedUrgency;
  double? _userLat;
  double? _userLng;
  double _searchRadius = 50.0;

  // Pagination
  int _currentPage = 1;
  bool _hasMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchFocusNode.requestFocus();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoading && _hasMore && _lastQuery.isNotEmpty) {
        _loadMoreResults();
      }
    }
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    _recentSearches = prefs.getStringList('recent_searches') ?? [];

    // Remove if already exists
    _recentSearches.remove(query);

    // Add to beginning
    _recentSearches.insert(0, query);

    // Keep only last 10
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }

    await prefs.setStringList('recent_searches', _recentSearches);
    setState(() {});
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    setState(() {
      _recentSearches = [];
    });
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    if (query.trim().isEmpty) {
      setState(() {
        _donors = [];
        _requests = [];
        _hasSearched = false;
        _lastQuery = '';
        _currentPage = 1;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query, {bool isLoadMore = false}) async {
    if (query.trim().isEmpty) {
      setState(() {
        _donors = [];
        _requests = [];
        _hasSearched = false;
        _lastQuery = '';
      });
      return;
    }

    if (!isLoadMore) {
      setState(() {
        _isSearching = true;
        _isLoading = true;
        _hasSearched = true;
        _lastQuery = query;
        _errorMessage = null;
        _currentPage = 1;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      if (_selectedTab == 0) {
        // Search donors
        final result = await ApiService.searchDonors(
          query: query,
          bloodType: _selectedBloodType,
          city: _selectedCity,
          lat: _userLat,
          lng: _userLng,
          radius: _searchRadius,
        );

        if (result['success'] == true && result['data'] != null) {
          final data = result['data'] as Map<String, dynamic>;
          final donors = data['donors'] as List? ?? [];

          setState(() {
            if (isLoadMore) {
              _donors.addAll(donors.map((d) => d as Map<String, dynamic>).toList());
            } else {
              _donors = donors.map((d) => d as Map<String, dynamic>).toList();
            }
            _hasMore = donors.length == 20; // Assuming page size is 20
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = result['message'] as String? ?? 'No donors found';
            _isLoading = false;
          });
        }
      } else {
        // Search blood requests
        final result = await ApiService.searchBloodRequests(
          bloodType: _selectedBloodType,
          urgency: _selectedUrgency,
          city: _selectedCity,
          lat: _userLat,
          lng: _userLng,
          radius: _searchRadius,
        );

        if (result['success'] == true && result['data'] != null) {
          final data = result['data'] as Map<String, dynamic>;
          final requests = data['results'] as List? ?? [];

          setState(() {
            if (isLoadMore) {
              _requests.addAll(requests.map((r) => r as Map<String, dynamic>).toList());
            } else {
              _requests = requests.map((r) => r as Map<String, dynamic>).toList();
            }
            _hasMore = requests.length == 20;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = result['message'] as String? ?? 'No requests found';
            _isLoading = false;
          });
        }
      }

      // Save to recent searches only on initial search
      if (!isLoadMore) {
        await _saveRecentSearch(query);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    } finally {
      if (!isLoadMore) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoading || !_hasMore) return;

    _currentPage++;
    await _performSearch(_lastQuery, isLoadMore: true);
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Results'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Blood Type Filter
                  const Text(
                    'Blood Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip('All', null, setDialogState),
                      _buildFilterChip('A+', '1', setDialogState),
                      _buildFilterChip('A-', '2', setDialogState),
                      _buildFilterChip('B+', '3', setDialogState),
                      _buildFilterChip('B-', '4', setDialogState),
                      _buildFilterChip('O+', '5', setDialogState),
                      _buildFilterChip('O-', '6', setDialogState),
                      _buildFilterChip('AB+', '7', setDialogState),
                      _buildFilterChip('AB-', '8', setDialogState),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Urgency Filter (for requests)
                  if (_selectedTab == 1) ...[
                    const Text(
                      'Urgency',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChip('All', null, setDialogState, isUrgency: true),
                        _buildFilterChip('Critical', 'critical', setDialogState, isUrgency: true),
                        _buildFilterChip('High', 'high', setDialogState, isUrgency: true),
                        _buildFilterChip('Normal', 'normal', setDialogState, isUrgency: true),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Distance Filter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Search Radius',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_searchRadius.toInt()} km',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: const Color(0xFFE0E0E0),
                      thumbColor: AppColors.primary,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayColor: AppColors.primary.withOpacity(0.1),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _searchRadius,
                      min: 5,
                      max: 200,
                      divisions: 39,
                      onChanged: (value) {
                        setDialogState(() {
                          _searchRadius = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    _selectedBloodType = null;
                    _selectedCity = null;
                    _selectedUrgency = null;
                    _searchRadius = 50.0;
                  });
                },
                child: const Text('Reset'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (_lastQuery.isNotEmpty) {
                    _performSearch(_lastQuery);
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, StateSetter setState, {bool isUrgency = false}) {
    final isSelected = isUrgency
        ? _selectedUrgency == value
        : _selectedBloodType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (isUrgency) {
            _selectedUrgency = selected ? value : null;
          } else {
            _selectedBloodType = selected ? value : null;
          }
        });
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Search Bar
            _buildSearchBar(),

            // Tab Bar
            _buildTabBar(),

            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Colors.black,
              ),
            ),
          ),

          const Expanded(
            child: Text(
              'Search',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Filter Icon with indicator
          GestureDetector(
            onTap: _showFilterDialog,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.filter_list_rounded,
                    color: Colors.black,
                    size: 22,
                  ),
                  if (_selectedBloodType != null || _selectedUrgency != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search_rounded,
              color: _isSearching ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search donors or blood requests...',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _performSearch(value);
                  }
                },
                onChanged: _onSearchChanged,
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _searchFocusNode.requestFocus();
                  setState(() {
                    _donors = [];
                    _requests = [];
                    _hasSearched = false;
                    _lastQuery = '';
                  });
                },
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = 0;
                });
                if (_lastQuery.isNotEmpty) {
                  _performSearch(_lastQuery);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _selectedTab == 0 ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  'Donors',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.w500,
                    color: _selectedTab == 0 ? AppColors.primary : Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = 1;
                });
                if (_lastQuery.isNotEmpty) {
                  _performSearch(_lastQuery);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _selectedTab == 1 ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  'Blood Requests',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.w500,
                    color: _selectedTab == 1 ? AppColors.primary : Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
            ),
            SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      return _buildSuggestions();
    }

    if (_selectedTab == 0) {
      return _buildDonorsList();
    } else {
      return _buildRequestsList();
    }
  }

  Widget _buildSuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: _clearRecentSearches,
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((search) {
                return _buildSearchChip(search);
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Quick Search Suggestions
          const Text(
            'Popular Searches',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSearchChip('O+ donors'),
              _buildSearchChip('A+ donors'),
              _buildSearchChip('Critical requests'),
              _buildSearchChip('Nearby hospitals'),
            ],
          ),
          const SizedBox(height: 24),

          // Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softPink.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search Tips',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Search by donor name\n• Filter by blood type\n• Use location for nearby results',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchChip(String label) {
    return GestureDetector(
      onTap: () {
        _searchController.text = label;
        _performSearch(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonorsList() {
    if (_donors.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_search,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No donors found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _donors.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _donors.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          );
        }

        final donor = _donors[index];
        return _DonorCard(
          donor: donor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DonorProfileScreen(donor: donor),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsList() {
    if (_requests.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bloodtype,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No blood requests found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _requests.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _requests.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          );
        }

        final request = _requests[index];
        return _RequestCard(
          request: request,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/blood-request-detail/${request['id']}',
            );
          },
        );
      },
    );
  }
}

class _DonorCard extends StatelessWidget {
  final Map<String, dynamic> donor;
  final VoidCallback onTap;

  const _DonorCard({
    required this.donor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bloodType = donor['blood_type'] as String? ?? 'Unknown';
    final distance = donor['distance_km'] as double?;
    final fullName = donor['full_name'] as String? ?? 'Unknown';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.softPink,
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          bloodType,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (distance != null)
                        Text(
                          '${distance.toStringAsFixed(1)} km away',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  if (donor['is_available'] == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Available to donate',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onTap;

  const _RequestCard({
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bloodType = request['blood_type']?['code'] as String? ?? 'Unknown';
    final urgency = request['urgency'] as String? ?? 'normal';
    final hospitalName = request['hospital_name'] as String? ?? 'Unknown';
    final requiredDate = request['required_date'] as String?;

    Color urgencyColor;
    switch (urgency) {
      case 'critical':
        urgencyColor = const Color(0xFFD62828);
        break;
      case 'high':
        urgencyColor = const Color(0xFFE85D04);
        break;
      default:
        urgencyColor = const Color(0xFF2A9D8F);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: urgencyColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: urgencyColor.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Blood Type Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: urgencyColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bloodtype,
                color: urgencyColor,
              ),
            ),

            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        bloodType,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: urgencyColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: urgencyColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          urgency.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hospitalName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (requiredDate != null)
                    Text(
                      'Needed by: $requiredDate',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
