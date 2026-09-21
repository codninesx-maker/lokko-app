import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lokko_market/adminpannel/admin_pannel.dart';
import 'package:lokko_market/externalads/lokko_test_banner.dart';
import 'package:lokko_market/login/login_screen.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart';
import 'package:lokko_market/screen/bottombar/profile/custom_image.dart';
import 'package:lokko_market/screen/bottombar/profile/edit_profile_screen.dart';
import 'package:lokko_market/screen/bottombar/profile/onetoseven/faq_screen.dart';
import 'package:lokko_market/screen/bottombar/profile/onetoseven/settings_screen.dart';
import 'package:lokko_market/screen/bottombar/profile/profile_provider.dart';
import 'package:lokko_market/screen/bottombar/profile/onetoseven/help_and_support_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onetoseven/aboutlokko.dart';
import 'onetoseven/favorites_screen.dart';
import 'onetoseven/my_ads_screen.dart';
import 'onetoseven/notifications_screen.dart';


class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final currentUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("My Account",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1aa332), // LOKKO Green
        elevation: 0,
        centerTitle: false, // Bikroy usually aligns left or center depending on version
      ),
      body: currentUser == null
          ? _buildGuestUI(context)
          : profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1aa332))),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (profileData) => _buildProfileContent(context, ref, profileData, currentUser),
      ),
    );
  }

  // --- 1. GUEST UI ---
  Widget _buildGuestUI(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.account_circle, size: 100, color: Colors.grey),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            "Log in to manage your ads and keep track of your activity",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1aa332),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
              child: const Text("Login / Sign up", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  // --- 2. LOGGED IN UI (Bikroy Design) ---
  Widget _buildProfileContent(BuildContext context, WidgetRef ref, Map<String, dynamic>? profileData, User user) {
    debugPrint("LOKKO_DATABASE_SNAPSHOT: $profileData");

    final String displayName = profileData?['full_name'] ?? "LOKKO User";
    final String? rawAvatarUrl = profileData?['avatar_url'];
    final String email = user.email ?? "";

    final String? rawPublicId = profileData?['avatar_public_id'];
    final String? rawUrl = profileData?['avatar_url'];

// 2. Use the Public ID to generate the Cloudinary link
    final String? resolvedAvatar = (rawPublicId != null && rawPublicId.isNotEmpty)
        ? CloudinaryHelper.getProfileAvatar(rawPublicId) // Use the Public ID
        : (rawUrl != null && rawUrl.isNotEmpty ? rawUrl : null); // Fallback to URL or null

    debugPrint("LOKKO_FINAL_URL: $resolvedAvatar");

    return RefreshIndicator(
      onRefresh: () async {
        // This invalidates the provider so it fetches the fresh avatar_url from Supabase
        ref.invalidate(userProfileProvider);
        // Wait for the new data to load
        await ref.read(userProfileProvider.future);
      },
      color: const Color(0xFF1aa332),
      child: SingleChildScrollView(
        // physics is REQUIRED for RefreshIndicator to work on short screens
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Header Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 🔽 UPDATED: Wrapped avatar in an interactive detector 🔽
                  GestureDetector(
                    onTap: () {
                      if (resolvedAvatar != null && resolvedAvatar.isNotEmpty) {
                        _openFullScreenAvatar(context, resolvedAvatar, displayName);
                      }
                    },
                    child: LokkoImage(
                      key: ValueKey(resolvedAvatar ?? 'no-image'),
                      imageUrl: resolvedAvatar,
                      size: 60,
                      fallbackIcon: Icons.person,
                    ),
                  ),
                  // 🔼 END OF AVATAR UPDATE 🔼
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  ),
                  // Added: Quick link to Edit Profile for testing
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                    ),
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF1aa332)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Menu Items
            _buildMenuSection([
              _buildMenuItem(
                Icons.list_alt,
                "My ads",
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyAdsScreen())),
              ),
              _buildMenuItem(
                Icons.star_border,
                "Favorites",
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesScreen())),
              ),
              _buildMenuItem(
                Icons.notifications_none,
                "Notifications",
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
              ),
            ]),
            const SizedBox(height: 10),

            _buildMenuSection([
              _buildMenuItem(
                Icons.settings_outlined,
                "Settings",
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
              ),
              _buildMenuItem(
                Icons.help_outline,
                "Help & Support",
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportScreen())),
              ),
              _buildMenuItem(
                Icons.question_answer_outlined,
                "FAQ",
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FAQScreen())),
              ),
              _buildMenuItem(
                Icons.info_outline,
                "About LOKKO",
                    () => showAboutLokkoSheet(context),
              ),
              if (user.email == 'codninesx@gmail.com')
                _buildMenuItem(
                  Icons.admin_panel_settings,
                  "Admin Panel",
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminPannel()),
                  ),
                  iconColor: Colors.deepPurple,
                ),
            ]),
            // 🔽 AD PLACEMENT INJECTED DIRECTLY AT THE VERY BOTTOM 🔽
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: RepaintBoundary(
                child: Container(
                  width: double.infinity,
                  height: 100, // Perfectly fits AdSize.largeBanner height parameters
                  alignment: Alignment.center,
                  color: Colors.transparent, // Keeps the layout background smooth & frameless
                  child: const SizedBox(
                    width: double.infinity,
                    child: LokkoTestBanner(
                      adSize: AdSize.largeBanner, // Explicitly requests the dynamic large canvas display
                    ),
                  ),
                ),
              ),
            ),
            // 🔼 END OF AD PLACEMENT 🔼

            const Text("Version 7.0.0", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _openFullScreenAvatar(BuildContext context, String avatarUrl, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(name, style: const TextStyle(fontSize: 16, color: Colors.white)),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              minScale: 1.0,
              maxScale: 4.0,
              panEnabled: true,
              scaleEnabled: true,
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.fitWidth,
                width: MediaQuery.of(context).size.width,
                // Keeps device memory optimized
                memCacheWidth: 800,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white24, size: 40),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widgets
  Widget _buildMenuSection(List<Widget> children) {
    return Container(
      color: Colors.white,
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(
      IconData icon,
      String title,
      VoidCallback onTap, {
        bool isDestructive = false,
        Color? iconColor, // <--- ADD THIS PARAMETER
      }) {
    return ListTile(
      leading: Icon(
        icon,
        // Logic: If it's destructive (Logout/Delete), it's Red.
        // Otherwise, use the custom iconColor if provided, else default to black.
        color: isDestructive ? Colors.red : (iconColor ?? Colors.black87),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: isDestructive ? Colors.red : Colors.black87,
          // Optional: Make the Admin text bold if iconColor is provided
          fontWeight: iconColor != null ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isDestructive
          ? null
          : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}