import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lokko_market/externalads/lokko_test_banner.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart' show CloudinaryHelper;
import 'package:lokko_market/screen/bottombar/ad_details_screen.dart';
import 'package:lokko_market/screen/bottombar/profile/account_screen.dart';
import 'package:lokko_market/screen/bottombar/search_screen.dart';
import 'package:lokko_market/screen/chat/chat_list_screen.dart';
import 'package:lokko_market/screen/bottombar/create_post_screen.dart';
import 'package:lokko_market/screen/topbar/category_menu_screen.dart';
import 'package:lokko_market/screen/topbar/filter_menu_screen.dart';
import 'package:lokko_market/screen/topbar/location_menu_state.dart';
import 'package:lokko_market/screen/topbar/notification_bell_red_dot.dart';
import 'dashboard_logic.dart';
import 'package:lokko_market/screen/topbar/filter_tab.dart';
import 'package:lokko_market/screen/topbar/show_all_post_screen.dart';
import 'package:flutter_riverpod/legacy.dart';



final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

class DashboardView extends ConsumerWidget {
  final bool isAdmin;
  const DashboardView({super.key,this.isAdmin = false,});


  void _openLocationMenu(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationMenu()),
    );

    if (result != null && result is Map) {
      debugPrint("LOKKO_DEBUG: Location Selected -> ${result['location_name']} (ID: ${result['location_id']})");

      // CRITICAL: Ensure your notifier handles 'locationId' as the filter key
      ref.read(dashboardProvider.notifier).updateLocation(
          locationId: result['location_id'].toString(),
          locationName: result['location_name']
      );
    }
  }

  void _openCategoryMenu(BuildContext context, WidgetRef ref) async {
    // 1. Wait for the multi-level CategoryMenu selection to return
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CategoryMenu()),
    );

    if (result != null && result is Map) {
      // 2. Safely extract values regardless of whether it's Level 1, 2, or 3
      final String catId = result['category_id'].toString();
      final String catName = result['category_name'];

      debugPrint("LOKKO_DEBUG: Selected Category Target -> $catName (ID: $catId)");

      // 3. Trigger your optimized 3-Level background query engine
      ref.read(dashboardProvider.notifier).updateFilters(
        categoryId: catId,
        categoryName: catName,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final adsAsync = state.ads; // Extract ads from the watched state


    String displayLocation = (state.selectedLocationName != null &&
        state.selectedLocationName!.isNotEmpty &&
        state.selectedLocationName != "null")
        ? state.selectedLocationName!
        : "Location";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1aa332),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text("LOKKO",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: state.ads.when(
                data: (adsList) => Text(
                  "${adsList.length}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                loading: () => const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),
          const NotificationBell(),
        ],
      ),
      // 1. CRASH FIX: The IndexedStack MUST always exist, regardless of data loading state
      body: IndexedStack(
        index: currentIndex,
        children: [
          // Pass 'state' as the third argument here
          _buildHomeWithData(context, ref, state, adsAsync),
          const SearchScreen(),
          const SizedBox.shrink(),
          const ChatListScreen(),
          const AccountScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, ref),
    );
  }

  // 1. Correct the parameter type to DashboardState
  Widget _buildHomeWithData(BuildContext context, WidgetRef ref, DashboardState state, AsyncValue<List<AdModel>> adsAsync) {
    final String currentLoc = state.selectedLocationName ?? "";

    return Column(
      children: [
        // 1. THE TOPBAR (Filter Section)
        Container(
          color: const Color(0xFF1aa332),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterTab(
                  icon: Icons.location_on,
                  label: currentLoc.isEmpty ? "Location" : currentLoc,
                  filterType: 'location',
                  onTap: () => _openLocationMenu(context, ref),
                ),
                const SizedBox(width: 15),
                FilterTab(
                  icon: Icons.grid_view,
                  label: ref.watch(dashboardProvider).selectedCategoryName ?? "Category",
                  filterType: 'category',
                  onTap: () => _openCategoryMenu(context, ref),
                ),
                const SizedBox(width: 15),
                FilterTab(
                  icon: Icons.people_outline,
                  label: "All Ads",
                  filterType: 'all',
                  onTap: () {
                    // Clear the active dashboard state driving this view
                    ref.read(dashboardProvider.notifier).resetFilters(); // Or your equivalent reset method

                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AllPostsView()),
                    );
                  },
                ),
                const SizedBox(width: 15),
                FilterTab(
                  icon: Icons.tune,
                  label: "Filter",
                  filterType: 'manual',
                  onTap: () async {
                    final currentState = ref.read(dashboardProvider);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FilterScreen(
                          initialCategoryId: currentState.selectedCategoryId,
                          initialCategoryName: currentState.selectedCategoryName,
                          initialDistrictId: currentState.selectedDistrictId,
                          initialLocationName: currentState.selectedLocationName,
                          initialPrice: RangeValues(currentState.minPrice, currentState.maxPrice),
                          initialSort: currentState.sortOrder,
                        ),
                      ),
                    );

                    if (result['categoryId'] == null && result['districtId'] == null) {
                      ref.read(dashboardProvider.notifier).resetFilters();
                    } else {
                      ref.read(dashboardProvider.notifier).updateFilters(
                        categoryId: result['categoryId'],
                        categoryName: result['categoryName'],
                        districtId: result['districtId'],
                        locationName: result['locationName'],
                        price: result['price'],
                        sort: result['sort'],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),

        // 2. THE AD VIEW (With Clean Connection Check)
        Expanded(
          child: adsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF1aa332)),
            ),
            // --- UPDATED ERROR BLOCK ---
            error: (error, stack) {
              // Check if the error message contains network keywords
              final errorStr = error.toString();
              final isNetworkIssue = errorStr.contains("SocketException") ||
                  errorStr.contains("host lookup") ||
                  errorStr.contains("ClientException");

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isNetworkIssue ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isNetworkIssue
                            ? "Check your connection please"
                            : "Something went wrong. Please try again.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 140,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1aa332),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => ref.invalidate(dashboardProvider),
                          child: const Text("Try Again"),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            data: (adsList) {
              if (adsList.isEmpty) {
                return const Center(child: Text("No ads found in this category/location"));
              }

              const int chunkSize = 4;
              final List<Widget> sliverItems = [];

              for (int i = 0; i < adsList.length; i += chunkSize) {
                final chunk = adsList.sublist(
                    i,
                    i + chunkSize > adsList.length ? adsList.length : i + chunkSize
                );

                // 1. Add the 2-product grid row segment
                sliverItems.add(
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildAdCard(context, chunk[index]),
                        childCount: chunk.length,
                      ),
                    ),
                  ),
                );

                // 2. Insert a horizontal full-width banner ad after this row
                if (i + chunkSize < adsList.length || chunk.length == chunkSize) {
                  sliverItems.add(
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: RepaintBoundary(
                          child: Container(
                            width: double.infinity, // Outer wrapper takes up screen width safely
                            height: 50, // Strict height for standard banner
                            alignment: Alignment.center, // Centers the small ad asset cleanly
                            color: Colors.transparent,
                            child: const LokkoTestBanner(
                              adSize: AdSize.banner, // KEEPS IT SMALL
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }

              return CustomScrollView(
                slivers: sliverItems,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdCard(BuildContext context, AdModel ad) {
    final String categoryDisplay = (ad.categoryName == null || ad.categoryName.isEmpty)
        ? 'General'
        : ad.categoryName;

    final String locationDisplay = (ad.districtName.isEmpty || ad.districtName == 'null')
        ? 'Bangladesh'
        : (ad.divisionName.isNotEmpty && ad.divisionName != ad.districtName)
        ? "${ad.divisionName}, ${ad.districtName}" // Result: "Rajshahi, Boalia"
        : ad.districtName;

    final String firstImage = (ad.images.isNotEmpty) ? ad.images[0] : "";
    final bool hasImage = firstImage.isNotEmpty;

    // KM7 FIX: Always use the Thumbnail URL for the Grid to save bandwidth and RAM
    final String imageUrl = hasImage ? CloudinaryHelper.getThumbnailUrl(firstImage) : "";

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AdDetailsScreen(ad: ad)),
      ),
      child: Card(
        elevation: 1.5,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- OPTIMIZED IMAGE SECTION ---
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF5F5F5),
                child: hasImage
                    ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  // RAM Optimization: Limits memory usage to exactly what the grid needs
                  memCacheWidth: 250,
                  memCacheHeight: 250,
                  maxWidthDiskCache: 400,
                  // GPU Optimization: Reduces work for the Mali-G52
                  filterQuality: FilterQuality.low,
                  placeholder: (context, url) => Center(
                    child: Image.asset(
                      'assets/images/placeholder.png',
                      width: 40,
                      color: Colors.grey[300],
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                )
                    : const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
              ),
            ),

            // TEXT SECTION
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      ad.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      "$categoryDisplay • $locationDisplay",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 9),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            "৳ ${ad.price.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: Color(0xFF1aa332),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (ad.isVerified)
                          const Icon(Icons.verified, size: 12, color: Colors.blue),
                      ],
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }


  Widget _buildBottomNav(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) async {
        if (index == 2) {
          // 1. Wait for the result from PostAdScreen
          final refresh = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PostAdScreen())
          );

          // 2. If an ad was posted successfully (returns true), refresh the list
          if (refresh == true) {
            PaintingBinding.instance.imageCache.clear();
            ref.refresh(dashboardProvider); // This is good
          }
          return; // Don't change the index to 2, keep it at 0 (Home)
        }

        // Handle other tabs
        ref.read(bottomNavIndexProvider.notifier).state = index;

        if (index == 0 && currentIndex == 0) {
          ref.invalidate(dashboardProvider);
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF1aa332),
      unselectedItemColor: Colors.grey,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Home"),
        const BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFFFCA28), shape: BoxShape.circle),
            child: const Icon(Icons.add, color: Colors.black),
          ),
          label: "Post Ad",
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Chat"),
        const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Account"),
      ],
    );
  }
}