import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────
// Shared Empty State
// ──────────────────────────────────────────────────
class SearchEmpty extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;

  const SearchEmpty({
    super.key,
    required this.icon,
    required this.label,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 8),
              Text(
                sub!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.3),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────
// Shared Shimmer Widget
// ──────────────────────────────────────────────────
class SearchShimmer extends StatefulWidget {
  final Widget Function(double opacity) builder;

  const SearchShimmer({super.key, required this.builder});

  /// List shimmer — Users / Hashtags tabs
  static Widget list() => ListView.builder(
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: 6,
    itemBuilder: (_, __) => SearchShimmer(
      builder: (op) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _box(52, 52, op, radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(12, 140, op),
                  const SizedBox(height: 8),
                  _box(10, 90, op * 0.7),
                ],
              ),
            ),
            _box(32, 74, op, radius: 16),
          ],
        ),
      ),
    ),
  );

  /// Grid shimmer — Videos tab
  static Widget grid() => GridView.builder(
    padding: const EdgeInsets.all(2),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      childAspectRatio: 9 / 16,
      crossAxisSpacing: 2,
      mainAxisSpacing: 2,
    ),
    itemCount: 9,
    itemBuilder: (_, __) => SearchShimmer(
      builder: (op) => Container(
        color: Colors.white.withOpacity(op * 0.4),
      ),
    ),
  );

  /// Hashtag list shimmer
  static Widget hashtagList() => ListView.builder(
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: 6,
    itemBuilder: (_, __) => SearchShimmer(
      builder: (op) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(op * 0.4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(12, 130, op),
                const SizedBox(height: 8),
                _box(10, 80, op * 0.6),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  static Widget _box(double h, double w, double op, {double radius = 8}) =>
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(op),
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  @override
  State<SearchShimmer> createState() => _SearchShimmerState();
}

class _SearchShimmerState extends State<SearchShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _anim = Tween(begin: 0.25, end: 0.6).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => widget.builder(_anim.value),
  );
}

// ──────────────────────────────────────────────────
// Shared Avatar Widget
// ──────────────────────────────────────────────────
class SearchAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const SearchAvatar({
    super.key,
    this.url,
    required this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFF0050), Color(0xFFFF8C00)],
        ),
      ),
      child: url != null
          ? ClipOval(
        child: Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(),
        ),
      )
          : _initials(),
    );
  }

  Widget _initials() => Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: size * 0.4,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );
}