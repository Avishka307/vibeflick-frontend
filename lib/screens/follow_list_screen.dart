import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ══════════════════════════════════════════════════════════════
// follow_list_screen.dart  —  Full Screen version
// ══════════════════════════════════════════════════════════════

class FollowListScreen extends StatefulWidget {
  final String type;
  final String targetUserId;
  final String? currentUserId;
  final FirebaseFirestore db;
  final Future<void> Function(String userId, String username)? onFollowTap;

  // targetUsername pass කළොත් AppBar title — නැත්නම් Firestore ගේනවා
  final String? targetUsername;

  const FollowListScreen({
    Key? key,
    required this.type,
    required this.targetUserId,
    required this.currentUserId,
    required this.db,
    this.onFollowTap,
    this.targetUsername,
  }) : super(key: key);

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _resolvedUsername; // Firestore ගෙන් ලැබෙන username

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.type == 'followers' ? 0 : 1;
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: initialIndex);

    // targetUsername pass නොකළොත් Firestore ගේනවා
    if (widget.targetUsername != null) {
      _resolvedUsername = widget.targetUsername;
    } else {
      _loadUsername();
    }
  }

  Future<void> _loadUsername() async {
    try {
      final doc = await widget.db
          .collection('users')
          .doc(widget.targetUserId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _resolvedUsername =
              doc.data()?['username'] as String? ?? widget.targetUserId;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _resolvedUsername != null
        ? '@$_resolvedUsername'
        : '@...';

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFF3B5C),
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF555555),
                labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w400),
                tabs: const [
                  Tab(text: 'Followers'),
                  Tab(text: 'Following'),
                ],
              ),
              const Divider(
                  color: Color(0xFF2A2A2A), height: 1, thickness: 1),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FollowTab(
            type: 'followers',
            targetUserId: widget.targetUserId,
            currentUserId: widget.currentUserId,
            db: widget.db,
            onFollowTap: widget.onFollowTap,
          ),
          _FollowTab(
            type: 'following',
            targetUserId: widget.targetUserId,
            currentUserId: widget.currentUserId,
            db: widget.db,
            onFollowTap: widget.onFollowTap,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Single tab — paging + scroll + search + error handling
// ══════════════════════════════════════════════════════════════
class _FollowTab extends StatefulWidget {
  final String type;
  final String targetUserId;
  final String? currentUserId;
  final FirebaseFirestore db;
  final Future<void> Function(String userId, String username)? onFollowTap;

  const _FollowTab({
    required this.type,
    required this.targetUserId,
    required this.currentUserId,
    required this.db,
    this.onFollowTap,
  });

  @override
  State<_FollowTab> createState() => _FollowTabState();
}

class _FollowTabState extends State<_FollowTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<Map<String, dynamic>> _allUsers = [];  // full list
  List<Map<String, dynamic>> _filteredUsers = [];   // search filtered
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  bool _isNetworkError = false;
  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 5;
  static const int _maxUsers = 50;

  @override
  void initState() {
    super.initState();
    _fetchBatch();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _searchQuery = q;
      if (q.isEmpty) {
        _filteredUsers = List.from(_allUsers);
      } else {
        _filteredUsers = _allUsers.where((u) {
          final name = (u['name'] as String).toLowerCase();
          final username = (u['username'] as String).toLowerCase();
          return name.contains(q) || username.contains(q);
        }).toList();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      if (_hasMore && !_isLoadingMore && _searchQuery.isEmpty) _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _fetchBatch();
    if (mounted) setState(() => _isLoadingMore = false);
  }

  Future<void> _retry() async {
    setState(() {
      _allUsers.clear();
      _filteredUsers.clear();
      _lastDoc = null;
      _hasMore = true;
      _isLoading = true;
      _hasError = false;
      _isNetworkError = false;
    });
    await _fetchBatch();
  }

  Future<void> _fetchBatch() async {
    if (_allUsers.length >= _maxUsers) {
      if (mounted) setState(() => _hasMore = false);
      return;
    }

    final remaining = _maxUsers - _allUsers.length;
    final limit = remaining < _pageSize ? remaining : _pageSize;

    try {
      Query query;

      if (widget.type == 'followers') {
        query = widget.db
            .collection('follows')
            .where('followingId', isEqualTo: widget.targetUserId)
            .where('status', isEqualTo: 'active')
            .orderBy('timestamp', descending: true)
            .limit(limit);
      } else {
        query = widget.db
            .collection('follows')
            .where('followerId', isEqualTo: widget.targetUserId)
            .where('status', isEqualTo: 'active')
            .orderBy('timestamp', descending: true)
            .limit(limit);
      }

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot =
      await query.get().timeout(const Duration(seconds: 10));

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _hasMore = false;
            _isLoading = false;
          });
        }
        return;
      }

      _lastDoc = snapshot.docs.last;

      final List<Map<String, dynamic>> newUsers = [];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = widget.type == 'followers'
            ? data['followerId'] as String?
            : data['followingId'] as String?;
        if (userId == null) continue;

        final userDoc = await widget.db
            .collection('users')
            .doc(userId)
            .get()
            .timeout(const Duration(seconds: 10));

        if (!userDoc.exists) continue;

        final ud = userDoc.data()!;
        newUsers.add({
          'userId': userId,
          'name': ud['name'] ?? 'User',
          'username': ud['username'] ?? userId,
          'profileUrl': ud['profile_picture_url'] ??
              ud['profile_url'] ??
              ud['profileImageUrl'],
        });
      }

      if (mounted) {
        setState(() {
          _allUsers.addAll(newUsers);
          // Re-apply search filter
          if (_searchQuery.isEmpty) {
            _filteredUsers = List.from(_allUsers);
          } else {
            _filteredUsers = _allUsers.where((u) {
              final name = (u['name'] as String).toLowerCase();
              final username = (u['username'] as String).toLowerCase();
              return name.contains(_searchQuery) ||
                  username.contains(_searchQuery);
            }).toList();
          }
          final reachedMax = _allUsers.length >= _maxUsers;
          final noMore = snapshot.docs.length < limit;
          _hasMore = !reachedMax && !noMore;
          _isLoading = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _isNetworkError = true;
        });
      }
    } catch (e) {
      debugPrint('❌ _FollowTab fetch error: $e');
      final msg = e.toString().toLowerCase();
      final isNet = msg.contains('network') ||
          msg.contains('unavailable') ||
          msg.contains('socket') ||
          msg.contains('connection') ||
          msg.contains('timeout') ||
          msg.contains('host');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _isNetworkError = isNet;
        });
      }
    }
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isFollowers = widget.type == 'followers';

    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF3B5C)));
    }
    if (_hasError) return _buildErrorState();

    return Column(
      children: [
        // ── Search bar ──
        _buildSearchBar(),

        // ── List ──
        Expanded(
          child: _filteredUsers.isEmpty
              ? _buildEmptyState(isFollowers)
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            itemCount:
            _filteredUsers.length + (_hasMore && _searchQuery.isEmpty ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _filteredUsers.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF3B5C), strokeWidth: 2),
                  ),
                );
              }
              return _buildUserTile(_filteredUsers[i]);
            },
          ),
        ),
      ],
    );
  }

  // ── Search bar ──
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search_rounded,
              color: Color(0xFF555555), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.type == 'followers'
                    ? 'Search followers...'
                    : 'Search following...',
                hintStyle: const TextStyle(
                    color: Color(0xFF555555), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
              cursorColor: const Color(0xFFFF3B5C),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.close_rounded,
                    color: Color(0xFF555555), size: 18),
              ),
            ),
        ],
      ),
    );
  }

  // ── Error state ──
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: Color(0xFF2A2A2A), shape: BoxShape.circle),
              child: Icon(
                _isNetworkError
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                color: const Color(0xFF555555),
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isNetworkError ? 'No Connection' : 'Something went wrong',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isNetworkError
                  ? 'Check your internet connection and try again.'
                  : "We couldn't load this list. Please try again.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF666666), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _retry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF3B5C),
                    borderRadius: BorderRadius.circular(24)),
                child: const Text('Try Again',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ──
  Widget _buildEmptyState(bool isFollowers) {
    final isSearchEmpty = _searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearchEmpty
                ? Icons.search_off_rounded
                : (isFollowers
                ? Icons.people_outline
                : Icons.person_add_alt_1_outlined),
            color: const Color(0xFF333333),
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            isSearchEmpty
                ? 'No results for "$_searchQuery"'
                : (isFollowers ? 'No followers yet' : 'Not following anyone'),
            style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 16,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          if (!isSearchEmpty)
            Text(
              isFollowers
                  ? 'When someone follows, they appear here'
                  : 'Followed accounts appear here',
              style: const TextStyle(
                  color: Color(0xFF444444), fontSize: 13),
            ),
        ],
      ),
    );
  }

  // ── User tile ──
  Widget _buildUserTile(Map<String, dynamic> user) {
    final name = user['name'] as String;
    final username = user['username'] as String;
    final profileUrl = user['profileUrl'] as String?;
    final userId = user['userId'] as String;
    final isMe = userId == widget.currentUserId;
    final isFollowersTab = widget.type == 'followers';

    final initials = _initials(name);
    final bgColor = _avatarColor(name);

    Widget avatarFallback = Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
    );

    Widget avatar = avatarFallback;
    if (profileUrl != null && profileUrl.isNotEmpty) {
      avatar = ClipOval(
        child: CachedNetworkImage(
          imageUrl: profileUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          placeholder: (_, __) => avatarFallback,
          errorWidget: (_, __, ___) => avatarFallback,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
              Border.all(color: const Color(0xFF2C2C2C), width: 1),
            ),
            child: ClipOval(child: avatar),
          ),
          const SizedBox(width: 12),

          // Name + username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('@$username',
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),

          // Right side button
          if (!isMe && widget.onFollowTap != null)
            isFollowersTab
                ? _buildFollowBackButton(userId, name)
                : _buildFollowingSection(userId, name),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // FOLLOWERS TAB → "Follow Back" button
  // ══════════════════════════════════════════════════════════
  Widget _buildFollowBackButton(String userId, String userName) {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.db
          .collection('follows')
          .doc('${widget.currentUserId}_$userId')
          .snapshots(),
      builder: (context, snap) {
        final isFollowingBack =
            snap.hasData && snap.data != null && snap.data!.exists;

        return GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            if (isFollowingBack) {
              final confirm = await _showUnfollowDialog(userName);
              if (confirm == true) {
                widget.onFollowTap?.call(userId, userName);
              }
            } else {
              widget.onFollowTap?.call(userId, userName);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isFollowingBack
                  ? const Color(0xFF2C2C2C)
                  : const Color(0xFFFF3B5C),
              borderRadius: BorderRadius.circular(20),
              border: isFollowingBack
                  ? Border.all(color: const Color(0xFF3A3A3A), width: 1)
                  : null,
            ),
            child: Text(
              isFollowingBack ? 'Following' : 'Follow Back',
              style: TextStyle(
                color: isFollowingBack
                    ? const Color(0xFF888888)
                    : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  // FOLLOWING TAB → green label + Unfollow/Follow button
  // ══════════════════════════════════════════════════════════
  Widget _buildFollowingSection(String userId, String userName) {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.db
          .collection('follows')
          .doc('${widget.currentUserId}_$userId')
          .snapshots(),
      builder: (context, snap) {
        final isFollowing =
            snap.hasData && snap.data != null && snap.data!.exists;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFollowing) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF2A4A2A), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_rounded,
                        color: Color(0xFF4CAF50), size: 12),
                    SizedBox(width: 4),
                    Text('Following',
                        style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onTap: () async {
                HapticFeedback.lightImpact();
                if (isFollowing) {
                  final confirm = await _showUnfollowDialog(userName);
                  if (confirm == true) {
                    widget.onFollowTap?.call(userId, userName);
                  }
                } else {
                  widget.onFollowTap?.call(userId, userName);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isFollowing
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFFF3B5C),
                  borderRadius: BorderRadius.circular(20),
                  border: isFollowing
                      ? Border.all(
                      color: const Color(0xFF3A3A3A), width: 1)
                      : null,
                ),
                child: Text(
                  isFollowing ? 'Unfollow' : 'Follow',
                  style: TextStyle(
                    color: isFollowing
                        ? const Color(0xFF888888)
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Unfollow dialog ──
  Future<bool?> _showUnfollowDialog(String userName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Unfollow?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to unfollow @$userName?',
          style:
          const TextStyle(color: Color(0xFF888888), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unfollow',
                style: TextStyle(
                    color: Color(0xFFFF3B5C),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──
  String _initials(String name) {
    if (name.isEmpty) return 'U';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words.last[0]}'.toUpperCase();
    }
    return name.substring(0, min(2, name.length)).toUpperCase();
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF3B82F6),
      Color(0xFFE53935),
      Color(0xFF10B981),
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}