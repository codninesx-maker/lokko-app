import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportHubScreen extends StatefulWidget {
  const SupportHubScreen({super.key});

  @override
  State<SupportHubScreen> createState() => _SupportHubScreenState();
}

class _SupportHubScreenState extends State<SupportHubScreen> {
  static const Color lokkoGreen = Color(0xFF1aa332);

  // These are now variable fields inside the mutable State container
  BannerAd? _bottomLargeBannerAd;
  bool _isBannerAdLoaded = false;

  // 🔽 Interstitial (Full Page) Ad Variables 🔽
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;

  @override
  void initState() {
    super.initState();
    // Start loading the ad configuration immediately on screen initialization
    _loadBottomLargeBannerAd();
    _loadInterstitialAd(); // Load the full-page ad immediately in the background
  }

  @override
  void dispose() {
    // CRUCIAL: Always dispose of your ads to prevent system memory leaks!
    _bottomLargeBannerAd?.dispose();
    _interstitialAd?.dispose(); // CRUCIAL: Prevent full-page ad memory leaks!
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

  // 🔽 Load the Interstitial Ad 🔽
  void _loadInterstitialAd() {
    InterstitialAd.load(
      // Test Interstitial Unit ID
      adUnitId: 'ca-app-pub-7494179033430216/3913456746',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;

          // Set up listeners for when the ad is closed or fails
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              Navigator.pop(context); // Finish leaving the screen after the ad closes
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              Navigator.pop(context); // Leave immediately if the ad fails to show
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial Ad failed to load: $error');
          _isInterstitialAdLoaded = false;
        },
      ),
    );
  }

  // 🔽 Helper method to intercept back actions 🔽
  void _handleBackAction() {
    if (_isInterstitialAdLoaded && _interstitialAd != null) {
      _interstitialAd!.show(); // Show full-page ad. The callback handles the pop.
    } else {
      Navigator.pop(context); // Fallback: Exit immediately if ad isn't loaded yet
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap Scaffold in PopScope to intercept the device's system back button/gesture
    return PopScope(
      canPop: false, // Prevent automatic popping so our handler can run
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackAction();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: lokkoGreen,
          foregroundColor: Colors.white,
          title: const Text("Help & Safety Hub", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          // Custom leading back button to handle the ad display
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackAction,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text("Marketplace Guides", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            _guideTile(context, Icons.shopping_cart_checkout, "Buying Guide", "Learn how to buy safely and avoid scams.", const BuyingGuideScreen()),
            _guideTile(context, Icons.sell_outlined, "Selling Guide", "Tips for faster sales and better ads.", const SellingGuideScreen()),

            const SizedBox(height: 30),
            const Text("Policy & Safety", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            _guideTile(context, Icons.gpp_maybe_outlined, "Community Guidelines", "What is allowed and not allowed on Lokko.", const CommunityPolicyScreen()),
            _guideTile(context, Icons.verified_user_outlined, "Safety Standards", "Our commitment to your security.", const SafetyStandardScreen()),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            width: double.infinity,
            height: _isBannerAdLoaded ? 100 : 0,
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
      ),
    );
  }

  Widget _guideTile(BuildContext context, IconData icon, String title, String sub, Widget screen) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: lokkoGreen),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => screen)),
      ),
    );
  }
}

// 4. COMMUNITY POLICY CLASS
// ==========================================
// 1. COMMUNITY POLICY SCREEN (Stateful)
// ==========================================
class CommunityPolicyScreen extends StatefulWidget {
  const CommunityPolicyScreen({super.key});

  @override
  State<CommunityPolicyScreen> createState() => _CommunityPolicyScreenState();
}

class _CommunityPolicyScreenState extends State<CommunityPolicyScreen> {
  BannerAd? _bottomLargeBannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBottomLargeBannerAd();
  }

  @override
  void dispose() {
    _bottomLargeBannerAd?.dispose();
    super.dispose();
  }

  void _loadBottomLargeBannerAd() {
    _bottomLargeBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7494179033430216/3379106871',
      size: AdSize.largeBanner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isBannerAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Community Policy Screen Ad failure: $error');
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Community Guidelines"),
        backgroundColor: const Color(0xFF1aa332),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _policyItem(Icons.block, "Prohibited Items", "Drugs, weapons, stolen goods, and regulated items are strictly banned from Lokko."),
          _policyItem(Icons.person_off, "Harassment", "Respect all users. Hate speech, bullying, or spamming will lead to a permanent ban."),
          _policyItem(Icons.camera_alt_outlined, "Honest Images", "Ads must use real photos of the item. No stock photos or misleading images."),
          _policyItem(Icons.report_problem_outlined, "Reporting", "If you see a suspicious ad, be carefull immediately & do not blame anyone ."),
        ],
      ),
      bottomNavigationBar: _buildAdBanner(),
    );
  }

  Widget _buildAdBanner() {
    return SafeArea(
      child: Container(
        width: double.infinity,
        height: _isBannerAdLoaded ? 100 : 0,
        alignment: Alignment.center,
        child: _isBannerAdLoaded
            ? SizedBox(
          width: _bottomLargeBannerAd!.size.width.toDouble(),
          height: _bottomLargeBannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bottomLargeBannerAd!),
        )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _policyItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.redAccent, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 5),
                Text(desc, style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. SAFETY STANDARD SCREEN (Converted to Stateful)
// ==========================================
class SafetyStandardScreen extends StatefulWidget {
  const SafetyStandardScreen({super.key});

  @override
  State<SafetyStandardScreen> createState() => _SafetyStandardScreenState();
}

class _SafetyStandardScreenState extends State<SafetyStandardScreen> {
  BannerAd? _bottomLargeBannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBottomLargeBannerAd();
  }

  @override
  void dispose() {
    _bottomLargeBannerAd?.dispose();
    super.dispose();
  }

  void _loadBottomLargeBannerAd() {
    _bottomLargeBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7494179033430216/3379106871',
      size: AdSize.largeBanner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isBannerAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Safety Standards Screen Ad failure: $error');
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Safety Standards"),
        backgroundColor: const Color(0xFF1aa332),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text("Our Privacy Commitment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("At Lokko, we prioritize your data security. We use encrypted storage for your personal information and never share your phone number without your permission."),
          Divider(height: 40),
          Text("Transaction Safety", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("We could not monitor ads for suspicious activity . While we facilitate the connection, we encourage users to always follow the Buying Guide steps found in the Hub."),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          width: double.infinity,
          height: _isBannerAdLoaded ? 100 : 0,
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
}

// ==========================================
// 3. BUYING GUIDE SCREEN (Converted to Stateful)
// ==========================================
class BuyingGuideScreen extends StatefulWidget {
  const BuyingGuideScreen({super.key});

  @override
  State<BuyingGuideScreen> createState() => _BuyingGuideScreenState();
}

class _BuyingGuideScreenState extends State<BuyingGuideScreen> {
  BannerAd? _bottomLargeBannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBottomLargeBannerAd();
  }

  @override
  void dispose() {
    _bottomLargeBannerAd?.dispose();
    super.dispose();
  }

  void _loadBottomLargeBannerAd() {
    _bottomLargeBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7494179033430216/3379106871',
      size: AdSize.largeBanner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isBannerAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Buying Guide Screen Ad failure: $error');
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("How to Buy Safely"),
        backgroundColor: const Color(0xFF1aa332),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _guideStep("1", "Check the Ad", "Look for clear photos and a realistic price. If it's too good to be true, be careful."),
          _guideStep("2", "Public Meetups", "Always meet sellers in crowded public places like markets or malls."),
          _guideStep("3", "Inspect First", "Never pay before checking the item. For electronics, test the battery and functions."),
          _guideStep("4", "Direct Payment", "Pay only after receiving the item. Use bKash/Nagad or Cash on delivery."),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          width: double.infinity,
          height: _isBannerAdLoaded ? 100 : 0,
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

  Widget _guideStep(String num, String title, String desc) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.black, radius: 12, child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 10))),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc),
    );
  }
}

// ==========================================
// 4. SELLING GUIDE SCREEN (Converted to Stateful)
// ==========================================
class SellingGuideScreen extends StatefulWidget {
  const SellingGuideScreen({super.key});

  @override
  State<SellingGuideScreen> createState() => _SellingGuideScreenState();
}

class _SellingGuideScreenState extends State<SellingGuideScreen> {
  BannerAd? _bottomLargeBannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBottomLargeBannerAd();
  }

  @override
  void dispose() {
    _bottomLargeBannerAd?.dispose();
    super.dispose();
  }

  void _loadBottomLargeBannerAd() {
    _bottomLargeBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7494179033430216/3379106871',
      size: AdSize.largeBanner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isBannerAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Selling Guide Screen Ad failure: $error');
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Selling Guide"),
        backgroundColor: const Color(0xFF1aa332),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _guideStep("1", "Great Photos", "Take bright, clear photos. Buyers trust listings with multiple real images."),
          _guideStep("2", "Honest Details", "Describe any scratches or issues. This builds trust with your buyer."),
          _guideStep("3", "Quick Replies", "Sellers who reply fast close deals faster. Keep your notifications on!"),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          width: double.infinity,
          height: _isBannerAdLoaded ? 100 : 0,
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

  Widget _guideStep(String num, String title, String desc) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.black, radius: 12, child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 10))),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc),
    );
  }
}