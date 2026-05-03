import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserTabLikes extends StatelessWidget {
  final String? userId;

  const UserTabLikes({Key? key, this.userId}) : super(key: key);

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
          .collection('likes')
          .where('userId', isEqualTo: userId)
          .orderBy('likedAt', descending: true)
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_outline,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No liked posts yet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        final likedPosts = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: likedPosts.length,
          itemBuilder: (context, index) {
            final likeData = likedPosts[index].data() as Map<String, dynamic>;
            final postId = likeData['postId'] as String?;

            if (postId == null) return const SizedBox.shrink();

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('media_posts')
                  .doc(postId)
                  .get(),
              builder: (context, postSnapshot) {
                if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
                  return Container(
                    color: const Color(0xFF2C2C2C),
                    child: const Icon(
                      Icons.broken_image,
                      color: Color(0xFF666666),
                    ),
                  );
                }

                final postData = postSnapshot.data!.data() as Map<String, dynamic>;
                final mediaUrl = postData['mediaUrl'] as String?;

                return GestureDetector(
                  onTap: () {
                    // Open post details
                    debugPrint('Post tapped: $postId');
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
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
                          child: const Icon(
                            Icons.broken_image,
                            color: Color(0xFF666666),
                          ),
                        ),
                      )
                          : Container(
                        color: const Color(0xFF2C2C2C),
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}