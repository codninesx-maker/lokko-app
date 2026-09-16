import 'package:flutter/foundation.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:lokko_market/screen/bottombar/create_post_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// This provider allows your UI to access the repository
final adRepositoryProvider = Provider((ref) => AdRepository());

class AdRepository {
  final _supabase = Supabase.instance.client;

  Future<List<AdModel>> fetchAds() async {
    List<dynamic> response = [];

    try {
      response = await _supabase
          .from('ads')
          .select('''
  *,
  categories:category_id(name),
  districts:district_id!ads_district_id_fkey(
    name, 
    parent:parent_id(name)
  ),
  profiles:user_id(full_name, phone, is_verified)
''')
          .eq('is_reviewed', true)
          .order('created_at', ascending: false);


      // ... debug logs
      if (response.isNotEmpty) {
        final districtData = response.first['districts'];
        debugPrint("📍 LOCATION DEEP CHECK: $districtData");
        // Should now show: {name: Boalia, parent: {name: Rajshahi}}
      }

      return response.map((adMap) => AdModel.fromMap(adMap)).toList();

    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('timeout')) {
        debugPrint("LOKKO_OFFLINE: Please check your data connection.");
      }
      debugPrint("LOKKO_FETCH_CRITICAL: $e");

      // 2. Return an empty list safely if the fetch fails
      return [];
    }
  }

  // Inside your AdRepository class
  Future<List<AdModel>> fetchAdsByUserId(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('ads')
          .select('''
          *,
          location:districts!ads_location_id_fkey (
            name,
            district:parent_id (name)
          ),
          profiles:user_id (full_name, is_verified),
          categories:category_id (name)
        ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((ad) => AdModel.fromMap(ad)).toList();
    } catch (e) {
      debugPrint("LOKKO_SELLER_ADS_ERROR: $e");
      return [];
    }
  }
}