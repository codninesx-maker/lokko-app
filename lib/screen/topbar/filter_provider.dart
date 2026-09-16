import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lokko_market/model/ad_model.dart';

// 1. FILTER STATE: Holds the current selection criteria
class FilterState {
  final String? category;
  final String? subCategory;
  final String? location;

  FilterState({this.category, this.subCategory, this.location});

  FilterState copyWith({String? category, String? subCategory, String? location}) {
    return FilterState(
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      location: location ?? this.location,
    );
  }
}

// 2. FILTER NOTIFIER: Manages the changes to the filter state
class FilterNotifier extends StateNotifier<FilterState> {
  FilterNotifier() : super(FilterState());

  void setCategory(String main, String sub) {
    state = state.copyWith(category: main, subCategory: sub);
  }

  void setLocation(String loc) {
    state = state.copyWith(location: loc);
  }

  void resetFilters() {
    state = FilterState();
  }
}

// 3. FILTER PROVIDER: The entry point for UI to change filters
final filterProvider = StateNotifierProvider<FilterNotifier, FilterState>((ref) {
  return FilterNotifier();
});
