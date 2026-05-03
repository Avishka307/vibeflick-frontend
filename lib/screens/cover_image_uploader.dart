import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

// ✅ Cover Image Upload Helper Class - FIXED VERSION
class CoverImageUploader {
  // 🔗 Backend URL - ඔයාගේ IP එකට වෙනස් කරන්න
  static const String BASE_URL = "https://avishka-tiktok-api.zeabur.app";

  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Main function to handle cover image upload
  Future<bool> uploadCoverImage({
    required BuildContext context,
    required ImageSource source,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ User not authenticated');
        onError('User not authenticated');
        return false;
      }

      final userId = currentUser.uid;
      debugPrint('✅ User authenticated: $userId');

      // 1️⃣ Pick image from gallery or camera
      debugPrint('📸 Picking cover image from ${source == ImageSource.gallery ? "gallery" : "camera"}');

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        debugPrint('❌ No image selected');
        onError('No image selected');
        return false;
      }

      debugPrint('✅ Image picked: ${pickedFile.path}');

      // 2️⃣ Crop image to 16:9 aspect ratio
      File? imageToUpload = File(pickedFile.path);

      // ✅ CRITICAL: Verify file exists
      if (!await imageToUpload.exists()) {
        debugPrint('❌ Image file does not exist');
        onError('Image file error');
        return false;
      }

      try {
        final croppedFile = await _cropCoverImage(imageToUpload);
        if (croppedFile != null) {
          imageToUpload = croppedFile;
          debugPrint('✅ Image cropped to 16:9 successfully');
        } else {
          debugPrint('⚠️ Cropping cancelled, using original image');
        }
      } catch (cropError) {
        debugPrint('⚠️ Crop error, using original: $cropError');
      }

      // 3️⃣ Compress image
      final compressedFile = await _compressImage(imageToUpload!);

      // ✅ Verify compressed file
      if (!await compressedFile.exists()) {
        debugPrint('❌ Compressed file does not exist');
        onError('Image compression failed');
        return false;
      }

      final fileSize = compressedFile.lengthSync();
      debugPrint('✅ Image compressed: $fileSize bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');

      if (fileSize > 5 * 1024 * 1024) {
        debugPrint('⚠️ Warning: File size is large (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
        onError('Image is too large. Please select a smaller image.');
        return false;
      }

      // 4️⃣ Upload to backend (ImageKit)
      final coverUrl = await _uploadToBackend(
        compressedFile,
        userId, // ✅ Pass userId explicitly
      );

      if (coverUrl != null) {
        debugPrint('✅ Cover image uploaded successfully!');
        debugPrint('🔗 Cover URL: $coverUrl');

        onSuccess(coverUrl);
        return true;
      } else {
        onError('Failed to upload cover image');
        return false;
      }

    } catch (e, stackTrace) {
      debugPrint('❌ Error uploading cover image: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      onError('Failed to upload: ${e.toString()}');
      return false;
    }
  }

  // ✅ Crop image to 16:9 aspect ratio
  Future<File?> _cropCoverImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        compressQuality: 100,
        maxWidth: 1920,
        maxHeight: 1080,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Cover Photo',
            toolbarColor: const Color(0xFFFF3B5C),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Cover Photo',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        ],
      );

      if (croppedFile != null) {
        return File(croppedFile.path);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error cropping cover image: $e');
      return null;
    }
  }

  // ✅ Compress image - FIXED nullable type error
  Future<File> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        'compressed_cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      debugPrint('🗜️ Compressing cover image...');
      debugPrint('📊 Original size: ${file.lengthSync()} bytes');

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 60,
        minWidth: 1280,
        minHeight: 720,
        format: CompressFormat.jpeg,
      );

      if (compressedFile != null) {
        final compressedFileObj = File(compressedFile.path);
        final compressedSize = compressedFileObj.lengthSync();
        debugPrint('✅ Compressed size: $compressedSize bytes');
        debugPrint('📉 Reduction: ${((1 - compressedSize / file.lengthSync()) * 100).toStringAsFixed(1)}%');
        return compressedFileObj; // ✅ Return non-nullable File
      }

      // If compression fails, return original file
      debugPrint('⚠️ Compression returned null, using original file');
      return file;
    } catch (e) {
      debugPrint('⚠️ Compression failed, using original: $e');
      return file;
    }
  }

  // ✅ FIXED: Upload to backend with proper validation
  Future<String?> _uploadToBackend(File imageFile, String userId) async {
    try {
      // ✅ CRITICAL VALIDATION
      debugPrint('🔍 Starting upload validation...');
      debugPrint('👤 User ID: $userId');

      if (userId.isEmpty) {
        debugPrint('❌ CRITICAL ERROR: userId is empty!');
        return null;
      }

      debugPrint('📤 Uploading cover image to backend...');
      debugPrint('🔗 Backend URL: $BASE_URL');
      debugPrint('📁 Image file path: ${imageFile.path}');

      // ✅ Read file bytes
      final bytes = await imageFile.readAsBytes();

      debugPrint('📊 Image size: ${bytes.length} bytes (${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');

      if (bytes.isEmpty) {
        debugPrint('❌ CRITICAL ERROR: Image file is empty');
        return null;
      }

      // ✅ Encode to base64
      debugPrint('🔄 Encoding to base64...');
      final base64Image = base64Encode(bytes);

      debugPrint('📊 Base64 size: ${base64Image.length} characters');

      if (base64Image.isEmpty) {
        debugPrint('❌ CRITICAL ERROR: Base64 encoding failed');
        return null;
      }

      // ✅ Validate base64 format (should start with /9j/ for JPEG)
      if (!base64Image.startsWith('/9j/') && !base64Image.startsWith('iVBOR')) {
        debugPrint('⚠️ Warning: Base64 might not be a valid image format');
        debugPrint('   Base64 starts with: ${base64Image.substring(0, 10)}...');
      }

      // Get old cover fileId if exists
      debugPrint('🔍 Checking for old cover image...');
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final oldCoverFileId = userDoc.data()?['coverImageKitFileId'];

      if (oldCoverFileId != null) {
        debugPrint('🗑️ Found old cover, will delete: $oldCoverFileId');
      } else {
        debugPrint('✅ No old cover image found');
      }

      // ✅ Prepare request body
      final requestBody = {
        'userId': userId,
        'imageBase64': base64Image,
        if (oldCoverFileId != null) 'oldFileId': oldCoverFileId,
      };

      // ✅ Log request details (without full base64)
      debugPrint('📦 Request body prepared:');
      debugPrint('   userId: $userId');
      debugPrint('   imageBase64 length: ${base64Image.length}');
      debugPrint('   oldFileId: ${oldCoverFileId ?? "null"}');

      // ✅ Encode request body
      final encodedBody = json.encode(requestBody);
      debugPrint('✅ Request body encoded (size: ${encodedBody.length} bytes)');

      debugPrint('📤 Sending POST request to backend...');

      final response = await http
          .post(
        Uri.parse('$BASE_URL/api/v1/upload-cover-image'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: encodedBody,
      )
          .timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          debugPrint('❌ Request timed out after 120 seconds');
          throw Exception('Connection timed out after 120 seconds');
        },
      );

      debugPrint('📡 Upload response received: ${response.statusCode}');
      debugPrint('📡 Response headers: ${response.headers}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final coverUrl = data['imageUrl'];
          final fileId = data['fileId'];

          debugPrint('✅ Cover uploaded successfully!');
          debugPrint('🔗 URL: $coverUrl');
          debugPrint('📁 File ID: $fileId');

          // ✅ Update Firestore with cover URL
          debugPrint('💾 Updating Firestore...');
          await _firestore.collection('users').doc(userId).update({
            'cover_image_url': coverUrl,
            'coverImageUrl': coverUrl,
            'cover_url': coverUrl,
            'coverImageKitFileId': fileId,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          debugPrint('✅ Firestore updated successfully');

          return coverUrl;
        } else {
          debugPrint('❌ Backend returned success=false');
          debugPrint('❌ Error message: ${data['message']}');
          throw Exception(data['message'] ?? 'Upload failed');
        }
      } else {
        debugPrint('❌ Server returned error status: ${response.statusCode}');
        debugPrint('❌ Response: ${response.body}');
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Upload error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  // ✅ Remove cover image
  Future<bool> removeCoverImage(String userId) async {
    try {
      debugPrint('🗑️ Removing cover image...');

      // Get current cover fileId
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final coverFileId = userDoc.data()?['coverImageKitFileId'];

      if (coverFileId != null) {
        debugPrint('🗑️ Deleting from ImageKit...');
        // Delete from ImageKit
        final response = await http.post(
          Uri.parse('$BASE_URL/api/v1/delete-cover-image'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': userId,
            'fileId': coverFileId,
          }),
        ).timeout(const Duration(seconds: 10));

        debugPrint('📡 Delete response: ${response.statusCode}');
      }

      // Delete from Firestore
      debugPrint('🗑️ Deleting from Firestore...');
      await _firestore.collection('users').doc(userId).update({
        'cover_image_url': FieldValue.delete(),
        'coverImageUrl': FieldValue.delete(),
        'cover_url': FieldValue.delete(),
        'coverImageKitFileId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Cover image removed successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Remove error: $e');
      return false;
    }
  }
}