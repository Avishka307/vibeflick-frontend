import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🆕 Import post detail page
import 'post_detail_page.dart';

class MentionItem {
  final String id;
  final String userName;
  final String userAvatar;
  final String contentType;
  final String contentPreview;
  final String time;
  final bool isRead;
  final String? thumbnailUrl;
  final String? postId; // 🆕 Post ID for navigation

  MentionItem({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.contentType,
    required this.contentPreview,
    required this.time,
    required this.isRead,
    this.thumbnailUrl,
    this.postId, // 🆕
  });

  // 🆕 Factory constructor from Firestore
  factory MentionItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Calculate time ago
    final timestamp = data['timestamp'] as int?;
    String timeAgo = 'Unknown';
    if (timestamp != null) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final difference = DateTime.now().difference(dateTime);

      if (difference.inDays > 0) {
        timeAgo = '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes}m ago';
      } else {
        timeAgo = 'Just now';
      }
    }

    return MentionItem(
      id: doc.id,
      userName: data['fromUserName'] ?? 'Unknown',
      userAvatar: data['avatarUrl'] ?? '',
      contentType: data['type'] ?? 'mention',
      contentPreview: data['message'] ?? data['preview'] ?? 'mentioned you in a post',
      time: timeAgo,
      isRead: data['read'] ?? false,
      thumbnailUrl: data['mediaThumbnail'] ?? data['mediaUrl'],
      postId: data['postId'], // 🆕
    );
  }
}

class MentionsScreen extends StatefulWidget {
  const MentionsScreen({super.key});

  @override
  State<MentionsScreen> createState() => _MentionsScreenState();
}

class _MentionsScreenState extends State<MentionsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _currentUserId;
  List<MentionItem> _mentions = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadMentions();
  }

  // 🔥 LOAD MENTIONS FROM FIRESTORE
  Future<void> _loadMentions() async {
    if (_currentUserId == null) {
      debugPrint('❌ No current user');
      setState(() => _isLoading = false);
      return;
    }

    try {
      debugPrint('📥 Loading mentions for user: $_currentUserId');

      final querySnapshot = await _db
          .collection('users')
          .doc(_currentUserId)
          .collection('notifications')
          .where('type', isEqualTo: 'mention')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final mentions = <MentionItem>[];
      int unread = 0;

      for (var doc in querySnapshot.docs) {
        final mention = MentionItem.fromFirestore(doc);
        mentions.add(mention);

        if (!mention.isRead) {
          unread++;
        }
      }

      debugPrint('✅ Loaded ${mentions.length} mentions (${unread} unread)');

      setState(() {
        _mentions = mentions;
        _unreadCount = unread;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading mentions: $e');
      setState(() => _isLoading = false);
    }
  }

  // 🔥 MARK AS READ
  Future<void> _markAsRead(MentionItem mention) async {
    if (_currentUserId == null || mention.isRead) return;

    try {
      await _db
          .collection('users')
          .doc(_currentUserId)
          .collection('notifications')
          .doc(mention.id)
          .update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        final index = _mentions.indexWhere((m) => m.id == mention.id);
        if (index != -1) {
          _mentions[index] = MentionItem(
            id: mention.id,
            userName: mention.userName,
            userAvatar: mention.userAvatar,
            contentType: mention.contentType,
            contentPreview: mention.contentPreview,
            time: mention.time,
            isRead: true,
            thumbnailUrl: mention.thumbnailUrl,
            postId: mention.postId,
          );
          _unreadCount = _mentions.where((m) => !m.isRead).length;
        }
      });

      debugPrint('✅ Marked as read: ${mention.id}');
    } catch (e) {
      debugPrint('❌ Mark as read error: $e');
    }
  }

  // 🔥 MARK ALL AS READ
  Future<void> _markAllAsRead() async {
    if (_currentUserId == null) return;

    try {
      final batch = _db.batch();

      for (var mention in _mentions) {
        if (!mention.isRead) {
          final docRef = _db
              .collection('users')
              .doc(_currentUserId)
              .collection('notifications')
              .doc(mention.id);

          batch.update(docRef, {
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      setState(() {
        _mentions = _mentions.map((m) => MentionItem(
          id: m.id,
          userName: m.userName,
          userAvatar: m.userAvatar,
          contentType: m.contentType,
          contentPreview: m.contentPreview,
          time: m.time,
          isRead: true,
          thumbnailUrl: m.thumbnailUrl,
          postId: m.postId,
        )).toList();
        _unreadCount = 0;
      });

      debugPrint('✅ Marked all as read');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All mentions marked as read'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('❌ Mark all as read error: $e');
    }
  }

  // 🔥 HANDLE TAP (Navigate to Post)
  void _handleMentionTap(MentionItem mention) {
    debugPrint('👆 Tapped mention: ${mention.id}');

    // Mark as read
    if (!mention.isRead) {
      _markAsRead(mention);
    }

    // Navigate to post if postId exists
    if (mention.postId != null && mention.postId!.isNotEmpty) {
      debugPrint('🔄 Navigating to post: ${mention.postId}');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailPage(
            postId: mention.postId!,
          ),
        ),
      );
    } else {
      debugPrint('⚠️ No postId available');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post not available'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mentions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_unreadCount > 0)
              Text(
                '$_unreadCount unread',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: Color(0xFFFF3B5C),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF3B5C),
          strokeWidth: 2,
        ),
      )
          : _mentions.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _loadMentions,
        backgroundColor: const Color(0xFF1E1E1E),
        color: const Color(0xFFFF3B5C),
        child: ListView.builder(
          itemCount: _mentions.length,
          itemBuilder: (context, index) {
            return _buildMentionItem(_mentions[index]);
          },
        ),
      ),
    );
  }

  Widget _buildMentionItem(MentionItem mention) {
    return InkWell(
      onTap: () => _handleMentionTap(mention),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: mention.isRead ? const Color(0xFF1E1E1E) : const Color(0xFF2D2D2D),
          border: const Border(
            bottom: BorderSide(color: Color(0xFF2D2D2D), width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Avatar with @ badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: mention.userAvatar.isNotEmpty
                      ? Image.network(
                    mention.userAvatar,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAvatar(mention.userName);
                    },
                  )
                      : _buildDefaultAvatar(mention.userName),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E1E1E), width: 2),
                    ),
                    child: const Icon(
                      Icons.alternate_email,
                      size: 12,
                      color: Colors.white,
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
                          mention.userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        mention.time,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mention.contentPreview,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (mention.thumbnailUrl != null && mention.thumbnailUrl!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        mention.thumbnailUrl!,
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 120,
                            color: const Color(0xFF2D2D2D),
                            child: const Icon(
                              Icons.image,
                              size: 40,
                              color: Color(0xFF6B7280),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3D3D3D),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.alternate_email,
                              size: 14,
                              color: Color(0xFF3B82F6),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'MENTION',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (!mention.isRead)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String username) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFF3B82F6),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
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
              Icons.alternate_email,
              size: 80,
              color: Color(0xFF4B5563),
            ),
            SizedBox(height: 24),
            Text(
              'No mentions yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'When someone mentions you in a post, it will appear here',
              style: TextStyle(
                fontSize: 15,
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