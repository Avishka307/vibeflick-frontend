import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

/// ✅ Background Upload Service - Singleton
/// Handles uploads in background and notifies listeners
class BackgroundUploadService {
  static final BackgroundUploadService _instance = BackgroundUploadService._internal();
  factory BackgroundUploadService() => _instance;
  BackgroundUploadService._internal();

  // Upload state
  final ValueNotifier<UploadState> uploadState = ValueNotifier(UploadState.idle);
  final ValueNotifier<int> uploadProgress = ValueNotifier(0);
  final ValueNotifier<String> uploadStatus = ValueNotifier('');

  File? currentThumbnail;
  bool isUploading = false;

  // Constants
  static const String BACKEND_URL = "https://avishka-tiktok-api.zeabur.app";
  static const String CLOUDINARY_CLOUD_NAME = "do5mpjsoh";

  /// Start background upload
  Future<void> startUpload({
    required File mediaFile,
    required String title,
    required String description,
    required bool isVideo,
    required String userId,
    required String username,
    required String userEmail,
    required String privacy,
    required List<String> hashtags,
    Map<String, dynamic>? additionalOptions,
  }) async {
    if (isUploading) {
      debugPrint('⚠️ Upload already in progress');
      return;
    }

    isUploading = true;
    currentThumbnail = mediaFile;
    uploadState.value = UploadState.uploading;
    uploadProgress.value = 0;
    uploadStatus.value = 'Starting upload...';

    try {
      // Step 1: Compress
      uploadProgress.value = 10;
      uploadStatus.value = 'Compressing media...';
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 2: Upload to Cloudinary
      uploadProgress.value = 20;
      uploadStatus.value = 'Uploading to cloud...';

      final cloudinary = CloudinaryPublic(
        CLOUDINARY_CLOUD_NAME,
        'user_uploads',
        cache: false,
      );

      final mimeType = lookupMimeType(mediaFile.path);
      final isVideoFile = mimeType != null && mimeType.startsWith('video');

      CloudinaryResponse? uploadResult;

      uploadResult = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          mediaFile.path,
          resourceType: isVideoFile
              ? CloudinaryResourceType.Video
              : CloudinaryResourceType.Image,
        ),
      );

      uploadProgress.value = 70;
      uploadStatus.value = 'Processing...';

      // Apply transformations
      final originalUrl = uploadResult.secureUrl;
      final optimizedUrl = _applyCloudinaryTransformations(originalUrl, isVideoFile);

      debugPrint('✅ Uploaded to Cloudinary: $optimizedUrl');

      // Step 3: Send to backend
      uploadProgress.value = 80;
      uploadStatus.value = 'Saving post...';

      await _sendPostToBackend(
        mediaUrl: optimizedUrl,
        publicId: uploadResult.publicId,
        title: title,
        description: description,
        mediaType: isVideo ? 'video' : 'image',
        userId: userId,
        username: username,
        userEmail: userEmail,
        privacy: privacy,
        hashtags: hashtags,
        additionalOptions: additionalOptions,
      );

      // Success!
      uploadProgress.value = 100;
      uploadStatus.value = 'Upload complete!';
      uploadState.value = UploadState.success;

      debugPrint('✅ Upload completed successfully');

      // Auto-dismiss after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      _reset();
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      uploadState.value = UploadState.failed;
      uploadStatus.value = 'Upload failed';
      isUploading = false;
    }
  }

  String _applyCloudinaryTransformations(String cloudinaryUrl, bool isVideo) {
    try {
      if (isVideo) {
        final transformations = 'q_auto,f_auto,c_limit,w_1080,vc_h264,ac_aac';
        if (cloudinaryUrl.contains('/upload/')) {
          return cloudinaryUrl.replaceFirst('/upload/', '/upload/$transformations/');
        }
      } else {
        final transformations = 'q_auto,f_auto,c_limit,w_1080';
        if (cloudinaryUrl.contains('/upload/')) {
          return cloudinaryUrl.replaceFirst('/upload/', '/upload/$transformations/');
        }
      }
      return cloudinaryUrl;
    } catch (e) {
      return cloudinaryUrl;
    }
  }

  Future<void> _sendPostToBackend({
    required String mediaUrl,
    required String publicId,
    required String title,
    required String description,
    required String mediaType,
    required String userId,
    required String username,
    required String userEmail,
    required String privacy,
    required List<String> hashtags,
    Map<String, dynamic>? additionalOptions,
  }) async {
    final hashtagsString = hashtags.join(',');

    String backendPrivacy = privacy.toLowerCase();
    if (backendPrivacy == 'only me') {
      backendPrivacy = 'onlyme';
    }

    final requestBody = {
      'uid': userId,
      'username': username,
      'user_email': userEmail,
      'media_url': mediaUrl,
      'type': mediaType,
      'cloudinary_public_id': publicId,
      'title': title,
      'description': description,
      'who_can_view': backendPrivacy,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'hashtags': hashtagsString,
      'allowDuet': additionalOptions?['allowDuet'] ?? true,
      'allowSave': additionalOptions?['allowSave'] ?? true,
      'allowComment': additionalOptions?['allowComment'] ?? true,
      'saveToDevice': additionalOptions?['saveToDevice'] ?? false,
      'mentioned_friends': additionalOptions?['mentioned_friends'] ?? '[]',
    };

    debugPrint('📤 Sending to backend: ${jsonEncode(requestBody)}');

    final response = await http.post(
      Uri.parse('$BACKEND_URL/uploadMedia'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode != 200 || responseData['success'] != true) {
      throw Exception(responseData['message'] ?? 'Upload failed');
    }
  }

  /// Retry failed upload
  Future<void> retryUpload() async {
    if (uploadState.value != UploadState.failed) return;
    // Reset and retry with same parameters
    _reset();
    uploadState.value = UploadState.uploading;
  }

  /// Cancel upload
  void cancelUpload() {
    if (!isUploading) return;
    _reset();
  }

  void _reset() {
    isUploading = false;
    uploadState.value = UploadState.idle;
    uploadProgress.value = 0;
    uploadStatus.value = '';
    currentThumbnail = null;
  }
}

enum UploadState {
  idle,
  uploading,
  success,
  failed,
}