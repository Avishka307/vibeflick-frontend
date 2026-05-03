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
import 'package:my_vibe_flick/screens/video_options_bottom_sheet.dart';

import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:io';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:shimmer/shimmer.dart';

import 'package:my_vibe_flick/screens/video_cache_manager.dart';
import 'dart:ui' as ui;
import '../Comment/comment_bottom_sheet.dart';
import '../search_navigation_helper.dart';
import 'activity_user_profile.dart';
import 'media_options_bottom_sheet.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  final String? initialUserId;
  final bool hideBackButton;

  const PostDetailPage({
    Key? key,
    required this.postId,
    this.initialUserId,
    this.hideBackButton = false,
  }) : super(key: key);

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> with WidgetsBindingObserver {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentUserId;
  Map<String, dynamic>? _postData;
  Map<String, dynamic>? _ownerData;
  bool _isLoading = true;
  bool _showFullDescription = false;
// Double tap like animation
  final Map<int, bool> _showHeartAnimation = {};
  final Map<int, OverlayEntry?> _heartOverlays = {};
  OverlayEntry? _heartOverlayEntry;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _showThumbnail = false;

  int _commentCount = 0;
  int _viewCount = 0;

  static final Map<String, VideoPlayerController> _controllerCache = {};

  bool _isPageActive = true;

  final ValueNotifier<double> _videoProgressNotifier = ValueNotifier<double>(
      0.0);

  bool _isDoubleSpeed = false;

  bool _videoVisible = false;

  bool _hasInternetConnection = true;
  bool _showNoInternetToast = false;

  bool _isMediaLoading = false;
  VideoPlayerController? _audioController;
  // 🆕 ADD HERE ↓
  Map<String, dynamic>? _repostInfo;


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
  void _handleDoubleTap(TapDownDetails details) async {
    _showHeartOverlay(details.globalPosition);

    if (_currentUserId == null) return;

    final likeRef = _db
        .collection('media_posts')
        .doc(widget.postId)
        .collection('likes')
        .doc(_currentUserId);

    final likeDoc = await likeRef.get();
    if (!likeDoc.exists) {
      await _toggleLike();
    }
  }

  void _showHeartOverlay(Offset position) {
    _heartOverlayEntry?.remove();

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _HeartAnimationWidget(
        position: position,
        onComplete: () {
          entry.remove();
          _heartOverlayEntry = null;
        },
      ),
    );

    _heartOverlayEntry = entry;
    overlay.insert(entry);
  }
  Widget _buildClickableDescription(String description, String username) {
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

    return RichText(
      text: TextSpan(children: spans),
      maxLines: _showFullDescription ? null : 2,
      overflow: _showFullDescription ? TextOverflow.visible : TextOverflow
          .ellipsis,
    );
  }


  Future<void> _handleMentionTap(String username) async {
    debugPrint('👆 Tapped mention: @$username');

    _pauseVideo();

    try {
      // 🔍 Try exact match first
      QuerySnapshot querySnapshot = await _db
          .collection('users')
          .where('name', isEqualTo: username)
          .limit(1)
          .get();

      // 🔍 If not found, try lowercase
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
          if (_isPageActive && mounted && _videoVisible) {
            _resumeVideo();
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

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadPostData();
    WidgetsBinding.instance.addObserver(this);
    _setupAudioSession();

    // 🆕 ADD: Start view tracking after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _postData != null) {
        _trackPostView();
      }
    });
  }

  Future<void> _trackPostView() async {
    if (_postData == null) return;

    final postId = widget.postId;

    if (_currentUserId == null) {
      await _trackGuestPostView(postId);
      return;
    }

    try {
      final viewDocId = '${_currentUserId}_$postId';
      final viewRef = _db
          .collection('media_posts')
          .doc(postId)
          .collection('views')
          .doc(viewDocId);

      final viewDoc = await viewRef.get();

      if (!viewDoc.exists) {
        // 🎯 FIRST TIME VIEWING - Create view record
        await viewRef.set({
          'userId': _currentUserId,
          'timestamp': DateTime
              .now()
              .millisecondsSinceEpoch,
          'isGuest': false,
        });

        // 🎯 INCREMENT VIEW COUNT
        await _db.collection('media_posts').doc(postId).update({
          'viewCount': FieldValue.increment(1),
        });

        debugPrint('✅ Post view tracked: $postId (NEW VIEW)');

        // 🔧 FIX: Reload viewCount from database instead of manually incrementing
        final updatedPostDoc = await _db
            .collection('media_posts')
            .doc(postId)
            .get();
        if (updatedPostDoc.exists) {
          setState(() {
            _viewCount = updatedPostDoc.data()?['viewCount'] ?? 0;
          });
        }
      } else {
        // 🎯 ALREADY VIEWED - Just log
        debugPrint('⏭️ Already viewed this post: $postId (NO NEW VIEW)');

        // 🔧 FIX: Still load current viewCount from database
        final currentPostDoc = await _db
            .collection('media_posts')
            .doc(postId)
            .get();
        if (currentPostDoc.exists) {
          setState(() {
            _viewCount = currentPostDoc.data()?['viewCount'] ?? 0;
          });
        }
      }
      // ✅ user_history collection එකට write (HISTORY TAB සඳහා)  ← ADD THIS BLOCK
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
          'timestamp': DateTime
              .now()
              .millisecondsSinceEpoch,
        });
        debugPrint('🔄 History timestamp updated for: $postId');
      } else {
        await historyRef.add({
          'postId': postId,
          'timestamp': DateTime
              .now()
              .millisecondsSinceEpoch,
          'userId': _currentUserId,
        });
        debugPrint('✅ Added to user history (PostDetail): $postId');
      }
      // ← ADD BLOCK END HERE

    } catch (e) {
      debugPrint('❌ Error tracking post view: $e');
    }
  }

// 🆕 ADD: Guest view tracking
  Future<void> _trackGuestPostView(String postId) async {
    try {
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

        debugPrint('✅ Guest post view tracked: $postId');
      }
    } catch (e) {
      debugPrint('❌ Error tracking guest post view: $e');
    }
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

  Future<void> _handlePostOwnerFollow() async {
    if (_currentUserId == null || _postData == null) return;

    final postOwnerId = _postData!['uid'] ?? '';
    final postOwnerUsername = _postData!['username'] ?? 'Unknown';

    if (postOwnerId == _currentUserId) {
      debugPrint('⏭️ Cannot follow yourself');
      return;
    }

    try {
      final followDocId = '${_currentUserId}_$postOwnerId';
      final followRef = _db.collection('follows').doc(followDocId);
      final followDoc = await followRef.get();

      if (followDoc.exists) {
        await _showUnfollowConfirmationDialog(postOwnerId, postOwnerUsername);
      } else {
        debugPrint('💙 Following post owner: $postOwnerId');

        final ownerDoc = await _db.collection('users').doc(postOwnerId).get();
        final isPrivateAccount = ownerDoc.data()?['private_account'] ?? false;

        final currentUserDoc = await _db
            .collection('users')
            .doc(_currentUserId)
            .get();
        final currentUsername = currentUserDoc.data()?['name'] ?? 'User';

        final followData = {
          'followerId': _currentUserId,
          'followerName': currentUsername,
          'followingId': postOwnerId,
          'followingName': postOwnerUsername,
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

          await _db.collection('users').doc(postOwnerId).update({
            'followerCount': FieldValue.increment(1),
          });

          debugPrint('✅ Follow completed');
        } else {
          debugPrint('⏳ Follow request sent (pending approval)');

          await _db.collection('users').doc(postOwnerId).collection(
              'notifications').add({
            'type': 'follow_request',
            'fromUserId': _currentUserId,
            'fromUserName': currentUsername,
            'toUserId': postOwnerId,
            'timestamp': DateTime
                .now()
                .millisecondsSinceEpoch,
            'isRead': false,
          });
        }

        _sendFollowNotificationInBackground(
            postOwnerId, postOwnerUsername, isPrivateAccount, currentUsername);
      }
    } catch (e) {
      debugPrint('❌ Error toggling follow: $e');
    }
  }

  Future<void> _setupAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      session.becomingNoisyEventStream.listen((_) {
        debugPrint('🎧 Headphones disconnected - Auto pausing video');
        _pauseVideo();
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
        debugPrint('⏸️ App paused/inactive/hidden - Pausing video');
        _isPageActive = false;
        _pauseVideo();
        break;

      case AppLifecycleState.resumed:
        debugPrint('▶️ App resumed - Resuming video');
        _isPageActive = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _isPageActive && _videoVisible) {
            _resumeVideo();
          }
        });
        break;

      default:
        break;
    }
  }

  @override
  void deactivate() {
    debugPrint('⏸️ PostDetailPage deactivated - Pausing video');
    _isPageActive = false;
    _pauseVideo();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    debugPrint('▶️ PostDetailPage activated - Resuming video');
    _isPageActive = true;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _isPageActive && _videoVisible) {
        _resumeVideo();
      }
    });
  }

  void _pauseVideo() {
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
      debugPrint('⏸️ Video paused');
    }
    if (_audioController != null && _audioController!.value.isPlaying) {
      _audioController!.pause();
      debugPrint('⏸️ Audio paused');
    }
  }

  void _resumeVideo() {
    if (!_isPageActive || !_videoVisible) {
      debugPrint('⏭️ Skipping resume - page not active or not visible');
      return;
    }

    if (_videoController != null &&
        !_videoController!.value.isPlaying &&
        _videoInitialized) {
      _videoController!.play();
      debugPrint('▶️ Video resumed');
      if (mounted) setState(() {});
    }

    if (_audioController != null &&
        !_audioController!.value.isPlaying) {
      _audioController!.play();
      debugPrint('▶️ Audio resumed');
    }
  }

  void _toggleDoubleSpeed() {
    if (_videoController == null) return;

    setState(() {
      _isDoubleSpeed = !_isDoubleSpeed;
    });

    if (_isDoubleSpeed) {
      _videoController!.setPlaybackSpeed(2.0);
      debugPrint('⚡ 2x speed enabled');
    } else {
      _videoController!.setPlaybackSpeed(1.0);
      debugPrint('🎬 Normal speed');
    }
  }

  void _handleVideoVisibilityChanged(double visibleFraction) {
    final wasVisible = _videoVisible;
    final isNowVisible = visibleFraction > 0.5;

    if (wasVisible != isNowVisible) {
      setState(() {
        _videoVisible = isNowVisible;
      });

      if (_videoController != null && _videoController!.value.isInitialized) {
        if (isNowVisible && _isPageActive) {
          if (!_videoController!.value.isPlaying) {
            _videoController!.play();
            debugPrint('▶️ Video became visible - playing');
          }
        } else {
          if (_videoController!.value.isPlaying) {
            _videoController!.pause();
            debugPrint('⏸️ Video became hidden - pausing');
          }
        }
      }
    }
  }

  Future<void> _loadPostData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final hasInternet = await _checkInternetConnection();
      if (!hasInternet) {
        // 🆕 Load repost info
        _repostInfo = await _loadRepostInfo(widget.postId);

        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          _showErrorAndGoBack(
              'No internet connection. Please check your connection and try again.');
        }
        return;
      }

      debugPrint('📥 Loading post: ${widget.postId}');

      final postDoc = await _db
          .collection('media_posts')
          .doc(widget.postId)
          .get();

      if (!postDoc.exists) {
        debugPrint('❌ Post not found');
        if (mounted) {
          _showErrorAndGoBack('Post not found');
        }
        return;
      }

      _postData = postDoc.data();
      _postData!['id'] = postDoc.id;

      _postData!['audio_id'] ??= 'original_sound';
      _postData!['audio_name'] ??= 'Original Sound';
      _postData!['album_art_url'] ??= null;

      final postOwnerId = _postData!['uid'] ?? '';

      debugPrint('✅ Post loaded: ${_postData!['username']} (${postOwnerId})');

      final ownerDoc = await _db.collection('users').doc(postOwnerId).get();
      if (ownerDoc.exists) {
        _ownerData = ownerDoc.data();
        debugPrint('✅ Owner data loaded: ${_ownerData!['name']}');
      }

      _commentCount = _postData!['commentCount'] ?? 0;
      _viewCount = _postData!['viewCount'] ?? 0;

      debugPrint('📊 Stats - Comments: $_commentCount, Views: $_viewCount');

      if (_postData!['type'] == 'video') {
        await _initializeVideo();
      } else {
        await _playAudioForImagePost();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading post: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showErrorAndGoBack('Failed to load post. Please try again.');
      }
    }
  }
// ════════════════════════════════════════════════════════════════════
  // REPOST — Check if any followed user reposted this post
  // ════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> _loadRepostInfo(String postId) async {
    if (_currentUserId == null) return null;
    try {
      final repostsSnap = await _db
          .collection('reposts')
          .where('postId', isEqualTo: postId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      if (repostsSnap.docs.isEmpty) return null;

      for (final doc in repostsSnap.docs) {
        final data       = doc.data();
        final reposterId = data['userId'] as String? ?? '';
        if (reposterId == _currentUserId) continue;

        final followDoc = await _db
            .collection('follows')
            .doc('${_currentUserId}_$reposterId')
            .get();

        if (followDoc.exists && followDoc.data()?['status'] == 'active') {
          return {
            'reposter_id'  : reposterId,
            'reposter_name': data['username'] ?? 'Someone',
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Repost info error: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // REPOST LABEL WIDGET
  // ════════════════════════════════════════════════════════════════════
  Widget _buildRepostLabel() {
    if (_repostInfo == null) return const SizedBox.shrink();

    final reposterName = _repostInfo!['reposter_name'] as String;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
  }
  void _showErrorAndGoBack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _loadPostData(),
        ),
      ),
    );
  }

  Future<void> _initializeVideo() async {
    if (_postData == null) return;

    try {
      final videoUrl = _postData!['media_url'] ?? '';

      if (videoUrl.isEmpty) {
        debugPrint('❌ Video URL is empty');
        return;
      }

      debugPrint('🎬 Initializing video: $videoUrl');

      setState(() {
        _showThumbnail = true;
        _videoInitialized = false;
        _isMediaLoading = true;
      });

      if (_controllerCache.containsKey(videoUrl)) {
        debugPrint('♻️ Reusing cached controller for: $videoUrl');
        _videoController = _controllerCache[videoUrl];

        if (!_videoController!.value.isInitialized) {
          await _videoController!.initialize();
        }

        setState(() {
          _videoInitialized = true;
          _showThumbnail = false;
          _isMediaLoading = false;
        });

        _videoController!.setLooping(true);
        _videoController!.setVolume(1.0);

        _videoController!.addListener(() {
          if (mounted && _videoController!.value.isInitialized) {
            final position = _videoController!.value.position.inMilliseconds
                .toDouble();
            final duration = _videoController!.value.duration.inMilliseconds
                .toDouble();
            if (duration > 0) {
              _videoProgressNotifier.value = position / duration;
            }
          }
        });

        if (_isPageActive && _videoVisible) {
          await _videoController!.play();
        }

        debugPrint('✅ Cached controller ready');
        return;
      }

      final cachedPath = await VideoCacheManager.getCachedVideoPath(videoUrl);

      VideoPlayerController controller;

      if (cachedPath != null) {
        debugPrint('✅ Using cached video file: $cachedPath');
        controller = VideoPlayerController.file(File(cachedPath));
      } else {
        debugPrint('⚠️ Cache failed/unavailable, using network URL');
        controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      }

      await controller.initialize();

      _controllerCache[videoUrl] = controller;
      _videoController = controller;

      setState(() {
        _videoInitialized = true;
        _showThumbnail = false;
        _isMediaLoading = false;
      });

      controller.setLooping(true);
      controller.setVolume(1.0);

      controller.addListener(() {
        if (mounted && controller.value.isInitialized) {
          final position = controller.value.position.inMilliseconds.toDouble();
          final duration = controller.value.duration.inMilliseconds.toDouble();
          if (duration > 0) {
            _videoProgressNotifier.value = position / duration;
          }
        }
      });

      if (_isPageActive && _videoVisible) {
        await controller.play();
      }

      debugPrint('✅ Video initialized');
    } catch (e) {
      debugPrint('❌ Video initialization error: $e');
      setState(() {
        _videoInitialized = false;
        _showThumbnail = false;
        _isMediaLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Failed to load video. Please check your connection.'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _initializeVideo(),
            ),
          ),
        );
      }
    }
  }

  static Future<void> cleanupControllerCache() async {
    debugPrint('🧹 Cleaning up controller cache...');

    int disposedCount = 0;

    for (var entry in _controllerCache.entries) {
      try {
        await entry.value.pause();
        await entry.value.dispose();
        disposedCount++;
      } catch (e) {
        debugPrint('⚠️ Error disposing controller: $e');
      }
    }

    _controllerCache.clear();
    debugPrint('✅ Disposed $disposedCount cached controllers');
  }

  static Future<void> removeControllerFromCache(String videoUrl) async {
    if (_controllerCache.containsKey(videoUrl)) {
      try {
        final controller = _controllerCache[videoUrl]!;
        await controller.pause();
        await controller.dispose();
        _controllerCache.remove(videoUrl);
        debugPrint('✅ Removed controller from cache: $videoUrl');
      } catch (e) {
        debugPrint('⚠️ Error removing controller from cache: $e');
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_currentUserId == null || _postData == null) {
      debugPrint('⚠️ User not logged in - cannot like');
      return;
    }

    try {
      final postRef = _db.collection('media_posts').doc(widget.postId);
      final likeRef = postRef.collection('likes').doc(_currentUserId);

      final likeDoc = await likeRef.get();
      final isCurrentlyLiked = likeDoc.exists;

      if (isCurrentlyLiked) {
        debugPrint('💔 Unliking post: ${widget.postId}');

        await likeRef.delete();
        await postRef.update({
          'likes': FieldValue.increment(-1),
        });

        await _db
            .collection('likes')
            .doc('${_currentUserId}_${widget.postId}')
            .delete();

        debugPrint('✅ Unlike completed successfully');
      } else {
        debugPrint('❤️ Liking post: ${widget.postId}');

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

        await _db
            .collection('likes')
            .doc('${_currentUserId}_${widget.postId}')
            .set({
          'uid': _currentUserId,
          'username': currentUsername,
          'postId': widget.postId,
          'timestamp': Timestamp.now(),
        });

        debugPrint('✅ Like saved successfully to both locations');


        _sendLikeNotificationInBackground();
      }
    } catch (e) {
      debugPrint('❌ Error toggling like: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update like. Please try again.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// AFTER:
  Future<void> _toggleSave() async {
    if (_currentUserId == null || _postData == null) return;

    try {
      // Root collection — like count tracking සඳහා
      final rootRef = _db.collection('saved_posts')
          .doc('${_currentUserId}_${widget.postId}');
      // User subcollection — Posts tab display සඳහා
      final userRef = _db
          .collection('users')
          .doc(_currentUserId)
          .collection('saved_posts')
          .doc(widget.postId);

      final savedDoc = await rootRef.get();
      final isCurrentlySaved = savedDoc.exists;

      if (isCurrentlySaved) {
        await rootRef.delete();
        await userRef.delete();
        debugPrint('🔓 Unsaved post');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from saved')),
          );
        }
      } else {
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        await rootRef.set({
          'userId': _currentUserId,
          'postId': widget.postId,
          'timestamp': timestamp,
        });



       // 🟢 REPLACE WITH:
        // Thumbnail + viewCount — type-safe cast
        final String thumbnailUrl = (_postData!['thumbnail_url'] as String?) ?? '';
        final int viewCountVal = (_postData!['viewCount'] as num?)?.toInt()
            ?? (_postData!['view_count'] as num?)?.toInt()
            ?? _viewCount;

        await userRef.set({
          'postId': widget.postId,
          'thumbnail_url': thumbnailUrl,
          'view_count': viewCountVal,
          'media_url': _postData!['media_url'] ?? '',
          'type': _postData!['type'] ?? 'video',
          'uid': _postData!['uid'] ?? '',
          'username': _postData!['username'] ?? '',
          'saved_at': FieldValue.serverTimestamp(),
        });
        debugPrint('💾 Saved post');
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

  void _showCommentsSheet() {
    if (_postData == null) return;
    // ✅ allowComment check
    final bool allowComment = _postData!['allowComment'] ?? true;
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

    debugPrint('💬 Opening comments for post: ${widget.postId}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CommentBottomSheet(
            postId: widget.postId,
            postOwnerId: _postData!['uid'] ?? '',
            initialCommentCount: _commentCount,
          ),
    );
  }

  void _sharePost() {
    _handleShare();
  }

  Future<void> _handleShare() async {
    if (_postData == null) return;
    _pauseVideo();

    final postOwnerId = _postData!['uid'] ?? '';
    final isOwnPost = postOwnerId == _currentUserId;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          ShareBottomSheet(
            postId            : widget.postId,
            username          : _postData!['username'] ?? 'Unknown',
            description       : _postData!['description'] ?? '',
            thumbnailUrl      : _postData!['thumbnail_url'],
            isOwnPost         : isOwnPost,
            postOwnerId       : postOwnerId,
            postOwnerUsername : _postData!['username'] ?? 'Unknown',
            mediaUrl          : _postData!['media_url'] ?? '',
            hashtags          : (_postData!['hashtags'] as List?)?.cast<String>() ?? [],
            category          : (_postData!['category'] as String?) ?? '',
            onReported        : () {
              // PostDetailPage close කරනවා — sheet already closed
              if (mounted) Navigator.pop(context);
            },
            onUndo            : () {
              // 🆕 PostDetailPage — page open ම තිබෙනවා, DB write නෑ
              debugPrint('↩️ Not interested undone — staying on PostDetailPage');
            },
          ),
    );

    if (_isPageActive && mounted && _videoVisible) {
      _resumeVideo();
    }
  }

  Future<void> _incrementShareCount(String postId) async {
    try {
      await _db.collection('media_posts').doc(postId).update({
        'shares_count': FieldValue.increment(1),
      });

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

  void _navigateToSoundDetail() {
    if (_postData == null) return;

    final audioId = _postData!['audio_id'] ?? 'original_sound';
    final audioName = _postData!['audio_name'] ?? 'Original Sound';
    final albumArtUrl = _postData!['album_art_url'];
    final creatorUsername = _postData!['username'] ?? 'Unknown';

    debugPrint('🎵 Navigating to sound detail:');
    debugPrint('   Audio ID: $audioId');
    debugPrint('   Audio Name: $audioName');

    _pauseVideo();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SoundDetailPage(
              soundId: audioId,
              // 🎯 Pass sound ID (NOT user ID)
              soundName: audioName,
              albumArtUrl: albumArtUrl,
              heroTag: 'vinyl_disc_post_detail',
              creatorUsername: creatorUsername, // Creator who first used this sound
            ),
      ),
    ).then((_) {
      if (_isPageActive && mounted && _videoVisible) {
        _resumeVideo();
      }
    });
  }

  void _showTaggedFriendsBottomSheet(List<dynamic> taggedFriends) {
    if (taggedFriends.isEmpty) {
      return;
    }

    debugPrint(
        '🏷️ Opening tagged friends sheet with ${taggedFriends.length} friends');

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
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

  Widget _buildTaggedFriendsPreview(List<dynamic> taggedFriends) {
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
      onTap: () => _showTaggedFriendsBottomSheet(taggedFriends),
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

  @override
  void dispose() {
    debugPrint('🛑 Disposing PostDetailPage');

    WidgetsBinding.instance.removeObserver(this);

    if (_videoController != null) {
      debugPrint('⏸️ Pausing video controller (keeping in cache)');
      _videoController!.pause();
      _videoController = null;
    }

    if (_audioController != null) {
      _audioController!.pause();
      _audioController!.dispose();
      _audioController = null;
      debugPrint('🛑 Audio controller disposed');
    }

    _videoProgressNotifier.dispose();

    super.dispose();
  }

  Widget _buildFollowButton() {
    if (_currentUserId == null || _postData == null) {
      return const SizedBox.shrink();
    }

    final postOwnerId = _postData!['uid'] ?? '';
    final postOwnerUsername = _postData!['username'] ?? 'Unknown';

    if (postOwnerId == _currentUserId) {
      debugPrint('⏭️ Hiding follow button - viewing own post');
      return const SizedBox.shrink();
    }

    final followDocId = '${_currentUserId}_$postOwnerId';

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('follows').doc(followDocId).snapshots(),
      builder: (context, snapshot) {
        bool isFollowing = false;
        bool isPending = false;
        String buttonText = 'Follow';
        Color buttonColor = const Color(0xFFFF3B5C);
        IconData buttonIcon = Icons.person_add;

        if (snapshot.hasData && snapshot.data != null &&
            snapshot.data!.exists) {
          final followData = snapshot.data!.data() as Map<String, dynamic>?;
          final status = followData?['status'] ?? '';

          if (status == 'active') {
            isFollowing = true;
            buttonText = 'Following';
            buttonColor = const Color(0xFF2C2C2C);
            buttonIcon = Icons.check;
          } else if (status == 'pending') {
            isPending = true;
            buttonText = 'Requested';
            buttonColor = const Color(0xFFFFA500);
            buttonIcon = Icons.access_time;
          }
        }

        return GestureDetector(
          onTap: () => _handlePostOwnerFollow(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: buttonColor,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: isFollowing
                    ? Colors.white.withOpacity(0.5)
                    : Colors.white.withOpacity(0.5),
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
              children: [
                Icon(
                  buttonIcon,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 2),
                Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const _PostCardShimmer(),
      );
    }

    if (_postData == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Post not found',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _loadPostData(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
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

    final isPlaying = _videoController?.value.isPlaying ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildMediaDisplay(),

          Positioned.fill(
            child: IgnorePointer( // ← මේක add කරන්න
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // 🆕 ADD HERE ↓
          _buildRepostLabel(),
          // ✅ මේ back button existing block ට ඊළඟට add කරන්න
          if (!widget.hideBackButton)
            Positioned(
              top: MediaQuery
                  .of(context)
                  .padding
                  .top + 16,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                      Icons.arrow_back, color: Colors.white, size: 24),
                ),
              ),
            ),

// ✅ ← මෙතන ADD කරන්න (owner ගෙ post නම් විතරක් show)
          if (_postData != null && (_postData!['uid'] ?? '') == _currentUserId)
            Positioned(
              top: MediaQuery
                  .of(context)
                  .padding
                  .top + 16,
              right: 16,
              child: GestureDetector(
                onTap: _showVideoOptionsIfOwner,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                      Icons.more_vert, color: Colors.white, size: 24),
                ),
              ),
            ),
          // 🎯 UI MATCHED: Right action buttons - same as for_you_screen.dart (28px icons, 28px spacing)
          // 🎯 UI MATCHED: Right action buttons - same as for_you_screen.dart (28px icons, 28px spacing)
          Positioned(
            right: 8,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLikeButton(),
                const SizedBox(height: 28),
                _buildActionButton(
                  icon: 'assets/images/comment_icon.svg',
                  label: _formatCount(_commentCount),
                  onTap: _showCommentsSheet,
                ),
                const SizedBox(height: 28),
                _buildSaveButton(),
                const SizedBox(height: 28),
                StreamBuilder<DocumentSnapshot>(
                  stream: _db
                      .collection('media_posts')
                      .doc(widget.postId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    int shareCount = 0;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      shareCount = data?['shares_count'] as int? ?? 0;
                    }
                    return _buildActionButton(
                      icon: 'assets/images/share_icon.svg',
                      label: _formatCount(shareCount),
                      onTap: _sharePost,
                    );
                  },
                ),
                ...() {
                  final String? soundUrl = _postData!['sound_url'] as String?;
                  final String? audioId = _postData!['audio_id'] as String?;
                  final bool hasSound = (soundUrl != null && soundUrl.isNotEmpty) ||
                      (audioId != null && audioId.isNotEmpty && audioId != 'original_sound');

                  if (!hasSound) return <Widget>[];
                  return <Widget>[
                    const SizedBox(height: 28),
                    RotatingVinylDisc(
                      isPlaying: isPlaying,
                      albumArtUrl: _postData!['album_art_url'],
                      soundId: _postData!['audio_id'],
                      onTap: _navigateToSoundDetail,
                      heroTag: 'vinyl_disc_post_detail',
                    ),
                  ];
                }(),
              ],
            ),
          ),
          _buildBottomInfoPanel(),
        ],
      ),
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

  Widget _buildMediaDisplay() {
    final isVideo = _postData!['type'] == 'video';
    final mediaUrl = _postData!['media_url'] ?? '';

    if (isVideo) {
      final thumbnailUrl = _postData!['thumbnail_url'] as String?;

      if (_isMediaLoading) {
        return _buildMediaShimmer();
      }

      if (_showThumbnail && thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Image.network(
                    thumbnailUrl,
                    fit: BoxFit.contain,
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

      if (!_videoInitialized || _videoController == null) {
        return _buildMediaShimmer();
      }

      return GestureDetector(
        onDoubleTapDown: _handleDoubleTap,
        onDoubleTap: () {},
        onLongPress: () {
          HapticFeedback.mediumImpact();
          final postOwnerId = _postData!['uid'] ?? '';
          if (postOwnerId == _currentUserId) {
            _showVideoOptionsIfOwner(); // ✅ Owner නම් - options sheet
          } else {
            _showReportBottomSheet(); // ✅ Owner නොවේ නම් - report sheet
          }
        },
        child: VisibilityDetector(
          key: const Key('post_detail_video'),
          onVisibilityChanged: (info) {
            _handleVideoVisibilityChanged(info.visibleFraction);
          },
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                } else {
                  _videoController!.play();
                }
              });
            },
            onLongPressStart: (_) {
              _toggleDoubleSpeed();
              HapticFeedback.mediumImpact();
            },
            onLongPressEnd: (_) {
              if (_isDoubleSpeed) {
                _toggleDoubleSpeed();
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.black,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  ),
                ),
                if (!_videoController!.value.isPlaying)
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
                if (_isDoubleSpeed)
                  Positioned(
                    top: MediaQuery
                        .of(context)
                        .padding
                        .top + 60,
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
                          Icon(Icons.fast_forward, color: Colors.white,
                              size: 16),
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
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _videoProgressNotifier,
                    builder: (context, progress, child) {
                      return LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white),
                        minHeight: 2,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    else {
      final mediaUrls = _getMediaUrls();
      return GestureDetector(
        onDoubleTapDown: _handleDoubleTap,
        onDoubleTap: () {},
        onLongPress: () {
          HapticFeedback.mediumImpact();
          final postOwnerId = _postData!['uid'] ?? '';
          if (postOwnerId == _currentUserId) {
            _showVideoOptionsIfOwner(); // ✅ Owner නම් - options sheet
          } else {
            _showReportBottomSheet(); // ✅ Owner නොවේ නම් - report sheet
          }
        },
        child: _ImageCarouselWidget(
          urls: mediaUrls,
          buildShimmer: _buildMediaShimmer,
        ),
      );
    }
  }

  Widget _buildLikeButton() {
    if (_currentUserId == null) {
      return _buildActionButton(
        icon: 'assets/images/like_outline.svg',
        label: '0',
        onTap: () {},
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('media_posts').doc(widget.postId).snapshots(),
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
              .doc(widget.postId)
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
              onTap: _toggleLike,
            );
          },
        );
      },
    );
  }

  Widget _buildSaveButton() {
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
          .doc('${_currentUserId}_${widget.postId}')
          .snapshots(),
      builder: (context, snapshot) {
        bool isSaved = false;

        if (snapshot.hasData && snapshot.data != null) {
          isSaved = snapshot.data!.exists;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('saved_posts')
              .where('postId', isEqualTo: widget.postId)
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
              onTap: _toggleSave,
            );
          },
        );
      },
    );
  }

  Widget _buildBottomInfoPanel() {
    final description = _postData!['description'] ?? '';
    final username = _postData!['username'] ?? 'Unknown';
    final hashtags = (_postData!['hashtags'] as List?)?.cast<String>() ?? [];
    final isLongDescription = description.length > 80;
    final postOwnerId = _postData!['uid'] ?? '';
    final isOwnPost = postOwnerId == _currentUserId;
    final bottomPadding = MediaQuery
        .of(context)
        .padding
        .bottom + 20;
    final String? _soundUrl = _postData!['sound_url'] as String?;
    final String? _audioId = _postData!['audio_id'] as String?;
    final bool hasSound = (_soundUrl != null && _soundUrl.isNotEmpty) ||
        (_audioId != null && _audioId.isNotEmpty && _audioId != 'original_sound');


    return Positioned(
      left: 16,
      right: 80,
      bottom: bottomPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ TITLE
          if ((_postData!['title'] ?? '')
              .toString()
              .trim()
              .isNotEmpty) ...[
            Text(
              _postData!['title'],
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ActivityUserProfile(userId: postOwnerId),
                    ),
                  );
                },
                child: _buildUserAvatar(postOwnerId, username),
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
              if (!isOwnPost) ...[
                const SizedBox(width: 12),
                _buildFollowButton(),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (_formatTimeAgo(_postData!['createdAt'] ?? _postData!['timestamp']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _formatTimeAgo(_postData!['createdAt'] ?? _postData!['timestamp']),
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
              _buildClickableDescription(description, username),
              if (isLongDescription)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showFullDescription = !_showFullDescription;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _showFullDescription ? 'See less' : 'See more',
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
    const Icon(Icons.music_note, color: Colors.white, size: 12),
    const SizedBox(width: 4),
    Expanded(
    child: Text(
    _postData!['audio_name'] ?? 'Original Sound',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        Icons.remove_red_eye, color: Colors.white, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      _formatCount(_viewCount),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    ],
          if (_postData!['tagged_friends'] != null &&
              (_postData!['tagged_friends'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTaggedFriendsPreview(_postData!['tagged_friends']),
          ],
        ],
      ),
    );
  }

  // 🎯 UI MATCHED: Same icon sizes (28px) and spacing as for_you_screen.dart
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                ? Icon(icon, color: Colors.white, size: 28)
                : SvgPicture.asset(
              isActive && activeIcon != null ? activeIcon : icon as String,
              width: 28,
              height: 28,
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
  Future<void> _sendLikeNotificationToBackend() async {
    if (_postData == null || _currentUserId == null) return;

    try {
      final postOwnerId = _postData!['uid'] ?? '';
      final postOwnerUsername = _postData!['username'] ?? 'Unknown';

      if (postOwnerId == _currentUserId) {
        debugPrint('⏭️ Skipping self-notification');
        return;
      }

      final currentUserDoc = await _db
          .collection('users')
          .doc(_currentUserId)
          .get();
      final currentUsername = currentUserDoc.data()?['name'] ?? 'User';

      debugPrint(
          '\n🔔 ========== SENDING LIKE NOTIFICATION TO BACKEND ==========');
      debugPrint('📤 From: $currentUsername ($_currentUserId)');
      debugPrint('📥 To: $postOwnerUsername ($postOwnerId)');
      debugPrint('📝 Post: ${widget.postId}');

      const backendUrl = 'https://avishka-tiktok-api.zeabur.app/api/posts/like';

      final requestBody = {
        'postId': widget.postId,
        'userUid': _currentUserId,
        'username': currentUsername,
        'postOwnerId': postOwnerId,
        'postOwnerUsername': postOwnerUsername,
      };

      debugPrint('📦 Request body: $requestBody');

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏰ Request timeout');
          throw Exception('Request timeout');
        },
      );

      debugPrint('📥 Response: ${response.statusCode}');
      debugPrint('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('✅ Notification sent successfully!');
      } else {
        debugPrint('⚠️ Backend error: ${response.statusCode}');
      }
      debugPrint('==========================================\n');
    } catch (e) {
      debugPrint('❌ Backend API error: $e');
      debugPrint('==========================================\n');
    }
  }

  void _sendLikeNotificationInBackground() {
    if (_postData == null || _currentUserId == null) return;

    final postOwnerId = _postData!['uid'] ?? '';

    if (postOwnerId == _currentUserId) {
      debugPrint('⏭️ Skipping self-notification');
      return;
    }

    _sendLikeNotificationToBackend().then((_) {
      debugPrint('✅ Background notification completed');
    }).catchError((error) {
      debugPrint('⚠️ Background notification failed (non-critical): $error');
    });
  }

  void _sendFollowNotificationInBackground(String targetUserId,
      String targetUsername,
      bool isPrivate,
      String currentUsername,) {
    if (_currentUserId == null || _currentUserId == targetUserId) {
      debugPrint('⏭️ Skipping self-notification');
      return;
    }


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

      const backendUrl = 'https://avishka-tiktok-api.zeabur.app/api/follow-notification';

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

  List<String> _getMediaUrls() {
    if (_postData == null) return [];
    debugPrint('🖼️ Getting media URLs for post: ${widget.postId}');
    debugPrint('   media_urls field: ${_postData!['media_urls']}');
    debugPrint('   media_url field: ${_postData!['media_url']}');

    final mediaUrls = _postData!['media_urls'];
    if (mediaUrls != null && mediaUrls is List && mediaUrls.isNotEmpty) {
      final urls = List<String>.from(mediaUrls);
      debugPrint('   ✅ Found ${urls.length} URLs in media_urls array');
      return urls;
    }

    final single = _postData!['media_url'] ?? '';
    debugPrint('   ⚠️ Falling back to single media_url');
    return single.isNotEmpty ? [single] : [];
  }

  Widget _buildImageCarousel(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();

    if (urls.length == 1) {
      return Image.network(
        urls[0],
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildMediaShimmer();
        },
        errorBuilder: (context, error, stackTrace) =>
            Container(
              color: Colors.grey[900],
              child: const Icon(
                  Icons.broken_image, size: 80, color: Colors.white54),
            ),
      );
    }

    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {},
      child: _ImageCarouselWidget(
        urls: urls,
        buildShimmer: _buildMediaShimmer,
      ),
    );
  }

  Future<void> _playAudioForImagePost() async {
    if (_postData == null) return;
    final soundUrl = _postData!['sound_url'] as String?;
    if (soundUrl == null || soundUrl.isEmpty) {
      debugPrint('⚠️ No sound URL for image post');
      return;
    }

    try {
      debugPrint('🎵 Initializing audio for image post: $soundUrl');
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(soundUrl));
      await ctrl.initialize();
      ctrl.setLooping(true);
      ctrl.setVolume(1.0);
      _audioController = ctrl;

      if (_isPageActive) {
        await ctrl.play();
        debugPrint('🎵 Audio playing for image post');
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Audio play error: $e');
    }
  }
  void _showReportBottomSheet() {
    if (_postData == null) return;
    final postOwnerId = _postData!['uid'] ?? '';
    // Own post නම් report කරන්න බෑ
    if (postOwnerId == _currentUserId) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MediaOptionsBottomSheet(
        postId: widget.postId,
        postOwnerId: postOwnerId,
        postOwnerUsername: _postData!['username'] ?? 'Unknown',
        mediaUrl: _postData!['media_url'] ?? '',
        onReported: () {
          Navigator.pop(context); // bottom sheet close
          Navigator.pop(context); // PostDetailPage close
        },
      ),
    );
  }
  void _showVideoOptionsIfOwner() {
    if (_postData == null) return;

    final postOwnerId = _postData!['uid'] ?? '';
    if (postOwnerId != _currentUserId) return;

    _pauseVideo();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          VideoOptionsBottomSheet(
            postId: widget.postId,
            postOwnerId: postOwnerId,
            postOwnerUsername: _postData!['username'] ?? 'Unknown',
            videoUrl: _postData!['media_url'] ?? '',
            onDeleted: () {
              // ✅ FIX: mounted check කරලා PostDetailPage pop කරනවා
              // bottom sheet context නෙවෙයි, PostDetailPage context use කරනවා
              if (mounted) {
                Navigator.of(context).pop(); // ← PostDetailPage close
              }
            },
            onPrivacyChanged: () {
              _loadPostData();
            },
          ),
    );
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

// ← _PostDetailPageState end


// ============================================================
// IMAGE CAROUSEL STATEFUL WIDGET
// ============================================================
class _ImageCarouselWidget extends StatefulWidget {
  final List<String> urls;
  final Widget Function() buildShimmer;
  final VoidCallback? onLongPress;

  const _ImageCarouselWidget({
    required this.urls,
    required this.buildShimmer,
    this.onLongPress,
  });

  @override
  State<_ImageCarouselWidget> createState() => _ImageCarouselWidgetState();
}

class _ImageCarouselWidgetState extends State<_ImageCarouselWidget> {
  late final PageController _controller;
  late final ValueNotifier<int> _pageNotifier;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _pageNotifier = ValueNotifier<int>(0);
    debugPrint('🖼️ Carousel init — total images: ${widget.urls.length}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final url in widget.urls) {
        precacheImage(NetworkImage(url), context);
        debugPrint('🔄 Precaching: $url');
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
    debugPrint('🏗️ Carousel build — urls count: ${widget.urls.length}');

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Blurred ambient background
        ValueListenableBuilder<int>(
          valueListenable: _pageNotifier,
          builder: (_, page, __) {
            debugPrint('🎨 BlurredBg showing page: $page');
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _BlurredBg(
                key: ValueKey(page),
                url: widget.urls[page],
              ),
            );
          },
        ),

        // ── Native PageView — GestureDetector INSIDE itemBuilder
        PageView.builder(
          controller: _controller,
          itemCount: widget.urls.length,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (i) {
            debugPrint('📄 Page changed → $i / ${widget.urls.length - 1}');
            _pageNotifier.value = i;
          },
          itemBuilder: (context, i) {
            debugPrint('🖼️ Building item $i: ${widget.urls[i]}');
            return GestureDetector(
              onLongPress: () {
                debugPrint('🔒 LongPress on image $i');
                widget.onLongPress?.call();
              },
              child: Center(
                child: Image.network(
                  widget.urls[i],
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      debugPrint('✅ Image $i loaded');
                      return child;
                    }
                    debugPrint('⏳ Image $i loading...');
                    return widget.buildShimmer();
                  },
                  errorBuilder: (_, error, __) {
                    debugPrint('❌ Image $i error: $error');
                    return Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.broken_image,
                          size: 80, color: Colors.white54),
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
                        )]
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
          top: MediaQuery.of(context).padding.top + 16,
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