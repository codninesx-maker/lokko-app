import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lokko_market/externalads/ad_helper.dart';

class LokkoNativeAd extends StatefulWidget {
  const LokkoNativeAd({super.key});

  @override
  State<LokkoNativeAd> createState() => _LokkoNativeAdState();
}

class _LokkoNativeAdState extends State<LokkoNativeAd> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      // Default AdMob template style layout
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 10.0,
      ),
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('LOKKO_NATIVE_AD: Native Ad loaded successfully.');
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, LoadAdError error) {
          debugPrint('LOKKO_NATIVE_AD_ERR: Native Ad failed to load. Code: ${error.code} | Message: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() => _isLoaded = false);
          }
        },
      ),
    );

    _nativeAd!.load();
  }

  @override
  void dispose() {
    // Safely dispose of the native controller to prevent memory leaks
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 320,
          minHeight: 320,
          maxWidth: 400,
          maxHeight: 400,
        ),
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}