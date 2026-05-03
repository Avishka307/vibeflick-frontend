import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart'; // ✅ Added for firstWhereOrNull

class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  // 🔥 Backend URL - ඔබේ server IP එක මෙතන
  static const String BACKEND_URL = "https://avishka-tiktok-api.zeabur.app";

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String? _currentUserId;
  List<Map<String, dynamic>> _likeNotifications = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadLikeNotifications();
  }

  // ✅ FIXED: Load like notifications from main 'likes' collection
  Future<void> _loadLikeNotifications() async {
    if (_currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      debugPrint('📥 Loading like notifications for user: $_currentUserId');

      // ✅ STEP 1: Get user's posts
      final userPostsSnapshot = await _db
          .collection('media_posts')
          .where('uid', isEqualTo: _currentUserId)
          .where('is_active', isEqualTo: true)
          .get();

      debugPrint('📊 Found ${userPostsSnapshot.docs.length} user posts');

      if (userPostsSnapshot.docs.isEmpty) {
        setState(() {
          _likeNotifications = [];
          _isLoading = false;
        });
        return;
      }

      // ✅ STEP 2: Get post IDs
      final postIds = userPostsSnapshot.docs.map((doc) => doc.id).toList();
      debugPrint('📋 Post IDs: $postIds');

      // ✅ STEP 3: Query main 'likes' collection for these posts
      List<Map<String, dynamic>> allLikes = [];

      // Process posts in chunks of 10 (Firestore limitation)
      for (int i = 0; i < postIds.length; i += 10) {
        final chunk = postIds.skip(i).take(10).toList();

        debugPrint('🔍 Querying likes for chunk: $chunk');

        final likesSnapshot = await _db
            .collection('likes')
            .where('postId', whereIn: chunk)
            .orderBy('timestamp', descending: true)
            .limit(50)
            .get();

        debugPrint('   ✅ Found ${likesSnapshot.docs.length} likes in this chunk');

        for (var likeDoc in likesSnapshot.docs) {
          final likeData = likeDoc.data();
          final postId = likeData['postId'] ?? '';
          final likerId = likeData['uid'] ?? '';

          // Skip if liker is the current user (self-like)
          if (likerId == _currentUserId) continue;

          // ✅ FIXED: Use firstWhereOrNull instead of firstWhere with orElse
          final postDoc = userPostsSnapshot.docs.firstWhereOrNull((doc) => doc.id == postId);

          // ✅ Handle null case properly
          if (postDoc == null) {
            debugPrint('⚠️ Post not found for postId: $postId');
            continue;
          }

          final postData = postDoc.data();

          // ✅ Get liker's profile info
          String likerName = likeData['username'] ?? 'Unknown User';
          String? likerAvatar;

          try {
            final likerDoc = await _db.collection('users').doc(likerId).get();
            if (likerDoc.exists) {
              final likerData = likerDoc.data();
              likerName = likerData?['name'] ?? likerData?['username'] ?? 'Unknown User';
              // ✅ හදන්න - profileImageUrl (ඔබේ Firestore document එකේ actual field)
              likerAvatar = likerData?['profileImageUrl'] ??
                  likerData?['profile_picture_url'] ??
                  likerData?['profile_url'] ??
                  likerData?['profileUrl'];
            }
          } catch (e) {
            debugPrint('⚠️ Failed to load liker profile: $e');
          }

          allLikes.add({
            'id': likeDoc.id,
            'userId': likerId,
            'userName': likerName,
            'userAvatar': likerAvatar ?? '',
            'mediaId': postId,
            'mediaThumbnail': postData['thumbnail_url'] ?? postData['media_url'] ?? '',
            'mediaType': postData['type'] ?? 'image',
            'time': _getTimeAgo(likeData['timestamp']),
            'timestamp': likeData['timestamp'],
            'isOnline': false,
          });
        }
      }

      // ✅ Sort by most recent
      allLikes.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _likeNotifications = allLikes;
        _isLoading = false;
      });

      debugPrint('✅ Loaded ${_likeNotifications.length} like notifications');

    } catch (e, stackTrace) {
      debugPrint('❌ Error loading like notifications: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      setState(() => _isLoading = false);
    }
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
  }

  // 🆕 Backend API වලට like notification යවන method
  Future<void> _sendLikeNotificationToBackend(String postId) async {
    try {
      debugPrint('\n🔔 ========== SENDING LIKE NOTIFICATION TO BACKEND ==========');

      // Post එකේ owner details ගන්න
      final postDoc = await _db.collection('media_posts').doc(postId).get();

      if (!postDoc.exists) {
        debugPrint('❌ Post not found: $postId');
        return;
      }

      final postData = postDoc.data()!;
      final postOwnerId = postData['uid'];
      final postOwnerUsername = postData['username'];

      // තමන්ගේ post එකනම් notification එක යවන්න එපා
      if (postOwnerId == _currentUserId) {
        debugPrint('⏭️ Skipping self-notification');
        return;
      }

      // Current user details ගන්න
      final currentUserDoc = await _db.collection('users').doc(_currentUserId).get();
      final currentUsername = currentUserDoc.data()?['name'] ?? 'User';

      debugPrint('📤 Sending like notification:');
      debugPrint('   From: $currentUsername ($_currentUserId)');
      debugPrint('   To: $postOwnerUsername ($postOwnerId)');
      debugPrint('   Post: $postId');

      // 🔥 Backend API call එක
      final url = Uri.parse('$BACKEND_URL/api/posts/like');
      debugPrint('🌐 Backend URL: $url');

      final requestBody = {
        'postId': postId,
        'userUid': _currentUserId,
        'username': currentUsername,
        'postOwnerId': postOwnerId,
        'postOwnerUsername': postOwnerUsername,
      };

      debugPrint('📦 Request body: $requestBody');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏰ Request timeout');
          throw Exception('Request timeout');
        },
      );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('✅ Like notification sent successfully to backend!');
        debugPrint('==========================================\n');
      } else {
        debugPrint('⚠️ Backend returned error: ${response.statusCode}');
        debugPrint('   Body: ${response.body}');
        debugPrint('==========================================\n');
      }
    } catch (e) {
      debugPrint('❌ Error sending like notification to backend: $e');
      debugPrint('==========================================\n');
    }
  }

  void _handleUserClick(String userId) {
    debugPrint('👤 Navigate to user profile: $userId');
    // TODO: Navigate to user profile
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (context) => ActivityUserProfile(userId: userId),
    // ));
  }

  void _handleMediaClick(String mediaId) {
    debugPrint('🎬 Navigate to media: $mediaId');
    // TODO: Navigate to media detail
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          _buildHeader(),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF3B5C),
                ),
              ),
            )
          else
            Expanded(
              child: _likeNotifications.isEmpty
                  ? _buildEmptyState()
                  : _buildLikesList(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 50, 16, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              size: 24,
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(8),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: const [
                Icon(
                  Icons.favorite,
                  color: Color(0xFFFF3B5C),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Likes',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B5C),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF3B5C).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              '${_likeNotifications.length}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikesList() {
    return RefreshIndicator(
      color: const Color(0xFFFF3B5C),
      backgroundColor: const Color(0xFF2C2C2C),
      onRefresh: _loadLikeNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _likeNotifications.length,
        itemBuilder: (context, index) {
          return _buildLikeItem(_likeNotifications[index]);
        },
      ),
    );
  }

  Widget _buildLikeItem(Map<String, dynamic> like) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _handleMediaClick(like['mediaId']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // User Avatar
              GestureDetector(
                onTap: () => _handleUserClick(like['userId']),
                child: Stack(
                  children: [
                    _buildUserAvatar(like),
                    if (like['isOnline'])
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: const Color(0xFF1F1F1F), width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      like['userName'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 16,
                          color: Color(0xFFFF3B5C),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'liked your',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          like['mediaType'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF3B5C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: Color(0xFF666666),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          like['time'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Media Thumbnail
              _buildMediaThumbnail(like),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic> like) {
    final avatarUrl = like['userAvatar'] as String;
    final userName = like['userName'] as String;

    if (avatarUrl.isNotEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE53935), width: 2),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => _buildAvatarPlaceholder(userName),
            errorWidget: (_, __, ___) => _buildAvatarPlaceholder(userName),
          ),
        ),
      );
    }

    return _buildAvatarPlaceholder(userName);
  }

  Widget _buildAvatarPlaceholder(String name) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFFE53935),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
    ];
    final hash = name.hashCode.abs();
    final bgColor = colors[hash % colors.length];

    String initials = 'U';
    if (name.isNotEmpty) {
      final words = name.trim().split(RegExp(r'\s+'));
      if (words.length >= 2) {
        initials = (words[0][0] + words[words.length - 1][0]).toUpperCase();
      } else {
        initials = name.length >= 2
            ? name.substring(0, 2).toUpperCase()
            : name[0].toUpperCase();
      }
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE53935), width: 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaThumbnail(Map<String, dynamic> like) {
    final thumbnailUrl = like['mediaThumbnail'] as String;
    final mediaType = like['mediaType'] as String;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: thumbnailUrl.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: thumbnailUrl,
            width: 70,
            height: 70,
            fit: BoxFit.cover,
            placeholder: (_, __) => _buildThumbnailPlaceholder(),
            errorWidget: (_, __, ___) => _buildThumbnailPlaceholder(),
          )
              : _buildThumbnailPlaceholder(),
        ),
        if (mediaType == 'video')
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_filled,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildThumbnailPlaceholder() {
    return Container(
      width: 70,
      height: 70,
      color: const Color(0xFF2C2C2C),
      child: const Icon(
        Icons.image,
        size: 30,
        color: Color(0xFF666666),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.favorite_border,
                size: 50,
                color: Color(0xFFFF3B5C),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No likes yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'When people like your posts,\nthey\'ll appear here',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}