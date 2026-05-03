import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
// GIPHY API Configuration
// ─────────────────────────────────────────────
// TODO: Replace with your actual Giphy API key
//       Free key: https://developers.giphy.com/
const String _GIPHY_API_KEY = 'BQdWTfaHgOybcYEfpKprZVLVCPoYpb4X';
const String _GIPHY_BASE_URL = 'https://api.giphy.com/v1/gifs';
const int _PAGE_LIMIT = 24; // Per page load count

// ─────────────────────────────────────────────
// Giphy Data Models
// ─────────────────────────────────────────────
class GiphySticker {
  final String id;
  final String title;
  final String gifUrl;       // Original GIF (for display)
  final String fixedWidthUrl; // Fixed width (lighter, for grid)
  final int? fixedWidthHeight;
  final int? fixedWidthWidth;

  const GiphySticker({
    required this.id,
    required this.title,
    required this.gifUrl,
    required this.fixedWidthUrl,
    this.fixedWidthHeight,
    this.fixedWidthWidth,
  });

  // Calculate aspect ratio for masonry grid
  double get aspectRatio {
    if (fixedWidthHeight != null && fixedWidthWidth != null && fixedWidthHeight! > 0) {
      return fixedWidthWidth! / fixedWidthHeight!;
    }
    return 1.0; // Default to square
  }

  static GiphySticker fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>? ?? {};
    final fixedWidth = images['fixed_width'] as Map<String, dynamic>? ?? {};
    final original = images['original'] as Map<String, dynamic>? ?? {};

    return GiphySticker(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      gifUrl: original['url'] ?? '',
      fixedWidthUrl: fixedWidth['url'] ?? '',
      fixedWidthHeight: int.tryParse(fixedWidth['height']?.toString() ?? '0'),
      fixedWidthWidth: int.tryParse(fixedWidth['width']?.toString() ?? '0'),
    );
  }
}

// ─────────────────────────────────────────────
// Giphy API Service
// ─────────────────────────────────────────────
class GiphyService {
  final http.Client _client = http.Client();

  /// Fetch Trending GIFs
  Future<List<GiphySticker>> fetchTrending({int offset = 0, int limit = _PAGE_LIMIT}) async {
    final uri = Uri.parse(
      '$_GIPHY_BASE_URL/trending?api_key=$_GIPHY_API_KEY&limit=$limit&offset=$offset&rating=g',
    );
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final gifsList = data['data'] as List<dynamic>? ?? [];
      return gifsList.map((e) => GiphySticker.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch trending: ${response.statusCode}');
  }

  /// Search GIFs by query
  Future<List<GiphySticker>> searchGifs({
    required String query,
    int offset = 0,
    int limit = _PAGE_LIMIT,
  }) async {
    final uri = Uri.parse(
      '$_GIPHY_BASE_URL/search?api_key=$_GIPHY_API_KEY&q=${Uri.encodeComponent(query)}&limit=$limit&offset=$offset&rating=g',
    );
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final gifsList = data['data'] as List<dynamic>? ?? [];
      return gifsList.map((e) => GiphySticker.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to search: ${response.statusCode}');
  }

  void dispose() => _client.close();
}

// ─────────────────────────────────────────────
// Main Stickers Screen
// ─────────────────────────────────────────────
class StickersScreen extends StatefulWidget {
  const StickersScreen({super.key});

  @override
  State<StickersScreen> createState() => _StickersScreenState();
}

class _StickersScreenState extends State<StickersScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GiphyService _giphyService = GiphyService();

  // ── State ──
  List<GiphySticker> _stickers = [];
  List<GiphySticker> _recentStickers = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isOffline = false;
  int _currentOffset = 0;
  String _currentQuery = '';  // '' means Trending mode
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadInitialTrending();
    _loadRecents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounceTimer?.cancel();
    _giphyService.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Data Loading Logic
  // ─────────────────────────────────────────────

  /// Called on app open → load trending
  Future<void> _loadInitialTrending() async {
    _setState(() {
      _isLoading = true;
      _isOffline = false;
      _stickers = [];
      _currentOffset = 0;
      _hasMore = true;
      _currentQuery = '';
    });

    try {
      final results = await _giphyService.fetchTrending(offset: 0, limit: _PAGE_LIMIT);
      _setState(() {
        _stickers = results;
        _currentOffset = results.length;
        _hasMore = results.length >= _PAGE_LIMIT;
        _isLoading = false;
      });
    } catch (e) {
      _setState(() {
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  /// Infinite scroll: load next page
  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;

    _setState(() { _isLoading = true; });

    try {
      final List<GiphySticker> results;
      if (_currentQuery.isEmpty) {
        results = await _giphyService.fetchTrending(offset: _currentOffset, limit: _PAGE_LIMIT);
      } else {
        results = await _giphyService.searchGifs(
          query: _currentQuery,
          offset: _currentOffset,
          limit: _PAGE_LIMIT,
        );
      }

      _setState(() {
        _stickers.addAll(results);
        _currentOffset += results.length;
        _hasMore = results.length >= _PAGE_LIMIT;
        _isLoading = false;
      });
    } catch (e) {
      _setState(() {
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  /// Search with debounce
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _executeSearch(value.trim());
    });
  }

  Future<void> _executeSearch(String query) async {
    _setState(() {
      _isLoading = true;
      _stickers = [];
      _currentOffset = 0;
      _hasMore = true;
      _currentQuery = query;
      _isOffline = false;
    });

    try {
      final List<GiphySticker> results;
      if (query.isEmpty) {
        results = await _giphyService.fetchTrending(offset: 0, limit: _PAGE_LIMIT);
      } else {
        results = await _giphyService.searchGifs(query: query, offset: 0, limit: _PAGE_LIMIT);
      }

      _setState(() {
        _stickers = results;
        _currentOffset = results.length;
        _hasMore = results.length >= _PAGE_LIMIT;
        _isLoading = false;
      });
    } catch (e) {
      _setState(() {
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  /// Scroll listener for infinite scroll
  void _onScroll() {
    if (_scrollController.position.pixels >=
        (_scrollController.position.maxScrollExtent - 200)) {
      _loadNextPage();
    }
  }

  /// setState wrapper (safe if disposed)
  void _setState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  // ─────────────────────────────────────────────
  // Recents Persistence (shared_preferences)
  // ─────────────────────────────────────────────
  static const String _kRecentsSPKey = 'vibefick_recents_stickers';

  /// App open හලෙ — disk තකේ saved recents load කරා
  Future<void> _loadRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_kRecentsSPKey);
      if (jsonString == null) return;

      final List<dynamic> decoded = jsonDecode(jsonString);
      final List<GiphySticker> loaded = decoded
          .map((e) => GiphySticker.fromJson(e as Map<String, dynamic>))
          .toList();

      _setState(() {
        _recentStickers = loaded;
      });
    } catch (_) {
      // Corrupted data හලෙ චුප් කරේ ignore — fresh start හබේ
    }
  }

  /// Sticker tap-එර් පර් — disk-එ save කරා
  Future<void> _saveRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> serialized = _recentStickers.map((s) {
        return <String, dynamic>{
          'id': s.id,
          'title': s.title,
          'gifUrl': s.gifUrl,
          'fixedWidthUrl': s.fixedWidthUrl,
          'fixedWidthHeight': s.fixedWidthHeight,
          'fixedWidthWidth': s.fixedWidthWidth,
        };
      }).toList();

      await prefs.setString(_kRecentsSPKey, jsonEncode(serialized));
    } catch (_) {
      // Save fail හලෙ චුප් — app crash හබේ නෑ
    }
  }

  /// On sticker tap → save to recents + return
  Future<void> _onStickerTap(GiphySticker sticker) async {
    // Add to recents (keep unique, max 50)
    _recentStickers.removeWhere((s) => s.id == sticker.id);
    _recentStickers.insert(0, sticker);
    if (_recentStickers.length > 50) _recentStickers = _recentStickers.take(50).toList();

    // Disk-එ persist කරා
    await _saveRecents();

    // හැමදාම original GIF URL එක return කරමු (best quality)
    if (mounted) {
      Navigator.pop(context, sticker.gifUrl);

      // Show snackbar feedback with haptic
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Added "${sticker.title}"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: const Color(0xFF21262D), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle ──
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF4A5568),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // ── Title Row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Stickers',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262D),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Search Bar (Sticky Header) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF30363D), width: 1.5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Search stickers...',
                        hintStyle: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  // Clear button
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: _searchController.text.isNotEmpty
                        ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF30363D),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF8B949E),
                          size: 14,
                        ),
                      ),
                    )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Tab Bar ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF21262D), width: 1),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFFFF3B5C),
              unselectedLabelColor: const Color(0xFF8B949E),
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              tabs: const [
                Tab(text: 'VibeFlick'),
                Tab(text: 'Recents'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Tab Body ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 0: VibeFlick (Giphy)
                _buildGiphyTab(),

                // Tab 1: Recents
                _buildRecentsTab(),
              ],
            ),
          ),

          // ── Powered by Giphy ──
          const _PoweredByGiphy(),
        ],
      ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // VibeFlick Tab (Giphy Grid + Infinite Scroll)
  // ─────────────────────────────────────────────
  Widget _buildGiphyTab() {
    // Offline state
    if (_isOffline && _stickers.isEmpty) {
      return _buildOfflineWidget();
    }

    // Initial loading (no data yet)
    if (_isLoading && _stickers.isEmpty) {
      return _buildShimmerGrid();
    }

    // Empty search result
    if (!_isLoading && _stickers.isEmpty) {
      return _buildEmptySearchWidget();
    }

    // Main grid with improved layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header label: Trending or Search results
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              if (_currentQuery.isEmpty)
                const Icon(Icons.local_fire_department_rounded,
                    color: Color(0xFFFF3B5C), size: 16),
              if (_currentQuery.isNotEmpty)
                const Icon(Icons.search_rounded,
                    color: Color(0xFF8B949E), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _currentQuery.isEmpty
                      ? 'Trending'
                      : 'Results for "$_currentQuery"',
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Grid with improved spacing
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0, // Square grid for consistency
            ),
            itemCount: _stickers.length + (_hasMore ? 3 : 0),
            itemBuilder: (context, index) {
              // Shimmer placeholders at the bottom while loading more
              if (index >= _stickers.length) {
                return _isLoading ? const _ShimmerBox() : const SizedBox.shrink();
              }

              final sticker = _stickers[index];
              return _GiphyStickerTile(
                sticker: sticker,
                onTap: () => _onStickerTap(sticker),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Recents Tab
  // ─────────────────────────────────────────────
  Widget _buildRecentsTab() {
    if (_recentStickers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF21262D), width: 2),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Color(0xFF6B7280),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No recent stickers',
              style: TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap a sticker to add it here',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: _recentStickers.length,
      itemBuilder: (context, index) {
        final sticker = _recentStickers[index];
        return _GiphyStickerTile(
          sticker: sticker,
          onTap: () => _onStickerTap(sticker),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Utility Widgets
  // ─────────────────────────────────────────────

  Widget _buildOfflineWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF21262D), width: 2),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFFFF3B5C),
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Internet Connection',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Please check your connection\nand try again.',
            style: TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _loadInitialTrending,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF3B5C), Color(0xFFFF1744)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF3B5C).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
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

  Widget _buildEmptySearchWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF21262D), width: 2),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: Color(0xFF6B7280),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No results for "$_currentQuery"',
            style: const TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Try a different keyword',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Full-screen shimmer grid (initial load)
  Widget _buildShimmerGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: 12,
      itemBuilder: (_, __) => const _ShimmerBox(),
    );
  }
}

// ─────────────────────────────────────────────
// Giphy Sticker Tile Widget
// ─────────────────────────────────────────────
class _GiphyStickerTile extends StatefulWidget {
  final GiphySticker sticker;
  final VoidCallback onTap;

  const _GiphyStickerTile({required this.sticker, required this.onTap});

  @override
  State<_GiphyStickerTile> createState() => __GiphyStickerTileState();
}

class __GiphyStickerTileState extends State<_GiphyStickerTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? const Color(0xFFFF3B5C).withOpacity(0.3)
                  : const Color(0xFF21262D),
              width: 1.5,
            ),
            boxShadow: _pressed ? [
              BoxShadow(
                color: const Color(0xFFFF3B5C).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // GIF Image with shimmer fallback
              Positioned.fill(
                child: _GifImageWidget(url: widget.sticker.fixedWidthUrl),
              ),
              // Gradient overlay at bottom for better title contrast
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xFF0D1117).withOpacity(0.9),
                        const Color(0xFF0D1117).withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Title with better styling
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text(
                    widget.sticker.title,
                    style: const TextStyle(
                      color: Color(0xFFE6EDF3),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(
                          color: Color(0xFF0D1117),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GIF Image with built-in Shimmer fallback
// ─────────────────────────────────────────────
class _GifImageWidget extends StatelessWidget {
  final String url;
  const _GifImageWidget({required this.url});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Shimmer always behind — image covers it once loaded
        const Positioned.fill(child: _ShimmerBox()),
        // Actual GIF image layered on top
        Positioned.fill(
          child: Image.network(
            url,
            fit: BoxFit.cover, // Changed to cover for better fill
            // Fade in once the first frame arrives
            frameBuilder: (context, child, frameIndex, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frameIndex != null) {
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: child,
                );
              }
              // Still loading → show nothing (shimmer underneath is visible)
              return const SizedBox.shrink();
            },
            errorBuilder: (_, __, ___) => Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.broken_image_rounded,
                  color: Color(0xFF4A5568),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Shimmer Box Widget (Animated placeholder)
// ─────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({super.key});

  @override
  State<_ShimmerBox> createState() => __ShimmerBoxState();
}

class __ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: const [
                Color(0xFF161B22),
                Color(0xFF21262D),
                Color(0xFF161B22),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// "Powered by Giphy" Footer Label
// ─────────────────────────────────────────────
class _PoweredByGiphy extends StatelessWidget {
  const _PoweredByGiphy({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        border: Border(
          top: BorderSide(color: Color(0xFF21262D), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Powered by',
            style: TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9933FF), Color(0xFF00CCFF)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'GIPHY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}