import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class LokkoTestBanner extends StatefulWidget {
  final AdSize adSize;
  const LokkoTestBanner({super.key, this.adSize = AdSize.banner});

  @override
  State<LokkoTestBanner> createState() => _LokkoTestBannerState();
}

// 1. Add AutomaticKeepAliveClientMixin to stop ScrollView from killing the ad state
class _LokkoTestBannerState extends State<LokkoTestBanner> with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  final String _testUnitId = 'ca-app-pub-7494179033430216/3379106871';

  @override
  // 2. This enforces that the framework keeps the loaded ad alive while scrolling
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeYourServices();
    });
  }

  @override
  void dispose() {
    debugPrint("LOKKO_UI_ADS: Widget is being DISPOSED!");
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadAd() {
    // 3. Absolute Guard: Do not request an ad if the user already backed out of the page
    if (!mounted) return;

    debugPrint("LOKKO_UI_ADS: Requesting test banner layout from server...");

    _bannerAd = BannerAd(
      adUnitId: _testUnitId,
      // 4. Use widget.adSize instead of forcing AdSize.banner to match your details page's 100dp height container (AdSize.largeBanner)
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint("LOKKO_UI_ADS: SUCCESS! Ad layout successfully established.");
          // 5. Always guard setState with a mounted check for asynchronous network responses
          if (!mounted) return;
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint("LOKKO_UI_ADS: FAIL! Ad failed to render layout: $error");
          debugPrint("LOKKO_UI_ADS_ERROR: Code ${error.code} | Message: ${error.message}");
          ad.dispose();

          if (!mounted) return;
          setState(() {
            _isLoaded = false;
          });
        },
      ),
    );

    _bannerAd!.load();
  }

  Future<void> _initializeYourServices() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _loadAd();
  }

  @override
  Widget build(BuildContext context) {
    // 6. REQUIRED by the AutomaticKeepAliveClientMixin contract to preserve layout state
    super.build(context);

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}