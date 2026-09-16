import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lokko_market/adminpannel/admin_review_provider.dart';
import 'package:lokko_market/screen/topbar/category_menu_screen.dart';
import 'package:lokko_market/screen/topbar/location_menu_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Project Imports (Assumed paths based on your snippet)
import 'package:lokko_market/ad_repository.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart';


final supabase = Supabase.instance.client;

class PostAdScreen extends ConsumerStatefulWidget {
  const PostAdScreen({super.key});

  @override
  ConsumerState<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends ConsumerState<PostAdScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();

  // Selection State
  int? _categoryId;
  String? _categoryName;
  int? _locationId;
  String? _locationName;

  String _selectedCondition = 'Used';
  String _selectedAuthenticity = 'Original';

  // Logic State
  bool _isSubmitting = false;
  bool _isLoadingProfile = true;
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  /// Loads initial user data to pre-fill Location
  Future<void> _loadUserProfile() async {
    try {
      final user = supabase.auth.currentUser;

      // Only query if the user session is active and ready
      if (user != null) {
        final data = await supabase
            .from('profiles')
            .select('location_name, location_id')
            .eq('id', user.id)
            .maybeSingle();

        if (data != null && mounted) {
          setState(() {
            _locationName = data['location_name'];
            _locationId = int.tryParse(data['location_id'].toString());
          });
        }
      } else {
        debugPrint("LOKKO_POST: No active user session detected yet.");
      }
    } catch (e) {
      debugPrint("Profile Load Error: $e");
    } finally {
      // This is now GUARANTEED to run, dropping the loader and opening the screen
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  /// Pick Location from LocationMenu
  Future<void> _openLocationPicker() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationMenu()),
    );

    if (result != null && result is Map) {
      setState(() {
        _locationId = result['location_id'];
        _locationName = result['location_name'];
      });
    }
  }

  /// Pick Category from CategoryMenu
  Future<void> _pickCategory() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CategoryMenu()),
    );

    if (result != null && result is Map) {
      setState(() {
        // Safe stringification parsing guards against runtime type cast crashes
        _categoryId = int.tryParse(result['category_id'].toString());
        _categoryName = result['category_name'];
      });
      debugPrint("LOKKO_POST: Category trapped successfully -> $_categoryName (ID: $_categoryId)");
    }
  }

  /// Image Picking & Compression Logic
  /// Image Picking & Compression Logic
  Future<void> _pickImages() async {
    // 1. Hard block if already at limit
    if (_selectedImages.length >= 4) {
      _showSnackBar("Maximum 4 photos allowed", isError: true);
      return;
    }

    // Calculate how many more they can pick
    int remainingSlots = 4 - _selectedImages.length;

    final List<XFile> images = await _picker.pickMultiImage(
      maxWidth: 1080,
    );

    if (images.isEmpty) return;

    // 2. Only process up to the remaining slots
    final limitedImages = images.take(remainingSlots).toList();

    for (var image in limitedImages) {
      final String targetPath = p.join(
        (await getTemporaryDirectory()).path,
        "img_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );

      var result = await FlutterImageCompress.compressAndGetFile(
        image.path,
        targetPath,
        quality: 70,
        keepExif: false, // Prevents the TECNO Tile Decoder crash
        format: CompressFormat.jpeg,
      );

      if (result != null && mounted) {
        final compressedFile = File(result.path);
        if (await compressedFile.length() > 0) {
          setState(() => _selectedImages.add(compressedFile));
        }
      }
    }

    // Optional: Notify if they tried to pick more than allowed
    if (images.length > remainingSlots) {
      _showSnackBar("Only the first $remainingSlots images were added (Limit: 4)", isError: false);
    }
  }

  /// The Main Submission Logic
  Future<void> _submitAd() async {
    // 1. Validation
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null || _locationId == null) {
      _showSnackBar("Please select Category and Location", isError: true);
      return;
    }
    if (_selectedImages.isEmpty) {
      _showSnackBar("Please add at least one image", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "You must be logged in to post.";

      // 2. Sequential Upload to Cloudinary
      List<String> cloudinaryIds = [];

// Upload images in parallel and wait for all to complete 100%
      final uploadResults = await Future.wait(
          _selectedImages.map((file) => CloudinaryHelper.uploadToCloudinary(file, "lokko_product"))
      );

// Filter out any nulls from failed uploads
      cloudinaryIds = uploadResults.whereType<String>().toList();

      if (cloudinaryIds.isEmpty) throw "Failed to upload images. Check connection.";

      // 3. Insert Ad to Supabase
      // 3. Insert Ad to Supabase
      await supabase.from('ads').insert({
        'user_id': user.id,
        'title': _titleController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0,
        'status': 'pending',
        'is_reviewed': false,
        'category_id': _categoryId,

        // FIX: Change 'location_id' to 'district_id' to match your SQL
        'district_id': _locationId,

        // Optional: Also save the 'district_name' if you want a text fallback
        'district_name': _locationName,

        'description': _descController.text.trim(),
        'images': cloudinaryIds,
        'condition': _selectedCondition,
        'authenticity': _selectedAuthenticity,
      });

      // 4. Update Profile Location (Sync)
      await supabase.from('profiles').update({
        'location_name': _locationName,
        'location_id': _locationId, // Ensure your profiles table has this exact column name
      }).eq('id', user.id);

      ref.invalidate(adminReviewProvider);

      if (mounted) {
        _showSnackBar("Post created & Sent for review!", isError: false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // 1. Center the text inside the content
        content: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        // 2. Use LOKKO Green or Red
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1aa332),
        // 3. Make it a floating pill shape for a better "fit"
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1aa332),
        title: const Text("Post your ad", style: TextStyle(color: Colors.white, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildImageSection(),
              _sectionTitle("BASIC DETAILS"),
              _buildSelectionTile(
                label: "Category",
                value: _categoryName ?? "Select a category",
                icon: Icons.grid_view,
                onTap: _pickCategory,
              ),
              _buildSelectionTile(
                label: "Location",
                value: _locationName ?? "Select location",
                icon: Icons.location_on_outlined,
                onTap: _openLocationPicker,
              ),
              _sectionTitle("PRODUCT INFO"),
              _buildInputField(
                controller: _titleController,
                label: "Title",
                hint: "e.g. iPhone 13 Pro Max",
              ),
              _buildInputField(
                controller: _descController,
                label: "Description",
                hint: "Provide details about the item",
                isMultiline: true,
              ),
              _buildInputField(
                controller: _priceController,
                label: "Price",
                hint: "00",
                keyboard: TextInputType.number,
              ),
              _sectionTitle("ADDITIONAL INFO"),
              _buildSelectionTile(
                label: "Condition",
                value: _selectedCondition,
                icon: Icons.info_outline,
                onTap: () => _showPicker("Condition", ["Used", "New"], (val) {
                  setState(() => _selectedCondition = val);
                }),
              ),
              _buildSelectionTile(
                label: "Authenticity",
                value: _selectedAuthenticity,
                icon: Icons.verified_user_outlined,
                onTap: () => _showPicker("Authenticity", ["Original", "Repaired"], (val) {
                  setState(() => _selectedAuthenticity = val);
                }),
              ),
              const SizedBox(height: 30),
              _buildSubmitButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI WIDGETS ---

  Widget _buildImageSection() {
    return Container(
      height: 130,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        // If length is 4, don't add the +1 for the button
        itemCount: _selectedImages.length < 4 ? _selectedImages.length + 1 : 4,
        itemBuilder: (context, index) {
          if (index == _selectedImages.length && _selectedImages.length < 4) {
            return _buildAddImageButton();
          }
          return _buildImageThumbnail(index);
        },
      ),
    );
  }

  Widget _buildImageThumbnail(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _selectedImages[index],
                fit: BoxFit.cover,
                // FIX: Increase cacheWidth to 500 or 600 for high-DPI screens
                cacheWidth: 600,
                // FIX: Add filterQuality for smoother downscaling
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => setState(() => _selectedImages.removeAt(index)),
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton() {
    return InkWell(
      onTap: _pickImages,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, color: Colors.grey),
            Text("Add Photo", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionTile({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.black54),
        title: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required String hint, bool isMultiline = false, TextInputType keyboard = TextInputType.text}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          TextFormField(
            controller: controller,
            maxLines: isMultiline ? 4 : 1,
            keyboardType: keyboard,
            validator: (v) => v == null || v.isEmpty ? "Required" : null,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey[350], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1aa332),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          onPressed: _isSubmitting ? null : _submitAd,
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("POST AD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  void _showPicker(String title, List<String> options, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      // This allows the sheet to sit above the system navigation bar
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Optional: Add a title header to the picker
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Text(
                "Select $title",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            // Map the options to ListTiles
            ...options.map((opt) => ListTile(
              title: Text(opt, textAlign: TextAlign.center),
              onTap: () {
                onSelect(opt);
                Navigator.pop(context);
              },
            )).toList(),
            // Add a tiny bit of extra space for better thumb reach
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}