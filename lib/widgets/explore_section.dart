import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ExploreSection extends StatefulWidget {
  final Function(String) onHashtagTap;
  final String? currentUserId;

  // 🆕 Recent history සහ trending searches සඳහා callbacks
  final List<String> recentSearches;
  final Function(String) onRecentSearchTap;
  final Function(String) onDeleteRecentSearch;
  final VoidCallback onClearAllRecent;

  const ExploreSection({
    super.key,
    required this.onHashtagTap,
    this.currentUserId,
    required this.recentSearches,
    required this.onRecentSearchTap,
    required this.onDeleteRecentSearch,
    required this.onClearAllRecent,
  });

  @override
  State<ExploreSection> createState() => _ExploreSectionState();
}

class _ExploreSectionState extends State<ExploreSection> {
  List<Map<String, dynamic>> _trendingSearches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrendingSearches();
  }

  // 🔥 Server එකෙන් trending searches load කරන්න
  Future<void> _loadTrendingSearches() async {
    try {
      setState(() => _isLoading = true);

      final response = await http.get(
        Uri.parse('https://avishka-tiktok-api.zeabur.app/api/trending-searches?limit=8'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _trendingSearches = List<Map<String, dynamic>>.from(data['data']);
            _isLoading = false;
          });
          debugPrint('✅ Loaded ${_trendingSearches.length} trending searches');
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Trending searches load failed: $e');
    }

    // Fallback: empty list
    setState(() {
      _trendingSearches = [];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // 🕐 Recent Searches Section
          if (widget.recentSearches.isNotEmpty) ...[
            _buildRecentSearchesSection(),
            const SizedBox(height: 24),
          ],

          // 🔥 Trending Searches Section
          _buildTrendingSearchesSection(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 🕐 Recent Searches
  // ─────────────────────────────────────────────────────────
  Widget _buildRecentSearchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: "Recent" + "Clear All"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: widget.onClearAllRecent,
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Recent items list
        Column(
          children: widget.recentSearches.map((query) {
            return _RecentSearchItem(
              query: query,
              onTap: () => widget.onRecentSearchTap(query),
              onDelete: () => widget.onDeleteRecentSearch(query),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 🔥 Trending Searches
  // ─────────────────────────────────────────────────────────
  Widget _buildTrendingSearchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFF4D00),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Trending Searches',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF0050),
                strokeWidth: 2,
              ),
            ),
          )
        else if (_trendingSearches.isEmpty)
          _buildTrendingEmpty()
        else
          Column(
            children: _trendingSearches
                .asMap()
                .entries
                .map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _TrendingSearchItem(
                rank: index + 1,
                keyword: item['keyword'] ?? '',
                searchCount: item['search_count'] ?? 0,
                onTap: () => widget.onHashtagTap(item['keyword'] ?? ''),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildTrendingEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: Text(
          'No trending searches yet',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 🕐 Recent Search Item Widget
// ─────────────────────────────────────────────────────────────────────
class _RecentSearchItem extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecentSearchItem({
    required this.query,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Clock icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                size: 18,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(width: 12),

            // Query text
            Expanded(
              child: Text(
                query,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // X button
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 🔥 Trending Search Item Widget
// ─────────────────────────────────────────────────────────────────────
class _TrendingSearchItem extends StatelessWidget {
  final int rank;
  final String keyword;
  final int searchCount;
  final VoidCallback onTap;

  const _TrendingSearchItem({
    required this.rank,
    required this.keyword,
    required this.searchCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Top 3 ranks ට special color
    final rankColor = rank <= 3
        ? const Color(0xFFFF0050)
        : Colors.white.withOpacity(0.35);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 36,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: rankColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),

            // Keyword + count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    keyword,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (searchCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${_formatCount(searchCount)} searches',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.north_west_rounded,
              size: 16,
              color: Colors.white.withOpacity(0.25),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}