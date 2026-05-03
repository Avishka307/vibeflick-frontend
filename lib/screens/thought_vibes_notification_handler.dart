// ════════════════════════════════════════════════════════════════════════════
//  ThoughtVibesScreenWrapper
//  ✅ thought_vibes_screen.dart import කරලා direct ThoughtVibesScreen() return
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../Thought/thought_vibes_screen.dart';
   // ← ඔයාගේ path adjust කරන්න

class ThoughtVibesScreenWrapper extends StatelessWidget {
  const ThoughtVibesScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const ThoughtVibesScreen();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  _NotifToast — Foreground in-app notification toast UI
// ════════════════════════════════════════════════════════════════════════════
class _NotifToast extends StatelessWidget {
  final String title;
  final String body;
  final Map<String, dynamic> data;

  const _NotifToast({
    required this.title,
    required this.body,
    required this.data,
  });

  // server.js FCMNotification.js type mapping:
  //   thought_like → 'like', thought_comment → 'comment', thought_repost → 'share'
  IconData get _icon {
    switch (data['type'] ?? '') {
      case 'like'   : return Icons.favorite_rounded;
      case 'comment': return Icons.chat_bubble_rounded;
      case 'share'  : return Icons.repeat_rounded;
      default       : return Icons.auto_awesome_rounded;
    }
  }

  Color get _iconColor {
    switch (data['type'] ?? '') {
      case 'like'   : return const Color(0xFFFF3B5C);
      case 'comment': return const Color(0xFF9B59B6);
      case 'share'  : return const Color(0xFF2ECC71);
      default       : return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e).withOpacity(0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: _iconColor.withOpacity(0.3)),
          ),
          child: Icon(_icon, color: _iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title.isNotEmpty)
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(body,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded,
            color: Colors.white24, size: 18),
      ]),
    );
  }
}