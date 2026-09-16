import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' show sha1;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CloudinaryHelper {
  static const String _cloudName = "dcrnhyalb";
  static const String _apiKey = "391266525353171";
  static const String _apiSecret = "DYXPRMvHuohveOB7i0Wg9MS5E8c";
  static const String _uploadPreset = "lokko_preset";
  static const String _baseUrl = "https://res.cloudinary.com/dcrnhyalb/image/upload/";


  /// Updated to return a Network-based placeholder instead of a local asset
  /// Updated for maximum performance on budget devices
  static String getProductImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty || imagePath == "null") {
      // Use a solid color background from UI-Avatars if no image exists
      return "https://ui-avatars.com/api/?name=No+Image&background=f4f4f4&color=ccc";
    }

    if (imagePath.startsWith('http')) return imagePath;

    // FIX: Changed c_fill to c_thumb, lowered width to 300, and added q_auto:eco
    // c_thumb is much more efficient than c_fill for generating fast previews
    return "https://res.cloudinary.com/$_cloudName/image/upload/c_thumb,w_300,h_300,f_webp,q_auto:eco/$imagePath";
  }

  static String getThumbnailUrl(String publicId) {
    if (publicId.isEmpty) return "";
    // Ensure we aren't sending a full URL or a null string
    if (publicId.startsWith('http')) return publicId;

    // Clean the path: remove leading slashes if any
    final cleanId = publicId.startsWith('/') ? publicId.substring(1) : publicId;

    return "https://res.cloudinary.com/$_cloudName/image/upload/c_thumb,w_250,h_250,f_auto,q_auto:eco/$cleanId";
  }

  static String getProfileAvatar(String? publicId, {String name = "User"}) {
    if (publicId == null || publicId.isEmpty || publicId == "null") {
      return "https://ui-avatars.com/api/?name=$name&background=random&color=fff";
    }
    if (publicId.startsWith('http')) return publicId;

    // Profiler avatars are small; 150px is plenty for the KM7
    return "https://res.cloudinary.com/$_cloudName/image/upload/w_150,h_150,c_thumb,g_face,f_webp,q_auto:eco/$publicId";
  }

  static String getFullViewUrl(String publicId) {
    return "https://res.cloudinary.com/$_cloudName/image/upload/c_limit,w_1200,f_auto,q_auto/$publicId";
  }

  static String getSmartImageUrl(String? imagePath) => getProductImage(imagePath);

  // --- DELETE LOGIC (Fixed Signature Order) ---
  static Future<void> deleteOldImage(String publicId) async {
    try {
      final int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Cloudinary requires parameters in alphabetical order for the signature
      // public_id -> timestamp -> secret
      final String signatureData = "public_id=$publicId&timestamp=$timestamp$_apiSecret";
      final String signature = sha1.convert(utf8.encode(signatureData)).toString();

      final response = await http.post(
        Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/destroy"),
        body: {
          'public_id': publicId,
          'timestamp': timestamp.toString(),
          'api_key': _apiKey,
          'signature': signature,
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['result'] == 'ok') {
          debugPrint("LOKKO_CLOUDINARY: Delete Success ✅");
        } else {
          debugPrint("LOKKO_CLOUDINARY: Delete Failed ❌ - ${result['result']}");
        }
      }
    } catch (e) {
      debugPrint("LOKKO_CLOUDINARY_ERROR: $e");
    }
  }

  // --- UPLOAD LOGIC ---
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(minutes: 2),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static Future<String?> uploadToCloudinary(File imageFile, String folderName) async {
    final String url = "https://api.cloudinary.com/v1_1/$_cloudName/image/upload";

    try {
      // Read bytes first to ensure the file isn't "locked" by the OS during upload
      final Uint8List bytes = await imageFile.readAsBytes();

      FormData formData = FormData.fromMap({
        // Use fromBytes instead of fromFile
        'file': MultipartFile.fromBytes(bytes, filename: "upload.jpg"),
        'upload_preset': _uploadPreset,
        'folder': folderName,
      });

      final response = await _dio.post(
        url,
        data: formData,
        onSendProgress: (sent, total) {
          debugPrint("LOKKO_PROGRESS: ${(sent / total * 100).toInt()}%");
        },
      );

      if (response.statusCode == 200) {
        return response.data['public_id'];
      }
    } catch (e) {
      debugPrint("LOKKO_UPLOAD_ERROR: $e");
    }
    return null;
  }

  static String getWatermarkedUrl(String imageId) {
    final String cloudName = "dcrnhyalb";
    final String logoId = "lokko_logo"; // Make sure this matches your uploaded logo name

    return "https://res.cloudinary.com/$cloudName/image/upload/"
        "f_auto,q_auto:best,w_1080/" // Main image settings
        "l_$logoId,o_40,w_180,g_south_east,x_20,y_20/" // Watermark settings
        "$imageId";
  }

  static String getWatermarkedProductImage(String imageId) {
    const String logoId = "mwofx9dzo1jbvyzypitc";

    // 1. Clean the ID from full URLs
    String cleanId = imageId;
    if (imageId.contains('/upload/')) {
      cleanId = imageId.split('/upload/').last;
      if (cleanId.contains('/')) {
        var parts = cleanId.split('/');
        cleanId = (parts.length >= 2) ? "${parts[parts.length - 2]}/${parts.last}" : parts.last;
      }
    }

    // URL BREAKDOWN:
    // Layer 1 (Logo): l_samples:logo_123,o_30,w_80,g_south_east,x_130,y_20
    // Layer 2 (Text): l_text:Arial_40_bold:LOKKO,co_white,o_30,g_south_east,x_20,y_35

    return "https://res.cloudinary.com/dcrnhyalb/image/upload/"
        "w_800,q_auto:eco,f_auto/" // Base Image
        "l_$logoId,o_30,w_80,g_south_east,x_150,y_20/" // Logo (Pushed further left with x_150)
        "l_text:Ubuntu_40_bold:LOKKO,co_white,o_30,g_south_east,x_20,y_35/" // Text (On the right)
        "$cleanId";
  }
}