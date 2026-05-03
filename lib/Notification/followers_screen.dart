import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../screens/activity_user_profile.dart';

class FollowersScreen extends StatefulWidget {
  const FollowersScreen({super.key});

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String? _currentUserId;
  List<Map<String, dynamic>> _followers = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
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

      debugPrint('📥 Loading real-time followers for user: $_currentUserId');

      _db
          .collection('follows')
          .where('followingId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .listen((snapshot) async {
        debugPrint('🔄 Real-time update: ${snapshot.docs.length} followers');

        List<Map<String, dynamic>> updatedFollowers = [];

        for (var doc in snapshot.docs) {
          final followData = doc.data();
          final followerId = followData['followerId'] ?? '';
          final followerName = followData['followerName'] ?? 'Unknown';
          final timestamp = followData['timestamp'] ?? 0;

          debugPrint('   Loading follower: $followerName ($followerId)');

          final userDoc = await _db.collection('users').doc(followerId).get();

          if (userDoc.exists) {
            final userData = userDoc.data()!;

            final postsSnapshot = await _db
                .collection('media_posts')
                .where('uid', isEqualTo: followerId)
                .where('is_active', isEqualTo: true)
                .get();

            updatedFollowers.add({
              'id': doc.id,
              'userId': followerId,
              'userName': userData['name'] ?? followerName,
              'userAvatar': userData['profile_picture_url'] ?? userData['profileUrl'] ?? '',
              'bio': userData['bio'] ?? 'No bio yet',
              'followersCount': userData['followerCount'] ?? 0,
              'videosCount': postsSnapshot.docs.length,
              'timestamp': timestamp,
              'time': _formatTime(timestamp),
            });
          }
        }

        if (mounted) {
          setState(() {
            _followers = updatedFollowers;
            _isLoading = false;
          });
        }

        debugPrint('✅ Real-time followers updated: ${_followers.length}');
      }, onError: (error) {
        debugPrint('❌ Error in followers stream: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Error loading followers: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return 'Just now';

    final now = DateTime.now();
    final followTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(followTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${(difference.inDays / 7).floor()} weeks ago';
    }
  }

  void _handleUserClick(String userId) {
    debugPrint('🔄 Navigating to user profile: $userId');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityUserProfile(userId: userId),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
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
              child: _followers.isEmpty
                  ? _buildEmptyState()
                  : _buildFollowersList(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF1F1F1F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 50, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              size: 24,
              color: Color(0xFFFFFFFF),
            ),
            padding: const EdgeInsets.all(8),
          ),
          const SizedBox(width: 8),

          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2C2C2C), Color(0xFF333333)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: const [
                Icon(
                  Icons.people,
                  color: Color(0xFFFF3B5C),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'New Followers',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFFFFF),
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
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '${_followers.length} new',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowersList() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadFollowers();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _followers.length,
        itemBuilder: (context, index) {
          return _buildFollowerItem(_followers[index]);
        },
      ),
    );
  }

  Widget _buildFollowerItem(Map<String, dynamic> follower) {
    final userId = follower['userId'] ?? '';
    final userName = follower['userName'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _handleUserClick(userId),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  _buildUserAvatar(follower),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          follower['bio'] ?? 'No bio yet',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 13,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              follower['time'] ?? 'Just now',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  _buildFollowButton(userId, userName),
                ],
              ),

              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      Icons.people,
                      _formatCount(follower['followersCount'] ?? 0),
                      'Followers',
                      const Color(0xFFFF3B5C),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: const Color(0xFF444444),
                    ),
                    _buildStatItem(
                      Icons.video_library,
                      (follower['videosCount'] ?? 0).toString(),
                      'Videos',
                      const Color(0xFF10B981),
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

  Widget _buildUserAvatar(Map<String, dynamic> follower) {
    final userName = follower['userName'] ?? 'U';
    final avatarUrl = follower['userAvatar'] ?? '';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3B5C), Color(0xFFFF3B5C)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: avatarUrl.isNotEmpty
            ? Image.network(
          avatarUrl,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 58,
              height: 58,
              color: const Color(0xFFFF3B5C),
              child: Center(
                child: Text(
                  userName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        )
            : Container(
          width: 58,
          height: 58,
          color: const Color(0xFFFF3B5C),
          child: Center(
            child: Text(
              userName[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowButton(String userId, String username) {
    if (_currentUserId == null || _currentUserId == userId) {
      return const SizedBox.shrink();
    }

    final followDocId = '${_currentUserId}_$userId';

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('follows').doc(followDocId).snapshots(),
      builder: (context, snapshot) {
        bool isFollowing = false;
        String buttonText = 'Follow Back';
        Color backgroundColor = const Color(0xFFFF3B5C);
        Color textColor = Colors.white;

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final followData = snapshot.data!.data() as Map<String, dynamic>?;
          final status = followData?['status'] ?? '';

          if (status == 'active') {
            isFollowing = true;
            buttonText = 'Following';
            backgroundColor = const Color(0xFF333333);
            textColor = const Color(0xFFFFFFFF);
          } else if (status == 'pending') {
            buttonText = 'Requested';
            backgroundColor = const Color(0xFFFFA500);
            textColor = Colors.white;
          }
        }

        return ElevatedButton(
          onPressed: () => _handleFollowToggle(userId, username, isFollowing),
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: textColor,
            elevation: isFollowing ? 0 : 2,
            shadowColor: Colors.black.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFollowing ? Icons.check : Icons.person_add,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleFollowToggle(String targetUserId, String targetUsername, bool isCurrentlyFollowing) async {
    if (_currentUserId == null) return;

    try {
      final followDocId = '${_currentUserId}_$targetUserId';
      final followRef = _db.collection('follows').doc(followDocId);

      if (isCurrentlyFollowing) {
        debugPrint('💔 Unfollowing user: $targetUserId');
        await followRef.delete();

        await _db.collection('users').doc(_currentUserId).update({
          'followingCount': FieldValue.increment(-1),
        });
        await _db.collection('users').doc(targetUserId).update({
          'followerCount': FieldValue.increment(-1),
        });

        debugPrint('✅ Unfollow completed');
      } else {
        debugPrint('💙 Following user: $targetUserId');

        final targetUserDoc = await _db.collection('users').doc(targetUserId).get();
        final isPrivateAccount = targetUserDoc.data()?['private_account'] ?? false;

        final currentUserDoc = await _db.collection('users').doc(_currentUserId).get();
        final currentUsername = currentUserDoc.data()?['name'] ?? 'User';

        final followData = {
          'followerId': _currentUserId,
          'followerName': currentUsername,
          'followingId': targetUserId,
          'followingName': targetUsername,
          'status': isPrivateAccount ? 'pending' : 'active',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        await followRef.set(followData);

        if (!isPrivateAccount) {
          await _db.collection('users').doc(_currentUserId).update({
            'followingCount': FieldValue.increment(1),
          });
          await _db.collection('users').doc(targetUserId).update({
            'followerCount': FieldValue.increment(1),
          });
          debugPrint('✅ Follow completed (Public account)');
        } else {
          debugPrint('⏳ Follow request sent (Private account - pending approval)');

          await _db.collection('users').doc(targetUserId).collection('notifications').add({
            'type': 'follow_request',
            'fromUserId': _currentUserId,
            'fromUserName': currentUsername,
            'toUserId': targetUserId,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'isRead': false,
          });
        }

        _sendFollowNotificationInBackground(targetUserId, targetUsername, isPrivateAccount, currentUsername);
      }
    } catch (e) {
      debugPrint('❌ Error toggling follow: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${isCurrentlyFollowing ? 'unfollow' : 'follow'} user'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendFollowNotificationInBackground(
      String targetUserId,
      String targetUsername,
      bool isPrivate,
      String currentUsername,
      ) {
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
      debugPrint('✅ Background notification sent');
    }).catchError((error) {
      debugPrint('⚠️ Notification failed (non-critical): $error');
    });
  }

  Future<void> _sendFollowNotificationToBackend(
      String targetUserId,
      String targetUsername,
      String currentUsername,
      bool isPrivate,
      ) async {
    try {
      debugPrint('\n🔔 ========== FOLLOW NOTIFICATION ==========');

      const backendUrl = 'https://avishka-tiktok-api.zeabur.app/api/follow-notification';

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fromUserId': _currentUserId,
          'fromUserName': currentUsername,
          'toUserId': targetUserId,
          'toUserName': targetUsername,
          'followStatus': isPrivate ? 'pending' : 'active',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ Notification sent');
      } else {
        debugPrint('⚠️ Backend error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Notification error: $e');
    }
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
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
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.people_outline,
                size: 50,
                color: Color(0xFFFF3B5C),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No new followers yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFFFFF),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'When people follow you,\nthey\'ll appear here',
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