import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationMenu extends StatefulWidget {
  const LocationMenu({super.key});

  @override
  State<LocationMenu> createState() => _LocationMenuState();
}

class _LocationMenuState extends State<LocationMenu> {
  final _supabase = Supabase.instance.client;

  int? parentId;
  List<Map<String, dynamic>> currentLocations = [];
  bool isLoading = true;
  String searchQuery = "";
  List<Map<String, dynamic>> pathStack = [];

  @override
  void initState() {
    super.initState();
    // We start with parentId = 0 to show divisions immediately
    parentId = 0;

    // We manually add "All Bangladesh" to the stack so the user can see
    // the path and we have it for the 'full_path' string later.
    pathStack.add({'id': 0, 'name': 'All Bangladesh', 'level': 0});

    Future.delayed(const Duration(milliseconds: 300), () => _fetchLocations());
  }

  Future<void> _fetchLocations() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      // We fetch where parent_id matches current level
      final data = await _supabase
          .from('districts')
          .select('id, name, level, parent_id')
          .eq('parent_id', parentId!)
          .order('name');

      debugPrint("Fetched ${data.length} locations for parentId: $parentId");

      if (!mounted) return;
      setState(() {
        currentLocations = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _handleSelection(Map<String, dynamic> location) {
    final int currentId = location['id'];
    final String currentName = location['name']?.toString() ?? "Unknown";
    final int currentLevel = location['level'] ?? 0;

    debugPrint("Selected: $currentName (Level: $currentLevel, ID: $currentId)");

    // CASE 1: Keep drilling down the tree (Levels 0, 1, 2)
    if (currentLevel < 3) {
      setState(() {
        pathStack.add({
          'id': currentId,
          'name': currentName,
          'level': currentLevel,
        });
        parentId = currentId;
        searchQuery = "";
      });
      _fetchLocations();
    }
    // CASE 2: Terminal leaf reached (Level 3 - Thana). Compile and return.
    // CASE 2: Terminal leaf reached (Level 3 - Thana). Compile and return.
    else {
      debugPrint("Level 3 Reached. Returning terminal data...");

      final List<String> names = pathStack.map((e) => e['name'].toString()).toList();
      names.add(currentName);
      final String fullPath = names.join(' > ');

      // --- NEW HIERARCHY EXTRACTION LOGIC ---
      int? divisionId;
      int? districtId;
      int? upazilaId = currentId; // The terminal element is always our Thana/Area ID

      // Walk through the pathStack to parse ancestral structural IDs
      for (var element in pathStack) {
        final int lvl = element['level'] ?? 0;
        if (lvl == 1) divisionId = element['id'] as int;
        if (lvl == 2) districtId = element['id'] as int;
      }

      Navigator.pop(context, {
        'location_name': currentName,
        'location_id': upazilaId,     // Level 3 (Thana)
        'district_id': districtId,     // Level 2 (District)
        'division_id': divisionId,     // Level 1 (Division)
        'level': currentLevel,
        'full_path': fullPath,
      });
    }
  }

  void _handleBackPress() {
    // If the stack only contains the baseline 'All Bangladesh' element, close the screen safely
    if (pathStack.length <= 1) {
      Navigator.pop(context, null);
      return;
    }

    setState(() {
      // 1. Safe to pop because we confirmed we are deeper than the baseline element
      pathStack.removeLast();

      // 2. Safely point back to the parent item's ID (this guarantees it won't be null)
      parentId = pathStack.last['id'] as int;
      searchQuery = "";
    });

    // 3. Re-fetch the previous layer without running into null exceptions
    _fetchLocations();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = currentLocations
        .where((loc) => loc['name']
        .toString()
        .toLowerCase()
        .contains(searchQuery.toLowerCase()))
        .toList();

    // Logic to determine the header text
    String titleText = parentId == 0 ? "Select Division" : (pathStack.isNotEmpty ? pathStack.last['name'] : "Select Location");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1aa332),
        elevation: 0, // Clean flat look like Category Menu
        title: Text(titleText, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: _handleBackPress,
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(titleText),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1aa332)))
                : ListView.separated(
              // Add 1 extra slot for the "All in..." row if we are deeper than root level
              itemCount: filteredList.length + (parentId != 0 && pathStack.isNotEmpty ? 1 : 0),
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
              itemBuilder: (context, index) {
                final bool showAllOption = parentId != 0 && pathStack.isNotEmpty;

                // 1. RENDER THE "ALL IN..." ROW AS THE FIRST ITEM
                if (showAllOption && index == 0) {
                  final currentParent = pathStack.last;
                  final String currentParentName = currentParent['name'];
                  final int currentParentId = currentParent['id'];
                  final int currentParentLevel = currentParent['level'];

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1aa332).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.all_inclusive, color: Color(0xFF1aa332), size: 24),
                    ),
                    title: Text(
                      "All in $currentParentName",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1aa332)),
                    ),
                    trailing: const Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF1aa332)),
                    onTap: () => _finalizeSelection(
                        currentParentName,
                        currentParentId,
                        currentParentLevel
                    ),
                  );
                }

                // 2. ADJUST INDEX FOR THE REGULAR LOCATIONS
                final actualIndex = showAllOption ? index - 1 : index;
                final loc = filteredList[actualIndex];
                final int level = loc['level'] ?? 0;

                return ListTile(
                  leading: _getLocationIcon(level, loc['name'].toString()),
                  title: Text(
                      loc['name'],
                      style: const TextStyle(fontWeight: FontWeight.w500)
                  ),
                  trailing: level < 3
                      ? const Icon(Icons.chevron_right, size: 20, color: Colors.grey)
                      : const Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF1aa332)),
                  onTap: () => _handleSelection(loc),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  void _finalizeSelection(String name, int id, int level) {
    debugPrint("LOKKO_POP: Finalizing Choice -> $name with ID: $id at Level: $level");

    List<String> names = pathStack.map((e) => e['name'].toString()).toList();

    if (names.isEmpty || names.last != name) {
      names.add(name);
    }
    // Remove "All Bangladesh" from the UI string path presentation if desired
    if(names.first == 'All Bangladesh') {
      names.removeAt(0);
    }
    String fullPath = names.isEmpty ? name : names.join(' > ');

    // --- PARSE MULTI-LEVEL STRUCTURAL IDs ---
    int? divisionId;
    int? districtId;
    int? locationId;

    // 1. Map the selection ID to its correct structural target
    if (level == 1) divisionId = id;
    if (level == 2) districtId = id;
    if (level == 3) locationId = id;

    // 2. Safely back-fill ancestors from historical stack trace
    for (var element in pathStack) {
      final int lvl = element['level'] ?? 0;
      if (lvl == 1) divisionId = element['id'] as int;
      if (lvl == 2) districtId = element['id'] as int;
    }

    // 3. CRITICAL ARCHITECTURAL MATCH:
    // If locationId is null but we have a districtId, we map the districtId
    // directly to location_id to ensure your stream `.eq('district_id', id)` doesn't receive null!
    final int? effectiveTargetId = locationId ?? districtId ?? divisionId;

    debugPrint("🌐 [LOKKO_OUTPUT] Return Payloads -> target: $effectiveTargetId, dist: $districtId, div: $divisionId");

    Navigator.pop(context, {
      'location_name': name,
      'location_id': effectiveTargetId, // Used as the primary filter key in your repositories
      'district_id': districtId,
      'division_id': divisionId,
      'level': level,
      'full_path': fullPath,
    });
  }

  Widget _getLocationIcon(int level, String name) {
    IconData iconData;
    Color color;

    // Logic to choose icons based on location levels in Bangladesh
    if (level == 0 || level == 1) { // "All Bangladesh" or Division
      iconData = Icons.map_outlined;
      color = Colors.blue;
    } else if (level == 2) { // District
      iconData = Icons.location_city;
      color = Colors.orange;
    } else { // Thana/Area (Level 3)
      iconData = Icons.pin_drop;
      color = const Color(0xFF1aa332); // LOKKO Green
    }

    // This container structure MUST match your Category Menu's _getCategoryIcon
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), // Light background
        borderRadius: BorderRadius.circular(12), // Matching rounded corners
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }

  Widget _buildSearchBar(String currentTitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF1aa332),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          hintText: "Search in $currentTitle...",
          fillColor: Colors.white,
          filled: true,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => searchQuery = ""))
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}