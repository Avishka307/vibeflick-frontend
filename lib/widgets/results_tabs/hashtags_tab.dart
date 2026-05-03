import 'package:flutter/material.dart';
import '../skeleton_loader.dart';
import 'dart:async';

class HashtagsTab extends StatefulWidget {
  final String query;

  const HashtagsTab({super.key, required this.query});

  @override
  State<HashtagsTab> createState() => _HashtagsTabState();
}

class _HashtagsTabState extends State<HashtagsTab> {
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _hashtags = [];
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
    Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _hashtags.addAll(_generateHashtags());
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

    Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _hashtags.addAll(_generateHashtags());
          _isLoadingMore = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> _generateHashtags() {
    final tags = [
      '#DanceChallenge',
      '#ComedySL',
      '#CookingTips',
      '#TravelSL',
      '#FitnessGoals',
      '#LifeHacks',
      '#BeautyTips',
      '#TechReview',
    ];

    return List.generate(8, (index) {
      final videos = (2500 - index * 200);
      final views = (50 - index * 3);
      return {
        'tag': '${tags[index % tags.length]}${index ~/ tags.length > 0 ? (index ~/ tags.length) : ''}',
        'videos': videos >= 1000 ? '${(videos / 1000).toStringAsFixed(1)}K' : '$videos',
        'views': '${views}M',
        'trending': index < 3,
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
            child: SkeletonLoader.hashtag(),
          );
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _hashtags.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _hashtags.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: SkeletonLoader.hashtag(),
          );
        }

        final hashtag = _hashtags[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildHashtagCard(hashtag),
        );
      },
    );
  }

  Widget _buildHashtagCard(Map<String, dynamic> hashtag) {
    return GestureDetector(
      onTap: () {
        // Navigate to hashtag page
      },
      child: Container(
        padding: const EdgeInsets.all(16),
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
            // Hashtag Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF0050).withOpacity(0.15),
                    const Color(0xFFFFB800).withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFF0050).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.tag_rounded,
                  color: Color(0xFFFF0050),
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Hashtag Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          hashtag['tag'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hashtag['trending']) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF0050),
                                Color(0xFFFF4B8C),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.trending_up_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Trending',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.video_library_rounded,
                            size: 14,
                            color: Color(0xFF5F6368),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${hashtag['videos']} videos',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5F6368),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.visibility_rounded,
                            size: 14,
                            color: Color(0xFF5F6368),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${hashtag['views']} views',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5F6368),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow Icon
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black.withOpacity(0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}