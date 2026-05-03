import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../components/skeleton_loaders.dart';

/// File: lib/search/tabs/hashtags_search_tab.dart
/// ✅ Algolia backend API — /search/hashtags?q=
/// ❌ Firestore direct query ඉවත් කළා

class HashtagsSearchTab extends StatefulWidget {
  final String query;

  const HashtagsSearchTab({
    super.key,
    required this.query,
  });

  @override
  State<HashtagsSearchTab> createState() => _HashtagsSearchTabState();
}

class _HashtagsSearchTabState extends State<HashtagsSearchTab>
    with AutomaticKeepAliveClientMixin {
  static const String _baseUrl = 'https://avishka-tiktok-api.zeabur.app';

  List<Map<String, dynamic>> _hashtags = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _currentPage = 0;
  static const int _hitsPerPage = 20;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadHashtags();
  }

  Future<void> _loadHashtags() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🏷️ [Algolia] Searching hashtags: "${widget.query}"');

      final uri = Uri.parse(
        '$_baseUrl/search/hashtags?q=${Uri.encodeComponent(widget.query)}'
            '&limit=$_hitsPerPage&page=$_currentPage',
      );

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final hits = (data['data'] as List).cast<Map<String, dynamic>>();
          _hashtags = hits.map(_mapHashtag).toList();
          _hasMore = hits.length == _hitsPerPage;
          debugPrint('   ✅ Found ${_hashtags.length} hashtags');
        } else {
          _hashtags = [];
          _hasMore = false;
        }
      }
    } catch (e) {
      debugPrint('   ❌ Error: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMoreHashtags() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      _currentPage++;
      final uri = Uri.parse(
        '$_baseUrl/search/hashtags?q=${Uri.encodeComponent(widget.query)}'
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
          setState(() => _hashtags.addAll(hits.map(_mapHashtag)));
        }
      }
    } catch (e) {
      _currentPage--;
    }
    setState(() => _isLoadingMore = false);
  }

  Map<String, dynamic> _mapHashtag(Map<String, dynamic> h) => {
    'tag': h['tag'] ?? '',
    'videos': h['usage_count'] ?? h['videos'] ?? 0,
    'views': h['views'] ?? 0,
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SkeletonLoaders.hashtag(),
        ),
      );
    }

    if (_hashtags.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tag, size: 60, color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'No hashtags found',
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
          _loadMoreHashtags();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _hashtags.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _hashtags.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SkeletonLoaders.hashtag(),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildHashtagCard(_hashtags[index], index < 3),
          );
        },
      ),
    );
  }

  Widget _buildHashtagCard(Map<String, dynamic> hashtag, bool isTrending) {
    return GestureDetector(
      onTap: () => debugPrint('🏷️ Hashtag tapped: ${hashtag['tag']}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTrending
                ? const Color(0xFFFF0050).withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF0050).withOpacity(0.3),
                    const Color(0xFFFFB800).withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFFF0050).withOpacity(0.5), width: 2),
              ),
              child: const Center(
                child:
                Icon(Icons.tag_rounded, color: Color(0xFFFF0050), size: 28),
              ),
            ),
            const SizedBox(width: 14),
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
                              color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isTrending) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              Color(0xFFFF0050),
                              Color(0xFFFF4B8C)
                            ]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.trending_up_rounded,
                                  size: 11, color: Colors.white),
                              SizedBox(width: 3),
                              Text('Trending',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.video_library_rounded,
                          size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text('${_fmt(hashtag['videos'])} videos',
                          style:
                          const TextStyle(fontSize: 13, color: Colors.white54)),
                      const SizedBox(width: 12),
                      Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      const Icon(Icons.visibility_rounded,
                          size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text('${_fmt(hashtag['views'])} views',
                          style:
                          const TextStyle(fontSize: 13, color: Colors.white54)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic count) {
    final n = count is int ? count : int.tryParse(count.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}