import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ThogarShare — Text Post Share System
//  System share sheet | Deep link | Share count increment | Console logs
//
//  pubspec.yaml ට add කරන්න:
//    share_plus: ^7.2.2
// ─────────────────────────────────────────────────────────────────────────────

class ThogarShare {
  static const String _baseUrl    = 'https://avishka-tiktok-api.zeabur.app';
  static const String _appDomain  = 'vibeflick.com';  // ← ඔයාගේ domain
  static const String _appPackage = 'com.vibeflick.app'; // ← ඔයාගේ package

  // ── Main Share Method ──────────────────────────────────────────────────────
  static Future<void> sharePost({
    required BuildContext context,
    required String postId,
    required String content,
    required String cityName,
    required bool isAnonymous,
    required String? username,
  }) async {
    debugPrint('\n📤 ========== THOGAR SHARE ==========');
    debugPrint('   Post ID   : $postId');
    debugPrint('   City      : $cityName');
    debugPrint('   Anonymous : $isAnonymous');
    debugPrint('   User      : ${isAnonymous ? "Anonymous" : (username ?? "Unknown")}');

    HapticFeedback.mediumImpact();

    // ── Build share text ───────────────────────────────────────────────────
    final preview = content.length > 120
        ? '${content.substring(0, 120)}...'
        : content;

    final author = isAnonymous ? 'Someone from $cityName' : '${username ?? "Someone"} from $cityName';

    final shareText = '$author vibed:\n\n"$preview"\n\n'
        'Check it on VibeFlick 👇\n'
        'https://$_appDomain/post/$postId';

    debugPrint('   Share text preview: "${shareText.substring(0, 50)}..."');

    // ── Open system share sheet ────────────────────────────────────────────
    try {
      await Share.share(
        shareText,
        subject: 'A vibe from $cityName 🔥',
      );
      debugPrint('   ✅ System share sheet opened');

      // ── Increment share count on backend (fire & forget) ──────────────
      _incrementShareCount(postId);

    } catch (e) {
      debugPrint('   ❌ Share error: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open share sheet'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    debugPrint('==========================================\n');
  }

  // ── Increment share count (fire & forget) ──────────────────────────────────
  static Future<void> _incrementShareCount(String postId) async {
    debugPrint('\n📊 ========== INCREMENT SHARE COUNT ==========');
    debugPrint('   Post ID : $postId');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/text-posts/$postId/share'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final newCount = body['shareCount'] ?? 0;

      debugPrint('   ✅ Share count updated: $newCount');
    } catch (e) {
      debugPrint('   ❌ Share count error (non-critical): $e');
    }

    debugPrint('==========================================\n');
  }

  // ── Copy Link to Clipboard ────────────────────────────────────────────────
  static Future<void> copyLink({
    required BuildContext context,
    required String postId,
  }) async {
    final link = 'https://$_appDomain/post/$postId';
    await Clipboard.setData(ClipboardData(text: link));

    debugPrint('📋 Link copied: $link');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.link_rounded, color: Colors.white70, size: 16),
            SizedBox(width: 8),
            Text('Link copied to clipboard'),
          ]),
          backgroundColor: Colors.white.withOpacity(0.1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Show Share Options Sheet ──────────────────────────────────────────────
  static void showShareSheet({
    required BuildContext context,
    required String postId,
    required String content,
    required String cityName,
    required bool isAnonymous,
    required String? username,
  }) {
    HapticFeedback.lightImpact();

    debugPrint('\n📋 ========== SHOW SHARE SHEET ==========');
    debugPrint('   Post ID : $postId');
    debugPrint('==========================================\n');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareOptionsSheet(
        postId: postId,
        content: content,
        cityName: cityName,
        isAnonymous: isAnonymous,
        username: username,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ShareOptionsSheet — Custom share bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ShareOptionsSheet extends StatelessWidget {
  final String  postId;
  final String  content;
  final String  cityName;
  final bool    isAnonymous;
  final String? username;

  const _ShareOptionsSheet({
    required this.postId,
    required this.content,
    required this.cityName,
    required this.isAnonymous,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Title
          const Row(children: [
            Icon(Icons.share_rounded, color: Colors.white70, size: 18),
            SizedBox(width: 8),
            Text(
              'Share this Vibe',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // Post preview
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              content.length > 80 ? '${content.substring(0, 80)}...' : content,
              style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
            ),
          ),

          // Options
          _ShareOption(
            icon: Icons.ios_share_rounded,
            label: 'Share via...',
            onTap: () {
              Navigator.pop(context);
              ThogarShare.sharePost(
                context: context,
                postId: postId,
                content: content,
                cityName: cityName,
                isAnonymous: isAnonymous,
                username: username,
              );
            },
          ),
          _ShareOption(
            icon: Icons.link_rounded,
            label: 'Copy Link',
            onTap: () {
              Navigator.pop(context);
              ThogarShare.copyLink(context: context, postId: postId);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      onTap: onTap,
    );
  }
}