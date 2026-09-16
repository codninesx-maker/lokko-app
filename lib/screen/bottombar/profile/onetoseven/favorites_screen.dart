import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


final favoritesProvider = FutureProvider<List<AdModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return [];

  try {
    final response = await supabase
        .from('favorites')
        .select('''
          ads:ad_id (
            *,
            categories:category_id (name),
            districts!ads_district_id_fkey (name),
            profiles:user_id (
              full_name, 
              avatar_url, 
              is_verified
            )
          )
        ''')
        .eq('user_id', user.id)
        .timeout(const Duration(seconds: 10));

    final List data = response as List;
    return data
        .where((fav) => fav['ads'] != null) // Safety check for deleted ads
        .map((fav) => AdModel.fromMap(fav['ads'] as Map<String, dynamic>))
        .toList();
  } catch (e) {
    debugPrint("LOKKO_FAV_ERROR: $e");
    return Future.error(e);
  }
});

// 2. Change to ConsumerWidget to use 'ref'
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  static const Color lokkoGreen = Color(0xFF1aa332);

  // Ad state fields inside mutable state container
  BannerAd? _bottomLargeBannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBottomLargeBannerAd();
  }

  @override
  void dispose() {
    // CRUCIAL: Always dispose of your ads to prevent system memory leaks!
    _bottomLargeBannerAd?.dispose();
    super.dispose();
  }

  void _loadBottomLargeBannerAd() {
    _bottomLargeBannerAd = BannerAd(
      // Test Banner Unit ID
      adUnitId: 'ca-app-pub-7494179033430216/3379106871',
      size: AdSize.largeBanner, // 320x100 Large Banner layout
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Favorites Bottom Large Banner Ad lifecycle failure: $error');
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    // With ConsumerState, 'ref' is directly available as a property of the state class
    final favoritesAsync = ref.watch(favoritesProvider);
    final supabase = Supabase.instance.client;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
            "My Favorites",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            )
        ),
        centerTitle: true,
        backgroundColor: lokkoGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: favoritesAsync.when(
        skipLoadingOnRefresh: true,
        data: (favoriteAds) {
          if (favoriteAds.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: favoriteAds.length,
            itemBuilder: (context, index) {
              final ad = favoriteAds[index];

              return Stack(
                children: [
                  AdItemTile(ad: ad), // Assuming this component remains defined globally
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () async {
                        try {
                          await supabase
                              .from('favorites')
                              .delete()
                              .eq('ad_id', ad.id)
                              .eq('user_id', supabase.auth.currentUser!.id);

                          ref.invalidate(favoritesProvider);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Removed from favorites")),
                            );
                          }
                        } catch (e) {
                          debugPrint("LOKKO_DELETE_ERROR: $e");
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: lokkoGreen)),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
      // 🔽 ADDED: Integrated bottom banner slot 🔽
      bottomNavigationBar: SafeArea(
        child: Container(
          width: double.infinity,
          height: _isBannerAdLoaded ? 100 : 0, // Collapses cleanly if the ad fails to load
          alignment: Alignment.center,
          child: _isBannerAdLoaded
              ? SizedBox(
            width: _bottomLargeBannerAd!.size.width.toDouble(),
            height: _bottomLargeBannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bottomLargeBannerAd!),
          )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No favorites saved yet", style: TextStyle(color: Colors.grey, fontSize: 18)),
        ],
      ),
    );
  }
}