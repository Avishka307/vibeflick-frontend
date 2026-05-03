// lib/screens/settings/report_problem_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // 🆕 Image compression

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({Key? key}) : super(key: key);

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Login Issue';
  File? _screenshot;
  bool _isSubmitting = false;

  // 🆕 Internet connection state
  bool _hasInternetConnection = true;
  bool _showNoInternetToast = false;

  // 🔥 Appwrite Configuration
  late Client _client;
  late Storage _storage;
  late Databases _databases;

  // ⚠️ TODO: මේ values ටික ඔයාගේ Appwrite credentials වලින් replace කරන්න
  static const String APPWRITE_ENDPOINT = 'https://sgp.cloud.appwrite.io/v1';
  static const String APPWRITE_PROJECT_ID = '699097b80017e2b33ca5';
  static const String APPWRITE_DATABASE_ID = 'problem_reports';
  static const String APPWRITE_COLLECTION_ID = 'reports_collection';
  static const String APPWRITE_BUCKET_ID = 'problem_reports';

  final List<String> _categories = [
    'Login Issue',
    'Upload Failed',
    'App Crash',
    'Video Playback',
    'Profile Issue',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAppwrite();
  }

  // 🔧 Appwrite Initialize කරන්න
  void _initializeAppwrite() {
    _client = Client()
        .setEndpoint(APPWRITE_ENDPOINT)
        .setProject(APPWRITE_PROJECT_ID);

    _storage = Storage(_client);
    _databases = Databases(_client);

    debugPrint('✅ Appwrite initialized');
  }

  // 🆕 NEW: Check internet connectivity
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        setState(() {
          _hasInternetConnection = true;
        });
        return true;
      }
    } catch (e) {
      setState(() {
        _hasInternetConnection = false;
      });
      _showNoInternetConnection();
      return false;
    }
    return false;
  }

  // 🆕 NEW: Show "No Internet" toast
  void _showNoInternetConnection() {
    if (!_showNoInternetToast) {
      setState(() {
        _showNoInternetToast = true;
        _hasInternetConnection = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 12),
              Text('No internet connection'),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showNoInternetToast = false;
          });
        }
      });
    }
  }

  Future<void> _pickScreenshot() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _screenshot = File(image.path);
      });
    }
  }

  // 🆕 Compress image before upload
  Future<File?> _compressImage(File imageFile) async {
    try {
      debugPrint('🖼️ Starting image compression...');

      final targetPath = '${imageFile.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1080,
        minHeight: 1920,
      );

      if (compressedFile != null) {
        final originalSize = imageFile.lengthSync();
        final compressedSize = File(compressedFile.path).lengthSync();

        debugPrint('✅ Image compressed successfully!');
        debugPrint('   Original: ${_formatFileSize(originalSize)}');
        debugPrint('   Compressed: ${_formatFileSize(compressedSize)}');

        return File(compressedFile.path);
      }

      debugPrint('⚠️ Compression returned null, using original');
      return imageFile;
    } catch (e) {
      debugPrint('❌ Image compression error: $e');
      return imageFile;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const units = ["B", "KB", "MB", "GB"];
    int digitGroups = (bytes.bitLength - 1) ~/ 10;
    return '${(bytes / (1 << (digitGroups * 10))).toStringAsFixed(1)} ${units[digitGroups]}';
  }

  // 📸 Screenshot Appwrite Storage එකට upload කරන්න
  Future<String?> _uploadScreenshot() async {
    if (_screenshot == null) return null;

    try {
      debugPrint('📸 Starting screenshot upload...');

      // 🆕 Compress image before upload
      final compressedImage = await _compressImage(_screenshot!);

      if (compressedImage == null) {
        throw Exception('Image compression failed');
      }

      final file = await _storage.createFile(
        bucketId: APPWRITE_BUCKET_ID,
        fileId: ID.unique(),
        file: InputFile.fromPath(
          path: compressedImage.path,
          filename: 'report_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      debugPrint('✅ Screenshot uploaded: ${file.$id}');
      return file.$id;
    } catch (e) {
      debugPrint('❌ Screenshot upload failed: $e');
      rethrow;
    }
  }

  // 💾 Report data Appwrite Database එකට save කරන්න
  Future<void> _saveReportToDatabase(String? screenshotId) async {
    try {
      // Firebase වලින් current user ගන්න
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('💾 Saving report to database...');
      debugPrint('   Category: $_selectedCategory');
      debugPrint('   Reporter UID: ${currentUser.uid}');
      debugPrint('   Screenshot ID: ${screenshotId ?? "None"}');

      final reportData = {
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'screenshot_id': screenshotId ?? '',
        'reporter_firebase_uid': currentUser.uid,
        'reporter_email': currentUser.email ?? 'Unknown',
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      final document = await _databases.createDocument(
        databaseId: APPWRITE_DATABASE_ID,
        collectionId: APPWRITE_COLLECTION_ID,
        documentId: ID.unique(),
        data: reportData,
      );

      debugPrint('✅ Report saved: ${document.$id}');
    } catch (e) {
      debugPrint('❌ Failed to save report: $e');
      rethrow;
    }
  }

  // 🚀 Submit කරන main function එක
  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      // 🆕 STEP 0: Check internet connection first
      final hasInternet = await _checkInternetConnection();
      if (!hasInternet) {
        debugPrint('❌ No internet connection');
        return; // Stop execution if no internet
      }

      setState(() {
        _isSubmitting = true;
      });

      try {
        // 🎯 STEP 1: Screenshot upload කරන්න (තියෙනවනම්)
        String? screenshotId;
        if (_screenshot != null) {
          screenshotId = await _uploadScreenshot();
        }

        // 🎯 STEP 2: Report data database එකට save කරන්න
        await _saveReportToDatabase(screenshotId);

        // 🎯 STEP 3: Success message පෙන්වලා navigate back කරන්න
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Problem reported successfully!'),
              backgroundColor: Color(0xFF43E97B), // 🎨 කොළ පාට
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('❌ Submit report error: $e');

        if (mounted) {
          // 🆕 Better error messages
          String errorMessage = 'Failed to submit report';

          if (e.toString().contains('network') ||
              e.toString().contains('connection')) {
            errorMessage = 'Network error. Please check your connection';
          } else if (e.toString().contains('timeout')) {
            errorMessage = 'Request timeout. Please try again';
          } else if (e.toString().contains('User not authenticated')) {
            errorMessage = 'Please login to report a problem';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: const Color(0xFFFF3B5C), // 🔴 රතු පාට error වලට
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _submitReport,
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: const Text(
          'Report a Problem',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Category Dropdown
            Text(
              'Problem Category',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue!;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Description
            Text(
              'Description',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextFormField(
                controller: _descriptionController,
                maxLines: 6,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Describe the problem in detail...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please describe the problem';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 24),

            // Screenshot
            Text(
              'Add Screenshot (Optional)',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickScreenshot,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade700,
                    style: BorderStyle.solid,
                    width: 1,
                  ),
                ),
                child: _screenshot == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Colors.grey.shade500,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add screenshot',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
                    : Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _screenshot!,
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _screenshot = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3B5C),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B5C),
                  disabledBackgroundColor: Colors.grey.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Submit Report',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}