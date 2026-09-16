import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lokko_market/adminpannel/manage_live-markets_ads.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:lokko_market/screen/bottombar/ad_details_screen.dart';



class ManageLiveAdsScreen extends ConsumerStatefulWidget {
  const ManageLiveAdsScreen({super.key});

  @override
  ConsumerState<ManageLiveAdsScreen> createState() => _AdminManageScreenState();
}

class _AdminManageScreenState extends ConsumerState<ManageLiveAdsScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final adsState = ref.watch(managelivemarketsads);
    final Color lokkoGreen = const Color(0xFF1aa332);

    return Scaffold(
        appBar: AppBar(
          backgroundColor: lokkoGreen,
          title: const Text(
            "Manage Live Market Ads",
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
            children: [
        // 1. SEARCH FILTER SECTION
        Padding(
        padding: const EdgeInsets.all(12.0),
        child: TextField(
        onChanged: (value) {
      setState(() {
        _searchQuery = value.toLowerCase();
      });
    },
    decoration: InputDecoration(
    hintText: "Search ads by title or user ID...",
    prefixIcon: const Icon(Icons.search),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(vertical: 0),
    ),
    ),
    ),

    // 2. LIVE DATA BLOCK
    Expanded(
    child: adsState.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (err, _) => Center(child: Text("Error fetching ads: $err")),
    data: (allAds) {
    // Apply search filter locally
    final filteredAds = allAds.where((ad) {
    return ad.title.toLowerCase().contains(_searchQuery) ||
    ad.userId.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredAds.isEmpty) {
    return const Center(child: Text("No matching live ads found."));
    }

    return ListView.builder(
    itemCount: filteredAds.length,
    itemBuilder: (context, index) {
    final ad = filteredAds[index];
    return Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    elevation: 1,
    child: ListTile(
    onTap: () => _showManageOptions(context, ref, ad),
    leading: ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: CachedNetworkImage(
    imageUrl: ad.images.isNotEmpty ? ad.images[0] : '',
    width: 50,
    height: 50,
    fit: BoxFit.cover,
    errorWidget: (ctx, _, __) => const Icon(Icons.image_not_supported),
    ),
    ),
    title: Text(ad.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text("Price: ৳ ${ad.price.toStringAsFixed(0)} • Seller: ${_formatUserRef(ad.userId)}"),
    trailing: IconButton(
    icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
    onPressed: () => _confirmAndExecuteDelete(context, ref, ad),
    ),
    ),
    );
    },
    );
    },
    ),
    ),
    ],
    ),
    );
  }

  String _formatUserRef(String rawId) {
    if (rawId.isEmpty) return "Unknown";
    // Safe extraction length check
    final int length = rawId.length > 6 ? 6 : rawId.length;
    return "UID-${rawId.substring(0, length).toUpperCase()}";
  }

  void _showManageOptions(BuildContext context, WidgetRef ref, AdModel ad) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.blue),
                title: const Text("View Original Listing"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AdDetailsScreen(ad: ad)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("Force Delete Post"),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAndExecuteDelete(context, ref, ad);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmAndExecuteDelete(BuildContext context, WidgetRef ref, AdModel ad) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Administrative Deletion"),
        content: Text("Are you completely sure you want to drop '${ad.title}' off the marketplace platform? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete Post", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(managelivemarketsads.notifier).adminForceDeleteAd(ad.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Post removed successfully" : "Failed to remove post"),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}