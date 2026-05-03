import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:my_vibe_flick/screens/post_detail_page.dart';
import '../search_page.dart';
import 'activity_user_profile.dart';
import 'trending_models.dart';
import 'trending_service.dart';
import 'shimmer_loading.dart';

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  String selectedCategory = 'All';
  String selectedFilter = 'today';

  bool isLoadingVideos = false;
  bool isLoadingCreators = false;
  bool isLoadingHashtags = false;

  // 🆕 Internet connection state
  bool _hasInternetConnection = true;
  bool _showNoInternetToast = false;

  List<TrendingVideo> trendingVideos = [];
  List<TrendingCreator> trendingCreators = [];
  List<TrendingHashtag> trendingHashtags = [];

  final List<String> categories = [
    'All',
    'Comedy',
    'Music',
    'Gaming',
    'Tech',
    'Dance',
    'Food',
    'Travel',
    'Fashion',
    'Sports',
    '#Hashtags',
    '🎵 Sounds',
    // ── New additions ──
    'News',
    'Politics',
    'Film',
    'Health',
    'Money',
    'Culture',
    'Science',
    'Anime',
    'LOL',
    'Pets',
    'Books',
    'Art',
    'Fitness',
    'Nature',
    'Education',
  ];

  @override
  void initState() {
    super.initState();
    _initWithConnectionCheck();
  }

  // 🆕 Check internet then load data
  // _initWithConnectionCheck REPLACE
  Future<void> _initWithConnectionCheck() async {
    final hasNet = await _checkInternetConnection();
    if (hasNet) {
      await _loadInitialData();
    } else {
      setState(() {
        isLoadingVideos = false;
        isLoadingCreators = false;
      });
    }
  }

  // 🆕 Show "No Internet" toast
  void _showNoInternetConnection() {
    if (!_showNoInternetToast) {
      setState(() {
        _showNoInternetToast = true;
        _hasInternetConnection = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 12),
              Text('No internet connection'),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showNoInternetToast = false;
          });
        }
      });
    }
  }

  // 🆕 Check internet connectivity
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        setState(() {
          _hasInternetConnection = true;
        });
        return true;
      }
    } catch (e) {
      setState(() {
        _hasInternetConnection = false;
      });
      _showNoInternetConnection();
      return false;
    }
    return false;
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadTrendingVideos(),
      _loadTrendingCreators(),
    ]);
  }

  Future<void> _loadTrendingVideos() async {
    setState(() => isLoadingVideos = true);

    final videos = await TrendingService.getTrendingVideos(
      category: selectedCategory,
      filter: selectedFilter,
    );

    setState(() {
      trendingVideos = videos;
      isLoadingVideos = false;
    });
  }

  Future<void> _loadTrendingCreators() async {
    setState(() => isLoadingCreators = true);
    final creators = await TrendingService.getTrendingCreators();

    // 🔧 DEBUG
    debugPrint('📦 Raw creators: ${creators.length}');
    for (final c in creators) {
      debugPrint('   ID: ${c.id} | Name: ${c.name} | Avatar: ${c.avatar} | Views: ${c.totalViews}');
    }

    final enrichedCreators = await _enrichCreatorsFromFirestore(creators);
    setState(() {
      trendingCreators = enrichedCreators;
      isLoadingCreators = false;
    });
  }
  Future<List<TrendingCreator>> _enrichCreatorsFromFirestore(
      List<TrendingCreator> creators) async {
    // Backend දැන් Firestore data include කරනවා
    // Avatar empty නම් විතරක් fetch කරන්න
    final needsEnrichment = creators.where((c) => c.avatar.isEmpty).toList();

    if (needsEnrichment.isEmpty) return creators;

    debugPrint('🔄 Enriching ${needsEnrichment.length} creators without avatar...');

    final enriched = <String, TrendingCreator>{};
    for (final c in creators) {
      enriched[c.id] = c;
    }

    for (final creator in needsEnrichment) {
      try {
        final response = await http.get(
          Uri.parse('https://avishka-tiktok-api.zeabur.app/profile/${creator.id}'),
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true && data['data'] != null) {
            final d = data['data'] as Map<String, dynamic>;
            enriched[creator.id] = TrendingCreator(
              id: creator.id,
              name: d['name'] ?? creator.name,
              avatar: d['profileImageUrl'] ?? d['profile_picture_url'] ?? creator.avatar,
              isVerified: d['isVerified'] ?? creator.isVerified,
              followerCount: d['followerCount'] ?? creator.followerCount,
              totalViews: creator.totalViews,
            );
          }
        }
      } catch (e) {
        debugPrint('⚠️ Enrich error for ${creator.id}: $e');
      }
    }

    return creators.map((c) => enriched[c.id] ?? c).toList();
  }
  Future<void> _loadTrendingHashtags() async {
    setState(() => isLoadingHashtags = true);
    final hashtags = await TrendingService.getTrendingHashtags();
    setState(() {
      trendingHashtags = hashtags;
      isLoadingHashtags = false;
    });
  }

  void _onCategoryChanged(String category) {
    setState(() => selectedCategory = category);

    if (category == '#Hashtags') {
      _loadTrendingHashtags();
    } else if (category != '🎵 Sounds') {
      _loadTrendingVideos();
    }
  }

  void _onFilterChanged(String filter) {
    setState(() => selectedFilter = filter);
    if (selectedCategory != '#Hashtags' && selectedCategory != '🎵 Sounds') {
      _loadTrendingVideos();
    }
  }

  // 🆕 Navigate to post detail page on video tap
  void _onVideoTap(TrendingVideo video) {
    // 🆕 Sync view to Supabase
    _syncViewToSupabase(video.postId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          postId: video.postId,
        ),
      ),
    );
  }

// 🆕 ADD this method
  void _syncViewToSupabase(String postId) {
    const backendUrl = 'http://10.109.149.236:5000/api/posts/view';
    http.post(
      Uri.parse(backendUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'postId': postId}),
    ).then((_) {
      debugPrint('✅ Trending view synced: $postId');
    }).catchError((e) {
      debugPrint('⚠️ View sync failed: $e');
    });
  }

  String formatViews(int views) {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return views.toString();
  }

  String _getCategoryEmoji(String category) {
    const Map<String, String> emojis = {
      'Comedy': '😂',
      'Music': '🎵',
      'Gaming': '🎮',
      'Tech': '💻',
      'Dance': '💃',
      'Food': '🍔',
      'Travel': '✈️',
      'Fashion': '👗',
      'Sports': '⚽',
      'All': '🔥',
      // ── New additions ──
      'News': '📰',
      'Politics': '🏛️',
      'Film': '🎬',
      'Health': '💊',
      'Money': '💰',
      'Culture': '🌍',
      'Science': '🔬',
      'Anime': '⛩️',
      'LOL': '🤣',
      'Pets': '🐾',
      'Books': '📚',
      'Art': '🎨',
      'Fitness': '💪',
      'Nature': '🌿',
      'Education': '🎓',
    };

    return emojis[category] ?? '📌';
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final screenWidth = MediaQuery.of(context).size.width;
    final itemSize = (screenWidth - 32 - 8) / 3;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final hasNet = await _checkInternetConnection();
                  if (hasNet) await _loadInitialData();
                },
                backgroundColor: const Color(0xFF1A1A1A),
                color: const Color(0xFFFF3B5C),
                child: ListView(
                  children: [
                    _buildCategoriesChips(),
                    _buildTimeFilters(),
                    _buildContentBasedOnCategory(itemSize),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchPage()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
          ),
          child: const AbsorbPointer(
            child: TextField(
              style: TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search for videos, creators...',
                hintStyle: TextStyle(color: Color(0xFF666666), fontSize: 15),
                prefixIcon: Icon(Icons.search, color: Color(0xFF888888), size: 22),
                border: InputBorder.none,
                contentPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildCategoriesChips() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category;
          return GestureDetector(
            onTap: () => _onCategoryChanged(category),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                    colors: [Color(0xFFFF3B5C), Color(0xFFFF1744)])
                    : null,
                color: isSelected ? null : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF3B5C)
                      : const Color(0xFF2A2A2A),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: const Color(0xFFFF3B5C).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
                    : [],
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color:
                    isSelected ? Colors.white : const Color(0xFF888888),
                    fontSize: 14,
                    fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _buildTimeFilterButton('Today', 'today'),
          const SizedBox(width: 8),
          _buildTimeFilterButton('This Week', 'week'),
          const SizedBox(width: 8),
          _buildTimeFilterButton('This Month', 'month'),
        ],
      ),
    );
  }

  Widget _buildTimeFilterButton(String label, String value) {
    final isActive = selectedFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onFilterChanged(value),
        child: Container(
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                colors: [Colors.white, Color(0xFFF0F0F0)])
                : null,
            color: isActive ? null : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive ? Colors.white : const Color(0xFF2A2A2A),
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ]
                : [],
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.black : const Color(0xFF666666),
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentBasedOnCategory(double itemSize) {
    if (selectedCategory == '#Hashtags') {
      return _buildHashtagsList();
    }
    if (selectedCategory == '🎵 Sounds') {
      return _buildSoundsList();
    }

    return Column(
      children: [
        // ✅ Category header shown when specific category selected
        if (selectedCategory != 'All') _buildCategoryHeader(),

        _buildTrendingCreators(),

        isLoadingVideos
            ? const VideoGridShimmer()
            : trendingVideos.isEmpty
            ? _buildEmptyState()
            : _buildVideoGrid(itemSize),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCategoryHeader() {
    final emoji = _getCategoryEmoji(selectedCategory);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF3B5C), Color(0xFFFF1744)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF3B5C).withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  'Trending in $selectedCategory',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (!isLoadingVideos)
            Text(
              '${trendingVideos.length} videos',
              style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
            ),
        ],
      ),
    );
  }
  Widget _buildTrendingCreators() {
    // 🆕 Top 3 creators by views badge සඳහා
    final sorted = [...trendingCreators]
      ..sort((a, b) => b.totalViews.compareTo(a.totalViews));
    final top3Ids = sorted.take(3).map((c) => c.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            '🔥 Trending Creators',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700),
          ),
        ),
        isLoadingCreators
            ? const CreatorsShimmer()
            : SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: trendingCreators.length,
            itemBuilder: (context, index) {
              final rank = top3Ids.indexOf(trendingCreators[index].id);
              return _buildCreatorItem(trendingCreators[index], rank);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorItem(TrendingCreator creator, int rankIndex) {
    // 🆕 Badge colors for top 3
    const badgeData = [
      {'emoji': '🥇', 'color': Color(0xFFFFD700)},
      {'emoji': '🥈', 'color': Color(0xFFC0C0C0)},
      {'emoji': '🥉', 'color': Color(0xFFCD7F32)},
    ];
    final hasBadge = rankIndex >= 0 && rankIndex < 3;

    return GestureDetector(
      onTap: () {
        if (creator.id.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActivityUserProfile(userId: creator.id),
            ),
          );
        }
      },
      child: Container(
        width: 75,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasBadge
                          ? (badgeData[rankIndex]['color'] as Color)
                          : const Color(0xFFFF3B5C),
                      width: hasBadge ? 3 : 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (hasBadge
                            ? (badgeData[rankIndex]['color'] as Color)
                            : const Color(0xFFFF3B5C))
                            .withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: creator.avatar.isNotEmpty
                        ? Image.network(
                      creator.avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildAvatarFallback(creator.name);
                      },
                    )
                        : _buildAvatarFallback(creator.name),
                  ),
                ),

                // 🆕 Top 3 badge
                if (hasBadge)
                  Positioned(
                    top: -6,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: badgeData[rankIndex]['color'] as Color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: Text(
                        badgeData[rankIndex]['emoji'] as String,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),

                // Verified badge
                if (creator.isVerified)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Icon(Icons.check, size: 10, color: Colors.black),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              creator.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            // 🆕 View count display
            if (creator.totalViews > 0)
        // 🆕 View count — 0 වුණත් fallback text පෙන්වන්න
        Text(
    creator.totalViews > 0
    ? '${formatViews(creator.totalViews)} views'
        : '${formatViews(creator.followerCount)} followers',
    style: const TextStyle(
    color: Color(0xFF888888),
    fontSize: 10,
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    ),

          ],
        ),
      ),
    );
  }

// 🆕 Helper: Avatar fallback
  Widget _buildAvatarFallback(String name) {
    final colors = [
      const Color(0xFF3B82F6), const Color(0xFFE53935),
      const Color(0xFF10B981), const Color(0xFF8B5CF6),
    ];
    final color = colors[name.hashCode.abs() % colors.length];
    return Container(
      color: color,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24),
        ),
      ),
    );
  }

  Widget _buildVideoGrid(double itemSize) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 0.67,
        ),
        itemCount: trendingVideos.length,
        itemBuilder: (context, index) {
          return _buildVideoItem(trendingVideos[index], itemSize);
        },
      ),
    );
  }

  // 🆕 UPDATED: Tap navigates to post_detail_page + view count always visible
  Widget _buildVideoItem(TrendingVideo video, double itemSize) {
    return GestureDetector(
      onTap: () => _onVideoTap(video),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[900],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              Image.network(
                video.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.image, color: Colors.grey),
                  );
                },
              ),

              // Bottom gradient
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7)
                      ],
                    ),
                  ),
                ),
              ),

              // Category emoji badge (only when "All" tab)
              if (selectedCategory == 'All' && video.category != 'All')
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getCategoryEmoji(video.category),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),

              // View/Like count badge
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        video.viewCount > 0 ? Icons.remove_red_eye : Icons.favorite,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        video.viewCount > 0
                            ? formatViews(video.viewCount)
                            : video.likeCount > 0
                            ? formatViews(video.likeCount)
                            : '—',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHashtagsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 16, bottom: 16),
            child: Text(
              '🔥 Trending Hashtags',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
          ),
          if (isLoadingHashtags)
            ...List.generate(
              5,
                  (index) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ShimmerLoading(width: double.infinity, height: 60),
              ),
            )
          else
            ...trendingHashtags.asMap().entries.map((entry) {
              return _buildHashtagItem(entry.value, entry.key);
            }).toList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHashtagItem(TrendingHashtag trend, int index) {
    List<Color> getRankColors(int i) {
      if (i == 0) return [const Color(0xFFFFD700), const Color(0xFFFFA500)];
      if (i == 1) return [const Color(0xFFC0C0C0), const Color(0xFF808080)];
      if (i == 2) return [const Color(0xFFCD7F32), const Color(0xFF8B4513)];
      return [const Color(0xFF1A1A1A), const Color(0xFF2A2A2A)];
    }

    return GestureDetector(
      onTap: () => print('Search: ${trend.hashtag}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border:
          Border(bottom: BorderSide(color: Color(0xFF1A1A1A), width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: getRankColors(index),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trend.hashtag,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.remove_red_eye_outlined,
                          size: 14, color: Color(0xFF888888)),
                      const SizedBox(width: 4),
                      Text(
                        '${trend.formattedViews} views',
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trend.formattedVideoCount,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const Text('videos',
                    style:
                    TextStyle(color: Color(0xFF888888), fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundsList() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Text(
          '🎵 Sounds feature coming soon!',
          style: TextStyle(color: Color(0xFF888888), fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.video_library_outlined,
                size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              selectedCategory == 'All'
                  ? 'No trending videos yet'
                  : 'No trending $selectedCategory videos yet',
              style:
              const TextStyle(color: Color(0xFF888888), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (selectedCategory != 'All')
              Text(
                'Be the first to post in ${_getCategoryEmoji(selectedCategory)} $selectedCategory!',
                style:
                const TextStyle(color: Color(0xFF555555), fontSize: 13),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}