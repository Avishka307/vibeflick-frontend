/// lib/services/firestore_thumbnail_service.dart
/// Firestore media_posts collection එකෙන් thumbnail_url fetch කරන service
/// videos_search_tab.dart වෙනස් කරන්නේ නැතුව VideoGridItem වලට pass කරන්න

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreThumbnailService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Single video එකක thumbnail fetch කරනවා
  /// [videoId] = Algolia objectID / Firestore document ID
  /// [uid] = video owner's user ID
  static Future<String?> getThumbnailUrl({
    required String videoId,
    required String uid,
  }) async {
    try {
      // 1️⃣ Direct document ID lookup (fastest)
      final doc = await _db
          .collection('media_posts')
          .doc(videoId)
          .get();

      if (doc.exists) {
        final url = doc.data()?['thumbnail_url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }

      // 2️⃣ uid + videoId query fallback
      final query = await _db
          .collection('media_posts')
          .where('uid', isEqualTo: uid)
          .where(FieldPath.documentId, isEqualTo: videoId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.data()['thumbnail_url'] as String?;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Batch fetch — video list එකක thumbnails එකවර ගන්නවා (efficient)
  /// Returns Map<videoId, thumbnailUrl>
  static Future<Map<String, String>> getBatchThumbnails(
      List<Map<String, dynamic>> videos,
      ) async {
    final Map<String, String> results = {};
    if (videos.isEmpty) return results;

    try {
      // Firestore 'whereIn' limit එක 30 — chunk කරනවා
      final ids = videos.map((v) => v['id'] as String).where((id) => id.isNotEmpty).toList();
      const chunkSize = 30;

      for (int i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.skip(i).take(chunkSize).toList();

        final snapshot = await _db
            .collection('media_posts')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          final url = doc.data()['thumbnail_url'] as String?;
          if (url != null && url.isNotEmpty) {
            results[doc.id] = url;
          }
        }
      }
    } catch (e) {
      // silent fail — Algolia thumbnail_url fallback use කරයි
    }

    return results;
  }
}