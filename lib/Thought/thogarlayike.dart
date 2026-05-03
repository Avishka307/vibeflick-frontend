import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ThogarLike — Text Post Like System
//  Toggle like | Check status | Show liked-by sheet | Console logs
// ─────────────────────────────────────────────────────────────────────────────

class ThogarLike {
  static const String _baseUrl = 'https://avishka-tiktok-api.zeabur.app';

  // ── Toggle Like (API call) ──────────────────────────────────────────────────
  static Future<ThogarLikeResult> toggleLike({
    required String postId,
    required String uid,
  }) async {
    debugPrint('\n❤️  ========== THOGAR LIKE TOGGLE ==========');
    debugPrint('   Post ID : $postId');
    debugPrint('   UID     : $uid');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/text-posts/$postId/like'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid}),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      final liked = body['liked'] as bool? ?? false;
      final message = body['message'] as String? ?? '';

      debugPrint('   Result  : ${liked ? '❤️  Liked' : '💔 Unliked'}');
      debugPrint('   Message : $message');
      debugPrint('==========================================\n');

      return ThogarLikeResult(
        success: body['success'] == true,
        liked: liked,
        message: message,
      );
    } catch (e) {
      debugPrint('   ❌ Error : $e');
      debugPrint('==========================================\n');
      return ThogarLikeResult(success: false, liked: false, message: e.toString());
    }
  }

  // ── Check if current user liked this post ──────────────────────────────────
  static Future<bool> isLikedByCurrentUser(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/text-posts/$postId/like-status/${user.uid}'),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['liked'] == true;
      }
    } catch (e) {
      debugPrint('❌ ThogarLike.isLiked error: $e');
    }
    return false;
  }

  // ── Show Liked-By Bottom Sheet ─────────────────────────────────────────────
  static void showLikedBySheet(BuildContext context, String postId, int likeCount) {
    HapticFeedback.lightImpact();
    debugPrint('\n👥 ========== SHOW LIKED BY SHEET ==========');
    debugPrint('   Post ID    : $postId');
    debugPrint('   Like Count : $likeCount');
    debugPrint('==========================================\n');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LikedBySheet(postId: postId, likeCount: likeCount),
    );
  }
}

// ── Result model ───────────────────────────────────────────────────────────────
class ThogarLikeResult {
  final bool success;
  final bool liked;
  final String message;
  const ThogarLikeResult({
    required this.success,
    required this.liked,
    required this.message,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  LikedBySheet — Bottom sheet showing who liked
// ─────────────────────────────────────────────────────────────────────────────
class _LikedBySheet extends StatefulWidget {
  final String postId;
  final int likeCount;
  const _LikedBySheet({required this.postId, required this.likeCount});

  @override
  State<_LikedBySheet> createState() => _LikedBySheetState();
}

class _LikedBySheetState extends State<_LikedBySheet> {
  static const String _baseUrl = 'https://avishka-tiktok-api.zeabur.app';

  List<Map<String, dynamic>> _likers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLikers();
  }

  Future<void> _fetchLikers() async {
    debugPrint('\n📋 ========== FETCH LIKERS ==========');
    debugPrint('   Post ID : ${widget.postId}');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/text-posts/${widget.postId}/likers'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = (body['data'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        setState(() { _likers = data; _loading = false; });
        debugPrint('   Found ${data.length} likers');
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('   ❌ Error: $e');
      setState(() => _loading = false);
    }
    debugPrint('==========================================\n');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(children: [
            const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              '${widget.likeCount} Likes',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Body
          Flexible(
            child: _loading
                ? const Center(
              child: CircularProgressIndicator(
                color: Colors.redAccent,
                strokeWidth: 2,
              ),
            )
                : _likers.isEmpty
                ? const Center(
              child: Text(
                'No likes yet',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            )
                : ListView.separated(
              shrinkWrap: true,
              itemCount: _likers.length,
              separatorBuilder: (_, __) => Divider(
                color: Colors.white.withOpacity(0.06),
                height: 1,
              ),
              itemBuilder: (_, i) {
                final liker = _likers[i];
                final name = liker['username'] as String? ?? 'Unknown';
                final avatar = liker['avatarUrl'] as String?;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white10,
                    backgroundImage:
                    (avatar != null && avatar.startsWith('http'))
                        ? NetworkImage(avatar)
                        : null,
                    child: (avatar == null || !avatar.startsWith('http'))
                        ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    )
                        : null,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.favorite,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LikeButton — Standalone reusable widget
//  Usage: LikeButton(postId: '...', initialCount: 5, initialLiked: false)
// ─────────────────────────────────────────────────────────────────────────────
class ThogarLikeButton extends StatefulWidget {
  final String postId;
  final int initialCount;
  final bool initialLiked;
  final VoidCallback? onLikeChanged;

  const ThogarLikeButton({
    super.key,
    required this.postId,
    this.initialCount = 0,
    this.initialLiked = false,
    this.onLikeChanged,
  });

  @override
  State<ThogarLikeButton> createState() => _ThogarLikeButtonState();
}

class _ThogarLikeButtonState extends State<ThogarLikeButton>
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _count;
  bool _loading = false;

  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.initialLiked;
    _count   = widget.initialCount;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _loading) return;

    HapticFeedback.lightImpact();
    _controller.forward(from: 0);

    setState(() {
      _isLiked = !_isLiked;
      _count += _isLiked ? 1 : -1;
      _loading = true;
    });

    final result = await ThogarLike.toggleLike(
      postId: widget.postId,
      uid: user.uid,
    );

    if (!result.success) {
      // Rollback on failure
      setState(() {
        _isLiked = !_isLiked;
        _count += _isLiked ? 1 : -1;
      });
    } else {
      widget.onLikeChanged?.call();
    }

    setState(() => _loading = false);
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n > 0 ? '$n' : '';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Row(children: [
            Icon(
              _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isLiked ? Colors.redAccent : Colors.white70,
              size: 20,
            ),
            if (_count > 0) ...[
              const SizedBox(width: 5),
              Text(
                _fmt(_count),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}