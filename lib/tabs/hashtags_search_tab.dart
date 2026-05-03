import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../screens/search_shared_widgets.dart';


class HashtagsSearchTab extends StatefulWidget {
  final String query;
  const HashtagsSearchTab({super.key, required this.query});

  @override
  State<HashtagsSearchTab> createState() => _HashtagsSearchTabState();
}

class _HashtagsSearchTabState extends State<HashtagsSearchTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _tags = [];
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
        'https://avishka-tiktok-api.zeabur.app/search/hashtags?q=${Uri.encodeComponent(widget.query)}&limit=20',
      ))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() => _tags = List<Map<String, dynamic>>.from(data['data']));
          debugPrint('✅ [Hashtags Tab] ${_tags.length} results');
          return;
        }
      }
    } catch (e) {
      debugPrint('❌ [Hashtags Tab] $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return SearchShimmer.hashtagList();
    if (_tags.isEmpty) {
      return const SearchEmpty(
        icon: Icons.tag_rounded,
        label: 'No hashtags found',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _tags.length,
      itemBuilder: (_, i) {
        final tag = _tags[i];
        final text = tag['tag'] ?? '';
        final count = tag['usage_count'] ?? tag['videoCount'] ?? 0;

        return InkWell(
          onTap: () => debugPrint('Navigate to hashtag: $text'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0050).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tag_rounded,
                      color: Color(0xFFFF0050), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      if (count > 0) ...[
                        const SizedBox(height: 3),
                        Text('${_fmt(count)} videos',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.4))),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.2)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmt(dynamic n) {
    final count = n is int ? n : int.tryParse(n.toString()) ?? 0;
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}