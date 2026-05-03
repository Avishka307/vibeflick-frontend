import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_vibe_flick/screens/profile_post_feed_page.dart';
import 'package:video_player/video_player.dart';
import 'package:my_vibe_flick/screens/post_detail_page.dart'; // ✅ Import post detail page

class FragmentFollowing extends StatefulWidget {
  const FragmentFollowing({Key? key}) : super(key: key);

  @override
  State<FragmentFollowing> createState() => _FragmentFollowingState();
}

class _FragmentFollowingState extends State<FragmentFollowing>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> followingPosts = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
    _loadFollowingPosts();
  }

  Future<void> _loadFollowingPosts() async {
    if (_currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      debugPrint('📥 Loading following posts for user: $_currentUserId');

      // Get list of users that current user is following
      final followingSnapshot = await _db
          .collection('follows')
          .where('followerId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active') // ✅ Only accepted follows
          .get();

      debugPrint('👥 Found ${followingSnapshot.docs.length} following users');

      if (followingSnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          followingPosts = [];
        });
        return;
      }

      // Extract following user IDs
      List<String> followingUserIds = [];
      for (var doc in followingSnapshot.docs) {
        final followingId = doc.data()['followingId'] as String?;
        if (followingId != null) {
          followingUserIds.add(followingId);
        }
      }

      debugPrint('📋 Following user IDs: $followingUserIds');

      // Load followers posts from following users
      followingPosts.clear();

      for (String userId in followingUserIds) {
        // Get followers posts from this user
        final postsSnapshot = await _db
            .collection('media_posts')
            .where('uid', isEqualTo: userId)
            .where('who_can_view', isEqualTo: 'followers')
            .where('is_active', isEqualTo: true)
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get();

        debugPrint('📊 User $userId has ${postsSnapshot.docs.length} followers posts');

        for (var doc in postsSnapshot.docs) {
          final data = doc.data();
          followingPosts.add({
            'id': doc.id,
            'uid': data['uid'] ?? '',
            'username': data['username'] ?? 'Unknown',
            'user_email': data['user_email'] ?? '',
            'media_url': data['media_url'] ?? '',
            'type': data['type'] ?? 'image',
            'description': data['description'] ?? '',
            'timestamp': data['timestamp'],
            'hashtags': data['hashtags'] ?? [],
            'who_can_view': 'followers',
            'thumbnail_url': data['thumbnail_url'], // ✅ Include thumbnail
          });
        }
      }

      // Sort all posts by timestamp
      followingPosts.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      debugPrint('✅ Loaded ${followingPosts.length} following posts');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading following posts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: followingPosts.isEmpty
          ? _buildEmptyState()
          : _buildPostsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Icon with Gradient Background
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade400,
                        Colors.purple.shade400,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.people_outline_rounded,
                    size: 70,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 32),

                // Main Title
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Colors.grey.shade800,
                      Colors.grey.shade600,
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'No Following Posts',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 16),

                // Description
                Text(
                  'You\'re not following anyone yet.\nFollow users to see their posts here!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    height: 1.6,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Action Button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade600,
                        Colors.blue.shade800,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _showFindPeopleDialog();
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.person_add_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Find People to Follow',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Refresh button
                TextButton(
                  onPressed: _loadFollowingPosts,
                  child: Text(
                    'Refresh Feed',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    return RefreshIndicator(
      onRefresh: _loadFollowingPosts,
      color: Colors.blue,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: followingPosts.length,
        itemBuilder: (context, index) {
          final post = followingPosts[index];
          return _buildPostCard(post);
        },
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final isVideo = post['type'] == 'video';
    final mediaUrl = post['media_url'] ?? '';
    final thumbnailUrl = post['thumbnail_url'] ?? '';
    final username = post['username'] ?? 'Unknown';
    final description = post['description'] ?? '';
    final timestamp = post['timestamp'] as Timestamp?;
    final postId = post['id'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    username[0].toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Followers Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people,
                        size: 12,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Followers',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Post Description
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                description,
                style: const TextStyle(fontSize: 14, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const SizedBox(height: 12),

          // ✅ Post Media - Navigate to PostDetailPage on tap
          // අලුත් ✅
          GestureDetector(
            onTap: () {
              debugPrint('🎬 Opening post detail: $postId');
              final clickedIndex = followingPosts.indexWhere((p) => p['id'] == postId);
              final startIndex = clickedIndex < 0 ? 0 : clickedIndex;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePostFeedPage(
                    posts: List<Map<String, dynamic>>.from(followingPosts),
                    initialIndex: startIndex,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isVideo
                  ? _VideoThumbnailWidget(
                videoUrl: mediaUrl,
                thumbnailUrl: thumbnailUrl,
              )
                  : Image.network(
                mediaUrl,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 250,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 60,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Post Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildActionButton(
                  Icons.favorite_border_rounded,
                  'Like',
                ),
                const SizedBox(width: 20),
                _buildActionButton(
                  Icons.chat_bubble_outline_rounded,
                  'Comment',
                ),
                const SizedBox(width: 20),
                _buildActionButton(
                  Icons.share_outlined,
                  'Share',
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bookmark_border_rounded),
                  onPressed: () {},
                  color: Colors.grey.shade700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    final now = DateTime.now();
    final postTime = timestamp.toDate();
    final difference = now.difference(postTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${postTime.day}/${postTime.month}/${postTime.year}';
    }
  }

  void _showFindPeopleDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Discover People',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find interesting people to follow',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'User suggestions will appear here',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ Video Thumbnail Widget with Static Image Preview
class _VideoThumbnailWidget extends StatelessWidget {
  final String videoUrl;
  final String thumbnailUrl;

  const _VideoThumbnailWidget({
    required this.videoUrl,
    required this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Show thumbnail image if available
          if (thumbnailUrl.isNotEmpty)
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.video_library,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            )
          else
            Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(
                  Icons.video_library,
                  size: 60,
                  color: Colors.grey,
                ),
              ),
            ),

          // Play button overlay
          Center(
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}