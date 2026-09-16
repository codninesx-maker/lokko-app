import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart' show CloudinaryHelper;
import 'package:lokko_market/screen/bottombar/ad_details_screen.dart';
import 'package:lokko_market/screen/bottombar/search_screen.dart';
import 'package:lokko_market/screen/topbar/filter_provider.dart'; // Ensure this contains your FilterNotifier
import 'package:lokko_market/screen/topbar/show_all_post_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeMenuScreen extends ConsumerWidget {
  const HomeMenuScreen({super.key});

  Future<void> checkLikeStatus() async {
    final user = Supabase.instance.client.auth.currentUser;

    // FIX: If user is null or ID is empty, STOP here.
    if (user == null || user.id.isEmpty) {
      debugPrint("LOKKO DEBUG: No user logged in, skipping like check.");
      return;
    }

    try {
      // Define it here so the code below knows what 'supabase' is
      final supabase = Supabase.instance.client;

      // Now this will work
      final response = await supabase
          .from('likes')
          .select()
          .eq('user_id', user.id);

    } catch (e) {
      debugPrint("Error checking like status: $e");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1aa332),
        elevation: 0,
        title: const Text(
          "Lokko Marketplace",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. SEARCH BAR ---
            _buildBikroySearch(context),

            // --- 2. CATEGORY GRID (Now Interactive) ---
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Browse categories",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 10,
                    children: [
                      _buildCategoryItem(context, ref, Icons.phone_android, "Mobiles", Colors.blue),
                      _buildCategoryItem(context, ref, Icons.laptop, "Laptops", Colors.orange),
                      _buildCategoryItem(context, ref, Icons.directions_car, "Vehicles", Colors.red),
                      _buildCategoryItem(context, ref, Icons.home, "Property", Colors.purple),
                      _buildCategoryItem(context, ref, Icons.watch, "Fashion", Colors.pink),
                      _buildCategoryItem(context, ref, Icons.pets, "Pets", Colors.brown),
                      _buildCategoryItem(context, ref, Icons.tv, "Electronics", Colors.teal),
                      _buildCategoryItem(context, ref, Icons.more_horiz, "More...", Colors.grey),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // --- 3. PROMO / VIEW ALL ---
            _buildPromoBanner(context, ref),

            const SizedBox(height: 8),

            // --- 4. FEATURED ADS ---
            _buildFeaturedSection(context),

            const SizedBox(height: 120),
          ],
        ),
      ),

      // --- POST AD BUTTON ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Logic for Post Ad Screen
        },
        backgroundColor: const Color(0xFFFFC107),
        icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 28),
        label: const Text(
          "POST AD",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.1),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBikroySearch(BuildContext context) {
    return Container(
      color: const Color(0xFF1aa332),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen())),
        child: Container(
          height: 45,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
          child: const Row(
            children: [
              SizedBox(width: 12),
              Icon(Icons.search, color: Colors.grey, size: 20),
              SizedBox(width: 10),
              Text("Search for anything...", style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, WidgetRef ref, IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {
        // 1. Update the filter state
        ref.read(filterProvider.notifier).setCategory(label, "");
        // 2. Navigate to show filtered results
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AllPostsView()));
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanner(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          // Reset filters to show ALL
          ref.read(filterProvider.notifier).setCategory("", "");
          ref.read(filterProvider.notifier).setLocation("");
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AllPostsView()));
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.explore, color: Color(0xFF1aa332)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text("View all ads in Bangladesh",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedSection(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text("Featured Ads", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('ads_with_details')
                  .stream(primaryKey: ['id'])
                  .eq('is_featured', true)
                  .limit(10),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No featured ads available"));
                }

                final ads = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: ads.length,
                  itemBuilder: (context, index) {
                    try {
                      final ad = AdModel.fromMap(ads[index]);
                      return _buildFeaturedCard(context, ad);
                    } catch (e) {
                      return const SizedBox.shrink();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(BuildContext context, AdModel ad) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AdDetailsScreen(ad: ad)),
      ),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 120,
                width: 160,
                color: Colors.grey.shade100,
                child: ad.images.isNotEmpty
                    ? Image.network(
                  // 1. Convert the ID to a full URL first
                  CloudinaryHelper.getSmartImageUrl(ad.images[0]),

                  fit: BoxFit.cover,

                  // 2. This handles 404s (deleted images)
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[100],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },

                  // 3. This shows a small indicator while loading on slower networks
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                      ),
                    );
                  },
                )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            Text(ad.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.2)),
            const SizedBox(height: 4),
            Text("Tk ${ad.price.toStringAsFixed(0)}",
                style: const TextStyle(color: Color(0xFF1aa332), fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}