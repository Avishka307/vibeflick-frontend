import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/media_post.dart';
import 'dart:developer' as developer;

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache systems
  static final Map<String, bool> _saveStatusCache = {};
  static final Map<String, bool> _followStatusCache = {};
  static final Map<String, int> _commentCountCache = {};
  static final Map<String, int> _lastClickTime = {};

  static String? get currentUserId => _auth.currentUser?.uid;
  static String? get currentUserName =>
      _auth.currentUser?.displayName ?? _auth.currentUser?.email;

  // Debounce logic
  static const int _debounceDuration = 1000;

  static bool canProcessClick(String key) {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _lastClickTime[key] ?? 0;

    if (currentTime - lastTime < _debounceDuration) {
      developer.log('🚫 Click ignored - debounce active for: $key');
      return false;
    }

    _lastClickTime[key] = currentTime;
    return true;
  }

  /// ✅ FIXED: Load public posts (EXACT match with Java logic)
  static Future<List<MediaPost>> loadPublicPosts({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      developer.log('===========================================');
      developer.log('🌍 LOADING PUBLIC POSTS FOR FORYOU FEED');
      developer.log('Current user ID: $currentUserId');
      developer.log('Limit: $limit');
      developer.log('===========================================');

      // 🔍 STEP 1: First check what's in the database
      final testQuery = await _db.collection('media_posts').limit(1).get();
      developer.log('📊 Database check: ${testQuery.docs.isNotEmpty ? "HAS DOCUMENTS" : "EMPTY"}');

      if (testQuery.docs.isNotEmpty) {
        final sampleDoc = testQuery.docs.first;
        final sampleData = sampleDoc.data();
        developer.log('📄 Sample document fields: ${sampleData.keys.toList()}');
        developer.log('   - who_can_view: ${sampleData['who_can_view']}');
        developer.log('   - is_active: ${sampleData['is_active']}');
        developer.log('   - type: ${sampleData['type']}');
      }

      // 🔍 STEP 2: Build query (EXACT Java logic)
      Query query = _db
          .collection('media_posts')
          .where('who_can_view', isEqualTo: 'public')  // ✅ EXACT field name
          .where('is_active', isEqualTo: true)         // ✅ EXACT field name
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      developer.log('🔍 Executing query with filters:');
      developer.log('   - who_can_view == "public"');
      developer.log('   - is_active == true');

      final snapshot = await query.get();

      developer.log('📊 Query returned: ${snapshot.docs.length} documents');

      if (snapshot.docs.isEmpty) {
        developer.log('⚠️ ========================================');
        developer.log('⚠️ NO DOCUMENTS FOUND!');
        developer.log('⚠️ Checking all documents in database...');
        developer.log('⚠️ ========================================');

        final allDocs = await _db.collection('media_posts').limit(10).get();
        developer.log('📊 Total documents in collection: ${allDocs.docs.length}');

        for (var doc in allDocs.docs) {
          final data = doc.data();
          developer.log('---');
          developer.log('Doc ID: ${doc.id}');
          developer.log('  who_can_view: ${data['who_can_view']}');
          developer.log('  is_active: ${data['is_active']}');
          developer.log('  uid: ${data['uid']}');
          developer.log('  type: ${data['type']}');
          developer.log('  media_url: ${data['media_url']}');
        }

        return [];
      }

      // 🔍 STEP 3: Parse documents (EXACT Java logic)
      List<MediaPost> posts = [];
      int excludedOwnPosts = 0;
      int parseErrors = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;

          developer.log('---');
          developer.log('📄 Processing: ${doc.id}');
          developer.log('  uid: ${data['uid']}');
          developer.log('  who_can_view: ${data['who_can_view']}');
          developer.log('  is_active: ${data['is_active']}');
          developer.log('  type: ${data['type']}');

          final post = MediaPost.fromFirestore(doc);



          // ✅ VALIDATE post has required fields
          if (post.mediaUrl == null || post.mediaUrl!.isEmpty) {
            developer.log('⚠️ Skipping: mediaUrl is null/empty');
            continue;
          }

          posts.add(post);
          developer.log('✅ Added to posts list');

        } catch (e) {
          parseErrors++;
          developer.log('❌ Parse error: $e');
          developer.log('   Data: ${doc.data()}');
        }
      }

      developer.log('===========================================');
      developer.log('✅ POSTS LOADED SUCCESSFULLY');
      developer.log('📊 Query returned: ${snapshot.docs.length}');
      developer.log('📊 Successfully parsed: ${posts.length}');
      developer.log('🚫 Excluded (own posts): $excludedOwnPosts');
      developer.log('❌ Parse errors: $parseErrors');
      developer.log('===========================================');

      return posts;

    } catch (e, stackTrace) {
      developer.log('❌ =========================================');
      developer.log('❌ ERROR LOADING PUBLIC POSTS');
      developer.log('❌ Error: $e');
      developer.log('❌ Stack: $stackTrace');
      developer.log('❌ =========================================');
      rethrow;
    }
  }

  // ... (keep all other methods unchanged - like, save, follow, etc.)

  // Toggle like
  static Future<bool> toggleLike(String postId) async {
    if (currentUserId == null || postId.isEmpty) {
      throw Exception('User not logged in or invalid post ID');
    }

    if (!canProcessClick('like_$postId')) {
      throw Exception('Please wait before liking again');
    }

    try {
      developer.log('❤️ Toggling like for post: $postId');

      final likeRef = _db
          .collection('media_posts')
          .doc(postId)
          .collection('likes')
          .doc(currentUserId);

      final likeDoc = await likeRef.get();
      final isCurrentlyLiked = likeDoc.exists;

      if (isCurrentlyLiked) {
        await likeRef.delete();
        developer.log('💔 Post unliked: $postId');
        return false;
      } else {
        await likeRef.set({
          'uid': currentUserId,
          'username': currentUserName ?? 'Unknown User',
          'postId': postId,
          'timestamp': FieldValue.serverTimestamp(),
          'likedAt': DateTime.now().millisecondsSinceEpoch,
        });
        developer.log('❤️ Post liked: $postId');
        return true;
      }
    } catch (e) {
      developer.log('❌ Error toggling like: $e');
      rethrow;
    }
  }

  static Future<bool> getLikeStatus(String postId) async {
    if (currentUserId == null) return false;
    try {
      final likeDoc = await _db
          .collection('media_posts')
          .doc(postId)
          .collection('likes')
          .doc(currentUserId)
          .get();
      return likeDoc.exists;
    } catch (e) {
      developer.log('Error getting like status: $e');
      return false;
    }
  }

  static Stream<int> likesCountStream(String postId) {
    return _db
        .collection('media_posts')
        .doc(postId)
        .collection('likes')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  static Future<List<Map<String, String>>> getUsersWhoLiked(String postId) async {
    try {
      final likesSnapshot = await _db
          .collection('media_posts')
          .doc(postId)
          .collection('likes')
          .get();

      List<Map<String, String>> users = [];
      for (var doc in likesSnapshot.docs) {
        final data = doc.data();
        final userName = data['username'] as String?;
        final userId = data['uid'] as String?;

        if (userName != null && userId != null) {
          users.add({'username': userName, 'userId': userId});
        }
      }
      return users;
    } catch (e) {
      developer.log('Error getting users who liked: $e');
      return [];
    }
  }

  // Save functionality
  static Future<bool> toggleSave(String postId, MediaPost post) async {
    if (currentUserId == null || postId.isEmpty) {
      throw Exception('User not logged in or invalid post ID');
    }

    if (!canProcessClick('save_$postId')) {
      throw Exception('Please wait before saving again');
    }

    try {
      final saveDocId = '${currentUserId}_$postId';
      final saveRef = _db.collection('saved_posts').doc(saveDocId);
      final saveDoc = await saveRef.get();
      final isCurrentlySaved = saveDoc.exists;

      if (isCurrentlySaved) {
        await saveRef.delete();
        _saveStatusCache[postId] = false;
        return false;
      } else {
        await saveRef.set({
          'userId': currentUserId,
          'postId': postId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'postOwnerId': post.uid,
          'postOwnerName': post.username,
          'mediaUrl': post.mediaUrl,
          'mediaType': post.type,
          'description': post.description,
        });
        _saveStatusCache[postId] = true;
        return true;
      }
    } catch (e) {
      developer.log('Error toggling save: $e');
      rethrow;
    }
  }

  static Future<bool> getSaveStatus(String postId) async {
    if (currentUserId == null) return false;
    if (_saveStatusCache.containsKey(postId)) {
      return _saveStatusCache[postId]!;
    }
    try {
      final saveDocId = '${currentUserId}_$postId';
      final saveDoc = await _db.collection('saved_posts').doc(saveDocId).get();
      final isSaved = saveDoc.exists;
      _saveStatusCache[postId] = isSaved;
      return isSaved;
    } catch (e) {
      developer.log('Error getting save status: $e');
      return false;
    }
  }

  // Follow functionality
  static Future<bool> toggleFollow(String targetUserId, String targetUsername) async {
    if (currentUserId == null || targetUserId.isEmpty) {
      throw Exception('User not logged in or invalid target user');
    }
    if (currentUserId == targetUserId) {
      throw Exception('Cannot follow yourself');
    }
    if (!canProcessClick('follow_$targetUserId')) {
      throw Exception('Please wait before following again');
    }

    try {
      final followDocId = '${currentUserId}_$targetUserId';
      final followRef = _db.collection('follows').doc(followDocId);
      final followDoc = await followRef.get();
      final isCurrentlyFollowing = followDoc.exists;

      if (isCurrentlyFollowing) {
        await followRef.delete();
        _followStatusCache[targetUserId] = false;
        return false;
      } else {
        await followRef.set({
          'followerId': currentUserId,
          'followerName': currentUserName,
          'followingId': targetUserId,
          'followingName': targetUsername,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        _followStatusCache[targetUserId] = true;
        return true;
      }
    } catch (e) {
      developer.log('Error toggling follow: $e');
      rethrow;
    }
  }

  static Future<bool> getFollowStatus(String targetUserId) async {
    if (currentUserId == null) return false;
    if (_followStatusCache.containsKey(targetUserId)) {
      return _followStatusCache[targetUserId]!;
    }
    try {
      final followDocId = '${currentUserId}_$targetUserId';
      final followDoc = await _db.collection('follows').doc(followDocId).get();
      final isFollowing = followDoc.exists;
      _followStatusCache[targetUserId] = isFollowing;
      return isFollowing;
    } catch (e) {
      developer.log('Error getting follow status: $e');
      return false;
    }
  }

  static Stream<bool> followStatusStream(String targetUserId) {
    if (currentUserId == null) return Stream.value(false);
    final followDocId = '${currentUserId}_$targetUserId';
    return _db.collection('follows').doc(followDocId).snapshots().map((doc) {
      final isFollowing = doc.exists;
      _followStatusCache[targetUserId] = isFollowing;
      return isFollowing;
    });
  }

  // Comment count
  static Stream<int> commentCountStream(String postId) {
    return _db
        .collection('media_posts')
        .doc(postId)
        .collection('comments')
        .where('reply', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  // Views
  static Future<void> recordView(String postId, String postOwnerId) async {
    if (currentUserId == null || currentUserId == postOwnerId) return;
    try {
      final postRef = _db.collection('media_posts').doc(postId);
      final postDoc = await postRef.get();
      if (!postDoc.exists) return;

      final data = postDoc.data();
      final viewsUsers = (data?['viewsUsers'] as List<dynamic>?)?.cast<String>() ?? [];

      if (!viewsUsers.contains(currentUserId)) {
        await postRef.update({
          'viewsUsers': FieldValue.arrayUnion([currentUserId!]),
          'viewsCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      developer.log('Error recording view: $e');
    }
  }

  static Stream<int> viewsCountStream(String postId) {
    return _db.collection('media_posts').doc(postId).snapshots().map((doc) => (doc.data()?['viewsCount'] as int?) ?? 0);
  }

  // Notifications
  static Future<void> sendLikeNotification(String postOwnerId, String postId) async {
    if (currentUserId == null || currentUserId == postOwnerId) return;
    try {
      await _db.collection('users').doc(postOwnerId).collection('notifications').add({
        'toUserId': postOwnerId,
        'type': 'like',
        'fromUserId': currentUserId,
        'fromUserName': currentUserName ?? 'Unknown User',
        'timestamp': FieldValue.serverTimestamp(),
        'postId': postId,
        'processed': false,
      });
    } catch (e) {
      developer.log('Error sending like notification: $e');
    }
  }

  static Future<void> sendFollowNotification(String toUserId, String toUsername) async {
    if (currentUserId == null || currentUserId == toUserId) return;
    try {
      await _db.collection('users').doc(toUserId).collection('notifications').add({
        'toUserId': toUserId,
        'type': 'follow',
        'fromUserId': currentUserId,
        'fromUserName': currentUserName ?? 'Unknown User',
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
        'extraData': {'targetUsername': toUsername},
      });
    } catch (e) {
      developer.log('Error sending follow notification: $e');
    }
  }

  static Future<String?> getUserProfileImage(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      final data = userDoc.data();
      return data?['profile_picture_url'] as String? ??
          data?['profile_url'] as String? ??
          data?['profileUrl'] as String?;
    } catch (e) {
      developer.log('Error getting profile image: $e');
      return null;
    }
  }

  static void clearAllCaches() {
    _saveStatusCache.clear();
    _followStatusCache.clear();
    _commentCountCache.clear();
    _lastClickTime.clear();
    developer.log('🧹 All caches cleared');
  }
}