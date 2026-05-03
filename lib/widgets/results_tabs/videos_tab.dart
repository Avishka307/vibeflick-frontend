import 'package:flutter/material.dart';
import '../skeleton_loader.dart';
import 'dart:async';

class VideosTab extends StatefulWidget {
  final String query;

  const VideosTab({super.key, required this.query});

  @override
  State<VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends State<VideosTab> {
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _videos = [];
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadData() {
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _videos.addAll(_generateVideos());
          _isLoading = false;
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      _loadMore();
    }
  }

  void _loadMore() {
    setState(() {
      _isLoadingMore = true;
    });

    Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _videos.addAll(_generateVideos());
          _isLoadingMore = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> _generateVideos() {
    final creators = ['@kasunp', '@nimalis', '@ravindu', '@sachinid'];
    final durations = ['0:15', '0:22', '0:18', '0:30', '0:25'];

    return List.generate(12, (index) {
      final views = (2500 - index * 100) / 1000;
      return {
        'views': views >= 1 ? '${views.toStringAsFixed(1)}M' : '${(views * 1000).toInt()}K',
        'creator': creators[index % creators.length],
        'duration': durations[index % durations.length],
        'likes': '${(50 - index * 2)}K',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SkeletonLoader.videoGrid(3),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.65,
      ),
      itemCount: _videos.length + (_isLoadingMore ? 3 : 0),
      itemBuilder: (context, index) {
        if (index >= _videos.length) {
          return SkeletonLoader.videoCard();
        }

        final video = _videos[index];
        return _buildVideoCard(video);
      },
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video) {
    return GestureDetector(
      onTap: () {
        // Navigate to video player
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color((0xFF000000 + (video.hashCode % 0xFFFFFF))).withOpacity(0.4),
              Color((0xFF000000 + ((video.hashCode * 2) % 0xFFFFFF))).withOpacity(0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Play Icon
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),

            // Duration Badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  video['duration'],
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Video Info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            video['views'],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      video['creator'],
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            // Like Count Badge
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0050).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      video['likes'],
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}