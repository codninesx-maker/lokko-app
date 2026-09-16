import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/ad_model.dart';

final supabase = Supabase.instance.client;

class AdminReviewProvider extends AsyncNotifier<List<AdModel>> {

  @override
  FutureOr<List<AdModel>> build() async {
    try {
      final response = await supabase
          .from('ads')
          .select('''
            *, 
            categories:category_id(name), 
            districts:district_id(name), 
            profiles:user_id(full_name, phone, is_verified)
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      final List<dynamic> data = response;

      return data.map((adData) {
        final Map<String, dynamic> ad = Map<String, dynamic>.from(adData);

        // Robust Normalization: Handles the case where Supabase returns
        // objects directly or inside lists
        _normalize(ad, 'profiles');
        _normalize(ad, 'districts');
        _normalize(ad, 'categories');

        return AdModel.fromMap(ad);
      }).toList();
    } catch (e) {
      debugPrint("LOKKO_ADMIN_FETCH_ERROR: $e");
      return [];
    }
  }

  void _normalize(Map<String, dynamic> ad, String key) {
    if (ad[key] is List && (ad[key] as List).isNotEmpty) {
      ad[key] = ad[key][0];
    }
  }

  /// Updates the ad status and removes it from the current list (Optimistic UI)
  Future<bool> updateAdStatus(String adId, String newStatus) async {
    try {
      // Ensure these strings match your DB ARRAY exactly:
      // ['pending', 'active', 'reviewed', 'rejected', 'expired']
      String dbStatus;
      bool isApproved;

      if (newStatus == 'approved' || newStatus == 'active') {
        dbStatus = 'active'; // Ad goes live
        isApproved = true;
      } else {
        dbStatus = 'rejected'; // Ad is hidden
        isApproved = false;
      }
      debugPrint("LOKKO_DEBUG_PAYLOAD: status is '$dbStatus'");

      await supabase.from('ads').update({
        'status': dbStatus,
        'is_reviewed': true,
        // REMOVE 'is_approved' if the column doesn't exist in Supabase
        'is_approved': isApproved,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', adId);

      // Optimistic UI Update
      state = AsyncValue.data(
        (state.value ?? []).where((ad) => ad.id != adId).toList(),
      );
      ref.invalidateSelf();

      return true;
    } catch (e) {
      debugPrint("LOKKO_ADMIN_ACTION_ERROR: $e");
      ref.invalidateSelf();
      return false;
    }
  }
}

final adminReviewProvider = AsyncNotifierProvider<AdminReviewProvider, List<AdModel>>(
      () => AdminReviewProvider(),
);