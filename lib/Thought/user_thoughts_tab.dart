import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;

// ─────────────────────────────────────────────────────────────────────────────
//  UserThoughtsTab
//
//  isOwner = true  → shows ALL posts (Public + anonymous) with 🔒 on anonymous
//  isOwner = false → shows only Public + non-anonymous posts
// ─────────────────────────────────────────────────────────────────────────────
class UserThoughtsTab extends StatelessWidget {
  final String userId;
  final bool isOwner;

  const UserThoughtsTab({
    Key? key,
    required this.userId,
    required this.isOwner,
  }) : super(key: key);

  // Sync with CreateTextPostScreen / NearbyFeedScreen
  static const List<LinearGradient> _gradients = [
    LinearGradient(
        colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF2d1b69), Color(0xFF11998e)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF1a1a2e), Color(0xFF6b2d5e)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(
        colors: [Color(0xFF1a0a00), Color(0xFF5c3a00), Color(0xFF8b5e00)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
  ];

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('text_posts')
        .where('uid', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    // Public view: only non-anonymous Public posts
    if (!isOwner) {
      query = query
          .where('privacyMode', isEqualTo: 'Public')
          .where('isAnonymous', isEqualTo: false);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 60),
              child: CircularProgressIndicator(
                  color: Color(0xFFFF3B5C), strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Could not load thoughts.',
                style: const TextStyle(color: Color(0xFF666666), fontSize: 14),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note_rounded,
                      color: const Color(0xFF333333), size: 52),
                  const SizedBox(height: 14),
                  Text(
                    isOwner
                        ? 'No thoughts yet.\nShare what\'s on your mind!'
                        : 'No public thoughts yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF555555), fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final gradientIdx =
            ((data['gradientIndex'] as int?) ?? 0).clamp(0, _gradients.length - 1);
            final isAnon = data['isAnonymous'] as bool? ?? false;

            return _ThoughtCard(
              data: data,
              gradient: _gradients[gradientIdx],
              showAnonymousBadge: isOwner && isAnon,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ThoughtCard — compact version of NearbyPostCard for profile view
// ─────────────────────────────────────────────────────────────────────────────
class _ThoughtCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final LinearGradient gradient;
  final bool showAnonymousBadge; // owner viewing their own anonymous post

  const _ThoughtCard({
    required this.data,
    required this.gradient,
    required this.showAnonymousBadge,
  });

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n > 0 ? '$n' : '0';
  }

  String _timeLabel(dynamic ts) {
    if (ts == null) return '';
    try {
      final ms = ts is int ? ts : (ts as Timestamp).millisecondsSinceEpoch;
      return timeago.format(DateTime.fromMillisecondsSinceEpoch(ms));
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = data['content'] as String? ?? '';
    final city = data['cityName'] as String? ?? '';
    final privacy = data['privacyMode'] as String? ?? 'Public';
    final likes = (data['likeCount'] as int?) ?? 0;
    final comments = (data['commentCount'] as int?) ?? 0;
    final time = _timeLabel(data['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: badges + time ──────────────────────────────
            Row(
              children: [
                // Anonymous badge (owner only)
                if (showAnonymousBadge) ...[
                  _Badge(
                    icon: Icons.lock_outline,
                    label: 'Anonymous',
                    color: Colors.white.withOpacity(0.25),
                  ),
                  const SizedBox(width: 6),
                ],
                // Privacy mode chip
                _Badge(
                  icon: privacy == 'Public'
                      ? Icons.public_rounded
                      : Icons.near_me_rounded,
                  label: privacy,
                  color: Colors.white.withOpacity(0.15),
                ),
                const Spacer(),
                if (time.isNotEmpty)
                  Text(time,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
              ],
            ),

            const SizedBox(height: 12),

            // ── Content ─────────────────────────────────────────────
            Text(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 12),

            // ── Footer: city + stats ─────────────────────────────────
            Row(
              children: [
                if (city.isNotEmpty) ...[
                  const Icon(Icons.location_on_rounded,
                      color: Colors.redAccent, size: 13),
                  const SizedBox(width: 3),
                  Text(city,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11)),
                  const SizedBox(width: 12),
                ],
                const Icon(Icons.favorite_border_rounded,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(_fmt(likes),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
                const SizedBox(width: 10),
                const Icon(Icons.chat_bubble_outline_rounded,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(_fmt(comments),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}