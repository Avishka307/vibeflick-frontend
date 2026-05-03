import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../screens/firestore_thumbnail_service.dart';
import '../components/video_grid_item.dart';
import '../components/skeleton_loaders.dart';


/// File: lib/search/tabs/videos_search_tab.dart
/// ✅ Algolia backend API — /search/videos?q=
/// ❌ Firestore direct query ඉවත් කළා

class VideosSearchTab extends StatefulWidget {
  final String query;
  final String? currentUserId;

  const VideosSearchTab({
    super.key,
    required this.query,
    this.currentUserId,
  });

  @override
  State<VideosSearchTab> createState() => _VideosSearchTabState();
}

class _VideosSearchTabState extends State<VideosSearchTab>
    with AutomaticKeepAliveClientMixin {
  static const String _baseUrl = 'https://avishka-tiktok-api.zeabur.app';

  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _currentPage = 0;
  static const int _hitsPerPage = 18;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🎬 [Algolia] Searching videos: "${widget.query}"');

      final uri = Uri.parse(
        '$_baseUrl/search/videos?q=${Uri.encodeComponent(widget.query)}'
            '&limit=$_hitsPerPage&page=$_currentPage',
      );

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final hits = (data['data'] as List).cast<Map<String, dynamic>>();
          _videos = hits.map(_mapVideo).toList();
          _hasMore = hits.length == _hitsPerPage;
          debugPrint('   ✅ Found ${_videos.length} videos');
        } else {
          _videos = [];
          _hasMore = false;
        }
      }
    } catch (e) {
      debugPrint('   ❌ Error: $e');
    }
    // 👇 NEW — මෙතනට
    final thumbnailMap = await FirestoreThumbnailService.getBatchThumbnails(_videos);
    for (final video in _videos) {
      if ((video['thumbnail_url'] as String).isEmpty) {
        video['thumbnail_url'] = thumbnailMap[video['id']] ?? '';
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      _currentPage++;
      final uri = Uri.parse(
        '$_baseUrl/search/videos?q=${Uri.encodeComponent(widget.query)}'
            '&limit=$_hitsPerPage&page=$_currentPage',
      );
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final hits = (data['data'] as List).cast<Map<String, dynamic>>();
          _hasMore = hits.length == _hitsPerPage;
          setState(() => _videos.addAll(hits.map(_mapVideo)));
        }
      }
    } catch (e) {
      _currentPage--;
    }
    setState(() => _isLoadingMore = false);
  }

  /// Algolia video_posts record → VideoGridItem compatible map
  Map<String, dynamic> _mapVideo(Map<String, dynamic> v) => {
    'id': v['objectID'] ?? v['id'] ?? '',
    'uid': v['uid'] ?? '',
    'username': v['username'] ?? 'Unknown',
    'media_url': v['media_url'] ?? '',
    'thumbnail_url': v['thumbnail_url'] ?? '',
    'description': v['description'] ?? '',
    'likes': v['likes'] ?? 0,
    'views': v['viewCount'] ?? v['views'] ?? 0,
    'timestamp': v['timestamp'],
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SkeletonLoaders.videoGrid(3),
      );
    }

    if (_videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_outlined,
                  size: 60, color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'No videos found',
                style: TextStyle(
                    fontSize: 16, color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _loadMoreVideos();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.65,
        ),
        itemCount: _videos.length + (_isLoadingMore ? 3 : 0),
        itemBuilder: (context, index) {
          if (index >= _videos.length) return SkeletonLoaders.videoCard();
          return VideoGridItem(video: _videos[index]);
        },
      ),
    );
  }
}