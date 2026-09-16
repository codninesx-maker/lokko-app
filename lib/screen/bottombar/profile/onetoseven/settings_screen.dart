import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lokko_market/externalads/lokko_test_banner.dart';
import 'package:lokko_market/main.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart';
import 'package:lokko_market/screen/bottombar/profile/edit_profile_screen.dart';
import 'package:lokko_market/screen/bottombar/profile/onetoseven/notification_settings_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'help_and_support_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmPermanentDeletion(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permanent Deletion"),
        content: const Text("All your ads, messages, and profile data will be permanently erased. This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete Everything", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Fetch ALL ad images belonging to this user BEFORE deleting rows
        final List<dynamic> adsResponse = await supabase
            .from('ads')
            .select('images')
            .eq('user_id', userId); // Make sure 'user_id' matches your schema column name

        List<String> imagesToPurge = [];

        for (var row in adsResponse) {
          if (row['images'] != null) {
            final List imagesList = row['images'] as List;
            for (var img in imagesList) {
              String imageStr = img.toString();

              // Extract public_id exactly like the force delete function
              if (imageStr.contains('image/upload/')) {
                imageStr = imageStr.split('image/upload/').last;
                imageStr = imageStr.replaceAll(RegExp(r'v\d+/'), '');
                if (imageStr.contains('.')) {
                  imageStr = imageStr.split('.').first;
                }
              }
              if (imageStr.isNotEmpty) {
                imagesToPurge.add(imageStr);
              }
            }
          }
        }

        // 2. Fetch the profile avatar if they have one stored in Cloudinary
        // (Optional, uncomment if you store user avatar fields in a profiles table)
        /*
      final profileResponse = await supabase
          .from('profiles')
          .select('avatar_url')
          .eq('id', userId)
          .maybeSingle();
      if (profileResponse != null && profileResponse['avatar_url'] != null) {
         String avatarStr = profileResponse['avatar_url'].toString();
         // Parse out clean public_id out of avatarStr here if needed...
         // imagesToPurge.add(avatarStr);
      }
      */

        // 3. Call the consolidated database function to wipe SQL data
        await supabase.rpc('delete_user_entire_account');

        // 4. Trigger background cleanup for Cloudinary asynchronously
        if (imagesToPurge.isNotEmpty) {
          for (var id in imagesToPurge) {
            CloudinaryHelper.deleteOldImage(id).catchError((e) {
              debugPrint("LOKKO_ACCOUNT_PURGE_CLOUD_FAIL: $id -> $e");
            });
          }
          debugPrint("LOKKO_ACCOUNT_PURGE: Cleaned up ${imagesToPurge.length} assets.");
        }

        // 5. Clear local session token storage
        await supabase.auth.signOut();

        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AuthGate()),
                (route) => false,
          );
        }
      } on PostgrestException catch (e) {
        debugPrint("LOKKO_POSTGREST_ERROR: ${e.message} (Details: ${e.details})");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Database Error: ${e.message}"), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        debugPrint("LOKKO_DELETE_ERROR: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting data: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), centerTitle: true),
      body: ListView(
        children: [
          _sectionTitle("Account"),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Edit Profile"),
            subtitle: Text(user?.userMetadata?['full_name'] ?? "Add your name"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
            },
          ),

          const Divider(),
          _sectionTitle("Preferences"),
          Consumer(
            builder: (context, ref, child) {
              // 1. Listen to the provider state
              final isEnabled = ref.watch(notificationSettingsProvider);

              return SwitchListTile(
                secondary: Icon(
                  isEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                  color: isEnabled ? const Color(0xFF1aa332) : Colors.grey,
                ),
                title: const Text(
                  "Push Notifications",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  isEnabled ? "Enabled" : "Disabled",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                value: isEnabled,
                // 2. Call the toggle function when clicked
                onChanged: (val) {
                  ref.read(notificationSettingsProvider.notifier).toggleNotification(val);

                  // Optional: Feedback for the user
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val ? "Notifications turned on" : "Notifications silenced"),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                activeColor: const Color(0xFF1aa332), // Lokko Brand Green
              );
            },
          ),

          const Divider(),
          _sectionTitle("Support"),

          const SizedBox(height: 20),
          ListTile(

            onLongPress: () => _showAccountOptions(context),
          ),
          // 🔽 INJECTED: Large Bottom Ad Banner Placement 🔽
          const Divider(height: 1, color: Color(0xFFE0E0E0)), // Upper divider separator boundary line
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 8, bottom: 12), // Structural safety clearance padding
            child: SafeArea(
              top: false,
              child: RepaintBoundary(
                child: Container(
                  width: double.infinity,
                  height: 100, // Explicitly sized layout frame to contain a large banner structure safely
                  alignment: Alignment.center,
                  color: Colors.transparent,
                  child: const SizedBox(
                    width: double.infinity,
                    child: LokkoTestBanner(
                      adSize: AdSize.largeBanner, // 👈 PASSING THE LARGE BANNER CONFIGURATION MATCHING THE AD DETAILS SCREEN
                    ),
                  ),
                ),
              ),
            ),
          ),
// 🔼 END OF BOTTOM AD PLACEMENT 🔼
        ],
      ),
    );
  }

  void _showAccountOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Account Settings",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("What would you like to do with your Lokko account?"),
        actions: [
          // 1. Cancel Action
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),

          // 2. Logout Action (Safe)
          TextButton(
            onPressed: () async {
              try {
                // Attempt sign out (don't worry if it fails)
                await Supabase.instance.client.auth.signOut();
              } catch (e) {
                debugPrint("Sign out error (ignoring): $e");
              } finally {
                // This runs EVEN IF the token is expired/invalid
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    PageRouteBuilder(
                      // Go back to AuthGate to re-evaluate session
                      pageBuilder: (context, a1, a2) => const AuthGate(),
                      // CRITICAL: No animation to prevent TECNO GPU crash
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                        (route) => false,
                  );
                }
              }
            },
            child: const Text(
              "Log Out",
              style: TextStyle(color: Color(0xFF1aa332), fontWeight: FontWeight.bold),
            ),
          ),

          // 3. Delete Action (Destructive)
          TextButton(
            onPressed: () => _confirmPermanentDeletion(context),
            child: const Text("Delete Account",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}