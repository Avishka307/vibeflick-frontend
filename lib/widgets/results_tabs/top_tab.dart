import 'package:flutter/material.dart';
import '../skeleton_loader.dart';
import 'dart:async';

class TopTab extends StatefulWidget {
  final String query;

  const TopTab({super.key, required this.query});

  @override
  State<TopTab> createState() => _TopTabState();
}

class _TopTabState extends State<TopTab> {
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

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
    // Simulate API call
    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more data
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SkeletonLoader.user(),
          const SizedBox(height: 16),
          SkeletonLoader.user(),
          const SizedBox(height: 20),
          SkeletonLoader.videoGrid(2),
        ],
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Top Users Section
        const Text(
          'Top Users',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildUserCard(
          name: 'Kasun Perera',
          username: '@kasunp',
          followers: '1.2M',
          avatar: '🎭',
          verified: true,
        ),
        const SizedBox(height: 12),
        _buildUserCard(
          name: 'Nimali Silva',
          username: '@nimalis',
          followers: '890K',
          avatar: '🎨',
          verified: true,
        ),

        const SizedBox(height: 24),

        // Top Videos Section
        const Text(
          'Top Videos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildVideoGrid(),
      ],
    );
  }

  Widget _buildUserCard({
    required String name,
    required String username,
    required String followers,
    required String avatar,
    required bool verified,
  }) {
    return Container(
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
              child: Text(avatar, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Color(0xFF00D9FF),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$username • $followers followers',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
  }

  Widget _buildVideoGrid() {
    final videos = [
      {'views': '2.5M', 'creator': '@kasunp'},
      {'views': '1.8M', 'creator': '@nimalis'},
      {'views': '1.2M', 'creator': '@ravindu'},
      {'views': '890K', 'creator': '@sachinid'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return _buildVideoCard(
          views: video['views']!,
          creator: video['creator']!,
        );
      },
    );
  }

  Widget _buildVideoCard({
    required String views,
    required String creator,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF0050).withOpacity(0.3),
            const Color(0xFFFFB800).withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Play Icon
          const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          // Video Info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
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
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        views,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    creator,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}