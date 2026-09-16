import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Added for AdMob Integration

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  // Banner Ad Configuration Instance Variables
  BannerAd? _bottomLargeBannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    // Instantly starts fetching the ad layout on screen arrival
    _loadBottomLargeBannerAd();
  }

  @override
  void dispose() {
    _bottomLargeBannerAd?.dispose(); // Clean up graphics and memory leaks
    super.dispose();
  }

  void _loadBottomLargeBannerAd() {
    _bottomLargeBannerAd = BannerAd(
      // Standard AdMob Test Banner ID. Swap to your production ID when building live release bundles.
      adUnitId: 'ca-app-pub-7494179033430216/3379106871',
      size: AdSize.largeBanner, // 320x100 Frame size matching your other screens
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
          debugPrint('FAQ Bottom Large Banner Ad lifecycle failure: $error');
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("FAQ", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1aa332), // LOKKO Green
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Wrapped logic inside a Column structure to secure a flat bottom layout zone
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  _FAQItem(
                    question: "How do I post an ad?",
                    answer: "Click on the 'Post Ad' button at the bottom of the home screen, select your category, select your location, add photos, and provide a clear description to start selling.",
                  ),
                  _FAQItem(
                    question: "Is LOKKO free to use?",
                    answer: "Yes, LOKKO is completely free for general users. You can post ads in most categories without any cost.",
                  ),
                  _FAQItem(
                    question: "How long will my ad stay online?",
                    answer: "Ads usually stay active for 30 to 60 days. You will receive a notification before your ad expires so you can renew it if the item hasn't sold yet.",
                  ),
                  _FAQItem(
                    question: "Why was my ad rejected?",
                    answer: "Ads may be rejected if they contain prohibited items, duplicate content, or incorrect contact information. Please check our posting rules in the 'About LOKKO' section.",
                  ),
                  _FAQItem(
                    question: "How do I stay safe while buying?",
                    answer: "Always meet sellers in a public place, inspect the item thoroughly before paying, and avoid making advance payments through mobile banking for items you haven't seen.",
                  ),
                  _FAQItem(
                    question: "Can I edit my ad after posting?",
                    answer: "Yes! Go to 'My Ads' in your profile, select the ad you want to change, and click the edit icon to update the price, photos, or description.",
                  ),
                  _FAQItem(
                    question: "How can I sell my items faster?",
                    answer: "Use high-quality photos, set a competitive price, and provide a detailed description. Using a verified profile also helps build trust with buyers.",
                  ),
                  _FAQItem(
                    question: "I forgot my password. How do I recover it?",
                    answer: "To create account, simply register your email on the Signup screen. You will receive a one-time code (OTP) to log in instantly—no password required.",
                  ),
                ],
              ),
            ),
            // Fixed bottom slot logic for your large ad block
            _buildPersistentBottomAd(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersistentBottomAd() {
    if (_isBannerAdLoaded && _bottomLargeBannerAd != null) {
      return Container(
        color: Colors.white,
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        height: 112, // 100px ad frame height + 12px padding buffer
        child: SizedBox(
          width: 320, // Strict structural width block mapping to AdSize.largeBanner
          height: 100,
          child: AdWidget(ad: _bottomLargeBannerAd!),
        ),
      );
    }
    return const SizedBox.shrink(); // Stays completely invisible until data loads
  }
}

class _FAQItem extends StatelessWidget {
  final String question, answer;
  const _FAQItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(answer),
        )
      ],
    );
  }
}