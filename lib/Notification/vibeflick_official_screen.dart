import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// VibeFlick Official Screen
/// Displays system notifications fetched in real-time from Firestore.
/// Replaces the previously hard-coded list with a live stream.
class VibeFlickOfficialScreen extends StatefulWidget {
  const VibeFlickOfficialScreen({super.key});

  @override
  State<VibeFlickOfficialScreen> createState() =>
      _VibeFlickOfficialScreenState();
}

class _VibeFlickOfficialScreenState extends State<VibeFlickOfficialScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── icon / colour helpers ────────────────────────────────────────────────

  static const Map<String, IconData> _typeIcons = {
    'welcome': Icons.waving_hand_rounded,
    'enable_notifications': Icons.notifications_active_rounded,
    'community_guidelines': Icons.menu_book_rounded,
    'milestone': Icons.emoji_events_rounded,
    'profile_complete': Icons.verified_user_rounded,
  };

  static const Map<String, Color> _typeColors = {
    'welcome': Color(0xFFE91E8C),
    'enable_notifications': Color(0xFF4CAF50),
    'community_guidelines': Color(0xFF2196F3),
    'milestone': Color(0xFFFF9800),
    'profile_complete': Color(0xFF9C27B0),
  };

  static IconData _iconFor(String type) =>
      _typeIcons[type] ?? Icons.notifications_rounded;

  static Color _colorFor(String type) =>
      _typeColors[type] ?? const Color(0xFFE91E8C);

  // ── mark read ────────────────────────────────────────────────────────────

  Future<void> _markAsRead(String docId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('system_notifications')
        .doc(docId)
        .update({'is_read': true});
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VibeFlick',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Official',
                  style: TextStyle(
                    color: Color(0xFFE91E8C),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                color: Colors.white54, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: uid == null
          ? const Center(
          child: Text('Not signed in',
              style: TextStyle(color: Colors.white54)))
          : StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(uid)
            .collection('system_notifications')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE91E8C),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading notifications',
                style: TextStyle(color: Colors.red[300]),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      color: Colors.white24, size: 64),
                  SizedBox(height: 12),
                  Text(
                    'No notifications yet',
                    style:
                    TextStyle(color: Colors.white38, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final docId = doc.id;

              final type = (data['type'] as String? ?? '');
              final title = (data['title'] as String? ?? '');
              final message = (data['message'] as String? ?? '');
              final isRead = (data['is_read'] as bool? ?? false);
              final createdAt = data['created_at'] as Timestamp?;

              return _NotificationCard(
                title: title,
                message: message,
                type: type,
                icon: _iconFor(type),
                accentColor: _colorFor(type),
                timeAgo: _formatTimestamp(createdAt),
                isRead: isRead,
                onTap: () => _markAsRead(docId),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Notification Card Widget ─────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final String title;
  final String message;
  final String type;
  final IconData icon;
  final Color accentColor;
  final String timeAgo;
  final bool isRead;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.title,
    required this.message,
    required this.type,
    required this.icon,
    required this.accentColor,
    required this.timeAgo,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isRead
              ? const Color(0xFF1A1A1A)
              : const Color(0xFF1E1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? Colors.white.withOpacity(0.05)
                : accentColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: isRead
              ? null
              : [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor,
                      accentColor.withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),

              const SizedBox(width: 12),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: isRead
                            ? Colors.white38
                            : Colors.white60,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    if (timeAgo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}