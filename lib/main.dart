import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:lokko_market/screen/bottombar/ad_details_screen.dart';
import 'package:lokko_market/screen/dashboard_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' show Client;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Hardware Compatibility
  PaintingBinding.instance.imageCache.maximumSize = 50;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;

  // 2. Initialize Services
  await Future.wait([
    if (Platform.isAndroid || Platform.isIOS) _initAdMobSecurely(),
    Supabase.initialize(
      url: 'https://qemnvggvsleaayfkesdy.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFlbW52Z2d2c2xlYWF5Zmtlc2R5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwOTc3MTIsImV4cCI6MjA4NjY3MzcxMn0.Qj6h_h9xUIj2-Ex8Xf72kkIfXQw94367CZxeKlarXGw', // (Your key here)
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
      httpClient: Client(),
    ),
  ]);

  // 3. Launch App
  runApp(const ProviderScope(child: LokkoApp()));

  // 4. Initialize Deep Linking
  final _appLinks = AppLinks();

  // Call the setup after defining the function below
  setupDeepLinkListener(_appLinks);
}

// Define these functions OUTSIDE of main() so they are accessible
Future<void> setupDeepLinkListener(AppLinks appLinks) async {
  final initialUri = await appLinks.getInitialLink();
  if (initialUri != null) {
    handleNavigation(initialUri);
  }

  appLinks.uriLinkStream.listen((uri) {
    handleNavigation(uri);
  });
}

Future<void> handleNavigation(Uri uri) async {
  if (uri.path.contains('/ad/')) {
    final adId = uri.pathSegments.last;

    try {
      final response = await Supabase.instance.client
          .from('ads')
          .select('*, categories(name), districts!ads_district_id_fkey(name)')
          .eq('id', adId)
          .single();

      final ad = AdModel.fromJson(response);

      // Small delay to ensure the Navigator is ready
      await Future.delayed(const Duration(milliseconds: 500));

      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => AdDetailsScreen(ad: ad)),
      );
    } catch (e) {
      debugPrint("Deep link navigation failed: $e");
    }
  }
}

// 🟩 CHANGED: Modified to return a Future<InitializationStatus> to guarantee focus completion
Future<InitializationStatus> _initAdMobSecurely() async {
  debugPrint("LOKKO_ADS: Starting Google Mobile Ads SDK initialization stream...");

  final RequestConfiguration configuration = RequestConfiguration(
    testDeviceIds: <String>["EA5D6F9C4A4BBF322F9AA51CD871EAA0"],
  );

  // Inject configuration parameters
  await MobileAds.instance.updateRequestConfiguration(configuration);

  // Initialize the engine core and return its completion handle
  return await MobileAds.instance.initialize();
}

class LokkoApp extends StatelessWidget {
  const LokkoApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'LOKKO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1aa332), // Lokko Green
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final bool isAdminUser = user?.email == 'codninesx@gmail.com';

    return SafeArea(
      top: false,
      bottom: true,
      child: DashboardView(isAdmin: isAdminUser),
    );
  }
}