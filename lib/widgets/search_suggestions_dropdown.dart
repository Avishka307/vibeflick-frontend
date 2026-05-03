import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class SearchSuggestionsDropdown extends StatefulWidget {
  final String query;
  final Function(String) onSuggestionTap;

  const SearchSuggestionsDropdown({
    super.key,
    required this.query,
    required this.onSuggestionTap,
  });

  @override
  State<SearchSuggestionsDropdown> createState() =>
      _SearchSuggestionsDropdownState();
}

class _SearchSuggestionsDropdownState extends State<SearchSuggestionsDropdown> {
  List<_Suggestion> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(SearchSuggestionsDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 180), _fetch);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (widget.query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Parallel: users + hashtags from Algolia
      final results = await Future.wait([
        http
            .get(Uri.parse(
          'https://avishka-tiktok-api.zeabur.app/search/users?q=${Uri.encodeComponent(widget.query)}&limit=3',
        ))
            .timeout(const Duration(seconds: 5)),
        http
            .get(Uri.parse(
          'https://avishka-tiktok-api.zeabur.app/search/hashtags?q=${Uri.encodeComponent(widget.query)}&limit=4',
        ))
            .timeout(const Duration(seconds: 5)),
      ]);

      final out = <_Suggestion>[];

      if (results[0].statusCode == 200) {
        final data = json.decode(results[0].body);
        if (data['success'] == true && data['data'] != null) {
          for (final u in data['data']) {
            out.add(_Suggestion(
              type: _SuggType.user,
              text: u['username'] ?? '',
              subtext: u['displayName'],
            ));
          }
        }
      }

      if (results[1].statusCode == 200) {
        final data = json.decode(results[1].body);
        if (data['success'] == true && data['data'] != null) {
          for (final h in data['data']) {
            out.add(_Suggestion(
              type: _SuggType.hashtag,
              text: h['tag'] ?? '',
              subtext: h['usage_count'] != null ? '${_fmt(h['usage_count'])} videos' : null,
            ));
          }
        }
      }

      debugPrint('✅ [Suggestions] ${out.length} results for "${widget.query}"');

      if (mounted) setState(() {
        _suggestions = out;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ [Suggestions] $e');
      if (mounted) setState(() {
        _suggestions = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Divider
          Divider(color: Colors.white.withOpacity(0.08), height: 1),

          // Loading shimmer
          if (_isLoading)
            ..._buildShimmer()
          // No results — "Search for X" hint
          else if (_suggestions.isEmpty)
            _SearchHintTile(
              query: widget.query,
              onTap: () => widget.onSuggestionTap(widget.query),
            )
          // Results
          else
            ..._suggestions.map((s) => _SuggestionTile(
              suggestion: s,
              query: widget.query,
              onTap: () => widget.onSuggestionTap(s.text),
            )),
        ],
      ),
    );
  }

  List<Widget> _buildShimmer() {
    return List.generate(
      4,
          (_) => _ShimmerTile(),
    );
  }

  String _fmt(dynamic n) {
    final count = n is int ? n : int.tryParse(n.toString()) ?? 0;
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

// ── Data ───────────────────────────────────────────
enum _SuggType { user, hashtag }

class _Suggestion {
  final _SuggType type;
  final String text;
  final String? subtext;
  const _Suggestion({required this.type, required this.text, this.subtext});
}

// ── "Search for X" hint tile ──────────────────────
class _SearchHintTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  const _SearchHintTile({required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 20, color: Colors.white.withOpacity(0.4)),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 15),
                  children: [
                    TextSpan(
                      text: 'Search for  ',
                      style: TextStyle(color: Colors.white.withOpacity(0.45)),
                    ),
                    TextSpan(
                      text: '"$query"',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
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

// ── Suggestion tile ────────────────────────────────
class _SuggestionTile extends StatelessWidget {
  final _Suggestion suggestion;
  final String query;
  final VoidCallback onTap;
  const _SuggestionTile(
      {required this.suggestion, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isHashtag = suggestion.type == _SuggType.hashtag;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isHashtag
                    ? const Color(0xFFFF0050).withOpacity(0.12)
                    : Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHashtag ? Icons.tag_rounded : Icons.person_rounded,
                size: 17,
                color: isHashtag
                    ? const Color(0xFFFF0050)
                    : Colors.white.withOpacity(0.55),
              ),
            ),
            const SizedBox(width: 12),

            // Text + subtext
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                      children: _highlight(suggestion.text, query),
                    ),
                  ),
                  if (suggestion.subtext != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        suggestion.subtext!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.white.withOpacity(0.38)),
                      ),
                    ),
                ],
              ),
            ),

            // Arrow (tap fills search bar)
            Icon(Icons.north_west_rounded,
                size: 15, color: Colors.white.withOpacity(0.22)),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _highlight(String text, String q) {
    if (q.isEmpty) return [TextSpan(text: text)];
    final idx = text.toLowerCase().indexOf(q.toLowerCase());
    if (idx == -1) return [TextSpan(text: text)];
    return [
      if (idx > 0) TextSpan(text: text.substring(0, idx)),
      TextSpan(
          text: text.substring(idx, idx + q.length),
          style: const TextStyle(
              color: Color(0xFFFF0050), fontWeight: FontWeight.w700)),
      if (idx + q.length < text.length)
        TextSpan(text: text.substring(idx + q.length)),
    ];
  }
}

// ── Shimmer tile ───────────────────────────────────
class _ShimmerTile extends StatefulWidget {
  @override
  State<_ShimmerTile> createState() => _ShimmerTileState();
}

class _ShimmerTileState extends State<_ShimmerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _a =
  Tween(begin: 0.18, end: 0.45).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_a.value * 0.5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 140, height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_a.value),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}