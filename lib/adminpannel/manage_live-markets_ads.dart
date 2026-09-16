import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lokko_market/model/ad_model.dart';

final managelivemarketsads = StateNotifierProvider<AdminManageNotifier, AsyncValue<List<AdModel>>>((ref) {
  return AdminManageNotifier();
});

class AdminManageNotifier extends StateNotifier<AsyncValue<List<AdModel>>> {
  AdminManageNotifier() : super(const AsyncValue.loading()) {
    fetchAllActiveAds();
  }

  final _supabase = Supabase.instance.client;

  /// Fetch all active ads across the whole market
  Future<void> fetchAllActiveAds() async {
    try {
      state = const AsyncValue.loading();

      // FIXED: Added missing relational tables so AdModel can parse cleanly
      final response = await _supabase
          .from('ads')
          .select('''
          *, 
          categories:category_id(name), 
          districts:district_id(name), 
          profiles:user_id(full_name, phone, is_verified)
        ''')
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final List<dynamic> data = response;

      final List<AdModel> ads = data.map((adData) {
        final Map<String, dynamic> ad = Map<String, dynamic>.from(adData);

        // Apply your robust normalization helpers here if needed:
        if (ad['profiles'] is List && (ad['profiles'] as List).isNotEmpty) ad['profiles'] = ad['profiles'][0];
        if (ad['districts'] is List && (ad['districts'] as List).isNotEmpty) ad['districts'] = ad['districts'][0];
        if (ad['categories'] is List && (ad['categories'] as List).isNotEmpty) ad['categories'] = ad['categories'][0];

        return AdModel.fromMap(ad);
      }).toList();

      state = AsyncValue.data(ads);
    } catch (e, stack) {
      debugPrint("LOKKO_ADMIN_MANAGE_FETCH_ERROR: $e");
      state = AsyncValue.error(e, stack);
    }
  }

  /// Admin override force delete sequence
  Future<bool> adminForceDeleteAd(String adId) async {
    try {
      // 1. Fetch the ad first to get the Cloudinary image references
      final response = await _supabase
          .from('ads')
          .select('images')
          .eq('id', adId)
          .maybeSingle();

      List<String> imagesToDelete = [];
      if (response != null && response['images'] != null) {
        imagesToDelete = (response['images'] as List).map((img) {
          String imageStr = img.toString();

          // If it's a full URL, parse out only the public_id parts
          if (imageStr.contains('image/upload/')) {
            imageStr = imageStr.split('image/upload/').last;
            // Strip out version tags like v12345678/ if they exist
            imageStr = imageStr.replaceAll(RegExp(r'v\d+/'), '');
            // Strip out file extensions like .jpg or .png
            if (imageStr.contains('.')) {
              imageStr = imageStr.split('.').first;
            }
          }

          return imageStr;
        }).where((id) => id.isNotEmpty).toList();
      }

      // 2. Delete the row from the Supabase Database
      await _supabase.from('ads').delete().eq('id', adId);

      // 3. Trigger background cleanup for Cloudinary using your existing helper
      if (imagesToDelete.isNotEmpty) {
        _cleanupCloudinaryParallel(imagesToDelete);
      }

      // 4. Local state reconciliation: remove item from UI immediately
      state.whenData((currentAds) {
        final updatedList = currentAds.where((ad) => ad.id != adId).toList();
        state = AsyncValue.data(updatedList);
      });

      return true;
    } catch (e) {
      debugPrint("LOKKO_FORCE_DELETE_ERROR: $e");
      return false;
    }
  }

  void _cleanupCloudinaryParallel(List<String> ids) {
    for (var id in ids) {
      CloudinaryHelper.deleteOldImage(id).then((_) {
        debugPrint("LOKKO_FORCE_DELETE: Deleted asset $id from Cloudinary");
      }).catchError((e) {
        debugPrint("LOKKO_FORCE_DELETE_FAIL: $id -> $e");
      });
    }
  }
}