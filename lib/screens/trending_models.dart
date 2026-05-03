// lib/models/trending_models.dart

class TrendingVideo {
  final String postId;
  final String creatorId;
  final String username;
  final String mediaUrl;
  final String mediaType;
  final String description;
  final List<String> hashtags;
  final String category;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;

  TrendingVideo({
    required this.postId,
    required this.creatorId,
    required this.username,
    required this.mediaUrl,
    required this.mediaType,
    required this.description,
    required this.hashtags,
    required this.category,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
  });

  factory TrendingVideo.fromJson(Map<String, dynamic> json) {
    final hashtags = (json['hashtags'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ??
        [];

    // ✅ Dual category detection: direct field → hashtag fallback
    final category = _detectCategoryFromData(
      categoryField: json['category'],
      hashtags: hashtags,
    );

    // ✅ VIEWS FIX: Try multiple field names (backend may use different naming)
    final viewCount = _parseCount(json['view_count']) ??
        _parseCount(json['views']) ??
        _parseCount(json['viewCount']) ??
        _parseCount(json['view_count_total']) ??
        0;

    // ✅ LIKES FIX: Try multiple field names
    final likeCount = _parseCount(json['like_count']) ??
        _parseCount(json['likes']) ??
        _parseCount(json['likeCount']) ??
        _parseCount(json['likes_count']) ??
        0;

    // ✅ COMMENTS FIX: Try multiple field names
    final commentCount = _parseCount(json['comments']) ??
        _parseCount(json['comment_count']) ??
        _parseCount(json['commentCount']) ??
        0;

    return TrendingVideo(
      postId: json['post_id'] ?? json['id'] ?? '',
      creatorId: json['creator_id'] ?? json['user_id'] ?? '',
      username: json['username'] ?? json['name'] ?? 'Unknown',
      mediaUrl: json['media_url'] ?? json['url'] ?? '',
      mediaType: json['media_type'] ?? json['type'] ?? 'image',
      description: json['description'] ?? json['caption'] ?? '',
      hashtags: hashtags,
      category: category,
      viewCount: viewCount,
      likeCount: likeCount,
      commentCount: commentCount,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Parse int from dynamic value safely
  static int? _parseCount(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Category detection:
  /// Step 1 → Direct `category` field
  /// Step 2 → Hashtag analysis
  /// Step 3 → Default "All"
  static String _detectCategoryFromData({
    dynamic categoryField,
    required List<String> hashtags,
  }) {
    // Step 1: Check direct category field
    if (categoryField != null) {
      final raw = categoryField.toString().trim();
      if (raw.isNotEmpty &&
          raw.toLowerCase() != 'other' &&
          raw.toLowerCase() != 'general' &&
          raw.toLowerCase() != 'all') {
        final normalized = _normalizeCategoryName(raw);
        if (normalized != null) return normalized;
      }
    }

    // Step 2: Hashtag analysis fallback
    if (hashtags.isNotEmpty) {
      final detected = _detectCategoryFromHashtags(hashtags);
      if (detected != null) return detected;
    }

    // Step 3: Default
    return 'All';
  }

  /// Map raw category string to standardized UI category name
  static String? _normalizeCategoryName(String raw) {
// ✅ REPLACE: _normalizeCategoryName() method ඇතුලේ categoryMap
    const categoryMap = {
      // Existing
      'comedy': 'Comedy', 'funny': 'Comedy', 'humor': 'Comedy', 'lol': 'LOL',
      'music': 'Music', 'song': 'Music', 'audio': 'Music',
      'gaming': 'Gaming', 'game': 'Gaming', 'gamer': 'Gaming',
      'tech': 'Technology', 'technology': 'Tech', 'ai': 'Tech',
      'dance': 'Dance', 'dancing': 'Dance',
      'food': 'Food', 'cooking': 'Food', 'recipe': 'Food',
      'travel': 'Travel', 'adventure': 'Travel',
      'fashion': 'Fashion', 'style': 'Fashion', 'outfit': 'Fashion',
      'sports': 'Sports', 'sport': 'Sports',
      'fitness': 'Fitness',   // ✅ Sports නෙවෙයි
      'workout': 'Fitness',   // ✅ Sports නෙවෙයි
      // ✅ NEW categories
      'news': 'News',
      'politics': 'Politics', 'political': 'Politics',
      'film': 'Film', 'movie': 'Film', 'cinema': 'Film',
      'health': 'Health', 'medical': 'Health', 'wellness': 'Health',
      'money': 'Money', 'finance': 'Money', 'business': 'Money',
      'culture': 'Culture', 'cultural': 'Culture',
      'science': 'Science', 'scientific': 'Science',  // ✅ Tech නෙවෙයි
      'anime': 'Anime', 'manga': 'Anime',
      'pets': 'Pets', 'animals': 'Pets', 'cats': 'Pets', 'dogs': 'Pets',
      'books': 'Books', 'reading': 'Books', 'literature': 'Books',
      'art': 'Art', 'artwork': 'Art', 'drawing': 'Art', 'painting': 'Art',
      'nature': 'Nature', 'outdoors': 'Nature', 'environment': 'Nature',
      'education': 'Education', 'learning': 'Education', 'study': 'Education',
    };

    final lower = raw.toLowerCase().trim();
    return categoryMap[lower]; // null if not found = no match
  }

  /// Score hashtags against keyword lists, return highest-matching category
  static String? _detectCategoryFromHashtags(List<String> hashtags) {
    // ✅ REPLACE: hashtagCategoryMap ඇතුළේ ඔක්කොම
    const hashtagCategoryMap = {
      'Comedy': ['comedy', 'funny', 'humor', 'hilarious', 'jokes', 'meme', 'laugh'],
      'LOL': ['lol', 'rofl', 'lmao'],
      'Music': ['music', 'song', 'singer', 'musician', 'beat', 'rhythm', 'hiphop', 'pop', 'rock', 'dj', 'concert', 'rap'],
      'Dance': ['dance', 'dancing', 'choreography', 'dancer', 'moves'],
      'Gaming': ['gaming', 'game', 'gamer', 'gameplay', 'esports', 'stream', 'fps', 'rpg', 'pubg', 'freefire'],
      'Tech': ['tech', 'technology', 'ai', 'gadget', 'phone', 'computer', 'innovation', 'robot', 'coding', 'programming'],
      'Science': ['science', 'scientific', 'biology', 'chemistry', 'physics', 'experiment', 'research'],  // ✅ NEW
      'Food': ['food', 'cooking', 'recipe', 'foodie', 'yummy', 'chef', 'kitchen', 'eat', 'delicious'],
      'Travel': ['travel', 'adventure', 'explore', 'journey', 'destination', 'trip', 'vacation', 'tour', 'wanderlust'],
      'Fashion': ['fashion', 'style', 'outfit', 'ootd', 'look', 'clothing', 'wear', 'model', 'trendy'],
      'Sports': ['sports', 'football', 'cricket', 'basketball', 'athlete', 'soccer'],
      'Fitness': ['fitness', 'workout', 'gym', 'training', 'exercise', 'bodybuilding'],  // ✅ Sports වෙන් කළා
      'News': ['news', 'breaking', 'update', 'headline', 'journalist', 'media'],         // ✅ NEW
      'Politics': ['politics', 'political', 'election', 'government', 'policy', 'vote'], // ✅ NEW
      'Film': ['film', 'movie', 'cinema', 'actor', 'actress', 'director', 'hollywood'],  // ✅ NEW
      'Health': ['health', 'medical', 'doctor', 'wellness', 'mentalhealth', 'nutrition'], // ✅ NEW
      'Money': ['money', 'finance', 'investment', 'stock', 'crypto', 'business', 'entrepreneur'], // ✅ NEW
      'Culture': ['culture', 'cultural', 'tradition', 'heritage', 'ethnic'],              // ✅ NEW
      'Anime': ['anime', 'manga', 'otaku', 'cosplay', 'naruto', 'onepiece'],             // ✅ NEW
      'Pets': ['pets', 'cat', 'dog', 'puppy', 'kitten', 'animals', 'wildlife'],         // ✅ NEW
      'Books': ['books', 'reading', 'literature', 'author', 'novel', 'booktok'],        // ✅ NEW
      'Art': ['art', 'artwork', 'drawing', 'painting', 'artist', 'illustration'],       // ✅ NEW
      'Nature': ['nature', 'outdoor', 'environment', 'forest', 'ocean', 'wildlife'],    // ✅ NEW
      'Education': ['education', 'learning', 'study', 'school', 'university', 'tutorial'], // ✅ NEW
    };

    final Map<String, int> scores = {};

    for (final hashtag in hashtags) {
      final tagLower = hashtag.toLowerCase().replaceAll('#', '').trim();
      for (final entry in hashtagCategoryMap.entries) {
        if (entry.value.any((kw) => tagLower.contains(kw))) {
          scores[entry.key] = (scores[entry.key] ?? 0) + 1;
        }
      }
    }

    if (scores.isEmpty) return null;
    return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String get thumbnailUrl {
    if (mediaUrl.contains('cloudinary.com')) {
      return mediaUrl.replaceFirst(
          '/upload/', '/upload/w_400,h_600,c_fill,q_auto/');
    }
    return mediaUrl;
  }
}

class TrendingCreator {
  final String id;
  final String name;
  final String avatar;
  final bool isVerified;
  final int followerCount;
  final int totalViews; // 🆕 Supabase/Firestore views

  TrendingCreator({
    required this.id,
    required this.name,
    required this.avatar,
    required this.isVerified,
    required this.followerCount,
    this.totalViews = 0,

  });

  factory TrendingCreator.fromJson(Map<String, dynamic> json) {
    return TrendingCreator(
      id: json['id'] ?? json['uid'] ?? json['creator_id'] ?? '',
      name: json['name'] ?? json['username'] ?? 'Unknown',
      avatar: json['avatar'] ?? json['avatar_url'] ?? json['profile_image'] ?? '',
      isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
      followerCount: json['followerCount'] ?? json['follower_count'] ?? json['followers'] ?? 0,
      totalViews: _parseViewCount(json), // ✅ duplicate line remove කළා
    );
  }

  static int _parseViewCount(Map<String, dynamic> json) {
    final keys = [
      'totalViews', 'total_views', 'view_count',
      'viewCount', 'views', 'total_view_count'
    ];
    for (final key in keys) {
      final val = json[key];
      if (val == null) continue;
      if (val is int && val > 0) return val;
      if (val is double && val > 0) return val.toInt();
      if (val is String) {
        final parsed = int.tryParse(val);
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return 0;
  }
}
class TrendingHashtag {
  final String hashtag;
  final int videoCount;
  final int views;

  TrendingHashtag({
    required this.hashtag,
    required this.videoCount,
    required this.views,
  });

  factory TrendingHashtag.fromJson(Map<String, dynamic> json) {
    return TrendingHashtag(
      hashtag: json['hashtag'] ?? '',
      videoCount: json['videoCount'] ?? json['video_count'] ?? json['count'] ?? 0,
      views: json['views'] ?? json['view_count'] ?? json['total_views'] ?? 0,
    );
  }

  String get formattedViews {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return views.toString();
  }

  String get formattedVideoCount {
    if (videoCount >= 1000) return '${(videoCount / 1000).toStringAsFixed(1)}K';
    return videoCount.toString();
  }
}