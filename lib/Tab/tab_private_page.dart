import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:my_vibe_flick/screens/post_detail_page.dart'; // 👈 PostDetailPage import

class TabPrivatePage extends StatefulWidget {
  const TabPrivatePage({super.key});

  @override
  State<TabPrivatePage> createState() => _TabPrivatePageState();
}

class _TabPrivatePageState extends State<TabPrivatePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? currentUserId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _privatePosts = [];

  @override
  void initState() {
    super.initState();
    _loadPrivatePosts();
  }

  Future<void> _loadPrivatePosts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No authenticated user');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      currentUserId = currentUser.uid;
      debugPrint('🔐 Loading private posts for UID: $currentUserId');

      // Query media_posts collection for "onlyme" posts
      final querySnapshot = await _db
          .collection('media_posts')
          .where('uid', isEqualTo: currentUserId)
          .where('who_can_view', isEqualTo: 'onlyme')
          .where('is_active', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .get();

      debugPrint('📊 Found ${querySnapshot.docs.length} private posts');

      _privatePosts.clear();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        _privatePosts.add({
          'id': doc.id,
          'media_url': data['media_url'] ?? '',
          'thumbnail_url': data['thumbnail_url'] ?? '',
          'type': data['type'] ?? 'image',
          'description': data['description'] ?? '',
          'timestamp': data['timestamp'],
          'username': data['username'] ?? '',
          'uid': data['uid'] ?? '',               // 👈 uid save කරන්න
          'cloudinary_public_id': data['cloudinary_public_id'] ?? '',
          'likes': data['likes'] ?? 0,
        });
      }

      debugPrint('✅ Loaded ${_privatePosts.length} private posts successfully');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading private posts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ Format view count like TikTok (2.5M, 1.8M, 950.0K, etc.)
  String _formatViewCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  // ✅ Private post tap handler — PostDetailPage open කරනවා
  // Query ම .where('uid', isEqualTo: currentUserId) filter කරලා ගෙනාව නිසා
  // මේ posts ඔක්කොම current user ගෙ. Extra check අවශ්‍ය නෑ.
  void _onPostTapped(Map<String, dynamic> post) {
    final postId = post['id'] ?? '';

    if (postId.isEmpty) {
      debugPrint('❌ Invalid post ID');
      return;
    }

    debugPrint('🔓 Opening private post: $postId (user: $currentUserId)');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          postId: postId,
          initialUserId: currentUserId, // 👈 currentUserId directly
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        constraints: const BoxConstraints(minHeight: 280),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
          ),
        ),
      );
    }

    if (_privatePosts.isEmpty) {
      return Container(
        constraints: const BoxConstraints(minHeight: 280),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(40),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.02),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Color(0xFFCBD5E1),
                ),
                SizedBox(height: 16),
                Text(
                  'No private content',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Your private posts will appear here',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: RefreshIndicator(
        onRefresh: _loadPrivatePosts,
        color: const Color(0xFF8B5CF6),
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 0.67,
          ),
          itemCount: _privatePosts.length,
          itemBuilder: (context, index) {
            final post = _privatePosts[index];
            return _buildPrivatePostItem(post);
          },
        ),
      ),
    );
  }

  Widget _buildPrivatePostItem(Map<String, dynamic> post) {
    final isVideo = post['type'] == 'video';

    return GestureDetector(
      onTap: () => _onPostTapped(post), // 👈 Updated tap handler
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media Display
              if (isVideo)
                (post['thumbnail_url'] ?? '').isNotEmpty
                    ? Image.network(
                  post['thumbnail_url'],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF8B5CF6)),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(Icons.play_circle_outline,
                            size: 40, color: Colors.white54),
                      ),
                    );
                  },
                )
                    : Container(
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(Icons.play_circle_outline,
                        size: 40, color: Colors.white54),
                  ),
                )
              else
              // Image post
                (post['thumbnail_url'] ?? '').isNotEmpty
                    ? Image.network(
                  post['thumbnail_url'],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF8B5CF6)),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image,
                              size: 30, color: Colors.grey),
                        ),
                      ),
                )
                    : (post['media_url'] ?? '').isNotEmpty
                    ? Image.network(
                  post['media_url'],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF8B5CF6)),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image,
                              size: 30, color: Colors.grey),
                        ),
                      ),
                )
                    : Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.image,
                        size: 30, color: Colors.grey),
                  ),
                ),

              // Video Play Icon Overlay (top right)
              if (isVideo)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),

              // Views count (bottom left - TikTok style)
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatViewCount(post['likes'] ?? 0),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Private Lock Badge (top left)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.lock,
                        size: 10,
                        color: Colors.white,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Private',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
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

// Video Thumbnail Widget
class _VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;

  const _VideoThumbnailWidget({required this.videoUrl});

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.network(widget.videoUrl);
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Video thumbnail error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
          ),
        ),
      );
    }

    return VideoPlayer(_controller!);
  }
}