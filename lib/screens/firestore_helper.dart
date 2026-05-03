import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/media_post.dart';


class FirestoreHelper {
  static const String _tag = "FirestoreHelper";

  /// Generalized method: load posts for a user with allowed visibility
  static Future<void> loadUserPosts({
    required String profileUid,
    required List<String> whoCanViewList,
    required int limit,
    required ValueEventListener listener,
  }) async {
    // 🔍 DEBUG: Query parameters
    print("=== loadUserPosts Debug ===");
    print("Profile UID: $profileUid");
    print("Allowed view types: $whoCanViewList");
    print("Limit: $limit");

    try {
      final db = FirebaseFirestore.instance;
      Query query = db
          .collection("media_posts")
          .where("uid", isEqualTo: profileUid)
          .where("is_active", isEqualTo: true);

      if (whoCanViewList.length > 1) {
        // 🔍 DEBUG: Using whereIn for multiple values
        print("Using whereIn with: $whoCanViewList");
        query = query.where("who_can_view", whereIn: whoCanViewList);
      } else if (whoCanViewList.length == 1) {
        // 🔍 DEBUG: Using whereEqualTo for single value
        print("Using whereEqualTo with: ${whoCanViewList[0]}");
        query = query.where("who_can_view", isEqualTo: whoCanViewList[0]);
      }

      query = query.orderBy("timestamp", descending: true).limit(limit);

      // 🔍 DEBUG: Executing query
      print("Executing Firestore query...");

      final querySnapshot = await query.get();

      // 🔍 DEBUG: Query results
      print("✅ Query successful!");
      print("Total documents returned: ${querySnapshot.docs.length}");

      List<MediaPost> posts = [];
      for (var doc in querySnapshot.docs) {
        try {
          MediaPost post = MediaPost.fromFirestore(doc);
          posts.add(post);

          // 🔍 DEBUG: Each post details
          print("Post ID: ${doc.id}");
          print("  - who_can_view: ${post.whoCanView}");
          print("  - uid: ${post.uid}");
          print("  - is_active: ${post.isActive}");
        } catch (e) {
          print("⚠️ Failed to convert document to MediaPost: ${doc.id}");
        }
      }

      print("Final posts list size: ${posts.length}");
      listener.onLoaded(posts);
    } catch (e) {
      // 🔍 DEBUG: Query failed
      print("❌ Firestore query FAILED: ${e.toString()}");
      listener.onError(e as Exception);
    }
  }

  /// Load public posts (excludes current user's posts)
  static Future<void> loadPublicPosts({
    String? excludeUserId,
    required int limit,
    required ValueEventListener listener,
  }) async {
    print("=== loadPublicPosts Debug ===");
    print("Exclude User ID: $excludeUserId");
    print("Limit: $limit");

    try {
      final db = FirebaseFirestore.instance;
      Query query = db
          .collection("media_posts")
          .where("who_can_view", isEqualTo: "public")
          .where("is_active", isEqualTo: true)
          .orderBy("timestamp", descending: true)
          .limit(limit);

      final querySnapshot = await query.get();
      print("✅ Public posts query successful: ${querySnapshot.docs.length} documents");

      List<MediaPost> posts = [];
      for (var doc in querySnapshot.docs) {
        try {
          MediaPost post = MediaPost.fromFirestore(doc);

          // 🔍 DEBUG: Check each post
          print("Processing post ID: ${post.id}");
          print("Post UID: ${post.uid}");
          print("Exclude UID: $excludeUserId");

          // ✅ EXCLUDE current user's posts from ForYou feed
          if (excludeUserId != null && excludeUserId == post.uid) {
            print("🚫 EXCLUDING current user's post: ${post.id}");
            continue; // Skip this post
          }

          print("✅ INCLUDING post from other user: ${post.id}");
          posts.add(post);
        } catch (e) {
          print("⚠️ Failed to convert document: ${doc.id}");
        }
      }

      print("Final posts count after filtering: ${posts.length}");
      print("📝 NOTE: Current user's posts have been excluded");

      listener.onLoaded(posts);
    } catch (e) {
      print("❌ Public posts query FAILED: ${e.toString()}");
      listener.onError(e as Exception);
    }
  }

  /// ✅ NEW: Load posts from users that current user is following
  static Future<void> loadFollowingUsersPosts({
    required String currentUserId,
    required int limit,
    required ValueEventListener listener,
  }) async {
    print("=== loadFollowingUsersPosts Debug ===");
    print("Current User ID: $currentUserId");
    print("Limit: $limit");

    if (currentUserId.isEmpty) {
      print("❌ Current user ID is null or empty");
      listener.onError(Exception("User not logged in"));
      return;
    }

    try {
      final db = FirebaseFirestore.instance;

      // First, get list of users that current user is following
      final followSnapshot = await db
          .collection("follows")
          .where("followerId", isEqualTo: currentUserId)
          .get();

      print("Found ${followSnapshot.docs.length} users being followed");

      if (followSnapshot.docs.isEmpty) {
        print("📭 No following users found");
        listener.onLoaded([]);
        return;
      }

      List<String> followingUserIds = [];
      for (var doc in followSnapshot.docs) {
        String? followingId = doc.get("followingId") as String?;
        if (followingId != null) {
          followingUserIds.add(followingId);
          print("Following user: $followingId (${doc.get("followingName")})");
        }
      }

      if (followingUserIds.isEmpty) {
        print("📭 No valid following user IDs found");
        listener.onLoaded([]);
        return;
      }

      // Load posts from these users
      await _loadPostsFromSpecificUsers(
        userIds: followingUserIds,
        limit: limit,
        listener: listener,
      );
    } catch (e) {
      print("❌ Failed to load following users: ${e.toString()}");
      listener.onError(e as Exception);
    }
  }

  /// ✅ NEW: Load posts from specific list of users (handles Firestore whereIn limit of 10)
  static Future<void> _loadPostsFromSpecificUsers({
    required List<String> userIds,
    required int limit,
    required ValueEventListener listener,
  }) async {
    print("🔍 Loading posts from ${userIds.length} specific users");

    final db = FirebaseFirestore.instance;

    // Split into chunks of 10 (Firestore whereIn limit)
    List<List<String>> chunks = [];
    for (int i = 0; i < userIds.length; i += 10) {
      chunks.add(userIds.sublist(i, (i + 10 > userIds.length) ? userIds.length : i + 10));
    }

    List<MediaPost> allPosts = [];
    int completedChunks = 0;

    print("Split into ${chunks.length} chunks for querying");

    for (var chunk in chunks) {
      print("Querying chunk with ${chunk.length} users: $chunk");

      try {
        final querySnapshot = await db
            .collection("media_posts")
            .where("uid", whereIn: chunk)
            .where("is_active", isEqualTo: true)
            .where("who_can_view", whereIn: ["public", "followers"])
            .orderBy("timestamp", descending: true)
            .limit((limit ~/ chunks.length) + 10)
            .get();

        print("✅ Chunk query successful: ${querySnapshot.docs.length} documents");

        for (var doc in querySnapshot.docs) {
          try {
            MediaPost post = MediaPost.fromFirestore(doc);
            allPosts.add(post);
            print("Added following post: ${post.id} from ${post.username}");
          } catch (e) {
            print("⚠️ Failed to convert document: ${doc.id}");
          }
        }

        completedChunks++;
        print("Completed chunk $completedChunks/${chunks.length}");
      } catch (e) {
        print("❌ Failed to load posts from chunk: ${e.toString()}");
        completedChunks++;
      }

      if (completedChunks == chunks.length) {
        // Sort all posts by timestamp
        allPosts.sort((p1, p2) {
          int timestamp1 = _getTimestampAsMillis(p1.timestamp);
          int timestamp2 = _getTimestampAsMillis(p2.timestamp);
          return timestamp2.compareTo(timestamp1); // Descending order
        });

        // Limit final results
        if (allPosts.length > limit) {
          allPosts = allPosts.sublist(0, limit);
        }

        print("✅ Total following posts loaded and sorted: ${allPosts.length}");
        listener.onLoaded(allPosts);
      }
    }
  }

  /// ✅ NEW: Helper method to handle timestamp conversion
  static int _getTimestampAsMillis(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now().millisecondsSinceEpoch;
    }
    if (timestamp is Timestamp) {
      return timestamp.millisecondsSinceEpoch;
    }
    if (timestamp is int) {
      return timestamp;
    }
    if (timestamp is DateTime) {
      return timestamp.millisecondsSinceEpoch;
    }
    return DateTime.now().millisecondsSinceEpoch;
  }
}

/// Listener interface for callbacks
abstract class ValueEventListener {
  void onLoaded(List<MediaPost> posts);
  void onError(Exception e);
}