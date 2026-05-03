import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../screens/search_shared_widgets.dart';

class VideosSearchTab extends StatefulWidget {
  final String query;
  final String? currentUserId;

  const VideosSearchTab({super.key, required this.query, this.currentUserId});

  @override
  State<VideosSearchTab> createState() => _VideosSearchTabState();
}

class _VideosSearchTabState extends State<VideosSearchTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() => _isLoading = true);
    try {
      final res = await http
          .get(Uri.parse(
        'https://avishka-tiktok-api.zeabur.app/search/posts?q=${Uri.encodeComponent(widget.query)}&limit=30',
      ))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() => _videos = List<Map<String, dynamic>>.from(data['data']));
          debugPrint('✅ [Videos Tab] ${_videos.length} results');
          return;
        }
      }
    } catch (e) {
      debugPrint('❌ [Videos Tab] $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return SearchShimmer.grid();
    if (_videos.isEmpty) {
      return const SearchEmpty(
        icon: Icons.videocam_off_rounded,
        label: 'No videos found',
        sub: 'Try different keywords or hashtags',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 9 / 16,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _videos.length,
      itemBuilder: (_, i) => _VideoTile(video: _videos[i]),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final Map<String, dynamic> video;
  const _VideoTile({required this.video});

  @override
  Widget build(BuildContext context) {
    final thumb = video['thumbnailUrl'];
    final likes = video['likes'] ?? 0;
    final caption = video['caption'] ?? '';

    return GestureDetector(
      onTap: () => debugPrint('Navigate to video: ${video['objectID']}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          thumb != null
              ? Image.network(thumb,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(caption))
              : _placeholder(caption),

          // Bottom gradient + like count
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 20, 6, 5),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite_rounded,
                      size: 11, color: Colors.white70),
                  const SizedBox(width: 3),
                  Text(
                    _fmt(likes),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String caption) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline_rounded,
              size: 30, color: Colors.white.withOpacity(0.2)),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                caption,
                style: TextStyle(
                    fontSize: 10, color: Colors.white.withOpacity(0.3)),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}