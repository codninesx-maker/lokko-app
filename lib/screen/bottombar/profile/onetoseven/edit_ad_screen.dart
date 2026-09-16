import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart';
import 'package:lokko_market/screen/topbar/category_menu_screen.dart';
import 'package:lokko_market/screen/topbar/location_menu_state.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class EditAdScreen extends StatefulWidget {
  final Map<String, dynamic> ad; // Using Map as we discussed for the Tecno crash
  final bool isAdmin;
  const EditAdScreen({super.key, required this.ad,this.isAdmin = false,});


  @override
  State<EditAdScreen> createState() => _EditAdScreenState();
}

class _EditAdScreenState extends State<EditAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final String _cloudinaryBaseUrl = "https://res.cloudinary.com/dcrnhyalb/image/upload/";

  List<String> _existingImageUrls = [];
  final List<File> _newImageFiles = [];
  final ImagePicker _picker = ImagePicker();

  // State variables matching PostAdScreen logic
  String? _selectedCategoryName;
  String? _selectedLocationName;
  String _selectedCondition = 'Used';
  String _selectedAuthenticity = 'Original';
  String? _selectedCategoryId;
  String? _selectedDistrictId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Text fields are always happy with .toString()
    _titleController.text = widget.ad['title']?.toString() ?? '';
    _priceController.text = widget.ad['price']?.toString() ?? '';
    _descController.text = widget.ad['description']?.toString() ?? '';

    _selectedCondition = widget.ad['condition']?.toString() ?? 'Used';
    _selectedAuthenticity = widget.ad['authenticity']?.toString() ?? 'Original';

    // FIX: Force these to Strings even if they come as integers from the DB
    _selectedCategoryId = widget.ad['category_id']?.toString();
    _selectedDistrictId = widget.ad['district_id']?.toString();

    if (widget.ad['categories'] != null && widget.ad['categories'] is Map) {
      _selectedCategoryName = widget.ad['categories']['name']?.toString();
    } else {
      _selectedCategoryName = widget.ad['category_name']?.toString();
    }
    _selectedCategoryName ??= "Select Category";

    if (widget.ad['districts'] != null && widget.ad['districts'] is Map) {
      _selectedLocationName = widget.ad['districts']['name']?.toString();
    } else {
      _selectedLocationName = widget.ad['district_name']?.toString();
    }
    _selectedLocationName ??= "Select Location";

    if (widget.ad['images'] != null) {
      _existingImageUrls = (widget.ad['images'] as List).map((img) {
        String imageStr = img.toString();
        // If it doesn't start with http, it's a raw ID, so add the URL
        if (!imageStr.startsWith('http')) {
          return "$_cloudinaryBaseUrl$imageStr";
        }
        return imageStr;
      }).toList();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _getPublicIdFromUrl(String url) {
    if (!url.contains('image/upload/')) return url;

    try {
      // 1. Get everything after 'image/upload/'
      final String afterUpload = url.split('image/upload/').last;
      final List<String> segments = afterUpload.split('/');

      // 2. Filter out transformation segments (e.g., 'w_300,h_300')
      // and version segments (e.g., 'v17123456')
      final List<String> idSegments = segments.where((segment) {
        bool isTransformation = segment.contains(',') || (segment.contains('_') && !segment.contains('lokko_product'));
        bool isVersion = segment.startsWith('v') && RegExp(r'^v\d+$').hasMatch(segment);
        return !isTransformation && !isVersion;
      }).toList();

      // 3. Join the remaining segments (folder + filename) and strip extension
      String fullId = idSegments.join('/');
      if (fullId.contains('.')) {
        fullId = fullId.split('.').first;
      }

      return fullId;
    } catch (e) {
      debugPrint("LOKKO_ID_ERROR: $e");
      return url;
    }
  }


  Future<void> _pickImages() async {
    // 1. Calculate current total
    int currentTotal = _existingImageUrls.length + _newImageFiles.length;

    if (currentTotal >= 4) {
      _showSnackBar("Maximum 4 photos allowed", isError: true);
      return;
    }

    // 2. Calculate remaining slots
    int remainingSlots = 4 - currentTotal;

    final List<XFile> images = await _picker.pickMultiImage(
      maxWidth: 1024, // Optimized for TECNO
    );

    if (images.isNotEmpty) {
      // 3. Only take what fits
      final limitedImages = images.take(remainingSlots).toList();

      for (var xFile in limitedImages) {
        final String targetPath = p.join(
            (await getTemporaryDirectory()).path,
            "lokko_edit_${DateTime.now().millisecondsSinceEpoch}.jpg"
        );

        final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
          xFile.path,
          targetPath,
          quality: 70, // Slightly lower quality for better performance
          minWidth: 1024,
          minHeight: 1024,
          keepExif: false, // Fixes TECNO crash
          autoCorrectionAngle: true,
          format: CompressFormat.jpeg,
        );

        if (compressedFile != null && mounted) {
          setState(() {
            _newImageFiles.add(File(compressedFile.path));
          });
        }
      }

      if (images.length > remainingSlots) {
        _showSnackBar("Only $remainingSlots images added (Limit: 4)");
      }
    }
  }

  Future<void> _updateAd() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final supabase = Supabase.instance.client;
    setState(() => _isSubmitting = true);
    final navigator = Navigator.of(context);

    try {
      // 1. Image Sync & Cloudinary Logic (Keeping your existing logic)
      List<dynamic> originalImages = widget.ad['images'] ?? [];
      List<String> currentExistingIds = _existingImageUrls
          .map((url) => _getPublicIdFromUrl(url))
          .whereType<String>()
          .toList();

      List<String> imagesToDelete = originalImages
          .map((img) => _getPublicIdFromUrl(img.toString()))
          .whereType<String>()
          .where((id) => !currentExistingIds.contains(id))
          .toList();

      final uploadFutures = _newImageFiles.map((file) =>
          CloudinaryHelper.uploadToCloudinary(file, "lokko_product"));
      final List<String?> uploadedIds = await Future.wait(uploadFutures);

      final List<String> finalImagePublicIds = [
        ...currentExistingIds,
        ...uploadedIds.whereType<String>(),
      ];

      if (finalImagePublicIds.isEmpty) throw "At least one image is required";

      // 2. Change Detection
      final bool sensitiveDataChanged =
          _titleController.text.trim() != widget.ad['title'] ||
              (double.tryParse(_priceController.text) ?? 0.0) != (widget.ad['price'] as num).toDouble() ||
              _newImageFiles.isNotEmpty ||
              imagesToDelete.isNotEmpty ||
              _selectedCategoryId != widget.ad['category_id']?.toString();

      // 3. Payload Construction
      final Map<String, dynamic> updateData = {
        'title': _titleController.text.trim(),
        'price': int.tryParse(_priceController.text) ?? 0,
        'condition': _selectedCondition,
        'authenticity': _selectedAuthenticity,
        'category_id': int.tryParse(_selectedCategoryId ?? ''),
        'district_id': int.tryParse(_selectedDistrictId ?? ''),
        'description': _descController.text.trim(),
        'images': finalImagePublicIds,
      };

      // 4. LOKKO Status Logic - SWITCHED TO 'reviewed'
      String currentStatus = (widget.ad['status']?.toString() ?? 'pending').toLowerCase();
      if (widget.isAdmin) {
        updateData['is_reviewed'] = false;
        updateData['status'] = 'active'; // Admin approval makes it LIVE immediately
      } else if (sensitiveDataChanged) {
        updateData['is_reviewed'] = false;
        updateData['status'] = 'pending'; // User edit requires NEW review
      } else {
        updateData['status'] = currentStatus;
      }

      // 5. Database Update
      await supabase
          .from('ads')
          .update(updateData)
          .eq('id', widget.ad['id']);

      _cleanupCloudinaryParallel(imagesToDelete);

      if (mounted) {
        _showSnackBar(widget.isAdmin ? "Admin: Ad Reviewed & Live!" : (sensitiveDataChanged ? "Sent for review!" : "Ad updated!"));
        navigator.pop(true);
      }
    } catch (e) {
      debugPrint("LOKKO_UPDATE_ERROR: $e");
      if (mounted) _showSnackBar("Update failed: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

// Run this when Approve is clicked
  Future<void> _approveAd() async {
    try {
      await Supabase.instance.client.from('ads').update({
        'status': 'reviewed', // Changed from 'active'
        'is_reviewed': true,
      }).eq('id', widget.ad['id']);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("LOKKO_APPROVE_ERROR: $e");
      _showSnackBar("Approval failed: $e", isError: true);
    }
  }

  Future<void> _rejectAd() async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('ads').update({
        'status': 'rejected',
        'is_reviewed': true,
      }).eq('id', widget.ad['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("LOKKO_REJECT_ERROR: $e");
      _showSnackBar("Rejection failed", isError: true);
    }
  }

// Helper to run deletions without blocking the UI
  void _cleanupCloudinaryParallel(List<String> ids) {
    for (var id in ids) {
      CloudinaryHelper.deleteOldImage(id).then((_) {
        debugPrint("LOKKO_CLEANUP: Deleted $id");
      }).catchError((e) => debugPrint("LOKKO_CLEANUP_FAIL: $id -> $e"));
    }
  }

  Future<void> _replaceImage(int index, bool isExisting) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final String targetPath = p.join(
          (await getTemporaryDirectory()).path,
          "lokko_replace_${DateTime.now().millisecondsSinceEpoch}.jpg"
      );

      final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
        image.path,
        targetPath,
        quality: 75,
        keepExif: false, // Essential for TECNO
        autoCorrectionAngle: true,
      );

      if (compressedFile != null) {
        setState(() {
          if (isExisting) {
            // If they replace an existing (Cloudinary) image,
            // we remove it from existing and add it to the NEW files list.
            _existingImageUrls.removeAt(index);
            _newImageFiles.add(File(compressedFile.path));
          } else {
            // If they replace a file they just picked
            _newImageFiles[index] = File(compressedFile.path);
          }
        });
        _showSnackBar("Image updated");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1aa332),
        elevation: 0,
        title: const Text("Edit your ad", style: TextStyle(fontSize: 17, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildImageHeader(),

              _sectionTitle("ADD DETAILS"),
              _buildBikroyTile(
                label: "Category",
                value: _selectedCategoryName ?? "Select Category",
                icon: Icons.grid_view,
                onTap: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(builder: (context) => const CategoryMenu()),
                  );

                  debugPrint("LOKKO_EDIT_RECEIVED: $result");

                  if (result != null) {
                    setState(() {
                      // --- MATCH THE LOGGED KEYS ---
                      // Your log shows 'category_id' and 'category_name'
                      _selectedCategoryId = result['category_id']?.toString();
                      _selectedCategoryName = result['category_name']?.toString();
                    });
                    debugPrint("LOKKO_EDIT: Selected Category $_selectedCategoryName");
                  } else {
                    debugPrint("LOKKO_EDIT_ERROR: Result was null");
                  }
                },
              ),
              _buildBikroyTile(
                label: "Location",
                value: _selectedLocationName ?? "Select Location",
                icon: Icons.location_on_outlined,
                onTap: () async {
                  final result = await Navigator.push<dynamic>(
                    context,
                    MaterialPageRoute(builder: (context) => const LocationMenu()),
                  );
                  if (result != null) {
                    setState(() {
                      if (result is Map) {
                        // Convert to String to be safe
                        _selectedDistrictId = result['location_id'].toString();
                        _selectedLocationName = result['location_name'].toString();
                      }
                    });
                  }
                },
              ),

              _sectionTitle("PRODUCT INFORMATION"),
              _buildInputField(controller: _titleController, label: "Title", hint: "Ad Title"),
              _buildInputField(controller: _descController, label: "Description", hint: "Description", isMultiline: true),
              _buildInputField(controller: _priceController, label: "Price (৳)", hint: "Price", keyboard: TextInputType.number),

              _sectionTitle("ADDITIONAL INFO"),
              _buildBikroyTile(
                label: "Condition",
                value: _selectedCondition,
                icon: Icons.info_outline,
                onTap: () => _showPicker("Condition", ["Used", "New"], (val) => setState(() => _selectedCondition = val)),
              ),
              _buildBikroyTile(
                label: "Authenticity",
                value: _selectedAuthenticity,
                icon: Icons.verified_user_outlined,
                onTap: () => _showPicker("Authenticity", ["Original", "Repaired"], (val) => setState(() => _selectedAuthenticity = val)),
              ),

              const SizedBox(height: 30),

              // Unified Admin / User Action Panel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Only show Reject button if it's an Admin
                    if (widget.isAdmin) ...[
                      Expanded(
                        flex: 2, // Slightly narrower for reject
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              backgroundColor: Colors.red.withOpacity(0.05),
                            ),
                            onPressed: _isSubmitting ? null : _rejectAd,
                            child: const Text(
                              "Reject",
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Main Dynamic Save Button
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1aa332),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            elevation: 1,
                          ),
                          onPressed: _isSubmitting ? null : _updateAd,
                          child: _isSubmitting
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : Text(
                            widget.isAdmin ? "Approve & Save" : "Save changes",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // 🔼 END OF ADMIN REVIEW BLOCK 🔼
            ],
          ),
        ),
      ),
    );
  }

  // --- REPLICATED UI HELPERS FROM POSTADSCREEN ---

  Widget _buildImageHeader() {
    int totalCount = _existingImageUrls.length + _newImageFiles.length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Update label to show /4
          Text("Add photos ($totalCount/4)", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Only show Add button if less than 4
                if (totalCount < 4)
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 75, height: 75,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.grey.shade50
                      ),
                      child: const Icon(Icons.add_a_photo, color: Color(0xFF1aa332), size: 30),
                    ),
                  ),
                // For Existing Images
                ..._existingImageUrls.asMap().entries.map((e) => _imageStack(
                  NetworkImage(e.value),
                      () => setState(() => _existingImageUrls.removeAt(e.key)),
                  index: e.key,
                  isExisting: true,
                )),

// For New Image Files
                ..._newImageFiles.asMap().entries.map((e) => _imageStack(
                  FileImage(e.value),
                      () => setState(() => _newImageFiles.removeAt(e.key)),
                  index: e.key,
                  isExisting: false,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageStack(ImageProvider provider, VoidCallback onRemove, {int? index, bool isExisting = true}) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _replaceImage(index!, isExisting),
          child: Container(
            width: 75, height: 75,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                // Use DecorationImage for sharp rendering
                image: DecorationImage(
                  image: provider,
                  fit: BoxFit.cover,
                  // Adding FilterQuality.medium helps smooth out the compressed edges
                  filterQuality: FilterQuality.medium,
                )
            ),
            child: Container(
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.edit, color: Colors.white, size: 16),
            ),
          ),
        ),
        Positioned(
            top: 0, right: 10,
            child: GestureDetector(
                onTap: onRemove,
                child: Container(
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 16)
                )
            )
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(16, 20, 16, 10), child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)));

  Widget _buildBikroyTile({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.black54),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required String hint, bool isMultiline = false, TextInputType keyboard = TextInputType.text}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          TextFormField(
            controller: controller,
            maxLines: isMultiline ? 4 : 1,
            keyboardType: keyboard,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            decoration: InputDecoration(hintText: hint, border: InputBorder.none),
          ),
        ],
      ),
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
}