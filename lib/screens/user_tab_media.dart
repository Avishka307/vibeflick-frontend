import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_vibe_flick/screens/post_detail_page.dart';
import 'package:my_vibe_flick/screens/profile_post_feed_page.dart';


class UserTabMedia extends StatefulWidget {
  final String? userId; // User's profile userId (not current user)

  const UserTabMedia({Key? key, this.userId}) : super(key: key);

  @override
  State<UserTabMedia> createState() => _UserTabMediaState();
}

class _UserTabMediaState extends State<UserTabMedia> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _mediaPosts = [];
  bool _isLoading = true;
  bool _isPrivateAccount = false;
  bool _isFollowing = false;
  bool _isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _loadUserMedia();
  }

  // ═══════════════════════════════════════════════════════════
  // 🆕🔒 CRITICAL: Check if target user has private account
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> _checkPrivacyAndFollowStatus(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;

    debugPrint('═══════════════════════════════════════');
    debugPrint('PRIVACY & FOLLOW STATUS CHECK');
    debugPrint('═══════════════════════════════════════');
    debugPrint('Current User ID: $currentUserId');
    debugPrint('Target User ID: $targetUserId');

    // 1. Check if viewing own profile
    bool isOwnProfile = (currentUserId == targetUserId);
    debugPrint('Is Own Profile: $isOwnProfile');

    if (isOwnProfile) {
      debugPrint('✅ Own profile - Full access granted');
      return {
        'canViewPosts': true,
        'isPrivateAccount': false,
        'isFollowing': false,
        'isOwnProfile': true,
      };
    }

    // 2. Load target user's privacy settings
    final userDoc = await _db.collection('users').doc(targetUserId).get();

    if (!userDoc.exists) {
      debugPrint('❌ User document does not exist!');
      return {
        'canViewPosts': false,
        'isPrivateAccount': false,
        'isFollowing': false,
        'isOwnProfile': false,
      };
    }

    final userData = userDoc.data()!;
    bool isPrivateAccount = userData['private_account'] ?? false;

    debugPrint('Target User Private Account: $isPrivateAccount');

    // 3. If public account, allow access
    if (!isPrivateAccount) {
      debugPrint('✅ Public account - Access granted');
      return {
        'canViewPosts': true,
        'isPrivateAccount': false,
        'isFollowing': false,
        'isOwnProfile': false,
      };
    }

    // 4. Private account - check follow status
    final followDocId = '${currentUserId}_$targetUserId';
    final followDoc = await _db.collection('follows').doc(followDocId).get();

    bool isFollowing = false;
    if (followDoc.exists) {
      final status = followDoc.data()?['status'];
      isFollowing = (status == 'accepted');
    }

    debugPrint('Follow Status: ${followDoc.exists ? "Document exists" : "No follow"}');
    debugPrint('Is Following (accepted): $isFollowing');

    bool canViewPosts = isFollowing;

    debugPrint('═══════════════════════════════════════');
    debugPrint('RESULT:');
    debugPrint('  Can View Posts: $canViewPosts');
    debugPrint('  Is Private Account: $isPrivateAccount');
    debugPrint('  Is Following: $isFollowing');
    debugPrint('═══════════════════════════════════════');

    return {
      'canViewPosts': canViewPosts,
      'isPrivateAccount': isPrivateAccount,
      'isFollowing': isFollowing,
      'isOwnProfile': false,
    };
  }

  Future<void> _loadUserMedia() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUserId = _auth.currentUser?.uid;
      final targetUserId = widget.userId ?? currentUserId;

      debugPrint('═══════════════════════════════════════');
      debugPrint('USER TAB MEDIA DEBUG');
      debugPrint('═══════════════════════════════════════');
      debugPrint('Current User ID: $currentUserId');
      debugPrint('Target User ID: $targetUserId');
      debugPrint('═══════════════════════════════════════');

      if (targetUserId == null) {
        debugPrint('ERROR: No user ID available!');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // ═══════════════════════════════════════════════════════════
      // 🆕🔒 STEP 1: Check privacy and follow status FIRST
      // ═══════════════════════════════════════════════════════════
      final privacyStatus = await _checkPrivacyAndFollowStatus(targetUserId);

      setState(() {
        _isPrivateAccount = privacyStatus['isPrivateAccount'] as bool;
        _isFollowing = privacyStatus['isFollowing'] as bool;
        _isOwnProfile = privacyStatus['isOwnProfile'] as bool;
      });

      // ═══════════════════════════════════════════════════════════
      // 🆕🔒 STEP 2: If cannot view posts, stop here!
      // ═══════════════════════════════════════════════════════════
      if (!(privacyStatus['canViewPosts'] as bool)) {
        debugPrint('🔒 BLOCKED: Cannot view posts (Private account, not following)');
        setState(() {
          _mediaPosts.clear();
          _isLoading = false;
        });
        return;
      }

      // ═══════════════════════════════════════════════════════════
      // 🆕🔒 STEP 3: Load posts (only if access is granted)
      // ═══════════════════════════════════════════════════════════
      debugPrint('✅ ACCESS GRANTED: Loading media posts for user: $targetUserId');

      final querySnapshot = await _db
          .collection('media_posts')
          .where('uid', isEqualTo: targetUserId)
          .where('is_active', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .get();

      debugPrint('Query returned ${querySnapshot.docs.length} documents');

      _mediaPosts.clear();

      // Process each document
      for (var doc in querySnapshot.docs) {
        final data = doc.data();

        debugPrint('-----------------------------------');
        debugPrint('Document ID: ${doc.id}');
        debugPrint('   uid: ${data['uid']}');
        debugPrint('   username: ${data['username']}');
        debugPrint('   who_can_view: ${data['who_can_view']}');
        debugPrint('   is_active: ${data['is_active']}');

        // Check visibility rules (additional check)
        final whoCanView = data['who_can_view'] ?? 'public';
        final postOwnerId = data['uid'] ?? '';

        bool canView = false;

        if (whoCanView == 'public') {
          canView = true;
          debugPrint('   Visibility: PUBLIC - Everyone can view');
        } else if (whoCanView == 'followers') {
          // Check if current user follows post owner
          if (currentUserId == postOwnerId) {
            canView = true;
            debugPrint('   Visibility: FOLLOWERS - Own post');
          } else {
            // Already checked follow status above
            canView = _isFollowing || _isOwnProfile;
            debugPrint('   Visibility: FOLLOWERS - Follow status: $canView');
          }
        } else if (whoCanView == 'onlyme') {
          canView = (currentUserId == postOwnerId);
          debugPrint('   Visibility: ONLY ME - Is owner: ${currentUserId == postOwnerId}');
        }

        if (canView) {
          _mediaPosts.add({
            'id': doc.id,
            'uid': data['uid'] ?? '',
            'username': data['username'] ?? 'Unknown',
            'media_url': data['media_url'] ?? '',
            'thumbnail_url': data['thumbnail_url'] ?? '',  // 👈 ADD
            'type': data['type'] ?? 'image',
            'description': data['description'] ?? '',
            'timestamp': data['timestamp'],
            'who_can_view': whoCanView,
            'likes': data['likes'] ?? 0,
            'commentCount': data['commentCount'] ?? 0,
            'viewCount': data['viewCount'] ?? 0,  // 🆕 ADD මේ line එක
          });
          debugPrint('   ADDED to display list');
        } else {
          debugPrint('   SKIPPED (no view permission)');
        }
      }
      debugPrint('═══════════════════════════════════════');
      debugPrint('FINAL RESULT: ${_mediaPosts.length} posts to display');
      debugPrint('═══════════════════════════════════════');

      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('ERROR loading user media: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ NEW: Navigate to PostDetailPage
  void _openPostDetail(String postId, String userId) {
    // clicked index find කරනවා
    final clickedIndex = _mediaPosts.indexWhere((p) => p['id'] == postId);
    final startIndex = clickedIndex < 0 ? 0 : clickedIndex;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePostFeedPage(
          posts: List<Map<String, dynamic>>.from(_mediaPosts),
          initialIndex: startIndex,
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3B82F6),
          strokeWidth: 2,
        ),
      );
    }

    // ═══════════════════════════════════════════════════════════
    // 🆕🔒 SHOW PRIVATE ACCOUNT MESSAGE (වෙනස්ම UI එකක්!)
    // ═══════════════════════════════════════════════════════════
    if (_isPrivateAccount && !_isFollowing && !_isOwnProfile) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 50,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'This Account is Private',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Follow this account to see their posts',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ═══════════════════════════════════════════════════════════
    // 🆕 EMPTY STATE (No posts yet)
    // ═══════════════════════════════════════════════════════════
    if (_mediaPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No media yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Posts will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    // ═══════════════════════════════════════════════════════════
    // 🆕 SHOW POSTS GRID
    // ═══════════════════════════════════════════════════════════
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 0.69,
      ),
      itemCount: _mediaPosts.length,
      itemBuilder: (context, index) {
        final post = _mediaPosts[index];
        return _buildMediaItem(post);
      },
    );
  }

  Widget _buildMediaItem(Map<String, dynamic> post) {
    final isVideo = post['type'] == 'video';
    final mediaUrl = post['media_url'] ?? '';
    final postId = post['id'] ?? '';
    final userId = post['uid'] ?? '';

    return GestureDetector(
      onTap: () {
        debugPrint('📱 Media item tapped: $postId');
        _openPostDetail(postId, userId);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media thumbnail
              // Media thumbnail
              if (mediaUrl.isNotEmpty)
                Image.network(
                  // 👇 Video නම් thumbnail_url, Image නම් media_url
                  (isVideo && (post['thumbnail_url'] ?? '').isNotEmpty)
                      ? post['thumbnail_url']
                      : mediaUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                    );
                  },
                )
              else
                Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.image_not_supported,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),

              // Video play icon (top right corner)
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
                        _formatViewCount(post['viewCount'] ?? 0),
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
            ],
          ),
        ),
      ),
    );
  }
}