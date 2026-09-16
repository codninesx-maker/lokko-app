import 'package:cached_network_image/cached_network_image.dart'; // Add this for better performance
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lokko_market/ad_repository.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart';
import 'package:lokko_market/screen/bottombar/ad_details_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';


class SellerProfileScreen extends ConsumerWidget {
  final String userId;
  const SellerProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adRepo = ref.read(adRepositoryProvider);

    return FutureBuilder(
      future: Supabase.instance.client
          .from('profiles')
          .select('*, districts(name, parent:parent_id(name))') // Ensure avatar_url is in the '*' or add it explicitly
          .eq('id', userId)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF1aa332))),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF1aa332),
              title: const Text("Profile", style: TextStyle(color: Colors.white)),
            ),
            body: const Center(child: Text("Profile not found")),
          );
        }

        final profile = snapshot.data as Map<String, dynamic>;
        final String name = profile['full_name'] ?? 'User';
        final bool isVerified = profile['is_verified'] ?? false;

// --- UPDATED IMAGE LOGIC ---
        final String? pubId = profile['avatar_public_id'];
        final String? legacyUrl = profile['avatar_url'];

        String? avatarUrl;
        if (pubId != null && pubId.isNotEmpty) {
          // Pull from Cloudinary if ID exists
          avatarUrl = CloudinaryHelper.getProfileAvatar(pubId);
        } else if (legacyUrl != null && legacyUrl.isNotEmpty) {
          // Fallback to legacy URL
          avatarUrl = legacyUrl;
        }
// ---------------------------

        debugPrint("DEBUG_LOKKO_AVATAR_RESOLVED: $avatarUrl");

        // Hierarchical Location Logic
        final districtMap = profile['districts'];
        final String thana = districtMap?['name'] ?? '';
        final String district = districtMap?['parent']?['name'] ?? '';
        final String locationLabel = (district.isNotEmpty && thana.isNotEmpty)
            ? "$district, $thana"
            : (thana.isNotEmpty ? thana : "Bangladesh");

        final String memberSince = profile['created_at'] != null
            ? DateFormat('MMM yyyy').format(DateTime.parse(profile['created_at']))
            : '2025';

        return Scaffold(
          backgroundColor: Colors.white, // Match brand background
          appBar: AppBar(
            backgroundColor: const Color(0xFF1aa332),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "LOKKO PROFILE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [

                // --- LOKKO BRANDED HEADER (ADJUSTED WIDTH) ---
                // --- NEW CLEAN LOKKO HEADER (BRIGHT & WHITE) ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0), // Small gap from AppBar
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 25, top: 15),
                    decoration: BoxDecoration(
                      color: Colors.white, // CHANGE: Use white background, not green
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04), // Suttle shadow for separation
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (avatarUrl != null && avatarUrl.isNotEmpty) {
                              _showLargeAvatar(context, avatarUrl);
                            }
                          },
                          child: Hero(
                            tag: 'avatar_preview',
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                // --- FIXED: USE LOKKO GREEN FOR BORDER ---
                                border: Border.all(color: const Color(0xFF1aa332), width: 3),
                              ),
                              child: CircleAvatar(
                                radius: 50, // Slightly smaller for cleaner look
                                backgroundColor: Colors.grey[100],
                                child: (avatarUrl != null && avatarUrl.isNotEmpty)
                                    ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF1aa332), // Fix loader color
                                    ),
                                  ),
                                )
                                    : const Icon(
                                    Icons.person,
                                    size: 60,
                                    // --- FIXED: USE LOKKO GREEN FOR ICON ---
                                    color: Color(0xFF1aa332)
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // NAME ROW
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                // --- FIXED: Use Black text, not white ---
                                color: Colors.black,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 6),
                              // Verified icon is often blue, but LOKKO blue is ok
                              const Icon(Icons.verified, color: Colors.blue, size: 20),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),

                        // VERIFICATION & LOCATION STATUS
                        Text(
                          isVerified ? "Verified Seller in $district" : "Seller in $district",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            // --- FIXED: Use clean grey text ---
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- STATS SECTION ---
                Transform.translate(
                  offset: const Offset(0, -20), // Pull stats slightly up into the green area
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildStatCard("Location", locationLabel, Icons.location_on),
                        const SizedBox(width: 12),
                        _buildStatCard("Member Since", memberSince, Icons.calendar_today),
                      ],
                    ),
                  ),
                ),

                // --- ACTIVE ADS SECTION ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1aa332),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "SELLER'S ADS",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),

                // --- REPLACE YOUR FUTUREBUILDER WITH THIS PIECE ---
                FutureBuilder<List<AdModel>>(
                  // ✅ FIX: Use the Riverpod provider instance created at the top of build()
                  future: adRepo.fetchAdsByUserId(userId),
                  builder: (context, adSnapshot) {
                    if (adSnapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(50.0),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF1aa332))),
                      );
                    }
                    final ads = adSnapshot.data ?? [];
                    if (ads.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(50.0),
                        child: Text("No ads posted yet.", style: TextStyle(color: Colors.grey)),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: ads.length,
                      // ✅ FIX: Added locationLabel here
                      itemBuilder: (context, index) => _buildAdCard(context, ads[index], locationLabel),
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        // We use a fixed height or minHeight to keep the cards even
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Fixes the 'unbounded height' error
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1aa332), size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            // Use Flexible instead of Expanded to avoid the crash
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5, // Slightly smaller to fit long RUET address
                  color: Colors.black87,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REPLACE YOUR OLD _buildAdCard FUNCTION WITH THIS ---
  Widget _buildAdCard(BuildContext context, AdModel ad, String fallbackLocation) {
    // ✅ FIX: Gracefully fall back to the profile's district location label if needed
    final String locationDisplay = (ad.districtName.isNotEmpty && ad.districtName != 'null')
        ? ad.districtName
        : fallbackLocation;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AdDetailsScreen(ad: ad)),
      ),
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    child: ad.images.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: ad.images[0],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[100],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    )
                        : Container(
                      color: Colors.grey[100],
                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  ),
                  if (ad.isVerified)
                    const Positioned(
                      top: 5,
                      right: 5,
                      child: Icon(Icons.verified, color: Colors.blue, size: 18),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locationDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "৳ ${ad.price.toStringAsFixed(0)}",
                    style: const TextStyle(
                        color: Color(0xFF1aa332),
                        fontWeight: FontWeight.w900,
                        fontSize: 14
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

  void _showLargeAvatar(BuildContext context, String url) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withOpacity(0.9), // Darker background for focus
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), // Increased blur
            child: Material(
              color: Colors.transparent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Hero(
                      tag: 'avatar_preview',
                      child: Container(
                        // --- INCREASED SIZE ---
                        // Taking 92% of the width for a "Large" feel
                        width: MediaQuery.of(context).size.width * 0.92,
                        height: MediaQuery.of(context).size.width * 0.92,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // X Button - Positioned further out
                  Positioned(
                    top: 60,
                    right: 25,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withOpacity(0.4),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(anim1),
            child: child,
          ),
        );
      },
    );
  }
}