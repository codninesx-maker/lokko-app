import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lokko_market/model/ad_model.dart';
import 'package:lokko_market/screen/bottombar/ad_details_screen.dart';
import 'package:lokko_market/screen/dashboard_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<AdModel> _allAds = [];
  List<AdModel> _filteredAds = [];
  final List<String> _recentSearches = ["iPhone 13", "Toyota Corolla", "Apartment in Dhaka"];
  bool _isLoading = true;
  bool _isSearching = false;

  BannerAd? _bottomLargeBannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _loadBottomLargeBannerAd();
  }

  @override
  void dispose() {
    _bottomLargeBannerAd?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadBottomLargeBannerAd() {
    _bottomLargeBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7494179033430216/3379106871',
      size: AdSize.largeBanner,
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

  Future<void> _fetchInitialData() async {
    try {
      // Updated join select matching structural sub-relation layer parameters
      final data = await Supabase.instance.client.from('ads').select('''
            *,
            categories:category_id(id, name, level, parent_id),
            districts:district_id(id, name, level, parent_id)
          ''').order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allAds = (data as List).map((ad) => AdModel.fromMap(ad)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("LOKKO Search Fetch Initial Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HIERARCHY STRUCTURAL FILTER LOGIC ---
  void _runFilter(String query) {
    final cleanQuery = query.trim().toLowerCase();

    setState(() {
      _isSearching = cleanQuery.isNotEmpty;
      if (!_isSearching) {
        _filteredAds = [];
        return;
      }

      _filteredAds = _allAds.where((ad) {
        // 1. Structural Title Match
        final bool matchesTitle = ad.title.toLowerCase().contains(cleanQuery);

        // 2. Structural Category Match (Safely parsing base layout layers)
        final bool matchesCategory = ad.categoryName.toLowerCase().contains(cleanQuery);

        // 3. Structural Location Match
        final bool matchesLocation = ad.districtName.toLowerCase().contains(cleanQuery) ||
            (ad.divisionName?.toLowerCase().contains(cleanQuery) ?? false);

        return matchesTitle || matchesCategory || matchesLocation;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1aa332),
        elevation: 0,
        toolbarHeight: 70,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () {
            ref.read(bottomNavIndexProvider.notifier).state = 0;
            _searchController.clear();
            _runFilter("");
          },
        ),
        title: Container(
          height: 45,
          margin: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _searchController,
            onChanged: _runFilter,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: "What are you looking for?",
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              fillColor: Colors.white,
              filled: true,
              prefixIcon: const Icon(Icons.search, color: Color(0xFF1aa332)),
              suffixIcon: _isSearching
                  ? IconButton(
                icon: const Icon(Icons.cancel, size: 18, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  _runFilter("");
                },
              )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1aa332)))
                  : !_isSearching
                  ? _buildPreSearchUI()
                  : _filteredAds.isEmpty
                  ? _buildNoResults()
                  : ListView.separated(
                padding: const EdgeInsets.only(top: 8),
                itemCount: _filteredAds.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 85),
                itemBuilder: (context, index) => _buildSearchTile(_filteredAds[index]),
              ),
            ),
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
        height: 112,
        child: SizedBox(
          width: 320,
          height: 100,
          child: AdWidget(ad: _bottomLargeBannerAd!),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPreSearchUI() {
    return ListView(
      children: [
        _buildSectionHeader("RECENT SEARCHES"),
        ..._recentSearches.map((term) => ListTile(
          leading: const Icon(Icons.history, color: Colors.grey, size: 22),
          title: Text(term, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          trailing: const Icon(Icons.north_west, size: 16, color: Colors.grey),
          onTap: () {
            _searchController.text = term;
            _runFilter(term);
          },
        )),
        const Divider(),
        _buildSectionHeader("POPULAR CATEGORIES"),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [
              _buildCategoryChip("Mobiles"),
              _buildCategoryChip("Electronics"),
              _buildCategoryChip("Vehicles"),
              _buildCategoryChip("Property"),
              _buildCategoryChip("Jobs"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        _searchController.text = label;
        _runFilter(label);
      },
      backgroundColor: Colors.grey.shade100,
      labelStyle: const TextStyle(color: Colors.black87, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade300)),
    );
  }

  Widget _buildSearchTile(AdModel ad) {
    // Structural metadata location display logic string construction
    final String locationDisplay = (ad.districtName.isEmpty || ad.districtName == 'null')
        ? 'Bangladesh'
        : (ad.divisionName != null && ad.divisionName!.isNotEmpty && ad.divisionName != ad.districtName)
        ? "${ad.divisionName}, ${ad.districtName}"
        : ad.districtName;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey.shade100,
          image: ad.images.isNotEmpty
              ? DecorationImage(image: NetworkImage(ad.images[0]), fit: BoxFit.cover)
              : null,
        ),
        child: ad.images.isEmpty ? const Icon(Icons.image, color: Colors.grey) : null,
      ),
      title: Text(ad.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${ad.categoryName} • $locationDisplay",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              "৳ ${ad.price.toStringAsFixed(0)}",
              style: const TextStyle(color: Color(0xFF1aa332), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdDetailsScreen(ad: ad))),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No results for \"${_searchController.text}\"", style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}