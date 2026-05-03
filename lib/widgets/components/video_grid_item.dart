import 'package:flutter/material.dart';
import 'package:my_vibe_flick/screens/post_detail_page.dart';

class VideoGridItem extends StatelessWidget {
  final Map<String, dynamic> video;

  const VideoGridItem({
    super.key,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = video['thumbnail_url'] as String?;
    final views = video['views'] ?? 0;

    return GestureDetector(
      onTap: () {
        debugPrint('🎬 Opening video: ${video['id']}');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailPage(
              postId: video['id'],
              initialUserId: video['uid'],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail or Gradient Background
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildGradientBackground();
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildGradientBackground();
                  },
                ),
              )
            else
              _buildGradientBackground(),

            // Bottom Gradient Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),
            ),

            // Play Icon
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),

            // View Count Badge
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatCount(views),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Creator Badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '@${video['username']}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color((0xFF000000 + (video.hashCode % 0xFFFFFF))).withOpacity(0.5),
            Color((0xFF000000 + ((video.hashCode * 2) % 0xFFFFFF)))
                .withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}