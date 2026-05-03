import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ADD with other imports:
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Comment/comment_bottom_sheet.dart';

// 🆕 Backend Configuration
class BackendConfig {
  static const String BACKEND_URL = "https://avishka-tiktok-api.zeabur.app";
}

// Models
class CommentNotification {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String commentText;
  final String mediaId;
  final String mediaThumbnail;
  final String mediaType;
  final String time;
  final int likes;
  final bool isOnline;
  final bool isReplied;
  final DateTime timestamp;

  CommentNotification({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.commentText,
    required this.mediaId,
    required this.mediaThumbnail,
    required this.mediaType,
    required this.time,
    required this.likes,
    required this.isOnline,
    required this.isReplied,
    required this.timestamp,
  });
}

class CommentsScreen extends StatefulWidget {
  const CommentsScreen({super.key});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  final Set<String> _likedComments = {};
  List<CommentNotification> _comments = [];

  Stream<QuerySnapshot>? _notificationStream;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadCommentNotifications();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadCommentNotifications() async {
    if (_currentUserId == null) {
      debugPrint('⚠️ Cannot load notifications - user not logged in');
      setState(() => _isLoading = false);
      return;
    }

    try {
      debugPrint('📥 Loading comment notifications for user: $_currentUserId');

      _notificationStream = _db
          .collection('users')
          .doc(_currentUserId)
          .collection('notifications')
          .where('type', isEqualTo: 'comment')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots();

      _notificationStream!.listen((snapshot) {
        debugPrint('📡 Received ${snapshot.docs.length} comment notifications');

        List<CommentNotification> loadedComments = [];

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;

          debugPrint('💬 Processing notification:');
          debugPrint('   ID: ${doc.id}');
          debugPrint('   From: ${data['fromUserName']}');
          debugPrint('   Comment: ${data['commentText']}');
          debugPrint('   Post ID: ${data['postId']}');
          debugPrint('   Time: ${data['timestamp']}');

          loadedComments.add(CommentNotification(
            id: doc.id,
            userId: data['fromUserId'] ?? '',
            userName: data['fromUserName'] ?? 'Unknown',
            userAvatar: data['avatarUrl'] ?? '',
            commentText: data['commentText'] ?? data['preview'] ?? data['message'] ?? '',
            mediaId: data['postId'] ?? '',
            mediaThumbnail: data['mediaThumbnail'] ?? '',
            mediaType: data['mediaType'] ?? data['type'] ?? 'image',
            time: _formatNotificationTime(data['timestamp']),
            likes: 0,
            isOnline: true,
            isReplied: false,
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ));
        }

        setState(() {
          _comments = loadedComments;
          _isLoading = false;
        });

        debugPrint('✅ Loaded ${_comments.length} comment notifications');
      }, onError: (error) {
        debugPrint('❌ Error listening to notifications: $error');
        setState(() => _isLoading = false);
      });

    } catch (e) {
      debugPrint('❌ Error loading comment notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatNotificationTime(dynamic timestamp) {
    if (timestamp == null) return 'just now';

    DateTime time;
    try {
      if (timestamp is Timestamp) {
        time = timestamp.toDate();
      } else if (timestamp is int) {
        time = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        time = DateTime.parse(timestamp);
      } else {
        return 'just now';
      }

      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inDays > 7) {
        return '${difference.inDays ~/ 7}w ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'just now';
      }
    } catch (e) {
      debugPrint('⚠️ Error formatting time: $e');
      return 'just now';
    }
  }

  // 1️⃣ LIKE - Firestore save සමඟ
  void _handleCommentLike(String commentId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() {
      if (_likedComments.contains(commentId)) {
        _likedComments.remove(commentId);
      } else {
        _likedComments.add(commentId);
      }
    });

    // notification document එකෙන් postId ගන්න
    final comment = _comments.firstWhere((c) => c.id == commentId);
    final postId = comment.mediaId;
    if (postId.isEmpty) return;

    final isNowLiked = _likedComments.contains(commentId);
    final commentRef = FirebaseFirestore.instance
        .collection('media_posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    try {
      if (isNowLiked) {
        await commentRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([currentUserId]),
        });
      } else {
        await commentRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([currentUserId]),
        });
      }
      debugPrint('${isNowLiked ? "❤️" : "💔"} Like saved for comment: $commentId');
    } catch (e) {
      // revert on error
      setState(() {
        if (isNowLiked) {
          _likedComments.remove(commentId);
        } else {
          _likedComments.add(commentId);
        }
      });
      debugPrint('❌ Like save failed: $e');
    }
  }

// 2️⃣ REPLY - CommentBottomSheet open කරයි
  void _handleReply(String commentId, String userName) async {
    final comment = _comments.firstWhere((c) => c.id == commentId);
    final postId = comment.mediaId;
    if (postId.isEmpty) return;

    // ✅ allowComment check
    try {
      final postDoc = await _db.collection('media_posts').doc(postId).get();
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        final allowComment = data['allowComment'] as bool? ?? true;
        if (!allowComment) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comments are disabled for this post'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('❌ allowComment check failed: $e');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentBottomSheet(
        postId: postId,
        postOwnerId: '',
        initialCommentCount: 0,
      ),
    );
  }
// ════════════════════════════════════════════════════════════════════
// ADD AFTER: void _handleReply(String commentId, String userName) async { ... }
// ════════════════════════════════════════════════════════════════════

  // ── Comment Report Bottom Sheet ───────────────────────────────────
  void _showCommentReportBottomSheet(CommentNotification comment) {
    String? selectedReason;

    const reportReasons = [
      'Spam or Misleading',
      'Hate Speech or Harassment',
      'Violence or Dangerous Content',
      'Nudity or Sexual Content',
      'False Information',
      'Something Else',
    ];

    showModalBottomSheet(
      context          : context,
      isScrollControlled: true,
      backgroundColor  : const Color(0xFF1E1E1E),
      shape            : const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Report Comment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Divider(color: Color(0xFF2C2C2C), height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(
                      'Why are you reporting @${comment.userName}\'s comment?',
                      style: const TextStyle(
                        color  : Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  ...reportReasons.map((reason) {
                    return RadioListTile<String>(
                      value      : reason,
                      groupValue : selectedReason,
                      onChanged  : (val) =>
                          setModalState(() => selectedReason = val),
                      title: Text(
                        reason,
                        style: const TextStyle(
                          color   : Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      activeColor: const Color(0xFFFF3B5C),
                      tileColor  : Colors.transparent,
                    );
                  }),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedReason == null
                            ? null
                            : () async {
                          Navigator.pop(ctx);
                          await _submitCommentReport(
                            comment: comment,
                            reason : selectedReason!,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor        : const Color(0xFFFF3B5C),
                          disabledBackgroundColor: const Color(0xFF3A3A3A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Submit Report',
                          style: TextStyle(
                            color     : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize  : 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Submit Comment Report ─────────────────────────────────────────
  Future<void> _submitCommentReport({
    required CommentNotification comment,
    required String reason,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    const highRiskReasons = {
      'Nudity or Sexual Content',
      'Violence or Dangerous Content',
    };
    final isHighRisk  = highRiskReasons.contains(reason);
    final timestamp   = DateTime.now().millisecondsSinceEpoch;

    try {
      // ── Duplicate check ──────────────────────────────────────────
      final existing = await _db
          .collection('reports')
          .where('type',              isEqualTo: 'comment')
          .where('commentId',         isEqualTo: comment.id)
          .where('reportedByUserId',  isEqualTo: currentUserId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content        : Text('You have already reported this comment.'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
        return;
      }

      // ── Save report ───────────────────────────────────────────────
      await _db.collection('reports').add({
        'type'                : 'comment',
        'postId'              : comment.mediaId,
        'commentId'           : comment.id,
        'commentText'         : comment.commentText,
        'commentOwnerId'      : comment.userId,
        'commentOwnerUsername': comment.userName,
        'reportedByUserId'    : currentUserId,
        'reason'              : reason,
        'originalReason'      : reason,
        'timestamp'           : timestamp,
        'status'              : 'pending',
        'isHighRisk'          : isHighRisk,
      });

      // ── Shadow flag ───────────────────────────────────────────────
      if (comment.mediaId.isNotEmpty && comment.id.isNotEmpty) {
        await _db
            .collection('media_posts')
            .doc(comment.mediaId)
            .collection('comments')
            .doc(comment.id)
            .update({
          'shadow_reported_by': FieldValue.arrayUnion([currentUserId]),
        });
      }

      // ── Telegram Notification ─────────────────────────────────────
      await _sendCommentReportToTelegram(
        comment   : comment,
        reason    : reason,
        isHighRisk: isHighRisk,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content        : Text('Comment reported. We will review within 24 hours.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );

    } catch (e) {
      debugPrint('❌ Comment report error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content        : Text('Failed to submit report. Please try again.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  // ── Telegram: Comment Report ──────────────────────────────────────
  Future<void> _sendCommentReportToTelegram({
    required CommentNotification comment,
    required String reason,
    required bool   isHighRisk,
  }) async {
    try {
      const telegramBotToken = '8635340129:AAFpYrTjtM1osB030tm7fs8szGhjXLvBIak';
      const telegramChatId   = '5484667748';

      final riskLabel  = isHighRisk ? '🔴 HIGH RISK' : '🟡 General';
      final reviewLink = 'https://console.firebase.google.com/project/vibeflick-5fe5c/firestore';
      final preview    = comment.commentText.length > 120
          ? comment.commentText.substring(0, 120) + '...'
          : comment.commentText;

      final message =
          '🚨 VibeFlick — Comment Report\n\n'
          '$riskLabel\n'
          '💬 Reason: $reason\n'
          '👤 Comment By: @${comment.userName}\n'
          '📝 Comment: $preview\n'
          '🆔 Post ID: ${comment.mediaId}\n'
          '🆔 Comment ID: ${comment.id}\n'
          '🕐 Time: ${DateTime.now().toLocal()}\n\n'
          '🛡️ Firebase: $reviewLink';

      await http.post(
        Uri.parse('https://api.telegram.org/bot$telegramBotToken/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': telegramChatId,
          'text'   : message,
        }),
      );

      debugPrint('📨 Telegram (comment report) sent');
    } catch (e) {
      debugPrint('⚠️ Telegram comment report notification failed: $e');
    }
  }

// ════════════════════════════════════════════════════════════════════
// END ADD — comments_screen.dart
// ════════════════════════════════════════════════════════════════════
// 3️⃣ THUMBNAIL - Firestore post document එකෙන් thumbnail load කරයි
  Future<String> _getMediaThumbnail(String postId) async {
    if (postId.isEmpty) return '';
    try {
      final doc = await _db.collection('media_posts').doc(postId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['thumbnail_url'] as String? ?? // ✅ ඔබේ field name එක මෙයයි
            data['thumbnailUrl'] as String? ??
            data['imageUrl'] as String? ??
            data['mediaUrl'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('❌ Failed to get thumbnail for $postId: $e');
    }
    return '';
  }

  void _handleUserClick(String userId) {
    print('User profile opened: $userId');
  }

  void _handleMediaClick(String mediaId) {
    print('Media opened: $mediaId');
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
              child: _comments.isEmpty
                  ? _buildEmptyState()
                  : _buildCommentsList(),
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
            color: Colors.black.withOpacity(0.3),
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
                  Icons.chat_bubble,
                  color: Color(0xFFFF3B5C),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Comments',
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
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '${_comments.length} new',
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

  Widget _buildCommentsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        return _buildCommentItem(_comments[index]);
      },
    );
  }

  Widget _buildCommentItem(CommentNotification comment) {
    final isLiked = _likedComments.contains(comment.id);
    final displayLikes = comment.likes + (isLiked ? 1 : 0);

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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _handleUserClick(comment.userId),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: comment.userAvatar.isNotEmpty
                            ? Image.network(
                          comment.userAvatar,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3A3A3A),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Center(
                                child: Text(
                                  comment.userName[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFAAAAAA),
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                            : Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A3A3A),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: Text(
                              comment.userName.isNotEmpty
                                  ? comment.userName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFAAAAAA),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (comment.isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: const Color(0xFF2A2A2A), width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              comment.userName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              comment.time,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        comment.commentText,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFFD1D5DB),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (comment.mediaId.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2A3A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                comment.mediaType == 'video'
                                    ? Icons.video_library
                                    : Icons.image,
                                size: 14,
                                color: const Color(0xFFFF3B5C),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Post: ${comment.mediaId.substring(0, 8)}...',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFFF3B5C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                // thumbnail widget — FutureBuilder සමඟ
                GestureDetector(
                  onTap: () => _handleMediaClick(comment.mediaId),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: comment.mediaThumbnail.isNotEmpty
                            ? Image.network(
                          comment.mediaThumbnail,
                          width: 60, height: 60, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbnailFallback(),
                        )
                            : FutureBuilder<String>(
                          future: _getMediaThumbnail(comment.mediaId),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                              return Image.network(
                                snapshot.data!,
                                width: 60, height: 60, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _thumbnailFallback(),
                              );
                            }
                            return _thumbnailFallback();
                          },
                        ),
                      ),
                      if (comment.mediaType == 'video')
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(Icons.play_circle_filled, color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Row(
                    children: [
                      _buildActionButton(
                        icon: isLiked ? Icons.favorite : Icons.favorite_border,
                        label: displayLikes > 0 ? '$displayLikes' : 'Like',
                        color: isLiked
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF9CA3AF),
                        onTap: () => _handleCommentLike(comment.id),
                      ),
                      const SizedBox(width: 12),

                      _buildActionButton(
                        icon: Icons.reply,
                        label: 'Reply',
                        color: comment.isReplied
                            ? const Color(0xFFFF3B5C)
                            : const Color(0xFF9CA3AF),
                        onTap: () =>
                            _handleReply(comment.id, comment.userName),
                      ),
                      // ✅ ADD THIS ↓↓↓
                      const SizedBox(width: 12),
                      _buildActionButton(
                        icon  : Icons.flag_outlined,
                        label : 'Report',
                        color : const Color(0xFF6B7280),
                        onTap : () => _showCommentReportBottomSheet(comment),
                      ),
                      if (comment.isReplied) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A3A2A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Replied',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF3B5C),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
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
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 50,
                color: Color(0xFFFF3B5C),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No comments yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFFFFF),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'When people comment on your posts,\nthey\'ll appear here',
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

Widget _thumbnailFallback() {
  return Container(
    width: 60, height: 60,
    color: const Color(0xFF3A3A3A),
    child: const Icon(Icons.image, size: 26, color: Color(0xFF6B7280)),
  );
}