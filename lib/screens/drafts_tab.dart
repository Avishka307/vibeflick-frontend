import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'activity_selected_media.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Draft Model — editing state සම්පූර්ණයෙන් store කරනවා
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class DraftItem {
  final String path;
  final bool isVideo;
  final String timestamp;
  final String? music;
  final String? thumbnailPath;
  final int durationSeconds;
  final double musicStartSec;
  final double musicVolume;

  // ── Editing state ─────────────────────────────────────────────
  final List<double>? activeFilterMatrix;
  final List<Map<String, dynamic>> placedStickers;
  final List<Map<String, dynamic>> textOverlays;
  final List<Map<String, dynamic>> effectLayers;
  final double trimStart;
  final double trimEnd;
  final String aspectRatio;
  final double originalAudioVolume;
  final bool isOriginalAudioMuted;
  final List<String> allMediaPaths;
  final List<bool> allMediaIsVideo;

  DraftItem({
    required this.path,
    required this.isVideo,
    required this.timestamp,
    this.music,
    this.thumbnailPath,
    this.durationSeconds = 0,
    this.musicStartSec = 0.0,
    this.musicVolume = 1.0,
    // editing defaults
    this.activeFilterMatrix,
    this.placedStickers = const [],
    this.textOverlays = const [],
    this.effectLayers = const [],
    this.trimStart = 0.0,
    this.trimEnd = 1.0,
    this.aspectRatio = '9:16',
    this.originalAudioVolume = 1.0,
    this.isOriginalAudioMuted = false,
    this.allMediaPaths = const [],
    this.allMediaIsVideo = const [],
  });

  factory DraftItem.fromJson(Map<String, dynamic> json) {
    // ── Helper: safely cast List<dynamic> → List<double> ──
    List<double>? _toDoubleList(dynamic raw) {
      if (raw == null) return null;
      if (raw is List) {
        return raw.map((e) => (e as num).toDouble()).toList();
      }
      return null;
    }

    List<Map<String, dynamic>> _toMapList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    }

    List<String> _toStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    List<bool> _toBoolList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e as bool).toList();
      return [];
    }

    return DraftItem(
      path: json['path'] as String,
      isVideo: json['isVideo'] as bool,
      timestamp: json['timestamp'] as String,
      music: json['music'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      durationSeconds: (json['durationSeconds'] as int?) ?? 0,
      musicStartSec: (json['musicStartSec'] as num?)?.toDouble() ?? 0.0,
      musicVolume: (json['musicVolume'] as num?)?.toDouble() ?? 1.0,
      // editing state
      activeFilterMatrix: _toDoubleList(json['activeFilterMatrix']),
      placedStickers: _toMapList(json['placedStickers']),
      textOverlays: _toMapList(json['textOverlays']),
      effectLayers: _toMapList(json['effectLayers']),
      trimStart: (json['trimStart'] as num?)?.toDouble() ?? 0.0,
      trimEnd: (json['trimEnd'] as num?)?.toDouble() ?? 1.0,
      aspectRatio: (json['aspectRatio'] as String?) ?? '9:16',
      originalAudioVolume:
      (json['originalAudioVolume'] as num?)?.toDouble() ?? 1.0,
      isOriginalAudioMuted:
      (json['isOriginalAudioMuted'] as bool?) ?? false,
      allMediaPaths: _toStringList(json['allMediaPaths']),
      allMediaIsVideo: _toBoolList(json['allMediaIsVideo']),
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'isVideo': isVideo,
    'timestamp': timestamp,
    'music': music,
    'thumbnailPath': thumbnailPath,
    'durationSeconds': durationSeconds,
    'musicStartSec': musicStartSec,
    'musicVolume': musicVolume,
    // editing state
    'activeFilterMatrix': activeFilterMatrix,
    'placedStickers': placedStickers,
    'textOverlays': textOverlays,
    'effectLayers': effectLayers,
    'trimStart': trimStart,
    'trimEnd': trimEnd,
    'aspectRatio': aspectRatio,
    'originalAudioVolume': originalAudioVolume,
    'isOriginalAudioMuted': isOriginalAudioMuted,
    'allMediaPaths': allMediaPaths,
    'allMediaIsVideo': allMediaIsVideo,
  };
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DraftsTab
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class DraftsTab extends StatefulWidget {
  const DraftsTab({Key? key}) : super(key: key);

  @override
  State<DraftsTab> createState() => _DraftsTabState();
}

class _DraftsTabState extends State<DraftsTab> {
  List<DraftItem> _drafts = [];
  bool _isLoading = true;
  final Map<String, Uint8List?> _thumbCache = {};

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('saved_drafts') ?? '[]';
      final List<dynamic> list = json.decode(raw);

      final valid = <DraftItem>[];
      for (final item in list) {
        final d = DraftItem.fromJson(item as Map<String, dynamic>);
        if (await File(d.path).exists()) {
          valid.add(d);
        } else {
          // Dangling thumbnail cleanup
          if (d.thumbnailPath != null) {
            final t = File(d.thumbnailPath!);
            if (await t.exists()) await t.delete();
          }
        }
      }

      // Persist cleaned list
      await prefs.setString(
          'saved_drafts', json.encode(valid.map((d) => d.toJson()).toList()));

      if (mounted) {
        setState(() {
          _drafts = valid.reversed.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Load drafts error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDraft(int index) async {
    final draft = _drafts[index];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Draft?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('This draft will be permanently deleted.',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final file = File(draft.path);
      if (await file.exists()) await file.delete();

      if (draft.thumbnailPath != null) {
        final thumb = File(draft.thumbnailPath!);
        if (await thumb.exists()) await thumb.delete();
      }

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('saved_drafts') ?? '[]';
      final List<dynamic> list = json.decode(raw);
      list.removeWhere(
              (e) => (e as Map<String, dynamic>)['path'] == draft.path);
      await prefs.setString('saved_drafts', json.encode(list));

      setState(() {
        _drafts.removeAt(index);
        _thumbCache.remove(draft.path);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft deleted'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Delete draft error: $e');
    }
  }

  // ── Open draft — editing state සම්පූර්ණයෙන් restore ───────────────────
  void _openDraft(DraftItem draft) {
    // allMediaPaths/allMediaIsVideo save වෙලා නොතිබ්බොත් primary path use
    final List<String> mediaPaths = draft.allMediaPaths.isNotEmpty
        ? draft.allMediaPaths
        : [draft.path];
    final List<bool> mediaIsVideo = draft.allMediaIsVideo.isNotEmpty
        ? draft.allMediaIsVideo
        : [draft.isVideo];

    // Primary = index 0; extras = rest
    final String primaryPath = mediaPaths.first;
    final bool primaryIsVideo = mediaIsVideo.first;
    final List<String> extraPaths =
    mediaPaths.length > 1 ? mediaPaths.sublist(1) : [];
    final List<bool> extraIsVideo =
    mediaIsVideo.length > 1 ? mediaIsVideo.sublist(1) : [];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectedMediaScreen(
          mediaPath: primaryPath,
          isVideo: primaryIsVideo,
          extraMediaPaths: extraPaths,
          extraMediaIsVideo: extraIsVideo,
          initialFilterMatrix: draft.activeFilterMatrix,
          // ── Restored editing state ──────────────────────────────
          restoredPlacedStickers: draft.placedStickers,
          restoredTextOverlays: draft.textOverlays,
          restoredEffectLayers: draft.effectLayers,
          restoredTrimStart: draft.trimStart,
          restoredTrimEnd: draft.trimEnd,
          restoredAspectRatio: draft.aspectRatio,
          restoredOriginalAudioVolume: draft.originalAudioVolume,
          restoredIsOriginalAudioMuted: draft.isOriginalAudioMuted,
          restoredMusicTitle: draft.music,
          restoredMusicVolume: draft.musicVolume,
        ),
      ),
    ).then((_) => _loadDrafts());
  }

  // ── Thumbnail helpers ────────────────────────────────────────────────────
  Widget _buildThumb(DraftItem draft) {
    if (draft.thumbnailPath != null &&
        File(draft.thumbnailPath!).existsSync()) {
      return Image.file(
        File(draft.thumbnailPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _fallbackThumb(draft),
      );
    }
    if (!draft.isVideo) {
      return Image.file(
        File(draft.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _fallbackThumb(draft),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: _getOrGenThumb(draft.path),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.done &&
            snap.data != null) {
          return Image.memory(
            snap.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        }
        return _fallbackThumb(draft);
      },
    );
  }

  Future<Uint8List?> _getOrGenThumb(String videoPath) async {
    if (_thumbCache.containsKey(videoPath)) return _thumbCache[videoPath];
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: 0,
      );
      _thumbCache[videoPath] = bytes;
      return bytes;
    } catch (_) {
      _thumbCache[videoPath] = null;
      return null;
    }
  }

  Widget _fallbackThumb(DraftItem draft) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Icon(
          draft.isVideo ? Icons.videocam : Icons.image,
          color: Colors.white24,
          size: 36,
        ),
      ),
    );
  }

  String _fmtDuration(int totalSec) {
    final m = totalSec ~/ 60;
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      final mm = dt.month.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mn = dt.minute.toString().padLeft(2, '0');
      return '$mm-$dd $hh:$mn';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Drafts',
          style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF3B5C)))
          : _drafts.isEmpty
          ? _buildEmptyState()
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
            const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Drafts will be deleted after the app is uninstalled',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 4),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 0.72,
              ),
              itemCount: _drafts.length,
              itemBuilder: (context, index) =>
                  _buildDraftCard(_drafts[index], index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCard(DraftItem draft, int index) {
    return GestureDetector(
      onTap: () => _openDraft(draft),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                    child: _buildThumb(draft),
                  ),

                  // Duration badge
                  if (draft.isVideo && draft.durationSeconds > 0)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _fmtDuration(draft.durationSeconds),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                  // Play icon
                  if (draft.isVideo)
                    Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow,
                            color: Colors.white, size: 22),
                      ),
                    ),

                  // Music badge
                  if (draft.music != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.music_note,
                            color: Colors.white70, size: 12),
                      ),
                    ),

                  // Sticker count badge
                  if (draft.placedStickers.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${draft.placedStickers.length} 🎭',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10),
                        ),
                      ),
                    ),

                  // Filter indicator
                  if (draft.activeFilterMatrix != null)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.filter_vintage,
                            color: Colors.white70, size: 12),
                      ),
                    ),
                ],
              ),
            ),

            // Date + delete row
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(draft.timestamp),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11),
                  ),
                  GestureDetector(
                    onTap: () => _deleteDraft(index),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          color: Colors.white.withOpacity(0.5),
                          size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined,
              color: Colors.white.withOpacity(0.2), size: 64),
          const SizedBox(height: 16),
          Text('No Drafts Yet',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 18,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Your saved drafts will appear here',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 13)),
        ],
      ),
    );
  }
}