import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';

/// Helper for saving media (photo / video) to Firestore and triggering
/// the first-upload milestone notification.
///
/// Usage:
///   await MediaUploadHelper().saveMedia(
///     downloadUrl: url,
///     type: 'video',          // or 'photo'
///     thumbnailUrl: thumbUrl, // optional
///     caption: 'My caption',  // optional
///   );
class MediaUploadHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  /// Save a media item to Firestore and check for the first-upload milestone.
  Future<void> saveMedia({
    required String downloadUrl,
    required String type, // 'photo' | 'video'
    String? thumbnailUrl,
    String? caption,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ MediaUploadHelper: no signed-in user');
      return;
    }

    final uid = user.uid;

    try {
      // 1. Write the media document
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('media')
          .add({
        'url': downloadUrl,
        'type': type, // 'photo' or 'video'
        'thumbnail_url': thumbnailUrl,
        'caption': caption ?? '',
        'uid': uid,
        'uploaded_at': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Media saved: $type');

      // 2. Check if this triggers the first-media milestone
      await _notificationService.checkAndSendFirstMediaMilestone(uid);
    } catch (e) {
      debugPrint('❌ Error saving media: $e');
      rethrow;
    }
  }
}