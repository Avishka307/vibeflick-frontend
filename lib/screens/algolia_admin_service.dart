import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Algolia Admin Service
/// File: lib/services/algolia_admin_service.dart
///
/// ⚠️ ADMIN ONLY — නිදහසේ users ට expose නොකරන්න
/// Existing files (search_results_tabs, users_search_tab, etc.) touch නොකළා
/// ─────────────────────────────────────────────────────────────────────────
class AlgoliaAdminService {
  static const String _baseUrl = 'https://avishka-tiktok-api.zeabur.app';

  // ───────────────────────────────────────────────────────────────────────
  // 1️⃣  GET /api/admin/algolia/health
  //     Algolia indices empty ද, record counts check කරනවා
  // ───────────────────────────────────────────────────────────────────────
  static Future<AlgoliaHealthResult> checkAlgoliaHealth() async {
    debugPrint('\n🔍 ========== ALGOLIA HEALTH CHECK ==========');
    try {
      final response = await http
          .get(
        Uri.parse('$_baseUrl/api/admin/algolia/health'),
        headers: {'Content-Type': 'application/json'},
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('   HTTP Status : ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final health = data['health'] as Map<String, dynamic>? ?? {};

        final result = AlgoliaHealthResult(
          success: true,
          usersCount: (health['users']?['recordCount'] as num?)?.toInt() ?? 0,
          hashtagsCount:
          (health['hashtags']?['recordCount'] as num?)?.toInt() ?? 0,
          postsCount: (health['posts']?['recordCount'] as num?)?.toInt() ?? 0,
          needsSync: data['needsSync'] as bool? ?? true,
          message: data['message'] as String? ?? '',
          syncEndpoints: (data['syncEndpoints'] as Map?)
              ?.cast<String, String>() ??
              {},
        );

        debugPrint('   👥 Users     : ${result.usersCount} records');
        debugPrint('   #️⃣  Hashtags  : ${result.hashtagsCount} records');
        debugPrint('   🎬 Posts     : ${result.postsCount} records');
        debugPrint('   ⚠️  Needs sync: ${result.needsSync}');
        debugPrint('==========================================\n');
        return result;
      }

      debugPrint('   ❌ HTTP Error: ${response.statusCode}');
      debugPrint('==========================================\n');
      return AlgoliaHealthResult.error('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('   ❌ Exception: $e');
      debugPrint('==========================================\n');
      return AlgoliaHealthResult.error(e.toString());
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // 2️⃣  POST /api/admin/algolia/sync-users
  //     Firestore users collection → Algolia users index batch sync
  // ───────────────────────────────────────────────────────────────────────
  static Future<AlgoliaSyncResult> syncUsersToAlgolia() async {
    debugPrint('\n👥 ========== SYNC USERS TO ALGOLIA ==========');
    try {
      final response = await http
          .post(
        Uri.parse('$_baseUrl/api/admin/algolia/sync-users'),
        headers: {'Content-Type': 'application/json'},
      )
          .timeout(const Duration(seconds: 120));

      debugPrint('   HTTP Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final synced = (data['synced'] as num?)?.toInt() ?? 0;
        final total = (data['total'] as num?)?.toInt() ?? 0;

        debugPrint('   ✅ Synced: $synced / $total users');
        debugPrint('==========================================\n');

        return AlgoliaSyncResult(
          success: true,
          synced: synced,
          total: total,
          message: data['message'] as String? ?? 'Users synced',
        );
      }

      debugPrint('   ❌ HTTP Error: ${response.statusCode}');
      debugPrint('==========================================\n');
      return AlgoliaSyncResult.error('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('   ❌ Exception: $e');
      debugPrint('==========================================\n');
      return AlgoliaSyncResult.error(e.toString());
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // 3️⃣  POST /api/admin/algolia/sync-hashtags
  //     media_posts collection → Algolia hashtags index batch sync
  // ───────────────────────────────────────────────────────────────────────
  static Future<AlgoliaSyncResult> syncHashtagsToAlgolia() async {
    debugPrint('\n#️⃣  ========== SYNC HASHTAGS TO ALGOLIA ==========');
    try {
      final response = await http
          .post(
        Uri.parse('$_baseUrl/api/admin/algolia/sync-hashtags'),
        headers: {'Content-Type': 'application/json'},
      )
          .timeout(const Duration(seconds: 120));

      debugPrint('   HTTP Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final synced = (data['synced'] as num?)?.toInt() ?? 0;
        final topHashtags =
            (data['topHashtags'] as List?)?.cast<String>() ?? [];

        debugPrint('   ✅ Synced: $synced hashtags');
        if (topHashtags.isNotEmpty) {
          debugPrint('   🔥 Top: ${topHashtags.take(5).join(', ')}');
        }
        debugPrint('==========================================\n');

        return AlgoliaSyncResult(
          success: true,
          synced: synced,
          total: synced,
          message: data['message'] as String? ?? 'Hashtags synced',
          extra: {'topHashtags': topHashtags},
        );
      }

      debugPrint('   ❌ HTTP Error: ${response.statusCode}');
      debugPrint('==========================================\n');
      return AlgoliaSyncResult.error('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('   ❌ Exception: $e');
      debugPrint('==========================================\n');
      return AlgoliaSyncResult.error(e.toString());
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // 4️⃣  POST /search/batch-sync
  //     media_posts collection → Algolia video_posts index batch sync
  // ───────────────────────────────────────────────────────────────────────
  static Future<AlgoliaSyncResult> syncPostsToAlgolia() async {
    debugPrint('\n🎬 ========== SYNC POSTS TO ALGOLIA ==========');
    try {
      final response = await http
          .post(
        Uri.parse('$_baseUrl/search/batch-sync'),
        headers: {'Content-Type': 'application/json'},
      )
          .timeout(const Duration(seconds: 180));

      debugPrint('   HTTP Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final synced = (data['synced'] as num?)?.toInt() ?? 0;

        debugPrint('   ✅ Synced: $synced posts');
        debugPrint('==========================================\n');

        return AlgoliaSyncResult(
          success: true,
          synced: synced,
          total: synced,
          message: data['message'] as String? ?? 'Posts synced',
        );
      }

      debugPrint('   ❌ HTTP Error: ${response.statusCode}');
      debugPrint('==========================================\n');
      return AlgoliaSyncResult.error('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('   ❌ Exception: $e');
      debugPrint('==========================================\n');
      return AlgoliaSyncResult.error(e.toString());
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // 5️⃣  Full sync — health check කරලා empty indices auto-sync
  //     Admin screen "Sync Now" button ට call කරන්න
  // ───────────────────────────────────────────────────────────────────────
  static Future<void> runFullSyncIfNeeded({
    void Function(String message)? onProgress,
  }) async {
    debugPrint('\n🚀 ========== FULL ALGOLIA SYNC ==========');

    onProgress?.call('Checking Algolia indices...');
    final health = await checkAlgoliaHealth();

    if (!health.success) {
      onProgress?.call('Health check failed: ${health.message}');
      return;
    }

    if (!health.needsSync) {
      onProgress?.call('✅ All indices up-to-date. Sync not needed.');
      return;
    }

    if (health.usersCount == 0) {
      onProgress?.call('Syncing users...');
      final r = await syncUsersToAlgolia();
      onProgress?.call(
        r.success ? '👥 Users synced: ${r.synced} ✅' : 'Users sync failed ❌',
      );
    }

    if (health.hashtagsCount == 0) {
      onProgress?.call('Syncing hashtags...');
      final r = await syncHashtagsToAlgolia();
      onProgress?.call(
        r.success
            ? '#️⃣ Hashtags synced: ${r.synced} ✅'
            : 'Hashtags sync failed ❌',
      );
    }

    if (health.postsCount == 0) {
      onProgress?.call('Syncing posts...');
      final r = await syncPostsToAlgolia();
      onProgress?.call(
        r.success ? '🎬 Posts synced: ${r.synced} ✅' : 'Posts sync failed ❌',
      );
    }

    onProgress?.call('🎉 Full sync complete!');
    debugPrint('==========================================\n');
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Result Models
// ─────────────────────────────────────────────────────────────────────────

class AlgoliaHealthResult {
  final bool success;
  final int usersCount;
  final int hashtagsCount;
  final int postsCount;
  final bool needsSync;
  final String message;
  final Map<String, String> syncEndpoints;

  const AlgoliaHealthResult({
    required this.success,
    this.usersCount = 0,
    this.hashtagsCount = 0,
    this.postsCount = 0,
    this.needsSync = true,
    this.message = '',
    this.syncEndpoints = const {},
  });

  factory AlgoliaHealthResult.error(String msg) =>
      AlgoliaHealthResult(success: false, message: msg, needsSync: true);
}

class AlgoliaSyncResult {
  final bool success;
  final int synced;
  final int total;
  final String message;
  final Map<String, dynamic> extra;

  const AlgoliaSyncResult({
    required this.success,
    this.synced = 0,
    this.total = 0,
    this.message = '',
    this.extra = const {},
  });

  factory AlgoliaSyncResult.error(String msg) =>
      AlgoliaSyncResult(success: false, message: msg);
}