import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// ❤️ Likes Tab - Display user's liked posts
class TabLikes extends StatefulWidget {
  const TabLikes({Key? key}) : super(key: key);

  @override
  State<TabLikes> createState() => _TabLikesState();
}

class _TabLikesState extends State<TabLikes> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _likedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLikedPosts();
  }

  Future<void> _loadLikedPosts() async {
    try {
      setState(() => _isLoading = true);

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('❤️ Loading liked posts for UID: ${currentUser.uid}');

      final likesSnapshot = await _db
          .collection('likes')
          .where('uid', isEqualTo: currentUser.uid)  // ← uid
          .orderBy('timestamp', descending: true)     // ← timestamp
          .get();

      _likedPosts.clear();

      for (var likeDoc in likesSnapshot.docs) {
        final postId = likeDoc.data()['postId'] as String?;

        if (postId != null) {
          final postDoc = await _db.collection('media_posts').doc(postId).get();

          if (postDoc.exists) {
            final postData = postDoc.data()!;
            _likedPosts.add({
              'id': postDoc.id,
              'media_url': postData['media_url'] ?? postData['mediaUrl'] ?? '',
              'thumbnail_url': postData['thumbnail_url'] ?? postData['thumbnailUrl'] ?? '',
              'type': postData['type'] ?? postData['mediaType'] ?? 'image',
              'description': postData['description'] ?? postData['caption'] ?? '',
              'username': postData['username'] ?? '',
              'views': postData['views'] ?? 0,
              'likes': postData['likes'] ?? 0,
              'likedAt': likeDoc.data()['likedAt'],

            });
          }
        }
      }

      debugPrint('✅ Loaded ${_likedPosts.length} liked posts');
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error loading liked posts: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF3B5C),
        ),
      );
    }

    if (_likedPosts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadLikedPosts,
      color: const Color(0xFFFF3B5C),
      backgroundColor: const Color(0xFF2A2A2A),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.7,
        ),
        itemCount: _likedPosts.length,
        itemBuilder: (context, index) {
          return _buildLikedPostItem(_likedPosts[index]);
        },
      ),
    );
  }

  Widget _buildLikedPostItem(Map<String, dynamic> post) {
    final isVideo = post['type'] == 'video';
    final mediaUrl = post['media_url'] ?? '';
    final thumbnailUrl = post['thumbnail_url'] ?? mediaUrl;
    final description = post['description'] as String;
    final views = post['views'] as int;

    final words = description.split(' ').take(3).join(' ');
    final shortDescription = words.length > 20
        ? '${words.substring(0, 20)}...'
        : words;

    return GestureDetector(
      onTap: () {
        debugPrint('❤️ Tapped liked post: ${post['id']}');
        // TODO: Navigate to post details
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF2A2A2A),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail Image
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFF2A2A2A),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF3B5C),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFF2A2A2A),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 40,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
              ),

              // Bottom gradient with description
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (shortDescription.isNotEmpty)
                        Text(
                          shortDescription,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white70,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatViewCount(views),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Video play icon
              if (isVideo)
                Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),

              // Like badge
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B5C).withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // AFTER
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B5C).withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 40,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No liked posts yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF888888),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Posts you like will appear here',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatViewCount(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }
}