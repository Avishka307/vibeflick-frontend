import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ============================================================
//  thought_comments_screen.dart
//  Thread / Comments — Real Firestore backend integration
//  Collection: text_posts/{postId}/comments
// ============================================================

const String _kBaseUrl = 'https://avishka-tiktok-api.zeabur.app';

// ── Data models ──────────────────────────────────────────────

class ThoughtPost {
  final String id;
  final String? username;
  final String? avatarUrl;
  final String content;
  final DateTime createdAt;
  final bool isAnonymous;

  const ThoughtPost({
    required this.id,
    this.username,
    this.avatarUrl,
    required this.content,
    required this.createdAt,
    this.isAnonymous = false,
  });
}

class Comment {
  final String id;
  final String? username;
  final String? avatarUrl;
  final String content;
  final DateTime createdAt;
  final bool isAnonymous;
  final bool isAuthor;
  final String? parentId;
  int likeCount;
  bool isLikedByMe;
  List<Comment> replies;
  bool showAllReplies;

  Comment({
    required this.id,
    this.username,
    this.avatarUrl,
    required this.content,
    required this.createdAt,
    this.isAnonymous = false,
    this.isAuthor = false,
    this.parentId,
    this.likeCount = 0,
    this.isLikedByMe = false,
    this.replies = const [],
    this.showAllReplies = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['commentId'] as String? ?? json['id'] as String? ?? '',
    username:
    json['isAnonymous'] == true ? null : json['username'] as String?,
    avatarUrl:
    json['isAnonymous'] == true ? null : json['avatarUrl'] as String?,
    content: json['comment'] as String? ?? '',
    createdAt: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
        : DateTime.now(),
    isAnonymous: json['isAnonymous'] as bool? ?? false,
    isAuthor: json['isAuthor'] as bool? ?? false,
    parentId: json['parentId'] as String?,
    likeCount: (json['likes'] as num?)?.toInt() ?? 0,
  );
}

// ── Screen ────────────────────────────────────────────────────

class ThoughtCommentsScreen extends StatefulWidget {
  final ThoughtPost post;
  final String currentUserId;
  final String currentUsername;
  final String? currentAvatarUrl;

  const ThoughtCommentsScreen({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.currentUsername,
    this.currentAvatarUrl,
  });

  @override
  State<ThoughtCommentsScreen> createState() => _ThoughtCommentsScreenState();
}

class _ThoughtCommentsScreenState extends State<ThoughtCommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String? _replyingToId;
  String? _replyingToUsername;

  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── API Calls ─────────────────────────────────────────────

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(
          '$_kBaseUrl/api/text-posts/${widget.post.id}/comments');
      final response =
      await http.get(uri).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final rawList = body['data'] as List<dynamic>? ?? [];

        final allComments = rawList
            .map((e) => Comment.fromJson(e as Map<String, dynamic>))
            .toList();

        // Build tree: top-level vs replies
        final topLevel = <Comment>[];
        final repliesMap = <String, List<Comment>>{};

        for (final c in allComments) {
          if (c.parentId == null || c.parentId == widget.post.id) {
            topLevel.add(c);
          } else {
            repliesMap.putIfAbsent(c.parentId!, () => []).add(c);
          }
        }

        for (final c in topLevel) {
          c.replies = List<Comment>.from(repliesMap[c.id] ?? []);
        }

        setState(() {
          _comments = topLevel;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              body['message'] as String? ?? 'Failed to load comments';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please try again.';
        _isLoading = false;
      });
      debugPrint('❌ Load comments error: $e');
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final uri = Uri.parse(
          '$_kBaseUrl/api/text-posts/${widget.post.id}/comments');

      final payload = <String, dynamic>{
        'userId': widget.currentUserId,
        'username': widget.currentUsername,
        'avatarUrl': widget.currentAvatarUrl ?? '',
        'comment': text,
        'isAnonymous': false,
        if (_replyingToId != null) 'parentId': _replyingToId,
      };

      final response = await http
          .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201 && body['success'] == true) {
        final newComment = Comment(
          id: body['data']?['commentId'] as String? ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          username: widget.currentUsername,
          avatarUrl: widget.currentAvatarUrl,
          content: text,
          createdAt: DateTime.now(),
          parentId: _replyingToId,
        );

        setState(() {
          if (_replyingToId != null) {
            for (final c in _comments) {
              if (c.id == _replyingToId) {
                c.replies = [...c.replies, newComment];
                break;
              }
            }
          } else {
            _comments.add(newComment);
          }
          _replyingToId = null;
          _replyingToUsername = null;
        });

        _commentController.clear();
        _focusNode.unfocus();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        _showSnack(body['message'] as String? ?? 'Failed to post comment');
      }
    } catch (e) {
      _showSnack('Network error. Please try again.');
      debugPrint('❌ Post comment error: $e');
    }

    setState(() => _isSending = false);
  }

  Future<void> _toggleLike(Comment comment) async {
    setState(() {
      comment.isLikedByMe = !comment.isLikedByMe;
      comment.likeCount += comment.isLikedByMe ? 1 : -1;
    });

    try {
      final uri = Uri.parse(
          '$_kBaseUrl/api/text-posts/${widget.post.id}/comments/${comment.id}/like');
      await http
          .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': widget.currentUserId}),
      )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      setState(() {
        comment.isLikedByMe = !comment.isLikedByMe;
        comment.likeCount += comment.isLikedByMe ? 1 : -1;
      });
      debugPrint('❌ Like comment error: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Helpers ───────────────────────────────────────────────

  String _formatTimestamp(DateTime dt) {
    final hour =
    dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    const months = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '$hour:$min $period · ${months[dt.month]} ${dt.day}, ${dt.year}';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _startReply(String commentId, String? username) {
    setState(() {
      _replyingToId = commentId;
      _replyingToUsername = username ?? 'Anonymous';
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToUsername = null;
    });
    _focusNode.unfocus();
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D0D1A),
                  Color(0xFF1A1030),
                  Color(0xFF0D1A2A)
                ],
              ),
            ),
          ),
          Column(
            children: [
              _buildGlassHeader(context),
              Expanded(
                child: _isLoading
                    ? const Center(
                    child: CircularProgressIndicator(
                        color: Colors.purpleAccent))
                    : _errorMessage != null
                    ? _buildErrorView()
                    : CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                        child: _buildParentPost()),
                    SliverToBoxAdapter(
                        child: _buildThreadDivider()),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (ctx, i) =>
                            _buildTopLevelComment(_comments[i]),
                        childCount: _comments.length,
                      ),
                    ),
                    if (_comments.isEmpty)
                      SliverToBoxAdapter(
                          child: _buildEmptyState()),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: 120)),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStickyInput(),
          ),
        ],
      ),
    );
  }

  // ── Glassmorphism Header ──────────────────────────────────

  Widget _buildGlassHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Nearby Comment',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadComments,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.white70, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Parent post (Focus mode) ──────────────────────────────

  Widget _buildParentPost() {
    final post = widget.post;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(
                post.isAnonymous ? null : post.avatarUrl,
                post.isAnonymous ? null : post.username,
                radius: 22,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.isAnonymous
                        ? 'Anonymous'
                        : (post.username ?? 'Unknown'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (post.isAnonymous)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('👤 Anonymous post',
                          style: TextStyle(
                              color: Colors.white60, fontSize: 10)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            post.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.6,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _formatTimestamp(post.createdAt),
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildThreadDivider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child:
    Divider(color: Colors.white.withOpacity(0.1), height: 1),
  );

  // ── States ────────────────────────────────────────────────

  Widget _buildEmptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              color: Colors.white.withOpacity(0.2), size: 48),
          const SizedBox(height: 12),
          Text('No comments yet.\nBe the first to reply!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 14,
                  height: 1.5)),
        ],
      ),
    ),
  );

  Widget _buildErrorView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline,
            color: Colors.white38, size: 48),
        const SizedBox(height: 12),
        Text(_errorMessage ?? 'Something went wrong',
            style: const TextStyle(
                color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent.withOpacity(0.2),
              foregroundColor: Colors.white),
          onPressed: _loadComments,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
      ],
    ),
  );

  // ── Comment cards ─────────────────────────────────────────

  Widget _buildTopLevelComment(Comment comment) {
    final visibleReplies = comment.showAllReplies
        ? comment.replies
        : comment.replies.take(2).toList();
    final hiddenCount = comment.replies.length - visibleReplies.length;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  _buildAvatar(
                    comment.isAnonymous ? null : comment.avatarUrl,
                    comment.isAnonymous ? null : comment.username,
                    radius: 18,
                  ),
                  if (comment.replies.isNotEmpty)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.only(top: 4),
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCommentBubble(comment, isReply: false),
                  ...visibleReplies.map((r) => _buildReplyRow(r)),
                  if (hiddenCount > 0) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(
                              () => comment.showAllReplies = true),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          'Show $hiddenCount more '
                              '${hiddenCount == 1 ? 'reply' : 'replies'}...',
                          style: TextStyle(
                            color: Colors.purpleAccent.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyRow(Comment reply) => Padding(
    padding: const EdgeInsets.only(top: 12, left: 8),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: _buildAvatar(
              reply.isAnonymous ? null : reply.avatarUrl,
              reply.isAnonymous ? null : reply.username,
              radius: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: _buildCommentBubble(reply, isReply: true)),
        ],
      ),
    ),
  );

  Widget _buildCommentBubble(Comment comment,
      {required bool isReply}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              comment.isAnonymous
                  ? 'Anonymous'
                  : (comment.username ?? 'Unknown'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600,
                fontSize: isReply ? 13 : 14,
              ),
            ),
            if (comment.isAuthor) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9B59B6), Color(0xFF3498DB)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Author 🎤',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
            const Spacer(),
            Text(
              _timeAgo(comment.createdAt),
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          comment.content,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: isReply ? 13.5 : 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            GestureDetector(
              onTap: () => _toggleLike(comment),
              child: Row(
                children: [
                  Icon(
                    comment.isLikedByMe
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 16,
                    color: comment.isLikedByMe
                        ? Colors.redAccent
                        : Colors.white.withOpacity(0.4),
                  ),
                  if (comment.likeCount > 0) ...[
                    const SizedBox(width: 4),
                    Text('${comment.likeCount}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => _startReply(comment.id, comment.username),
              child: Row(
                children: [
                  Icon(Icons.reply,
                      size: 16,
                      color: Colors.white.withOpacity(0.4)),
                  const SizedBox(width: 4),
                  Text('Reply',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Avatar ────────────────────────────────────────────────

// ── Avatar ────────────────────────────────────────────────

  Widget _buildAvatar(String? avatarUrl, String? username, {double radius = 20}) {
    // ── Check 1: Anonymous (both null means anonymous) ──────────────────
    final bool isAnonymous = (avatarUrl == null && username == null);
    if (isAnonymous) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade700,
        child: const Icon(Icons.person, color: Colors.white),
      );
    }

    // ── Check 2: Valid http URL ──────────────────────────────────────────
    final bool hasValidUrl =
        avatarUrl != null &&
            avatarUrl.isNotEmpty &&
            avatarUrl.startsWith('http');

    if (hasValidUrl) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade800,
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (_, __) {},
      );
    }

    // ── Check 3: First letter fallback ──────────────────────────────────
    final String initial =
    (username != null && username.isNotEmpty)
        ? username[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.deepPurple.shade700,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }

  // ── Sticky input ──────────────────────────────────────────

  Widget _buildStickyInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A).withOpacity(0.95),
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_replyingToId != null)
                GestureDetector(
                  onTap: _cancelReply,
                  child: Container(
                    margin:
                    const EdgeInsets.only(bottom: 8, left: 44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.purpleAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Replying to @$_replyingToUsername',
                          style: const TextStyle(
                              color: Colors.purpleAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.close,
                            size: 14, color: Colors.purpleAccent),
                      ],
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildAvatar(widget.currentAvatarUrl,
                      widget.currentUsername, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.12)),
                      ),
                      child: TextField(
                        controller: _commentController,
                        focusNode: _focusNode,
                        maxLines: 4,
                        minLines: 1,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.4),
                        decoration: InputDecoration(
                          hintText: _replyingToId != null
                              ? 'Write a reply...'
                              : 'Add a comment...',
                          hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _submitComment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isSending
                              ? [Colors.grey, Colors.grey]
                              : const [
                            Color(0xFF9B59B6),
                            Color(0xFF3498DB)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _isSending
                          ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                          : Text(
                        _replyingToId != null ? 'Reply' : 'Post',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Usage example (NearbyFeedScreen onComment callback):
//
//  onComment: () => Navigator.push(
//    context,
//    MaterialPageRoute(
//      builder: (_) => ThoughtCommentsScreen(
//        post: ThoughtPost(
//          id: post.id,
//          username: post.username,
//          avatarUrl: post.avatarUrl,
//          content: post.content,
//          createdAt: DateTime.tryParse(post.timestamp) ?? DateTime.now(),
//          isAnonymous: post.isAnonymous,
//        ),
//        currentUserId: FirebaseAuth.instance.currentUser!.uid,
//        currentUsername: 'YourUsername',
//        currentAvatarUrl: 'https://...',
//      ),
//    ),
//  ),
// ══════════════════════════════════════════════════════════════