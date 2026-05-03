import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import '../Thought/thogar_country.dart';
import '../Thought/thogar_global.dart';

import '../Thought/thogaranymore.dart';
import '../Thought/thogarlayike.dart';
import '../Thought/thogarripost.dart';
import '../Thought/thogarshea.dart';
import '../Thought/thought_comments_screen.dart';
import 'location_cache_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NearbyPostCard  — Glassmorphism Twitter-style
//  Double-tap to like | Gradient BG | Anonymous support
// ─────────────────────────────────────────────────────────────────────────────
class NearbyPostCard extends StatefulWidget {
  const NearbyPostCard({
    super.key,
    required this.postId,
    required this.username,
    required this.content,
    required this.distanceLabel,
    required this.city,
    required this.postGradient,
    required this.isAnonymous,
    this.likeCount    = 0,
    this.commentCount = 0,
    this.repostCount  = 0,
    this.avatarUrl,
    this.onComment,
    this.onRepost,
    this.onShare,
    this.onMoreOptions,
    this.onLike,
    this.isLiked    = false,
    this.isReposted = false,
  });

  final String         postId;
  final String         username;
  final String         content;
  final String         distanceLabel;
  final String         city;
  final LinearGradient postGradient;
  final bool           isAnonymous;
  final int            likeCount;
  final int            commentCount;
  final int            repostCount;
  final String?        avatarUrl;
  final VoidCallback?  onComment;
  final VoidCallback?  onRepost;
  final VoidCallback?  onShare;
  final VoidCallback?  onMoreOptions;
  final VoidCallback?  onLike;
  final bool isLiked;
  final bool isReposted;

  @override
  State<NearbyPostCard> createState() => _NearbyPostCardState();
}

class _NearbyPostCardState extends State<NearbyPostCard>
    with SingleTickerProviderStateMixin {

  bool _isLiked = false;
  late int _likeCount;
  late int _repostCount;
  late int _commentCount;
  bool _showHeart = false;
  late AnimationController _heartController;
  late Animation<double>   _heartScale;
  late Animation<double>   _heartOpacity;

  static const String _baseUrl = 'https://avishka-tiktok-api.zeabur.app';

  @override
  void initState() {
    super.initState();
    _isLiked   = widget.isLiked;
    _likeCount = widget.likeCount;
    _repostCount  = widget.repostCount;
    _commentCount = widget.commentCount;
    _heartController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.4), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _heartController, curve: Curves.easeOut));

    _heartOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_heartController);

    _heartController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHeart = false);
      }
    });
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _callLikeApi(String uid) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/text-posts/${widget.postId}/like'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid}),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('❤️ Like API: ${body['message']}');
    } catch (e) {
      debugPrint('❌ Like API error: $e');
    }
  }

  void _handleDoubleTap() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (!_isLiked) { _isLiked = true; _likeCount++; }
      _showHeart = true;
    });
    _heartController.forward(from: 0);
    _callLikeApi(user.uid);
  }

  void _toggleLike() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLiked   = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    _callLikeApi(user.uid);
  }

  String _friendlyDistance(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.startsWith('0') || lower == '0m away') return 'Very close';

    final mMatch = RegExp(r'^(\d+)\s*m').firstMatch(lower);
    if (mMatch != null) {
      final meters = int.tryParse(mMatch.group(1)!) ?? 0;
      if (meters < 250)  return 'Very close';
      if (meters < 750)  return 'Within 500m';
      return 'Within 1 km';
    }

    return raw.replaceAll(' away', '').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: widget.postGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3),
              blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: GestureDetector(
            onDoubleTap: _handleDoubleTap,
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildHeader(),
                  const SizedBox(height: 14),
                  _buildBody(),
                  const SizedBox(height: 16),
                  _buildActionBar(),
                ]),
              ),
              if (_showHeart)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _heartController,
                        builder: (_, __) => Opacity(
                          opacity: _heartOpacity.value,
                          child: Transform.scale(
                            scale: _heartScale.value,
                            child: const Icon(Icons.favorite,
                                color: Colors.redAccent, size: 80),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final friendlyDist = _friendlyDistance(widget.distanceLabel);

    return Row(children: [
      _AutoAvatar(
        avatarUrl  : widget.isAnonymous ? null : widget.avatarUrl,
        username   : widget.username,
        isAnonymous: widget.isAnonymous,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            widget.isAnonymous ? 'Anonymous Vibe' : widget.username,
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 3),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on_rounded,
                    color: Colors.redAccent, size: 10),
                const SizedBox(width: 3),
                Text(
                  widget.city,
                  style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.near_me_rounded, size: 10, color: Colors.white38),
            const SizedBox(width: 3),
            Text(
              friendlyDist,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ]),
        ]),
      ),
      GestureDetector(
        onTap: widget.onMoreOptions,
        child: const Icon(Icons.more_horiz, color: Colors.white54),
      ),
    ]);
  }

  Widget _buildBody() => Text(
    widget.content,
    style: const TextStyle(color: Colors.white, fontSize: 18,
        height: 1.45, fontWeight: FontWeight.w500),
  );

  Widget _buildActionBar() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      GestureDetector(
        onTap: _toggleLike,
        onLongPress: widget.onLike,
        child: _ActionChip(
          icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          iconColor: _isLiked ? Colors.redAccent : Colors.white70,
          label: _fmt(_likeCount),
        ),
      ),
      GestureDetector(
        onTap: () {
          widget.onComment?.call();
          if (mounted) setState(() {});
        },
        child: _SvgActionChip(
          assetPath: 'assets/images/comment_icon.svg',
          label: _fmt(_commentCount),
        ),
      ),
      GestureDetector(
        onTap: () {
          widget.onRepost?.call();
          setState(() => _repostCount++);
        },
        child: _SvgActionChip(
          assetPath: 'assets/images/repost-round-svgrepo-com.svg',
          label: _fmt(_repostCount),
        ),
      ),
      GestureDetector(
        onTap: widget.onShare,
        child: const _SvgActionChip(
          assetPath: 'assets/images/share_icon.svg',
          label: '',
        ),
      ),
    ],
  );

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n > 0 ? '$n' : '';
  }
}

class _SvgActionChip extends StatelessWidget {
  const _SvgActionChip({required this.assetPath, required this.label});
  final String assetPath;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
    SvgPicture.asset(
      assetPath,
      width: 20,
      height: 20,
      colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn),
    ),
    if (label.isNotEmpty) ...[
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
    ],
  ]);
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, this.iconColor = Colors.white70});
  final IconData icon;
  final String   label;
  final Color    iconColor;

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: iconColor, size: 20),
    if (label.isNotEmpty) ...[
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
    ],
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  📍 NearbyFeedScreen
// ═══════════════════════════════════════════════════════════════════════════════
class NearbyFeedScreen extends StatefulWidget {
  const NearbyFeedScreen({super.key});

  @override
  State<NearbyFeedScreen> createState() => _NearbyFeedScreenState();
}

class _NearbyFeedScreenState extends State<NearbyFeedScreen> {

  static const List<LinearGradient> _gradients = [
    LinearGradient(
        colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2d1b69), Color(0xFF11998e)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF6b2d5e)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF1a0a00), Color(0xFF5c3a00), Color(0xFF8b5e00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF000428), Color(0xFF004e92)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF360033), Color(0xFF0b8793)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1f4037), Color(0xFF99f2c8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF3a1c71), Color(0xFFd76d77), Color(0xFFffaf7b)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0052d4), Color(0xFF4364f7), Color(0xFF6fb1fc)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF16222a), Color(0xFF3a6073)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF373b44), Color(0xFF4286f4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0b0c10), Color(0xFF1f2833), Color(0xFF45a29e)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2c003e), Color(0xFF8b00ff)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF002f4b), Color(0xFFdc4225)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF1c1c2e), Color(0xFF2e4057), Color(0xFF048a81)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0d0d0d), Color(0xFF1a1a2e), Color(0xFFe94560)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1b2631), Color(0xFF2c3e50)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF4a0072), Color(0xFF9c27b0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF003300), Color(0xFF006600), Color(0xFF00cc44)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF1a0533), Color(0xFF4a0080), Color(0xFF9900ff)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0a0a0a), Color(0xFF1a1a1a), Color(0xFF2d6a4f)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF091833), Color(0xFF1a3a6b), Color(0xFF2563eb)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF1c0221), Color(0xFF6a0572), Color(0xFFab83a1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0d1117), Color(0xFF161b22), Color(0xFF58a6ff)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF3d0000), Color(0xFF8b0000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF020024), Color(0xFF090979), Color(0xFF00d4ff)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0a3d62), Color(0xFF1e3799)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF192a56), Color(0xFF273c75)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF130f40), Color(0xFF30305e), Color(0xFF7f00ff)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF1a1a1a), Color(0xFF2d2d2d), Color(0xFF00b4d8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2b5876), Color(0xFF4e4376)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0c0c0c), Color(0xFF1f1c2c), Color(0xFF928dab)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF004953), Color(0xFF007965)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1c2833), Color(0xFF2e86c1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF3b1f2b), Color(0xFF7b2d8b), Color(0xFFaa076b)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0f2041), Color(0xFF1557ea)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a0a2e), Color(0xFF6c3483)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF00111c), Color(0xFF003b5c), Color(0xFF006994)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF533483)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0f0f1a), Color(0xFF1a1a35), Color(0xFF00c9ff)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF001a00), Color(0xFF003300), Color(0xFF00ff88)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF0d0221), Color(0xFF3a0ca3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF140152), Color(0xFF22007c), Color(0xFF0d00a4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0b132b), Color(0xFF1c2541), Color(0xFF3a506b)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2c003e), Color(0xFF560bad)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF010b13), Color(0xFF02233a), Color(0xFF0077b6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF10002b), Color(0xFF240046), Color(0xFF7b2d8b)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF023e8a), Color(0xFF0077b6), Color(0xFF00b4d8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF1b0000), Color(0xFF3d0000), Color(0xFFb00020)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF003049), Color(0xFF023e7d)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0e0e0e), Color(0xFF1c1c1c), Color(0xFF2e4057)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF2d132c), Color(0xFF810034)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF00005c), Color(0xFF0000ab), Color(0xFF4040ff)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0a001a), Color(0xFF1a0040), Color(0xFF6600cc)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF001219), Color(0xFF005f73), Color(0xFF0a9396)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF1c0a00), Color(0xFF4d2600), Color(0xFF7a3b00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight),
  ];

  static const String _baseUrl = 'https://avishka-tiktok-api.zeabur.app';

  final List<String> _radiusLabels = ['City', 'Country', '🌍 Global', '🔥 Top'];
  final List<double> _radiusValues = [50.0, 500.0, 20000.0, -1.0];
  int _selectedRadius = 0;
  double? _latitude;
  double? _longitude;
  String _cityName = 'Locating…';
  bool _locationReady = false;
  String _detectedCountryName = 'My Country';
  String _detectedCountryCode = '';
  List<_NearbyPost> _posts = [];
  bool _loading = false;
  String? _errorMessage;
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollCtrl = ScrollController();

  // ── NEW: Internet & skeleton ───────────────────────────────────────────────
  bool _hasInternet         = true;
  bool _showNoInternetToast = false;

  // ── NEW: Seen-post tracking ────────────────────────────────────────────────
  final Set<String> _seenPostIds = {};

  // ── NEW: Top tab data ──────────────────────────────────────────────────────
  List<_NearbyPost> _topPosts   = [];
  bool              _topLoading = false;
  bool              _isTopTab   = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _initLocation();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300
        && !_loadingMore && _hasMore) {
      _loadMorePosts();
    }
  }

  // ── NEW: Internet check ────────────────────────────────────────────────────
  Future<bool> _checkInternetNearby() async {
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

  // ── NEW: Mark posts seen ───────────────────────────────────────────────────
  Future<void> _markPostsSeen(List<String> postIds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || postIds.isEmpty) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/text-posts/mark-seen'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': user.uid, 'postIds': postIds}),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  // ── NEW: Fetch Top posts ───────────────────────────────────────────────────
  Future<void> _fetchTopPosts() async {
    if (!await _checkInternetNearby()) return;
    setState(() => _topLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    try {
      final uri = Uri.parse('$_baseUrl/api/text-posts/top').replace(
        queryParameters: {
          'latitude'  : '$_latitude',
          'longitude' : '$_longitude',
          'radiusKm'  : '20000',
          'limit'     : '20',
          if (user != null) 'uid': user.uid,
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        final data = body['data'] as List<dynamic>;
        setState(() {
          _topPosts   = data.map((e) => _NearbyPost.fromJson(e)).toList();
          _topLoading = false;
        });
        _markPostsSeen(_topPosts.map((p) => p.id).toList());
      } else {
        setState(() => _topLoading = false);
      }
    } catch (_) {
      setState(() => _topLoading = false);
    }
  }

  void _openCountryView() {
    if (_latitude == null || _longitude == null) return;

    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, animation, __) =>
          ThogarCountryScreen(
            userLatitude: _latitude!,
            userLongitude: _longitude!,
            userCityName: _cityName,
            countryName: _detectedCountryName,
            countryCode: _detectedCountryCode,
          ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(1, 0), end: Offset.zero)
                  .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
    ));
  }

  void _openGlobalView() {
    if (_latitude == null || _longitude == null) return;
    debugPrint('🌍 Global View');

    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, animation, __) =>
          ThogarGlobalScreen(
            userLatitude: _latitude!,
            userLongitude: _longitude!,
          ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(1, 0), end: Offset.zero)
                  .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
    ));
  }

  void _openLike(_NearbyPost post) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('🔒 [NearbyFeed] Like blocked: User not authenticated');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to like'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ThogarLike.showLikedBySheet(context, post.id, post.likeCount);
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

  void _openShare(_NearbyPost post) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to share'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    ThogarShare.showShareSheet(
      context: context,
      postId: post.id,
      content: post.content,
      cityName: post.cityName,
      isAnonymous: post.isAnonymous,
      username: post.username,
    );
  }

  void _openRepost(_NearbyPost post) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to repost'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    await ThogarRepost.showRepostSheet(
      context: context,
      post: ThogarRepostPost(
        id: post.id,
        content: post.content,
        cityName: post.cityName,
        isAnonymous: post.isAnonymous,
        username: post.username,
        avatarUrl: post.avatarUrl,
        repostCount: post.repostCount,
      ),
    );
  }

  void _openComments(_NearbyPost post) async {
    HapticFeedback.lightImpact();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to comment'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw const SocketException('No address');
      }
    } on Exception catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            ThoughtCommentsScreen(
              post: ThoughtPost(
                id: post.id,
                username: post.username,
                avatarUrl: post.avatarUrl,
                content: post.content,
                createdAt: DateTime.now(),
                isAnonymous: post.isAnonymous,
              ),
              currentUserId: currentUser.uid,
              currentUsername:
              currentUser.displayName ?? currentUser.email ?? 'User',
              currentAvatarUrl: currentUser.photoURL,
            ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            ),
      ),
    );
  }

  Future<void> _initLocation() async {
    if (!await _checkInternetNearby()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    // ✅ CACHED LOCATION CHECK — GPS call skip කරනවා
    final cache = LocationCacheService.instance;
    final loaded = cache.hasCachedLocation || await cache.loadFromPrefs();

    if (loaded) {
      // Cache හිටියා — GPS ඉල්ලන්නේ නෑ, සෙකන්ඩ් 0 delay
      _latitude            = cache.latitude;
      _longitude           = cache.longitude;
      _cityName            = cache.city;
      _detectedCountryName = cache.countryName.isNotEmpty
          ? cache.countryName
          : 'My Country';
      _detectedCountryCode = cache.countryCode;

      setState(() => _locationReady = true);
      await _fetchNearbyPosts();
      return;
    }

    // Cache නෑ — GPS fetch (first time only)
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are off.';
          _loading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permission denied.';
          _loading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );

      _latitude  = position.latitude;
      _longitude = position.longitude;

      String city        = 'Nearby';
      String countryName = 'My Country';
      String countryCode = '';

      try {
        final p = await placemarkFromCoordinates(_latitude!, _longitude!);
        if (p.isNotEmpty) {
          city = p.first.locality?.isNotEmpty == true
              ? p.first.locality!
              : (p.first.subAdministrativeArea ?? 'Nearby');
          countryName = p.first.country        ?? 'My Country';
          countryCode = p.first.isoCountryCode ?? '';
        }
      } catch (_) {}

      // ✅ Save to cache
      await LocationCacheService.instance.saveLocation(
        latitude   : _latitude!,
        longitude  : _longitude!,
        city       : city,
        countryName: countryName,
        countryCode: countryCode,
      );

      _cityName            = city;
      _detectedCountryName = countryName;
      _detectedCountryCode = countryCode;

      setState(() => _locationReady = true);
      await _fetchNearbyPosts();
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() {
        _errorMessage = 'Could not get location. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _fetchNearbyPosts() async {
    // ── NEW: internet check ──────────────────────────────────────────────────
    if (!await _checkInternetNearby()) return;

    setState(() {
      _page = 0;
      _hasMore = true;
      _posts = [];
      _loading = true;
    });
    await _loadPostsPage(reset: true);
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
    });
    _page++;
    await _loadPostsPage(reset: false);
  }

  Future<void> _loadPostsPage({required bool reset}) async {
    if (_latitude == null || _longitude == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    final radiusKm = _radiusValues[_selectedRadius];
    final effectiveRadius = radiusKm < 0 ? 20000.0 : radiusKm;

    try {
      final uri = Uri.parse('$_baseUrl/api/text-posts/nearby').replace(
          queryParameters: {
            'latitude': '$_latitude',
            'longitude': '$_longitude',
            'radiusKm': '$effectiveRadius',
            'limit': '10',
            'page': '$_page',
            if (radiusKm < 0) 'sort': 'top',
            if (currentUser != null) 'uid': currentUser.uid,
          });

      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as List<dynamic>;
        final newPosts = data.map((e) => _NearbyPost.fromJson(e)).toList();
        setState(() {
          if (reset)
            _posts = newPosts;
          else
            _posts.addAll(newPosts);
          _hasMore = newPosts.length == 10;
          _loading = false;
          _loadingMore = false;
        });
        // ── NEW: mark seen ─────────────────────────────────────────────────
        _markPostsSeen(newPosts.map((p) => p.id).toList());
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0f),
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0a0a0f),
            elevation: 0,
            pinned: true,
            automaticallyImplyLeading: false,
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.25)),
                ),
                child: const Icon(Icons.near_me_rounded,
                    color: Colors.redAccent, size: 18),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Nearby',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3)),
                Row(children: [
                  const Icon(Icons.location_on_rounded,
                      size: 10, color: Colors.redAccent),
                  const SizedBox(width: 2),
                  Text(
                    _cityName,
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ]),
              ]),
            ]),

            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        color: Colors.white70, size: 18),
                  ),
                  onPressed: _locationReady ? _fetchNearbyPosts : _initLocation,
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(child: _buildRadiusChips()),

          // ── NEW: skeleton loader replaces spinner ────────────────────────
          if (_loading || _topLoading)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, __) => const _SkeletonCard(),
                childCount: 5,
              ),
            )
          else if (_errorMessage != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off_rounded,
                          color: Colors.white38, size: 48),
                      const SizedBox(height: 16),
                      Text(_errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 14)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                            Colors.redAccent.withOpacity(0.15),
                            foregroundColor: Colors.white),
                        onPressed: _initLocation,
                        icon: const Icon(Icons.my_location_rounded, size: 16),
                        label: const Text('Try again'),
                      ),
                    ]),
              ),
            )
          else if ((_isTopTab ? _topPosts : _posts).isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.near_me_disabled_rounded,
                            color: Colors.white24, size: 56),
                        const SizedBox(height: 16),
                        Text(
                          'No vibes within ${_radiusLabels[_selectedRadius]}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        const Text('Be the first to post!',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 13)),
                      ]),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  // ── NEW: switch between normal and top posts ───────────────
                  final post = _isTopTab ? _topPosts[index] : _posts[index];
                  final gradient = _gradients[
                  post.gradientIndex.clamp(0, _gradients.length - 1)];
                  return NearbyPostCard(
                    postId: post.id,
                    username: post.username,
                    avatarUrl: post.avatarUrl,   // ← මේ line add කරන්න
                    content: post.content,
                    distanceLabel: post.distanceLabel,
                    city: post.cityName,
                    postGradient: gradient,
                    isAnonymous: post.isAnonymous,
                    likeCount: post.likeCount,
                    isLiked: post.isLiked,
                    isReposted: post.isReposted,
                    commentCount: post.commentCount,
                    repostCount: post.repostCount,
                    onComment: () => _openComments(post),
                    onRepost: () => _openRepost(post),
                    onShare: () => _openShare(post),
                    onMoreOptions: () =>
                        ThogarAnymore.showMoreSheet(
                          context: context,
                          postId: post.id,
                          postOwnerId: post.uid,
                          content: post.content,
                          isAnonymous: post.isAnonymous,
                          cityName: post.cityName,
                          username: post.username,
                          avatarUrl: post.avatarUrl,
                          onReport: _reportPost,
                          onDeleted: () {
                            setState(() =>
                                _posts.removeWhere((p) => p.id == post.id));
                          },
                          onEdited: _fetchNearbyPosts,
                        ),
                    onLike: () => _openLike(post),
                  );
                }, childCount: _isTopTab ? _topPosts.length : _posts.length),
              ),

          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(
                    color: Colors.redAccent, strokeWidth: 2)),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildRadiusChips() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _radiusLabels.length,
        itemBuilder: (context, i) {
          if (i >= _radiusLabels.length) return const SizedBox.shrink();

          final active  = _selectedRadius == i;
          final isTop     = _radiusLabels[i].contains('Top');
          final isGlobal  = _radiusLabels[i].contains('Global');
          final isCountry = _radiusLabels[i] == 'Country';

          final Color chipAccent = isTop
              ? Colors.orange
              : isGlobal
              ? const Color(0xFF7C4DFF)
              : Colors.redAccent;

          return GestureDetector(
            // ── NEW: full onTap with Top support ──────────────────────────
            onTap: () {
              setState(() => _selectedRadius = i);
              if (!_locationReady) return;
              if (isCountry) { _openCountryView(); return; }
              if (isGlobal)  { _openGlobalView();  return; }
              if (isTop) {
                setState(() => _isTopTab = true);
                _fetchTopPosts();
                return;
              }
              setState(() => _isTopTab = false);
              _fetchNearbyPosts();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? chipAccent.withOpacity(0.85)
                    : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? chipAccent
                      : (isGlobal || isTop)
                      ? chipAccent.withOpacity(0.35)
                      : Colors.white.withOpacity(0.12),
                ),
              ),
              child: Text(
                _radiusLabels[i],
                style: TextStyle(
                  color: active
                      ? Colors.white
                      : (isGlobal || isTop)
                      ? chipAccent.withOpacity(0.85)
                      : Colors.white60,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Data model
// ─────────────────────────────────────────────────────────────────────────────
class _NearbyPost {
  const _NearbyPost({
    required this.id,
    required this.uid,
    required this.username,
    required this.content,
    required this.distanceLabel,
    required this.cityName,
    required this.gradientIndex,
    required this.isAnonymous,
    required this.likeCount,
    required this.commentCount,
    required this.repostCount,
    required this.latitude,
    required this.longitude,
    required this.isLiked,
    required this.isReposted,
    this.avatarUrl,
  });

  final String  id;
  final String  uid;
  final String  username;
  final String  content;
  final String  distanceLabel;
  final String  cityName;
  final int     gradientIndex;
  final bool    isAnonymous;
  final int     likeCount;
  final int     commentCount;
  final int     repostCount;
  final double  latitude;
  final double  longitude;
  final String? avatarUrl;
  final bool isLiked;
  final bool isReposted;

  factory _NearbyPost.fromJson(Map<String, dynamic> json) => _NearbyPost(
    id            : json['id']            as String? ?? '',
    uid           : json['uid']           as String? ?? '',
    username      : json['username']      as String? ?? 'Unknown',
    content       : json['content']       as String? ?? '',
    distanceLabel : json['distanceLabel'] as String? ?? '',
    cityName      : json['cityName']      as String? ?? 'Nearby',
    gradientIndex : (json['gradientIndex'] as num?)?.toInt() ?? 0,
    isAnonymous   : json['isAnonymous']   as bool?   ?? false,
    likeCount     : (json['likeCount']    as num?)?.toInt() ?? 0,
    commentCount  : (json['commentCount'] as num?)?.toInt() ?? 0,
    repostCount   : (json['repostCount']  as num?)?.toInt() ?? 0,
    latitude      : (json['latitude']     as num?)?.toDouble() ?? 0.0,
    longitude     : (json['longitude']    as num?)?.toDouble() ?? 0.0,
    avatarUrl     : json['avatarUrl']     as String?,
    isLiked       : json['isLiked']       as bool? ?? false,
    isReposted    : json['isReposted']    as bool? ?? false,
  );
}