import 'package:flutter/material.dart';
import 'package:lokko_market/screen/topbar/category_menu_screen.dart';
import 'package:lokko_market/screen/topbar/location_menu_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FilterScreen extends StatefulWidget {
  final String? initialCategoryId;
  final String? initialCategoryName;
  final String? initialDistrictId;
  final String? initialLocationName;
  final RangeValues initialPrice;
  final String initialSort;

  const FilterScreen({
    super.key,
    this.initialCategoryId,
    this.initialCategoryName,
    this.initialDistrictId,
    this.initialLocationName,
    required this.initialPrice,
    required this.initialSort,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late String _selectedSort;
  late RangeValues _priceRange;

  // Storing IDs and Names
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _selectedDistrictId;
  String? _selectedLocationName;

  @override
  void initState() {
    super.initState();
    _selectedSort = widget.initialSort;
    _priceRange = widget.initialPrice;
    _selectedCategoryId = widget.initialCategoryId;
    _selectedCategoryName = widget.initialCategoryName;
    _selectedDistrictId = widget.initialDistrictId;
    _selectedLocationName = widget.initialLocationName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1aa332), // LOKKO Brand Green
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Filter",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900, // Matching the dashboard's heavy brand weight
            fontSize: 22,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'categoryId': null,
                'districtId': null,
                'price': const RangeValues(0, 1000000),
                'sort': "Newest on top",
                'locationName': null,
                'categoryName': null,
              });
            },
            child: const Text(
              "Reset",
              style: TextStyle(
                color: Colors.white, // Inverted to stand out cleanly on the green background
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          )
        ],
      ),
      body: ListView(
        children: [
          _buildHeader("Sort results by"),
          _buildSortOption("Newest on top"),
          _buildSortOption("Price: Low to High"),
          _buildSortOption("Price: High to Low"),

          const Divider(),

          _buildHeader("Category"),
          _buildSelectionTile(
            icon: Icons.category_outlined,
            title: _selectedCategoryName ?? "All Categories",
            onTap: () => _openCategoryPicker(),
          ),

          const Divider(),

          _buildHeader("Location"),
          _buildSelectionTile(
            icon: Icons.location_on_outlined,
            title: _selectedLocationName ?? "All of Bangladesh",
            onTap: () => _openLocationPicker(),
          ),

          const Divider(),

          _buildHeader("Price Range (৳)"),
          _buildPriceSlider(),
        ],
      ),
      bottomNavigationBar: _buildApplyButton(),
    );
  }

  // Navigates to your dedicated CategoryMenu screen
  void _openCategoryPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const CategoryMenu()),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedCategoryId = result['category_id']?.toString();
        _selectedCategoryName = result['category_name']?.toString();
      });
    }
  }

  // Navigates to your dedicated LocationMenu screen
  void _openLocationPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const LocationMenu()),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedDistrictId = result['location_id']?.toString();
        _selectedLocationName = result['location_name']?.toString();
      });
    }
  }

  Widget _buildSortOption(String value) {
    return RadioListTile<String>(
      title: Text(value, style: const TextStyle(fontSize: 14)),
      value: value,
      groupValue: _selectedSort,
      activeColor: const Color(0xFF1aa332),
      onChanged: (val) => setState(() => _selectedSort = val!),
    );
  }

  Widget _buildPriceSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 1000000,
            activeColor: const Color(0xFF1aa332),
            onChanged: (val) => setState(() => _priceRange = val),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("৳${_priceRange.start.round()}"),
              Text("৳${_priceRange.end.round()}"),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildApplyButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1aa332),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 2,
          ),
          onPressed: () {
            Navigator.pop(context, {
              'categoryId': _selectedCategoryId,
              'districtId': _selectedDistrictId,
              'price': _priceRange,
              'sort': _selectedSort,
              'locationName': _selectedLocationName,
              'categoryName': _selectedCategoryName,
            });
          },
          child: const Text(
              "Apply Filters",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              )
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildSelectionTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}