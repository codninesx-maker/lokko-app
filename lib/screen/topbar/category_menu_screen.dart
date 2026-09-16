import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lokko_market/model/category_model.dart';

class CategoryMenu extends StatefulWidget {
  const CategoryMenu({super.key});

  @override
  State<CategoryMenu> createState() => _CategoryMenuState();
}

class _CategoryMenuState extends State<CategoryMenu> {
  final _supabase = Supabase.instance.client;

  int? parentId; // Tracks our current level (null = Top Level)
  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;
  String? selectedMainCategoryName;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  final List<int?> _navigationHistory = [];

  Future<void> _fetchCategories() async {
    setState(() => isLoading = true);
    try {
      var query = _supabase.from('categories').select('id, name, level, icon_key');

      if (parentId == null) {
        query = query.isFilter('parent_id', null);
      } else {
        query = query.eq('parent_id', parentId!);
      }

      final data = await query.order('name');
      setState(() {
        categories = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("LOKKO Error: $e");
      setState(() => isLoading = false);
    }
  }

  void _handleSelection(Map<String, dynamic> category) async {
    setState(() => isLoading = true);

    try {
      // Check if this selected node has any child subcategories underneath it
      final childrenCheck = await _supabase
          .from('categories')
          .select('id')
          .eq('parent_id', category['id'])
          .limit(1);

      if (childrenCheck.isNotEmpty) {
        // CHILDREN EXIST (It's a Level 1 or Level 2 Parent node) -> Navigate Deeper
        _navigationHistory.add(parentId); // Save previous parent state to history
        setState(() {
          parentId = category['id'];
          selectedMainCategoryName = category['name'];
          searchQuery = "";
        });
        _fetchCategories();
      } else {
        // NO CHILDREN FOUND (It's a leaf node - a deep Level 3, or a Level 2 with no subcategories) -> Return Selection
        debugPrint("LOKKO_POP: Finalizing Choice -> ${category['name']} with ID: ${category['id']}");

        Navigator.pop(context, {
          'category_name': category['name'],
          'category_id': category['id'],
        });
      }
    } catch (e) {
      debugPrint("LOKKO Selection Error: $e");
      // Safety fallback: if lookup fails, pop out with what we have
      Navigator.pop(context, {
        'category_name': category['name'],
        'category_id': category['id'],
      });
    }
  }

  void _handleBackPress() {
    if (_navigationHistory.isNotEmpty) {
      setState(() {
        parentId = _navigationHistory.removeLast(); // Pop back one step cleanly
        if (parentId == null) {
          selectedMainCategoryName = null;
        }
        searchQuery = "";
      });
      _fetchCategories();
    } else if (parentId != null) {
      setState(() {
        parentId = null;
        selectedMainCategoryName = null;
        searchQuery = "";
      });
      _fetchCategories();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = categories
        .where((c) => c['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1aa332),
        title: Text(parentId == null ? "Select Category" : "Select Sub-category"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: _handleBackPress,
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder( // Changed to builder to handle mixed rows smoothly
              itemCount: filteredList.length + (parentId != null ? 1 : 0),
              itemBuilder: (context, index) {
                // 1. INJECT "ALL IN..." OPTION AT THE TOP OF SUBCATEGORIES
                if (parentId != null && index == 0) {
                  return Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1aa332).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.all_inclusive, color: Color(0xFF1aa332), size: 24),
                        ),
                        title: Text(
                          "All in $selectedMainCategoryName",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1aa332)),
                        ),
                        trailing: const Icon(Icons.check_circle_outline, color: Color(0xFF1aa332), size: 20),
                        onTap: () {
                          // Return the current parent category instead of going deeper!
                          debugPrint("LOKKO_POP: Choosing Broad Category -> $selectedMainCategoryName with ID: $parentId");
                          Navigator.pop(context, {
                            'category_name': selectedMainCategoryName,
                            'category_id': parentId, // Returns Level 1 or Level 2 ID
                          });
                        },
                      ),
                      const Divider(height: 1, indent: 70),
                    ],
                  );
                }

                // 2. ADJUST INDEX FOR REGULAR CATEGORIES IF THE "ALL" BUTTON IS SHOWN
                final actualIndex = parentId != null ? index - 1 : index;
                final cat = filteredList[actualIndex];

                return Column(
                  children: [
                    ListTile(
                      leading: _getCategoryIcon(cat['icon_key'] ?? 'default'),
                      title: Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _handleSelection(cat),
                    ),
                    const Divider(height: 1, indent: 70),
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1aa332),
      child: TextField(
        onChanged: (val) => setState(() => searchQuery = val),
        decoration: InputDecoration(
          hintText: "Search categories...",
          fillColor: Colors.white,
          filled: true,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _getCategoryIcon(String key) {
    IconData iconData;
    Color color;

    switch (key) {
      case 'mobile':
        iconData = Icons.phone_android;
        color = Colors.blue;
        break;
      case 'electronics':
        iconData = Icons.laptop_mac;
        color = Colors.orange;
        break;
      case 'vehicle':
        iconData = Icons.directions_car;
        color = Colors.red;
        break;
      case 'property':
        iconData = Icons.home_work;
        color = Colors.purple;
        break;
      case 'home':
        iconData = Icons.chair;
        color = Colors.brown;
        break;
      case 'pets':
        iconData = Icons.pets;
        color = Colors.orangeAccent;
        break;
      case 'fashion':
        iconData = Icons.checkroom;
        color = Colors.pink;
        break;
      case 'jobs':
        iconData = Icons.work;
        color = Colors.deepOrange;
        break;
      case 'services':
        iconData = Icons.handyman;
        color = Colors.blueGrey;
        break;
      case 'agriculture':
        iconData = Icons.agriculture;
        color = Colors.green;
        break;
      case 'education':
        iconData = Icons.school;
        color = Colors.indigo;
        break;
      default:
        iconData = Icons.category;
        color = Colors.teal;
    }

    // IMPORTANT: You must return the widget here!
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }
}