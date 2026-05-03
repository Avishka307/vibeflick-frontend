import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async'; // ✅ TimeoutException සඳහා
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

// Import your edit screens
import 'activity_name_edit.dart';
import 'notification_service.dart';
import 'user_name_edit.dart';
import 'activity_bio_edit.dart';
import 'gender_edit.dart';
import 'birthday_edit.dart';   // ✅ New
import 'region_edit.dart';     // ✅ New

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool isLoading = true;
  bool isSaving = false;
  bool isUploadingImage = false;

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
// ✅ NotificationService instance
  final NotificationService _notificationService = NotificationService();
  // 🔗 Backend URL - ඔයාගේ IP එකට වෙනස් කරන්න

  static const String BASE_URL = "https://avishka-tiktok-api.zeabur.app";

  // Profile data
  String name = '';
  String username = '';
  String gender = 'Male';
  String bio = '';
  String birthday = '1999-09-19';  // ✅ New
  String region = 'Sri Lanka';      // ✅ New
  String? profileImageUrl;
  String? oldImageKitFileId;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _testBackendConnection(); // ✅ Test connection on start
  }

  // 🔍 Test Backend Connection
  Future<void> _testBackendConnection() async {
    try {
      print('🔍 Testing backend connection...');

      final response = await http
          .get(Uri.parse('$BASE_URL/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print('✅ Backend is reachable!');
        print('📡 Response: ${response.body}');
      } else {
        print('❌ Backend returned: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Backend not reachable: $e');
      print('⚠️ Make sure:');
      print('   1. Backend server is running (node server.js)');
      print('   2. BASE_URL has correct IP address');
      print('   3. Phone and computer are on same WiFi');
    }
  }

  Future<void> _loadProfileData() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;

        setState(() {
          name = data['name'] ?? 'Jacob West';
          username = data['username'] ?? '@jacob_w123';
          gender = data['gender'] ?? 'Male';
          bio = data['bio'] ?? 'Add a bio to your profile';
          birthday = data['birthday'] ?? '1999-09-19';   // ✅ New
          region = data['region'] ?? 'Sri Lanka';         // ✅ New
          // ✅ Check multiple possible field names for profile image
          profileImageUrl = data['profileImageUrl'] ??
              data['profile_picture_url'] ??
              data['profile_url'] ??
              data['profileUrl'];
          oldImageKitFileId = data['imageKitFileId'];
          isLoading = false;
        });
      } else {
        await _firestore.collection('users').doc(currentUser.uid).set({
          'name': 'Jacob West',
          'username': '@jacob_w123',
          'gender': 'Male',
          'bio': 'Add a bio to your profile',
          'birthday': '1999-09-19',   // ✅ New
          'region': 'Sri Lanka',       // ✅ New
          'email': currentUser.email,
          'createdAt': Timestamp.now(),
        });

        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error loading profile data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load profile data')),
        );
        setState(() => isLoading = false);
      }
    }
  }

// ✅ UPDATED _handleSave() – profile complete notification trigger added
  Future<void> _handleSave() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() => isSaving = true);

    try {
      // 1. Save profile data to Firestore
      await _firestore.collection('users').doc(currentUser.uid).update({
        'name': name,
        'username': username,
        'gender': gender,
        'bio': bio,
        'birthday': birthday,
        'region': region,
        'updatedAt': Timestamp.now(),
      });

      // ✅ 2. Check if profile is now complete → send notification once
      await _notificationService.checkAndSendProfileCompleteNotification(
        currentUser.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _handleEditPhoto() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Preview + title row ──
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFFF3B5C), width: 2),
                    ),
                    child: ClipOval(
                      child: profileImageUrl != null &&
                          profileImageUrl!.isNotEmpty
                          ? Image.network(profileImageUrl!,
                          fit: BoxFit.cover)
                          : _buildDefaultAvatar(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile Photo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Choose how to update',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Option tiles ──
              _buildPhotoOptionTile(
                icon: Icons.photo_library_rounded,
                iconBg: const Color(0xFF1E3A5F),
                iconColor: const Color(0xFF4DA3FF),
                title: 'Choose from Gallery',
                subtitle: 'Pick from your photos',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),

              const SizedBox(height: 10),

              _buildPhotoOptionTile(
                icon: Icons.camera_alt_rounded,
                iconBg: const Color(0xFF1A3D2B),
                iconColor: const Color(0xFF4CAF50),
                title: 'Take a Photo',
                subtitle: 'Use your camera',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),

              if (profileImageUrl != null) ...[
                const SizedBox(height: 10),
                _buildPhotoOptionTile(
                  icon: Icons.delete_outline_rounded,
                  iconBg: const Color(0xFF3D1A1A),
                  iconColor: const Color(0xFFFF4444),
                  title: 'Remove Photo',
                  subtitle: 'Revert to default avatar',
                  titleColor: const Color(0xFFFF4444),
                  onTap: () {
                    Navigator.pop(context);
                    _removePhoto();
                  },
                ),
              ],

              const SizedBox(height: 16),

              // ── Cancel button ──
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Cancel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// ── Helper: option tile ──────────────────────────────────
  Widget _buildPhotoOptionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color titleColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2E2E2E)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF444444), size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      print('📸 Starting image picker...');

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile == null) {
        print('❌ No image selected');
        return;
      }

      print('✅ Image picked: ${pickedFile.path}');

      // Crop image (skip if cropping fails)
      File? imageToUpload = File(pickedFile.path);

      try {
        final croppedFile = await _cropImage(imageToUpload);
        if (croppedFile != null) {
          imageToUpload = croppedFile;
          print('✅ Image cropped successfully');
        } else {
          print('⚠️ Cropping cancelled, using original image');
        }
      } catch (cropError) {
        print('⚠️ Crop error, using original: $cropError');
      }

      // Compress image
      final compressedFile = await _compressImage(imageToUpload!);
      print('✅ Image compressed: ${compressedFile.lengthSync()} bytes');

      // Upload
      await _uploadProfileImage(compressedFile);

    } catch (e) {
      print('❌ Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 100,
        maxWidth: 1000,
        maxHeight: 1000,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            toolbarColor: const Color(0xFFFF3B5C),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
          ),
        ],
      );

      if (croppedFile != null) {
        return File(croppedFile.path);
      }
      return null;
    } catch (e) {
      print('❌ Error cropping image: $e');
      return null;
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      print('🗜️ Compressing image...');
      print('📊 Original size: ${file.lengthSync()} bytes');

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 50,
        minWidth: 400,
        minHeight: 400,
      );

      if (compressedFile != null) {
        final compressedSize = File(compressedFile.path).lengthSync();
        print('✅ Compressed size: $compressedSize bytes');
        print('📉 Reduction: ${((1 - compressedSize / file.lengthSync()) * 100).toStringAsFixed(1)}%');
        return File(compressedFile.path);
      }

      return file;
    } catch (e) {
      print('⚠️ Compression failed, using original: $e');
      return file;
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      isUploadingImage = true;
      isLoading = true;
    });

    try {
      print('📤 Uploading image to backend...');
      print('🔗 Backend URL: $BASE_URL');

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      print('📊 Image size: ${bytes.length} bytes');
      print('📊 Base64 size: ${base64Image.length} characters');

      final response = await http
          .post(
        Uri.parse('$BASE_URL/api/v1/upload-profile-image'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': currentUser.uid,
          'imageBase64': base64Image,
          'oldFileId': oldImageKitFileId,
        }),
      )
          .timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException(
            'Connection timed out. Please check your internet connection and try again.',
          );
        },
      );

      print('📡 Upload response: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final imageUrl = data['imageUrl'];
          final fileId = data['fileId'];

          print('✅ Image uploaded successfully!');
          print('🔗 URL: $imageUrl');

          // ✅ ONLY update Firestore if upload was successful
          await _firestore.collection('users').doc(currentUser.uid).update({
            'profileImageUrl': imageUrl,
            'profile_picture_url': imageUrl,
            'imageKitFileId': fileId,
            'updatedAt': Timestamp.now(),
          });

          setState(() {
            profileImageUrl = imageUrl;
            oldImageKitFileId = fileId;
            isUploadingImage = false;
            isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Profile photo updated successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          throw Exception(data['message'] ?? 'Upload failed');
        }
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException catch (e) {
      print('⏱️ Timeout error: $e');

      setState(() {
        isUploadingImage = false;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⏱️ Upload timeout!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text('Please check:'),
                const Text('• Backend server is running'),
                const Text('• Phone and PC on same WiFi'),
                Text('• IP address: $BASE_URL'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } on SocketException catch (e) {
      print('🌐 Network error: $e');

      setState(() {
        isUploadingImage = false;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🌐 No internet connection! Please check your network.',
              style: TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('❌ Upload error: $e');

      setState(() {
        isUploadingImage = false;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Upload failed: ${e.toString()}',
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _removePhoto() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text('Are you sure you want to remove your profile photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      print('🗑️ Removing profile photo...');

      if (oldImageKitFileId != null) {
        final response = await http.post(
          Uri.parse('$BASE_URL/api/v1/delete-profile-image'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': currentUser.uid,
            'fileId': oldImageKitFileId,
          }),
        ).timeout(const Duration(seconds: 10));

        print('📡 Delete response: ${response.statusCode}');
      }

      await _firestore.collection('users').doc(currentUser.uid).update({
        'profileImageUrl': FieldValue.delete(),
        'profile_picture_url': FieldValue.delete(),
        'profile_url': FieldValue.delete(),
        'imageKitFileId': FieldValue.delete(),
        'updatedAt': Timestamp.now(),
      });

      setState(() {
        profileImageUrl = null;
        oldImageKitFileId = null;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo removed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Remove error: $e');
      setState(() => isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildProfilePhotoSection(),
                        const SizedBox(height: 24),
                        _buildProfileInfoCard(),
                        const SizedBox(height: 16),
                        _buildExtraInfoCard(),   // ✅ Birthday & Region card
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                padding: const EdgeInsets.all(8),
              ),
              const Expanded(
                child: Text(
                  'Edit Profile',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: isSaving
                    ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF3B5C),
                      ),
                    ),
                  ),
                )
                    : TextButton(
                  onPressed: _handleSave,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF3B5C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSection() {
    return Center(
      child: SizedBox(
        width: 150,
        height: 170,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // ── Animated gradient ring ──────────────────
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.85 + (0.15 * value),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFFFF3B5C),
                      Color(0xFFFF6B35),
                      Color(0xFFFFB800),
                      Color(0xFFFF3B5C),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: SizedBox(
                      width: 128,
                      height: 128,
                      child: profileImageUrl != null && profileImageUrl!.isNotEmpty
                          ? Image.network(
                        profileImageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildShimmerAvatar();
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            _buildDefaultAvatar(),
                      )
                          : _buildDefaultAvatar(),
                    ),
                  ),
                ),
              ),
            ),

            // ── Camera button ───────────────────────────
            Positioned(
              bottom: 0,
              child: GestureDetector(
                onTap: isUploadingImage ? null : _handleEditPhoto,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isUploadingImage
                        ? const LinearGradient(
                      colors: [Color(0xFF888888), Color(0xFF666666)],
                    )
                        : const LinearGradient(
                      colors: [Color(0xFFFF3B5C), Color(0xFFFF6B35)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF3B5C).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: isUploadingImage
                      ? const SizedBox(
                    width: 80,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Uploading',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                      : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Edit Photo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildEditItem(
            title: 'Name',
            value: name,
            onTap: () => _navigateToNameEdit(),
            showDivider: true,
          ),
          _buildEditItem(
            title: 'Username',
            value: username,
            onTap: () => _navigateToUsernameEdit(),
            showDivider: true,
          ),
          _buildEditItem(
            title: 'Gender',
            value: gender,
            onTap: () => _navigateToGenderEdit(),
            showDivider: true,
          ),
          _buildEditItem(
            title: 'Bio',
            value: bio,
            onTap: () => _navigateToBioEdit(),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ✅ New Card for Birthday & Region
  Widget _buildExtraInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildEditItem(
            title: 'Birthday',
            value: birthday,
            onTap: () => _navigateToBirthdayEdit(),
            showDivider: true,
          ),
          _buildEditItem(
            title: 'Region',
            value: region,
            onTap: () => _navigateToRegionEdit(),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildEditItem({
    required String title,
    required String value,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF757575),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFFFF3B5C),
                      strokeWidth: 3,
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF3B5C), Color(0xFFFF6B35)],
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isUploadingImage ? 'Uploading Photo...' : 'Loading...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isUploadingImage) ...[
                const SizedBox(height: 6),
                const Text(
                  'Please wait a moment',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildShimmerAvatar() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Color.lerp(const Color(0xFFE0E0E0),
                    const Color(0xFFF5F5F5), value)!,
                Color.lerp(const Color(0xFFF5F5F5),
                    const Color(0xFFE0E0E0), value)!,
              ],
            ),
          ),
        );
      },
      onEnd: () => setState(() {}),
    );
  }
  void _navigateToNameEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NameEditActivityScreen(),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        name = result;
      });
    }
  }

  void _navigateToUsernameEdit() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserNameEditScreen(
          currentUsername: username,
          userId: currentUser.uid,
        ),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        username = result;
      });
    }
  }

  void _navigateToGenderEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenderEditScreen(
          currentGender: gender,
        ),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        gender = result;
      });
    }
  }

  void _navigateToBioEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BioEditActivityScreen(
          currentBio: bio,
        ),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        bio = result;
      });
    }
  }

  // ✅ Navigate to Birthday Edit
  void _navigateToBirthdayEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BirthdayEditScreen(
          currentBirthday: birthday,
        ),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        birthday = result;
      });
    }
  }

  // ✅ Navigate to Region Edit
  void _navigateToRegionEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegionEditScreen(
          currentRegion: region,
        ),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        region = result;
      });
    }
  }

  // 🎨 Build default avatar with user initials
  Widget _buildDefaultAvatar() {
    try {
      return Image.asset(
        'assets/default_profile_pic.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildColoredAvatar();
        },
      );
    } catch (e) {
      return _buildColoredAvatar();
    }
  }

  Widget _buildColoredAvatar() {
    final displayName = name.isNotEmpty ? name : username;
    final initials = _getInitials(displayName);
    final color = _getAvatarColor(displayName);

    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  String _getInitials(String text) {
    if (text.isEmpty) return 'U';

    final cleanText = text.replaceAll('@', '').trim();

    final words = cleanText.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return (words[0][0] + words[words.length - 1][0]).toUpperCase();
    }

    return cleanText.length >= 2
        ? cleanText.substring(0, 2).toUpperCase()
        : cleanText[0].toUpperCase();
  }

  Color _getAvatarColor(String text) {
    final colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FECA57',
      '#FF9FF3', '#54A0FF', '#5F27CD', '#00D2D3', '#FF9F43',
      '#10AC84', '#EE5A24', '#0984E3', '#A29BFE', '#FD79A8',
      '#E17055', '#81ECEC', '#74B9FF', '#FDCB6E', '#6C5CE7',
    ];

    final hash = text.hashCode.abs();
    final colorHex = colors[hash % colors.length];
    return Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
  }
}

