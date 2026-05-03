import 'dart:io';
import 'package:my_vibe_flick/screens/storage_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';


class StorageService {
  // Calculate size of a directory
  Future<double> _calculateDirectorySize(Directory directory) async {
    double totalSize = 0;
    try {
      if (await directory.exists()) {
        await for (var entity in directory.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      print('Error calculating size: $e');
    }
    return totalSize / (1024 * 1024); // Convert to MB
  }

  // Count files in directory
  Future<int> _countFiles(Directory directory) async {
    int count = 0;
    try {
      if (await directory.exists()) {
        await for (var entity in directory.list(recursive: true)) {
          if (entity is File) count++;
        }
      }
    } catch (e) {
      print('Error counting files: $e');
    }
    return count;
  }

  // Get all storage categories
  Future<List<StorageInfo>> getStorageInfo() async {
    List<StorageInfo> storageList = [];

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = await getApplicationCacheDirectory();
      final appDir = await getApplicationDocumentsDirectory();

      // 1. Image Cache (Downloaded profile pics, posts, stories)
      final imageCacheDir = Directory('${cacheDir.path}/image_cache');
      final imageSize = await _calculateDirectorySize(imageCacheDir);
      final imageCount = await _countFiles(imageCacheDir);
      storageList.add(StorageInfo(
        category: 'Image Cache',
        sizeInMB: imageSize,
        path: imageCacheDir.path,
        fileCount: imageCount,
      ));

      // 2. Video Cache
      final videoCacheDir = Directory('${cacheDir.path}/video_cache');
      final videoSize = await _calculateDirectorySize(videoCacheDir);
      final videoCount = await _countFiles(videoCacheDir);
      storageList.add(StorageInfo(
        category: 'Video Cache',
        sizeInMB: videoSize,
        path: videoCacheDir.path,
        fileCount: videoCount,
      ));

      // 3. Temporary Files
      final tempSize = await _calculateDirectorySize(tempDir);
      final tempCount = await _countFiles(tempDir);
      storageList.add(StorageInfo(
        category: 'Temporary Files',
        sizeInMB: tempSize,
        path: tempDir.path,
        fileCount: tempCount,
      ));

      // 4. Thumbnails
      final thumbDir = Directory('${cacheDir.path}/thumbnails');
      final thumbSize = await _calculateDirectorySize(thumbDir);
      final thumbCount = await _countFiles(thumbDir);
      storageList.add(StorageInfo(
        category: 'Thumbnails',
        sizeInMB: thumbSize,
        path: thumbDir.path,
        fileCount: thumbCount,
      ));

      // 5. Database Cache (optional - if you have local DB)
      final dbDir = Directory('${appDir.path}/databases');
      final dbSize = await _calculateDirectorySize(dbDir);
      storageList.add(StorageInfo(
        category: 'Database Cache',
        sizeInMB: dbSize,
        path: dbDir.path,
        fileCount: 0,
      ));

    } catch (e) {
      print('Error getting storage info: $e');
    }

    return storageList;
  }

  // Clear specific category
  Future<bool> clearCategory(StorageInfo info) async {
    try {
      final directory = Directory(info.path);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        await directory.create(); // Recreate empty directory
        return true;
      }
    } catch (e) {
      print('Error clearing ${info.category}: $e');
      return false;
    }
    return false;
  }

  // Clear all cache (nuclear option)
  Future<void> clearAllCache() async {
    try {
      await DefaultCacheManager().emptyCache();
      final tempDir = await getTemporaryDirectory();
      final cacheDir = await getApplicationCacheDirectory();

      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        await tempDir.create();
      }

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }
    } catch (e) {
      print('Error clearing all cache: $e');
    }
  }

  // Get total storage used - FIXED VERSION
  Future<double> getTotalStorageUsed() async {
    final storageList = await getStorageInfo();
    double total = 0.0;
    for (var item in storageList) {
      total += item.sizeInMB;
    }
    return total;
  }
}