import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  🔁  ThoughtRepostsTab — Reposts Notification Tab
//  Dark Glassmorphism | Teal/Green Accent | Anonymous support
//  "Recent" / "Earlier" grouping | Unread Neon Glow | Reach indicator
// ─────────────────────────────────────────────────────────────────────────────

class ThoughtRepostsTab extends StatefulWidget {
  final String? currentUserId;
  final FirebaseFirestore firestore;
  final VoidCallback onVisible;

  const ThoughtRepostsTab({
    super.key,
    required this.currentUserId,
    required this.firestore,
    required this.onVisible,
  });

  @override
  State<ThoughtRepostsTab> createState() => _ThoughtRepostsTabState();
}

class _ThoughtRepostsTabState extends State<ThoughtRepostsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _accentColor     = Color(0xFF11998e);
  static const _accentColorSoft = Color(0xFF38ef7d);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onVisible());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.currentUserId == null) return _emptyRepostsState();

    return StreamBuilder<QuerySnapshot>(
      stream: widget.firestore
          .collection('users')
          .doc(widget.currentUserId)
          .collection('notifications')
          .where('type', isEqualTo: 'thought_repost')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: _accentColor, strokeWidth: 2),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _emptyRepostsState();

        // ── Group: Recent (< 24h) vs Earlier ──────────────────────────────
        final now     = DateTime.now();
        final recent  = <QueryDocumentSnapshot>[];
        final earlier = <QueryDocumentSnapshot>[];

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ts   = data['createdAt'];
          DateTime? dt;
          if (ts is Timestamp) dt = ts.toDate();
          if (dt != null && now.difference(dt).inHours < 24) {
            recent.add(doc);
          } else {
            earlier.add(doc);
          }
        }

        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            if (recent.isNotEmpty) ...[
              _SectionHeader(label: 'Recent',
                  icon: Icons.access_time_rounded,
                  color: _accentColorSoft),
              ...recent.map((d) =>
                  _buildTile(d.data() as Map<String, dynamic>)),
            ],
            if (earlier.isNotEmpty) ...[
              _SectionHeader(label: 'Earlier',
                  icon: Icons.history_rounded, color: Colors.white38),
              ...earlier.map((d) =>
                  _buildTile(d.data() as Map<String, dynamic>)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTile(Map<String, dynamic> data) {
    final isAnon  = data['isAnonymous'] as bool? ?? false;
    final isRead  = data['read']        as bool? ?? true;
    final name    = isAnon
        ? 'Anonymous Vibe'
        : (data['fromUserName'] as String? ?? 'Someone');
    final avatar  = isAnon ? null : data['fromUserAvatar'] as String?;
    final preview = data['thoughtPreview'] as String? ?? '';
    final time    = _timeAgo(data['createdAt']);

    return _RepostNotifTile(
      name        : name,
      avatarUrl   : avatar,
      isAnonymous : isAnon,
      preview     : preview,
      time        : time,
      isRead      : isRead,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tile
// ─────────────────────────────────────────────────────────────────────────────
class _RepostNotifTile extends StatelessWidget {
  final String  name;
  final String? avatarUrl;
  final bool    isAnonymous;
  final String  preview;
  final String  time;
  final bool    isRead;

  static const _accent = Color(0xFF11998e);

  const _RepostNotifTile({
    required this.name,
    required this.avatarUrl,
    required this.isAnonymous,
    required this.preview,
    required this.time,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isRead
            ? Colors.white.withOpacity(0.03)
            : _accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRead
              ? Colors.white.withOpacity(0.06)
              : _accent.withOpacity(0.30),
        ),
        boxShadow: isRead
            ? []
            : [
          BoxShadow(
            color: _accent.withOpacity(0.18),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Avatar ────────────────────────────────────────────────────────
          Stack(children: [
            _buildAvatar(),
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF0a0a0f), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: _accent.withOpacity(0.6),
                        blurRadius: 6),
                  ],
                ),
                child: const Icon(Icons.repeat_rounded,
                    size: 10, color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(width: 12),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + action
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, height: 1.4),
                      children: [
                        TextSpan(
                          text: name,
                          style: TextStyle(
                            color: isAnonymous
                                ? Colors.white60
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: isAnonymous
                              ? ' reposted your thought anonymously'
                              : ' reposted your thought to their feed',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),

                  // Thought preview
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _accent.withOpacity(0.18)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.format_quote_rounded,
                              size: 14,
                              color: _accent.withOpacity(0.5)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              preview.length > 100
                                  ? '${preview.substring(0, 100)}…'
                                  : preview,
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),

                  // ── Reach indicator row ──────────────────────────────────────
                  Row(children: [
                    Icon(Icons.access_time_rounded,
                        size: 11,
                        color: _accent.withOpacity(0.6)),
                    const SizedBox(width: 3),
                    Text(time,
                        style: TextStyle(
                            color: _accent.withOpacity(0.7),
                            fontSize: 11)),
                    const Spacer(),
                    // "Shared to their feed" badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _accent.withOpacity(0.25)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          isAnonymous
                              ? Icons.visibility_off_rounded
                              : Icons.public_rounded,
                          size: 9,
                          color: _accent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isAnonymous ? 'Anonymous' : 'Shared to feed',
                          style: TextStyle(
                              color: _accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ]),
                ]),
          ),

          // ── Unread dot ────────────────────────────────────────────────────
          if (!isRead)
            Container(
              width: 9, height: 9,
              margin: const EdgeInsets.only(top: 4, left: 6),
              decoration: BoxDecoration(
                color: _accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: _accent.withOpacity(0.7),
                      blurRadius: 6,
                      spreadRadius: 1),
                ],
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildAvatar() {
    if (isAnonymous) {
      return Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF0a2e2a), Color(0xFF051a17)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: _accent.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: _accent.withOpacity(0.2), blurRadius: 8),
          ],
        ),
        child: const Icon(Icons.visibility_off_rounded,
            size: 20, color: Colors.white38),
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white.withOpacity(0.08),
      backgroundImage: (avatarUrl != null && avatarUrl!.startsWith('http'))
          ? NetworkImage(avatarUrl!)
          : null,
      child: (avatarUrl == null || !avatarUrl!.startsWith('http'))
          ? const Icon(Icons.person_rounded,
          size: 20, color: Colors.white54)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty State
// ─────────────────────────────────────────────────────────────────────────────
Widget _emptyRepostsState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF11998e).withOpacity(0.08),
            border: Border.all(
                color: const Color(0xFF11998e).withOpacity(0.2)),
          ),
          child: const Icon(Icons.repeat_rounded,
              size: 36, color: Color(0xFF11998e)),
        ),
        const SizedBox(height: 16),
        const Text('No reposts yet',
            style: TextStyle(
                color: Colors.white70, fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('Start sharing your thoughts!',
            style: TextStyle(color: Colors.white30, fontSize: 13)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section Header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionHeader(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label.toUpperCase(),
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
              height: 1, color: color.withOpacity(0.15)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Time helper
// ─────────────────────────────────────────────────────────────────────────────
String _timeAgo(dynamic timestamp) {
  if (timestamp == null) return '';
  if (timestamp is! Timestamp) return '';
  final diff = DateTime.now().difference(timestamp.toDate());
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24)   return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}