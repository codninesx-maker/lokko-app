import 'package:flutter/material.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart';
import 'package:lokko_market/screen/bottombar/profile/onetoseven/edit_ad_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class MyAdsScreen extends StatefulWidget {
  const MyAdsScreen({super.key});

  @override
  State<MyAdsScreen> createState() => _MyAdsScreenState();
}

class _MyAdsScreenState extends State<MyAdsScreen> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _myAdsFuture;

  @override
  void initState() {
    super.initState();
    _myAdsFuture = _fetchMyAds(); // Store the future so it doesn't reset on every rebuild
  }

// When you need to refresh (after edit or delete)
  void _refreshAds() {
    setState(() {
      _myAdsFuture = _fetchMyAds();
    });
  }

  // Function to fetch real ads from the database
  Future<List<Map<String, dynamic>>> _fetchMyAds() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await supabase
          .from('ads')
          .select('''
          *,
          categories:category_id (name),
          districts!ads_district_id_fkey (name),
          profiles:user_id (is_verified, full_name) 
        ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("LOKKO_MY_ADS_FETCH_ERROR: $e");
      rethrow;
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> ad) async {
    final String adId = ad['id'].toString();
    final List<dynamic> imageUrls = ad['images'] ?? [];

    // 1. DEFINE the variable by showing the dialog
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Ad?"),
        content: const Text("This will permanently remove the ad from LOKKO."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    // 2. USE the variable (This is where the 'Undefined' error happens if step 1 is missing)
    if (shouldDelete == true) {
      try {
        // 1. Show Loader
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        // 2. --- CLOUDINARY CLEANUP (SAFE WRAP) ---
        // We wrap this so a Cloudinary error doesn't stop the Database delete
        try {
          for (var imageId in imageUrls) {
            // Ensure this is a Public ID, not a full URL
            await CloudinaryHelper.deleteOldImage(imageId.toString());
          }
        } catch (cloudinaryErr) {
          debugPrint("CLOUDINARY_CLEANUP_FAILED: $cloudinaryErr");
          // We don't 'throw' here, so we can proceed to delete the record
        }

        // 3. --- DATABASE DELETE ---
        final response = await supabase.from('ads').delete().eq('id', adId);

        // 4. Close Loader and Refresh
        if (mounted) {
          Navigator.pop(context); // Close the CircularProgressIndicator
          _refreshAds(); // Refresh the UI list

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ad deleted successfully")),
          );
        }
      } catch (e) {
        // Handle Database or unexpected errors
        if (mounted) {
          Navigator.pop(context); // Ensure loader is closed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${e.toString()}")),
          );
        }
        debugPrint("DELETE_ERROR: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light grey background to make cards pop
      appBar: AppBar(
        backgroundColor: const Color(0xFF1aa332), // LOKKO Green
        title: const Text("My Post", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _myAdsFuture,
        builder: (context, snapshot) {
          // 1. Handle Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1aa332)),
            );
          }

          // 2. --- CRITICAL FIX: Handle Errors (Socket/Internet) ---
          if (snapshot.hasError) {
            final errorStr = snapshot.error.toString();
            // Checking for common Flutter/Supabase network error strings
            bool isNetworkError = errorStr.contains("SocketException") ||
                errorStr.contains("host lookup") ||
                errorStr.contains("ClientException") ||
                errorStr.contains("errno = 7");

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isNetworkError
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
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1aa332),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _refreshAds, // Retries the fetch
                      child: const Text("Try Again", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          }

          // 3. Handle Empty State
          final myAds = snapshot.data ?? [];
          if (myAds.isEmpty) {
            return _buildEmptyState();
          }

          // 4. Build the List
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myAds.length,
            itemBuilder: (context, index) {
              final ad = myAds[index];
              final List images = ad['images'] ?? [];
              final String? imageUrl = images.isNotEmpty ? images[0] : null;

              // Get current status for the "Mark as Sold" logic
              final String status = ad['status']?.toString() ?? 'pending';
              final bool isSold = status == 'sold';
              final String categoryDisplayName = ad['categories']?['name']?.toString() ?? 'GENERAL';

              // 1. STATUS BADGE LOGIC
              Color statusColor;
              String statusText = status.toUpperCase();

              switch (status) {
                case 'active':
                  statusColor = Colors.green;
                  break;
                case 'pending':
                  statusColor = Colors.orange;
                  statusText = "UNDER REVIEW";
                  break;
                case 'rejected':
                  statusColor = Colors.red;
                  statusText = "REJECTED";
                  break;
                case 'sold':
                  statusColor = Colors.blue;
                  break;
                default:
                  statusColor = Colors.grey;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                color: isSold ? Colors.grey.shade50 : Colors.white, // Dim if sold
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EditAdScreen(ad: ad)),
                    );
                    if (result == true) _refreshAds();
                  },
                  onLongPress: () => _confirmDelete(ad),
                  child: Stack( // Added stack to show "SOLD" badge if applicable
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // --- IMAGE SECTION ---
                                Container(
                                  width: 90, height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                    image: imageUrl != null
                                        ? DecorationImage(
                                      image: NetworkImage(CloudinaryHelper.getSmartImageUrl(imageUrl)),
                                      fit: BoxFit.cover,
                                      // Add FilterQuality to match your Edit Screen fix
                                      filterQuality: FilterQuality.medium,
                                    )
                                        : null,
                                  ),
                                  child: imageUrl == null ? const Icon(Icons.image, color: Colors.grey) : null,
                                ),
                                const SizedBox(width: 12),

                                // --- TITLE, CATEGORY, PRICE ---
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ad['title'] ?? 'No Title',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          decoration: isSold ? TextDecoration.lineThrough : null,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        (ad['categories']?['name'] ?? ad['category_name'] ?? 'GENERAL').toString().toUpperCase(),
                                        style: const TextStyle(color: Color(0xFF1aa332), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "৳ ${ad['price']}", // Switched to Taka for Bangladesh market
                                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      // 2. STATUS BADGE CONTAINER (Visible inside the card)
                                      // ---------------------------------------------------------
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: statusColor, width: 0.5),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // --- SOLD TOGGLE ---
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    debugPrint("LOKKO_CLICK: Icon clicked for Ad ${ad['id']}");
                                    _toggleSoldStatus(ad['id'].toString(), status);
                                  },
                                  child: IconButton(
                                    icon: Icon(
                                      isSold ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: isSold ? Colors.blue : Colors.grey,
                                    ),
                                    // Setting onPressed to null ensures the GestureDetector
                                    // handles the tap exclusively
                                    onPressed: null,
                                    tooltip: "Mark as Sold",
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 0.5),
                            // Add your Location row here if needed
                          ],
                        ),
                      ),
                      if (isSold)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4)
                            ),
                            child: const Text(
                                "SOLD",
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("You haven't posted any ads yet", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
  //for options for mark as sold
  Future<void> _toggleSoldStatus(String adId, String currentStatus) async {
    // 1. Instant calculation
    final String newStatus = (currentStatus == 'active') ? 'sold' : 'active';

    try {
      // 2. Silent Database Update
      await supabase
          .from('ads')
          .update({'status': newStatus})
          .eq('id', adId);

      // 3. Instant UI Refresh
      // Since this is silent, the user sees the "SOLD" badge
      // appear or disappear instantly on the card.
      _refreshAds();

    } catch (e) {
      debugPrint("LOKKO_STATUS_ERROR: $e");
      // Only show a message if it actually fails,
      // otherwise stay quiet.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text("Could not update status"),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }
}