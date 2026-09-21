import 'package:flutter/material.dart';

void showAboutLokkoSheet(BuildContext context) {
  const Color lokkoGreen = Color(0xFF1aa332); // Your Brand Color

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)), // Softer, modern curve
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 12.0, // Tighter top for the handle
          bottom: MediaQuery.of(context).padding.bottom + 24.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pull Handle
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 30),

            // Logo Branding - Focused on the LOKKO identity
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: lokkoGreen.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
                Image.asset(
                  'assets/logo.png',
                  width: 70,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.shopping_bag_rounded, size: 50, color: lokkoGreen),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              "LOKKO",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900, // Extra bold for brand impact
                letterSpacing: 2.0,
                color: Colors.black,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: lokkoGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "v7.0.0",
                style: TextStyle(color: lokkoGreen, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 25),

            // Purposeful Brand Mission
            const Text(
              "Trade Local. Trade Easy.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              "Lokko is more than just a marketplace. It’s a community-driven platform built to make local buying and selling as simple as a handshake.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  height: 1.5,
                  fontSize: 15,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w400
              ),
            ),

            const SizedBox(height: 30),

            // Brand Action Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: lokkoGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text(
                    "Keep Exploring",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Social/Web Link (Makes it feel real)
            Text(
              "www.lokkomarket.com",
              style: TextStyle(fontSize: 14, color: lokkoGreen.withOpacity(0.7), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              "© 2026 Lokko Marketplace • Rajshahi, BD",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      );
    },
  );
}