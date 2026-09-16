import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lokko_market/screen/bottombar/create_post_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lokko_market/model/ad_model.dart';

/// 1. STATE MODEL: Holds all UI data and filter criteria
class DashboardState {
  final AsyncValue<List<AdModel>> ads;
  final String searchQuery;

  // IDs for Database filtering
  final String? selectedCategoryId;
  final String? selectedDistrictId;

  // Names for UI Display
  final String? selectedCategoryName;
  final String? selectedLocationName;
  final String? selectedLocationId;

  // Filtering & Sorting
  final double minPrice;
  final double maxPrice;
  final String sortOrder;

  DashboardState({
    required this.ads,
    this.searchQuery = '',
    this.selectedCategoryId,
    this.selectedDistrictId,
    this.selectedCategoryName,
    this.selectedLocationName,
    this.minPrice = 0,
    this.maxPrice = 1000000,
    this.sortOrder = "Newest on top",
    this.selectedLocationId,
  });

  DashboardState copyWith({
    AsyncValue<List<AdModel>>? ads,
    String? searchQuery,
    String? selectedCategoryId,
    String? selectedCategoryName,
    String? selectedDistrictId,
    String? selectedLocationName,
    double? minPrice,
    double? maxPrice,
    String? sortOrder,
    String? selectedLocationId,
    bool clearCategory = false,
  }) {
    return DashboardState(
      ads: ads ?? this.ads,
      searchQuery: searchQuery ?? this.searchQuery,
      // ADD '?? this.variable' to ALL of these:
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      selectedCategoryName: selectedCategoryName ?? this.selectedCategoryName,
      selectedDistrictId: selectedDistrictId ?? this.selectedDistrictId,
      selectedLocationName: selectedLocationName ?? this.selectedLocationName,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      sortOrder: sortOrder ?? this.sortOrder,
      selectedLocationId: selectedLocationId ?? this.selectedLocationId,
    );
  }
}


/// 2. NOTIFIER: Handles the logic and Supabase communication
class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(DashboardState(ads: const AsyncValue.loading())) {
    fetchAds();
  }

  final _supabase = Supabase.instance.client;

  /// The Core Query Engine
  // Add this variable at the top of your Notifier class
  int _requestCount = 0;

  // Inside DashboardNotifier
  Future<void> fetchInitialLocation() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('profiles')
        .select('location_name, location_id')
        .eq('id', user.id)
        .maybeSingle(); // Use maybeSingle to prevent crashes if profile is missing

    if (data != null) {
      state = state.copyWith(
        selectedLocationName: data['location_name'],
        selectedDistrictId: data['location_id']?.toString(), // Use DistrictId consistently
      );
    }
  }

  Future<void> _initDashboard() async {
    await syncProfileLocation(); // Step 1: Updates state parameters cleanly
    await fetchAds();            // Step 2: Executes the query once with the updated state
  }

  Future<void> fetchAds() async {
    final currentRequest = ++_requestCount;
    state = state.copyWith(ads: const AsyncValue.loading());

    int retryCount = 0;
    const int maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        // 1. CLEAN SELECT: Don't put .in_ inside the select string
        var query = _supabase.from('ads').select('''
          *, 
          categories:category_id(name), 
          districts:district_id(name, parent:parent_id(name)), 
          profiles:user_id(
            full_name, 
            phone, 
            is_number,
            is_verified
          )
        ''');

        // 2. CORRECT STATUS FILTER:
        query = query.inFilter('status', ['active', 'sold']);

        // 3. ADVANCED 3-LEVEL LOCATION HIERARCHY FILTER
        if (state.selectedDistrictId != null &&
            state.selectedDistrictId != 'null' &&
            state.selectedDistrictId != '0' &&
            state.selectedDistrictId!.isNotEmpty) {

          final locId = int.tryParse(state.selectedDistrictId!);
          if (locId != null && locId != 0) {
            debugPrint("LOKKO_FILTER: Selected Location Node ID: $locId");

            // Step A: Check if this location has children (Level 0/1 Division or Level 2 District parent)
            final childLocationsResponse = await _supabase
                .from('districts')
                .select('id, parent_id')
                .eq('parent_id', locId);

            final List<int> locationIdsToFilter = [locId];

            if (childLocationsResponse.isNotEmpty) {
              // It's a Division or a District with sub-areas
              final List<int> level2Ids = (childLocationsResponse as List)
                  .map((c) => c['id'] as int)
                  .toList();

              locationIdsToFilter.addAll(level2Ids);

              // Step B: Check for deep Level 3 grandchildren (e.g., Thanas under a District)
              final grandchildLocationsResponse = await _supabase
                  .from('districts')
                  .select('id')
                  .inFilter('parent_id', level2Ids);

              if (grandchildLocationsResponse.isNotEmpty) {
                final List<int> level3Ids = (grandchildLocationsResponse as List)
                    .map((c) => c['id'] as int)
                    .toList();
                locationIdsToFilter.addAll(level3Ids);
              }
            }

            // Step C: Filter ads that match either the selected node or any of its sub-branches
            query = query.inFilter('district_id', locationIdsToFilter);
            debugPrint("LOKKO_FILTER: Broadening location search across IDs: $locationIdsToFilter");
          }
        }

        // 4. ADVANCED 3-LEVEL CATEGORY HIERARCHY FILTER
        if (state.selectedCategoryId != null &&
            state.selectedCategoryId != 'null' &&
            state.selectedCategoryId != '0' &&
            state.selectedCategoryId!.isNotEmpty) {

          final catId = int.tryParse(state.selectedCategoryId!);
          if (catId != null) {
            debugPrint("LOKKO_FILTER: Selected Category Node ID: $catId");

            // Step A: Check if this category has children (Level 1 or Level 2 parent)
            final childCategoriesResponse = await _supabase
                .from('categories')
                .select('id, parent_id')
                .eq('parent_id', catId);

            final List<int> categoryIdsToFilter = [catId];

            if (childCategoriesResponse.isNotEmpty) {
              // It's a Level 1 parent (e.g., Mobiles) or Level 2 parent (e.g., Mobile Phones)
              final List<int> level2Ids = (childCategoriesResponse as List)
                  .map((c) => c['id'] as int)
                  .toList();

              categoryIdsToFilter.addAll(level2Ids);

              // Step B: Check for deep Level 3 grandchildren (e.g., Apple iPhones)
              final grandchildCategoriesResponse = await _supabase
                  .from('categories')
                  .select('id')
                  .inFilter('parent_id', level2Ids);

              if (grandchildCategoriesResponse.isNotEmpty) {
                final List<int> level3Ids = (grandchildCategoriesResponse as List)
                    .map((c) => c['id'] as int)
                    .toList();
                categoryIdsToFilter.addAll(level3Ids);
              }
            }

            // Step C: Filter ads that match either the selected item or any of its children branches
            query = query.inFilter('category_id', categoryIdsToFilter);
            debugPrint("LOKKO_FILTER: Broadening category search across IDs: $categoryIdsToFilter");
          }
        }

        // 5. PRICE & SEARCH
        query = query.gte('price', state.minPrice).lte('price', state.maxPrice);

        if (state.searchQuery.isNotEmpty) {
          query = query.ilike('title', '%${state.searchQuery}%');
        }

        // 6. SORTING
        final dynamic data;
        if (state.sortOrder == "Price: Low to High") {
          data = await query.order('price', ascending: true);
        } else if (state.sortOrder == "Price: High to Low") {
          data = await query.order('price', ascending: false);
        } else {
          data = await query.order('created_at', ascending: false);
        }

        if (currentRequest != _requestCount || !mounted) return;

        final adList = (data as List).map((ad) => AdModel.fromMap(ad)).toList();
        state = state.copyWith(ads: AsyncValue.data(adList));
        break;

      } catch (e, st) {
        debugPrint("LOKKO_RETRY_$retryCount: $e");
        if (e.toString().contains("abort") && retryCount < maxRetries) {
          retryCount++;
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
          continue;
        }

        if (currentRequest != _requestCount || !mounted) return;
        state = state.copyWith(ads: AsyncValue.error(e, st));
        break;
      }
    }
  }

  // Inside DashboardNotifier
  void updateLocation({required String locationId, required String locationName}) {
    state = state.copyWith(
      selectedDistrictId: locationId,   // This is what Supabase uses to filter
      selectedLocationName: locationName, // This is what the Top Bar shows
    );

    // This call is mandatory to fetch the new list from Supabase!
    fetchAds();
  }

  void updateFilters({
    String? categoryId,
    String? categoryName,
    String? districtId,
    String? locationName,
    RangeValues? price,
    String? sort,
  }) {
    // Use the existing state if the new value is null
    state = state.copyWith(
      selectedCategoryId: categoryId ?? state.selectedCategoryId,
      selectedCategoryName: categoryName ?? state.selectedCategoryName,
      selectedDistrictId: districtId ?? state.selectedDistrictId,
      selectedLocationName: locationName ?? state.selectedLocationName,
      minPrice: price?.start ?? state.minPrice,
      maxPrice: price?.end ?? state.maxPrice,
      sortOrder: sort ?? state.sortOrder,
      ads: const AsyncValue.loading(), // Trigger the spinner immediately
    );

    fetchAds();
  }

  Future<void> syncProfileLocation() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch only the user's saved profile data cleanly
      final data = await _supabase
          .from('profiles')
          .select('location_name, location_id')
          .eq('id', user.id)
          .single();

      if (data['location_name'] != null && data['location_id'] != null) {
        // 2. Update Riverpod state to trigger UI rebuild
        state = state.copyWith(
          selectedLocationName: data['location_name'].toString(),
          selectedDistrictId: data['location_id'].toString(),
        );

        debugPrint("LOKKO_SYNC: Successfully synced profile location to: ${data['location_name']}");
      }
    } catch (e) {
      debugPrint("LOKKO_SYNC_ERROR: Failed to sync profile location: $e");
    }
  }

  /// Dedicated Search Update
  void updateSearch(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    fetchAds();
  }


  void resetFilters() {
    state = DashboardState(
      ads: const AsyncValue.loading(),
      sortOrder: "Newest on top",
      minPrice: 0,
      maxPrice: 1000000,
      // Keep location selection intact, but wipe category nodes cleanly
      selectedDistrictId: state.selectedDistrictId,
      selectedLocationName: state.selectedLocationName,
    );
    fetchAds();
  }

  void clearCategoryFilter() {
    state = state.copyWith(clearCategory: true);
    fetchAds();
  }
}

/// 3. PROVIDER: The entry point for the UI
final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});