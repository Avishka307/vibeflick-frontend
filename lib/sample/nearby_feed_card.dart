// ============================================================
//  nearby_feed_card.dart
//  Nearby Feed section එකේ text posts "card" ලෙස පෙන්වන widget.
//  Full-screen preview, like/comment count, city badge සහිතයි.
// ============================================================

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'text_post_model.dart';

// ── Re-use කරන constants (text_create_screen.dart එකෙන් copy) ──
const _kBackgrounds = {
  PostBackground.saffron: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B35), Color(0xFFF7C59F)],
  ),
  PostBackground.ocean: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF023E8A), Color(0xFF48CAE4)],
  ),
  PostBackground.forest: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B4332), Color(0xFF95D5B2)],
  ),
  PostBackground.sunset: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9D0208), Color(0xFFFFBA08)],
  ),
  PostBackground.night: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F0E17), Color(0xFF2E2E3A)],
  ),
  PostBackground.thambili: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE76F51), Color(0xFFF4D35E)],
  ),
};

const _kDarkBackgrounds = {
  PostBackground.ocean,
  PostBackground.forest,
  PostBackground.night,
};

TextStyle _cardFontStyle(PostFontStyle fs, double size, Color color) {
  switch (fs) {
    case PostFontStyle.clean:
      return TextStyle(
          fontFamily: 'NotoSansSinhala',
          fontSize: size,
          color: color,
          height: 1.35);
    case PostFontStyle.bold:
      return TextStyle(
          fontFamily: 'NotoSansSinhala',
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.35);
    case PostFontStyle.serif:
      return TextStyle(
          fontFamily: 'NotoSerifSinhala',
          fontSize: size,
          color: color,
          height: 1.35);
    case PostFontStyle.boldSerif:
      return TextStyle(
          fontFamily: 'NotoSerifSinhala',
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.35);
  }
}

// ---------------------------------------------------------------
//  NearbyFeedCard  — Feed list / grid එකට use කරන card
// ---------------------------------------------------------------
class NearbyFeedCard extends StatefulWidget {
  const NearbyFeedCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onTap,
    this.distanceKm,
  });

  final TextPostModel post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onTap;
  final double? distanceKm; // e.g. 2.4  → "2.4 km"

  @override
  State<NearbyFeedCard> createState() => _NearbyFeedCardState();
}

class _NearbyFeedCardState extends State<NearbyFeedCard>
    with SingleTickerProviderStateMixin {
  bool _liked = false;
  late int _localLikes;
  late final AnimationController _heartCtrl;
  late final Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _localLikes = widget.post.likesCount;
    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  void _handleLike() {
    setState(() {
      _liked = !_liked;
      _localLikes += _liked ? 1 : -1;
    });
    _heartCtrl.forward(from: 0);
    widget.onLike?.call();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isDark = _kDarkBackgrounds.contains(post.background);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subColor = isDark
        ? Colors.white.withOpacity(0.55)
        : Colors.black.withOpacity(0.45);

    // Font size: card cards නිසා text ටිකක් කුඩා
    final charCount = post.textContent.length;
    final double fontSize = charCount < 40
        ? 22
        : charCount < 100
        ? 18
        : 15;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: _kBackgrounds[post.background],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // ── Main Content ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 70),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Text
                      Text(
                        post.textContent,
                        textAlign: TextAlign.center,
                        style: _cardFontStyle(
                            post.fontStyle, fontSize, textColor),
                        maxLines: 8,
                        overflow: TextOverflow.fade,
                      ),

                      // Stickers (positioned relative to card)
                      if (post.stickers.isNotEmpty)
                        const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Placed Stickers ───────────────────────────────
              ...post.stickers.map((s) {
                return Positioned(
                  left: s.xPercent / 100 * (MediaQuery.of(context).size.width - 32),
                  top: s.yPercent / 100 * 250,
                  child: Text(s.emoji,
                      style: const TextStyle(fontSize: 28)),
                );
              }),

              // ── Top Row (Avatar + Name + City Badge) ──────────
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: post.avatarUrl.isNotEmpty
                          ? NetworkImage(post.avatarUrl)
                          : null,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: post.avatarUrl.isEmpty
                          ? Text(
                        post.username.isNotEmpty
                            ? post.username[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    // Username
                    Expanded(
                      child: Text(
                        post.username,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Distance badge
                    if (widget.distanceKm != null)
                      _Badge(
                        label:
                        '${widget.distanceKm!.toStringAsFixed(1)} km',
                        icon: Icons.location_on_rounded,
                        color: textColor,
                      ),
                    const SizedBox(width: 6),
                    // City badge
                    if (post.cityName.isNotEmpty)
                      _Badge(
                        label: post.cityName,
                        color: textColor,
                      ),
                  ],
                ),
              ),

              // ── Bottom Bar (Time + Like + Comment) ────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Time ago
                      Text(
                        timeago.format(post.createdAt, locale: 'en_short'),
                        style: TextStyle(color: subColor, fontSize: 12),
                      ),
                      const Spacer(),
                      // Comment button
                      _ActionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        count: widget.post.commentsCount,
                        color: subColor,
                        onTap: widget.onComment,
                      ),
                      const SizedBox(width: 16),
                      // Like button
                      ScaleTransition(
                        scale: _heartScale,
                        child: _ActionButton(
                          icon: _liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          count: _localLikes,
                          color: _liked ? const Color(0xFFE63946) : subColor,
                          onTap: _handleLike,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small Badge ────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Action Button (Like / Comment) ────────────────────────────
class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.icon,
        required this.count,
        required this.color,
        this.onTap});
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 4),
          Text(
            _formatCount(count),
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}