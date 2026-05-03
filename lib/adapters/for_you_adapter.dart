import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import '../models/media_post.dart';


class ForYouAdapter {
  final BuildContext context;
  List<MediaPost> postList = [];

  // Cache maps
  final Map<String, bool> saveStatusCache = {};
  final Map<String, bool> followStatusCache = {};
  final Map<String, int> commentCountCache = {};

  // Firebase instances
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  String? currentUserId;
  String? currentUserName;

  // Constants
  static const int maxDescriptionLength = 100;
  static const int saveClickDebounceTime = 1000; // 1 second

  int lastSaveClickTime = 0;

  // Listeners
  final Map<String, StreamSubscription> followListeners = {};
  final Map<String, StreamSubscription> commentListeners = {};
  final Map<String, StreamSubscription> viewsListeners = {};

  ForYouAdapter(this.context) {
    _initializeAuth();
  }

  void _initializeAuth() {
    final user = auth.currentUser;
    if (user != null) {
      currentUserId = user.uid;
      currentUserName = user.displayName ?? user.email;
    }
  }

  void setPosts(List<MediaPost> posts) {
    postList = posts;
  }

  bool canProcessSaveClick() {
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime - lastSaveClickTime < saveClickDebounceTime) {
      debugPrint('SaveDebounce: Save click ignored - too fast');
      return false;
    }
    lastSaveClickTime = currentTime;
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  // SHOW USERS WHO LIKED
  // ═══════════════════════════════════════════════════════════
  Future<void> showUsersWhoLiked(MediaPost post) async {
    if (post.id == null) {
      _showToast('Post ID not available');
      return;
    }

    debugPrint('LikesList: Loading users who liked post: ${post.id}');

    try {
      final likesSnapshot = await db
          .collection('media_posts')
          .doc(post.id)
          .collection('likes')
          .get();

      if (likesSnapshot.docs.isEmpty) {
        _showToast('No likes yet');
        return;
      }

      List<String> userNames = [];
      List<String> userIds = [];

      for (var doc in likesSnapshot.docs) {
        final data = doc.data();
        String? userName = data['username'] as String?;
        String? userId = data['uid'] as String?;

        if (userName != null && userId != null) {
          userNames.add(userName);
          userIds.add(userId);
          debugPrint('LikesList: Found like from user: $userName (ID: $userId)');
        }
      }

      if (userNames.isEmpty) {
        _showToast('No user data found');
        return;
      }

      // Show dialog with users who liked
      _showLikedUsersDialog(userNames, userIds);
    } catch (e) {
      debugPrint('LikesList: Failed to load likes: $e');
      _showToast('Failed to load likes');
    }
  }

  void _showLikedUsersDialog(List<String> userNames, List<String> userIds) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Liked by ${userNames.length} user(s)'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: userNames.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(userNames[index]),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToUserProfile(userIds[index], userNames[index]);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToUserProfile(String uid, String username) {
    // TODO: Navigate to user profile screen
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (context) => UserProfileActivity(uid: uid, username: username)
    // ));
  }

  // ═══════════════════════════════════════════════════════════
  // COMMENT COUNT METHODS
  // ═══════════════════════════════════════════════════════════
  Future<void> loadCommentCount(MediaPost post, Function(int) onCountLoaded) async {
    if (post.id == null) {
      onCountLoaded(0);
      return;
    }

    // Check cache first
    if (commentCountCache.containsKey(post.id)) {
      onCountLoaded(commentCountCache[post.id]!);
      return;
    }

    try {
      final commentsRef = db
          .collection('media_posts')
          .doc(post.id)
          .collection('comments');

      final mainCommentsSnapshot = await commentsRef
          .where('reply', isEqualTo: false)
          .get();

      int mainCommentCount = mainCommentsSnapshot.docs.length;

      if (mainCommentCount == 0) {
        commentCountCache[post.id!] = 0;
        onCountLoaded(0);
        return;
      }

      // Count replies
      int totalCount = mainCommentCount;
      int processedCount = 0;

      for (var mainComment in mainCommentsSnapshot.docs) {
        final repliesSnapshot = await commentsRef
            .doc(mainComment.id)
            .collection('replies')
            .get();

        totalCount += repliesSnapshot.docs.length;
        processedCount++;

        if (processedCount == mainCommentCount) {
          commentCountCache[post.id!] = totalCount;
          onCountLoaded(totalCount);
          debugPrint('CommentCount: Updated count for post ${post.id}: $totalCount');
        }
      }
    } catch (e) {
      debugPrint('CommentCount: Failed to load comment count: $e');
      onCountLoaded(0);
    }
  }

  void setupCommentCountListener(MediaPost post, Function(int) onCountUpdated) {
    if (post.id == null) return;

    final commentsRef = db
        .collection('media_posts')
        .doc(post.id)
        .collection('comments');

    final listener = commentsRef
        .where('reply', isEqualTo: false)
        .snapshots()
        .listen((snapshot) async {
      int mainCommentCount = snapshot.docs.length;

      if (mainCommentCount == 0) {
        commentCountCache[post.id!] = 0;
        onCountUpdated(0);
        return;
      }

      int totalCount = mainCommentCount;
      int processedCount = 0;

      for (var mainComment in snapshot.docs) {
        final repliesSnapshot = await commentsRef
            .doc(mainComment.id)
            .collection('replies')
            .get();

        totalCount += repliesSnapshot.docs.length;
        processedCount++;

        if (processedCount == mainCommentCount) {
          commentCountCache[post.id!] = totalCount;
          onCountUpdated(totalCount);
        }
      }
    });

    commentListeners[post.id!] = listener;
  }

  // ═══════════════════════════════════════════════════════════
  // SAVE/UNSAVE POST METHODS
  // ═══════════════════════════════════════════════════════════
  Future<void> toggleSavePost(MediaPost post, Function(bool) onStatusChanged) async {
    if (currentUserId == null || post.id == null) {
      _showToast('Please log in to save posts');
      return;
    }

    String saveDocId = '${currentUserId}_${post.id}';
    debugPrint('SaveToggle: Checking save status for: $saveDocId');

    try {
      final document = await db.collection('saved_posts').doc(saveDocId).get();
      bool isCurrentlySaved = document.exists;

      debugPrint('SaveToggle: Current save status: $isCurrentlySaved');

      if (isCurrentlySaved) {
        await _unsavePost(post, saveDocId, onStatusChanged);
      } else {
        await _savePost(post, saveDocId, onStatusChanged);
      }
    } catch (e) {
      debugPrint('SaveToggle: Error checking save status: $e');
      _showToast('Error processing save');
    }
  }

  Future<void> _savePost(MediaPost post, String saveDocId, Function(bool) onStatusChanged) async {
    debugPrint('SavePost: Saving post: ${post.id}');
    _showToast('💾 Saving post...');

    Map<String, dynamic> saveData = {
      'userId': currentUserId,
      'postId': post.id,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (post.uid != null) saveData['postOwnerId'] = post.uid;
    if (post.username != null) saveData['postOwnerName'] = post.username;
    if (post.mediaUrl != null) saveData['mediaUrl'] = post.mediaUrl;
    if (post.type != null) saveData['mediaType'] = post.type;
    if (post.description != null) saveData['description'] = post.description;

    try {
      await db.collection('saved_posts').doc(saveDocId).set(saveData);

      debugPrint('SavePost: Successfully saved post: ${post.id}');
      saveStatusCache[post.id!] = true;
      onStatusChanged(true);
      _showToast('✅ Post saved!');

      // Notify SavedFragment to refresh
      _notifySavedFragmentRefresh();
    } catch (e) {
      debugPrint('SavePost: Failed to save post: $e');
      _showToast('Failed to save post');
    }
  }

  Future<void> _unsavePost(MediaPost post, String saveDocId, Function(bool) onStatusChanged) async {
    debugPrint('UnsavePost: Unsaving post: ${post.id}');
    _showToast('🗑️ Removing from saved...');

    try {
      await db.collection('saved_posts').doc(saveDocId).delete();

      debugPrint('UnsavePost: Successfully unsaved post: ${post.id}');
      saveStatusCache[post.id!] = false;
      onStatusChanged(false);
      _showToast('📤 Post removed from saved');

      _notifySavedFragmentRefresh();
    } catch (e) {
      debugPrint('UnsavePost: Failed to unsave post: $e');
      _showToast('Failed to remove post');
    }
  }

  Future<void> checkSaveStatus(MediaPost post, Function(bool) onStatusLoaded) async {
    if (currentUserId == null || post.id == null) {
      onStatusLoaded(false);
      return;
    }

    // Check cache first
    if (saveStatusCache.containsKey(post.id)) {
      onStatusLoaded(saveStatusCache[post.id]!);
      return;
    }

    String saveDocId = '${currentUserId}_${post.id}';

    try {
      final document = await db.collection('saved_posts').doc(saveDocId).get();
      bool isSaved = document.exists;

      saveStatusCache[post.id!] = isSaved;
      onStatusLoaded(isSaved);

      debugPrint('SaveStatus: Save status for ${post.id}: $isSaved');
    } catch (e) {
      debugPrint('SaveStatus: Failed to check save status: $e');
      onStatusLoaded(false);
    }
  }

  void _notifySavedFragmentRefresh() {
    // TODO: Implement broadcast to SavedFragment
    // You can use EventBus or Provider for state management
    debugPrint('SaveSystem: Sent refresh broadcast to SavedFragment');
  }

  // ═══════════════════════════════════════════════════════════
  // FOLLOW/UNFOLLOW METHODS
  // ═══════════════════════════════════════════════════════════
  Future<void> toggleFollow(MediaPost post, Function(bool) onStatusChanged) async {
    if (currentUserId == null || post.uid == null) {
      _showToast('Please log in to follow users');
      return;
    }

    if (currentUserId == post.uid) {
      _showToast("You can't follow yourself");
      return;
    }

    String followDocId = '${currentUserId}_${post.uid}';

    try {
      final document = await db.collection('follows').doc(followDocId).get();
      bool isCurrentlyFollowing = document.exists;

      if (isCurrentlyFollowing) {
        await _unfollowUser(post, followDocId, onStatusChanged);
      } else {
        await _followUser(post, followDocId, onStatusChanged);
      }
    } catch (e) {
      debugPrint('FollowSystem: Error checking follow status: $e');
      _showToast('Error checking follow status');
    }
  }

  Future<void> _followUser(MediaPost post, String followDocId, Function(bool) onStatusChanged) async {
    Map<String, dynamic> followData = {
      'followerId': currentUserId,
      'followerName': currentUserName,
      'followingId': post.uid,
      'followingName': post.username,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await db.collection('follows').doc(followDocId).set(followData);

      debugPrint('FollowSystem: Successfully followed user: ${post.username}');
      followStatusCache[post.uid!] = true;
      onStatusChanged(true);

      _sendFollowNotificationViaBackend(post.uid!, post.username!);
      _showToast('You are now following ${post.username}');
    } catch (e) {
      debugPrint('FollowSystem: Failed to follow user: $e');
      _showToast('Failed to follow user');
    }
  }

  Future<void> _unfollowUser(MediaPost post, String followDocId, Function(bool) onStatusChanged) async {
    try {
      await db.collection('follows').doc(followDocId).delete();

      debugPrint('FollowSystem: Successfully unfollowed user: ${post.username}');
      followStatusCache[post.uid!] = false;
      onStatusChanged(false);

      _showToast('You unfollowed ${post.username}');
    } catch (e) {
      debugPrint('FollowSystem: Failed to unfollow user: $e');
      _showToast('Failed to unfollow user');
    }
  }

  void _sendFollowNotificationViaBackend(String toUserId, String toUsername) {
    debugPrint('FollowNotification: 🔔 Creating follow notification for backend processing');

    Map<String, dynamic> notificationData = {
      'toUserId': toUserId,
      'type': 'follow',
      'fromUserId': currentUserId,
      'fromUserName': currentUserName ?? 'Unknown User',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'processed': false,
      'extraData': {
        'targetUsername': toUsername,
      },
    };

    db.collection('users')
        .doc(toUserId)
        .collection('notifications')
        .add(notificationData)
        .then((docRef) {
      debugPrint('FollowNotification: ✅ Follow notification created successfully: ${docRef.id}');
    }).catchError((e) {
      debugPrint('FollowNotification: ❌ Failed to create follow notification: $e');
    });
  }

  Future<void> checkFollowStatus(MediaPost post, Function(bool) onStatusLoaded) async {
    if (currentUserId == null || post.uid == null || currentUserId == post.uid) {
      onStatusLoaded(true); // Hide follow button
      return;
    }

    // Check cache first
    if (followStatusCache.containsKey(post.uid)) {
      onStatusLoaded(followStatusCache[post.uid]!);
      return;
    }

    String followDocId = '${currentUserId}_${post.uid}';

    try {
      final document = await db.collection('follows').doc(followDocId).get();
      bool isFollowing = document.exists;

      followStatusCache[post.uid!] = isFollowing;
      onStatusLoaded(isFollowing);
    } catch (e) {
      debugPrint('FollowSystem: Failed to check follow status: $e');
      onStatusLoaded(false);
    }
  }

  void setupFollowStatusListener(MediaPost post, Function(bool) onStatusUpdated) {
    if (currentUserId == null || post.uid == null || currentUserId == post.uid) {
      return;
    }

    String followDocId = '${currentUserId}_${post.uid}';

    final listener = db
        .collection('follows')
        .doc(followDocId)
        .snapshots()
        .listen((snapshot) {
      bool isFollowing = snapshot.exists;
      followStatusCache[post.uid!] = isFollowing;
      onStatusUpdated(isFollowing);

      debugPrint('FollowSystem: Follow status updated for ${post.username}: $isFollowing');
    });

    followListeners[post.uid!] = listener;
  }

  // ═══════════════════════════════════════════════════════════
  // VIEWS COUNT METHODS
  // ═══════════════════════════════════════════════════════════
  Future<void> recordViewForPost(MediaPost post) async {
    if (post.id == null || currentUserId == null) {
      return;
    }

    // Don't track views for own posts
    if (currentUserId == post.uid) {
      debugPrint('ViewCount: Skipping view tracking for own post');
      return;
    }

    try {
      final document = await db.collection('media_posts').doc(post.id).get();

      if (document.exists) {
        List<dynamic>? viewsUsers = document.get('viewsUsers') as List<dynamic>?;

        if (viewsUsers == null || !viewsUsers.contains(currentUserId)) {
          await db.collection('media_posts').doc(post.id).update({
            'viewsUsers': FieldValue.arrayUnion([currentUserId]),
            'viewsCount': FieldValue.increment(1),
            'viewCount': FieldValue.increment(1),
          });

          debugPrint('ViewCount: View recorded for post: ${post.id}');
        }
      }
    } catch (e) {
      debugPrint('ViewCount: Failed to record view: $e');
    }
  }

  void setupViewsCountListener(MediaPost post, Function(String) onViewsUpdated) {
    if (post.id == null) {
      onViewsUpdated('0');
      return;
    }

    final listener = db
        .collection('media_posts')
        .doc(post.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        int? viewsCount = snapshot.get('viewsCount') as int?;
        viewsCount ??= snapshot.get('viewCount') as int?;
        viewsCount ??= 0;

        String formattedCount = _formatViewsCount(viewsCount);
        onViewsUpdated(formattedCount);

        debugPrint('ViewsListener: Real-time views count updated: $viewsCount');
      } else {
        onViewsUpdated('0');
      }
    });

    viewsListeners[post.id!] = listener;
  }

  String _formatViewsCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else if (count < 1000000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else {
      return '${(count / 1000000000).toStringAsFixed(1)}B';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // LIKE/UNLIKE METHODS
  // ═══════════════════════════════════════════════════════════
  Future<void> toggleLike(MediaPost post, Function(bool, int) onLikeUpdated) async {
    if (currentUserId == null || post.id == null) {
      _showToast('Please login to like posts');
      return;
    }

    debugPrint('LikeToggle: Toggling like for post: ${post.id} by user: $currentUserId');

    try {
      final likeRef = db
          .collection('media_posts')
          .doc(post.id)
          .collection('likes')
          .doc(currentUserId);

      final document = await likeRef.get();
      bool isCurrentlyLiked = document.exists;

      debugPrint('LikeToggle: Current like status: $isCurrentlyLiked');

      if (isCurrentlyLiked) {
        // Unlike
        await likeRef.delete();
        final likesSnapshot = await db
            .collection('media_posts')
            .doc(post.id)
            .collection('likes')
            .get();

        int newCount = likesSnapshot.docs.length;
        onLikeUpdated(false, newCount);
        _showToast('Post unliked!');

        debugPrint('LikeToggle: Post unliked successfully. New count: $newCount');
      } else {
        // Like
        Map<String, dynamic> likeData = {
          'uid': currentUserId,
          'username': currentUserName ?? 'Unknown User',
          'postId': post.id,
          'postOwnerId': post.uid,
          'postOwnerName': post.username,
          'timestamp': FieldValue.serverTimestamp(),
          'likedAt': DateTime.now().millisecondsSinceEpoch,
        };

        await likeRef.set(likeData);
        final likesSnapshot = await db
            .collection('media_posts')
            .doc(post.id)
            .collection('likes')
            .get();

        int newCount = likesSnapshot.docs.length;
        onLikeUpdated(true, newCount);
        _showToast('Post liked!');

        debugPrint('LikeToggle: Post liked successfully. New count: $newCount');

        // Send notification
        _sendLikeNotification(post.uid, post.id, currentUserName);
      }
    } catch (e) {
      debugPrint('LikeToggle: Failed to process like: $e');
      _showToast('Failed to process like');
    }
  }

  Future<void> loadLikeStatusAndCount(MediaPost post, Function(bool, int) onLoaded) async {
    if (post.id == null) {
      debugPrint('LikeStatus: Post ID is null');
      onLoaded(false, 0);
      return;
    }

    debugPrint('LikeStatus: Loading like status for post: ${post.id}');

    try {
      // Check if current user liked
      bool isLiked = false;
      if (currentUserId != null) {
        final likeDoc = await db
            .collection('media_posts')
            .doc(post.id)
            .collection('likes')
            .doc(currentUserId)
            .get();

        isLiked = likeDoc.exists;
      }

      // Get total likes count
      final likesSnapshot = await db
          .collection('media_posts')
          .doc(post.id)
          .collection('likes')
          .get();

      int likeCount = likesSnapshot.docs.length;

      onLoaded(isLiked, likeCount);
      debugPrint('LikeStatus: Like status loaded - isLiked: $isLiked, count: $likeCount');
    } catch (e) {
      debugPrint('LikeStatus: Failed to load like status: $e');
      onLoaded(false, 0);
    }
  }

  void _sendLikeNotification(String? postOwnerId, String? postId, String? currentUsername) {
    if (postOwnerId == null || postOwnerId == currentUserId) {
      return;
    }

    Map<String, dynamic> notificationData = {
      'type': 'like',
      'fromUserId': currentUserId,
      'fromUserName': currentUsername,
      'toUserId': postOwnerId,
      'postId': postId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    db.collection('fcm_notifications').add(notificationData).then((_) {
      debugPrint('FCMNotification: Like notification sent successfully');
    }).catchError((e) {
      debugPrint('FCMNotification: Failed to send like notification: $e');
    });
  }

  // ═══════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════
  void cleanup() {
    // Cancel all listeners
    for (var listener in followListeners.values) {
      listener.cancel();
    }
    for (var listener in commentListeners.values) {
      listener.cancel();
    }
    for (var listener in viewsListeners.values) {
      listener.cancel();
    }

    // Clear caches
    commentCountCache.clear();
    followListeners.clear();
    followStatusCache.clear();
    saveStatusCache.clear();

    debugPrint('ForYouAdapter: Cleanup completed');
  }
}

// ═══════════════════════════════════════════════════════════
// VIDEO PLAYER CONTROLLER HELPER
// ═══════════════════════════════════════════════════════════
class VideoPlayerManager {
  VideoPlayerController? _currentController;

  Future<VideoPlayerController?> initializeVideo(String url) async {
    try {
      final controller = VideoPlayerController.network(url);
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(1.0);

      _currentController = controller;
      return controller;
    } catch (e) {
      debugPrint('VideoPlayback: Error initializing video: $e');
      return null;
    }
  }

  void play() {
    _currentController?.play();
  }

  void pause() {
    _currentController?.pause();
  }

  void dispose() {
    _currentController?.dispose();
    _currentController = null;
  }

  bool get isPlaying => _currentController?.value.isPlaying ?? false;
}