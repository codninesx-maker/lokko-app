import 'package:flutter/material.dart';
import 'package:lokko_market/adminpannel/manage_live_ads_screen.dart';
import 'package:lokko_market/adminpannel/pending_review_queue.dart';


const Color klokkoGreen = Color(0xFF1aa332);

/// 1. MAIN NAVIGATION HUB (AdminPannel) - Converted to StatefulWidget
///
class AdminPannel extends StatefulWidget {
  const AdminPannel({super.key});

  @override
  State<AdminPannel> createState() => _AdminPannelState();
}

class _AdminPannelState extends State<AdminPannel> {
  // Track the triple-tap sequence right here inside the mutable State block
  int _manageAdsTapCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: klokkoGreen,
        elevation: 0,
        title: const Text(
          "Admin Pannel",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              "Moderation Panels",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),

          /// BUTTON 1: PENDING VERIFICATION QUEUE
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.rate_review_outlined, color: Colors.orange),
              ),
              title: const Text("Pending Review Queue", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Approve, modify, or reject new ad entries"),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PendingReviewQueue()),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          /// BUTTON 2: LIVE MARKETPLACE MANAGEMENT
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              ),
              title: const Text("Manage Live Ads", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Search filter and drop active listings off DB"),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                setState(() {
                  _manageAdsTapCount++;
                });

                if (_manageAdsTapCount >= 3) {
                  // Reset the counter so it requires 3 taps again next time
                  _manageAdsTapCount = 0;

                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageLiveAdsScreen()),
                  );
                } else {
                  // Optional: Show a subtle toast or debug message letting you know it registered
                  debugPrint("Tap registered: $_manageAdsTapCount/3");
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
