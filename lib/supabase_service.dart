import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class SupabaseService {
  static final _supabase = Supabase.instance.client;

  /// Upload audio file to Supabase Storage with progress tracking
  static Future<String?> uploadAudioToSupabase({
    required String filePath,
    required String fileName,
    required Function(double) onProgress,
  }) async {
    try {
      print('📤 Starting upload to Supabase...');

      final file = File(filePath);

      // Check if file exists
      if (!await file.exists()) {
        print('❌ File does not exist: $filePath');
        return null;
      }

      // Get file size for progress calculation
      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);
      print('📦 File size: ${fileSizeMB.toStringAsFixed(2)} MB');

      // 🔥 FIX: Reject files larger than 10 MB
      if (fileSizeMB > 10) {
        print('❌ File too large: ${fileSizeMB.toStringAsFixed(2)} MB (max 10 MB)');
        throw Exception('File size exceeds 10 MB limit. Please compress the audio.');
      }

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(fileName);

      // 🔥 FIX: Convert MP4 to MP3 extension for audio files
      String finalExtension = extension;
      if (extension.toLowerCase() == '.mp4' ||
          extension.toLowerCase() == '.mov' ||
          extension.toLowerCase() == '.avi') {
        finalExtension = '.mp3'; // Convert video extensions to audio
      }

      // 🔥 FIX: Add random suffix to prevent duplicates during retries
      final random = DateTime.now().microsecondsSinceEpoch % 10000;
      final uniqueFileName = 'audio_${timestamp}_${random}$finalExtension';

      print('📝 Uploading as: $uniqueFileName');

      // Read file bytes
      final fileBytes = await file.readAsBytes();

      // 🔥 FIX: Smart retry logic - retry network errors, NOT duplicate errors
      int retries = 3;
      String? uploadPath;

      while (retries > 0) {
        try {
          // Upload to Supabase Storage 'sounds' bucket with timeout
          uploadPath = await _supabase.storage.from('sounds').uploadBinary(
            uniqueFileName,
            fileBytes,
            fileOptions: FileOptions(
              contentType: _getContentType(finalExtension),
              upsert: false, // Don't overwrite existing files
            ),
          ).timeout(
            const Duration(seconds: 90), // 90 second timeout (increased)
            onTimeout: () {
              throw Exception('Upload timeout - network too slow');
            },
          );

          print('✅ Upload successful!');
          break; // Success - exit retry loop

        } catch (e) {
          print('❌ Upload attempt failed: $e');

          // ⚠️ DON'T RETRY duplicate errors - file already exists
          if (e.toString().contains('Duplicate') || e.toString().contains('409')) {
            print('⚠️ File already exists, using existing file...');

            // Get the public URL of the existing file
            final publicUrl = _supabase.storage
                .from('sounds')
                .getPublicUrl(uniqueFileName);

            print('✅ Using existing file: $publicUrl');
            onProgress(100.0);
            return publicUrl;
          }

          retries--;
          print('⚠️ Retries remaining: $retries');

          // If no more retries, throw the error
          if (retries == 0) {
            print('❌ All retry attempts failed');
            rethrow;
          }

          // Wait before retry (exponential backoff)
          final waitTime = (4 - retries) * 2; // 2s, 4s, 6s
          print('⏳ Waiting ${waitTime}s before retry...');
          await Future.delayed(Duration(seconds: waitTime));

          // Update progress to show retry
          onProgress(10.0 * (3 - retries));
        }
      }

      print('✅ Upload complete: $uploadPath');

      // Get public URL
      final publicUrl = _supabase.storage
          .from('sounds')
          .getPublicUrl(uniqueFileName);

      print('🔗 Public URL: $publicUrl');

      // Report 100% progress
      onProgress(100.0);

      return publicUrl;

    } catch (e, stackTrace) {
      print('❌ Error uploading to Supabase: $e');
      print('Stack trace: $stackTrace');

      // Better error messages
      if (e.toString().contains('500') || e.toString().contains('502')) {
        print('💡 TIP: Supabase server issue. Try again in a few moments.');
      } else if (e.toString().contains('timeout')) {
        print('💡 TIP: Upload timeout - check your internet connection or try a smaller file.');
      } else if (e.toString().contains('Duplicate') || e.toString().contains('409')) {
        print('💡 TIP: File already exists in storage.');
      } else if (e.toString().contains('Connection reset') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        print('💡 TIP: Network connection lost. Check your internet and try again.');
      } else if (e.toString().contains('No address associated with hostname')) {
        print('💡 TIP: Cannot reach Supabase server. Check your internet connection.');
      } else {
        print('💡 TIP: Upload failed. Try a smaller file or check your internet connection.');
      }

      return null;
    }
  }

  /// Get content type based on file extension
  static String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      default:
        return 'audio/mpeg';
    }
  }

  /// Delete audio file from Supabase Storage
  static Future<bool> deleteAudioFromSupabase(String audioUrl) async {
    try {
      // Extract file name from URL
      final uri = Uri.parse(audioUrl);
      final fileName = uri.pathSegments.last;

      print('🗑️ Deleting from Supabase: $fileName');

      await _supabase.storage.from('sounds').remove([fileName]);

      print('✅ File deleted from Supabase');
      return true;
    } catch (e) {
      print('❌ Error deleting from Supabase: $e');
      return false;
    }
  }

  /// Check Supabase storage usage (if available in your plan)
  static Future<void> checkStorageUsage() async {
    try {
      final files = await _supabase.storage.from('sounds').list();

      print('📊 Total files in storage: ${files.length}');

      // You can implement more detailed storage tracking here
    } catch (e) {
      print('⚠️ Could not check storage usage: $e');
    }
  }
}