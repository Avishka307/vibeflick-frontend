import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../models/media_post.dart';
import '../services/firestore_service.dart';
import 'activity_full_screen_player.dart';

// ═══════════════════════════════════════════════════════════
// 📱 MAIN FRAGMENT - UploadsMediaFragment
// ═══════════════════════════════════════════════════════════
class FragmentUploadsMediaUser extends StatefulWidget {
  final String? profileUid;

  const FragmentUploadsMediaUser({Key? key, this.profileUid}) : super(key: key);

  @override
  State<FragmentUploadsMediaUser> createState() =>
      _FragmentUploadsMediaUserState();
}

class _FragmentUploadsMediaUserState extends State<FragmentUploadsMediaUser> {
  static const String TAG = "UploadsMediaFragment";
  List<MediaPost> posts = [];
  bool isLoading = true;
  String? profileUid;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    developer.log("=== UploadsMediaFragment Debug ===", name: TAG);
    developer.log("Fragment created and view inflated", name: TAG);

    // Get which user's uploads to show
    profileUid = widget.profileUid;
    developer.log("Profile UID from arguments: $profileUid", name: TAG);

    String? myUid = FirebaseAuth.instance.currentUser?.uid;
    developer.log("My UID: $myUid", name: TAG);

    if (profileUid == null) {
      profileUid = myUid;
      developer.log("Profile UID was null, set to myUid: $profileUid", name: TAG);
    }

    bool isMyProfile = profileUid != null && profileUid == myUid;
    developer.log("Is my profile: $isMyProfile", name: TAG);

    // 📝 NEW LOGIC: UploadsMediaFragment shows Public + Followers only
    // OnlyMe posts are now handled by PrivateFragment
    List<String> allowedViewTypes = isMyProfile
        ? ["public", "followers"] // 🔄 REMOVED "onlyme"
        : ["public"];

    developer.log("Allowed view types: $allowedViewTypes", name: TAG);
    developer.log("Loading posts for profile: $profileUid", name: TAG);
    developer.log("📝 NOTE: OnlyMe posts are excluded - use PrivateFragment instead", name: TAG);

    await _loadPosts(allowedViewTypes);
  }

  Future<void> _loadPosts(List<String> allowedViewTypes) async {
    try {
      // Load user posts with allowed view types
      List<MediaPost> loadedPosts = await _loadUserPosts(
        profileUid!,
        allowedViewTypes,
        50,
      );

      developer.log("✅ Posts loaded successfully in UploadsMediaFragment", name: TAG);
      developer.log("Total posts count: ${loadedPosts.length}", name: TAG);

      for (int i = 0; i < loadedPosts.length; i++) {
        MediaPost post = loadedPosts[i];
        developer.log("Post ${i + 1} in UploadsMediaFragment:", name: TAG);
        developer.log("  - ID: ${post.id}", name: TAG);
        developer.log("  - who_can_view: ${post.whoCanView}", name: TAG);
        developer.log("  - uid: ${post.uid}", name: TAG);
        developer.log("  - is_active: ${post.isActive}", name: TAG);

        // 🔍 VERIFY: Should not contain OnlyMe posts
        if (post.whoCanView == "onlyme") {
          developer.log("⚠️ WARNING: OnlyMe post found in UploadsMediaFragment!", name: TAG);
          developer.log("Post ID: ${post.id} - This should be in PrivateFragment", name: TAG);
        }
      }

      if (mounted) {
        setState(() {
          posts = loadedPosts;
          isLoading = false;
        });
      }

      developer.log("Posts set to adapter successfully", name: TAG);
      developer.log("UploadsMediaFragment setup completed", name: TAG);
    } catch (e) {
      developer.log("❌ Error loading posts in UploadsMediaFragment: $e", name: TAG);
      developer.log("Error details: ${e.toString()}", name: TAG);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading posts: $e"),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Load user posts from Firestore
  Future<List<MediaPost>> _loadUserPosts(
      String uid,
      List<String> allowedViewTypes,
      int limit,
      ) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('media_posts')
          .where('uid', isEqualTo: uid)
          .where('is_active', isEqualTo: true)
          .where('who_can_view', whereIn: allowedViewTypes)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) {
        try {
          return MediaPost.fromFirestore(doc);
        } catch (e) {
          developer.log('Error parsing post ${doc.id}: $e', name: TAG);
          return null;
        }
      })
          .whereType<MediaPost>()
          .toList();
    } catch (e) {
      developer.log('Error loading user posts: $e', name: TAG);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (posts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              "No uploads yet",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // ✅ TikTok-style grid with 3 columns and minimal spacing
    return GridView.builder(
      padding: const EdgeInsets.all(1), // Minimal padding
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2, // 1dp spacing like Java
        mainAxisSpacing: 2,
        childAspectRatio: 1 / 1.6, // TikTok-style tall aspect ratio
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return UploadsMediaCard(post: posts[index]);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎬 UPLOADS MEDIA CARD WIDGET
// ═══════════════════════════════════════════════════════════
class UploadsMediaCard extends StatefulWidget {
  final MediaPost post;

  const UploadsMediaCard({Key? key, required this.post}) : super(key: key);

  @override
  State<UploadsMediaCard> createState() => _UploadsMediaCardState();
}

class _UploadsMediaCardState extends State<UploadsMediaCard> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  int _viewsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadViewsCount();

    // Initialize video preview if it's a video
    if (widget.post.type?.toLowerCase() == 'video' && widget.post.mediaUrl != null) {
      _initializeVideoPreview();
    }
  }

  Future<void> _initializeVideoPreview() async {
    try {
      _videoController = VideoPlayerController.network(widget.post.mediaUrl!);
      await _videoController!.initialize();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });

        // Mute and seek to 1 second for preview
        _videoController!.setVolume(0);
        _videoController!.setLooping(true);

        if (_videoController!.value.duration.inMilliseconds > 1000) {
          _videoController!.seekTo(const Duration(seconds: 1));
        }
      }
    } catch (e) {
      developer.log('Error initializing video preview: $e');
    }
  }

  Future<void> _loadViewsCount() async {
    if (widget.post.id == null) return;

    // Real-time listener for views count
    FirebaseFirestore.instance
        .collection('media_posts')
        .doc(widget.post.id)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data();
        final count = (data?['viewsCount'] as int?) ?? (data?['viewCount'] as int?) ?? 0;

        setState(() {
          _viewsCount = count;
        });
      }
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
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

  IconData _getVisibilityIcon() {
    switch (widget.post.whoCanView) {
      case 'public':
        return Icons.public;
      case 'followers':
        return Icons.people;
      case 'onlyme':
        return Icons.lock;
      default:
        return Icons.help_outline;
    }
  }

  Color _getVisibilityColor() {
    switch (widget.post.whoCanView) {
      case 'public':
        return Colors.green;
      case 'followers':
        return Colors.blue;
      case 'onlyme':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _handleTap() {
    // Debug logging (exactly like Java)
    developer.log("AdapterClick - Media URL: ${widget.post.mediaUrl}");
    developer.log("AdapterClick - Media Type: ${widget.post.type}");
    developer.log("AdapterClick - Uploader UID: ${widget.post.uid}");
    developer.log("AdapterClick - Document ID: ${widget.post.id}");
    developer.log("AdapterClick - Username: ${widget.post.username}");

    // Navigate to FullScreenPlayerActivity (exactly like Java Intent)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenPlayerActivity(
          mediaUrl: widget.post.mediaUrl ?? '',
          mediaType: widget.post.type ?? 'image',
          uploaderUid: widget.post.uid ?? '',
          description: widget.post.description ?? '',
          username: widget.post.username ?? '',
          musicInfo: widget.post.musicTitle ?? '',
          documentId: widget.post.id ?? '',
        ),
      ),
    );
  }

  void _showPostDetail() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(widget.post.username ?? 'User'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      // Handle more options
                    },
                  ),
                ],
              ),

              // Media
              Expanded(
                child: widget.post.mediaUrl != null
                    ? widget.post.type?.toLowerCase() == 'video'
                    ? _isVideoInitialized
                    ? VideoPlayer(_videoController!)
                    : const Center(child: CircularProgressIndicator())
                    : InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: widget.post.mediaUrl!,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                    const Center(child: Icon(Icons.error)),
                  ),
                )
                    : const Center(child: Icon(Icons.image, size: 64)),
              ),

              // Caption and Info
              if (widget.post.description != null && widget.post.description!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.description!,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _getVisibilityIcon(),
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getVisibilityText(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.visibility,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatViewsCount(_viewsCount),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getVisibilityText() {
    switch (widget.post.whoCanView) {
      case 'public':
        return 'Public';
      case 'followers':
        return 'Followers only';
      case 'onlyme':
        return 'Only me';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.post.type?.toLowerCase() == 'video';

    return GestureDetector(
      onTap: _handleTap,
      child: Card(
        margin: const EdgeInsets.all(2),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ═══════════════════════════════════════════════════════════
              // 🎬 MEDIA CONTENT (Video or Image)
              // ═══════════════════════════════════════════════════════════
              if (isVideo)
                _isVideoInitialized
                    ? VideoPlayer(_videoController!)
                    : Container(
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(
                      Icons.videocam,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                )
              else if (widget.post.mediaUrl != null)
                CachedNetworkImage(
                  imageUrl: widget.post.mediaUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.error_outline, color: Colors.grey),
                    ),
                  ),
                )
              else
                const Center(
                  child: Icon(Icons.image, color: Colors.grey),
                ),

              // ═══════════════════════════════════════════════════════════
              // ▶️ PLAY ICON (for videos)
              // ═══════════════════════════════════════════════════════════
              if (isVideo)
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),

              // ═══════════════════════════════════════════════════════════
              // 🔒 VISIBILITY BADGE (top-right)
              // ═══════════════════════════════════════════════════════════
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getVisibilityIcon(),
                    size: 16,
                    color: _getVisibilityColor(),
                  ),
                ),
              ),

              // ═══════════════════════════════════════════════════════════
              // 👁️ VIEWS COUNT (bottom-left)
              // ═══════════════════════════════════════════════════════════
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatViewsCount(_viewsCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ═══════════════════════════════════════════════════════════
              // 📐 GRADIENT OVERLAY (bottom for better text visibility)
              // ═══════════════════════════════════════════════════════════
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}