import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
//  ThogarRepost — Text Post Repost System
//  Confirm sheet | Nested card preview | Backend repost | Console logs
// ─────────────────────────────────────────────────────────────────────────────

// ── Model for post data passed to repost sheet ─────────────────────────────────
class ThogarRepostPost {
  final String  id;
  final String  content;
  final String  cityName;
  final bool    isAnonymous;
  final String? username;
  final String? avatarUrl;
  final int     repostCount;

  const ThogarRepostPost({
    required this.id,
    required this.content,
    required this.cityName,
    required this.isAnonymous,
    this.username,
    this.avatarUrl,
    this.repostCount = 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  ThogarRepost service
// ─────────────────────────────────────────────────────────────────────────────
class ThogarRepost {
  static const String _baseUrl = 'https://avishka-tiktok-api.zeabur.app';

  // ── Show Repost Confirmation Sheet ────────────────────────────────────────
  static Future<bool> showRepostSheet({
    required BuildContext context,
    required ThogarRepostPost post,
  }) async {
    HapticFeedback.lightImpact();

    debugPrint('\n🔁 ========== SHOW REPOST SHEET ==========');
    debugPrint('   Post ID  : ${post.id}');
    debugPrint('   City     : ${post.cityName}');
    debugPrint('   Anon     : ${post.isAnonymous}');
    debugPrint('==========================================\n');

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RepostSheet(post: post),
    );

    return result ?? false;
  }

  // ── Execute Repost (API call) ──────────────────────────────────────────────
  static Future<ThogarRepostResult> repost({
    required String originalPostId,
    required String currentUserId,
    required String? currentUsername,
    required String? currentAvatarUrl,
    required bool repostAnonymously,
    required double? latitude,
    required double? longitude,
    required String cityName,
  }) async {
    debugPrint('\n🔁 ========== THOGAR REPOST EXECUTE ==========');
    debugPrint('   Original Post : $originalPostId');
    debugPrint('   Reposter      : $currentUserId');
    debugPrint('   Anonymous     : $repostAnonymously');
    debugPrint('   City          : $cityName');

    // ── Internet check ────────────────────────────────────────────────────
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      if (result.isEmpty || result[0].rawAddress.isEmpty) throw Exception();
    } catch (_) {
      debugPrint('   ❌ No internet');
      return ThogarRepostResult(success: false, message: 'No internet connection');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/text-posts/$originalPostId/repost'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId'          : currentUserId,
          'username'        : currentUsername,
          'avatarUrl'       : currentAvatarUrl,
          'isAnonymous'     : repostAnonymously,
          'latitude'        : latitude,
          'longitude'       : longitude,
          'cityName'        : cityName,
        }),
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201 && body['success'] == true) {
        debugPrint('   ✅ Repost created: ${body['repostId']}');
        debugPrint('==========================================\n');
        return ThogarRepostResult(
          success: true,
          repostId: body['repostId'] as String?,
          message: body['message'] as String? ?? 'Reposted!',
        );
      } else {
        final msg = body['message'] as String? ?? 'Repost failed';
        debugPrint('   ❌ Backend error: $msg');
        debugPrint('==========================================\n');
        return ThogarRepostResult(success: false, message: msg);
      }
    } catch (e) {
      debugPrint('   ❌ Exception: $e');
      debugPrint('==========================================\n');
      return ThogarRepostResult(success: false, message: 'Network error');
    }
  }
}

// ── Result model ──────────────────────────────────────────────────────────────
class ThogarRepostResult {
  final bool   success;
  final String message;
  final String? repostId;

  const ThogarRepostResult({
    required this.success,
    required this.message,
    this.repostId,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  RepostSheet — Bottom sheet with nested card preview + options
// ─────────────────────────────────────────────────────────────────────────────
class _RepostSheet extends StatefulWidget {
  final ThogarRepostPost post;
  const _RepostSheet({required this.post});

  @override
  State<_RepostSheet> createState() => _RepostSheetState();
}

class _RepostSheetState extends State<_RepostSheet> {
  bool _repostAnonymously = false;
  bool _loading = false;

  // Gradients to match nearby feed
  static const List<LinearGradient> _gradients = [
    LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF16213e)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2d1b69), Color(0xFF11998e)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0f0c29), Color(0xFF24243e)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  ];

  Future<void> _onConfirmRepost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    HapticFeedback.mediumImpact();

    debugPrint('\n🔁 ========== CONFIRM REPOST ==========');
    debugPrint('   User       : ${user.uid}');
    debugPrint('   Anonymous  : $_repostAnonymously');

    final result = await ThogarRepost.repost(
      originalPostId   : widget.post.id,
      currentUserId    : user.uid,
      currentUsername  : user.displayName ?? user.email,
      currentAvatarUrl : user.photoURL,
      repostAnonymously: _repostAnonymously,
      latitude         : null,   // Caller can inject if needed
      longitude        : null,
      cityName         : widget.post.cityName,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.pop(context, result.success);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            result.success ? Icons.repeat_rounded : Icons.error_outline_rounded,
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(result.success ? 'Reposted to your vibes!' : result.message),
        ]),
        backgroundColor: result.success
            ? Colors.white.withOpacity(0.1)
            : Colors.redAccent.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          const Row(children: [
            Icon(Icons.repeat_rounded, color: Colors.greenAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'Repost this Vibe?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            'This will appear in your vibes and nearby feed.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // ── Nested card preview ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: _gradients[post.id.hashCode.abs() % _gradients.length],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mini header
                Row(children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    backgroundImage: (!post.isAnonymous &&
                        post.avatarUrl != null &&
                        post.avatarUrl!.startsWith('http'))
                        ? NetworkImage(post.avatarUrl!)
                        : null,
                    child: (post.isAnonymous || post.avatarUrl == null)
                        ? Icon(
                        post.isAnonymous
                            ? Icons.visibility_off_rounded
                            : Icons.person_rounded,
                        size: 14, color: Colors.white70)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      post.isAnonymous ? 'Anonymous Vibe' : (post.username ?? 'Unknown'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      post.cityName,
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ]),
                  const Spacer(),
                  // Repost badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.repeat_rounded, color: Colors.greenAccent, size: 10),
                      SizedBox(width: 3),
                      Text('Repost', style: TextStyle(color: Colors.greenAccent, fontSize: 9)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 10),

                // Content preview
                Text(
                  post.content.length > 120
                      ? '${post.content.substring(0, 120)}...'
                      : post.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Anonymous toggle ──────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: SwitchListTile(
              value: _repostAnonymously,
              onChanged: (v) => setState(() => _repostAnonymously = v),
              title: const Text(
                'Repost anonymously',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              subtitle: const Text(
                'Your name won\'t be shown',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              activeColor: Colors.greenAccent,
              secondary: Icon(
                _repostAnonymously
                    ? Icons.visibility_off_rounded
                    : Icons.person_rounded,
                color: Colors.white54,
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 16),

          // ── Action buttons ────────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _loading ? null : _onConfirmRepost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.withOpacity(0.85),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black54),
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.repeat_rounded, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Repost',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ]),

          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
        ],
      ),
    );
  }
}