import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_vibe_flick/screens/post_detail_page.dart';

class TagNotificationItem {
  final String id;
  final String postCreator;
  final String creatorAvatar;
  final String postDescription;
  final String time;
  final bool isRead;
  final String postId;
  final DateTime timestamp;
  final String? mediaThumbnail;

  TagNotificationItem({
    required this.id,
    required this.postCreator,
    required this.creatorAvatar,
    required this.postDescription,
    required this.time,
    required this.isRead,
    required this.postId,
    required this.timestamp,
    this.mediaThumbnail,
  });

  factory TagNotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp?;
    final dateTime = timestamp?.toDate() ?? DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    String timeAgo = '';
    if (difference.inMinutes < 1) {
      timeAgo = 'just now';
    } else if (difference.inMinutes < 60) {
      timeAgo = '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      timeAgo = '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      timeAgo = '${difference.inDays}d ago';
    } else {
      timeAgo = '${(difference.inDays / 7).floor()}w ago';
    }

    return TagNotificationItem(
      id: doc.id,
      postCreator: data['fromUserName'] ?? 'Unknown',
      creatorAvatar: data['extraData']?['avatarUrl'] ?? '',
      postDescription: data['message'] ?? 'Tagged you in a post',
      time: timeAgo,
      isRead: data['read'] ?? false,
      postId: data['postId'] ?? '',
      timestamp: dateTime,
      mediaThumbnail: data['extraData']?['mediaUrl'] ?? data['extraData']?['mediaThumbnail'],
    );
  }
}

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
  }

  void _handleTagClick(String postId) {
    debugPrint('🏷️ Tag clicked - Opening post: $postId');
    // TODO: Navigate to post detail page
    Navigator.push(
        context,
       MaterialPageRoute(
         builder: (context) => PostDetailPage(postId: postId),
      ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tags',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: currentUser == null
          ? _buildNotLoggedIn()
          : StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .where('type', isEqualTo: 'tag')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF3B5C),
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error loading tags: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final tagDocs = snapshot.data?.docs ?? [];

          if (tagDocs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            itemCount: tagDocs.length,
            itemBuilder: (context, index) {
              final tag = TagNotificationItem.fromFirestore(tagDocs[index]);
              return _buildTagItem(tag);
            },
          );
        },
      ),
    );
  }

  Widget _buildTagItem(TagNotificationItem tag) {
    return InkWell(
      onTap: () => _handleTagClick(tag.postId),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tag.isRead ? Colors.transparent : const Color(0xFF2D2D2D),
          border: const Border(
            bottom: BorderSide(color: Color(0xFF2D2D2D), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Avatar with tag badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: tag.creatorAvatar.isNotEmpty
                      ? Image.network(
                    tag.creatorAvatar,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAvatar(tag.postCreator);
                    },
                  )
                      : _buildDefaultAvatar(tag.postCreator),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF3B5C), Color(0xFFFF1744)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E1E1E), width: 2),
                    ),
                    child: const Text(
                      '🏷️',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          tag.postCreator,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        tag.time,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tag.postCreator} tagged you in a post',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Post Thumbnail
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 50,
                height: 50,
                color: const Color(0xFF2D2D2D),
                child: tag.mediaThumbnail != null && tag.mediaThumbnail!.isNotEmpty
                    ? Image.network(
                  tag.mediaThumbnail!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.image,
                      color: Color(0xFF6B7280),
                      size: 24,
                    );
                  },
                )
                    : const Icon(
                  Icons.image,
                  color: Color(0xFF6B7280),
                  size: 24,
                ),
              ),
            ),

            // Unread indicator
            if (!tag.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3B5C), Color(0xFFFF1744)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B5C),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.local_offer_outlined,
              size: 80,
              color: Color(0xFF4B5563),
            ),
            SizedBox(height: 16),
            Text(
              'No tags yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9CA3AF),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'When someone tags you in a post,\nit will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.login,
              size: 80,
              color: Color(0xFF4B5563),
            ),
            SizedBox(height: 16),
            Text(
              'Please log in',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9CA3AF),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'You need to be logged in to view tags',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}