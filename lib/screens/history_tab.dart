import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'post_detail_page.dart'; // ✅ PostDetailPage navigate කරන්න

class HistoryTab extends StatefulWidget {
  const HistoryTab({Key? key}) : super(key: key);

  @override
  State<HistoryTab> createState() => HistoryTabState();
}

// ✅ GlobalKey helper - SocialCardsTabs ගොනුවෙන් refresh call කරන්න

class HistoryTabState extends State<HistoryTab> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentUserId;

  // 📄 Pagination
  List<Map<String, dynamic>> _historyItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 15;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _loadHistory();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _loadMoreHistory();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  //  DATA FETCHING
  // ──────────────────────────────────────────────

  // ✅ Public method - SocialCardsTabs ගොනුවෙන් call කරන්න
  Future<void> loadHistory() => _loadHistory();

  Future<void> _loadHistory() async {
    if (_currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _historyItems = [];
        _lastDocument = null;
        _hasMore = true;
      });

      final snapshot = await _db
          .collection('media_posts')
          .doc('placeholder') // ← replaced below
          .collection('views')
          .limit(1)
          .get(); // dummy — real query is below ↓

      // ✅ REAL QUERY: user's view records across all posts
      // We store per-post views, so we need a top-level collection.
      // Assumes a top-level `user_history` collection keyed by userId.
      final query = await _db
          .collection('user_history')
          .doc(_currentUserId)
          .collection('watched')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize)
          .get();

      final items = await _buildHistoryItems(query.docs);

      setState(() {
        _historyItems = items;
        _isLoading = false;
        _lastDocument = query.docs.isNotEmpty ? query.docs.last : null;
        _hasMore = query.docs.length >= _pageSize;
      });

      debugPrint('✅ History loaded: ${_historyItems.length} items');
    } catch (e) {
      debugPrint('❌ Error loading history: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_currentUserId == null || _lastDocument == null || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final query = await _db
          .collection('user_history')
          .doc(_currentUserId)
          .collection('watched')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      final items = await _buildHistoryItems(query.docs);

      setState(() {
        _historyItems.addAll(items);
        _isLoadingMore = false;
        _lastDocument = query.docs.isNotEmpty ? query.docs.last : null;
        _hasMore = query.docs.length >= _pageSize;
      });

      debugPrint('✅ More history loaded: ${items.length} items');
    } catch (e) {
      debugPrint('❌ Error loading more history: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  /// History doc -> post data fetch කරනවා
  Future<List<Map<String, dynamic>>> _buildHistoryItems(
      List<QueryDocumentSnapshot> docs) async {
    final items = <Map<String, dynamic>>[];

    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final postId = data['postId'] as String?;
        if (postId == null) continue;

        final postDoc =
        await _db.collection('media_posts').doc(postId).get();

        if (!postDoc.exists) continue;

        final postData = postDoc.data() as Map<String, dynamic>;
        postData['id'] = postDoc.id;
        postData['watchedAt'] = data['timestamp'];

        items.add(postData);
      } catch (e) {
        debugPrint('⚠️ Error fetching post for history item: $e');
      }
    }

    return items;
  }

  // ──────────────────────────────────────────────
  //  DELETE / CLEAR
  // ──────────────────────────────────────────────

  Future<void> _removeHistoryItem(String postId) async {
    if (_currentUserId == null) return;

    try {
      await _db
          .collection('user_history')
          .doc(_currentUserId)
          .collection('watched')
          .where('postId', isEqualTo: postId)
          .get()
          .then((snap) async {
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      });

      setState(() {
        _historyItems.removeWhere((item) => item['id'] == postId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from history'),
            backgroundColor: Color(0xFF2C2C2C),
            duration: Duration(seconds: 2),
          ),
        );
      }

      debugPrint('✅ Removed from history: $postId');
    } catch (e) {
      debugPrint('❌ Error removing history item: $e');
    }
  }

  Future<void> _clearAllHistory() async {
    if (_currentUserId == null) return;

    final confirmed = await _showClearConfirmDialog();
    if (!confirmed) return;

    try {
      final batch = _db.batch();
      final snap = await _db
          .collection('user_history')
          .doc(_currentUserId)
          .collection('watched')
          .get();

      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      setState(() {
        _historyItems.clear();
        _hasMore = false;
        _lastDocument = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('History cleared'),
            backgroundColor: Color(0xFF2C2C2C),
            duration: Duration(seconds: 2),
          ),
        );
      }

      debugPrint('✅ All history cleared');
    } catch (e) {
      debugPrint('❌ Error clearing history: $e');
    }
  }

  Future<bool> _showClearConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B5C),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Clear All History?',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text(
                'This will permanently remove your entire watch history.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B5C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Clear All',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C2C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    ) ??
        false;
  }

  // ──────────────────────────────────────────────
  //  NAVIGATION
  // ──────────────────────────────────────────────

  void _openPost(Map<String, dynamic> post) {
    final postId = post['id'] as String?;
    if (postId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(postId: postId),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  HELPER
  // ──────────────────────────────────────────────

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return '';
    }
    return timeago.format(dt);
  }

  // ──────────────────────────────────────────────
  //  SHIMMER
  // ──────────────────────────────────────────────

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[900]!,
        highlightColor: Colors.grey[700]!,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              // Thumbnail placeholder
              Container(
                width: 72,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  EMPTY STATE
  // ──────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.1), width: 1.5),
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 52,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Watch History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Videos you watch will appear here',
            style: TextStyle(fontSize: 14, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  HISTORY ITEM CARD
  // ──────────────────────────────────────────────

  Widget _buildHistoryItem(Map<String, dynamic> post) {
    final postId = post['id'] as String? ?? '';
    final username = post['username'] as String? ?? 'Unknown';
    final description = post['description'] as String? ?? '';
    final thumbnailUrl = post['thumbnail_url'] as String?;
    final mediaUrl = post['media_url'] as String? ?? '';
    final isVideo = post['type'] == 'video';
    final watchedAt = post['watchedAt'];
    final timeAgo = _formatTimeAgo(watchedAt);

    // Thumbnail fallback for images
    // ✅ මේකෙන් REPLACE කරන්න
    final displayThumbnail = (isVideo && (thumbnailUrl ?? '').isNotEmpty)
        ? thumbnailUrl!
        : mediaUrl;

    return GestureDetector(
      onTap: () => _openPost(post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ──────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  SizedBox(
                    width: 72,
                    height: 96,
                    child: displayThumbnail != null
                        ? Image.network(
                      displayThumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _thumbnailFallback(username),
                    )
                        : _thumbnailFallback(username),
                  ),

                  // video badge
                  if (isVideo)
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // ── Info ───────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // username row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: const Color(0xFFFF3B5C),
                        child: Text(
                          username.isNotEmpty
                              ? username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '@$username',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFAAAAAA),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // description
                  Text(
                    description.isNotEmpty ? description : '(no caption)',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // bottom row: time ago + type badge
                  Row(
                    children: [
                      if (timeAgo.isNotEmpty) ...[
                        const Icon(Icons.access_time_rounded,
                            size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text(
                          timeAgo,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white38),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isVideo
                              ? const Color(0xFFFF3B5C).withOpacity(0.15)
                              : Colors.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isVideo
                                ? const Color(0xFFFF3B5C).withOpacity(0.3)
                                : Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          isVideo ? '▶ Video' : '🖼 Image',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isVideo
                                ? const Color(0xFFFF3B5C)
                                : Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Remove button ──────────────────────
            GestureDetector(
              onTap: () => _removeHistoryItem(postId),
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.close_rounded,
                    size: 18, color: Colors.white.withOpacity(0.3)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnailFallback(String username) {
    return Container(
      width: 72,
      height: 96,
      color: const Color(0xFF2A2A2A),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white54,
              fontSize: 24,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Scaffold + extra top padding ඉවත් කළා
    // SocialCardsTabs > TabBarView ඇතුළේ embed වෙන නිසා
    // Scaffold/AppBar/header padding කිසිවක් එපා
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // ── Clear All row (history items ඇත්නම් පමණයි) ──
          if (_historyItems.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  Text(
                    '${_historyItems.length} watched',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _clearAllHistory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.12)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFFF3B5C), size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Clear All',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF3B5C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF222222), height: 1),
          ],

          // ── Body ─────────────────────────────────
          Expanded(
            child: _isLoading
                ? _buildShimmerList()
                : _historyItems.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadHistory,
              backgroundColor: const Color(0xFF1E1E1E),
              color: const Color(0xFFFF3B5C),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                itemCount:
                _historyItems.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _historyItems.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white38,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    );
                  }
                  return _buildHistoryItem(_historyItems[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}