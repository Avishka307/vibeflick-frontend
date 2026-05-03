import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Import the three tab files ───────────────────────────────────────────────
import 'thought_likes_notification_dart.dart';
import 'thought_replies_notification_dart.dart';
import 'thought_reposts_notification_dart.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  ThoughtVibesScreen — Thought Interactions Notification Hub
//  Tabs: ❤️ Likes | 💬 Replies | 🔁 Reposts
//
//  ✅ FIX: Badge listeners use exact same type strings as tab files:
//     Likes   → 'thought_like'
//     Replies → 'thought_reply'
//     Reposts → 'thought_repost'
// ═════════════════════════════════════════════════════════════════════════════

class ThoughtVibesScreen extends StatefulWidget {
  const ThoughtVibesScreen({super.key});

  @override
  State<ThoughtVibesScreen> createState() => _ThoughtVibesScreenState();
}

class _ThoughtVibesScreenState extends State<ThoughtVibesScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth     _auth       = FirebaseAuth.instance;
  String? _currentUserId;

  // Badge counts
  int _likesCount   = 0;
  int _repliesCount = 0;
  int _repostsCount = 0;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _tabController = TabController(length: 3, vsync: this);
    _setupBadgeListeners();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Real-time badge counts ─────────────────────────────────────────────────
  //
  //  ✅ KEY FIX: Use EXACT same 'type' values as the tab StreamBuilder queries:
  //     ThoughtLikesTab   queries → type == 'thought_like'
  //     ThoughtRepliesTab queries → type == 'thought_reply'
  //     ThoughtRepostsTab queries → type == 'thought_repost'
  //
  //  ❌ OLD (broken): 'like' / 'comment' / 'share'  +  notifCategory filter
  //  ✅ NEW (fixed) : 'thought_like' / 'thought_reply' / 'thought_repost'
  //
  void _setupBadgeListeners() {
    if (_currentUserId == null) return;

    final notifRef = _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('notifications');

    // ❤️ Likes — type == 'thought_like'
    notifRef
        .where('type', isEqualTo: 'thought_like')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((s) {
      if (mounted) setState(() => _likesCount = s.docs.length);
    });

    // 💬 Replies — type == 'thought_reply'
    notifRef
        .where('type', isEqualTo: 'thought_reply')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((s) {
      if (mounted) setState(() => _repliesCount = s.docs.length);
    });

    // 🔁 Reposts — type == 'thought_repost'
    notifRef
        .where('type', isEqualTo: 'thought_repost')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((s) {
      if (mounted) setState(() => _repostsCount = s.docs.length);
    });
  }

  // ── Mark all as read for a tab ─────────────────────────────────────────────
  Future<void> _markTabAsRead(String type) async {
    if (_currentUserId == null) return;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('notifications')
          .where('type', isEqualTo: type)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
      debugPrint('✅ Marked ${snap.docs.length} "$type" notifications as read');
    } catch (e) {
      debugPrint('❌ markTabAsRead error: $e');
    }
  }

  // ── Navigate to ThoughtCommentsScreen ─────────────────────────────────────
  void _navigateToThoughtThread(
      BuildContext context, String postId, String? replyId) {
    debugPrint(
        '💬 Navigate → ThoughtCommentsScreen | postId=$postId | replyId=$replyId');
    // TODO: Replace with your actual navigation:
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (_) => ThoughtCommentsScreen(
    //     post: ThoughtPost(id: postId, ...),
    //     currentUserId: _currentUserId!,
    //     currentUsername: ...,
    //   ),
    // ));
  }

  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0f),
      body: Column(children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // ── ❤️ Likes ── 'thought_like' type ──────────────────────────
              ThoughtLikesTab(
                currentUserId: _currentUserId,
                firestore    : _firestore,
                onVisible    : () => _markTabAsRead('thought_like'),
              ),

              // ── 💬 Replies ── 'thought_reply' type ───────────────────────
              ThoughtRepliesTab(
                currentUserId     : _currentUserId,
                firestore         : _firestore,
                onVisible         : () => _markTabAsRead('thought_reply'),
                onNavigateToThread: (postId, replyId) =>
                    _navigateToThoughtThread(context, postId, replyId),
              ),

              // ── 🔁 Reposts ── 'thought_repost' type ──────────────────────
              ThoughtRepostsTab(
                currentUserId: _currentUserId,
                firestore    : _firestore,
                onVisible    : () => _markTabAsRead('thought_repost'),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final total = _likesCount + _repliesCount + _repostsCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0a0a0f),
        border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(children: [
        // Back button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        // Icon
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6b2d5e), Color(0xFF2d1b69)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF6b2d5e).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Thought Vibes',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3)),
          Text('Your thought interactions',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 11)),
        ]),
        const Spacer(),
        // Total unread badge
        if (total > 0)
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF3B5C), Color(0xFFFF1744)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$total',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }

  // ── Tab Bar ─────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF0a0a0f),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFFF3B5C),
        indicatorWeight: 2,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: [
          _BadgeTab(icon: '❤️', label: 'Likes',   count: _likesCount),
          _BadgeTab(icon: '💬', label: 'Replies', count: _repliesCount),
          _BadgeTab(icon: '🔁', label: 'Reposts', count: _repostsCount),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _BadgeTab — Tab with optional red badge counter
// ─────────────────────────────────────────────────────────────────────────────
class _BadgeTab extends StatelessWidget {
  final String icon;
  final String label;
  final int    count;
  const _BadgeTab(
      {required this.icon, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B5C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ]),
    );
  }
}