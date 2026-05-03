import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

// ═══════════════════════════════════════════════════════════
// 🎬 FULL SCREEN PLAYER ACTIVITY
// ═══════════════════════════════════════════════════════════
class FullScreenPlayerActivity extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final String uploaderUid;
  final String description;
  final String username;
  final String musicInfo;
  final String documentId;

  const FullScreenPlayerActivity({
    Key? key,
    required this.mediaUrl,
    required this.mediaType,
    required this.uploaderUid,
    required this.description,
    required this.username,
    required this.musicInfo,
    required this.documentId,
  }) : super(key: key);

  @override
  State<FullScreenPlayerActivity> createState() =>
      _FullScreenPlayerActivityState();
}

class _FullScreenPlayerActivityState extends State<FullScreenPlayerActivity>
    with TickerProviderStateMixin {
  // Firebase
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _currentUserId;
  String? _currentUserName;

  // Video player
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = true;

  // Animation
  late AnimationController _spinController;
  bool _hasAudio = false;

  // Counts
  int _likeCount = 0;
  int _commentCount = 0;
  int _viewsCount = 0;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isFollowing = false;

  // Description
  bool _isDescriptionExpanded = false;
  static const int _maxDescriptionLength = 100;

  // Profile image
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _initializeActivity();
  }

  Future<void> _initializeActivity() async {
    // Debug logging (exactly like Java)
    developer.log("FullScreenDebug - Media URL: ${widget.mediaUrl}");
    developer.log("FullScreenDebug - Media Type: ${widget.mediaType}");
    developer.log("FullScreenDebug - Uploader UID: ${widget.uploaderUid}");
    developer.log("FullScreenDebug - Document ID: ${widget.documentId}");
    developer.log("FullScreenDebug - Username: ${widget.username}");
    developer.log("FullScreenDebug - Music Info: ${widget.musicInfo}");
    developer.log("FullScreenDebug - Description: ${widget.description}");

    // Check critical values
    if (widget.uploaderUid.isEmpty) {
      developer.log("ERROR: uploaderUid is null!");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Uploader ID is missing')),
        );
        Navigator.pop(context);
      }
      return;
    }

    if (widget.documentId.isEmpty) {
      developer.log("ERROR: documentId is null!");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Document ID is missing')),
        );
        Navigator.pop(context);
      }
      return;
    }

    // Get current user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      developer.log("✅ User logged in: ${currentUser.uid}");
      developer.log("✅ User email: ${currentUser.email}");
      _currentUserId = currentUser.uid;
      _currentUserName = currentUser.displayName ?? currentUser.email;
    } else {
      developer.log("❌ NO USER LOGGED IN!");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first')),
        );
        Navigator.pop(context);
      }
      return;
    }

    developer.log("📍 Document path: media_posts/${widget.documentId}");
    developer.log("📍 Current User: $_currentUserId");
    developer.log("📍 Uploader UID: ${widget.uploaderUid}");

    // Initialize spinning animation controller
    _spinController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Load data
    await Future.wait<void>([
      _loadProfileImage(),
      _loadLikeStatus(),
      _loadSaveStatus(),
      _loadFollowStatus(),
    ]);

    // Load counts (no await - these use streams)
    _loadCounts();

    // Record view (no await needed)
    _recordView();

    // Initialize video if needed
    if (widget.mediaType.toLowerCase() == 'video') {
      await _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      developer.log("🎬 Initializing video: ${widget.mediaUrl}");

      _videoController = VideoPlayerController.network(widget.mediaUrl);
      await _videoController!.initialize();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });

        _videoController!.setLooping(true);
        _videoController!.setVolume(1.0); // 🔊 Enable sound
        _videoController!.play();

        // Check if video has audio
        _hasAudio = _videoController!.value.volume > 0;

        developer.log("✅ Video initialized and playing");
      }
    } catch (e) {
      developer.log("❌ Video initialization error: $e");
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
        });
      }
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      final userDoc = await _db.collection('users').doc(widget.uploaderUid).get();

      if (userDoc.exists) {
        final data = userDoc.data();
        _profileImageUrl = data?['profile_picture_url'] as String? ??
            data?['profile_url'] as String? ??
            data?['profileUrl'] as String?;

        developer.log("Profile URL found: $_profileImageUrl");

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      developer.log("Error loading profile image: $e");
    }
  }

  Future<void> _loadLikeStatus() async {
    if (_currentUserId == null) return;

    try {
      final likeDoc = await _db
          .collection('media_posts')
          .doc(widget.documentId)
          .collection('likes')
          .doc(_currentUserId)
          .get();

      if (mounted) {
        setState(() {
          _isLiked = likeDoc.exists;
        });
      }
    } catch (e) {
      developer.log("Error loading like status: $e");
    }
  }

  Future<void> _loadSaveStatus() async {
    if (_currentUserId == null) return;

    try {
      final saveDocId = '${_currentUserId}_${widget.documentId}';
      final saveDoc = await _db.collection('saved_posts').doc(saveDocId).get();

      if (mounted) {
        setState(() {
          _isSaved = saveDoc.exists;
        });
      }
    } catch (e) {
      developer.log("Error loading save status: $e");
    }
  }

  Future<void> _loadFollowStatus() async {
    if (_currentUserId == null || _currentUserId == widget.uploaderUid) {
      return;
    }

    try {
      final followDocId = '${_currentUserId}_${widget.uploaderUid}';
      final followDoc = await _db.collection('follows').doc(followDocId).get();

      if (mounted) {
        setState(() {
          _isFollowing = followDoc.exists;
        });
      }
    } catch (e) {
      developer.log("Error loading follow status: $e");
    }
  }

  void _loadCounts() {
    // Like count stream
    _db
        .collection('media_posts')
        .doc(widget.documentId)
        .collection('likes')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _likeCount = snapshot.size;
        });
      }
    });

    // Comment count stream
    _db
        .collection('media_posts')
        .doc(widget.documentId)
        .collection('comments')
        .where('reply', isEqualTo: false)
        .snapshots()
        .asyncMap((snapshot) async {
      int totalCount = snapshot.size;

      for (var doc in snapshot.docs) {
        final replies = await _db
            .collection('media_posts')
            .doc(widget.documentId)
            .collection('comments')
            .doc(doc.id)
            .collection('replies')
            .get();
        totalCount += replies.size;
      }

      return totalCount;
    }).listen((count) {
      if (mounted) {
        setState(() {
          _commentCount = count;
        });
      }
    });

    // Views count stream
    _db
        .collection('media_posts')
        .doc(widget.documentId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data();
        final count = (data?['viewsCount'] as int?) ??
            (data?['viewCount'] as int?) ??
            0;

        setState(() {
          _viewsCount = count;
        });
      }
    });
  }

  Future<void> _recordView() async {
    if (_currentUserId == null || _currentUserId == widget.uploaderUid) {
      developer.log("Skipping view tracking for own post");
      return;
    }

    try {
      final postRef = _db.collection('media_posts').doc(widget.documentId);
      final postDoc = await postRef.get();

      if (postDoc.exists) {
        final data = postDoc.data();
        final viewsUsers =
            (data?['viewsUsers'] as List<dynamic>?)?.cast<String>() ?? [];

        if (!viewsUsers.contains(_currentUserId)) {
          await postRef.update({
            'viewsUsers': FieldValue.arrayUnion([_currentUserId!]),
            'viewsCount': FieldValue.increment(1),
            'viewCount': FieldValue.increment(1),
          });
          developer.log("View recorded for post: ${widget.documentId}");
        }
      }
    } catch (e) {
      developer.log("Error recording view: $e");
    }
  }

  String _formatCount(int count) {
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

  Future<void> _toggleLike() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to like posts')),
      );
      return;
    }

    try {
      final likeRef = _db
          .collection('media_posts')
          .doc(widget.documentId)
          .collection('likes')
          .doc(_currentUserId);

      final likeDoc = await likeRef.get();
      final currentlyLiked = likeDoc.exists;

      if (currentlyLiked) {
        // Unlike
        await likeRef.delete();
        setState(() {
          _isLiked = false;
        });
      } else {
        // Like
        await likeRef.set({
          'uid': _currentUserId,
          'username': _currentUserName ?? 'Unknown User',
          'postId': widget.documentId,
          'postOwnerId': widget.uploaderUid,
          'postOwnerName': widget.username,
          'timestamp': FieldValue.serverTimestamp(),
          'likedAt': DateTime.now().millisecondsSinceEpoch,
        });

        setState(() {
          _isLiked = true;
        });

        // Send notification
        if (widget.uploaderUid != _currentUserId) {
          await _sendLikeNotification();
        }
      }
    } catch (e) {
      developer.log("Error toggling like: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like post: $e')),
      );
    }
  }

  Future<void> _sendLikeNotification() async {
    try {
      await _db
          .collection('users')
          .doc(widget.uploaderUid)
          .collection('notifications')
          .add({
        'toUserId': widget.uploaderUid,
        'type': 'like',
        'fromUserId': _currentUserId,
        'fromUserName': _currentUserName ?? 'Unknown User',
        'timestamp': FieldValue.serverTimestamp(),
        'postId': widget.documentId,
        'processed': false,
      });
      developer.log("Like notification sent");
    } catch (e) {
      developer.log("Error sending like notification: $e");
    }
  }

  Future<void> _toggleSave() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to save posts')),
      );
      return;
    }

    try {
      final saveDocId = '${_currentUserId}_${widget.documentId}';
      final saveRef = _db.collection('saved_posts').doc(saveDocId);

      final saveDoc = await saveRef.get();
      final currentlySaved = saveDoc.exists;

      if (currentlySaved) {
        // Unsave
        await saveRef.delete();
        setState(() {
          _isSaved = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📤 Post removed from saved')),
        );
      } else {
        // Save
        await saveRef.set({
          'userId': _currentUserId,
          'postId': widget.documentId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'postOwnerId': widget.uploaderUid,
          'postOwnerName': widget.username,
          'mediaUrl': widget.mediaUrl,
          'mediaType': widget.mediaType,
          'description': widget.description,
        });

        setState(() {
          _isSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Post saved!')),
        );
      }
    } catch (e) {
      developer.log("Error toggling save: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save post: $e')),
      );
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to follow users')),
      );
      return;
    }

    if (_currentUserId == widget.uploaderUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't follow yourself")),
      );
      return;
    }

    try {
      final followDocId = '${_currentUserId}_${widget.uploaderUid}';
      final followRef = _db.collection('follows').doc(followDocId);

      final followDoc = await followRef.get();
      final currentlyFollowing = followDoc.exists;

      if (currentlyFollowing) {
        // Unfollow
        await followRef.delete();
        setState(() {
          _isFollowing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You unfollowed ${widget.username}')),
        );
      } else {
        // Follow
        await followRef.set({
          'followerId': _currentUserId,
          'followerName': _currentUserName ?? 'Unknown User',
          'followingId': widget.uploaderUid,
          'followingName': widget.username,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        setState(() {
          _isFollowing = true;
        });

        // Send notification
        await _sendFollowNotification();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are now following ${widget.username}')),
        );
      }
    } catch (e) {
      developer.log("Error toggling follow: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to follow: $e')),
      );
    }
  }

  Future<void> _sendFollowNotification() async {
    try {
      await _db
          .collection('users')
          .doc(widget.uploaderUid)
          .collection('notifications')
          .add({
        'toUserId': widget.uploaderUid,
        'type': 'follow',
        'fromUserId': _currentUserId,
        'fromUserName': _currentUserName ?? 'Unknown User',
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
        'extraData': {
          'targetUsername': widget.username,
          'source': 'fullscreen_player',
        },
      });
      developer.log("Follow notification sent");
    } catch (e) {
      developer.log("Error sending follow notification: $e");
    }
  }

  void _handleComment() {
    // TODO: Open comment bottom sheet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comments feature coming soon')),
    );
  }

  void _handleShare() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon')),
    );
  }

  void _handleMoreOptions() {
    // TODO: Open post options bottom sheet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post options coming soon')),
    );
  }

  void _openUserProfile() {
    // TODO: Navigate to UserProfileActivity
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening profile: ${widget.username}')),
    );
  }

  void _toggleVideoPlayback() {
    if (_videoController != null && _isVideoInitialized) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _currentUserId == widget.uploaderUid;
    final showFollowButton = !isOwner && !_isFollowing;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ═══════════════════════════════════════════════════════════
          // 🎬 MEDIA (Video or Image)
          // ═══════════════════════════════════════════════════════════
          if (widget.mediaType.toLowerCase() == 'video')
            GestureDetector(
              onTap: _toggleVideoPlayback,
              child: Center(
                child: _isVideoInitialized
                    ? AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                )
                    : _isVideoLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.error, color: Colors.white, size: 64),
              ),
            )
          else
            Center(
              child: CachedNetworkImage(
                imageUrl: widget.mediaUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.error, color: Colors.white, size: 64),
                ),
              ),
            ),

          // ═══════════════════════════════════════════════════════════
          // 🔙 BACK BUTTON (top-left)
          // ═══════════════════════════════════════════════════════════
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // ═══════════════════════════════════════════════════════════
          // ⋮ MORE OPTIONS (top-right) - Only for owner
          // ═══════════════════════════════════════════════════════════
          if (isOwner)
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.white, size: 28),
                onPressed: _handleMoreOptions,
              ),
            ),

          // ═══════════════════════════════════════════════════════════
          // 👉 RIGHT SIDEBAR (Actions)
          // ═══════════════════════════════════════════════════════════
          Positioned(
            right: 12,
            top: MediaQuery.of(context).size.height * 0.3,
            child: Column(
              children: [
                // Like Button
                _buildActionButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : Colors.white,
                  label: _formatCount(_likeCount),
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 24),

                // Comment Button
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  color: Colors.white,
                  label: _formatCount(_commentCount),
                  onTap: _handleComment,
                ),
                const SizedBox(height: 24),

                // Save Button
                _buildActionButton(
                  icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: _isSaved ? Colors.yellow : Colors.white,
                  label: 'Save',
                  onTap: _toggleSave,
                ),
                const SizedBox(height: 24),

                // Share Button
                _buildActionButton(
                  icon: Icons.share_outlined,
                  color: Colors.white,
                  label: 'Share',
                  onTap: _handleShare,
                ),
                const SizedBox(height: 24),

                // Spinning Music Icon
                if (widget.mediaType.toLowerCase() == 'video' && _hasAudio)
                  GestureDetector(
                    onTap: () {
                      final text = widget.musicInfo.isNotEmpty
                          ? widget.musicInfo
                          : 'Original Sound';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Track: $text')),
                      );
                    },
                    child: RotationTransition(
                      turns: _spinController,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade300,
                              Colors.blue.shade300,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.album,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ═══════════════════════════════════════════════════════════
          // 📝 BOTTOM INFO PANEL
          // ═══════════════════════════════════════════════════════════
          Positioned(
            left: 16,
            right: 80,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Row
                Row(
                  children: [
                    GestureDetector(
                      onTap: _openUserProfile,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.purple, width: 2),
                        ),
                        child: ClipOval(
                          child: _profileImageUrl != null
                              ? CachedNetworkImage(
                            imageUrl: _profileImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                _buildDefaultAvatar(),
                            errorWidget: (context, url, error) =>
                                _buildDefaultAvatar(),
                          )
                              : _buildDefaultAvatar(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _openUserProfile,
                        child: Text(
                          '@${widget.username}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (showFollowButton)
                      GestureDetector(
                        onTap: _toggleFollow,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.add_circle,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                if (widget.description.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDescriptionExpanded = !_isDescriptionExpanded;
                      });
                    },
                    child: Text(
                      _isDescriptionExpanded ||
                          widget.description.length <= _maxDescriptionLength
                          ? widget.description
                          : '${widget.description.substring(0, _maxDescriptionLength)}...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: _isDescriptionExpanded ? null : 3,
                    ),
                  ),

                if (widget.description.length > _maxDescriptionLength)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isDescriptionExpanded = !_isDescriptionExpanded;
                        });
                      },
                      child: Text(
                        _isDescriptionExpanded ? 'See less' : 'See more',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Music Info
                Row(
                  children: [
                    const Icon(
                      Icons.music_note,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.musicInfo.isNotEmpty
                            ? widget.musicInfo
                            : 'Original Sound',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ═══════════════════════════════════════════════════════════
          // 👁️ VIEWS COUNT (bottom-right)
          // ═══════════════════════════════════════════════════════════
          Positioned(
            bottom: 16,
            right: 88,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.visibility,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(_viewsCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ═══════════════════════════════════════════════════════════
          // ⏳ VIDEO LOADING PROGRESS
          // ═══════════════════════════════════════════════════════════
          if (_isVideoLoading && widget.mediaType.toLowerCase() == 'video')
            const Center(
              child: CircularProgressIndicator(
                color: Colors.purple,
                strokeWidth: 4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade300, Colors.blue.shade300],
        ),
      ),
      child: Center(
        child: Text(
          widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: Icon(
              icon,
              color: color,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}