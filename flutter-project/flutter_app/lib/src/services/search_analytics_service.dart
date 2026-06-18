import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Search Analytics Service - Track and analyze search usage patterns
/// Provides insights into user search behavior for improving the app
class SearchAnalyticsService {
  static const String _searchHistoryKey = 'search_analytics_history';
  static const String _searchStatsKey = 'search_analytics_stats';
  static const int _maxHistorySize = 100;

  // Singleton pattern
  SearchAnalyticsService._();
  static final SearchAnalyticsService _instance = SearchAnalyticsService._();
  factory SearchAnalyticsService() => _instance;

  /// Track a search event
  Future<void> trackSearch(SearchEvent event) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing history
      final historyJson = prefs.getStringList(_searchHistoryKey) ?? [];
      final history = historyJson
          .map((e) => SearchEvent.fromJson(jsonDecode(e)))
          .toList();

      // Add new event
      history.add(event);

      // Keep only recent events
      if (history.length > _maxHistorySize) {
        history.removeRange(0, history.length - _maxHistorySize);
      }

      // Save back
      await prefs.setStringList(
        _searchHistoryKey,
        history.map((e) => jsonEncode(e.toJson())).toList(),
      );

      // Update stats
      await _updateStats(event);
    } catch (e) {
    }
  }

  /// Get search history
  Future<List<SearchEvent>> getSearchHistory({int limit = 20}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_searchHistoryKey) ?? [];

      final events = historyJson
          .map((e) => SearchEvent.fromJson(jsonDecode(e)))
          .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return events.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get search statistics
  Future<SearchStats> getSearchStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString(_searchStatsKey);

      if (statsJson != null) {
        return SearchStats.fromJson(jsonDecode(statsJson));
      }

      return SearchStats();
    } catch (e) {
      return SearchStats();
    }
  }

  /// Get popular search terms
  Future<List<String>> getPopularSearchTerms({int limit = 10}) async {
    try {
      final stats = await getSearchStats();
      final entries = stats.searchTermCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return entries
          .take(limit)
          .map((e) => e.key)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get most used blood type filters
  Future<List<String>> getMostUsedBloodTypes() async {
    try {
      final stats = await getSearchStats();
      final entries = stats.bloodTypeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return entries.map((e) => '${e.key} (${e.value})').toList();
    } catch (e) {
      return [];
    }
  }

  /// Get average search radius
  Future<double> getAverageSearchRadius() async {
    try {
      final stats = await getSearchStats();
      if (stats.totalRadiusSearches == 0) return 50.0; // Default

      return stats.totalRadius / stats.totalRadiusSearches;
    } catch (e) {
      return 50.0;
    }
  }

  /// Clear all search analytics
  Future<void> clearAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
      await prefs.remove(_searchStatsKey);
    } catch (e) {
    }
  }

  /// Update search statistics
  Future<void> _updateStats(SearchEvent event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString(_searchStatsKey);
      SearchStats stats;

      if (statsJson != null) {
        stats = SearchStats.fromJson(jsonDecode(statsJson));
      } else {
        stats = SearchStats();
      }

      // Update stats
      stats.totalSearches++;

      // Update search type counts
      stats.searchTypeCounts.update(
        event.searchType,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      // Update search term counts
      if (event.query != null && event.query!.isNotEmpty) {
        stats.searchTermCounts.update(
          event.query!.toLowerCase(),
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      // Update blood type counts
      if (event.filters['blood_type'] != null) {
        stats.bloodTypeCounts.update(
          event.filters['blood_type'] as String,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      // Update radius stats
      if (event.filters['radius'] != null) {
        stats.totalRadius += event.filters['radius'] as double;
        stats.totalRadiusSearches++;
      }

      // Update result count stats
      if (event.resultCount != null) {
        if (event.resultCount! > 0) {
          stats.successfulSearches++;
        } else {
          stats.unsuccessfulSearches++;
        }

        stats.totalResultCount += event.resultCount!;
      }

      // Save stats
      await prefs.setString(_searchStatsKey, jsonEncode(stats.toJson()));
    } catch (e) {
    }
  }

  /// Get search suggestions based on history
  Future<List<String>> getSearchSuggestions(String prefix) async {
    if (prefix.isEmpty) return [];

    try {
      final stats = await getSearchStats();
      final lowerPrefix = prefix.toLowerCase();

      return stats.searchTermCounts.keys
          .where((term) => term.startsWith(lowerPrefix))
          .toList()
        ..sort((a, b) => stats.searchTermCounts[b]!
            .compareTo(stats.searchTermCounts[a]!));
    } catch (e) {
      return [];
    }
  }
}

/// Search Event Model
class SearchEvent {
  final String id;
  final String searchType; // 'donors' or 'requests'
  final String? query;
  final Map<String, dynamic> filters;
  final int? resultCount;
  final DateTime timestamp;
  final double? durationMs;
  final bool isEmpty;

  SearchEvent({
    required this.id,
    required this.searchType,
    this.query,
    this.filters = const {},
    this.resultCount,
    required this.timestamp,
    this.durationMs,
    this.isEmpty = false,
  });

  factory SearchEvent.fromJson(Map<String, dynamic> json) {
    return SearchEvent(
      id: json['id'] as String,
      searchType: json['search_type'] as String,
      query: json['query'] as String?,
      filters: (json['filters'] as Map<String, dynamic>?) ?? {},
      resultCount: json['result_count'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      durationMs: json['duration_ms'] as double?,
      isEmpty: json['is_empty'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'search_type': searchType,
      'query': query,
      'filters': filters,
      'result_count': resultCount,
      'timestamp': timestamp.toIso8601String(),
      'duration_ms': durationMs,
      'is_empty': isEmpty,
    };
  }

  /// Create a new search event
  factory SearchEvent.create({
    required String searchType,
    String? query,
    Map<String, dynamic> filters = const {},
    int? resultCount,
    double? durationMs,
    bool isEmpty = false,
  }) {
    return SearchEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      searchType: searchType,
      query: query,
      filters: filters,
      resultCount: resultCount,
      timestamp: DateTime.now(),
      durationMs: durationMs,
      isEmpty: isEmpty,
    );
  }
}

/// Search Statistics Model
class SearchStats {
  int totalSearches;
  int successfulSearches;
  int unsuccessfulSearches;
  int totalResultCount;
  Map<String, int> searchTypeCounts;
  Map<String, int> searchTermCounts;
  Map<String, int> bloodTypeCounts;
  double totalRadius;
  int totalRadiusSearches;

  SearchStats({
    this.totalSearches = 0,
    this.successfulSearches = 0,
    this.unsuccessfulSearches = 0,
    this.totalResultCount = 0,
    Map<String, int>? searchTypeCounts,
    Map<String, int>? searchTermCounts,
    Map<String, int>? bloodTypeCounts,
    this.totalRadius = 0,
    this.totalRadiusSearches = 0,
  })  : searchTypeCounts = searchTypeCounts ?? {},
        searchTermCounts = searchTermCounts ?? {},
        bloodTypeCounts = bloodTypeCounts ?? {};

  factory SearchStats.fromJson(Map<String, dynamic> json) {
    return SearchStats(
      totalSearches: json['total_searches'] as int? ?? 0,
      successfulSearches: json['successful_searches'] as int? ?? 0,
      unsuccessfulSearches: json['unsuccessful_searches'] as int? ?? 0,
      totalResultCount: json['total_result_count'] as int? ?? 0,
      searchTypeCounts: Map<String, int>.from(
        json['search_type_counts'] as Map? ?? {},
      ),
      searchTermCounts: Map<String, int>.from(
        json['search_term_counts'] as Map? ?? {},
      ),
      bloodTypeCounts: Map<String, int>.from(
        json['blood_type_counts'] as Map? ?? {},
      ),
      totalRadius: json['total_radius'] as double? ?? 0,
      totalRadiusSearches: json['total_radius_searches'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_searches': totalSearches,
      'successful_searches': successfulSearches,
      'unsuccessful_searches': unsuccessfulSearches,
      'total_result_count': totalResultCount,
      'search_type_counts': searchTypeCounts,
      'search_term_counts': searchTermCounts,
      'blood_type_counts': bloodTypeCounts,
      'total_radius': totalRadius,
      'total_radius_searches': totalRadiusSearches,
    };
  }

  /// Get success rate as percentage
  double get successRate {
    if (totalSearches == 0) return 0;
    return (successfulSearches / totalSearches) * 100;
  }

  /// Get average results per search
  double get averageResults {
    if (totalSearches == 0) return 0;
    return totalResultCount / totalSearches;
  }

  /// Get most popular search type
  String? get mostPopularSearchType {
    if (searchTypeCounts.isEmpty) return null;
    return searchTypeCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}
