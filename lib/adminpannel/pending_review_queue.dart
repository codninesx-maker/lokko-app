import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:lokko_market/screen/bottombar/ad_details_screen.dart';
import '../screen/bottombar/profile/onetoseven/edit_ad_screen.dart';
import 'admin_pannel.dart';
import 'admin_review_provider.dart';

class PendingReviewQueue extends ConsumerWidget {
  const PendingReviewQueue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAds = ref.watch(adminReviewProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: klokkoGreen,
        elevation: 0,
        title: const Text(
          "Pending Review Queue",
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: pendingAds.when(
        loading: () =>
        const Center(child: CircularProgressIndicator(color: klokkoGreen)),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (ads) {
          if (ads.isEmpty) {
            return const Center(child: Text("No ads pending verification."));
          }

          return ListView.builder(
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final ad = ads[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  onTap: () => _showAdminOptions(context, ref, ad),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: ad.images.isNotEmpty ? ad.images[0] : '',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                      const Icon(Icons.image),
                    ),
                  ),
                  title: Text(
                      ad.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      "৳ ${ad.price.toStringAsFixed(0)} • ${ad.districtName}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                            Icons.check_circle, color: Colors.green),
                        onPressed: () =>
                            _handleAction(context, ref, ad.id, 'active'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () =>
                            ref
                                .read(adminReviewProvider.notifier)
                                .updateAdStatus(ad.id, 'rejected'),
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

  void _showAdminOptions(BuildContext context, WidgetRef ref, AdModel ad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Admin Actions", style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.visibility, color: Colors.blue),
                  title: const Text("View Details & Confirm"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) => AdDetailsScreen(ad: ad)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.orange),
                  title: const Text("Minor Correction & Verify"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditAdScreen(ad: ad.toMap(), isAdmin: true),
                      ),
                    ).then((result) {
                      if (result == true) {
                        ref.invalidate(adminReviewProvider);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String adId, String status) async {
    final success = await ref.read(adminReviewProvider.notifier).updateAdStatus(adId, status);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Ad ${status.toUpperCase()} successfully!" : "Error: Check DB Constraints"),
          backgroundColor: success
              ? (status == 'active' ? Colors.green : Colors.red)
              : Colors.black,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}