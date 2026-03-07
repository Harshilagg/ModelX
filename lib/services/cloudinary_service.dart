import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class CloudinaryService {
  // 🔴 REPLACE THESE WITH YOUR CLOUDINARY DETAILS
  static const String _cloudName = "modelx-prod";
  static const String _uploadPreset = "portfolio_upload";

  // ================= PROFILE IMAGE =================
  static Future<String?> uploadProfileImage(
    File imageFile,
    String userId,
  ) async {
    return _uploadImage(
      imageFile: imageFile,
      publicId: "profiles/${userId}_${DateTime.now().millisecondsSinceEpoch}",
    );
  }

  // ================= PORTFOLIO IMAGE =================
  static Future<String?> uploadPortfolioImage(
    File imageFile,
    String publicId,
  ) async {
    return _uploadImage(
      imageFile: imageFile,
      publicId: "portfolio/$publicId",
    );
  }

  // ================= CORE UPLOAD =================
  static Future<String?> _uploadImage({
  required File imageFile,
  required String publicId,
}) async {
  final uri = Uri.parse(
    "https://api.cloudinary.com/v1_1/$_cloudName/image/upload",
  );

  print("📤 Uploading image to Cloudinary...");
  print("📁 File path: ${imageFile.path}");
  print("🆔 Public ID: $publicId");
  print("☁️ Cloud name: $_cloudName");
  print("🎯 Upload preset: $_uploadPreset");

  final request = http.MultipartRequest("POST", uri)
    ..fields["upload_preset"] = _uploadPreset
    ..fields["public_id"] = publicId
    ..files.add(
      await http.MultipartFile.fromPath("file", imageFile.path),
    );

  try {
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    print("📨 Status code: ${response.statusCode}");
    print("📨 Response body: $responseBody");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(responseBody);
      return decoded["secure_url"];
    } else {
      print("❌ Cloudinary upload failed");
      return null;
    }
  } catch (e) {
    print("🔥 Cloudinary exception: $e");
    return null;
  }
}
static Future<bool> deleteImage(String publicId) async {
  final uri = Uri.parse(
    "https://api.cloudinary.com/v1_1/$_cloudName/image/destroy",
  );

  final request = http.MultipartRequest("POST", uri)
    ..fields["public_id"] = publicId
    ..fields["upload_preset"] = _uploadPreset;

  try {
    final response = await request.send();
    final body = await response.stream.bytesToString();

    debugPrint("🗑 Cloudinary delete response: $body");

    return response.statusCode == 200;
  } catch (e) {
    debugPrint("🔥 Cloudinary delete error: $e");
    return false;
  }
}

}