import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart' show CloudinaryHelper;
import 'package:lokko_market/screen/bottombar/ad_details_screen.dart';
import 'package:lokko_market/screen/dashboard_logic.dart';
import 'package:lokko_market/screen/topbar/filter_menu_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class AllPostsView extends ConsumerStatefulWidget {
  const AllPostsView({super.key});

  @override
  ConsumerState<AllPostsView> createState() => _AllPostsViewState();
}

class _AllPostsViewState extends ConsumerState<AllPostsView> {
  @override
  Widget build(BuildContext context) {
    // 1. Listen to the centralized dashboard state
    final dashboardState = ref.watch(dashboardProvider);
    final adsAsync = dashboardState.ads;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1aa332),
        elevation: 0,
        title: const Text(
          "All Ads",
          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () async {
              // 2. Open FilterScreen with current values from Provider
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FilterScreen(
                    initialPrice: RangeValues(
                        dashboardState.minPrice ?? 0,
                        dashboardState.maxPrice ?? 1000000
                    ),
                    initialSort: dashboardState.sortOrder ?? "Newest on top",
                    initialCategoryId: dashboardState.selectedCategoryId,
                    initialDistrictId: dashboardState.selectedDistrictId,
                  ),
                ),
              );

              // 3. Apply the results back to the Notifier
              if (result != null) {
                ref.read(dashboardProvider.notifier).updateFilters(
                  categoryId: result['categoryId'],   // Matches FilterScreen key
                  districtId: result['districtId'],   // Matches FilterScreen key
                  price: result['price'],             // RangeValues
                  sort: result['sort'],               // String
                  locationName: result['locationName'], // String for the UI Label
                );
              }
            },
          ),
        ],
      ),
      // 4. Use .when to handle loading, error, and data automatically
      body: adsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1aa332))),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (adsList) {
          if (adsList.isEmpty) {
            return const Center(child: Text("No ads match your filters."));
          }

          return ListView.separated(
            itemCount: adsList.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              // PASS THE MODEL TO THE TILE
              return BikroyAdTile(ad: adsList[index]);
            },
          );
        },
      ),
    );
  }
}

class BikroyAdTile extends StatelessWidget {
  final AdModel ad; // Use the Model, not Map<String, dynamic>
  const BikroyAdTile({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AdDetailsScreen(ad: ad)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE SECTION
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 125,
                height: 95,
                color: Colors.grey.shade100,
                child: ad.images.isNotEmpty
                    ? Image.network(
                  // 1. TRANSFORM: Turn the ID into a real URL before passing it to the widget
                  CloudinaryHelper.getSmartImageUrl(ad.images[0]),

                  fit: BoxFit.cover,

                  // 2. ERROR HANDLING: This catches 404s (e.g., if you deleted it from Cloudinary)
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint("LOKKO_IMAGE_ERROR: $error");
                    return Container(
                      color: Colors.grey[100],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },

                  // 3. PROGRESS FEEDBACK: Essential for users on mobile data
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: const Color(0xFF1aa332),
                      ),
                    );
                  },
                )
                    : const Icon(Icons.image_outlined, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            // DETAILS SECTION
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${ad.districtName}, ${ad.categoryName}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "৳ ${ad.price}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1aa332),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      timeago.format(ad.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}