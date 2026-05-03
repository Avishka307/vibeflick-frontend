import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // 🆕 ADD TO pubspec.yaml
import 'dart:io';

/// 🎬 Video Cache Manager
/// වීඩියෝ cache කරලා local storage එකේ තියන්න පාවිච්චි කරන helper class
class VideoCacheManager {
  static const String key = 'vibeflic_video_cache';
  static const int maxCacheObjects = 50;
  static const Duration maxCacheDuration = Duration(days: 7);

  // ─── 🆕 RETRY LOGIC CONFIG ────────────────────────────────────────────────
  static const int _maxRetryAttempts = 3;
  static const Duration _retryBaseDelay = Duration(milliseconds: 800);

  // ─── 🆕 NETWORK-AWARE PREFETCH CONFIG ────────────────────────────────────
  /// WiFi ඇති නම් මේ ගණනක් ahead prefetch කරනවා
  static const int _wifiPrefetchDistance = 3;
  /// Mobile Data ඇති නම් ඊළඟ 1 විතරක් prefetch කරනවා
  static const int _mobilePrefetchDistance = 1;

  // ─── 🆕 SMART PREFETCH PRIORITY QUEUE ────────────────────────────────────
  /// Prefetch in-progress URLs — duplicate requests skip කරනවා
  static final Set<String> _prefetchInProgress = {};
  /// Priority queue: (index, url) pairs sorted nearest-first
  static final List<_PrefetchTask> _prefetchQueue = [];
  static bool _isProcessingQueue = false;

  static CacheManager? _instance;

  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: maxCacheDuration,
        maxNrOfCacheObjects: maxCacheObjects,
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(),
      ),
    );
    return _instance!;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🆕 FEATURE 1: NETWORK AWARENESS
  // ══════════════════════════════════════════════════════════════════════════

  /// දැනට ඇත්තේ WiFi ද Mobile Data ද කියා check කරනවා
  static Future<_NetworkType> _getNetworkType() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.wifi) {
        return _NetworkType.wifi;
      } else if (result == ConnectivityResult.mobile) {
        return _NetworkType.mobile;
      }
      return _NetworkType.none;
    } catch (e) {
      debugPrint('⚠️ Network type check failed: $e');
      return _NetworkType.mobile; // safe default — mobile limits apply
    }
  }

  /// Network type එක අනුව prefetch distance එක ලබා දෙනවා
  static Future<int> getPrefetchDistance() async {
    final type = await _getNetworkType();
    final distance =
    type == _NetworkType.wifi ? _wifiPrefetchDistance : _mobilePrefetchDistance;
    debugPrint(
        '📶 Network: ${type.name} → prefetch distance: $distance');
    return distance;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🆕 FEATURE 2: SMART PREFETCH PRIORITY
  // ══════════════════════════════════════════════════════════════════════════

  /// Smart prefetch: Network-aware + nearest-first priority
  ///
  /// [videoUrls]     — full feed URL list
  /// [currentIndex]  — user's current position in the list
  static Future<void> smartPrefetch({
    required List<String> videoUrls,
    required int currentIndex,
  }) async {
    final prefetchDistance = await getPrefetchDistance();

    // Build priority tasks nearest→farthest
    for (int offset = 1; offset <= prefetchDistance; offset++) {
      final targetIndex = currentIndex + offset;
      if (targetIndex >= videoUrls.length) break;

      final url = videoUrls[targetIndex];
      if (_prefetchInProgress.contains(url)) continue;

      // Lower offset = higher priority (insert near front)
      _prefetchQueue.insert(
        offset - 1 < _prefetchQueue.length ? offset - 1 : _prefetchQueue.length,
        _PrefetchTask(index: targetIndex, url: url, priority: offset),
      );
    }

    // Sort ascending by priority (nearest first)
    _prefetchQueue.sort((a, b) => a.priority.compareTo(b.priority));

    if (!_isProcessingQueue) {
      _processQueue();
    }
  }

  /// Queue processor — tasks are executed one-by-one, nearest first
  static Future<void> _processQueue() async {
    _isProcessingQueue = true;

    while (_prefetchQueue.isNotEmpty) {
      final task = _prefetchQueue.removeAt(0);

      if (_prefetchInProgress.contains(task.url)) continue;

      _prefetchInProgress.add(task.url);
      debugPrint(
          '🔄 Smart prefetch [priority ${task.priority}] index ${task.index}: ${task.url}');

      try {
        final fileInfo = await instance.getFileFromCache(task.url);
        if (fileInfo != null && fileInfo.file.existsSync()) {
          debugPrint('✅ Already cached, skipping: ${task.url}');
          _prefetchInProgress.remove(task.url);
          continue;
        }

        await instance.getSingleFile(task.url);
        debugPrint('✅ Smart prefetch done: index ${task.index}');
      } catch (e) {
        debugPrint('⚠️ Smart prefetch failed (non-critical): $e');
      } finally {
        _prefetchInProgress.remove(task.url);
      }
    }

    _isProcessingQueue = false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🆕 FEATURE 3: RETRY LOGIC
  // ══════════════════════════════════════════════════════════════════════════

  /// Retry-aware video cache fetcher
  ///
  /// Tries up to [_maxRetryAttempts] times with exponential back-off.
  /// Returns local path on success, null after all retries exhausted.
  static Future<String?> getCachedVideoPath(String videoUrl) async {
    // 1️⃣ Cache hit — no network needed
    try {
      final fileInfo = await instance.getFileFromCache(videoUrl);
      if (fileInfo != null && fileInfo.file.existsSync()) {
        debugPrint('✅ Cache hit: ${fileInfo.file.path}');
        return fileInfo.file.path;
      }
    } catch (e) {
      debugPrint('⚠️ Cache lookup error: $e');
    }

    // 2️⃣ Cache miss — download with retry
    debugPrint('📥 Cache miss, downloading: $videoUrl');

    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        debugPrint('🔁 Attempt $attempt/$_maxRetryAttempts');
        final file = await instance.getSingleFile(videoUrl);

        if (file.existsSync()) {
          debugPrint('✅ Downloaded & cached (attempt $attempt): ${file.path}');
          return file.path;
        }
      } catch (e) {
        debugPrint('❌ Attempt $attempt failed: $e');

        if (attempt < _maxRetryAttempts) {
          // Exponential back-off: 800ms, 1600ms, 3200ms …
          final delay = _retryBaseDelay * (1 << (attempt - 1)); // 2^(attempt-1)
          debugPrint('⏳ Retrying in ${delay.inMilliseconds}ms…');
          await Future.delayed(delay);
        }
      }
    }

    debugPrint('❌ All $_maxRetryAttempts attempts failed for: $videoUrl');
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ORIGINAL METHODS (unchanged public API)
  // ══════════════════════════════════════════════════════════════════════════

  /// Legacy single-URL prefetch (still works; use [smartPrefetch] for feed)
  static Future<void> prefetchVideo(String videoUrl) async {
    try {
      if (_prefetchInProgress.contains(videoUrl)) {
        debugPrint('⏭️ Already prefetching: $videoUrl');
        return;
      }

      final fileInfo = await instance.getFileFromCache(videoUrl);
      if (fileInfo != null && fileInfo.file.existsSync()) {
        debugPrint('✅ Already cached, no need to prefetch');
        return;
      }

      _prefetchInProgress.add(videoUrl);
      instance.getSingleFile(videoUrl).then((file) {
        if (file.existsSync()) {
          debugPrint('✅ Pre-fetch successful: ${file.path}');
        }
      }).catchError((e) {
        debugPrint('⚠️ Pre-fetch failed (not critical): $e');
      }).whenComplete(() => _prefetchInProgress.remove(videoUrl));
    } catch (e) {
      debugPrint('⚠️ Error pre-fetching video: $e');
      _prefetchInProgress.remove(videoUrl);
    }
  }

  static Future<void> clearCache() async {
    try {
      debugPrint('🧹 Clearing video cache…');
      _prefetchQueue.clear();
      _prefetchInProgress.clear();
      await instance.emptyCache();
      debugPrint('✅ Video cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  static Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheFiles = Directory('${cacheDir.path}/$key')
          .listSync()
          .where((item) => item is File)
          .toList();

      int totalSize = 0;
      for (var file in cacheFiles) {
        if (file is File) totalSize += await file.length();
      }

      final info = {
        'count': cacheFiles.length,
        'size_mb': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'size_bytes': totalSize,
      };

      debugPrint(
          '📊 Cache Info: ${info['count']} videos, ${info['size_mb']} MB');
      return info;
    } catch (e) {
      debugPrint('❌ Error getting cache info: $e');
      return {'count': 0, 'size_mb': '0.00', 'size_bytes': 0};
    }
  }

  static Future<void> cleanupOldCache() async {
    try {
      debugPrint('🗑️ Cleaning up old cached videos…');

      final cacheDir = await getTemporaryDirectory();
      final videoCacheDir = Directory('${cacheDir.path}/$key');

      if (!await videoCacheDir.exists()) {
        debugPrint('ℹ️ No cache directory found');
        return;
      }

      final files = videoCacheDir
          .listSync()
          .where((item) => item is File)
          .cast<File>()
          .toList();

      int deletedCount = 0;
      final now = DateTime.now();

      for (var file in files) {
        final stat = await file.stat();
        final age = now.difference(stat.modified);
        if (age.inDays > 7) {
          await file.delete();
          deletedCount++;
          debugPrint('🗑️ Deleted old cache file: ${file.path}');
        }
      }

      debugPrint('✅ Cleanup complete: Deleted $deletedCount old videos');
    } catch (e) {
      debugPrint('❌ Error during cache cleanup: $e');
    }
  }

  static Future<void> removeFromCache(String videoUrl) async {
    try {
      debugPrint('🗑️ Removing from cache: $videoUrl');
      await instance.removeFile(videoUrl);
      debugPrint('✅ Removed from cache');
    } catch (e) {
      debugPrint('❌ Error removing from cache: $e');
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// PRIVATE HELPERS
// ══════════════════════════════════════════════════════════════════════════

enum _NetworkType { wifi, mobile, none }

class _PrefetchTask {
  final int index;
  final String url;
  final int priority; // lower = higher priority

  const _PrefetchTask({
    required this.index,
    required this.url,
    required this.priority,
  });
}