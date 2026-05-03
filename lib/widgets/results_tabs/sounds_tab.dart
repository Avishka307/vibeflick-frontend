import 'package:flutter/material.dart';
import '../skeleton_loader.dart';
import 'dart:async';

class SoundsTab extends StatefulWidget {
  final String query;

  const SoundsTab({super.key, required this.query});

  @override
  State<SoundsTab> createState() => _SoundsTabState();
}

class _SoundsTabState extends State<SoundsTab> {
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _sounds = [];
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
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _sounds.addAll(_generateSounds());
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

    Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _sounds.addAll(_generateSounds());
          _isLoadingMore = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> _generateSounds() {
    final tracks = [
      {'title': 'Trending Beat Mix', 'artist': 'DJ Lanka', 'icon': '🎵'},
      {'title': 'Viral Dance Track', 'artist': 'Beat Masters', 'icon': '💃'},
      {'title': 'Chill Vibes', 'artist': 'Relaxation', 'icon': '🎸'},
      {'title': 'Party Anthem', 'artist': 'Night Fever', 'icon': '🎉'},
      {'title': 'Motivational Beat', 'artist': 'Energy Boost', 'icon': '⚡'},
      {'title': 'Love Songs', 'artist': 'Romance Mix', 'icon': '💕'},
    ];

    return List.generate(6, (index) {
      final track = tracks[index % tracks.length];
      final videos = (500 - index * 30);
      return {
        'title': '${track['title']} ${index ~/ tracks.length > 0 ? (index ~/ tracks.length + 1) : ''}',
        'artist': track['artist'],
        'videos': videos >= 100 ? '${(videos / 1000).toStringAsFixed(1)}K' : '$videos',
        'duration': '${(15 + index * 5)}s',
        'icon': track['icon'],
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SkeletonLoader.sound(),
          );
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _sounds.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _sounds.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: SkeletonLoader.sound(),
          );
        }

        final sound = _sounds[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildSoundCard(sound),
        );
      },
    );
  }

  Widget _buildSoundCard(Map<String, dynamic> sound) {
    return GestureDetector(
      onTap: () {
        // Show videos using this sound
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Album Art / Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF0050),
                    Color(0xFFFFB800),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF0050).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  sound['icon'],
                  style: const TextStyle(fontSize: 30),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Track Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sound['title'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 13,
                        color: Color(0xFF5F6368),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          sound['artist'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withOpacity(0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0050).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.video_library_rounded,
                              size: 12,
                              color: Color(0xFFFF0050),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${sound['videos']} videos',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF0050),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: Color(0xFF5F6368),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              sound['duration'],
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF5F6368),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Use Sound Button
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0050),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}