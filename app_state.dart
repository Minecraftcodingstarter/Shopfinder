import 'shop_model.dart';

enum SearchState { idle, searching, results, noResults, error }

class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  List<Shop> searchResults = [];
  List<Shop> filteredResults = [];
  String searchQuery = '';
  double searchRadius = 5000;
  double? currentLatitude;
  double? currentLongitude;
  SearchState searchState = SearchState.idle;
  String? errorMessage;
  bool locationPermissionDenied = false;
  String sortBy = 'quality';
  List<String> searchHistory = [];

  void setSearchResults(List<Shop> results) {
    searchResults = results;
    _applySort();
    searchState = searchResults.isEmpty ? SearchState.noResults : SearchState.results;
  }

  void _applySort() {
    filteredResults = List.from(searchResults)..sort((a, b) {
      return b.getScore(sortBy: sortBy).compareTo(a.getScore(sortBy: sortBy));
    });
  }

  void setSortBy(String newSort) {
    sortBy = newSort;
    _applySort();
  }

  void updateSearchRadius(double radius) {
    searchRadius = radius;
  }

  void addToHistory(String query) {
    if (query.trim().isNotEmpty && !searchHistory.contains(query.trim())) {
      searchHistory.insert(0, query.trim());
      if (searchHistory.length > 20) {
        searchHistory.removeLast();
      }
    }
  }
}
