import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:my_vibe_flick/screens/rotating_vinyl_disc.dart';
import 'package:my_vibe_flick/screens/share_bottom_sheet.dart';

import 'package:my_vibe_flick/screens/sound_detail_page.dart' hide SoundDetailPage;
import 'package:my_vibe_flick/screens/video_cache_manager.dart';
import 'package:my_vibe_flick/screens/video_options_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:io';
import 'package:my_vibe_flick/screens/media_options_bottom_sheet.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:shimmer/shimmer.dart'; // 🆕 ADD THIS PACKAGE
import '../Comment/comment_bottom_sheet.dart';
import '../search_navigation_helper.dart';
import 'activity_user_profile.dart';


class ForYouScreen extends StatefulWidget {
  const ForYouScreen({super.key});

  @override
  State<ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends State<ForYouScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PageController _pageController = PageController();
  final Map<int, VideoPlayerController?> _audioControllers = {};
  List<Map<String, dynamic>> _publicPosts = [];
  bool _isLoading = true;
  String? _currentUserId;
  int _currentPageIndex = 0;
  bool _isRefreshing = false;

// Double tap like animation
  final Map<int, bool> _showHeartAnimation = {};
  final Map<int, OverlayEntry?> _heartOverlays = {};

  // 🎯 LRU Memory Management Configuration
  static const int _maxVideosInMemory = 3;
  static const int _preloadDistance = 1;
  static const int _keepAliveDistance = 1;

  final Map<int, VideoPlayerController?> _videoControllers = {};
  final Map<int, bool> _showFullDescription = {};
  final List<int> _videoAccessOrder = [];

  // 🎬 Thumbnail Management
  final Map<int, bool> _videoInitialized = {};
  final Map<int, bool> _showThumbnail = {};

  // 📄 Pagination Variables
  DocumentSnapshot? _lastDocument;
  bool _hasMorePosts = true;
  bool _isLoadingMore = false;
  static const int _postsPerPage = 10;

  // 🔄 Pre-fetching tracking
  final Set<String> _prefetchedUrls = {};

  // 🆕 BUG FIX: Track if page is active
  bool _isPageActive = true;

  // 🔥 NEW: ValueNotifier for video progress (NO MORE setState!)
  final Map<int, ValueNotifier<double>> _videoProgressNotifiers = {};

  // 🆕 NEW: 2x speed tracking
  final Map<int, bool> _isDoubleSpeed = {};

  // 🆕 NEW: Visibility tracking
  final Map<int, bool> _videoVisibility = {};

  // 🆕 NEW: Network connectivity tracking
  bool _hasInternetConnection = true;
  bool _showNoInternetToast = false;

  // 🆕 NEW: Loading state per media item
  final Map<int, bool> _isMediaLoading = {};
  final Set<String> _seenPostIds = {};
  static const double _seenResetThreshold = 0.80; // 80% නම් reset
  // 🆕 ADD HERE ↓
  final Map<String, Map<String, dynamic>?> _repostInfoCache = {};

  void _showMediaOptionsBottomSheet(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          MediaOptionsBottomSheet(
            postId: post['id'] ?? '',
            postOwnerId: post['uid'] ?? '',
            postOwnerUsername: post['username'] ?? 'Unknown',
            mediaUrl: post['media_url'] ?? '',
            onReported: () {
              setState(() {
                _publicPosts.removeWhere((p) => p['id'] == post['id']);
              });
              Navigator.pop(context);
            },
          ),
    );
  }

  void _handleDoubleTap(int pageIndex, String postId,
      TapDownDetails details) async {
    // Heart animation show කරන්න
    _showHeartOverlay(details.globalPosition);

    // Already liked නම් like නොකරන්න, නැත්නම් like කරන්න
    if (_currentUserId == null) return;

    final likeRef = _db
        .collection('media_posts')
        .doc(postId)
        .collection('likes')
        .doc(_currentUserId);

    final likeDoc = await likeRef.get();
    if (!likeDoc.exists) {
      await _toggleLike(postId, pageIndex);
    }
  }

  void _showHeartOverlay(Offset position) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) =>
          _HeartAnimationWidget(
            position: position,
            onComplete: () {
              entry.remove();
            },
          ),
    );

    overlay.insert(entry);
  }

  // 🔄 Refresh method for double tap
  Future<void> refreshFeed() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    debugPrint('🔄 Refreshing ForYou feed...');

    try {
      // Reset pagination
      _lastDocument = null;
      _hasMorePosts = true;
      _currentPageIndex = 0;
      _seenPostIds.clear(); // ← ADD: Refresh කරාම seen cache reset
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('seen_post_ids_${_currentUserId ?? "guest"}');
      debugPrint('🔄 Seen cache cleared on manual refresh');
      _audioControllers.forEach((_, ctrl) {
        ctrl?.pause();
        ctrl?.dispose();
      });
      _audioControllers.clear();
      // Dispose all videos
      _videoControllers.forEach((index, controller) {
        controller?.dispose();
      });
      _videoControllers.clear();
      _videoAccessOrder.clear();
      _videoInitialized.clear();
      _showThumbnail.clear();
      _prefetchedUrls.clear();
  // 🆕 PEXELS: Refresh වෙනකොට audio cache reset
      await _refreshPexelsTrendingAudio();
      // Reload posts
      await _loadPublicPosts();

      // Scroll to top
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      debugPrint('✅ Feed refreshed successfully');
    } catch (e) {
      debugPrint('❌ Error refreshing feed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _sharePost(Map<String, dynamic> post) async {
    final postOwnerId = post['uid'] ?? '';
    final isOwnPost = postOwnerId == _currentUserId;

    // 🆕 Original index + copy — restore සඳහා
    final int originalIndex = _publicPosts.indexWhere((p) =>
    p['id'] == post['id']);
    final Map<String, dynamic> postCopy = Map<String, dynamic>.from(post);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          ShareBottomSheet(
            postId: post['id'] ?? '',
            username: post['username'] ?? 'Unknown',
            description: post['description'] ?? '',
            thumbnailUrl: post['thumbnail_url'],
            isOwnPost: isOwnPost,
            postOwnerId: postOwnerId,
            postOwnerUsername: post['username'] ?? 'Unknown',
            mediaUrl: post['media_url'] ?? '',
            hashtags: (post['hashtags'] as List?)?.cast<String>() ?? [],
            category: (post['category'] as String?) ?? '',
            onReported: () {
              // UI only hide — DB write Snackbar close වෙනකන් delay වෙනවා
              setState(() {
                _publicPosts.removeWhere((p) => p['id'] == post['id']);
              });
            },
            onUndo: () {
              // 🆕 Post restore — DB write නෑ
              setState(() {
                final insertAt = originalIndex.clamp(0, _publicPosts.length);
                _publicPosts.insert(insertAt, postCopy);
              });
              debugPrint('↩️ Post restored to index $originalIndex');
            },
          ),
    );
  }

  Future<void> _incrementShareCount(String postId) async {
    try {
      await _db.collection('media_posts').doc(postId).update({
        'shares_count': FieldValue.increment(1),
      });

      // Activity log
      if (_currentUserId != null) {
        await _db.collection('activity_logs').add({
          'type': 'share',
          'userId': _currentUserId,
          'postId': postId,
          'timestamp': DateTime
              .now()
              .millisecondsSinceEpoch,
        });
      }
      debugPrint('✅ Share count incremented: $postId');
    } catch (e) {
      debugPrint('❌ Share count update error: $e');
    }
  }

// ============================================================
// SHARE FEATURE - END
// ============================================================
// 🆕 ADD: Track view for current video
  Future<void> _trackVideoView(String postId, int pageIndex) async {
    if (_currentUserId == null) {
      await _trackGuestView(postId);
      return;
    }

    // 🆕 FIX: Pexels posts → pexels_posts collection, Normal → media_posts
    final bool isPexels = postId.startsWith('pexels_');
    final String collection = isPexels ? 'pexels_posts' : 'media_posts';

    try {
      final viewDocId = '${_currentUserId}_$postId';
      final viewRef = _db
          .collection(collection)
          .doc(postId)
          .collection('views')
          .doc(viewDocId);

      final viewDoc = await viewRef.get();

      if (!viewDoc.exists) {
        // 🆕 FIX: Pexels doc exist නැත්නම් create කරනවා (viewCount update සඳහා)
        if (isPexels && pageIndex < _publicPosts.length) {
          await _ensurePexelsPostDocument(_publicPosts[pageIndex]);
        }

        await viewRef.set({
          'userId': _currentUserId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'watchDuration': 0,
          'isGuest': false,
        });

        await _db.collection(collection).doc(postId).update({
          'viewCount': FieldValue.increment(1),
        });
        debugPrint('✅ New view tracked for post: $postId');
      } else {
        debugPrint('⏭️ Already viewed this post: $postId');
      }

      final historyRef = _db
          .collection('user_history')
          .doc(_currentUserId)
          .collection('watched');

      final existingHistory = await historyRef
          .where('postId', isEqualTo: postId)
          .limit(1)
          .get();

      if (existingHistory.docs.isNotEmpty) {
        await existingHistory.docs.first.reference.update({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        debugPrint('🔄 History timestamp updated for: $postId');
      } else {
        await historyRef.add({
          'postId': postId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'userId': _currentUserId,
        });
        debugPrint('✅ Added to user history: $postId');
      }
    } catch (e) {
      debugPrint('❌ Error tracking view: $e');
    }
  }

  // 🆕 ADD: Track guest view using device ID
  Future<void> _trackGuestView(String postId) async {
    try {
      // You'll need to add device_info_plus package
      // Get device ID here
      final deviceId = 'guest_temp_${DateTime
          .now()
          .millisecondsSinceEpoch}';

      final viewDocId = 'guest_${deviceId}_$postId';
      final viewRef = _db
          .collection('media_posts')
          .doc(postId)
          .collection('views')
          .doc(viewDocId);

      final viewDoc = await viewRef.get();

      if (!viewDoc.exists) {
        await viewRef.set({
          'userId': 'guest',
          'deviceId': deviceId,
          'timestamp': DateTime
              .now()
              .millisecondsSinceEpoch,
          'isGuest': true,
        });

        await _db.collection('media_posts').doc(postId).update({
          'viewCount': FieldValue.increment(1),
        });

        debugPrint('✅ Guest view tracked for post: $postId');
      }
    } catch (e) {
      debugPrint('❌ Error tracking guest view: $e');
    }
  }

// 🆕 ADD: Track watch duration
  Timer? _viewTrackingTimer;
  int _currentWatchDuration = 0;

  void _startViewTracking(String postId, int pageIndex) {
    _currentWatchDuration = 0;

    _viewTrackingTimer?.cancel();
    _viewTrackingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentWatchDuration += 1000; // milliseconds

      // Track view after 3 seconds of watching
      if (_currentWatchDuration >= 3000 && _currentWatchDuration <= 4000) {
        _trackVideoView(postId, pageIndex);
      }
    });
  }

  void _stopViewTracking() {
    _viewTrackingTimer?.cancel();
    _currentWatchDuration = 0;
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

  Widget _buildClickableDescription(String description, String username,
      int pageIndex) {
    final spans = <TextSpan>[];
    final RegExp combinedRegex = RegExp(r'(@\w+|#\w+)');

    int lastIndex = 0;
    final allMatches = combinedRegex.allMatches(description).toList();

    for (final match in allMatches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: description.substring(lastIndex, match.start),
          style: const TextStyle(
              fontSize: 14, color: Colors.white, height: 1.3),
        ));
      }

      final matchText = match.group(0)!;
      final isHashtag = matchText.startsWith('#');

      spans.add(TextSpan(
        text: matchText,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF3B82F6),
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (isHashtag) {
              _handleHashtagTap(matchText.substring(1));
            } else {
              _handleMentionTap(matchText.substring(1));
            }
          },
      ));

      lastIndex = match.end;
    }

    if (lastIndex < description.length) {
      spans.add(TextSpan(
        text: description.substring(lastIndex),
        style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.3),
      ));
    }

    final showFull = _showFullDescription[pageIndex] ?? false;

    return RichText(
      text: TextSpan(children: spans),
      maxLines: showFull ? null : 2,
      overflow: showFull ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }

// ✅ STEP 2: _handleMentionTap method එක add කරන්න (NEW METHOD)

  Future<void> _handleMentionTap(String username) async {
    debugPrint('👆 Tapped mention: @$username');

    _pauseAllVideos();

    try {
      // 🔍 Try exact match first
      QuerySnapshot querySnapshot = await _db
          .collection('users')
          .where('name', isEqualTo: username)
          .limit(1)
          .get();

      // 🔍 If not found, try case-insensitive search
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await _db
            .collection('users')
            .where('name', isEqualTo: username.toLowerCase())
            .limit(1)
            .get();
      }

      // 🔍 If still not found, try username field
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await _db
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();
      }

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first;
        final userId = userDoc.id;

        debugPrint('🔄 Navigating to profile: $userId');

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityUserProfile(userId: userId),
          ),
        ).then((_) {
          if (_isPageActive && mounted) {
            _resumeCurrentVideo();
          }
        });
      } else {
        debugPrint('⚠️ User not found: $username');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('@$username not found'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error finding user: $e');
    }
  }

  Future<void> _handleFeedFollow(String targetUserId,
      String targetUsername) async {
    if (_currentUserId == null || _currentUserId == targetUserId) {
      return;
    }

    try {
      final followDocId = '${_currentUserId}_$targetUserId';
      final followRef = _db.collection('follows').doc(followDocId);
      final followDoc = await followRef.get();

      if (followDoc.exists) {
        await _showUnfollowConfirmationDialog(targetUserId, targetUsername);
      } else {
        debugPrint('💙 Following from feed: $targetUserId');

        final targetUserDoc = await _db
            .collection('users')
            .doc(targetUserId)
            .get();
        final isPrivateAccount = targetUserDoc.data()?['private_account'] ??
            false;

        final currentUserDoc = await _db
            .collection('users')
            .doc(_currentUserId)
            .get();
        final currentUsername = currentUserDoc.data()?['name'] ?? 'User';

        final followData = {
          'followerId': _currentUserId,
          'followerName': currentUsername,
          'followingId': targetUserId,
          'followingName': targetUsername,
          'status': isPrivateAccount ? 'pending' : 'active',
          'timestamp': DateTime
              .now()
              .millisecondsSinceEpoch,
        };

        await followRef.set(followData);

        if (!isPrivateAccount) {
          await _db.collection('users').doc(_currentUserId).update({
            'followingCount': FieldValue.increment(1),
          });

          await _db.collection('users').doc(targetUserId).update({
            'followerCount': FieldValue.increment(1),
          });

          debugPrint('✅ Follow completed');
        } else {
          debugPrint('⏳ Follow request sent (pending approval)');

          await _db.collection('users').doc(targetUserId).collection(
              'notifications').add({
            'type': 'follow_request',
            'fromUserId': _currentUserId,
            'fromUserName': currentUsername,
            'toUserId': targetUserId,
            'timestamp': DateTime
                .now()
                .millisecondsSinceEpoch,
            'isRead': false,
          });
        }

        _sendFollowNotificationInBackground(
            targetUserId, targetUsername, isPrivateAccount);
      }
    } catch (e) {
      debugPrint('❌ Error toggling follow: $e');
    }
  }

  void _sendFollowNotificationInBackground(String targetUserId,
      String targetUsername, bool isPrivate) {
    if (_currentUserId == null || _currentUserId == targetUserId) {
      debugPrint('⏭️ Skipping self-notification');
      return;
    }

    _db.collection('users').doc(_currentUserId).get().then((currentUserDoc) {
      final currentUsername = currentUserDoc.data()?['name'] ?? 'User';

      _sendFollowNotificationToBackend(
        targetUserId,
        targetUsername,
        currentUsername,
        isPrivate,
      ).then((_) {
        debugPrint('✅ Background follow notification sent');
      }).catchError((error) {
        debugPrint('⚠️ Follow notification failed (non-critical): $error');
      });
    });
  }

  Future<void> _showUnfollowConfirmationDialog(String targetUserId,
      String targetUsername) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF3B5C),
                  ),
                  child: Center(
                    child: Text(
                      targetUsername.isNotEmpty ? targetUsername[0]
                          .toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Unfollow @$targetUsername?',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'If you change your mind, you\'ll have to request to follow again.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFAAAAAA),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _executeUnfollow(targetUserId, targetUsername);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B5C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Unfollow',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF2C2C2C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeUnfollow(String targetUserId,
      String targetUsername) async {
    if (_currentUserId == null) return;

    try {
      final followDocId = '${_currentUserId}_$targetUserId';
      final followRef = _db.collection('follows').doc(followDocId);
      final followDoc = await followRef.get();

      if (followDoc.exists) {
        final currentStatus = followDoc.data()?['status'];

        debugPrint('💔 Unfollowing: $targetUserId');

        await followRef.delete();

        if (currentStatus == 'active') {
          await _db.collection('users').doc(_currentUserId).update({
            'followingCount': FieldValue.increment(-1),
          });

          await _db.collection('users').doc(targetUserId).update({
            'followerCount': FieldValue.increment(-1),
          });
        }

        debugPrint('✅ Unfollow completed');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unfollowed @$targetUsername'),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF2C2C2C),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error unfollowing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to unfollow. Please try again.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendFollowNotificationToBackend(String targetUserId,
      String targetUsername,
      String currentUsername,
      bool isPrivate,) async {
    try {
      debugPrint('\n🔔 ========== SENDING FOLLOW NOTIFICATION ==========');
      debugPrint('📤 From: $currentUsername ($_currentUserId)');
      debugPrint('📥 To: $targetUsername ($targetUserId)');
      debugPrint('🔒 Private: $isPrivate');

      const backendUrl = 'http://10.109.149.236:5000/api/follow-notification';

      final requestBody = {
        'fromUserId': _currentUserId,
        'fromUserName': currentUsername,
        'toUserId': targetUserId,
        'toUserName': targetUsername,
        'followStatus': isPrivate ? 'pending' : 'active',
      };

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Follow notification sent to backend');
      } else {
        debugPrint('⚠️ Backend error: ${response.statusCode}');
      }
      debugPrint('==========================================\n');
    } catch (e) {
      debugPrint('❌ Follow notification error: $e');
    }
  }

  Future<bool> _canViewPost(String postOwnerId) async {
    try {
      final userDoc = await _db.collection('users').doc(postOwnerId).get();

      if (!userDoc.exists) {
        debugPrint('⚠️ User document not found: $postOwnerId');
        return true;
      }

      final isPrivateAccount = userDoc.data()?['private_account'] ?? false;

      if (!isPrivateAccount) {
        return true;
      }

      if (_currentUserId == null) {
        return false;
      }

      final followDocId = '${_currentUserId}_$postOwnerId';
      final followDoc = await _db.collection('follows').doc(followDocId).get();

      if (!followDoc.exists) {
        debugPrint('🔒 Private account, not following: $postOwnerId');
        return false;
      }

      final followStatus = followDoc.data()?['status'];
      final isFollowingAccepted = (followStatus == 'accepted');

      debugPrint(
          '🔍 Private account check: $postOwnerId - Following: $isFollowingAccepted');

      return isFollowingAccepted;
    } catch (e) {
      debugPrint('❌ Error checking if can view post: $e');
      return true;
    }
  }


  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadPublicPosts();
    _loadSeenPostIds(); // ← ADD THIS LINE (before _loadPublicPosts)
    WidgetsBinding.instance.addObserver(this);
    _setupAudioSession();

    _pageController.addListener(() {
      final newPage = _pageController.page?.round() ?? 0;
      if (newPage != _currentPageIndex) {
        _onPageChanged(newPage);
      }

      if (newPage >= _publicPosts.length - 3 && !_isLoadingMore &&
          _hasMorePosts) {
        _loadMorePosts();
      }
    });

    VideoCacheManager.cleanupOldCache();
  }

  Future<void> _setupAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      session.becomingNoisyEventStream.listen((_) {
        debugPrint('🎧 Headphones disconnected - Auto pausing video');
        _pauseCurrentVideo();
      });
    } catch (e) {
      debugPrint('⚠️ Audio session setup error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    debugPrint('📱 App lifecycle state changed: $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        debugPrint('⏸️ App paused/inactive/hidden - Pausing all videos');
        _isPageActive = false;
        _pauseAllVideos();
        break;

      case AppLifecycleState.resumed:
        debugPrint('▶️ App resumed - Resuming current video');
        _isPageActive = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _isPageActive) {
            _resumeCurrentVideo();
          }
        });
        break;

      default:
        break;
    }
  }

  @override
  void deactivate() {
    debugPrint('⏸️ ForYouScreen deactivated - Pausing all videos');
    _isPageActive = false;

    // ✅ FIX: setState() නැතුව videos pause කරන්න
    _videoControllers.forEach((index, controller) {
      if (controller != null && controller.value.isPlaying) {
        controller.pause();
        debugPrint('⏸️ Paused video at index $index');
      }
    });

    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    debugPrint('▶️ ForYouScreen activated - Resuming current video');
    _isPageActive = true;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _isPageActive) {
        _resumeCurrentVideo();
      }
    });
  }

  void _pauseAllVideos() {
    _videoControllers.forEach((index, controller) {
      if (controller != null && controller.value.isPlaying) {
        controller.pause();
        debugPrint('⏸️ Paused video at index $index');
      }
    });
    _audioControllers.forEach((_, ctrl) {
      ctrl?.pause();
    });
    if (mounted) {
      setState(() {});
    }
  }

  void _pauseCurrentVideo() {
    final controller = _videoControllers[_currentPageIndex];
    if (controller != null && controller.value.isPlaying) {
      controller.pause();
      debugPrint('⏸️ Paused current video at index $_currentPageIndex');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _resumeCurrentVideo() {
    if (!_isPageActive) {
      debugPrint('⏭️ Skipping resume - page not active');
      return;
    }

    if (_currentPageIndex < _publicPosts.length &&
        _publicPosts[_currentPageIndex]['type'] == 'video') {
      final controller = _videoControllers[_currentPageIndex];
      if (controller != null && !controller.value.isPlaying) {
        controller.play();
        debugPrint('▶️ Resumed video at index $_currentPageIndex');
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  void _toggleDoubleSpeed(int pageIndex) {
    final controller = _videoControllers[pageIndex];
    if (controller == null) return;

    final isCurrentlyDouble = _isDoubleSpeed[pageIndex] ?? false;

    setState(() {
      _isDoubleSpeed[pageIndex] = !isCurrentlyDouble;
    });

    if (!isCurrentlyDouble) {
      controller.setPlaybackSpeed(2.0);
      debugPrint('⚡ 2x speed enabled for video $pageIndex');
    } else {
      controller.setPlaybackSpeed(1.0);
      debugPrint('🎬 Normal speed for video $pageIndex');
    }
  }

// ════════════════════════════════════════════════════════
// ALGORITHM: Fetch Personalized Feed
// GET /api/feed/for-you
// ════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> _fetchAlgorithmFeed({
    int limit = 10,
    String? lastPostId,
    String? category,
  }) async {
    try {
      debugPrint('🤖 Fetching algorithm-personalized feed...');

      String url =
          'http://10.109.149.236:5000/api/feed/for-you?limit=$limit';

      if (_currentUserId != null) {
        url += '&userId=$_currentUserId';
      }
      if (lastPostId != null) {
        url += '&lastPostId=$lastPostId';
      }
      if (category != null && category.isNotEmpty && category != 'all') {
        url += '&category=$category';
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final posts = List<Map<String, dynamic>>.from(data['data'] ?? []);

          debugPrint('✅ Algorithm feed:');
          debugPrint('   Total candidates : ${data['totalCandidates']}');
          debugPrint('   After filter     : ${data['afterFilter']}');
          debugPrint('   After score      : ${data['afterScore']}');
          debugPrint('   Final            : ${data['finalCount']}');
          debugPrint('   Processing time  : ${data['processingTime']}');

          return posts;
        }
      }

      debugPrint('⚠️ Algorithm feed fallback → diversified feed');
      return [];
    } catch (e) {
      debugPrint('❌ Algorithm feed error: $e');
      return [];
    }
  }

// ════════════════════════════════════════════════════════
// ALGORITHM: Fetch Trending Posts
// GET /api/algorithm/trending
// ════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> _fetchTrendingPosts({
    int limit = 20,
    int hours = 24,
    String? category,
  }) async {
    try {
      String url =
          'https://avishka-tiktok-api.zeabur.app/api/algorithm/trending'
          '?limit=$limit&hours=$hours';

      if (category != null && category.isNotEmpty && category != 'all') {
        url += '&category=$category';
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final posts = List<Map<String, dynamic>>.from(data['data'] ?? []);
          debugPrint('🔥 Trending posts fetched: ${posts.length}');
          return posts;
        }
      }
      return [];
    } catch (e) {
      debugPrint('❌ Trending fetch error: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════
// ALGORITHM: Negative Signals
// ════════════════════════════════════════════════════════

  /// Quick swipe = skip signal
  void _handleSkipSignal(String postId) {
    if (postId.isEmpty || _currentUserId == null) return;
    debugPrint('⏭️ Skip signal: $postId');
    _recordSignal(postId, 'skip');
  }

  /// "Not Interested" option bottom sheet ගෙන් call කරනවා
  Future<void> _handleNotInterested(String postId, int pageIndex) async {
    if (_currentUserId == null) return;

    debugPrint('🚫 Not interested: $postId');

    // Signal යවනවා
    await _recordSignal(postId, 'not_interested');

    // UI ගෙන් post remove කරනවා
    if (mounted) {
      setState(() {
        _publicPosts.removeWhere((p) => p['id'] == postId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Post removed from your feed'),
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF2C2C2C),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () {
              // Undo — signal cancel කරන්න backend support නෑ,
              // ඒත් UI restore කරනවා
              setState(() {
                // post restore කරන්නෙ නෑ (undo complex)
              });
            },
          ),
        ),
      );
    }
  }

// 🆕 UPDATED: Send userId to backend for privacy checks
  Future<List<Map<String, dynamic>>> _fetchDiversifiedFeed({
    int limit = 10,
    String? lastPostId,
    String? userId, // 🆕 NEW parameter
  }) async {
    try {
      debugPrint('🌐 Fetching diversified feed from backend...');
      debugPrint('   Limit: $limit');
      debugPrint('   User ID: ${userId ?? "Guest"}');
      debugPrint('   Last Post ID: ${lastPostId ?? "None"}');

      // Build URL with userId
      String url = 'http://10.109.149.236:5000/api/feed/for-you-firestore?limit=$limit';

      if (userId != null) {
        url += '&userId=$userId'; // 🆕 Send userId for privacy checks
      }

      if (lastPostId != null) {
        url += '&lastPostId=$lastPostId';
      }

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final posts = List<Map<String, dynamic>>.from(data['data']);

          debugPrint('✅ Backend response:');
          debugPrint('   Total fetched: ${data['totalFetched']}');
          debugPrint('   After filtering: ${data['afterFiltering']}');
          debugPrint('   After diversity: ${data['afterDiversity']}');
          debugPrint('   Unique creators: ${data['uniqueCreators']}');

          // 🎯 Show what was skipped
          if (data['skipped'] != null) {
            final skipped = data['skipped'];
            debugPrint('   Skipped:');
            debugPrint('     Own posts: ${skipped['ownPost']}');
            debugPrint('     Private: ${skipped['privateAccount']}');
            debugPrint('     Not following: ${skipped['notFollowing']}');
          }

          return posts;
        } else {
          debugPrint('⚠️ Backend returned success=false');
          return [];
        }
      } else {
        debugPrint('❌ Backend error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Network error: $e');
      return [];
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts) {
      debugPrint(
          '⏸️ Cannot load more: Loading=$_isLoadingMore, HasMore=$_hasMorePosts');
      return;
    }

    // Check internet
    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      return;
    }

    try {
      setState(() {
        _isLoadingMore = true;
      });

      debugPrint('📄 Loading more posts...');

      // 🎯 BACKEND HANDLES ALL PRIVACY CHECKS!
      final lastPostId = _publicPosts.isNotEmpty
          ? _publicPosts.last['id']
          : null;
      final newPosts = await _fetchDiversifiedFeed(
        limit: _postsPerPage,
        lastPostId: lastPostId,
        userId: _currentUserId, // 🆕 Send userId to backend
      );

      if (newPosts.isEmpty) {
        debugPrint('ℹ️ No more posts available');
        setState(() {
          _isLoadingMore = false;
          _hasMorePosts = false;
        });
        return;
      }

      // ✅ NO MORE _canViewPost() CHECKS - Just add posts!
      _publicPosts.addAll(newPosts);
      _hasMorePosts = newPosts.length >= _postsPerPage;

      debugPrint('✅ Total posts now: ${_publicPosts
          .length} (Has more: $_hasMorePosts)');

      setState(() {
        _isLoadingMore = false;
      });
      // 🆕 PEXELS: DB posts ඉවර නම් Pexels inject කරනවා
      await _injectPexelsIfNeeded();
    } catch (e) {
      debugPrint('❌ Error loading more posts: $e');
      setState(() {
        _isLoadingMore = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load more posts'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _prefetchNextVideos(int currentPage) {
    for (int i = 1; i <= _preloadDistance; i++) {
      final nextIndex = currentPage + i;

      if (nextIndex < _publicPosts.length &&
          _publicPosts[nextIndex]['type'] == 'video') {
        final videoUrl = _publicPosts[nextIndex]['media_url'] as String;

        if (!_prefetchedUrls.contains(videoUrl)) {
          _prefetchedUrls.add(videoUrl);
          VideoCacheManager.prefetchVideo(videoUrl);
          debugPrint('🔄 Pre-fetching video at index $nextIndex');
        }
      }
    }
  }


  void _updateAccessOrder(int pageIndex) {
    _videoAccessOrder.remove(pageIndex);
    _videoAccessOrder.add(pageIndex);
    debugPrint('📝 LRU Order Updated: $_videoAccessOrder');
  }

  int? _getLeastRecentlyUsedVideo() {
    if (_videoAccessOrder.isEmpty) return null;
    return _videoAccessOrder.first;
  }

  Future<void> _enforceMemoryLimit() async {
    while (_videoControllers.length > _maxVideosInMemory) {
      final lruIndex = _getLeastRecentlyUsedVideo();

      if (lruIndex == null) break;

      if ((lruIndex - _currentPageIndex).abs() <= _keepAliveDistance) {
        _videoAccessOrder.remove(lruIndex);
        continue;
      }

      debugPrint(
          '🗑️ LRU: Disposing video at index $lruIndex (Limit: $_maxVideosInMemory)');
      await _disposeVideoAtIndex(lruIndex);
      _videoAccessOrder.remove(lruIndex);
    }
  }

  Future<void> _disposeVideoAtIndex(int index) async {
    final controller = _videoControllers[index];
    if (controller != null) {
      try {
        await controller.pause();
        await controller.dispose();
        _videoControllers.remove(index);
        _videoInitialized.remove(index);
        _showThumbnail.remove(index);

        _videoProgressNotifiers[index]?.dispose();
        _videoProgressNotifiers.remove(index);

        _isDoubleSpeed.remove(index);
        _videoVisibility.remove(index);
        _isMediaLoading.remove(index);
        debugPrint('✅ Disposed video at index $index');
      } catch (e) {
        debugPrint('⚠️ Error disposing video at index $index: $e');
      }
    }
  }

  Future<void> _initializeVideoForPage(int pageIndex) async {
    if (pageIndex >= _publicPosts.length) return;

    final post = _publicPosts[pageIndex];
    if (post['type'] != 'video') return;

    if (_videoControllers[pageIndex] != null) {
      debugPrint('🎥 Video already initialized for page $pageIndex');
      _updateAccessOrder(pageIndex);
      return;
    }

    await _enforceMemoryLimit();

    try {
      debugPrint(
          '🎬 Initializing video for page $pageIndex (Memory: ${_videoControllers
              .length}/$_maxVideosInMemory)');

      final videoUrl = post['media_url'] as String;
      debugPrint('📹 Video URL: $videoUrl');

      setState(() {
        _showThumbnail[pageIndex] = true;
        _videoInitialized[pageIndex] = false;
        _isMediaLoading[pageIndex] = true; // 🆕 NEW: Track loading state
      });

      VideoPlayerController controller;

      final cachedPath = await VideoCacheManager.getCachedVideoPath(videoUrl);

      if (cachedPath != null) {
        debugPrint('✅ Using cached video: $cachedPath');
        controller = VideoPlayerController.file(File(cachedPath));
      } else {
        debugPrint('⚠️ Cache failed, using network URL');
        controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      }

      // 🆕 PERFORMANCE FIX: Set buffer to optimize playback
      await controller.initialize();

      // 🆕 PERFORMANCE: Preload ahead for smoother playback
      controller.setVolume(1.0);
      controller.setLooping(true);

      setState(() {
        _videoControllers[pageIndex] = controller;
        _videoInitialized[pageIndex] = true;
        _showThumbnail[pageIndex] = false;
        _isMediaLoading[pageIndex] = false; // 🆕 NEW: Loading complete
      });

      _updateAccessOrder(pageIndex);

      _videoProgressNotifiers[pageIndex] = ValueNotifier<double>(0.0);

      controller.addListener(() {
        if (controller.value.isInitialized) {
          final position = controller.value.position.inMilliseconds.toDouble();
          final duration = controller.value.duration.inMilliseconds.toDouble();
          if (duration > 0) {
            _videoProgressNotifiers[pageIndex]?.value = position / duration;
          }
        }
      });

      if (pageIndex == _currentPageIndex && _isPageActive &&
          (_videoVisibility[pageIndex] ?? false)) {
        await controller.play();
      }

      debugPrint(
          '✅ Video initialized for page $pageIndex (Total in memory: ${_videoControllers
              .length})');
    } catch (e) {
      debugPrint('❌ Video initialization error for page $pageIndex: $e');
      setState(() {
        _videoControllers[pageIndex] = null;
        _videoInitialized[pageIndex] = false;
        _showThumbnail[pageIndex] = false;
        _isMediaLoading[pageIndex] = false;
      });

      if (mounted && pageIndex == _currentPageIndex) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Failed to load video. Please check your connection.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _cleanupDistantVideos(int currentPage) {
    final controllersToRemove = <int>[];

    _videoControllers.forEach((pageIndex, controller) {
      final distance = (pageIndex - currentPage).abs();

      if (distance > _keepAliveDistance) {
        controller?.pause();
        controllersToRemove.add(pageIndex);
        debugPrint(
            '🧹 Cleaning up video at page $pageIndex (distance: $distance)');
      }
    });

    for (var index in controllersToRemove) {
      _disposeVideoAtIndex(index);
      _videoAccessOrder.remove(index);
    }
  }

  void _onPageChanged(int pageIndex) {
    // ✅ Previous page index save කරනවා BEFORE setState
    final previousPageIndex = _currentPageIndex;

    setState(() {
      _currentPageIndex = pageIndex;
    });

    debugPrint('📄 Page changed to: $pageIndex');
    debugPrint('💾 Videos in memory: ${_videoControllers.length}');

    _stopViewTracking();

    // Previous post watch signal
    if (previousPageIndex >= 0 && _publicPosts.isNotEmpty) {
      if (previousPageIndex < _publicPosts.length) {
        final prevPostId =
            _publicPosts[previousPageIndex]['id'] as String? ?? '';
        _stopAlgorithmWatchTracking(prevPostId, previousPageIndex);
        _handleSkipSignal(prevPostId);
      }
    }

    // New post watch tracking start
    if (pageIndex < _publicPosts.length) {
      final newPostId = _publicPosts[pageIndex]['id'] as String? ?? '';
      _startAlgorithmWatchTracking(newPostId);
    }

    _videoControllers.forEach((index, controller) {
      if (index != pageIndex) {
        controller?.pause();
        debugPrint('⏸️ Paused video at page $index');
      }
    });

    // ✅ FIX: Video + Image දෙකම track කරනවා
    if (pageIndex < _publicPosts.length) {
      final post = _publicPosts[pageIndex];
      final postId = post['id'] ?? '';

      if (post['type'] == 'video') {
        if (_videoControllers[pageIndex] != null) {
          final controller = _videoControllers[pageIndex]!;
          if (!controller.value.isPlaying && _isPageActive) {
            controller.play();
            _updateAccessOrder(pageIndex);
            debugPrint('▶️ Playing existing video at page $pageIndex');
          }
        } else {
          _initializeVideoForPage(pageIndex);
        }
        _startViewTracking(postId, pageIndex);
      } else {
        // ✅ FIX: Video නෙවෙයි නම් විතරක් audio play
        if (post['type'] != 'video') {
          _playAudioForImagePost(pageIndex);
        }

        // ✅ IMAGE post - 3 seconds later history write
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _currentPageIndex == pageIndex) {
            _trackVideoView(postId, pageIndex);
            debugPrint('✅ Image view tracked for history: $postId');
          }
        });
      }
    }

    _prefetchNextVideos(pageIndex);

    final nextIndex = pageIndex + _preloadDistance;
    if (nextIndex < _publicPosts.length &&
        _publicPosts[nextIndex]['type'] == 'video' &&
        _videoControllers[nextIndex] == null) {
      _initializeVideoForPage(nextIndex);
      debugPrint('🔄 Preloading video controller for page $nextIndex');
    }

    _cleanupDistantVideos(pageIndex);
  }

// ════════════════════════════════════════════════════════
// ALGORITHM: Record Signal
// POST /api/algorithm/signal
// ════════════════════════════════════════════════════════
  Future<void> _recordSignal(String postId, String signalType,
      {Map<String, dynamic>? metadata}) async {
    if (_currentUserId == null || postId.isEmpty) return;
    try {
      await http.post(
        Uri.parse('https://avishka-tiktok-api.zeabur.app/api/algorithm/signal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _currentUserId,
          'postId': postId,
          'signalType': signalType,
          'metadata': metadata ?? {},
        }),
      ).timeout(const Duration(seconds: 5));
      debugPrint('📊 Signal recorded: $signalType → $postId');
    } catch (e) {
      debugPrint('⚠️ Signal record failed (non-critical): $e');
    }
  }

  // ════════════════════════════════════════════════════════
// ALGORITHM: Record Watch Signal
// POST /api/algorithm/watch
// ════════════════════════════════════════════════════════
  Future<void> _recordWatchSignal(String postId, double watchPercent,
      int durationSeconds) async {
    if (_currentUserId == null || postId.isEmpty) return;
    try {
      await http.post(
        Uri.parse('http://192.168.1.5:5000/api/algorithm/watch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _currentUserId,
          'postId': postId,
          'watchPercent': watchPercent,
          'durationSeconds': durationSeconds,
        }),
      ).timeout(const Duration(seconds: 5));
      debugPrint(
          '👁️ Watch signal: ${watchPercent.toStringAsFixed(0)}% → $postId');
    } catch (e) {
      debugPrint('⚠️ Watch signal failed (non-critical): $e');
    }
  }

  @override
  void dispose() {
    debugPrint('🛑 Disposing ForYouScreen - Cleaning up all videos');

    WidgetsBinding.instance.removeObserver(this);
    // 🆕 ADD: Stop view tracking
    _stopViewTracking();
    _pageController.dispose();

    _videoControllers.forEach((index, controller) {
      controller?.pause();
      controller?.dispose();
    });
    _videoControllers.clear();
    _videoAccessOrder.clear();
    _videoInitialized.clear();
    _showThumbnail.clear();
    _prefetchedUrls.clear();

    _videoProgressNotifiers.forEach((index, notifier) {
      notifier.dispose();
    });
    _videoProgressNotifiers.clear();

    _isDoubleSpeed.clear();
    _videoVisibility.clear();
    _isMediaLoading.clear();
    _audioControllers.forEach((_, ctrl) {
      ctrl?.pause();
      ctrl?.dispose();
    });
    _audioControllers.clear();
    // 🆕 ADD HERE ↓
    _repostInfoCache.clear();
    _watchStartTimes.clear();
    _watchSignalSent.clear();
    // PEXELS cleanup
    _pexelsEngagementCache.clear();
    _cachedTrendingAudioUrl    = null;
    _cachedTrendingAudioId     = null;
    _cachedTrendingAudioName   = null;
    _cachedTrendingAlbumArtUrl = null;
    super.dispose();
  }

  void _navigateToUserProfile(String uid, String username) {
    debugPrint('🔄 Navigating to profile:');
    debugPrint('   Target User ID: $uid');
    debugPrint('   Target Username: $username');

    _pauseAllVideos();

    // ✅ Find current post ID for signal
    if (_currentPageIndex < _publicPosts.length) {
      final postId = _publicPosts[_currentPageIndex]['id'] as String? ?? '';
      _recordSignal(postId, 'profile_visit');
      debugPrint('👤 Profile visit signal: $postId');
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityUserProfile(userId: uid),
      ),
    ).then((_) {
      if (_isPageActive && mounted) {
        _resumeCurrentVideo();
      }
    });
  }
  Future<void> _toggleLike(String postId, int pageIndex) async {
    if (_currentUserId == null) {
      debugPrint('⚠️ User not logged in - cannot like');
      return;
    }

    try {
      final postRef = _db.collection('media_posts').doc(postId);
      final likeRef = postRef.collection('likes').doc(_currentUserId);

      final likeDoc = await likeRef.get();
      final isCurrentlyLiked = likeDoc.exists;

      if (isCurrentlyLiked) {
        debugPrint('💔 Unliking post: $postId');

        await likeRef.delete();
        await postRef.update({
          'likes': FieldValue.increment(-1),
        });

        await _db.collection('likes').doc('${_currentUserId}_$postId').delete();

        debugPrint('✅ Unlike completed');
      } else {
        debugPrint('❤️ Liking post: $postId');

        final currentUserDoc = await _db
            .collection('users')
            .doc(_currentUserId)
            .get();
        final currentUsername = currentUserDoc.data()?['name'] ?? 'User';

        final likeData = {
          'uid': _currentUserId,
          'username': currentUsername,
          'timestamp': Timestamp.now(),
        };

        await likeRef.set(likeData);

        await postRef.update({
          'likes': FieldValue.increment(1),
        });

        await _db.collection('likes').doc('${_currentUserId}_$postId').set({
          'uid': _currentUserId,
          'username': currentUsername,
          'postId': postId,
          'timestamp': Timestamp.now(),
        });

        debugPrint('✅ Like saved to both locations');

        _sendLikeNotificationInBackground(postId, pageIndex);
      }
    } catch (e) {
      debugPrint('❌ Error toggling like: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update like'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// ════════════════════════════════════════════════════════════════════
  // REPOST — Check if any followed user reposted this post
  // ════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> _loadRepostInfo(String postId) async {
    if (_currentUserId == null) return null;

    // Cache hit
    if (_repostInfoCache.containsKey(postId)) {
      return _repostInfoCache[postId];
    }

    try {
      // Get reposts for this post (limit 20 for performance)
      final repostsSnap = await _db
          .collection('reposts')
          .where('postId', isEqualTo: postId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      if (repostsSnap.docs.isEmpty) {
        _repostInfoCache[postId] = null;
        return null;
      }

      // Check if any reposter is followed by current user
      for (final doc in repostsSnap.docs) {
        final data = doc.data();
        final reposterId = data['userId'] as String? ?? '';

        // Skip self-reposts in label (own reposts already shown via repost count)
        if (reposterId == _currentUserId) continue;

        final followDoc = await _db
            .collection('follows')
            .doc('${_currentUserId}_$reposterId')
            .get();

        if (followDoc.exists &&
            followDoc.data()?['status'] == 'active') {
          final info = {
            'reposter_id': reposterId,
            'reposter_name': data['username'] ?? 'Someone',
          };
          _repostInfoCache[postId] = info;
          return info;
        }
      }

      _repostInfoCache[postId] = null;
      return null;
    } catch (e) {
      debugPrint('❌ Repost info error: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // REPOST LABEL — "🔁 Username reposted" widget
  // ════════════════════════════════════════════════════════════════════
  Widget _buildRepostLabel(String postId) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadRepostInfo(postId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final reposterName = snapshot.data!['reposter_name'] as String;

        return Positioned(
          top: MediaQuery
              .of(context)
              .padding
              .top + 60,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.repeat_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '@$reposterName reposted',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 🆕 NEW: Toggle save function
// AFTER:
  Future<void> _toggleSave(String postId) async {
    if (_currentUserId == null) return;

    try {
      // Root collection — like count tracking සඳහා
      final rootRef = _db.collection('saved_posts').doc('${_currentUserId}_$postId');
      // User subcollection — Posts tab display සඳහා
      final userRef = _db
          .collection('users')
          .doc(_currentUserId)
          .collection('saved_posts')
          .doc(postId);

      final savedDoc = await rootRef.get();
      final isCurrentlySaved = savedDoc.exists;

      if (isCurrentlySaved) {
        await rootRef.delete();
        await userRef.delete();
        debugPrint('🔓 Unsaved post: $postId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from saved')),
          );
        }
      } else {
        // Post data ගන්නවා thumbnail සහ view_count සඳහා
        final postData = _publicPosts.firstWhere(
              (p) => p['id'] == postId,
          orElse: () => {},
        );

        final timestamp = DateTime.now().millisecondsSinceEpoch;

        await rootRef.set({
          'userId': _currentUserId,
          'postId': postId,
          'timestamp': timestamp,
        });

        // 🟢 REPLACE WITH:
        // Thumbnail + viewCount — Firestore fallback with type-safe cast
        String thumbnailUrl = (postData['thumbnail_url'] as String?) ?? '';
        int viewCountVal = (postData['viewCount'] as num?)?.toInt()
            ?? (postData['view_count'] as num?)?.toInt()
            ?? 0;

        if (thumbnailUrl.isEmpty || viewCountVal == 0) {
          try {
            final postDoc = await _db.collection('media_posts').doc(postId).get();
            final d = postDoc.data() ?? {};
            if (thumbnailUrl.isEmpty) {
              thumbnailUrl = (d['thumbnail_url'] as String?) ?? '';
            }
            if (viewCountVal == 0) {
              viewCountVal = (d['viewCount'] as num?)?.toInt() ?? 0;
            }
          } catch (_) {}
        }

        await userRef.set({
          'postId': postId,
          'thumbnail_url': thumbnailUrl,
          'view_count': viewCountVal,
          'media_url': postData['media_url'] ?? '',
          'type': postData['type'] ?? 'video',
          'uid': postData['uid'] ?? '',
          'username': postData['username'] ?? '',
          'saved_at': FieldValue.serverTimestamp(),
        });

        debugPrint('💾 Saved post: $postId');
        debugPrint('💾 Saved post with thumbnail: $postId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved successfully')),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error toggling save: $e');
    }
  }

  void _showCommentBottomSheet(String postId, String postOwnerId,
      int currentCommentCount) {
    // ✅ allowComment check — post data ලා බලනවා
    final postIndex = _publicPosts.indexWhere((p) => p['id'] == postId);
    if (postIndex != -1) {
      final bool allowComment = _publicPosts[postIndex]['allowComment'] ?? true;
      if (!allowComment) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comments are disabled for this post'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return; // ← sheet open නොකර return
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CommentBottomSheet(
            postId: postId,
            postOwnerId: postOwnerId,
            initialCommentCount: currentCommentCount,
          ),
    ).then((_) {
      _refreshCommentCount(postId);
    });
  }

  void _navigateToSoundDetail(Map<String, dynamic> post, int pageIndex) {
    final audioId = post['audio_id'] ?? 'original_sound';
    final audioName = post['audio_name'] ?? 'Original Sound';
    final albumArtUrl = post['album_art_url'];
    final creatorUsername = post['username'] ?? 'Unknown';
    final soundUrl = post['sound_url'];

    debugPrint('🎵 Navigating to sound detail:');
    debugPrint('   Audio ID: $audioId');
    debugPrint('   Audio Name: $audioName');
    debugPrint('   Creator: $creatorUsername');

    _pauseAllVideos();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SoundDetailPage(
              soundId: audioId,
              // 🎯 Pass sound ID (NOT user ID)
              soundName: audioName,
              albumArtUrl: albumArtUrl,
              heroTag: 'vinyl_disc_$pageIndex',
              creatorUsername: creatorUsername,
              creatorProfileUrl: null,
              soundUrl: soundUrl,
            ),
      ),
    ).then((_) {
      if (_isPageActive && mounted) {
        _resumeCurrentVideo();
      }
    });
  }

  void _handleVideoVisibilityChanged(int pageIndex, double visibleFraction) {
    final wasVisible = _videoVisibility[pageIndex] ?? false;
    final isNowVisible = visibleFraction > 0.5;

    if (wasVisible != isNowVisible) {
      setState(() {
        _videoVisibility[pageIndex] = isNowVisible;
      });

      final controller = _videoControllers[pageIndex];
      if (controller != null && controller.value.isInitialized) {
        if (isNowVisible && pageIndex == _currentPageIndex && _isPageActive) {
          if (!controller.value.isPlaying) {
            controller.play();
            debugPrint('▶️ Video $pageIndex became visible - playing');
          }
        } else {
          if (controller.value.isPlaying) {
            controller.pause();
            debugPrint('⏸️ Video $pageIndex became hidden - pausing');
          }
        }
      }
    }
  }

  // 🆕 NEW: Shimmer effect for loading media
  Widget _buildMediaShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!,
      highlightColor: Colors.grey[700]!,
      child: Container(
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 120,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: 3,
          itemBuilder: (context, index) => const _PostCardShimmer(),
        ),
      );
    }

    if (_publicPosts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.video_library_outlined,
                size: 80,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              const Text(
                'No videos yet',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check back later for new content',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _loadPublicPosts(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🆕 RefreshIndicator එකතු කරනවා
          RefreshIndicator(
            onRefresh: refreshFeed,
            backgroundColor: const Color(0xFF1E1E1E),
            color: const Color(0xFFFF3B5C),
            displacement: 60,
            // Status bar එකට යටින්
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _publicPosts.length,
              onPageChanged: _onPageChanged,
              physics: const AlwaysScrollableScrollPhysics(),
              // 🆕 මේක add කරන්න
              itemBuilder: (context, index) {
                return _buildPostPage(_publicPosts[index], index);
              },
            ),
          ),
          // 🔄 Refresh loading indicator at top
          if (_isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                child: const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF3B5C)),
                ),
              ),
            ),
          // 🆕 NEW: Enhanced loading indicator with retry option
          if (_isLoadingMore && !_hasInternetConnection)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off,
                        color: Colors.red,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No Internet Connection',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _loadMorePosts(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            if (_isLoadingMore)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Loading more...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _isLoading
                ? Container(
              height: 3,
              child: const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
                : const SizedBox.shrink(),
          ),

          Positioned(
            top: MediaQuery
                .of(context)
                .padding
                .top + 16,
            right: 16,
            child: GestureDetector(
              onTap: () => SearchNavigationHelper.navigateToSearch(context),
              child: SvgPicture.asset(
                'assets/images/search_icon.svg',
                width: 28,
                height: 28,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPublicPosts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Check internet
      final hasInternet = await _checkInternetConnection();
      if (!hasInternet) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      debugPrint('📥 Loading initial public posts for ForYou feed');

      // 🎯 BACKEND HANDLES ALL PRIVACY CHECKS - NO CLIENT-SIDE FILTERING!
      final posts = await _fetchDiversifiedFeed(
        limit: _postsPerPage,
        userId: _currentUserId, // 🆕 Send userId to backend
      );

      if (posts.isEmpty) {
        debugPrint('ℹ️ No posts returned from backend');
        setState(() {
          _isLoading = false;
          _publicPosts = [];
          _hasMorePosts = false;
        });
        return;
      }

      // ✅ NO MORE _canViewPost() CHECKS - Backend already filtered!
      _publicPosts = posts;
      _hasMorePosts = posts.length >= _postsPerPage;
// ✅ AFTER:
// Filter already-seen posts
      final freshPosts = _filterSeenPosts(posts);
      await _resetSeenPostsIfNeeded(freshPosts.length);
      _publicPosts =
      freshPosts.isEmpty ? posts : freshPosts; // fallback if all seen
      _hasMorePosts = posts.length >= _postsPerPage;

// Mark all loaded posts as seen
      for (final post in _publicPosts) {
        final id = post['id'] as String? ?? '';
        if (id.isNotEmpty) await _saveSeenPostId(id);
      }
      debugPrint(
          '✅ Loaded ${_publicPosts.length} posts (Has more: $_hasMorePosts)');

      setState(() {
        _isLoading = false;
      });
// 🆕 PEXELS: Initial load වෙලාවෙත් posts අඩු නම් inject
      if (_publicPosts.length < 5) {
        await _injectPexelsIfNeeded();
      }

      // ✅ FIX: First post track + initialize (video හෝ image දෙකටම)
      if (_publicPosts.isNotEmpty) {
        final firstPost = _publicPosts[0];
        final firstPostId = firstPost['id'] ?? '';

        if (firstPost['type'] == 'video') {
          await _initializeVideoForPage(0);
          _prefetchNextVideos(0);
          _startViewTracking(firstPostId, 0);
        } else {
          // 🎵 IMAGE: Audio play කරන්න (first post)
          _playAudioForImagePost(0);

          // ✅ IMAGE: 3 seconds පසු history write
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _currentPageIndex == 0) {
              _trackVideoView(firstPostId, 0);
              debugPrint(
                  '✅ Image view tracked for history (first post): $firstPostId');
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading public posts: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load posts. Please try again.'),
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _loadPublicPosts(),
            ),
          ),
        );
      }
    }
  }

  Widget _buildPostPage(Map<String, dynamic> post, int pageIndex) {
    final isVideo = post['type'] == 'video';
    final mediaUrl = post['media_url'] ?? '';
    final description = post['description'] ?? '';
    final username = post['username'] ?? 'Unknown';
    final hashtags = (post['hashtags'] as List?)?.cast<String>() ?? [];
    final showFull = _showFullDescription[pageIndex] ?? false;
    final isLongDescription = description.length > 80;
    final postId = post['id'] ?? '';
    final postOwnerId = post['uid'] ?? '';
    final String? soundUrl = post['sound_url'] as String?;
    final String? audioId = post['audio_id'] as String?;
    final bool hasSound =
        (soundUrl != null && soundUrl.isNotEmpty) ||
            (audioId != null &&
                audioId.isNotEmpty &&
                audioId != 'original_sound');
    final controller = _videoControllers[pageIndex];
    final isPlaying = isVideo
        ? (controller?.value.isPlaying ?? false)
        : (_audioControllers[pageIndex]?.value.isPlaying ?? false);
    Widget mediaWidget;
    if (isVideo) {
      mediaWidget = VisibilityDetector(
        key: Key('video_$pageIndex'),
        onVisibilityChanged: (info) {
          _handleVideoVisibilityChanged(pageIndex, info.visibleFraction);
        },
        child: _buildVideoPlayer(pageIndex, post),
      );
    } else {
      final mediaUrls = _getMediaUrls(post);
      mediaWidget = _buildImageCarousel(mediaUrls, post, pageIndex);
    }
    mediaWidget = GestureDetector(
      onDoubleTapDown: (details) =>
          _handleDoubleTap(pageIndex, postId, details),
      onDoubleTap: () {},

      child: mediaWidget,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        mediaWidget,

        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 🆕 Repost label — Stack children list ට add කරන්න
        _buildRepostLabel(postId),

        Positioned(
          right: 8,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isPexelsPost(post)
                  ? _buildPexelsLikeButton(postId, pageIndex)
                  : _buildLikeButton(postId, pageIndex),
              const SizedBox(height: 28),
              // ← ADD: Comment button
              StreamBuilder<DocumentSnapshot>(
                stream: _isPexelsPost(post)
                    ? _db.collection('pexels_posts').doc(postId).snapshots()
                    : _db.collection('media_posts').doc(postId).snapshots(),
                builder: (context, snapshot) {
                  int commentCount = 0;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    commentCount = data?['commentCount'] as int? ?? 0;
                  }
                  return _buildActionButton(
                    icon: 'assets/images/comment_icon.svg',
                    label: _formatCount(commentCount),
                    onTap: () => _isPexelsPost(post)
                        ? _showPexelsCommentSheet(postId, commentCount)
                        : _showCommentBottomSheet(postId, postOwnerId, commentCount),
                  );
                },
              ),

              const SizedBox(height: 28),
              _isPexelsPost(post)
                  ? _buildPexelsSaveButton(postId, pageIndex)
                  : _buildSaveButton(postId),
              StreamBuilder<DocumentSnapshot>(
                stream: _isPexelsPost(post)
                    ? _db.collection('pexels_posts').doc(postId).snapshots()
                    : _db.collection('media_posts').doc(postId).snapshots(),
                builder: (context, snapshot) {
                  int shareCount = 0;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    shareCount = data?['shares_count'] as int? ?? 0;
                  }
                  return _buildActionButton(
                    icon: 'assets/images/share_icon.svg',
                    label: _formatCount(shareCount),
                    onTap: () => _isPexelsPost(post)
                        ? _sharePexelsPost(post)
                        : _sharePost(post),
                  );
                },
              ),
              ...() {

                if (!hasSound) return <Widget>[];
                return <Widget>[
                  const SizedBox(height: 28),
                  RotatingVinylDisc(
                    isPlaying: isPlaying,
                    albumArtUrl: post['album_art_url'],
                    soundId: post['audio_id'],
                    onTap: () => _navigateToSoundDetail(post, pageIndex),
                    heroTag: 'vinyl_disc_$pageIndex',
                  ),
                ];
              }(),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 80,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ TITLE - image post නම් විතරක්
              if (!isVideo && (post['title'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty) ...[
                Text(
                  post['title'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
              ],

              Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        _navigateToUserProfile(post['uid'] ?? '', username),
                    child: _buildUserAvatar(post['uid'] ?? '', username),
                  ),

                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      username,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildFollowButtonForFeed(postOwnerId, username),
                ],
              ),
              const SizedBox(height: 4),
              if (_formatTimeAgo(post['createdAt'] ?? post['timestamp'])
                  .isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _formatTimeAgo(post['createdAt'] ?? post['timestamp']),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClickableDescription(description, username, pageIndex),
                  if (isLongDescription)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showFullDescription[pageIndex] = !showFull;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          showFull ? 'See less' : 'See more',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFCCCCCC),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),


              const SizedBox(height: 8),

    if (hasSound) ...[
    Row(
    children: [
    Expanded(
    child: Row(
    children: [
    const Icon(
    Icons.music_note, color: Colors.white, size: 12),
    const SizedBox(width: 4),
    Expanded(
    child: Text(
    post['audio_name'] ?? 'Original Sound',
                            style: const TextStyle(fontSize: 12,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ✅ Replace කරන්න
                  StreamBuilder<DocumentSnapshot>(
                    stream: _db
                        .collection('media_posts')
                        .doc(postId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int viewCount = 0;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<
                            String,
                            dynamic>?;
                        viewCount = data?['viewCount'] as int? ?? 0;
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                                Icons.remove_red_eye, color: Colors.white,
                                size: 12),
                            const SizedBox(width: 3),
                            Text(
                              _formatCount(viewCount),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }, // ← builder close
                  ), // ← StreamBuilder close

                ], // ← Row children close (music_note + StreamBuilder)
              ), // ← Row close (music + views row)
    ],
              if (post['tagged_friends'] != null &&
                  (post['tagged_friends'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildTaggedFriendsPreview(post['tagged_friends'], post['id']),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Firestore uid එකෙන් real profile image load කරන widget
  Widget _buildUserAvatar(String uid, String fallbackUsername,
      {double size = 45}) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        String? profileImageUrl;
        String displayName = fallbackUsername;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          profileImageUrl =
              data['profile_picture_url'] ??
                  data['profile_url'] ??
                  data['profileUrl'];
          displayName = data['name'] ?? fallbackUsername;
        }

        final initial = displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : '?';

        // Consistent color per user
        final hash = uid.hashCode.abs();
        final colors = [
          const Color(0xFF3B82F6),
          const Color(0xFFE53935),
          const Color(0xFF10B981),
          const Color(0xFF8B5CF6),
          const Color(0xFFF59E0B),
          const Color(0xFFEC4899),
        ];
        final bgColor = colors[hash % colors.length];

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: ClipOval(
            child: profileImageUrl != null && profileImageUrl.isNotEmpty
                ? Image.network(
              profileImageUrl,
              fit: BoxFit.cover,
              width: size,
              height: size,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: bgColor,
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: size * 0.4,
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) =>
                  Container(
                    color: bgColor,
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: size * 0.4,
                        ),
                      ),
                    ),
                  ),
            )
                : Container(
              color: bgColor,
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.4,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 🎯 FIX: Following button එක transparent කරලා, center align කරලා, size adjust කරලා
  Widget _buildFollowButtonForFeed(String targetUserId, String targetUsername) {
    if (_currentUserId == null) {
      return const SizedBox.shrink();
    }

    final followDocId = '${_currentUserId}_$targetUserId';

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('follows').doc(followDocId).snapshots(),
      builder: (context, snapshot) {
        bool isFollowing = false;
        bool isPending = false;
        String buttonText = 'Follow';
        Color buttonColor = const Color(0xFFFF3B5C);
        Color borderColor = Colors.white.withOpacity(0.5);
        IconData buttonIcon = Icons.person_add;

        if (snapshot.hasData && snapshot.data != null &&
            snapshot.data!.exists) {
          final followData = snapshot.data!.data() as Map<String, dynamic>?;
          final status = followData?['status'] ?? '';

          if (status == 'active') {
            isFollowing = true;
            buttonText = 'Following';
            buttonColor = Colors.transparent; // 🎯 FIX: Transparent background
            borderColor = Colors.white.withOpacity(0.6);
            buttonIcon = Icons.check;
          } else if (status == 'pending') {
            isPending = true;
            buttonText = 'Requested';
            buttonColor = const Color(0xFFFFA500);
            borderColor = Colors.white.withOpacity(0.5);
            buttonIcon = Icons.access_time;
          }
        }

        return GestureDetector(
          onTap: () => _handleFeedFollow(targetUserId, targetUsername),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            // 🎯 FIX: Reduced padding
            decoration: BoxDecoration(
              color: buttonColor,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              // 🎯 FIX: Center align
              children: [
                Icon(
                  buttonIcon,
                  color: Colors.white,
                  size: 16, // 🎯 FIX: Slightly smaller icon
                ),
                const SizedBox(width: 6), // 🎯 FIX: Better spacing
                Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 14, // 🎯 FIX: Slightly smaller text
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTaggedFriendsBottomSheet(List<dynamic> taggedFriends,
      String postId) {
    if (taggedFriends.isEmpty) {
      return;
    }

    debugPrint(
        '🏷️ Opening tagged friends sheet with ${taggedFriends.length} friends');

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Tagged in This Post',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView.builder(
                  itemCount: taggedFriends.length,
                  itemBuilder: (context, index) {
                    final friend = taggedFriends[index] as Map<String, dynamic>;
                    final name = friend['username'] ?? 'Unknown';
                    final avatarUrl = friend['avatarUrl'] ?? '';

                    return _buildTaggedFriendRow(name, avatarUrl);
                  },
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2D2D),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaggedFriendRow(String name, String avatarUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: avatarUrl.isNotEmpty
                ? Image.network(
              avatarUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B5C),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                );
              },
            )
                : Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B5C),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B5C).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFF3B5C).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Text(
              '🏷️ Tagged',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFFF3B5C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaggedFriendsPreview(List<dynamic> taggedFriends,
      String postId) {
    if (taggedFriends.isEmpty) {
      return const SizedBox.shrink();
    }

    String displayText = '';

    if (taggedFriends.length == 1) {
      final username = taggedFriends[0]['username'] ?? 'Unknown';
      displayText = 'with @$username';
    } else if (taggedFriends.length == 2) {
      final name1 = taggedFriends[0]['username'] ?? 'Unknown';
      final name2 = taggedFriends[1]['username'] ?? 'Unknown';
      displayText = 'with @$name1 & @$name2';
    } else {
      final name1 = taggedFriends[0]['username'] ?? 'Unknown';
      final remainingCount = taggedFriends.length - 1;
      displayText = 'with @$name1 & $remainingCount others';
    }

    return GestureDetector(
      onTap: () => _showTaggedFriendsBottomSheet(taggedFriends, postId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🏷️',
              style: TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 4),

            Flexible(
              child: Text(
                displayText,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikeButton(String postId, int pageIndex) {
    if (_currentUserId == null) {
      return _buildActionButton(
        icon: 'assets/images/like_outline.svg',
        label: '0',
        onTap: () {},
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('media_posts').doc(postId).snapshots(),
      builder: (context, postSnapshot) {
        int likeCount = 0;

        if (postSnapshot.hasData && postSnapshot.data != null &&
            postSnapshot.data!.exists) {
          final data = postSnapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('likes')) {
            likeCount = data['likes'] as int? ?? 0;
          }
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: _db
              .collection('media_posts')
              .doc(postId)
              .collection('likes')
              .doc(_currentUserId)
              .snapshots(),
          builder: (context, likeSnapshot) {
            bool isLiked = false;

            if (likeSnapshot.hasData && likeSnapshot.data != null) {
              isLiked = likeSnapshot.data!.exists;
            }

            return _buildActionButton(
              icon: 'assets/images/like_outline.svg',
              activeIcon: 'assets/images/like_filled.svg',
              label: _formatCount(likeCount),
              isActive: isLiked,
              onTap: () => _toggleLike(postId, pageIndex),
            );
          },
        );
      },
    );
  }

  // 🆕 NEW: Save button with dynamic count
  Widget _buildSaveButton(String postId) {
    if (_currentUserId == null) {
      return _buildActionButton(
        icon: 'assets/images/bookmark_outline.svg',
        label: '0',
        onTap: () {},
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db
          .collection('saved_posts')
          .doc('${_currentUserId}_$postId')
          .snapshots(),
      builder: (context, snapshot) {
        bool isSaved = false;

        if (snapshot.hasData && snapshot.data != null) {
          isSaved = snapshot.data!.exists;
        }

        // Get save count (you can track this in Firestore if needed)
        return StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('saved_posts')
              .where('postId', isEqualTo: postId)
              .snapshots(),
          builder: (context, countSnapshot) {
            int saveCount = 0;
            if (countSnapshot.hasData) {
              saveCount = countSnapshot.data!.docs.length;
            }

            return _buildActionButton(
              icon: 'assets/images/bookmark_outline.svg',
              activeIcon: 'assets/images/bookmark_filled.svg',
              label: _formatCount(saveCount),
              isActive: isSaved,
              onTap: () => _toggleSave(postId),
            );
          },
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime postTime;

    if (timestamp is Timestamp) {
      postTime = timestamp.toDate();
    } else if (timestamp is int) {
      postTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return '';
    }

    final now = DateTime.now();
    final diff = now.difference(postTime);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (diff.inDays / 365).floor();
      return '${years}y ago';
    }
  }

  Widget _buildVideoPlayer(int pageIndex, Map<String, dynamic> post) {
    final controller = _videoControllers[pageIndex];
    final isInitialized = _videoInitialized[pageIndex] ?? false;
    final showThumbnail = _showThumbnail[pageIndex] ?? false;
    final thumbnailUrl = post['thumbnail_url'] as String?;
    final isLoading = _isMediaLoading[pageIndex] ?? false;

    // 🆕 LOADING STATE
    if (isLoading || (showThumbnail && !isInitialized)) {
      return _buildMediaShimmer();
    }

    // 🆕 THUMBNAIL WITH LOADING
    if (showThumbnail && thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // 🎯 9:16 CONTAINER with BLACK BACKGROUND
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Image.network(
                  thumbnailUrl,
                  fit: BoxFit.contain, // 🎯 CONTAIN mode - no crop/stretch
                  errorBuilder: (context, error, stackTrace) {
                    return _buildMediaShimmer();
                  },
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
        ],
      );
    }

    // 🆕 NOT INITIALIZED
    if (!isInitialized || controller == null) {
      return _buildMediaShimmer();
    }

    // 🎬 MAIN VIDEO PLAYER - FIXED 9:16 ASPECT RATIO with BLACK BACKGROUND
    return GestureDetector(
      onTap: () {
        setState(() {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        });
      },
      onLongPressStart: (_) {
        _toggleDoubleSpeed(pageIndex);
        HapticFeedback.mediumImpact();
      },
      onLongPressEnd: (_) {
        if (_isDoubleSpeed[pageIndex] == true) {
          _toggleDoubleSpeed(pageIndex);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 🎯 BLACK BACKGROUND CONTAINER (Full screen)
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16, // 🎯 FIXED 9:16 ratio
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),

          // ⏸️ PLAY/PAUSE ICON
          if (!controller.value.isPlaying)
            Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),

          // ⚡ 2X SPEED INDICATOR
          if (_isDoubleSpeed[pageIndex] == true)
            Positioned(
              top: 60,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fast_forward, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '2x',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 📊 VIDEO PROGRESS BAR
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _videoProgressNotifiers[pageIndex] ??
                  ValueNotifier(0.0),
              builder: (context, progress, child) {
                return LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 2,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 UI IMPROVED: Smaller icon size (28px) and better padding
  Widget _buildActionButton({
    dynamic icon,
    String? activeIcon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
    bool isIconData = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shadow wrapper
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isIconData && icon is IconData
                  ? Icon(icon, color: Colors.white, size: 26)
                  : SvgPicture.asset(
                isActive && activeIcon != null ? activeIcon : icon as String,
                width: 26,
                height: 26,
                colorFilter: ColorFilter.mode(
                  isActive ? Colors.red : Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                // ✅ Letter spacing
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshCommentCount(String postId) async {
    try {
      debugPrint('🔄 Refreshing comment count for post: $postId');

      final postDoc = await _db.collection('media_posts').doc(postId).get();

      if (postDoc.exists) {
        final newCommentCount = postDoc.data()?['commentCount'] ?? 0;

        debugPrint('✅ New comment count: $newCommentCount');

        final postIndex = _publicPosts.indexWhere((post) =>
        post['id'] == postId);

        if (postIndex != -1) {
          setState(() {
            _publicPosts[postIndex]['commentCount'] = newCommentCount;
          });
          debugPrint('✅ Comment count updated in UI');
        }
      }
    } catch (e) {
      debugPrint('❌ Error refreshing comment count: $e');
    }
  }

  void _sendLikeNotificationInBackground(String postId, int pageIndex) {
    if (_currentUserId == null) return;

    final post = _publicPosts[pageIndex];
    final postOwnerId = post['uid'] ?? '';

    if (postOwnerId == _currentUserId) {
      debugPrint('⏭️ Skipping self-notification');
      return;
    }

    _sendLikeNotificationToBackend(postId, post).then((_) {
      debugPrint('✅ Background notification sent');
    }).catchError((error) {
      debugPrint('⚠️ Notification failed (non-critical): $error');
    });
  }

  Future<void> _sendLikeNotificationToBackend(String postId,
      Map<String, dynamic> post) async {
    try {
      debugPrint('\n🔔 ========== SENDING NOTIFICATION ==========');

      final postOwnerId = post['uid'] ?? '';
      final postOwnerUsername = post['username'] ?? 'Unknown';

      if (postOwnerId == _currentUserId) {
        debugPrint('⏭️ Skipping self-notification');
        return;
      }

      final currentUserDoc = await _db
          .collection('users')
          .doc(_currentUserId)
          .get();
      final currentUsername = currentUserDoc.data()?['name'] ?? 'User';

      debugPrint('📤 From: $currentUsername ($_currentUserId)');
      debugPrint('📥 To: $postOwnerUsername ($postOwnerId)');

      const backendUrl = 'http://192.168.1.5:5000/api/posts/like';

      final requestBody = {
        'postId': postId,
        'userUid': _currentUserId,
        'username': currentUsername,
        'postOwnerId': postOwnerId,
        'postOwnerUsername': postOwnerUsername,
      };

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Notification sent');
      } else {
        debugPrint('⚠️ Backend error: ${response.statusCode}');
      }
      debugPrint('==========================================\n');
    } catch (e) {
      debugPrint('❌ Notification error: $e');
    }
  }

  List<String> _getMediaUrls(Map<String, dynamic> post) {
    debugPrint('🖼️ Getting media URLs for post: ${post['id']}');
    debugPrint('   media_urls field: ${post['media_urls']}');
    debugPrint('   media_url field: ${post['media_url']}');

    final mediaUrls = post['media_urls'];
    if (mediaUrls != null && mediaUrls is List && mediaUrls.isNotEmpty) {
      final urls = List<String>.from(mediaUrls);
      debugPrint('   ✅ Found ${urls.length} URLs in media_urls array');
      return urls;
    }

    final single = post['media_url'] ?? '';
    debugPrint('   ⚠️ Falling back to single media_url');
    return single.isNotEmpty ? [single] : [];
  }

  Widget _buildImageCarousel(List<String> urls, Map<String, dynamic> post,
      int pageIndex) {
    if (urls.isEmpty) return const SizedBox.shrink();

    if (urls.length == 1) {
      return _FeedImageCarouselWidget(
        urls: urls,
        post: post,
        buildShimmer: _buildMediaShimmer,
        onLongPress: () {
          HapticFeedback.mediumImpact();
        },
      );
    }

    return _FeedImageCarouselWidget(
      urls: urls,
      post: post,
      buildShimmer: _buildMediaShimmer,
      onLongPress: () {
        HapticFeedback.mediumImpact();
      },
    );
  }

  // ForYouScreen - _playAudioForImagePost method replace karanna
  Future<void> _playAudioForImagePost(int pageIndex) async {
    // Stop all other audio controllers
    final toRemove = _audioControllers.keys
        .where((idx) => idx != pageIndex)
        .toList();
    for (final idx in toRemove) {
      await _audioControllers[idx]?.pause();
      await _audioControllers[idx]?.dispose();
      _audioControllers.remove(idx);
    }

    if (pageIndex >= _publicPosts.length) return;
    final post = _publicPosts[pageIndex];

    debugPrint('🔍 Sound fields for page $pageIndex (postId: ${post['id']}):');
    debugPrint('   sound_url     : ${post['sound_url']}');
    debugPrint('   audio_url     : ${post['audio_url']}');
    debugPrint('   music_url     : ${post['music_url']}');
    debugPrint('   audio_id      : ${post['audio_id']}');
    debugPrint('   audio_name    : ${post['audio_name']}');
    debugPrint('   type          : ${post['type']}');

    // ✅ Try direct URL fields first
    String? soundUrl = (post['sound_url'] as String?)?.isNotEmpty == true
        ? post['sound_url'] as String
        : (post['audio_url'] as String?)?.isNotEmpty == true
        ? post['audio_url'] as String
        : (post['music_url'] as String?)?.isNotEmpty == true
        ? post['music_url'] as String
        : null;

// ✅ If no direct URL, try fetching from another post with same audio_id
    if (soundUrl == null || soundUrl.isEmpty) {
      final audioId = post['audio_id'] as String?;
      if (audioId != null && audioId.isNotEmpty &&
          audioId != 'original_sound') {
        debugPrint('🔍 Searching other posts with audio_id: $audioId');

        try {
          final snapshot = await _db
              .collection('media_posts')
              .where('audio_id', isEqualTo: audioId)
              .where('sound_url', isGreaterThan: '')
              .limit(1)
              .get();

          if (snapshot.docs.isNotEmpty) {
            final data = snapshot.docs.first.data();
            soundUrl = data['sound_url'] as String?;
            debugPrint('✅ Found sound_url from sibling post: $soundUrl');
          } else {
            debugPrint(
                '⚠️ No post found with sound_url for audio_id: $audioId');
          }
        } catch (e) {
          debugPrint('❌ Error searching sibling posts: $e');
        }
      }
    }

    debugPrint('🎵 Resolved soundUrl for page $pageIndex: $soundUrl');

    if (soundUrl == null || soundUrl.isEmpty) {
      debugPrint('⚠️ No sound URL found in any field - skipping audio');
      return;
    }

    // ✅ Already have a controller for this page? Reuse it
    if (_audioControllers[pageIndex] != null) {
      final existing = _audioControllers[pageIndex]!;
      if (existing.value.isInitialized && !existing.value.isPlaying &&
          _isPageActive) {
        await existing.play();
        debugPrint('▶️ Resumed existing audio for page $pageIndex');
        if (mounted) setState(() {});
      }
      return;
    }

    try {
      debugPrint('🎵 Initializing audio: $soundUrl');
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(soundUrl));

      _audioControllers[pageIndex] = ctrl;

      await ctrl.initialize();
      debugPrint('✅ Audio initialized, duration: ${ctrl.value.duration}');

      ctrl.setLooping(true);
      await ctrl.setVolume(1.0);

      if (pageIndex != _currentPageIndex) {
        debugPrint('⏭️ Page changed during audio init - discarding');
        await ctrl.dispose();
        _audioControllers.remove(pageIndex);
        return;
      }

      if (_isPageActive) {
        await ctrl.play();
        debugPrint('▶️ Audio playing: ${ctrl.value.isPlaying}');
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Audio error: $e');
      _audioControllers.remove(pageIndex);
    }
  }

  void _handleHashtagTap(String hashtag) {
    debugPrint('🏷️ Tapped hashtag: #$hashtag');
    // TODO: Navigate to hashtag search results page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('#$hashtag'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF2C2C2C),
      ),
    );
  }

  // ============================================================
// SEEN POSTS FILTER - ADD THIS METHOD
// ============================================================

  /// SharedPreferences වලින් seen IDs load කරනවා (app restart වෙනත් persist)
  Future<void> _loadSeenPostIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(
          'seen_post_ids_${_currentUserId ?? "guest"}') ?? [];
      _seenPostIds.addAll(stored);
      debugPrint('✅ Loaded ${_seenPostIds.length} seen post IDs from storage');
    } catch (e) {
      debugPrint('❌ Error loading seen IDs: $e');
    }
  }

  /// Seen ID SharedPreferences වලට save කරනවා
  Future<void> _saveSeenPostId(String postId) async {
    try {
      _seenPostIds.add(postId);
      final prefs = await SharedPreferences.getInstance();
      final key = 'seen_post_ids_${_currentUserId ?? "guest"}';

      // Max 500 IDs store කරනවා (memory control)
      List<String> stored = _seenPostIds.toList();
      if (stored.length > 500) {
        stored = stored.sublist(stored.length - 500); // Latest 500 keep
        _seenPostIds
          ..clear()
          ..addAll(stored);
      }

      await prefs.setStringList(key, stored);
      debugPrint('💾 Saved seen post: $postId (Total: ${_seenPostIds.length})');
    } catch (e) {
      debugPrint('❌ Error saving seen ID: $e');
    }
  }

  /// Feed posts filter කරනවා - already seen ඒවා remove
  List<Map<String, dynamic>> _filterSeenPosts(
      List<Map<String, dynamic>> posts) {
    if (_seenPostIds.isEmpty) return posts;

    final filtered = posts.where((post) {
      final id = post['id'] as String? ?? '';
      return !_seenPostIds.contains(id);
    }).toList();

    debugPrint(
        '🔍 Filter: ${posts.length} posts → ${filtered.length} (removed ${posts
            .length - filtered.length} seen)');
    return filtered;
  }

  /// Seen posts clear කරනවා (80% threshold hit වෙනකොට)
  Future<void> _resetSeenPostsIfNeeded(int totalAvailable) async {
    if (totalAvailable == 0) return;

    final seenRatio = _seenPostIds.length /
        (totalAvailable + _seenPostIds.length);
    debugPrint('📊 Seen ratio: ${(seenRatio * 100).toStringAsFixed(1)}%');

    if (seenRatio >= _seenResetThreshold) {
      debugPrint('🔄 80%+ seen - Resetting seen posts cache...');
      _seenPostIds.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('seen_post_ids_${_currentUserId ?? "guest"}');
      debugPrint('✅ Seen posts cache reset');
    }
  }

  // ════════════════════════════════════════════════════════
// ALGORITHM: Watch Percentage Tracking
// ════════════════════════════════════════════════════════

// Per-post watch tracking data
  final Map<String, int> _watchStartTimes = {}; // postId → start ms
  final Map<String, bool> _watchSignalSent = {}; // postId → already sent?

  // ══════════════════════════════════════════════════════
// PEXELS INTEGRATION — NEW STATE VARIABLES
// ══════════════════════════════════════════════════════
  static const String _pexelsApiKey =
      'IlqjoaL1ckMPQJqN9EutMDfdoVw1oQMF4hyL4TSzrOPgMp4HKgDNdwoX';
  static const String _pexelsOfficialUid     = 'vibeflick_official';
  static const String _pexelsOfficialUsername = 'VibeFlick Official';

  int  _pexelsCurrentPage  = 1;
  bool _isFetchingPexels   = false;

// Pexels posts වලට likes/comments/shares DB save tracking
  final Map<String, Map<String, dynamic>> _pexelsEngagementCache = {};

// Trending audio cache (Pexels silent videos සඳහා)
  String? _cachedTrendingAudioUrl;
  String? _cachedTrendingAudioId;
  String? _cachedTrendingAudioName;
  String? _cachedTrendingAlbumArtUrl;
  /// Video watch කරන්න පටන් ගත්ත වෙලාව mark කරනවා
  void _startAlgorithmWatchTracking(String postId) {
    if (postId.isEmpty) return;
    _watchStartTimes[postId] = DateTime
        .now()
        .millisecondsSinceEpoch;
    _watchSignalSent[postId] = false;
    debugPrint('⏱️ Watch tracking started: $postId');
  }

  /// Video ගිය page එකෙ watch % calculate කරල signal යවනවා
  Future<void> _stopAlgorithmWatchTracking(String postId,
      int pageIndex) async {
    if (postId.isEmpty) return;

    final startMs = _watchStartTimes[postId];
    if (startMs == null) return;

    final alreadySent = _watchSignalSent[postId] ?? false;
    if (alreadySent) return;

    final watchedMs = DateTime
        .now()
        .millisecondsSinceEpoch - startMs;

    // Video controller ගෙන duration ගන්නවා
    final ctrl = _videoControllers[pageIndex];
    int durationMs = 0;
    double watchPercent = 0.0;

    if (ctrl != null && ctrl.value.isInitialized) {
      durationMs = ctrl.value.duration.inMilliseconds;
      if (durationMs > 0) {
        watchPercent = (watchedMs / durationMs * 100).clamp(0, 100);
      }
    } else {
      // Image post — watched time as proxy (3s = 100%)
      watchPercent = (watchedMs / 3000 * 100).clamp(0, 100);
      durationMs = 3000;
    }

    debugPrint('⏱️ Watch stop: $postId | '
        '${watchPercent.toStringAsFixed(0)}% | '
        '${watchedMs ~/ 1000}s / ${durationMs ~/ 1000}s');

    _watchSignalSent[postId] = true;
    _watchStartTimes.remove(postId);

    // Background send — non-blocking
    _recordWatchSignal(
      postId,
      watchPercent,
      watchedMs ~/ 1000,
    );
  }

  // ══════════════════════════════════════════════════════════════
// PEXELS — 1. Fetch Videos from Pexels API
// ══════════════════════════════════════════════════════════════
  /// Pexels API එකෙන් trending videos ගෙනෙනවා.
  /// [page] — pagination page number
  /// [perPage] — page එකකට videos ගණන
  Future<List<Map<String, dynamic>>> _fetchPexelsVideos({
    int page = 1,
    int perPage = 5,
  }) async {
    try {
      debugPrint('🎬 Fetching Pexels videos (page $page)...');

      final uri = Uri.parse(
        'https://api.pexels.com/videos/popular?page=$page&per_page=$perPage',
      );

      final response = await http.get(uri, headers: {
        'Authorization': _pexelsApiKey,
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('⚠️ Pexels API error: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final videos = (data['videos'] as List?) ?? [];

      final List<Map<String, dynamic>> posts = [];

      for (final video in videos) {
        final videoFiles = video['video_files'] as List? ?? [];
        final videoUrl = _selectPexelsVideoQuality(videoFiles);
        if (videoUrl.isEmpty) continue;

        final pexelsId = 'pexels_${video['id']}';
        final thumbnailUrl = (video['image'] as String?) ?? '';

        // Trending audio overlay info ගන්නවා
        await _loadTrendingAudioForPexels();

        posts.add({
          'id'           : pexelsId,
          'uid'          : _pexelsOfficialUid,
          'username'     : _pexelsOfficialUsername,
          'type'         : 'video',
          'media_url'    : videoUrl,
          'thumbnail_url': thumbnailUrl,
          'description'  : (video['url'] as String?)?.split('/').lastWhere(
                (s) => s.isNotEmpty,
            orElse: () => 'Trending video',
          ) ?? 'Trending video',
          'hashtags'     : ['trending', 'vibeflick'],
          'likes'        : 0,
          'commentCount' : 0,
          'shares_count' : 0,
          'viewCount'    : 0,
          'createdAt'    : Timestamp.now(),
          'isPexels'     : true,

          // Audio overlay fields (Pexels silent → trending audio)
          'sound_url'    : _cachedTrendingAudioUrl ?? '',
          'audio_id'     : _cachedTrendingAudioId  ?? '',
          'audio_name'   : _cachedTrendingAudioName ?? 'Trending Sound',
          'album_art_url': _cachedTrendingAlbumArtUrl,
          'allowComment' : true,
        });
      }

      debugPrint('✅ Pexels: ${posts.length} videos prepared');
      return posts;
    } catch (e) {
      debugPrint('❌ Pexels fetch error: $e');
      return [];
    }
  }

// ══════════════════════════════════════════════════════════════
// PEXELS — 2. Inject into Feed when DB posts are low
// ══════════════════════════════════════════════════════════════
  /// DB posts 3 කට වඩා අඩු නම් හෝ ඉවර නම් Pexels inject කරනවා.
  /// _loadMorePosts() ඇතුළෙ call කරන්න:
  ///   await _injectPexelsIfNeeded();
  Future<void> _injectPexelsIfNeeded() async {
    if (_isFetchingPexels) return;

    final remainingPosts = _publicPosts.length - _currentPageIndex;

    // 3 posts කට වඩා remain නම් inject කරන්නෙ නෑ
    if (remainingPosts > 3 && _hasMorePosts) return;

    _isFetchingPexels = true;
    debugPrint('📥 Injecting Pexels videos (remaining: $remainingPosts)...');

    try {
      final pexelsPosts = await _fetchPexelsVideos(
        page    : _pexelsCurrentPage,
        perPage : 5,
      );

      if (pexelsPosts.isNotEmpty) {
        setState(() {
          _publicPosts.addAll(pexelsPosts);
          _pexelsCurrentPage++;
        });
        debugPrint('✅ Injected ${pexelsPosts.length} Pexels posts. '
            'Total: ${_publicPosts.length}');
      }
    } finally {
      _isFetchingPexels = false;
    }
  }

// ══════════════════════════════════════════════════════════════
// PEXELS — 3. Load Trending Audio for Pexels Videos
// ══════════════════════════════════════════════════════════════
  /// DB එකෙ trending audio එකක් ගෙනත් Pexels videos වලට overlay කරනවා.
  Future<void> _loadTrendingAudioForPexels() async {
    // Cache hit — already loaded
    if (_cachedTrendingAudioUrl != null &&
        _cachedTrendingAudioUrl!.isNotEmpty) return;

    try {
      // sound_url field තියෙන latest posts ගන්නවා
      final snap = await _db
          .collection('media_posts')
          .where('sound_url', isGreaterThan: '')
          .orderBy('sound_url')
          .orderBy('likes', descending: true)
          .limit(10)
          .get();

      if (snap.docs.isEmpty) {
        debugPrint('⚠️ No trending audio found in DB');
        return;
      }

      // Random audio one pick කරනවා variety සඳහා
      snap.docs.shuffle();
      final data = snap.docs.first.data();

      _cachedTrendingAudioUrl    = data['sound_url']     as String?;
      _cachedTrendingAudioId     = data['audio_id']      as String?;
      _cachedTrendingAudioName   = data['audio_name']    as String? ?? 'Trending Sound';
      _cachedTrendingAlbumArtUrl = data['album_art_url'] as String?;

      debugPrint('🎵 Trending audio cached: $_cachedTrendingAudioName');
    } catch (e) {
      debugPrint('❌ Trending audio load error: $e');
    }
  }

// ══════════════════════════════════════════════════════════════
// PEXELS — 4. Select Video Quality (SD / HD)
// ══════════════════════════════════════════════════════════════
  /// Connection speed / settings අනුව SD හෝ HD video URL return කරනවා.
  String _selectPexelsVideoQuality(List<dynamic> videoFiles) {
    if (videoFiles.isEmpty) return '';

    // HD files (width >= 1280) සහ SD files වෙන් කරනවා
    final hdFiles = videoFiles.where((f) {
      final w = (f['width'] as num?)?.toInt() ?? 0;
      return w >= 1280;
    }).toList();

    final sdFiles = videoFiles.where((f) {
      final w = (f['width'] as num?)?.toInt() ?? 0;
      return w > 0 && w < 1280;
    }).toList();

    // Simple quality decision: connection check
    // Default → SD (data saving). HD prefer කරන්නෙ නැහැ unless good connection
    // NOTE: Advanced — ConnectivityPlus package use කරල HD/SD switch කරන්න පුළුවන්
    final preferHD = false; // settings integration කරනකල් SD default

    if (preferHD && hdFiles.isNotEmpty) {
      final f = hdFiles.first;
      return (f['link'] as String?) ?? '';
    }

    if (sdFiles.isNotEmpty) {
      // Best SD quality (highest width among SD)
      sdFiles.sort((a, b) =>
          ((b['width'] as num?)?.toInt() ?? 0)
              .compareTo((a['width'] as num?)?.toInt() ?? 0));
      return (sdFiles.first['link'] as String?) ?? '';
    }

    // Fallback: any file
    return (videoFiles.first['link'] as String?) ?? '';
  }


  // ══════════════════════════════════════════════════════════════
// PEXELS — Public helper: Fetch videos for Official Profile Grid
// ══════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> fetchPexelsVideosForProfile({
    int page = 1,
    int perPage = 20,
  }) async {
    const apiKey = 'IlqjoaL1ckMPQJqN9EutMDfdoVw1oQMF4hyL4TSzrOPgMp4HKgDNdwoX';
    try {
      final uri = Uri.parse(
        'https://api.pexels.com/videos/popular?page=$page&per_page=$perPage',
      );
      final response = await http.get(uri, headers: {
        'Authorization': apiKey,
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final videos = (data['videos'] as List?) ?? [];

      return videos.map<Map<String, dynamic>>((video) {
        final files = video['video_files'] as List? ?? [];

        // SD quality select කරනවා
        final sdFiles = files.where((f) {
          final w = (f['width'] as num?)?.toInt() ?? 0;
          return w > 0 && w < 1280;
        }).toList()
          ..sort((a, b) =>
              ((b['width'] as num?)?.toInt() ?? 0)
                  .compareTo((a['width'] as num?)?.toInt() ?? 0));

        final videoUrl = sdFiles.isNotEmpty
            ? (sdFiles.first['link'] as String? ?? '')
            : (files.isNotEmpty ? (files.first['link'] as String? ?? '') : '');

        return {
          'id': 'pexels_${video['id']}',
          'media_url': videoUrl,
          'thumbnail_url': video['image'] as String? ?? '',
          'type': 'video',
          'isPexels': true,
        };
      }).where((p) => (p['media_url'] as String).isNotEmpty).toList();
    } catch (e) {
      debugPrint('❌ Pexels profile grid fetch error: $e');
      return [];
    }
  }
// ══════════════════════════════════════════════════════════════
// PEXELS — 5. Save Engagement (Like / Comment / Share) to DB
// ══════════════════════════════════════════════════════════════
  /// Pexels post වලට like/comment/share කරනකොට අපේම DB ට save කරනවා.
  /// Call from _toggleLike(), _showCommentBottomSheet(), _sharePost()
  /// (isPexels check කරලා)
  Future<void> _savePexelsEngagement(
      String pexelsPostId,
      String type, // 'like' | 'unlike' | 'comment' | 'share' | 'view'
      ) async {
    if (_currentUserId == null) return;

    try {
      final docRef = _db
          .collection('pexels_engagement')
          .doc(pexelsPostId);

      // Document create or update
      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);

        if (!snap.exists) {
          tx.set(docRef, {
            'pexelsPostId' : pexelsPostId,
            'likes'        : type == 'like'    ? 1 : 0,
            'comments'     : type == 'comment' ? 1 : 0,
            'shares'       : type == 'share'   ? 1 : 0,
            'views'        : type == 'view'    ? 1 : 0,
            'createdAt'    : FieldValue.serverTimestamp(),
          });
        } else {
          final updates = <String, dynamic>{};
          if (type == 'like')    updates['likes']    = FieldValue.increment(1);
          if (type == 'unlike')  updates['likes']    = FieldValue.increment(-1);
          if (type == 'comment') updates['comments'] = FieldValue.increment(1);
          if (type == 'share')   updates['shares']   = FieldValue.increment(1);
          if (type == 'view')    updates['views']    = FieldValue.increment(1);
          tx.update(docRef, updates);
        }
      });

      // User-level record (like ද, unlike ද track කරන්නෙ)
      if (type == 'like' || type == 'unlike') {
        final userLikeRef = _db
            .collection('pexels_engagement')
            .doc(pexelsPostId)
            .collection('likes')
            .doc(_currentUserId);

        if (type == 'like') {
          await userLikeRef.set({
            'uid'       : _currentUserId,
            'timestamp' : Timestamp.now(),
          });
        } else {
          await userLikeRef.delete();
        }
      }

      debugPrint('✅ Pexels engagement saved: $type → $pexelsPostId');
    } catch (e) {
      debugPrint('❌ Pexels engagement error: $e');
    }
  }

// ══════════════════════════════════════════════════════════════
// PEXELS — 6. Helper: Is this a Pexels Post?
// ══════════════════════════════════════════════════════════════
  /// post map එකෙ 'isPexels' flag හෝ id prefix check කරනවා.
  bool _isPexelsPost(Map<String, dynamic> post) {
    final flag = post['isPexels'] as bool? ?? false;
    final id   = post['id'] as String? ?? '';
    return flag || id.startsWith('pexels_');
  }


  // ══════════════════════════════════════════════════════════════
// PEXELS — Ensure virtual Firestore document exists
// ══════════════════════════════════════════════════════════════
  Future<void> _ensurePexelsPostDocument(Map<String, dynamic> post) async {
    final postId = post['id'] as String? ?? '';
    if (postId.isEmpty || !_isPexelsPost(post)) return;

    try {
      final docRef = _db.collection('pexels_posts').doc(postId);
      final snap = await docRef.get();

      if (!snap.exists) {
        await docRef.set({
          'pexelsId'     : postId,
          'isPexels'     : true,
          'media_url'    : post['media_url'] ?? '',
          'thumbnail_url': post['thumbnail_url'] ?? '',
          'description'  : post['description'] ?? '',
          'uid'          : _pexelsOfficialUid,
          'username'     : _pexelsOfficialUsername,
          'type'         : 'video',
          'likes'        : 0,
          'commentCount' : 0,
          'shares_count' : 0,
          'viewCount'    : 0,
          'allowComment' : true,
          'createdAt'    : Timestamp.now(),
        });
        debugPrint('✅ Pexels virtual doc created: $postId');
      }
    } catch (e) {
      debugPrint('❌ Pexels doc ensure error: $e');
    }
  }

// ══════════════════════════════════════════════════════════════
// PEXELS — Toggle Like (routes to pexels_posts collection)
// ══════════════════════════════════════════════════════════════
  Future<void> _togglePexelsLike(String postId, int pageIndex) async {
    if (_currentUserId == null) return;

    await _ensurePexelsPostDocument(_publicPosts[pageIndex]);

    try {
      final postRef = _db.collection('pexels_posts').doc(postId);
      final likeRef = postRef.collection('likes').doc(_currentUserId);

      final likeDoc = await likeRef.get();
      final isLiked = likeDoc.exists;

      if (isLiked) {
        await likeRef.delete();
        await postRef.update({'likes': FieldValue.increment(-1)});
        await _savePexelsEngagement(postId, 'unlike');
        debugPrint('💔 Pexels unliked: $postId');
      } else {
        final currentUserDoc = await _db.collection('users').doc(_currentUserId).get();
        final currentUsername = currentUserDoc.data()?['name'] ?? 'User';

        await likeRef.set({
          'uid'      : _currentUserId,
          'username' : currentUsername,
          'timestamp': Timestamp.now(),
        });
        await postRef.update({'likes': FieldValue.increment(1)});
        await _savePexelsEngagement(postId, 'like');
        debugPrint('❤️ Pexels liked: $postId');
      }
    } catch (e) {
      debugPrint('❌ Pexels like error: $e');
    }
  }

// ══════════════════════════════════════════════════════════════
// PEXELS — Like Button Widget (routes correct collection)
// ══════════════════════════════════════════════════════════════
  Widget _buildPexelsLikeButton(String postId, int pageIndex) {
    if (_currentUserId == null) {
      return _buildActionButton(
        icon: 'assets/images/like_outline.svg',
        label: '0',
        onTap: () {},
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('pexels_posts').doc(postId).snapshots(),
      builder: (context, postSnapshot) {
        int likeCount = 0;
        if (postSnapshot.hasData && postSnapshot.data!.exists) {
          final data = postSnapshot.data!.data() as Map<String, dynamic>?;
          likeCount = data?['likes'] as int? ?? 0;
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: _db
              .collection('pexels_posts')
              .doc(postId)
              .collection('likes')
              .doc(_currentUserId)
              .snapshots(),
          builder: (context, likeSnapshot) {
            final isLiked = likeSnapshot.hasData && likeSnapshot.data!.exists;

            return _buildActionButton(
              icon: 'assets/images/like_outline.svg',
              activeIcon: 'assets/images/like_filled.svg',
              label: _formatCount(likeCount),
              isActive: isLiked,
              onTap: () => _togglePexelsLike(postId, pageIndex),
            );
          },
        );
      },
    );
  }

// ══════════════════════════════════════════════════════════════
// PEXELS — Comment Bottom Sheet (routes pexels_posts collection)
// ══════════════════════════════════════════════════════════════
  void _showPexelsCommentSheet(String postId, int currentCommentCount) async {
    await _ensurePexelsPostDocument(
      _publicPosts.firstWhere((p) => p['id'] == postId, orElse: () => {}),
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentBottomSheet(
        postId         : postId,
        postOwnerId    : _pexelsOfficialUid,
        initialCommentCount: currentCommentCount,
        collectionName : 'pexels_posts', // ← pass collection name
      ),
    ).then((_) {
      _refreshPexelsCommentCount(postId);
    });
  }

  Future<void> _refreshPexelsCommentCount(String postId) async {
    try {
      final doc = await _db.collection('pexels_posts').doc(postId).get();
      if (doc.exists) {
        final count = doc.data()?['commentCount'] as int? ?? 0;
        final idx = _publicPosts.indexWhere((p) => p['id'] == postId);
        if (idx != -1 && mounted) {
          setState(() => _publicPosts[idx]['commentCount'] = count);
        }
      }
    } catch (e) {
      debugPrint('❌ Pexels comment count refresh error: $e');
    }
  }

// ══════════════════════════════════════════════════════════════
// PEXELS — Save Button (routes pexels_posts collection)
// ══════════════════════════════════════════════════════════════
  Widget _buildPexelsSaveButton(String postId, int pageIndex) {
    if (_currentUserId == null) {
      return _buildActionButton(
        icon: 'assets/images/bookmark_outline.svg',
        label: '0',
        onTap: () {},
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db
          .collection('saved_posts')
          .doc('${_currentUserId}_$postId')
          .snapshots(),
      builder: (context, snapshot) {
        final isSaved = snapshot.hasData && snapshot.data!.exists;

        return _buildActionButton(
          icon      : 'assets/images/bookmark_outline.svg',
          activeIcon: 'assets/images/bookmark_filled.svg',
          label     : '0',
          isActive  : isSaved,
          onTap     : () => _togglePexelsSave(postId, pageIndex),
        );
      },
    );
  }

  Future<void> _togglePexelsSave(String postId, int pageIndex) async {
    if (_currentUserId == null) return;

    await _ensurePexelsPostDocument(_publicPosts[pageIndex]);

    try {
      final rootRef = _db.collection('saved_posts').doc('${_currentUserId}_$postId');
      final userRef = _db
          .collection('users')
          .doc(_currentUserId)
          .collection('saved_posts')
          .doc(postId);

      final savedDoc = await rootRef.get();

      if (savedDoc.exists) {
        await rootRef.delete();
        await userRef.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from saved')),
          );
        }
      } else {
        final post = _publicPosts[pageIndex];
        await rootRef.set({
          'userId'   : _currentUserId,
          'postId'   : postId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        await userRef.set({
          'postId'       : postId,
          'thumbnail_url': post['thumbnail_url'] ?? '',
          'view_count'   : 0,
          'media_url'    : post['media_url'] ?? '',
          'type'         : 'video',
          'uid'          : _pexelsOfficialUid,
          'username'     : _pexelsOfficialUsername,
          'isPexels'     : true,
          'saved_at'     : FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved successfully')),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Pexels save error: $e');
    }
  }

// ══════════════════════════════════════════════════════════════
// PEXELS — Share (routes pexels_posts collection)
// ══════════════════════════════════════════════════════════════
  Future<void> _sharePexelsPost(Map<String, dynamic> post) async {
    await _ensurePexelsPostDocument(post);
    await _savePexelsEngagement(post['id'] ?? '', 'share');

    try {
      await _db.collection('pexels_posts').doc(post['id']).update({
        'shares_count': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('❌ Pexels share count error: $e');
    }

    if (!mounted) return;
    await _sharePost(post);
  }
// ══════════════════════════════════════════════════════════════
// PEXELS — 7. Get Engagement Counts for Pexels Post from DB
// ══════════════════════════════════════════════════════════════
  /// Pexels post එකක current like/comment/share count DB ගෙන් ගන්නවා.
  Future<Map<String, int>> _getPexelsEngagementCounts(
      String pexelsPostId) async {
    try {
      final snap = await _db
          .collection('pexels_engagement')
          .doc(pexelsPostId)
          .get();

      if (!snap.exists) {
        return {'likes': 0, 'comments': 0, 'shares': 0, 'views': 0};
      }

      final d = snap.data() ?? {};
      return {
        'likes'   : (d['likes']    as num?)?.toInt() ?? 0,
        'comments': (d['comments'] as num?)?.toInt() ?? 0,
        'shares'  : (d['shares']   as num?)?.toInt() ?? 0,
        'views'   : (d['views']    as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      debugPrint('❌ Pexels count fetch error: $e');
      return {'likes': 0, 'comments': 0, 'shares': 0, 'views': 0};
    }
  }

// ══════════════════════════════════════════════════════════════
// PEXELS — 8. Refresh Trending Audio Cache
// ══════════════════════════════════════════════════════════════
  /// Audio cache reset කරල නැවත load කරනවා.
  /// refreshFeed() call වෙනකොට call කරන්න.
  Future<void> _refreshPexelsTrendingAudio() async {
    _cachedTrendingAudioUrl    = null;
    _cachedTrendingAudioId     = null;
    _cachedTrendingAudioName   = null;
    _cachedTrendingAlbumArtUrl = null;
    _pexelsCurrentPage         = 1;
    debugPrint('🔄 Pexels audio cache cleared');
    await _loadTrendingAudioForPexels();
  }
}



// ============================================================
// PER-CARD SHIMMER WIDGET
// ============================================================
class _PostCardShimmer extends StatelessWidget {
  const _PostCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!,
      highlightColor: Colors.grey[800]!,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video area
          Container(color: Colors.grey[900]),

          // Bottom gradient overlay (same as real post)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // Right side action buttons shimmer
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 24,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              )),
            ),
          ),

          // Bottom info panel shimmer
          Positioned(
            left: 16,
            right: 80,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar + username row
                Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 70,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Timestamp line
                Container(
                  width: 60,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 6),

                // Description line 1
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),

                // Description line 2
                Container(
                  width: 200,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 10),

                // Music note line
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 140,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================
// HEART ANIMATION WIDGET
// ============================================================
class _HeartAnimationWidget extends StatefulWidget {
  final Offset position;
  final VoidCallback onComplete;

  const _HeartAnimationWidget({
    required this.position,
    required this.onComplete,
  });

  @override
  State<_HeartAnimationWidget> createState() => _HeartAnimationWidgetState();
}

class _HeartAnimationWidgetState extends State<_HeartAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _moveAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 30,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    _moveAnimation = Tween<double>(begin: 0.0, end: -30.0)
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 50,
      top: widget.position.dy - 50,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _moveAnimation.value),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 100,
                    shadows: [
                      Shadow(
                        color: Colors.black38,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
// ← _ForYouScreenState class end


// ============================================================
// FEED IMAGE CAROUSEL - STATEFUL WIDGET
// ============================================================
// ============================================================
// FEED IMAGE CAROUSEL - STATEFUL WIDGET
// ============================================================
class _FeedImageCarouselWidget extends StatefulWidget {
  final List<String> urls;
  final Map<String, dynamic> post;
  final Widget Function() buildShimmer;
  final VoidCallback onLongPress;

  const _FeedImageCarouselWidget({
    required this.urls,
    required this.post,
    required this.buildShimmer,
    required this.onLongPress,
  });

  @override
  State<_FeedImageCarouselWidget> createState() =>
      _FeedImageCarouselWidgetState();
}

class _FeedImageCarouselWidgetState extends State<_FeedImageCarouselWidget> {
  late final PageController _controller;
  late final ValueNotifier<int> _pageNotifier;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _pageNotifier = ValueNotifier<int>(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final url in widget.urls) {
        precacheImage(NetworkImage(url), context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Black background
        Container(color: Colors.black),

        // ── Native PageView — BouncingScrollPhysics (same as post_detail_page)
        PageView.builder(
          controller: _controller,
          itemCount: widget.urls.length,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (i) => _pageNotifier.value = i,
          itemBuilder: (context, i) {
            return GestureDetector(
              onLongPress: widget.onLongPress,
              child: ColoredBox(
                color: Colors.black,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxWidth * 16 / 9,
                            child: Image.network(
                              widget.urls[i],
                              fit: BoxFit.contain,  // ← Contain = full image

                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return widget.buildShimmer();
                              },
                              errorBuilder: (_, __, ___) =>
                                  Container(
                                    color: Colors.grey[900],
                                    child: const Icon(Icons.broken_image,
                                        size: 80, color: Colors.white54),
                                  ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),

        // ── Bottom gradient
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),

        // ── Dot indicators
        Positioned(
          bottom: 90,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ValueListenableBuilder<int>(
              valueListenable: _pageNotifier,
              builder: (_, current, __) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.urls.length, (i) {
                    final active = i == current;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: active
                            ? [BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 6,
                        )
                        ]
                            : null,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),

        // ── Photo count badge
        Positioned(
          top: MediaQuery
              .of(context)
              .padding
              .top + 16,
          right: 12,
          child: IgnorePointer(
            child: ValueListenableBuilder<int>(
              valueListenable: _pageNotifier,
              builder: (_, current, __) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_outlined,
                              color: Colors.white70, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            '${current + 1} / ${widget.urls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}


/// Blurred background for premium carousel look
class _BlurredBg extends StatelessWidget {
  final String url;
  const _BlurredBg({required this.url, super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) =>
              Container(color: Colors.black),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: Colors.black.withOpacity(0.55),
          ),
        ),
      ],
    );
  }
}