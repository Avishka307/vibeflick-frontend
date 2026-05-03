import 'package:flutter/material.dart';
import 'dart:math';

class ExploreView extends StatelessWidget {
  final Function(String) onHashtagTap;
  final Function(String) onCreatorTap;

  const ExploreView({
    super.key,
    required this.onHashtagTap,
    required this.onCreatorTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Banners
          _buildBannerSlider(),

          const SizedBox(height: 24),

          // Trending Hashtags
          _buildSectionTitle('Trending Hashtags', Icons.tag_rounded),
          const SizedBox(height: 12),
          _buildTrendingHashtags(),

          const SizedBox(height: 28),

          // Suggested Creators
          _buildSectionTitle('Suggested Creators', Icons.stars_rounded),
          const SizedBox(height: 12),
          _buildSuggestedCreators(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBannerSlider() {
    final banners = [
      {
        'title': 'Dance Challenge 2026',
        'color': const Color(0xFFFF0050),
        'gradient': const LinearGradient(
          colors: [Color(0xFFFF0050), Color(0xFFFF4B8C)],
        ),
      },
      {
        'title': 'Comedy Week',
        'color': const Color(0xFF00D9FF),
        'gradient': const LinearGradient(
          colors: [Color(0xFF00D9FF), Color(0xFF4BE3FF)],
        ),
      },
      {
        'title': 'Cooking Masters',
        'color': const Color(0xFFFFB800),
        'gradient': const LinearGradient(
          colors: [Color(0xFFFFB800), Color(0xFFFFD34E)],
        ),
      },
    ];

    return SizedBox(
      height: 180,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.9),
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final banner = banners[index];
          return Container(
            margin: EdgeInsets.only(
              left: index == 0 ? 16 : 8,
              right: index == banners.length - 1 ? 16 : 8,
            ),
            decoration: BoxDecoration(
              gradient: banner['gradient'] as LinearGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (banner['color'] as Color).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CustomPaint(
                      painter: _BannerPatternPainter(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        banner['title'] as String,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Join Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingHashtags() {
    final hashtags = [
      {'tag': '#DanceChallenge', 'count': '2.5M'},
      {'tag': '#ComedySL', 'count': '1.8M'},
      {'tag': '#CookingTips', 'count': '980K'},
      {'tag': '#TravelSL', 'count': '750K'},
      {'tag': '#FitnessGoals', 'count': '620K'},
      {'tag': '#LifeHacks', 'count': '540K'},
    ];

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: hashtags.length,
        itemBuilder: (context, index) {
          final hashtag = hashtags[index];
          return GestureDetector(
            onTap: () => onHashtagTap(hashtag['tag']!),
            child: Container(
              width: 140,
              margin: EdgeInsets.only(
                right: index == hashtags.length - 1 ? 0 : 12,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color((Random().nextDouble() * 0xFFFFFF).toInt())
                        .withOpacity(0.1),
                    Color((Random().nextDouble() * 0xFFFFFF).toInt())
                        .withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(
                    Icons.tag_rounded,
                    color: Color(0xFFFF0050),
                    size: 24,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hashtag['tag']!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${hashtag['count']} videos',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestedCreators() {
    final creators = [
      {
        'name': 'Kasun Perera',
        'username': '@kasunp',
        'followers': '1.2M',
        'avatar': '🎭'
      },
      {
        'name': 'Nimali Silva',
        'username': '@nimalis',
        'followers': '890K',
        'avatar': '🎨'
      },
      {
        'name': 'Ravindu Fernando',
        'username': '@ravindu',
        'followers': '750K',
        'avatar': '🎵'
      },
      {
        'name': 'Sachini Dias',
        'username': '@sachinid',
        'followers': '620K',
        'avatar': '💃'
      },
    ];

    return Column(
      children: creators.map((creator) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.black.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF0050), Color(0xFFFFB800)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    creator['avatar']!,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      creator['name']!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${creator['username']} • ${creator['followers']} followers',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0050),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Follow',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _BannerPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.3),
        30.0 + (i * 20),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}