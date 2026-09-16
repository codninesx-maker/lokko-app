import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lokko_market/model/utility/CloudinaryHelper.dart';
import 'package:lokko_market/screen/bottombar/profile/custom_image.dart';
import 'package:lokko_market/screen/bottombar/profile/profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;
  bool _hasLoadedData = false;
  File? _image;


  // Add 'String? currentAvatarId' to the parameters
  Future<void> _updateProfile(Map<String, dynamic>? profileData, String? passedId) async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || name.length < 3) {
      _showErrorSnackBar("Please enter a valid full name (at least 3 characters)");
      return;
    }

    // Clean phone input check (handles standard 11 digit local number layout like 017XXXXXXXX)
    if (phone.isEmpty || phone.length < 11) {
      _showErrorSnackBar("Please enter a valid 11-digit mobile number");
      return;
    }

    // 1. SHOW LOADER
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF1aa332))),
    );

    final String? oldIdToDelete = passedId;
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) Navigator.pop(context); // Close loader if no user
      return;
    }

    try {
      String? finalPublicId = oldIdToDelete;

      if (_image != null) {
        // 2. UPLOAD
        final String? newPublicId = await CloudinaryHelper.uploadToCloudinary(_image!, 'lokko_profile');

        if (newPublicId != null) {
          // 3. UPDATE DB WITH IMAGE
          await supabase.from('profiles').update({
            'avatar_public_id': newPublicId,
            'full_name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'avatar_url': null,
          }).eq('id', user.id);


          // 4. DELETE OLD IMAGE
          if (oldIdToDelete != null && oldIdToDelete.isNotEmpty && oldIdToDelete != newPublicId) {
            debugPrint("LOKKO_CLEANUP: Deleting old ID: $oldIdToDelete");
            await CloudinaryHelper.deleteOldImage(oldIdToDelete);
          }
        }
      } else {
        // 3. UPDATE DB WITHOUT IMAGE (Text only)
        await supabase.from('profiles').update({
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        }).eq('id', user.id);
      }

      // 5. SUCCESS REFRESH
      ref.invalidate(userProfileProvider);

      if (mounted) {
        Navigator.pop(context); // Closes the LOADER

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated! ✅"), backgroundColor: Color(0xFF1aa332)),
        );

        Navigator.pop(context); // Closes the PROFILE SCREEN (Returns to Home)
      }

    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loader on error
      debugPrint("LOKKO_UPDATE_ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload(ImageSource source, String userId) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path); // Just set the local file
      });
    }
  }

  Future<void> _saveProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      }).eq('id', user.id);

      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF1aa332)))),
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
      data: (profileData) {
        // 1. Safety Check: If profileData is null, show an error or empty state
        if (profileData == null) {
          return const Scaffold(
            body: Center(child: Text("Profile not found. Please log in again.")),
          );
        }

        // 2. Initialize controllers only once
        if (!_hasLoadedData) {
          _nameController.text = profileData['full_name'] ?? '';
          _phoneController.text = profileData['phone'] ?? '';
          _hasLoadedData = true;
        }

        // 3. Safe Casting
        final profile = profileData; // Riverpod already knows this is Map<String, dynamic>?

        final String? pubId = profile['avatar_public_id'];
        final String? legacyUrl = profile['avatar_url'];

        String? avatarUrl;
        if (pubId != null && pubId.isNotEmpty) {
          avatarUrl = CloudinaryHelper.getProfileAvatar(pubId);
        } else if (legacyUrl != null && legacyUrl.isNotEmpty) {
          avatarUrl = legacyUrl;
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text("Edit Profile", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF1aa332),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (!_isSaving)
                IconButton(
                  icon: const Icon(Icons.check),
                  // CHANGE THIS LINE: Pass profileData to the new update function
                  onPressed: () {
                    // We grab the ID right here and pass it as the second argument
                    final String? currentId = profileData?['avatar_public_id'];
                    _updateProfile(profileData, currentId);
                  }, // Ensure this closing brace and comma are here to fix the ';' error
                )
              else
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                    )
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Stack(
                    children: [
                      // FIXED: Correct variable name and removed semicolon
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: _image != null
                            ? ClipOval(child: Image.file(_image!, width: 110, height: 110, fit: BoxFit.cover)) // Local Picked Image
                            : (avatarUrl != null
                            ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                            errorWidget: (context, url, error) => const Icon(Icons.person, size: 65, color: Color(0xFF1aa332)),
                          ),
                        )
                            : const Icon(Icons.person, size: 65, color: Color(0xFF1aa332))),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          // FIXED: Pass userId to function
                          onTap: _isSaving ? null : () => _pickAndUpload(ImageSource.gallery, profileData!['id']),
                          child: CircleAvatar(
                            backgroundColor: _isSaving ? Colors.grey : const Color(0xFF1aa332),
                            radius: 18,
                            child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF1aa332)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _phoneController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "Mobile Number",
                    prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF1aa332)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}