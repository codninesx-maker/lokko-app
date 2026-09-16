import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lokko_market/externalads/lokko_test_banner.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:lokko_market/model/like_button.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart';
import 'package:lokko_market/screen/bottombar/profile/seller_profile_screen.dart';
import 'package:lokko_market/screen/chat/chat_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

class AdDetailsScreen extends StatefulWidget {
  final AdModel ad;
  const AdDetailsScreen({super.key, required this.ad});

  @override
  State<AdDetailsScreen> createState() => _AdDetailsScreenState();
}

class _AdDetailsScreenState extends State<AdDetailsScreen> {
  int _currentImageIndex = 0;
  final Color lokkoGreen = const Color(0xFF1aa332);
  final PageController _pageController = PageController();
  Future<List<AdModel>>? _similarPostFuture;

  // Computed properties to keep build() clean
  String get _displayLocation {
    final rawLocation = widget.ad.districtName.trim();

    // 1. Check if it's a University/Campus entry (usually contains parentheses or "University")
    if (rawLocation.contains('(') || rawLocation.toLowerCase().contains('university')) {
      // Return only the University name for the Map/Header
      return rawLocation;
    }

    // 2. Fallback for standard areas (e.g., "Rajshahi, Boalia")
    final district = widget.ad.divisionName.trim();
    if (rawLocation.isEmpty || rawLocation.toLowerCase() == "null") {
      return district.isNotEmpty ? district : "Bangladesh";
    }

    return district.isNotEmpty ? "$district, $rawLocation" : rawLocation;
  }

  String get _displayCategory => (widget.ad.categoryName.trim().isEmpty ||
      widget.ad.categoryName.toLowerCase() == "null")
      ? "General"
      : widget.ad.categoryName;

  @override
  void dispose() {
    _pageController.dispose(); // Always dispose to save RAM
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _incrementViewCount();
    _similarPostFuture = _fetchSimilarPost();
  }

  Future<void> _incrementViewCount() async {
    try {
      await Supabase.instance.client.rpc(
          'increment_ad_views',
          params: {'ad_id': widget.ad.id} // Ensure this matches the SQL parameter name
      );
      debugPrint("LOKKO_VIEWS: Increment successful for ${widget.ad.id}");
    } catch (e) {
      debugPrint("LOKKO_VIEWS_ERROR: $e");
    }
  }

  Future<List<AdModel>> _fetchSimilarPost() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && session.isExpired) {
        debugPrint("LOKKO_DEBUG: Expired JWT detected. Refreshing session...");
        await Supabase.instance.client.auth.refreshSession();
      }

      final String categoryId = widget.ad.categoryId;
      debugPrint("LOKKO_DEBUG: Fetching similar ads for Category ID: $categoryId");

      // FIX: Explicitly embed related table data so fields are not null
      final response = await Supabase.instance.client
          .from('ads')
          .select('*, categories(name), districts!ads_district_id_fkey(name)')
          .eq('category_id', categoryId)
          .eq('status', 'active')
          .neq('id', widget.ad.id)
          .limit(6);

      final List data = response as List;
      debugPrint("LOKKO_DEBUG: Successfully found ${data.length} similar ads.");

      return data.map((json) => AdModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint("LOKKO_SIMILAR_ADS_ERROR: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(ad),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildImageSlider(ad),
            _buildMainInfo(ad),
            const SizedBox(height: 8),
            _buildDescription(ad),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                width: double.infinity,
                height: 100, // Force structural locked dimension
                alignment: Alignment.center,
                color: Colors.transparent,
                // Use a unique Key to prevent state recycling loops on navigation
                child: const LokkoTestBanner(
                  key: ValueKey('ad_details_banner'),
                  adSize: AdSize.largeBanner,
                ),
              ),
            ),
            _buildSimilarPostSection(),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(ad),
    );
  }

  // --- UI COMPONENTS ---

  PreferredSizeWidget _buildAppBar(AdModel ad) {
    return AppBar(
      backgroundColor: lokkoGreen,
      elevation: 0,
      title: const Text("Post Details", style: TextStyle(color: Colors.white, fontSize: 17)),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.share, size: 20),
          onPressed: () {
            // 1. Direct URL structure on your domain
            // Using a clean path like /ad/${ad.id}
            final String postLink = "https://codninesx-maker.github.io/ad/${ad.id}";

            // 2. Format the text
            final String shareText =
                '🔥 *${ad.title}*\n'
                '💰 Price: ৳ ${ad.price.toStringAsFixed(0)}\n'
                '📍 Location: $_displayLocation\n\n'
                'Check this out on Lokko Market. Click to view the post instantly:\n'
                '$postLink';

            // 3. Trigger the share sheet
            Share.share(shareText, subject: "Interesting find on Lokko Market!");
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: LikeButton(adId: ad.id),
        ),
      ],
    );
  }

  Widget _buildSimilarPostSection() {
    return FutureBuilder<List<AdModel>>(
      future: _similarPostFuture,
      builder: (context, snapshot) {
        debugPrint("LOKKO_UI_DEBUG: ConnectionState = ${snapshot.connectionState}, HasData = ${snapshot.hasData}");

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1aa332), // Synchronized with corporate branding hex
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          // If database returns empty, hide the area cleanly out of sight
          return const SizedBox.shrink();
        }

        final similarList = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 16, 12, 4),
              child: Text(
                "Similar Recommendations",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            // Changed to a non-scrolling vertical list using ListView.separated
            // to sit seamlessly within your parent scrollable screen.
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: similarList.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return _buildSimilarCard(similarList[index]);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSimilarCard(AdModel item) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdDetailsScreen(ad: item),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), // Exact layout match
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE SECTION (LEFT SIDE)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 125, // Matched tile width
                height: 95, // Matched tile height
                color: Colors.grey.shade100,
                child: item.images.isNotEmpty
                    ? Image.network(
                  CloudinaryHelper.getSmartImageUrl(item.images[0]),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint("LOKKO_IMAGE_ERROR: $error");
                    return Container(
                      color: Colors.grey[100],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
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

            // DETAILS SECTION (RIGHT SIDE)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${item.districtName}, ${item.categoryName}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "৳ ${item.price}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1aa332),
                    ),
                  ),
                  // Timestamp aligned neatly at the bottom right corner
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      timeago.format(item.createdAt),
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

  Widget _buildImageSlider(AdModel ad) {
    final bool isSold = ad.status == 'sold';

    return Stack(
      children: [
        // 1. THE IMAGE LAYER (Base)
        Container(
          height: 300,
          width: double.infinity,
          color: Colors.black,
          child: ad.images.isNotEmpty
              ? PageView.builder(
            controller: _pageController,
            physics: const PageScrollPhysics(),
            allowImplicitScrolling: true,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemCount: ad.images.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openFullScreenImage(ad.images[index]),
                child: _buildGalleryImage(ad.images[index]),
              );
            },
          )
              : const Center(
            child: Icon(Icons.image, size: 80, color: Colors.white24),
          ),
        ),

        // 2. THE SOLD BADGE (Top Right Corner)
        if (isSold)
          Positioned(
            top: 16,     // Distance from top
            right: 16,   // Distance from right
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4), // Sharper look for a badge
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: const Text(
                  "SOLD",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14, // Reduced font size
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),

        // 3. THE IMAGE COUNTER
        // We move the counter to the LEFT or slightly lower if it overlaps
        if (ad.images.length > 1)
          Positioned(
            bottom: 16,
            right: 16,
            child: _buildImageCounter(ad.images.length),
          ),
      ],
    );
  }

  Widget _buildGalleryImage(String imageId) {
    // 1. Get a high-quality URL specifically for the details slider
    final fullUrl = CloudinaryHelper.getSmartImageUrl(imageId);

    return Image.network(
      fullUrl,
      width: double.infinity,
      // 2. Change fit to cover to fill the 300dp height without stretching logic gaps
      fit: BoxFit.cover,
      // 3. Increase cacheWidth slightly. 1080 is the native width of your KM7
      cacheWidth: 800,
      filterQuality: FilterQuality.medium, // 4. Adds a slight sharpening during downscaling
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 300,
          color: Colors.black12,
          child: const Center(
              child: CircularProgressIndicator(color: Colors.white70)
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white24, size: 50)
      ),
    );
  }

  Widget _buildImageCounter(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text("${_currentImageIndex + 1}/$total",
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMainInfo(AdModel ad) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ad.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text("${timeago.format(ad.createdAt)} • $_displayLocation",
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 10),
          _buildViewCount(ad.views),
          const Divider(height: 24),
          Text("Tk ${ad.price.toStringAsFixed(0)}",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: lokkoGreen)),
          const SizedBox(height: 12),
          _buildSellerRow(ad),
          const Divider(height: 32),
          _buildDetailRow("Condition", ad.condition),
          _buildDetailRow("Authenticity", ad.authenticity),
          _buildDetailRow("Category", _displayCategory),
          _buildDetailRow("Location", _displayLocation),
        ],
      ),
    );
  }

  Widget _buildViewCount(int views) {
    // If no one has seen it yet, don't show the row at all
    if (views <= 0) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(Icons.visibility_outlined, size: 16, color: lokkoGreen),
        const SizedBox(width: 6),
        Text(
          // Added 'NumberFormat' logic mentally here: 1000 -> 1k
          views > 999 ? "${(views / 1000).toStringAsFixed(1)}k views" : "$views views",
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSellerRow(AdModel ad) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        _openSellerProfile(ad.userId);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Keep the row content tight to the left
          children: [
            Text(
                "For sale by ",
                style: TextStyle(color: Colors.grey[700], fontSize: 14)
            ),
            Text(
              ad.sellerName,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: lokkoGreen,
                  fontSize: 14
              ),
            ),
            // This will now sit right next to the name
            verifiedBadge(ad.isVerified),
          ],
        ),
      ),
    );
  }

// Add this helper function in the Logic & Helpers section
  void _openSellerProfile(String sellerId) {
    HapticFeedback.mediumImpact(); // Feels good on the TECNO KM7

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellerProfileScreen(userId: sellerId),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align to top for multi-line
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(width: 16), // Space between label and value
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w500),
              // This allows the text to wrap to the next line instead of overflowing
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(AdModel ad) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Description", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(ad.description, style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildBottomActions(AdModel ad) {
    // Check if the ad is sold
    final bool isSold = ad.status == 'sold';

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2)
            )
          ],
        ),
        // If sold, show a full-width disabled button/message
        // If active, show the Call/Chat/WhatsApp row
        child: isSold
            ? Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            "This item has been sold",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        )
            : Row(
          children: [
            _actionBtn(Icons.call, "Call", () => _makeCall(ad.phoneNumber)),
            const SizedBox(width: 8),
            _actionBtn(Icons.chat_bubble_outline, "Chat", () => _openChat(ad)),
            const SizedBox(width: 8),
            _actionBtn(FontAwesomeIcons.whatsapp, "WhatsApp", () => _openWhatsApp(ad.phoneNumber)),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: lokkoGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () {
          HapticFeedback.lightImpact(); // Add this line
          onTap();
        },
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- LOGIC & HELPERS ---

  void _openFullScreenImage(String initialImage) {
    final int initialIndex = widget.ad.images.indexOf(initialImage);
    final List<String> adImages = widget.ad.images;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(widget.ad.title, style: const TextStyle(fontSize: 14)),
          ),
          body: PageView.builder(
            itemCount: adImages.length,
            controller: PageController(initialPage: initialIndex),
            itemBuilder: (context, index) {
              // FIX: Defined inside the builder so 'index' is valid
              final watermarkedUrl = CloudinaryHelper.getWatermarkedProductImage(adImages[index]);

              return InteractiveViewer(
                clipBehavior: Clip.none,
                minScale: 1.0,
                maxScale: 4.0,
                panEnabled: true,
                scaleEnabled: true,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: watermarkedUrl,
                    fit: BoxFit.fitWidth,
                    width: MediaQuery.of(context).size.width,
                    // Limits decoding to 800px to prevent memory crashes on KM7
                    memCacheWidth: 800,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white24, size: 40),
                        Text("Check Logo ID", style: TextStyle(color: Colors.white24, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _makeCall(String phone) async {
    if (phone.trim().isEmpty || phone == "null") {
      _showSnackBar("Seller has not provided a phone number", isError: true);
      return;
    }
    // 1. Give haptic feedback so the buyer knows the tap registered
    HapticFeedback.lightImpact();

    // 2. Clean the number (LOKKO users might enter spaces or dashes)
    final String cleanNumber = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    // 3. Create the URI
    final Uri url = Uri(scheme: 'tel', path: cleanNumber);

    try {
      // 4. Check if the device can actually make calls
      if (await canLaunchUrl(url)) {
        // 5. launchUrl with 'externalApplication' is what triggers
        // the "Automatic" jump to the phone's keypad.
        await launchUrl(
            url,
            mode: LaunchMode.externalApplication
        );
      } else {
        _showSnackBar("Could not open dialer", isError: true);
      }
    } catch (e) {
      debugPrint("Call Error: $e");
      _showSnackBar("Could not initiate call", isError: true);
    }
  }

  void _openWhatsApp(String phone) async {
    // 1. Force the string to be a string and trim it
    String rawPhone = phone.toString().trim();
    debugPrint("Original Phone: $rawPhone");

    if (rawPhone.isEmpty || rawPhone == "null") {
      _showSnackBar("Seller has no WhatsApp number", isError: true);
      return;
    }

    // 2. Remove EVERYTHING except numbers
    String cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');

    // 3. Bangladesh Formatting (017... -> 88017...)
    if (cleanPhone.startsWith('01') && cleanPhone.length == 11) {
      cleanPhone = '88$cleanPhone';
    }

    // 4. If it's already 11 digits but starts with 1 (missing 0), add 880
    if (cleanPhone.startsWith('1') && cleanPhone.length == 10) {
      cleanPhone = '880$cleanPhone';
    }

    debugPrint("Clean Phone for WhatsApp: $cleanPhone");

    final message = Uri.encodeComponent(
        "Hi, I'm interested in your ad on Lokko: ${widget.ad.title}");

    // Use the direct whatsapp:// scheme for better results on your TECNO KM7
    final Uri whatsappUri = Uri.parse("whatsapp://send?phone=$cleanPhone&text=$message");
    final Uri httpsUri = Uri.parse("https://wa.me/$cleanPhone?text=$message");

    try {
      bool launched = await launchUrl(whatsappUri, mode: LaunchMode.externalNonBrowserApplication);
      if (!launched) {
        await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("WhatsApp Error: $e");
      _showSnackBar("Could not open WhatsApp", isError: true);
    }
  }

  void _openChat(AdModel ad) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          roomId: null, // Allow it to be null for new chats
          ad: ad,
          receiverName: ad.sellerName ?? "Seller",
          receiverId: ad.userId,
          receiverAvatarPublicId: ad.sellerAvatarPublicId,
        ),
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : lokkoGreen),
    );
  }

  Widget verifiedBadge(bool isVerified) {
    if (!isVerified) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(left: 5), // Small gap from the name
      child: Icon(
          Icons.verified,
          size: 15, // Slightly smaller than the text for a balanced look
          color: Colors.blue
      ),
    );
  }
}