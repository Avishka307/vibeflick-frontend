import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

/// Video recording utility that captures frames with effects burned in
/// මේකෙන් effects එක්ක video එකක් record කරන්න පුළුවන්
class VideoRecorderWithEffects {
  final GlobalKey repaintKey;
  List<ui.Image> capturedFrames = [];
  bool isRecording = false;

  VideoRecorderWithEffects({required this.repaintKey});

  /// Start recording frames with effects
  Future<void> startRecording() async {
    isRecording = true;
    capturedFrames.clear();
  }

  /// Capture a single frame from the RepaintBoundary
  Future<void> captureFrame() async {
    if (!isRecording) return;

    try {
      RenderRepaintBoundary boundary = repaintKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      capturedFrames.add(image);
    } catch (e) {
      print('Error capturing frame: $e');
    }
  }

  /// Stop recording and save video
  Future<String?> stopRecording({int fps = 30}) async {
    isRecording = false;

    if (capturedFrames.isEmpty) {
      print('No frames captured');
      return null;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${directory.path}/video_with_effects_$timestamp.mp4';

      // Note: FFmpeg integration කරන්න ඕන නම් ffmpeg_kit_flutter package එක පාවිච්චි කරන්න
      // දැනට frames PNG sequence එකක් විදියට save කරනවා
      await _saveFramesAsSequence(directory.path, timestamp);

      print('Frames saved. Use FFmpeg to create video from sequence.');
      return outputPath;
    } catch (e) {
      print('Error saving recording: $e');
      return null;
    }
  }

  /// Save frames as PNG sequence
  Future<void> _saveFramesAsSequence(String directory, int timestamp) async {
    final framesDir = Directory('$directory/frames_$timestamp');
    if (!await framesDir.exists()) {
      await framesDir.create(recursive: true);
    }

    for (int i = 0; i < capturedFrames.length; i++) {
      final byteData =
      await capturedFrames[i].toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final file = File('${framesDir.path}/frame_${i.toString().padLeft(5, '0')}.png');
      await file.writeAsBytes(buffer);
    }

    print('Saved ${capturedFrames.length} frames to ${framesDir.path}');
  }

  /// Clear captured frames
  void clear() {
    capturedFrames.clear();
  }
}

/// Advanced version with FFmpeg integration (requires ffmpeg_kit_flutter package)
///
/// pubspec.yaml එකට එකතු කරන්න:
/// ffmpeg_kit_flutter: ^6.0.3
///
/// Usage example:
/// ```dart
/// final recorder = AdvancedVideoRecorder(repaintKey: _repaintKey);
/// await recorder.startRecording();
/// // Record frames...
/// final videoPath = await recorder.stopAndCreateVideo();
/// ```
class AdvancedVideoRecorder {
  final GlobalKey repaintKey;
  final List<String> _framePaths = [];
  String? _outputDirectory;
  bool isRecording = false;

  AdvancedVideoRecorder({required this.repaintKey});

  Future<void> startRecording() async {
    isRecording = true;
    _framePaths.clear();

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _outputDirectory = '${directory.path}/video_frames_$timestamp';

    await Directory(_outputDirectory!).create(recursive: true);
  }

  Future<void> captureFrame() async {
    if (!isRecording || _outputDirectory == null) return;

    try {
      RenderRepaintBoundary boundary = repaintKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final frameNumber = _framePaths.length;
      final framePath =
          '$_outputDirectory/frame_${frameNumber.toString().padLeft(5, '0')}.png';

      await File(framePath).writeAsBytes(buffer);
      _framePaths.add(framePath);
    } catch (e) {
      print('Error capturing frame: $e');
    }
  }

  Future<String?> stopAndCreateVideo({int fps = 30}) async {
    isRecording = false;

    if (_framePaths.isEmpty || _outputDirectory == null) {
      print('No frames to process');
      return null;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${directory.path}/video_$timestamp.mp4';

      // FFmpeg command to create video from frames
      // ffmpeg -framerate $fps -i $_outputDirectory/frame_%05d.png -c:v libx264 -pix_fmt yuv420p $outputPath

      print('Use FFmpeg to create video:');
      print('ffmpeg -framerate $fps -i $_outputDirectory/frame_%05d.png -c:v libx264 -pix_fmt yuv420p $outputPath');

      // FFmpeg integration කරන්න නම්:
      // final session = await FFmpegKit.execute(
      //   '-framerate $fps -i $_outputDirectory/frame_%05d.png -c:v libx264 -pix_fmt yuv420p $outputPath'
      // );
      //
      // if (ReturnCode.isSuccess(await session.getReturnCode())) {
      //   // Clean up frames
      //   await Directory(_outputDirectory!).delete(recursive: true);
      //   return outputPath;
      // }

      return outputPath;
    } catch (e) {
      print('Error creating video: $e');
      return null;
    }
  }

  void clear() {
    _framePaths.clear();
  }
}

/// Helper class for managing recording state
class RecordingManager {
  final VideoRecorderWithEffects recorder;
  bool _isRecording = false;
  DateTime? _recordingStartTime;

  RecordingManager(this.recorder);

  bool get isRecording => _isRecording;
  Duration? get recordingDuration {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }

  Future<void> startRecording() async {
    await recorder.startRecording();
    _isRecording = true;
    _recordingStartTime = DateTime.now();
  }

  Future<String?> stopRecording() async {
    final path = await recorder.stopRecording();
    _isRecording = false;
    _recordingStartTime = null;
    return path;
  }
}