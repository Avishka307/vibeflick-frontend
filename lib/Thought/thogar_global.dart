import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../Thought/thought_comments_screen.dart';
import '../Thought/thogaranymore.dart';
import '../Thought/thogarlayike.dart';
import '../Thought/thogarripost.dart';
import '../Thought/thogarshea.dart';

class ThogarGlobalScreen extends StatefulWidget {
  final double userLatitude;
  final double userLongitude;

  const ThogarGlobalScreen({
    super.key,
    required this.userLatitude,
    required this.userLongitude,
  });

  @override
  State<ThogarGlobalScreen> createState() => _ThogarGlobalScreenState();
}

class _ThogarGlobalScreenState extends State<ThogarGlobalScreen> {

  static const String _baseUrl = 'https://avishka-tiktok-api.zeabur.app';

  static const List<LinearGradient> _gradients = [
    LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2d1b69), Color(0xFF11998e)],                   begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF6b2d5e)],                   begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a0a00), Color(0xFF5c3a00), Color(0xFF8b5e00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF000428), Color(0xFF004e92)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF000428), Color(0xFF004e92)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF360033), Color(0xFF0b8793)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1f4037), Color(0xFF99f2c8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF3a1c71), Color(0xFFd76d77), Color(0xFFffaf7b)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0052d4), Color(0xFF4364f7), Color(0xFF6fb1fc)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF16222a), Color(0xFF3a6073)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF373b44), Color(0xFF4286f4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0b0c10), Color(0xFF1f2833), Color(0xFF45a29e)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2c003e), Color(0xFF8b00ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF002f4b), Color(0xFFdc4225)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1c1c2e), Color(0xFF2e4057), Color(0xFF048a81)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0d0d0d), Color(0xFF1a1a2e), Color(0xFFe94560)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1b2631), Color(0xFF2c3e50)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF4a0072), Color(0xFF9c27b0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF003300), Color(0xFF006600), Color(0xFF00cc44)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF4a0080), Color(0xFF9900ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0a0a0a), Color(0xFF1a1a1a), Color(0xFF2d6a4f)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF091833), Color(0xFF1a3a6b), Color(0xFF2563eb)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1c0221), Color(0xFF6a0572), Color(0xFFab83a1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0d1117), Color(0xFF161b22), Color(0xFF58a6ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF3d0000), Color(0xFF8b0000)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF020024), Color(0xFF090979), Color(0xFF00d4ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0a3d62), Color(0xFF1e3799)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF192a56), Color(0xFF273c75)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF130f40), Color(0xFF30305e), Color(0xFF7f00ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a1a1a), Color(0xFF2d2d2d), Color(0xFF00b4d8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2b5876), Color(0xFF4e4376)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0c0c0c), Color(0xFF1f1c2c), Color(0xFF928dab)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF004953), Color(0xFF007965)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1c2833), Color(0xFF2e86c1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF3b1f2b), Color(0xFF7b2d8b), Color(0xFFaa076b)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0f2041), Color(0xFF1557ea)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a0a2e), Color(0xFF6c3483)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF00111c), Color(0xFF003b5c), Color(0xFF006994)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF533483)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0f0f1a), Color(0xFF1a1a35), Color(0xFF00c9ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF001a00), Color(0xFF003300), Color(0xFF00ff88)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0d0221), Color(0xFF3a0ca3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF140152), Color(0xFF22007c), Color(0xFF0d00a4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0b132b), Color(0xFF1c2541), Color(0xFF3a506b)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2c003e), Color(0xFF560bad)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF010b13), Color(0xFF02233a), Color(0xFF0077b6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF10002b), Color(0xFF240046), Color(0xFF7b2d8b)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF023e8a), Color(0xFF0077b6), Color(0xFF00b4d8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1b0000), Color(0xFF3d0000), Color(0xFFb00020)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF003049), Color(0xFF023e7d)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0e0e0e), Color(0xFF1c1c1c), Color(0xFF2e4057)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2d132c), Color(0xFF810034)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF00005c), Color(0xFF0000ab), Color(0xFF4040ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0a001a), Color(0xFF1a0040), Color(0xFF6600cc)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF001219), Color(0xFF005f73), Color(0xFF0a9396)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1c0a00), Color(0xFF4d2600), Color(0xFF7a3b00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  ];

  List<_GlobalPost> _posts       = [];
  bool              _loading      = true;
  String?           _errorMessage;

  // ── NEW: Internet ──────────────────────────────────────────────────────────
  bool _hasInternet         = true;
  bool _showNoInternetToast = false;

  final Map<String, String> _translations = {};
  final Set<String>         _translating  = {};

  @override
  void initState() {
    super.initState();
    _fetchGlobalPosts();

  }

  // ── NEW: Internet check ────────────────────────────────────────────────────
  Future<bool> _checkInternetGlobal() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        if (!_hasInternet) setState(() => _hasInternet = true);
        return true;
      }
    } catch (_) {}
    if (mounted && !_showNoInternetToast) {
      setState(() { _hasInternet = false; _showNoInternetToast = true; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: const [
            Icon(Icons.wifi_off, color: Colors.white),
            SizedBox(width: 12),
            Text('No internet connection'),
          ]),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showNoInternetToast = false);
      });
    }
    return false;
  }

  Future<void> _fetchGlobalPosts() async {
    // ── NEW: internet check ──────────────────────────────────────────────────
    if (!await _checkInternetGlobal()) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    setState(() { _loading = true; _errorMessage = null; });

    try {
      final uri = Uri.parse('$_baseUrl/api/text-posts/global').replace(
        queryParameters: {
          'limit' : '20',
          'sort'  : 'recent',
          if (currentUser != null) 'uid': currentUser.uid,
        },
      );

      debugPrint('\n🌍 ========== FETCHING GLOBAL POSTS ==========');
      debugPrint('   URL: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 25));
      final body     = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as List<dynamic>;
        setState(() {
          _posts   = data.map((e) => _GlobalPost.fromJson(e)).toList();
          _loading = false;
        });
        debugPrint('   Loaded: ${_posts.length} global posts');
      } else {
        setState(() {
          _errorMessage = body['message'] as String? ?? 'Failed to load';
          _loading      = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Global fetch error: $e');
      setState(() {
        _errorMessage = 'Network error. Check your connection.';
        _loading      = false;
      });
    }
  }

  void _reportPost(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/text-posts/$postId/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': user.uid}),
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(body['autoHidden'] == true
              ? 'Post hidden due to multiple reports'
              : 'Reported. Thank you.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (body['autoHidden'] == true) {
        setState(() => _posts.removeWhere((p) => p.id == postId));
      }
    } catch (e) {
      debugPrint('❌ Report error: $e');
    }
  }

  Future<void> _translatePost(_GlobalPost post) async {
    if (_translating.contains(post.id)) return;
    if (_translations.containsKey(post.id)) {
      setState(() => _translations.remove(post.id));
      return;
    }

    setState(() => _translating.add(post.id));

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      final translated = '[EN] ${post.content}';

      setState(() {
        _translations[post.id] = translated;
        _translating.remove(post.id);
      });
    } catch (e) {
      debugPrint('❌ Translate error: $e');
      setState(() => _translating.remove(post.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translation failed. Try again.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openComments(_GlobalPost post) async {
    HapticFeedback.lightImpact();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to comment'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (!mounted) return;
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, anim, __) => ThoughtCommentsScreen(
        post: ThoughtPost(
          id: post.id, username: post.username,
          avatarUrl: post.avatarUrl, content: post.content,
          createdAt: post.createdAt, isAnonymous: post.isAnonymous,
        ),
        currentUserId   : user.uid,
        currentUsername : user.displayName ?? user.email ?? 'User',
        currentAvatarUrl: user.photoURL,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(0, 0.05), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0f),
      body: CustomScrollView(slivers: [

        SliverAppBar(
          backgroundColor: const Color(0xFF0a0a0f),
          elevation: 0,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color : const Color(0xFF7C4DFF).withOpacity(0.15),
                shape : BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF7C4DFF).withOpacity(0.3)),
              ),
              child: const Text('🌍', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Global Vibes',
                  style: TextStyle(color: Colors.white,
                      fontSize: 18, fontWeight: FontWeight.bold,
                      letterSpacing: 0.3)),
              Text('${_posts.length} thoughts worldwide',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ]),
          ]),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color       : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border      : Border.all(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.white70, size: 18),
                ),
                onPressed: _fetchGlobalPosts,
              ),
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Container(
            margin  : const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color : const Color(0xFF7C4DFF).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF7C4DFF).withOpacity(0.2)),
            ),
            child: const Row(children: [
              Text('🌐', style: TextStyle(fontSize: 14)),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Tap "Translate" on any post to read it in your language.',
                style: TextStyle(
                    color: Colors.white38, fontSize: 11, height: 1.4),
              )),
            ]),
          ),
        ),

        // ── NEW: skeleton replaces spinner ───────────────────────────────────
        if (_loading)
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (_, __) => const _SkeletonCard(),
              childCount: 5,
            ),
          )
        else if (_errorMessage != null)
          SliverFillRemaining(
            child: _ErrorState(
                message: _errorMessage!, onRetry: _fetchGlobalPosts),
          )
        else if (_posts.isEmpty)
            const SliverFillRemaining(child: _EmptyState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final post         = _posts[index];
                final gradient     = _gradients[
                post.gradientIndex.clamp(0, _gradients.length - 1)];
                final translated   = _translations[post.id];
                final isTranslating = _translating.contains(post.id);

                return _GlobalPostCard(
                  post          : post,
                  gradient      : gradient,
                  translated    : translated,
                  isTranslating : isTranslating,
                  onComment     : () => _openComments(post),
                  onTranslate   : () => _translatePost(post),
                  onLike        : () => ThogarLike.showLikedBySheet(
                      context, post.id, post.likeCount),
                  onRepost      : () => ThogarRepost.showRepostSheet(
                    context: context,
                    post   : ThogarRepostPost(
                      id: post.id, content: post.content,
                      cityName: post.cityName, isAnonymous: post.isAnonymous,
                      username: post.username, avatarUrl: post.avatarUrl,
                      repostCount: post.repostCount,
                    ),
                  ),
                  onShare       : () => ThogarShare.showShareSheet(
                    context    : context, postId: post.id,
                    content    : post.content, cityName: post.cityName,
                    isAnonymous: post.isAnonymous, username: post.username,
                  ),
                  onMoreOptions : () => ThogarAnymore.showMoreSheet(
                    context    : context, postId: post.id,
                    postOwnerId: post.uid, content: post.content,
                    isAnonymous: post.isAnonymous, cityName: post.cityName,
                    username   : post.username, avatarUrl: post.avatarUrl,
                    onReport: _reportPost,
                    onDeleted  : () => setState(
                            () => _posts.removeWhere((p) => p.id == post.id)),
                    onEdited   : _fetchGlobalPosts,
                  ),
                );
              }, childCount: _posts.length),
            ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
    );
  }
}

class _GlobalPostCard extends StatefulWidget {
  final _GlobalPost    post;
  final LinearGradient gradient;
  final String?        translated;
  final bool           isTranslating;
  final VoidCallback   onComment;
  final VoidCallback   onTranslate;
  final VoidCallback   onLike;
  final VoidCallback   onRepost;
  final VoidCallback   onShare;
  final VoidCallback   onMoreOptions;

  static const _accent = Color(0xFF7C4DFF);

  const _GlobalPostCard({
    required this.post,
    required this.gradient,
    required this.translated,
    required this.isTranslating,
    required this.onComment,
    required this.onTranslate,
    required this.onLike,
    required this.onRepost,
    required this.onShare,
    required this.onMoreOptions,
  });

  @override
  State<_GlobalPostCard> createState() => _GlobalPostCardState();
}

class _GlobalPostCardState extends State<_GlobalPostCard> {
  static const String _baseUrl = 'https://avishka-tiktok-api.zeabur.app';

  late bool _isLiked;
  late int  _likeCount;
  late int  _repostCount;
  late int  _commentCount;
  bool _isHidden = false;

  @override
  void initState() {
    super.initState();
    _isLiked   = widget.post.isLiked;
    _likeCount = widget.post.likeCount;
    _repostCount  = widget.post.repostCount;
    _commentCount = widget.post.commentCount;
  }

  Future<void> _callLikeApi(String uid) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/text-posts/${widget.post.id}/like'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('❌ Like API error: $e');
    }
  }

  void _toggleLike() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _isLiked    = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    _callLikeApi(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    if (_isHidden) {
      return _ReportedPostPlaceholder(
        onUnhide: () => setState(() => _isHidden = false),
      );
    }
    final showTranslated = widget.translated != null;
    final flag = _countryFlagFromCode(widget.post.countryCode);

    return Container(
      margin     : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration : BoxDecoration(
        gradient    : widget.gradient,
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow   : [
          BoxShadow(color: Colors.black.withOpacity(0.3),
              blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(children: [
                  _AutoAvatar(
                    avatarUrl  : widget.post.isAnonymous ? null : widget.post.avatarUrl,
                    username   : widget.post.username,
                    isAnonymous: widget.post.isAnonymous,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.post.isAnonymous ? 'Anonymous Vibe' : widget.post.username,
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 3),
                      Row(children: [
                        if (flag.isNotEmpty)
                          Text(flag, style: const TextStyle(fontSize: 12)),
                        if (flag.isNotEmpty) const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color : _GlobalPostCard._accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _GlobalPostCard._accent.withOpacity(0.25)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.public_rounded,
                                color: Color(0xFF9B8FFF), size: 10),
                            const SizedBox(width: 3),
                            Text(
                              widget.post.cityName.isNotEmpty
                                  ? widget.post.cityName
                                  : widget.post.countryName,
                              style: const TextStyle(color: Color(0xFF9B8FFF),
                                  fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        Text(_timeAgo(widget.post.createdAt),
                            style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      ]),
                    ],
                  )),
                  GestureDetector(
                    onTap : widget.onMoreOptions,
                    child : const Icon(Icons.more_horiz, color: Colors.white54),
                  ),
                ]),

                const SizedBox(height: 14),

                Text(
                  showTranslated ? widget.translated! : widget.post.content,
                  style: const TextStyle(color: Colors.white, fontSize: 18,
                      height: 1.45, fontWeight: FontWeight.w500),
                ),

                if (showTranslated) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.translate_rounded, size: 11, color: Color(0xFF7C4DFF)),
                    const SizedBox(width: 4),
                    const Text('Translated',
                        style: TextStyle(color: Color(0xFF7C4DFF),
                            fontSize: 10, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap : widget.onTranslate,
                      child : const Text('Show original',
                          style: TextStyle(color: Colors.white38, fontSize: 10,
                              decoration: TextDecoration.underline)),
                    ),
                  ]),
                ],

                const SizedBox(height: 14),

                Row(children: [
                  GestureDetector(
                    onTap      : _toggleLike,
                    onLongPress: widget.onLike,
                    child: Row(children: [
                      Icon(
                        _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: _isLiked ? Colors.redAccent : Colors.white70,
                        size: 20,
                      ),
                      if (_likeCount > 0) ...[
                        const SizedBox(width: 5),
                        Text('$_likeCount',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ]),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      widget.onComment();
                      if (mounted) setState(() {});
                    },
                    child: Row(children: [
                      SvgPicture.asset(
                        'assets/images/comment_icon.svg',
                        width: 20, height: 20,
                        colorFilter: const ColorFilter.mode(
                            Colors.white70, BlendMode.srcIn),
                      ),
                      if (_commentCount > 0) ...[
                        const SizedBox(width: 5),
                        Text('$_commentCount',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ]),
                  ),

                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      widget.onRepost();
                      if (mounted) setState(() => _repostCount++);
                    },

                    child: Row(children: [
                      const _GlobChip(icon: Icons.repeat_rounded),
                      if (_repostCount > 0) ...[
                        const SizedBox(width: 5),
                        Text('$_repostCount',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ]),
                  ),

                  GestureDetector(onTap: widget.onShare,
                      child: const _GlobChip(icon: Icons.ios_share_rounded)),
                  const Spacer(),

                  GestureDetector(
                    onTap: widget.isTranslating ? null : widget.onTranslate,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color : showTranslated
                            ? _GlobalPostCard._accent.withOpacity(0.25)
                            : _GlobalPostCard._accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _GlobalPostCard._accent.withOpacity(
                            showTranslated ? 0.5 : 0.25)),
                      ),
                      child: widget.isTranslating
                          ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: Color(0xFF7C4DFF), strokeWidth: 1.5))
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.translate_rounded,
                            size: 12, color: Color(0xFF9B8FFF)),
                        const SizedBox(width: 4),
                        Text(
                          showTranslated ? 'Original' : 'Translate',
                          style: const TextStyle(color: Color(0xFF9B8FFF),
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportedPostPlaceholder extends StatelessWidget {
  final VoidCallback onUnhide;
  const _ReportedPostPlaceholder({required this.onUnhide});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(children: [
        const Icon(Icons.report_gmailerrorred_rounded,
            color: Colors.orange, size: 20),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('This post was hidden due to multiple reports.',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ),
        GestureDetector(
          onTap: onUnhide,
          child: const Text('Show',
              style: TextStyle(color: Colors.orange, fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Auto Avatar
// ─────────────────────────────────────────────────────────────────────────────
class _AutoAvatar extends StatelessWidget {
  final String?  avatarUrl;
  final String   username;
  final bool     isAnonymous;
  final double   radius;

  const _AutoAvatar({
    required this.avatarUrl,
    required this.username,
    required this.isAnonymous,
    this.radius = 20,
  });

  String get _initials {
    final parts = username.trim().split(' ')
        .where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Color get _avatarColor {
    final colors = [
      const Color(0xFF7C4DFF), const Color(0xFF00BCD4),
      const Color(0xFF4CAF50), const Color(0xFFFF5722),
      const Color(0xFF9C27B0), const Color(0xFF2196F3),
      const Color(0xFFFF9800), const Color(0xFF009688),
    ];
    final hash = username.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (isAnonymous) {
      return CircleAvatar(
        radius         : radius,
        backgroundColor: Colors.white.withOpacity(0.12),
        child: Icon(Icons.visibility_off_rounded,
            size: radius, color: Colors.white70),
      );
    }
    if (avatarUrl != null && avatarUrl!.startsWith('http')) {
      return CircleAvatar(
        radius         : radius,
        backgroundColor: Colors.white.withOpacity(0.12),
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }
    return CircleAvatar(
      radius         : radius,
      backgroundColor: _avatarColor.withOpacity(0.8),
      child: Text(
        _initials,
        style: TextStyle(
          color     : Colors.white,
          fontSize  : radius * 0.75,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NEW: Skeleton Card
// ─────────────────────────────────────────────────────────────────────────────
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(_anim.value),
              ),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 100, height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(_anim.value),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(width: 60, height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(_anim.value * 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ]),
          ]),
          const SizedBox(height: 16),
          ...List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: i == 2 ? 160 : double.infinity,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_anim.value * 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          )),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (_) => Container(
              width: 40, height: 14,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_anim.value * 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
            )),
          ),
        ]),
      ),
    );
  }
}

class _GlobChip extends StatelessWidget {
  final IconData icon;
  const _GlobChip({required this.icon});
  @override
  Widget build(BuildContext context) =>
      Icon(icon, color: Colors.white70, size: 20);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('🌍', style: TextStyle(fontSize: 52)),
      SizedBox(height: 14),
      Text('No global vibes yet',
          style: TextStyle(color: Colors.white54, fontSize: 15)),
      SizedBox(height: 6),
      Text('Be the first to post worldwide!',
          style: TextStyle(color: Colors.white24, fontSize: 13)),
    ]),
  );
}

class _ErrorState extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.signal_wifi_off_rounded,
          color: Colors.white38, size: 48),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 14)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C4DFF).withOpacity(0.15),
            foregroundColor: Colors.white),
        onPressed: onRetry,
        icon  : const Icon(Icons.refresh_rounded, size: 16),
        label : const Text('Try again'),
      ),
    ]),
  );
}

String _countryFlagFromCode(String? code) {
  if (code == null || code.length != 2) return '🌐';
  final c      = code.toUpperCase();
  final first  = c.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final second = c.codeUnitAt(1) - 0x41 + 0x1F1E6;
  return String.fromCharCode(first) + String.fromCharCode(second);
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours   < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _GlobalPost {
  const _GlobalPost({
    required this.id,
    required this.uid,
    required this.username,
    required this.content,
    required this.cityName,
    required this.countryName,
    required this.countryCode,
    required this.gradientIndex,
    required this.isAnonymous,
    required this.likeCount,
    required this.commentCount,
    required this.repostCount,
    required this.createdAt,
    required this.isLiked,
    required this.isReposted,
    this.avatarUrl,
  });

  final String   id;
  final String   uid;
  final String   username;
  final String   content;
  final String   cityName;
  final String   countryName;
  final String?  countryCode;
  final int      gradientIndex;
  final bool     isAnonymous;
  final int      likeCount;
  final int      commentCount;
  final int      repostCount;
  final DateTime createdAt;
  final String?  avatarUrl;
  final bool isLiked;
  final bool isReposted;

  factory _GlobalPost.fromJson(Map<String, dynamic> json) {
    DateTime dt = DateTime.now();
    final raw = json['timestamp'] ?? json['createdAt'];
    if (raw is String) dt = DateTime.tryParse(raw) ?? dt;

    return _GlobalPost(
      id           : json['id']            as String? ?? '',
      uid          : json['uid']           as String? ?? '',
      username     : json['username']      as String? ?? 'Unknown',
      content      : json['content']       as String? ?? '',
      cityName     : json['cityName']      as String? ?? '',
      countryName  : json['countryName']   as String? ?? 'World',
      countryCode  : json['countryCode']   as String?,
      gradientIndex: (json['gradientIndex'] as num?)?.toInt() ?? 0,
      isAnonymous  : json['isAnonymous']   as bool?   ?? false,
      likeCount    : (json['likeCount']    as num?)?.toInt() ?? 0,
      commentCount : (json['commentCount'] as num?)?.toInt() ?? 0,
      repostCount  : (json['repostCount']  as num?)?.toInt() ?? 0,
      createdAt    : dt,
      avatarUrl    : json['avatarUrl']     as String?,
      isLiked      : json['isLiked']       as bool? ?? false,
      isReposted   : json['isReposted']    as bool? ?? false,
    );
  }
}