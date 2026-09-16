import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lokko_market/model/like_button.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart';
import 'package:lokko_market/screen/bottombar/ad_details_screen.dart';
import 'package:share_plus/share_plus.dart';


class AdModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String phoneNumber;
  final String categoryName;
  final String districtName;
  final String sellerName; // <-- ADD THIS LINE
  final String? sellerAvatarPublicId;
  final List<String> images;
  final double price;
  final DateTime createdAt;
  final bool isVerified;
  final int views;
  final String condition;
  final String authenticity;
  final String status;
  final String divisionName;
  final String categoryId; // Add this
  final String districtId;
  final String? locationName;




  AdModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.phoneNumber,
    required this.categoryName,
    required this.districtName,
    required this.sellerName,
    this.sellerAvatarPublicId,
    required this.images,
    required this.price,
    required this.createdAt,
    required this.isVerified,
    required this.views,
    required this.condition,
    required this.authenticity,
    required this.status,
    required this.divisionName,
    required this.categoryId,
    required this.districtId,
    this.locationName,
  });

  // This is only for admin pannel editadscreen
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'phone': phoneNumber, // Using 'phone' to match your EditAdScreen logic
      'category_name': categoryName,
      'district_name': districtName,
      'seller_name': sellerName,
      'seller_avatar_public_id': sellerAvatarPublicId,
      'images': images,
      'price': price,
      'created_at': createdAt.toIso8601String(),
      'is_verified': isVerified,
      'views': views,
      'condition': condition,
      'authenticity': authenticity,
      'status': status,
      'parent_location_name': divisionName,
      'category_id': categoryId, // Crucial for Edit screen
      'district_id': districtId, // Crucial for Edit screen
    };
  }

  factory AdModel.fromMap(Map<String, dynamic> map) {
    // HELPER: Flattens Supabase joins that return [ {data} ] instead of {data}
    Map<String, dynamic>? flatten(dynamic data) {
      if (data is Map<String, dynamic>) return data;
      if (data is List && data.isNotEmpty) return data.first as Map<String, dynamic>;
      return null;
    }

    final fetchedUserId = map['user_id']?.toString() ?? '';

    // 1. Process Profiles
    final profileMap = flatten(map['profiles']);
    bool isUserVerified = (map['is_verified']?.toString() == 'true') ||
        (profileMap?['is_verified']?.toString() == 'true');
    String sName = profileMap?['full_name']?.toString() ?? "User";
    String? avatarId = map['avatar_public_id']?.toString() ??
        profileMap?['avatar_public_id']?.toString() ??
        map['seller_avatar_public_id']?.toString();

    String pNumber = profileMap?['phone']?.toString().trim() ??
        map['phone']?.toString().trim() ?? '';

    // 2. Process Districts & Parent (UPDATED FOR NEW ALIASES)
    // We check 'location' first because that's the alias in your query
    final locationMap = flatten(map['location']) ?? flatten(map['districts']);

    // dName gets the local name (e.g., Matihar)
    String dName = locationMap?['name']?.toString() ??
        map['district_name']?.toString() ?? 'Bangladesh';

    String divName = '';
    // Check 'district' first (alias for parent_id) then fallback to 'parent'
    final parentMap = flatten(locationMap?['district']) ?? flatten(locationMap?['parent']);

    if (parentMap != null) {
      divName = parentMap['name']?.toString() ?? '';
    } else {
      divName = map['parent_location_name']?.toString() ?? '';
    }

    // 3. Process Categories
    final categoryMap = flatten(map['categories']);
    String cName = categoryMap?['name']?.toString() ??
        map['category_name']?.toString() ?? 'General';

    // 4. Process Images
    List<String> resolvedImages = [];
    final rawImages = map['images'];
    if (rawImages is List) {
      resolvedImages = rawImages.map((img) {
        String path = img.toString();
        return path.startsWith('http') ? path : CloudinaryHelper.getProductImage(path);
      }).toList();
    }

    final String cId = map['category_id']?.toString() ?? '';
    final String dId = map['district_id']?.toString() ?? '';

    return AdModel(
      id: map['id']?.toString() ?? '',
      userId: fetchedUserId,
      title: map['title']?.toString() ?? 'No Title',
      views: int.tryParse(map['views']?.toString() ?? '0') ?? 0,
      phoneNumber: pNumber,
      description: map['description']?.toString() ?? '',
      categoryName: cName,
      districtName: dName, // Shows 'Matihar'
      sellerName: sName,
      sellerAvatarPublicId: avatarId,
      isVerified: isUserVerified,
      images: resolvedImages,
      price: (map['price'] ?? 0).toDouble(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      condition: map['condition']?.toString() ?? 'Used',
      authenticity: map['authenticity']?.toString() ?? 'Original',
      status: map['status']?.toString() ?? 'active',
      locationName: dName,
      divisionName: divName, // Shows 'Rajshahi'
      categoryId: cId,
      districtId: dId,
    );
  }

  factory AdModel.fromJson(Map<String, dynamic> json) => AdModel.fromMap(json);
}

// --- 2. LIST ITEM TILE (UI) ---
class AdItemTile extends StatelessWidget {
  final AdModel ad;
  const AdItemTile({super.key, required this.ad});

  void _shareAd(AdModel ad) {
    // 1. Get the real package name from your Android build
    const String packageName = "com.rxai.lokko";
    const String appLink = "https://play.google.com/store/apps/details?id=$packageName";

    // 2. Format location (Since _displayLocation isn't in this class)
    final String location = ad.divisionName.isNotEmpty
        ? "${ad.divisionName}, ${ad.districtName}"
        : ad.districtName;

    // 3. Format the text for high conversion (WhatsApp friendly)
    final String shareText =
        '🔥 *${ad.title}*\n'
        '💰 Price: ৳ ${ad.price.toStringAsFixed(0)}\n'
        '📍 Location: $location\n\n'
        'Check this out on Lokko Market. Download the app to chat with the seller:\n'
        '$appLink';

    // 4. Trigger the share sheet
    Share.share(shareText, subject: "Interesting find on Lokko Market!");
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AdDetailsScreen(ad: ad)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGE SECTION
            Stack( // Use a Stack to put the badge ON TOP of the image
              children: [
                ad.images.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: ad.images[0],
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    // If status is sold, make the image slightly transparent/grey
                    color: ad.status == 'sold' ? Colors.black.withOpacity(0.3) : null,
                    colorBlendMode: ad.status == 'sold' ? BlendMode.darken : null,
                  ),
                )
                    : const SizedBox(width: 100, height: 100),

                // --- ADD THE SOLD BADGE HERE ---
                if (ad.status == 'sold')
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "SOLD",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // 2. INFORMATION SECTION
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TITLE & VERIFIED BADGE
                      Expanded(
                        child: Row( // Changed from Wrap to Row for better stability
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                ad.title,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Call the badge
                            verifiedBadge(ad.isVerified, key: ValueKey("${ad.id}_${ad.isVerified}")),
                          ],
                        ),
                      ),

                      // ACTION BUTTONS (SHARE & LIKE)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _shareAd(ad),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Icon(Icons.share_outlined, size: 20, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 8),
                          LikeButton(adId: ad.id),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // LOCATION & CATEGORY
                  Text(
                    "${ad.districtName} • ${ad.categoryName}",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),

                  const SizedBox(height: 12),

                  // PRICE
                  // PRICE
                  Text(
                    "৳ ${ad.price.toStringAsFixed(0)}",
                    style: TextStyle(
                      // If sold, use grey. If active, use your green color.
                      color: ad.status == 'sold' ? Colors.grey : const Color(0xFF1aa332),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      // Add a strike-through if you want it to look clearly "gone"
                      decoration: ad.status == 'sold' ? TextDecoration.lineThrough : null,
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

  Widget verifiedBadge(bool isVerified, {Key? key}) {
    debugPrint("UI_CHECK: Badge for ${ad.title} is $isVerified");
    if (!isVerified) return const SizedBox.shrink();
    return Padding(
      key: key, // Add the key here
      padding: const EdgeInsets.only(left: 4),
      child: const Icon(Icons.verified, size: 16, color: Colors.blue),
    );
  }
}