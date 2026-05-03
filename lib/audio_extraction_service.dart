import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_compress/video_compress.dart';
import 'package:flutter_video_info/flutter_video_info.dart';

class AudioExtractionService {
  static final _videoInfo = FlutterVideoInfo();

  /// Extract audio from video file using video_compress
  static Future<String?> extractAudioFromVideo(
      String videoPath,
      Function(String) onProgress,
      ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/uploaded_audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${audioDir.path}/audio_$timestamp.mp3';

      onProgress('Starting extraction...');

      // Subscribe to compression progress
      final subscription = VideoCompress.compressProgress$.subscribe((progress) {
        onProgress('Extracting audio: ${progress.toInt()}%');
      });

      onProgress('Processing video...');

      // 🔥 FIX: Compress with LOWER quality to reduce file size
      final info = await VideoCompress.compressVideo(
        videoPath,
        quality: VideoQuality.LowQuality, // Changed from DefaultQuality
        deleteOrigin: false,
        includeAudio: true,
      );

      subscription.unsubscribe();

      if (info != null && info.file != null) {
        onProgress('Finalizing extraction...');

        final videoData = await _videoInfo.getVideoInfo(videoPath);

        if (videoData != null && videoData.duration != null) {
          onProgress('Completing...');

          // Copy compressed file
          await info.file!.copy(outputPath);

          // 🔥 Check final file size
          final finalFile = File(outputPath);
          final finalSize = await finalFile.length();
          final finalSizeMB = finalSize / (1024 * 1024);

          print('📦 Extracted audio size: ${finalSizeMB.toStringAsFixed(2)} MB');

          if (finalSizeMB > 10) {
            print('⚠️ Warning: Extracted file still large (${finalSizeMB.toStringAsFixed(2)} MB)');
          }

          onProgress('Audio extracted successfully!');
          return outputPath;
        } else {
          onProgress('No audio track found in video');
          return null;
        }
      } else {
        onProgress('Failed to extract audio');
        return null;
      }
    } catch (e) {
      print('Error extracting audio: $e');
      onProgress('Error: ${e.toString()}');
      return null;
    }
  }
  /// Copy audio file to app directory
  /// Uses native Dart file operations - no external libraries needed
  static Future<String?> copyAudioFile(String sourcePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/uploaded_audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(sourcePath);
      final outputPath = '${audioDir.path}/audio_$timestamp$extension';

      // Native Dart file copy - simple and efficient
      final sourceFile = File(sourcePath);
      await sourceFile.copy(outputPath);

      return outputPath;
    } catch (e) {
      print('Error copying audio file: $e');
      return null;
    }
  }

  /// Get audio/video duration using flutter_video_info
  /// Much faster than FFmpeg as it reads metadata directly
  static Future<int> getAudioDuration(String audioPath) async {
    try {
      // flutter_video_info works for both audio and video files
      final videoData = await _videoInfo.getVideoInfo(audioPath);

      if (videoData != null && videoData.duration != null) {
        // Duration is in milliseconds, convert to seconds
        return (videoData.duration! / 1000).round();
      }

      return 0;
    } catch (e) {
      print('Error getting audio duration: $e');

      // Fallback: Try using video_compress info
      try {
        final info = await VideoCompress.getMediaInfo(audioPath);
        if (info != null && info.duration != null) {
          // Duration is already in seconds
          return info.duration!.toInt();
        }
      } catch (fallbackError) {
        print('Fallback error: $fallbackError');
      }

      return 0;
    }
  }

  /// Clean up temporary files and release resources
  static Future<void> cleanup() async {
    try {
      await VideoCompress.deleteAllCache();
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }

  /// Get file size in MB
  static Future<double> getFileSizeInMB(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.length();
      return bytes / (1024 * 1024);
    } catch (e) {
      print('Error getting file size: $e');
      return 0;
    }
  }
}