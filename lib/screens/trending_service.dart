// lib/services/trending_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'trending_models.dart';

class TrendingService {
  static const String baseUrl = 'https://avishka-tiktok-api.zeabur.app/api/trending';

  static Future<List<TrendingVideo>> getTrendingVideos({
    required String category,
    required String filter,
    int limit = 50, // ✅ More videos since we do client-side filtering
  }) async {
    try {
      print('📊 Fetching videos - category: $category, filter: $filter');

      // ✅ KEY FIX: Always fetch ALL videos from backend (avoid broken category routes)
      // Client-side filtering handles category separation reliably
      final response = await http.get(
        Uri.parse('$baseUrl/videos/All?filter=$filter&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> videosJson = data['videos'];

          // Parse all videos - category detection happens inside TrendingVideo.fromJson
          List<TrendingVideo> allVideos =
          videosJson.map((json) => TrendingVideo.fromJson(json)).toList();

          print('📥 Total fetched: ${allVideos.length} videos');

          // ✅ Client-side category filter (the only filtering we need)
          if (category != 'All' &&
              category != '#Hashtags' &&
              category != '🎵 Sounds') {
            allVideos = _filterByCategory(allVideos, category);
            print('🔍 After "$category" filter: ${allVideos.length} videos');
          }

          // Sort by views descending (highest views = most trending)
          allVideos.sort((a, b) => b.viewCount.compareTo(a.viewCount));

          return allVideos;
        }
      }

      print('⚠️ Backend returned: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ getTrendingVideos error: $e');
      return [];
    }
  }

  /// Client-side filter: match video's detected category to selected category
  /// Works for BOTH direct category field AND hashtag-based detection
  static List<TrendingVideo> _filterByCategory(
      List<TrendingVideo> videos,
      String selectedCategory,
      ) {
    return videos.where((video) {
      // Primary: exact category match (set by TrendingVideo.fromJson detection)
      if (video.category.toLowerCase() == selectedCategory.toLowerCase()) {
        return true;
      }

      // Secondary: direct hashtag keyword check as extra safety net
      final keywords = _getCategoryKeywords(selectedCategory);
      if (keywords.isNotEmpty) {
        final lowerHashtags = video.hashtags
            .map((h) => h.toLowerCase().replaceAll('#', '').trim())
            .toList();
        return lowerHashtags.any(
              (tag) => keywords.any((kw) => tag.contains(kw)),
        );
      }

      return false;
    }).toList();
  }

  static List<String> _getCategoryKeywords(String category) {
// ✅ REPLACE: keywords Map ඇතුළේ ඔක්කොම
    const Map<String, List<String>> keywords = {
      'Comedy': ['comedy', 'funny', 'humor', 'lol', 'hilarious', 'meme', 'laugh'],
      'LOL': ['lol', 'rofl', 'lmao', 'haha'],
      'Music': ['music', 'song', 'singer', 'beat', 'dj', 'rap', 'hiphop', 'pop'],
      'Dance': ['dance', 'dancing', 'choreography', 'dancer'],
      'Gaming': ['gaming', 'game', 'gamer', 'gameplay', 'esports', 'pubg', 'freefire'],
      'Tech': ['tech', 'technology', 'ai', 'gadget', 'coding', 'programming'],
      'Science': ['science', 'scientific', 'biology', 'chemistry', 'physics', 'experiment'], // ✅ NEW
      'Food': ['food', 'cooking', 'recipe', 'foodie', 'chef', 'yummy', 'delicious'],
      'Travel': ['travel', 'adventure', 'explore', 'journey', 'vacation', 'trip'],
      'Fashion': ['fashion', 'style', 'outfit', 'ootd', 'clothing', 'wear'],
      'Sports': ['sports', 'football', 'cricket', 'basketball', 'soccer'],
      'Fitness': ['fitness', 'workout', 'gym', 'training', 'exercise'],      // ✅ NEW
      'News': ['news', 'breaking', 'update', 'headline', 'journalist'],      // ✅ NEW
      'Politics': ['politics', 'political', 'election', 'government', 'vote'], // ✅ NEW
      'Film': ['film', 'movie', 'cinema', 'actor', 'actress', 'director'],   // ✅ NEW
      'Health': ['health', 'medical', 'doctor', 'wellness', 'mentalhealth'], // ✅ NEW
      'Money': ['money', 'finance', 'investment', 'stock', 'crypto', 'business'], // ✅ NEW
      'Culture': ['culture', 'cultural', 'tradition', 'heritage'],           // ✅ NEW
      'Anime': ['anime', 'manga', 'otaku', 'cosplay'],                       // ✅ NEW
      'Pets': ['pets', 'cat', 'dog', 'puppy', 'kitten', 'animals'],         // ✅ NEW
      'Books': ['books', 'reading', 'literature', 'author', 'novel'],       // ✅ NEW
      'Art': ['art', 'artwork', 'drawing', 'painting', 'artist'],           // ✅ NEW
      'Nature': ['nature', 'outdoor', 'environment', 'forest', 'ocean'],    // ✅ NEW
      'Education': ['education', 'learning', 'study', 'school', 'tutorial'], // ✅ NEW
    };
    return keywords[category] ?? [];
  }

  static Future<List<TrendingCreator>> getTrendingCreators({int limit = 10}) async {
    try {
      print('👥 Fetching creators...');
      final response = await http.get(Uri.parse('$baseUrl/creators?limit=$limit'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> creators = data['creators'];
          print('✅ Loaded ${creators.length} creators');
          return creators.map((json) => TrendingCreator.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ getTrendingCreators error: $e');
      return [];
    }
  }

  static Future<List<TrendingHashtag>> getTrendingHashtags({int limit = 10}) async {
    try {
      print('🏷️ Fetching hashtags...');
      final response = await http.get(Uri.parse('$baseUrl/hashtags?limit=$limit'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> hashtags = data['hashtags'];
          print('✅ Loaded ${hashtags.length} hashtags');
          return hashtags.map((json) => TrendingHashtag.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ getTrendingHashtags error: $e');
      return [];
    }
  }
}