import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lokko_market/screen/bottombar/profile/onetoseven/help_privacy_whatsapp_email.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const Color lokkoGreen = Color(0xFF1aa332);

  // These are now variable fields inside the mutable State container
  BannerAd? _bottomLargeBannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    // Start loading the ad configuration immediately on screen initialization
    _loadBottomLargeBannerAd();
  }

  @override
  void dispose() {
    // CRUCIAL: Always dispose of your ads to prevent system memory leaks!
    _bottomLargeBannerAd?.dispose();
    super.dispose();
  }

  void _loadBottomLargeBannerAd() {
    _bottomLargeBannerAd = BannerAd(
      // Test Banner Unit ID
      adUnitId: 'ca-app-pub-7494179033430216/3379106871',
      size: AdSize.largeBanner, // 320x100 Large Banner layout
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Bottom Large Banner Ad lifecycle failure: $error');
        },
      ),
    )..load();
  }

  Future<void> _openWhatsApp() async {
    const String supportPhone = "8801778073934";

    // 1. Grab base authentication data
    final currentUser = Supabase.instance.client.auth.currentUser;

    // 2. Safely initialize default fallback information strings
    String accountDetailsBlock = "User Status: Guest Session";

    if (currentUser != null) {
      // A. Generate a clean visual Reference hash string
      final String shortId = currentUser.id.length > 6
          ? currentUser.id.substring(0, 6).toUpperCase()
          : currentUser.id;

      // B. PULL FROM LOCAL PROFILE CACHE/STATE (matching your database snapshot logs)
      // NOTE: Swap these strings out with your real riverpod profile state references if needed!
      const String profileName = "Sur plaza";    // e.g., userProfileProvider.value.fullName
      const String profilePhone = "01778073934";  // e.g., userProfileProvider.value.phone

      accountDetailsBlock = "Name: $profileName\n"
          "Phone: $profilePhone\n"
          "Ref Tag: LK-$shortId";
    }

    // 3. Construct a beautiful, easy-to-read workspace ticket message layout
    final String rawMessage = "Hello Lokko Support!\n\n"
        "I need assistance with my marketplace account.\n\n"
        "--- Account Details ---\n"
        "$accountDetailsBlock";

    final String encodedMessage = Uri.encodeComponent(rawMessage);

    // 4. Formulate the explicit deep linking application strings
    final Uri appUri = Uri.parse("whatsapp://send?phone=$supportPhone&text=$encodedMessage");
    final Uri webUri = Uri.parse("https://wa.me/$supportPhone?text=$encodedMessage");

    // 5. Fire off intent safely
    try {
      final bool launched = await launchUrl(appUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendEmail() async {
    // 1. Get the current authenticated user
    final user = Supabase.instance.client.auth.currentUser;

    // 2. Extract profile details (Fallback to 'Guest' if not logged in)
    // Note: Replace these hardcoded placeholders with your real riverpod state
    // or profile provider references if you aren't doing it globally yet.
    String senderName = "Guest User";
    String senderPhone = "Not Provided";

    if (user != null) {
      senderName = "Sur plaza";    // e.g., ref.read(profileProvider).fullName
      senderPhone = "01778073934"; // e.g., ref.read(profileProvider).phone
    }

    // 3. Build a structured email body layout
    final String emailBody =
        "--- Account Details ---\n"
        "Sender Name: $senderName\n"
        "Phone Number: $senderPhone\n"
        "User ID: ${user?.id ?? "Guest"}\n"
        "------------------------\n\n"
        "Describe your issue here: ";

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'codninesx@lokko.com',
      query: _encodeQueryParameters(<String, String>{
        'subject': 'Support Request: Lokko Market',
        'body': emailBody,
      }),
    );

    try {
      // Note: Using launchUrl directly is safer on newer Android versions
      // than relying purely on canLaunchUrl checks.
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error launching email client: $e");
    }
  }

// Helper to handle special characters in the email body/subject
  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
    '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: lokkoGreen,
        foregroundColor: Colors.white,
        title: const Text("Help & Support", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("How can we help?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 15),

          // 1. FAQ / Help Center Card
          _buildSupportCard(
            context,
            Icons.help_center_outlined,
            "Help Center",
            "Guides for buying and selling on Lokko.",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SupportHubScreen(),
                ),
              );
            },
          ),

          // 2. Privacy Policy Card
          _buildSupportCard(
            context,
            Icons.policy_outlined,
            "Privacy Policy",
            "How Lokko handles your data.",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SafetyStandardScreen(),
                ),
              );
            },
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),

          const Text("Direct Contact",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          // 3. Contact Row
          // 3. Contact Row
          Row(
            children: [
              Expanded(
                child: _contactCard(
                  context,
                  Icons.chat_bubble_outline,
                  "WhatsApp",
                  Colors.green,
                      () => _openWhatsApp(), // Logic already handles app vs web fallback
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _contactCard(
                  context,
                  Icons.mail_outline,
                  "Email Us",
                  Colors.blue,
                      () => _sendEmail(), // Logic handles user ID and mailto scheme
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          width: double.infinity,
          height: _isBannerAdLoaded ? 100 : 0, // Collapses cleanly if the ad fails to load
          alignment: Alignment.center,
          child: _isBannerAdLoaded
              ? SizedBox(
            width: _bottomLargeBannerAd!.size.width.toDouble(),
            height: _bottomLargeBannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bottomLargeBannerAd!),
          )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  // --- Keep all your existing _buildSupportCard, showPrivacyPolicy, etc. below this ---
  Widget _buildSupportCard(BuildContext context, IconData icon, String title, String sub, {VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey[100]!),
          borderRadius: BorderRadius.circular(15)
      ),
      child: ListTile(
        onTap: onTap ?? () {},
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: lokkoGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: lokkoGreen),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      ),
    );
  }

  void showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  const Text("Privacy Policy", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1aa332))),
                  const SizedBox(height: 8),
                  Text("Last updated: February 2026", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const Divider(height: 40),

                  _policySection("1. Data Collection",
                      "We collect information you provide directly to us when you create an account, post an ad, or communicate with other users. This includes your name, email address, phone number, and any photos you upload to Lokko."),

                  _policySection("2. How We Use Data",
                      "Your data is used to provide and improve our marketplace services, facilitate transactions, verify user accounts to prevent fraud, and send you relevant notifications regarding your ads."),

                  _policySection("3. Data Storage (Supabase)",
                      "Lokko uses Supabase for secure data storage and authentication. Your data is protected using industry-standard encryption. We do not sell your personal information to third parties."),

                  _policySection("4. Location Services",
                      "When you post an ad, we collect location data to help buyers find items near them. You can manage location permissions in your device settings."),

                  _policySection("5. Contact Us",
                      "If you have questions about this policy or wish to request data deletion, please contact us at support@lokko.com."),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1aa332),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("I Understand", style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _policySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(content, style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5)),
        ],
      ),
    );
  }

  void showLokkoHelpCenter(BuildContext context) {
    const Color lokkoGreen = Color(0xFF1aa332);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("How can we help?",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // --- Quick FAQ Section ---
            _buildHelpTile(Icons.shopping_bag_outlined, "How to Buy", "Learn how to contact sellers safely."),

            _buildHelpTile(Icons.sell_outlined, "Selling Guide", "Tips to get your ads noticed quickly."),

            _buildHelpTile(Icons.gpp_maybe_outlined, "Safety Tips", "Avoid scams and stay safe in the marketplace."),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(),
            ),

            const Text("Direct Support",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // --- Contact Actions ---
            Row(
              children: [
                Expanded(
                  child: _contactCard(
                    context,
                    Icons.chat_bubble_outline,
                    "WhatsApp",
                    lokkoGreen,
                        () => _openWhatsApp(), // Now it's functional!
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _contactCard(
                    context,
                    Icons.mail_outline,
                    "Email Us",
                    Colors.blue,
                        () => _sendEmail(), // Triggers the mail app
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpTile(IconData icon, String title, String sub) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[100],
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () { /* Navigate to specific FAQ detail */ },
    );
  }

  Widget _contactCard(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}