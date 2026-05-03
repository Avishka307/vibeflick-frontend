import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 🔄 Reposts Tab - Display posts that user has reposted
/// Shows reposted content in a grid layout with Firebase integration
class UserTabRepostPage extends StatelessWidget {
  final String? userId;

  const UserTabRepostPage({Key? key, this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Center(
        child: Text(
          'User not found',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reposts')
          .where('userId', isEqualTo: userId)
          .orderBy('repostedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFF3B5C),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final reposts = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1.0,
          ),
          itemCount: reposts.length,
          itemBuilder: (context, index) {
            final repostData = reposts[index].data() as Map<String, dynamic>;
            final originalPostId = repostData['originalPostId'] as String?;

            if (originalPostId == null) return const SizedBox.shrink();

            return _buildRepostGridItem(context, originalPostId);
          },
        );
      },
    );
  }

  /// Build grid item for reposted content
  Widget _buildRepostGridItem(BuildContext context, String postId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('media_posts')
          .doc(postId)
          .get(),
      builder: (context, postSnapshot) {
        if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(
                Icons.broken_image,
                color: Color(0xFF666666),
                size: 32,
              ),
            ),
          );
        }

        final postData = postSnapshot.data!.data() as Map<String, dynamic>;
        final mediaUrl = postData['mediaUrl'] as String?;
        final mediaType = postData['mediaType'] as String? ?? 'image';

        return GestureDetector(
          onTap: () {
            // TODO: Navigate to post details
            debugPrint('🔄 Reposted content tapped: $postId');
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Media content
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: mediaUrl != null && mediaUrl.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: mediaUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFF2C2C2C),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF3B5C),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF2C2C2C),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Color(0xFF666666),
                          size: 32,
                        ),
                      ),
                    ),
                  )
                      : Container(
                    color: const Color(0xFF2C2C2C),
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Color(0xFF666666),
                        size: 32,
                      ),
                    ),
                  ),
                ),

                // Video indicator overlay
                if (mediaType == 'video')
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),

                // Repost indicator (bottom-right corner)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.repeat,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build empty state when no reposts
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.repeat_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No reposts yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reposted content will appear here',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}