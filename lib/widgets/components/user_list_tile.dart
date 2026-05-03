import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UserListTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final String? currentUserId;

  const UserListTile({
    super.key,
    required this.user,
    this.currentUserId,
  });

  Future<void> _toggleFollow(BuildContext context) async {
    if (currentUserId == null) return;

    final targetUserId = user['uid'];
    if (targetUserId == currentUserId) return;

    try {
      final followDocId = '${currentUserId}_$targetUserId';
      final followRef = FirebaseFirestore.instance
          .collection('follows')
          .doc(followDocId);

      final followDoc = await followRef.get();
      final isFollowing = followDoc.exists;

      if (isFollowing) {
        await followRef.delete();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({
          'followingCount': FieldValue.increment(-1),
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUserId)
            .update({
          'followerCount': FieldValue.increment(-1),
        });

        debugPrint('👋 Unfollowed: ${user['name']}');
      } else {
        await followRef.set({
          'followerId': currentUserId,
          'followingId': targetUserId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({
          'followingCount': FieldValue.increment(1),
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUserId)
            .update({
          'followerCount': FieldValue.increment(1),
        });

        debugPrint('❤️ Followed: ${user['name']}');
      }
    } catch (e) {
      debugPrint('❌ Error toggling follow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update follow status'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = user['uid'] == currentUserId;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF0050), Color(0xFFFFB800)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    user['name'][0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user['username']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_rounded,
                          size: 14,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatCount(user['followers'])} followers',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isOwnProfile && currentUserId != null)
                _buildFollowButton(context),
            ],
          ),
          if (user['bio'] != null && (user['bio'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                user['bio'],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.7),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFollowButton(BuildContext context) {
    final followDocId = '${currentUserId}_${user['uid']}';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('follows')
          .doc(followDocId)
          .snapshots(),
      builder: (context, snapshot) {
        bool isFollowing = false;

        if (snapshot.hasData && snapshot.data != null) {
          isFollowing = snapshot.data!.exists;
        }

        return GestureDetector(
          onTap: () => _toggleFollow(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: isFollowing ? const Color(0xFF1E1E1E) : const Color(0xFFFF0050),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isFollowing
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
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
}